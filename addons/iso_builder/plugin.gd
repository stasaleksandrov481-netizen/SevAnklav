@tool
extends EditorPlugin
const Region=preload("res://iso/editor/region.gd")
const Piece=preload("res://iso/editor/piece.gd")
const DoorMarker=preload("res://iso/editor/door_marker.gd")
const Lamp=preload("res://iso/editor/lamp.gd")
const Station=preload("res://iso/editor/station.gd")
const Spawn=preload("res://iso/editor/spawn.gd")
var dock: VBoxContainer
var scroll: ScrollContainer
var palette: ItemList
var note: Label
var room_width: SpinBox
var room_depth: SpinBox
var grid: SpinBox
var placing:=false
var blank_copy:=false
var entries: Array=[]
var save_dialog: EditorFileDialog
var loot_type: OptionButton
var loot_count: SpinBox
var loot_ids: Array=[]
func _enter_tree() -> void:
	scroll=ScrollContainer.new(); scroll.name="Анклав — карты"; scroll.custom_minimum_size.x=300
	dock=VBoxContainer.new(); dock.custom_minimum_size.x=294; dock.add_theme_constant_override("separation",8); scroll.add_child(dock)
	_label("КОНСТРУКТОР ЛОКАЦИЙ")
	_button("Открыть весь бункер",func(): get_editor_interface().open_scene_from_path("res://iso/maps/zarya_bunker.tscn"))
	_button("Новая локация — копия текущей",_new_map)
	_button("Новая пустая локация",func(): blank_copy=true; save_dialog.current_path="res://iso/maps/new_location.tscn"; save_dialog.popup_centered_ratio(0.7))
	_button("Играть в текущую карту (F6)",_play)
	_button("Использовать карту в новой игре",_activate)
	_label("Размер НОВОЙ комнаты, м")
	room_width=_spin(12,2,50,1); room_depth=_spin(10,2,50,1)
	_label("Привязка размещения, м")
	grid=_spin(0.5,0.1,4,0.1)
	palette=ItemList.new(); palette.custom_minimum_size=Vector2(290,310); dock.add_child(palette)
	for entry in [["Комната с полом и стенами","room"],["Стена","wall"],["Пол","floor"],["Труба / кабель-канал","pipe"],["Своя модель GLB","custom"],["Лампа обычная","lamp"],["Лампа аварийная","emergency"],["Дверь","door"],["Контейнер с предметами","container"],["Сюжетный терминал","station"],["Точка появления существа","spawn"],["Старт игрока (свободная карта)","player_start"]]: entries.append(entry)
	var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://iso/editor/palette/catalogue.json"))
	for title in catalogue: entries.append([title,"res://iso/editor/palette/"+catalogue[title]+".tscn"])
	for entry in entries: palette.add_item(entry[0])
	palette.select(0)
	_button("Разместить щелчком в 3D",func(): placing=true; note.text="ЛКМ по полу — поставить. Esc — отменить. Затем W/E для перемещения/поворота.")
	_button("Добавить у выделенного объекта",_add_at_selection)
	_button("Вырезать проём под выбранной дверью",_cut_door)
	_label("Содержимое выбранного контейнера")
	loot_type=OptionButton.new(); dock.add_child(loot_type)
	for id in preload("res://iso/zarya/state.gd").ITEMS:
		loot_ids.append(id); loot_type.add_item(preload("res://iso/zarya/state.gd").ITEMS[id].name)
	loot_count=_spin(1,1,999,1)
	_button("Добавить предмет в контейнер",_fill_loot)
	_button("Очистить выбранный контейнер",func(): _set_contents([]))
	_button("Проверить карту",_validate)
	_button("Открыть инструкцию",func(): OS.shell_open(ProjectSettings.globalize_path("res://docs/КАК_СОБРАТЬ_КАРТУ.txt")))
	note=_label("Выберите объект в палитре. Всё редактируется в 3D и Инспекторе. Ctrl+S — сохранить, Ctrl+Z — отменить. Бункер виден целиком в редакторе; скрытие комнат работает только в игре.")
	save_dialog=EditorFileDialog.new(); save_dialog.file_mode=EditorFileDialog.FILE_MODE_SAVE_FILE; save_dialog.access=EditorFileDialog.ACCESS_RESOURCES; save_dialog.add_filter("*.tscn","Локация Godot"); save_dialog.file_selected.connect(_save_copy); dock.add_child(save_dialog)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL,scroll)
	set_input_event_forwarding_always_enabled()
	if OS.get_cmdline_user_args().has("--anklav-editor-test"): call_deferred("_qa")
func _exit_tree() -> void:
	remove_control_from_docks(scroll); scroll.queue_free()
func _label(text: String) -> Label:
	var label:=Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; dock.add_child(label); return label
func _button(text: String, fn: Callable) -> void:
	var b:=Button.new(); b.text=text; b.pressed.connect(fn); dock.add_child(b)
func _spin(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var s:=SpinBox.new(); s.min_value=minimum; s.max_value=maximum; s.step=step; s.value=value; dock.add_child(s); return s
func _root() -> Node3D:
	var node=get_editor_interface().get_edited_scene_root()
	if node is Node3D and node.get_script()==preload("res://iso/editor/map.gd"): return node
	note.text="Сначала нажмите «Открыть весь бункер» или откройте копию его сцены."
	return null
func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not placing: return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: placing=false; return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var point=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
		if point!=null: _place(point); placing=false
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS
func _add_at_selection() -> void:
	var map=_root()
	if not map: return
	var selected=get_editor_interface().get_selection().get_selected_nodes()
	var pos:=Vector3.ZERO
	if not selected.is_empty() and selected[0] is Node3D: pos=selected[0].global_position+Vector3(2,0,0); pos.y=0
	_place(pos)
func _unique(prefix: String) -> String: return prefix+"_"+str(Time.get_ticks_usec())
func _place(at: Vector3) -> void:
	var map=_root()
	if not map or palette.get_selected_items().is_empty(): return
	at.x=snappedf(at.x,grid.value); at.z=snappedf(at.z,grid.value)
	var kind: String=entries[palette.get_selected_items()[0]][1]
	var node: Node3D
	match kind:
		"room":
			node=Region.new(); node.room_id=_unique("room"); node.title="НОВАЯ КОМНАТА"; node.width=room_width.value; node.depth=room_depth.value
			_add_piece(node,"Floor",Vector3(node.width,0.18,node.depth),Vector3(0,-0.09,0))
			for side in [-1,1]:
				_add_piece(node,"Wall",Vector3(node.width,2.8,0.2),Vector3(0,1.4,side*node.depth/2))
				_add_piece(node,"Wall",Vector3(0.2,2.8,node.depth),Vector3(side*node.width/2,1.4,0))
		"wall","floor","pipe":
			node=Piece.new(); node.kind="Wall" if kind=="wall" else "Floor"; node.dimensions=Vector3(3,2.8,0.2) if kind=="wall" else Vector3(3,0.18,3); at.y=1.4 if kind=="wall" else -0.09
			if kind=="pipe": node.kind="Block"; node.dimensions=Vector3(3,0.08,0.08); node.solid=false; at.y=1.7
		"lamp","emergency":
			node=Lamp.new(); node.emergency=kind=="emergency"; node.tint=Color("#e9533b") if node.emergency else Color("#bad2df"); node.energy=1.4 if node.emergency else 2.7; at.y=2.1
		"door": node=DoorMarker.new(); node.door_id=_unique("door")
		"container","station":
			node=Station.new(); node.action_id=_unique(kind); node.kind="loot" if kind=="container" else "terminal"; node.title="КОНТЕЙНЕР" if kind=="container" else "ТЕРМИНАЛ"
			var model=load("res://iso/editor/palette/locker.tscn" if kind=="container" else "res://iso/editor/palette/terminal.tscn").instantiate(); node.add_child(model)
		"player_start": node=preload("res://iso/editor/player_start.gd").new(); at.y=0.95
		"custom": node=preload("res://iso/prop.gd").new(); node.kind=4
		"spawn": node=Spawn.new(); node.spawn_id=_unique("subject"); at.y=0.95
		_: node=load(kind).instantiate()
	node.name=entries[palette.get_selected_items()[0]][0].replace(" ","_")
	var parent: Node3D=map
	if kind not in ["room","door","spawn"]:
		for region in map.get_children():
			if region.get_script()==Region and region.contains_world_point(at): parent=region; break
	node.position=parent.to_local(at)
	if kind=="door": _door_neighbours(node,map,at)
	var undo=get_undo_redo(); undo.create_action("Добавить "+node.name)
	undo.add_do_method(parent,"add_child",node,true); undo.add_do_method(self,"_own",node,map)
	undo.add_undo_method(parent,"remove_child",node); undo.add_do_reference(node); undo.commit_action()
	get_editor_interface().get_selection().clear(); get_editor_interface().get_selection().add_node(node)
	note.text="Добавлено. W — двигать, E — повернуть; размеры/свет/допуск — в Инспекторе. Ctrl+S — сохранить."
func _add_piece(parent: Node3D, kind: String, dimensions: Vector3, at: Vector3) -> void:
	var p=Piece.new(); p.kind=kind; p.name=kind; p.dimensions=dimensions; p.position=at; parent.add_child(p,true)
func _own(node: Node, map: Node) -> void:
	node.owner=map
	for child in node.get_children():
		if child.name in ["Generated","Preview"]: continue
		_own(child,map)
func _door_neighbours(door: Node3D, map: Node3D, at: Vector3) -> void:
	var normal:=door.basis.z
	for region in map.get_children():
		if region.get_script()!=Region: continue
		if region.contains_world_point(at-normal*0.45): door.room_a=region.room_id
		if region.contains_world_point(at+normal*0.45): door.room_b=region.room_id
func _cut_door() -> void:
	var map=_root()
	if not map: return
	var selection=get_editor_interface().get_selection().get_selected_nodes()
	if selection.is_empty() or selection[0].get_script()!=DoorMarker: note.text="Выделите узел двери в дереве сцены."; return
	var door=selection[0]
	var old_a: String=door.room_a; var old_b: String=door.room_b
	_door_neighbours(door,map,door.global_position)
	var gap:=3.0 if door.kind=="gate" else 1.4
	var undo=get_undo_redo(); undo.create_action("Вырезать дверной проём")
	undo.add_do_property(door,"room_a",door.room_a); undo.add_do_property(door,"room_b",door.room_b)
	undo.add_undo_property(door,"room_a",old_a); undo.add_undo_property(door,"room_b",old_b)
	var count:=0
	for wall in map.find_children("*","Node3D",true,false):
		if wall.get_script()!=Piece or wall.kind!="Wall" or wall.dimensions.y<2: continue
		var p: Vector3=wall.to_local(door.global_position)
		var axis:=0 if wall.dimensions.x>wall.dimensions.z else 2
		var across:=2 if axis==0 else 0
		if absf(p[across])>wall.dimensions[across]/2+0.12 or absf(p[axis])>wall.dimensions[axis]/2: continue
		if absf(wall.global_basis[across].dot(door.global_basis.z))<0.9: continue
		count+=1
		var lo: float=-wall.dimensions[axis]/2; var hi: float=wall.dimensions[axis]/2
		for interval in [Vector2(lo,p[axis]-gap/2),Vector2(p[axis]+gap/2,hi)]:
			if interval.y-interval.x<0.02: continue
			var part=Piece.new(); part.kind="Wall"; part.material=wall.material; part.dimensions=wall.dimensions; part.dimensions[axis]=interval.y-interval.x
			part.transform=wall.transform; var offset:=Vector3.ZERO; offset[axis]=(interval.x+interval.y)/2; part.position+=wall.basis*offset
			undo.add_do_method(wall.get_parent(),"add_child",part,true); undo.add_do_method(self,"_own",part,map); undo.add_undo_method(wall.get_parent(),"remove_child",part); undo.add_do_reference(part)
		undo.add_do_method(wall.get_parent(),"remove_child",wall); undo.add_undo_method(wall.get_parent(),"add_child",wall); undo.add_undo_method(self,"_own",wall,map); undo.add_undo_reference(wall)
	undo.commit_action()
	note.text="Разрезано стен: "+str(count)+". Проверьте Room A / Room B у двери. Проём не создаёт скрытых коллизий."
func _validate() -> void:
	var map=_root()
	if not map: return
	var problems: Array[String]=[]; var ids: Dictionary={}; var regions: Dictionary={}; var starts:=0
	for node in map.get_children():
		if node.get_script()==Region: regions[node.room_id]=true
	for node in map.find_children("*","Node3D",true,false):
		var key: String=""
		if node.get_script()==preload("res://iso/editor/player_start.gd"): starts+=1
		if node.get_script()==Region: key="room:"+node.room_id
		elif node.get_script()==DoorMarker:
			key="door:"+node.door_id
			if not regions.has(node.room_a) or not regions.has(node.room_b) or node.room_a==node.room_b: problems.append("Дверь без двух разных комнат: "+node.name)
		elif node.get_script()==Station: key="action:"+node.action_id
		elif node.get_script()==Spawn: key="spawn:"+node.spawn_id
		if not key.is_empty():
			if ids.has(key): problems.append("Повтор ID: "+key)
			ids[key]=true
	if map.story_enabled and (not regions.has("capsule") or not map.find_child("V17Capsule",true,false)): problems.append("Для запуска истории нужны комната capsule и V17Capsule.")
	for id in ["staff","weapon","card","fuse","power","archive","experiment","quarantine","stairs"]:
		if map.story_enabled and not ids.has("action:"+id): problems.append("Нет сюжетного объекта: "+id)
	if not map.story_enabled and starts!=1: problems.append("Свободной карте нужна ровно одна точка старта игрока.")
	note.text="Проверка: ошибок структуры не найдено. Затем пройдите карту в F6." if problems.is_empty() else "\n".join(problems)
func _play() -> void:
	var map=_root()
	if not map: return
	get_editor_interface().save_scene(); get_editor_interface().play_custom_scene(map.scene_file_path)
func _activate() -> void:
	var map=_root()
	if not map: return
	get_editor_interface().save_scene(); ProjectSettings.set_setting("anklav/active_map",map.scene_file_path); ProjectSettings.save()
	note.text="Новая игра использует "+map.scene_file_path+". Карты имеют отдельные сохранения по Map Id."
func _new_map() -> void:
	if not _root(): return
	blank_copy=false
	save_dialog.current_path="res://iso/maps/new_location.tscn"; save_dialog.popup_centered_ratio(0.7)
func _save_copy(path: String) -> void:
	var map=get_editor_interface().get_edited_scene_root()
	if FileAccess.file_exists(path): note.text="Выберите новое имя: существующие карты не перезаписываются."; return
	var copy: Node3D
	if blank_copy: copy=preload("res://iso/editor/map.gd").make_blank(path.get_file().get_basename())
	else:
		if not _root(): return
		get_editor_interface().save_scene()
		var scene: PackedScene=load(map.scene_file_path); copy=scene.instantiate(); copy.map_id=path.get_file().get_basename()
	var packed:=PackedScene.new(); packed.pack(copy)
	if ResourceSaver.save(packed,path)!=OK: note.text="Не удалось сохранить карту."; copy.free(); return
	copy.free()
	get_editor_interface().get_resource_filesystem().scan(); get_editor_interface().open_scene_from_path(path)

func _qa() -> void:
	await preload("res://tests/editor_workflow.gd").new().run(self)

func _selected_station() -> Node3D:
	var selected=get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty(): return null
	var node=selected[0]
	while node and node!=_root():
		if node.get_script()==Station: return node
		node=node.get_parent()
	return null
func _set_contents(values: Array) -> void:
	var node=_selected_station()
	if not node: note.text="Выберите контейнер/шкаф с Action Id."; return
	var typed: Array[Dictionary]=[]; typed.assign(values)
	var undo=get_undo_redo(); undo.create_action("Содержимое контейнера")
	undo.add_do_property(node,"initial_contents",typed); undo.add_undo_property(node,"initial_contents",node.initial_contents.duplicate(true)); undo.commit_action()
	note.text="Содержимое обновлено. Уже обысканные контейнеры в старом сохранении не пополняются. Проверяйте через F6."
func _fill_loot() -> void:
	var node=_selected_station()
	if not node: note.text="Выберите контейнер/шкаф с Action Id."; return
	var values: Array=node.initial_contents.duplicate(true)
	values.append({"id":loot_ids[loot_type.selected],"count":int(loot_count.value),"condition":100})
	_set_contents(values)
