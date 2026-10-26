extends CanvasLayer
const State=preload("res://iso/zarya/state.gd")
const Icons=preload("res://scripts/ui/equipment_icons.gd")
var world
var root: Control
var objective: Label
var notice: Label
var bars := {}
var slots: Array = []
var modal: Control
var selected := ""
var selected_zone := "Торс"
var minimap
var weapon_status: Label
var dead_shown := false
var timer := 0.0
var refresh_clock := 0.0
func style() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(0.018,0.027,0.032,0.88)
	s.border_color=Color("#526068")
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(12)
	return s
func surface_style() -> StyleBoxTexture:
	var surface:=StyleBoxTexture.new(); surface.texture=preload("res://assets/ui/zarya/panel.svg")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: surface.set_texture_margin(side,7)
	surface.set_content_margin_all(12)
	return surface
func label(parent: Node, text: String, size := 18) -> Label:
	var result:=Label.new(); result.text=text
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("#bdcbd0"))
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result
func icon_button(parent: Node, id: String, hint: String, callback: Callable) -> Button:
	var b:=button(parent,"",callback,60)
	b.custom_minimum_size=Vector2(60,60); b.tooltip_text=hint
	b.icon=load("res://assets/ui/controls/"+id+".svg"); b.expand_icon=true
	b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER; b.add_theme_constant_override("icon_max_width",32)
	var disabled:=style(); disabled.bg_color=Color("#10171c"); b.add_theme_stylebox_override("disabled",disabled)
	b.add_theme_color_override("icon_disabled_color",Color(0.4,0.5,0.55,0.4))
	return b
func button(parent: Node, text: String, callback: Callable, width := 110) -> Button:
	var b:=Button.new(); b.text=text; b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size=Vector2(width,52)
	b.add_theme_stylebox_override("normal",surface_style())
	var hover:=style(); hover.bg_color=Color("#23343b"); hover.border_color=Color("#9aaeb5")
	b.add_theme_stylebox_override("hover",hover)
	var pressed:=style(); pressed.bg_color=Color("#334850")
	b.add_theme_stylebox_override("pressed",pressed)
	b.add_theme_font_size_override("font_size",14)
	b.add_theme_color_override("font_color",Color("#b8d1dc"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
func panel(parent: Node, at: Vector2, dimensions: Vector2) -> PanelContainer:
	var p:=PanelContainer.new(); p.position=at; p.custom_minimum_size=dimensions
	p.add_theme_stylebox_override("panel",surface_style()); parent.add_child(p)
	return p
var icon_cache := {}
var detail_title: Label
var detail_description: Label
var detail_image: TextureRect
var item_actions := {}
var shade: ColorRect
var hud_body
var last_map_position := Vector3.INF
var last_map_count := -1
var canvas_size := Vector2(1600,900)
func place(node: Control, rect: Rect2) -> void:
	node.position=rect.position; node.size=rect.size
func _fit_canvas() -> void:
	var viewport_size:=get_viewport().get_visible_rect().size
	var safe:=Rect2(Vector2.ZERO,viewport_size)
	if OS.has_feature("mobile"):
		var pixels:=DisplayServer.get_display_safe_area()
		var window_pixels:=Vector2(DisplayServer.window_get_size())
		if pixels.has_area() and window_pixels.x>0 and window_pixels.y>0:
			var ratio:=viewport_size/window_pixels
			safe=Rect2(Vector2(pixels.position)*ratio,Vector2(pixels.size)*ratio).intersection(safe)
	var factor:=minf(1.0,minf(safe.size.x/1600.0,safe.size.y/900.0))
	root.scale=Vector2.ONE*factor; root.position=safe.position; root.size=safe.size/factor
	canvas_size=root.size
	_layout_hud()
func _layout_hud() -> void:
	if not root.has_node("Tasks"): return
	var w:=canvas_size.x; var h:=canvas_size.y
	var rects: Dictionary={
		"Tasks":Rect2(18,18,300,130),"Vitals":Rect2(w/2-160,16,320,72),
		"Tools":Rect2(w-452,18,198,60),"Condition":Rect2(18,162,112,142),
		"Map":Rect2(w-232,18,214,168),"Belt":Rect2(w/2-345,h-148,690,130),
		"Check":Rect2(w/2-450,h-126,90,96),"MoveStick":Rect2(22,h-395,245,245),
		"AimStick":Rect2(w-267,h-395,245,245),"Interact":Rect2(w-340,h-193,64,64),
		"Weapon":Rect2(w-397,h-92,379,72),"Utilities":Rect2(18,h-80,238,60),
		"Notice":Rect2(w/2-350,114,700,64)}
	for key in rects:
		var n=root.get_node_or_null(NodePath(key))
		if n: n.position=rects[key].position; n.size=rects[key].size
	if is_instance_valid(shade): shade.size=canvas_size
	if is_instance_valid(modal):
		modal.position=Vector2(24,36); modal.size=canvas_size-Vector2(48,72)
func _ready() -> void:
	world=get_parent(); world.hud=self
	root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	_fit_canvas(); get_viewport().size_changed.connect(_fit_canvas)
	var task:=panel(root,Vector2(20,24),Vector2(300,130)); task.name="Tasks"
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",14); task.add_child(column)
	label(column,"▤   ЗАДАЧИ",15)
	column.add_child(HSeparator.new())
	objective=label(column,"",20)
	objective.add_theme_color_override("font_color",Color("#e0e4e3"))
	var status:=panel(root,Vector2(566,18),Vector2(320,72)); status.name="Vitals"
	var stack:=VBoxContainer.new(); stack.add_theme_constant_override("separation",10); status.add_child(stack)
	for entry in [["food","ПИТАНИЕ",Color("#dbb567")],["water","ВОДА",Color("#74b4cf")]]:
		var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",16); stack.add_child(row)
		var title:=label(row,entry[1],13); title.custom_minimum_size.x=78
		var bar:=preload("res://iso/zarya/meter.gd").new(); bar.tint=entry[2]; bar.custom_minimum_size=Vector2(180,19)
		row.add_child(bar); bars[entry[0]]=bar
	var tools:=HBoxContainer.new(); tools.position=Vector2(980,22); tools.add_theme_constant_override("separation",8); root.add_child(tools); tools.name="Tools"
	icon_button(tools,"bag","Рюкзак",open_inventory)
	icon_button(tools,"pda","КПК",open_pda)
	icon_button(tools,"pause","Пауза",pause_menu)
	var condition:=panel(root,Vector2(392,18),Vector2(112,142)); condition.name="Condition"
	var condition_stack:=VBoxContainer.new(); condition.add_child(condition_stack)
	label(condition_stack,"V-17",11)
	var body_area:=Control.new(); body_area.custom_minimum_size=Vector2(120,100); condition_stack.add_child(body_area)
	hud_body=preload("res://iso/zarya/body.gd").new(); hud_body.ui=self
	hud_body.scale=Vector2(0.25,0.25); hud_body.position=Vector2(1,0); hud_body.size=Vector2(340,410)
	hud_body.mouse_filter=Control.MOUSE_FILTER_IGNORE; body_area.add_child(hud_body)
	var body_hit:=Button.new(); body_hit.flat=true; body_hit.tooltip_text="Состояние организма / лечение"
	body_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body_hit.pressed.connect(open_medical); body_area.add_child(body_hit)
	var map_frame:=panel(root,Vector2(1325,18),Vector2(214,168)); map_frame.name="Map"
	var map_stack:=VBoxContainer.new(); map_frame.add_child(map_stack)
	label(map_stack,"ПОДЗЕМНЫЙ УРОВЕНЬ\nЗАРЯ  /  −2",14)
	minimap=preload("res://iso/zarya/minimap.gd").new(); minimap.world=world; minimap.custom_minimum_size=Vector2(184,98); map_stack.add_child(minimap)
	var bottom:=HBoxContainer.new(); bottom.position=Vector2(418,752); bottom.add_theme_constant_override("separation",7); root.add_child(bottom); bottom.name="Belt"
	var index:=1
	for entry in [["left","ЛЕВАЯ РУКА"],["right","ПРАВАЯ РУКА"],["quick0","ЛЕЧЕНИЕ"],["quick1","БЫСТРЫЙ ДОСТУП"],["quick2","БЫСТРЫЙ ДОСТУП"],["quick3","УТИЛИТЫ"]]:
		var col:=VBoxContainer.new(); col.add_theme_constant_override("separation",3); bottom.add_child(col)
		var heading:=label(col,entry[1],11); heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var cell:=make_slot(col,entry[0]); cell.custom_minimum_size=Vector2(110,104)
		var key_label:=label(col,str(index),12); key_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; index+=1
	var check:=icon_button(root,"ammo","Проверить магазин",world.player.check_ammo); check.name="Check"
	for side in [0,1]:
		var stick:=preload("res://iso/zarya/stick.gd").new(); stick.set_meta("side",side); root.add_child(stick)
		place(stick,Rect2(55 if side==0 else 1285,510,245,245))
		stick.name="MoveStick" if side==0 else "AimStick"
	var interact:=icon_button(root,"hand","Взаимодействовать",func(): world.interact()); interact.name="Interact"
	var gun_panel:=panel(root,Vector2(1150,816),Vector2(379,72)); gun_panel.name="Weapon"
	var gun_row:=HBoxContainer.new(); gun_panel.add_child(gun_row)
	weapon_status=label(gun_row,"",14); weapon_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	icon_button(gun_row,"reload","Перезарядить",world.player.reload)
	var utility:=HBoxContainer.new(); utility.position=Vector2(26,820); utility.add_theme_constant_override("separation",7); root.add_child(utility); utility.name="Utilities"
	icon_button(utility,"flashlight","Фонарь",func(): world.state.data["flash_on"]=not world.state.data.get("flash_on",false))
	icon_button(utility,"minus","Отдалить камеру",func(): world.get_node("Camera").desired_size=minf(24,world.get_node("Camera").desired_size+1))
	icon_button(utility,"plus","Приблизить камеру",func(): world.get_node("Camera").desired_size=maxf(10,world.get_node("Camera").desired_size-1))
	notice=label(root,"",18); notice.name="Notice"; place(notice,Rect2(560,116,700,64))
	world.state.changed.connect(func(): hud_body.queue_redraw())
	world.state.changed.connect(refresh_slots)
	refresh_slots()
	call_deferred("_fit_canvas")
func icon_for(id: String) -> Texture2D:
	if icon_cache.has(id): return icon_cache[id]
	var custom_path: String="res://assets/ui/zarya/"+id+".svg"
	if ResourceLoader.exists(custom_path):
		icon_cache[id]=load(custom_path)
		return icon_cache[id]
	var texture: Texture2D
	if id=="pistol":
		var atlas:=AtlasTexture.new(); atlas.atlas=Icons.ATLAS; atlas.region=Rect2(81,165,470,359); texture=atlas
	else: texture=Icons.get_icon(id)
	if texture!=null:
		icon_cache[id]=texture
		return texture
	var path: String="res://assets/icons/"+str(State.ITEMS.get(id,{}).get("icon","gear"))+".svg"
	var result:=load(path) as Texture2D if ResourceLoader.exists(path) else null
	icon_cache[id]=result
	return result
func make_slot(parent: Node, key: String) -> Button:
	var cell:=preload("res://iso/zarya/slot.gd").new()
	cell.ui=self; cell.key=key; cell.custom_minimum_size=Vector2(90,78)
	cell.add_theme_stylebox_override("normal",surface_style()); cell.expand_icon=true
	cell.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cell.vertical_icon_alignment=VERTICAL_ALIGNMENT_CENTER
	cell.add_theme_constant_override("icon_max_width",76)
	cell.pressed.connect(func(): selected=key; refresh_slots(); update_details())
	parent.add_child(cell); slots.append(cell)
	return cell
func refresh_slots() -> void:
	var kept: Array=[]
	for cell in slots:
		if not is_instance_valid(cell): continue
		kept.append(cell)
		var item: Dictionary=world.state.data.slots.get(cell.key,{})
		cell.icon=icon_for(item.get("id","")) if not item.is_empty() else null
		cell.text=""
		cell.queue_redraw()
		cell.tooltip_text=State.ITEMS.get(item.get("id",""),{}).get("name","Пусто")
	slots=kept
func _process(delta: float) -> void:
	if modal==null:
		world.player.move_vector=root.get_node("MoveStick").get_move_vector()
		world.player.aim_vector=root.get_node("AimStick").get_move_vector()
		world.player.fire=world.player.aim_vector.length()>0.8
	else:
		world.player.move_vector=Vector2.ZERO; world.player.aim_vector=Vector2.ZERO; world.player.fire=false
	refresh_clock+=delta
	if refresh_clock>0.15:
		refresh_clock=0
		objective.text="◯  "+world.objective()
		for key in bars: bars[key].value=world.state.data[key]
		if last_map_position.distance_squared_to(world.player.position)>0.04 or last_map_count!=world.state.data.visited.size():
			minimap.queue_redraw(); last_map_position=world.player.position; last_map_count=world.state.data.visited.size()
		var description: String="?"
		if world.state.data.checked: description="почти полный" if world.state.data.mag>=6 else ("меньше половины" if world.state.data.mag>0 else "пуст")
		weapon_status.text=("ОРУЖИЕ НЕ В РУКАХ" if world.state.weapon().is_empty() else "ПМ / МАГАЗИН: "+description)+"\nЗАПАС: "+str(world.state.amount("ammo"))+" × 9×18"
		if float(world.state.data.health)<=0 and not dead_shown:
			dead_shown=true
			var column:=window("V-17 / ЖИЗНЕННЫЕ ПОКАЗАТЕЛИ УТРАЧЕНЫ")
			button(column,"НАЧАТЬ УРОВЕНЬ ЗАНОВО",restart_level,400)
	if timer>0:
		timer-=delta; notice.modulate.a=minf(1,timer)
func notify(text: String) -> void:
	if text.is_empty(): return
	notice.text=text; timer=7; notice.modulate.a=1
func close_modal() -> void:
	if is_instance_valid(shade): shade.queue_free()
	if is_instance_valid(modal): modal.queue_free()
	for child in root.get_children():
		if child!=modal and child!=shade: child.show()
	modal=null; world.paused=false
	world.player.move_vector=Vector2.ZERO; world.player.aim_vector=Vector2.ZERO; world.player.fire=false
	world.save_state()
func window(title: String) -> VBoxContainer:
	close_modal()
	for child in root.get_children():
		if child!=modal: child.hide()
	shade=ColorRect.new(); shade.color=Color(0.005,0.01,0.015,0.65); shade.size=canvas_size; root.add_child(shade)
	modal=PanelContainer.new(); modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.position=Vector2(24,36); modal.size=canvas_size-Vector2(48,72)
	modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var surface:=style(); surface.bg_color=Color(0.025,0.035,0.04,0.97); surface.set_content_margin_all(24)
	modal.add_theme_stylebox_override("panel",surface); root.add_child(modal)
	world.paused=true
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",16); modal.add_child(column)
	var header:=HBoxContainer.new(); column.add_child(header)
	var text:=label(header,title,22); text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	icon_button(header,"close","Закрыть",close_modal)
	column.add_child(HSeparator.new())
	modal.modulate.a=0; create_tween().tween_property(modal,"modulate:a",1.0,0.18)
	call_deferred("_redraw_overlay")
	return column
func _redraw_overlay() -> void:
	# Rebuild draw commands once after replacing an overlay in the same frame.
	# Compatibility can otherwise retain stale commands from the retired window.
	if not is_instance_valid(modal): return
	modal.queue_redraw()
	for node in modal.find_children("*","Control",true,false): node.queue_redraw()
func bag(parent: Node) -> void:
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(580,440); parent.add_child(scroll)
	var sections:=VBoxContainer.new(); sections.add_theme_constant_override("separation",12); scroll.add_child(sections)
	for group in [["ЭКИПИРОВКА",["left","right","clothes","pocket0","pocket1"]],["БЫСТРЫЙ ДОСТУП",["quick0","quick1","quick2","quick3"]],["РЮКЗАК",[]]]:
		label(sections,group[0],12)
		var grid:=GridContainer.new(); grid.columns=6; grid.add_theme_constant_override("h_separation",6); grid.add_theme_constant_override("v_separation",6); sections.add_child(grid)
		var keys: Array=group[1]
		if group[0]=="РЮКЗАК":
			for i in range(18): keys.append("bag"+str(i))
		for key in keys:
			var cell:=make_slot(grid,key); cell.custom_minimum_size=Vector2(86,78)
	refresh_slots()
func update_details() -> void:
	if not is_instance_valid(detail_title): return
	var item: Dictionary=world.state.data.slots.get(selected,{})
	detail_title.text=State.ITEMS.get(item.get("id",""),{}).get("name","ВЫБЕРИТЕ ПРЕДМЕТ")
	detail_image.texture=icon_for(item.id) if not item.is_empty() else null
	for key in item_actions:
		if is_instance_valid(item_actions[key]):
			item_actions[key].disabled=item.is_empty() or (key=="use" and item.get("id","") not in ["food","water"]) or (key=="hand" and not State.ITEMS.get(item.get("id",""),{}).has("hands"))
	detail_description.text=("КОЛИЧЕСТВО  %s    /    СОСТОЯНИЕ  %s%%\n\nПеретащите предмет в ячейку или выберите действие." % [item.get("count",1),item.get("condition",100)]) if not item.is_empty() else "Снаряжение, карманы и быстрые слоты.\nВыберите предмет для осмотра."
func open_inventory() -> void:
	var column:=window("СНАРЯЖЕНИЕ / АЛЕКСЕЙ ВОЛКОВ")
	var tabs:=HBoxContainer.new(); tabs.add_theme_constant_override("separation",12); column.add_child(tabs)
	button(tabs,"ИНВЕНТАРЬ",open_inventory,180); button(tabs,"ОРГАНИЗМ",open_medical,180); button(tabs,"КПК",open_pda,180)
	var row:=HBoxContainer.new(); row.size_flags_vertical=Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation",24); column.add_child(row)
	var equipment:=VBoxContainer.new(); equipment.custom_minimum_size.x=234; row.add_child(equipment)
	label(equipment,"ЭКИПИРОВКА / V-17",13)
	var silhouette_area:=Control.new(); silhouette_area.custom_minimum_size=Vector2(230,270); equipment.add_child(silhouette_area)
	var silhouette=preload("res://iso/zarya/body.gd").new(); silhouette.ui=self; silhouette.scale=Vector2.ONE*0.64; silhouette.position.x=6; silhouette_area.add_child(silhouette)
	var hands:=HBoxContainer.new(); equipment.add_child(hands)
	for key in ["left","right"]:
		var cell:=make_slot(hands,key); cell.custom_minimum_size=Vector2(110,100)
	label(equipment,"ОДЕЖДА / КАРМАНЫ",12)
	var pockets:=HBoxContainer.new(); equipment.add_child(pockets)
	for key in ["clothes","pocket0","pocket1"]:
		var cell:=make_slot(pockets,key); cell.custom_minimum_size=Vector2(72,76)
	var center:=VBoxContainer.new(); center.size_flags_horizontal=Control.SIZE_EXPAND_FILL; center.custom_minimum_size.x=552; center.add_theme_constant_override("separation",14); row.add_child(center)
	label(center,"РЮКЗАК / 18 ЯЧЕЕК",14)
	var grid:=GridContainer.new(); grid.columns=6; grid.add_theme_constant_override("h_separation",6); grid.add_theme_constant_override("v_separation",6); center.add_child(grid)
	for i in range(18):
		var cell:=make_slot(grid,"bag"+str(i)); cell.custom_minimum_size=Vector2(86,94)
	label(center,"БЫСТРЫЙ ДОСТУП",13)
	var quick:=HBoxContainer.new(); quick.add_theme_constant_override("separation",6); center.add_child(quick)
	for key in ["quick0","quick1","quick2","quick3"]: make_slot(quick,key)
	var side:=VBoxContainer.new(); side.custom_minimum_size.x=360; side.size_flags_horizontal=Control.SIZE_EXPAND_FILL; side.add_theme_constant_override("separation",16); row.add_child(side)
	detail_title=label(side,"",24)
	detail_image=TextureRect.new(); detail_image.custom_minimum_size=Vector2(330,210); detail_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; detail_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; side.add_child(detail_image)
	detail_description=label(side,"",16)
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",12); side.add_child(actions)
	item_actions["hand"]=icon_button(actions,"hand","Взять в свободную руку",func(): world.state.equip(selected); refresh_slots(); update_details())
	item_actions["use"]=icon_button(actions,"use","Использовать паёк или воду",consume)
	icon_button(actions,"medical","Открыть лечение",open_medical)
	item_actions["trash"]=icon_button(actions,"trash","Выложить предмет на пол",drop_selected)
	label(side,"Взять · Использовать · Лечение · Выложить",12)
	refresh_slots(); update_details()
func consume() -> void:
	var entry: Dictionary=world.state.data.slots.get(selected,{})
	if entry.is_empty(): return
	if entry.id in ["food","water"]:
		world.state.take(entry.id)
		world.state.data[entry.id]=minf(100,float(world.state.data[entry.id])+30)
		refresh_slots(); update_details()
func drop_selected() -> void:
	var entry: Dictionary=world.state.data.slots.get(selected,{})
	if entry.is_empty(): return
	var id: String="drop"+str(world.state.data.drops.size())
	world.state.data.drops.append({"id":id,"item":entry.duplicate(),"position":[world.player.position.x,world.player.position.y,world.player.position.z]})
	world.state.data.slots.erase(selected)
	world.create_drop(world.state.data.drops.back())
	refresh_slots(); update_details()
func open_loot(action: Dictionary) -> void:
	var column:=window("ОБЫСК / "+str(action.title))
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",28); column.add_child(row)
	var left:=VBoxContainer.new(); row.add_child(left); label(left,"ИНВЕНТАРЬ ВОЛКОВА",18); bag(left)
	var right:=VBoxContainer.new(); right.custom_minimum_size.x=420; row.add_child(right)
	label(right,action.title,22)
	label(right,"СОДЕРЖИМОЕ ОБЪЕКТА / ПЕРЕНОС В РЮКЗАК",12)
	right.add_theme_constant_override("separation",12)
	var list: Array=world.state.data.containers.get(action.id,[])
	if list.is_empty(): label(right,"ПУСТО / ПРЕДМЕТЫ УЖЕ ЗАБРАНЫ",16)
	for i in range(list.size()):
		var item: Dictionary=list[i]
		var b:=button(right,State.ITEMS[item.id].name+"   × "+str(item.count)+"\nСОСТОЯНИЕ "+str(item.get("condition",100))+"%",func(): transfer(action,i),380)
		b.icon=icon_for(item.id); b.expand_icon=true; b.add_theme_constant_override("icon_max_width",64); b.custom_minimum_size.y=82
	button(right,"ВЗЯТЬ ВСЁ",func():
		while not world.state.data.containers[action.id].is_empty():
			if not world.state.loot(action.id,0): break
		loot_flags(); open_loot(action),380)
func transfer(action: Dictionary, index: int) -> void:
	world.state.loot(action.id,index)
	loot_flags()
	open_loot(action)
func loot_flags() -> void:
	if world.state.amount("pistol")>0:
		world.state.mark("armed")
		world.player.rig.perform("pickup")
	if world.state.amount("card")>0: world.state.mark("card")
	world.save_state()
func open_terminal(action: Dictionary) -> void:
	var column:=window("ЗАРЯ / ЛОКАЛЬНЫЙ УЗЕЛ / "+str(action.title))
	label(column,"ОПЕРАТОР V-17   •   УРОВЕНЬ −2   •   СЕТЬ ИЗОЛИРОВАНА",14)
	var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://iso/bunker_records.json"))
	var record: Dictionary=records.get(action.record,{"title":"СЛУЖЕБНАЯ ЗАПИСЬ / СЕРОВ","body":"Резервный предохранитель оставлен в серверной. Карту заберите с моего рабочего места. После восстановления питания проверьте карантинную блокировку. Верхний уровень не отвечает."})
	record=record.duplicate(true)
	if not str(action.get("custom_text","")).is_empty(): record={"title":action.title,"body":action.custom_text}
	if action.id in ["power","generator","pump"]:
		record.body="Предохранитель установлен. Резервная цепь научно-технического уровня −2 готова к работе.\nПроверьте карантинную блокировку перед доступом к вертикальному узлу."
	if action.id=="archive": record.body=str(record.body)+"\n\nСИСТЕМА: грузовой шлюз требует подтверждения с верхнего уровня. Следуйте к лестничному узлу −1."
	label(column,record.title,22)
	var text:=RichTextLabel.new(); text.custom_minimum_size=Vector2(1050,350); text.text=str(record.body).replace("\\n","\n"); column.add_child(text)
	button(column,"ЗАГРУЗИТЬ ЗАПИСЬ / ВЫПОЛНИТЬ ДЕЙСТВИЕ",func():
		if world.activate(action.id):
			world.state.data.records[action.id]=record
			notify("ДАННЫЕ СОХРАНЕНЫ В КПК")
			world.save_state(),480)
func open_medical() -> void:
	var column:=window("МЕДИЦИНСКИЙ МОНИТОРИНГ / V-17")
	var row:=HBoxContainer.new(); column.add_child(row)
	var body:=preload("res://iso/zarya/body.gd").new(); body.ui=self; body.custom_minimum_size=Vector2(340,410); row.add_child(body)
	var side:=VBoxContainer.new(); side.custom_minimum_size.x=650; row.add_child(side)
	label(side,"Выберите область на схеме",18)
	for zone in State.ZONES:
		var wound: Dictionary=world.state.data.wounds[zone]
		button(side,zone+" / повреждение %d · кровотечение %.2f" % [int(wound.damage),float(wound.bleeding)],func(): selected_zone=zone; notify("ВЫБРАНО: "+zone),550)
	var actions:=HBoxContainer.new(); column.add_child(actions)
	for entry in [["band","ПЕРЕВЯЗАТЬ"],["medkit","ОБРАБОТАТЬ"],["morph","ОБЕЗБОЛИТЬ"]]:
		button(actions,entry[1],func():
			if world.state.treat(selected_zone,entry[0]): world.player.rig.perform("treat"); open_medical()
			else: notify("НЕТ ПРЕПАРАТА ИЛИ ПОКАЗАНИЙ К ПРИМЕНЕНИЮ"),220)
func open_pda() -> void:
	var column:=window("КПК  /  ЛИЧНЫЙ АРХИВ V-17")
	label(column,"ЛОКАЛЬНАЯ ПАМЯТЬ   •   ОБЪЕКТ «ЗАРЯ»   •   СВЯЗЬ ОТСУТСТВУЕТ",13)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",28); column.add_child(row)
	var navigation:=VBoxContainer.new(); navigation.custom_minimum_size.x=330; row.add_child(navigation)
	label(navigation,"ЖУРНАЛ / ЗАПИСИ",13)
	var reader:=VBoxContainer.new(); reader.custom_minimum_size.x=780; row.add_child(reader)
	var heading:=label(reader,"ТЕКУЩАЯ ЗАДАЧА",24)
	var text:=RichTextLabel.new(); text.custom_minimum_size=Vector2(780,420); text.add_theme_font_size_override("normal_font_size",20); text.text=world.objective(); reader.add_child(text)
	button(navigation,"ТЕКУЩАЯ ЗАДАЧА",func(): heading.text="ТЕКУЩАЯ ЗАДАЧА"; text.text=world.objective(),320)
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(330,350); navigation.add_child(scroll)
	var entries:=VBoxContainer.new(); scroll.add_child(entries)
	for record in world.state.data.records.values():
		button(entries,str(record.title),func(): heading.text=str(record.title); text.text=str(record.body).replace("\\n","\n"),315)
	if world.state.data.records.is_empty(): label(entries,"Нет загруженных записей",15)
func pause_menu() -> void:
	var column:=window("ПАУЗА / ОБЪЕКТ «ЗАРЯ»")
	button(column,"ПРОДОЛЖИТЬ",close_modal,400)
	button(column,"СОХРАНИТЬ",func(): world.save_state(); notify("СОХРАНЕНО"),400)
	button(column,"В ГЛАВНОЕ МЕНЮ",func():
		var mains=get_tree().get_nodes_in_group("main_root")
		if not mains.is_empty(): mains[0].to_main_menu(),400)
func prologue() -> void:
	var column:=window("СЕВЕРНЫЙ АНКЛАВ / АЛЕКСЕЙ ВОЛКОВ")
	label(column,"Последнее, что вы помните, — холод.\n\nТеперь кто-то называет вас пациентом V-17. За стеклом работает незнакомое оборудование. Голос системы произносит вашу фамилию.\n\nВы — Алексей Волков. Вы не знаете, сколько времени прошло.",24)
	button(column,"ОТКРЫТЬ ГЛАЗА",func(): close_modal(); world.player.awaken(),400)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_TAB: open_inventory()
		if event.keycode==KEY_M: open_pda()
		if event.keycode==KEY_ESCAPE: close_modal() if modal!=null else pause_menu()

func restart_level() -> void:
	var game=get_node("/root/G")
	game.zsave.erase(world.state_key)
	game.zsave["iso_layer"]="bunker"
	var mains=get_tree().get_nodes_in_group("main_root")
	if not mains.is_empty(): mains[0]._enter_iso_world()
	else: get_tree().reload_current_scene()
