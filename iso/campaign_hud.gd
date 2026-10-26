extends CanvasLayer

const STORY := [
 {
  "id": "terminal",
  "title": "Осмотреть терминал персонала",
  "record": "terminal",
  "message": "Данные добавлены в КПК."
 },
 {
  "id": "door",
  "title": "Открыть служебную дверь",
  "record": "",
  "message": "Служебный доступ восстановлен."
 },
 {
  "id": "gear",
  "title": "Забрать оружие и КПК на посту охраны",
  "record": "cameras",
  "message": "Получены пистолет, КПК и медицинские принадлежности."
 },
 {
  "id": "video",
  "title": "Просмотреть запись эксперимента №12",
  "record": "journal_a",
  "message": "Данные добавлены в КПК."
 },
 {
  "id": "journal",
  "title": "Найти журнал №12",
  "record": "journal_b",
  "message": "Данные добавлены в КПК."
 },
 {
  "id": "fuse",
  "title": "Найти резервный предохранитель",
  "record": "",
  "message": "Предохранитель получен."
 },
 {
  "id": "generator",
  "title": "Восстановить цепь питания",
  "record": "power_note",
  "message": "Данные добавлены в КПК."
 },
 {
  "id": "lower",
  "title": "Пройти в нижний технический сектор",
  "record": "",
  "message": "Нижний технический сектор. Сигнал персонала отсутствует."
 },
 {
  "id": "isolation",
  "title": "Снять блокировку карантинного перехода",
  "record": "isolation_note",
  "message": "Данные добавлены в КПК."
 },
 {
  "id": "archive",
  "title": "Изучить архив наблюдения",
  "record": "archive",
  "message": "Данные добавлены в КПК."
 },
 {
  "id": "pump",
  "title": "Запустить насос шлюза",
  "record": "",
  "message": "Насос запущен."
 },
 {
  "id": "drive",
  "title": "Разблокировать привод шлюза",
  "record": "",
  "message": "Привод освобождён."
 },
 {
  "id": "hold",
  "title": "Подать питание на внешний шлюз",
  "record": "",
  "message": "Питание подано. Шлюз открывается."
 },
 {
  "id": "exit",
  "title": "Покинуть бункер",
  "record": "",
  "message": "Волков покидает комплекс."
 }
]

var game
var world: Node3D
var objective_label: Label
var prompt_label: Label
var message_label: Label
var inventory_panel: PanelContainer
var inventory_label: Label
var map_panel: PanelContainer
var map_position: Label
var vitals_label: Label
var area_label: Label
var action_busy := false
var _nearest: Node3D
var _save_clock := 0.0
var _message_clock := 0.0

func _ready() -> void:
	game = get_node("/root/G")
	world = get_parent() as Node3D
	if not game.zsave.get("bunker_story_v2",false):
		var old := int(game.zsave.get("iso_objective",0))
		game.zsave["iso_objective"] = [0,1,2,4,5,7,14][clampi(old,0,6)]
		game.zsave["bunker_story_v2"] = true
		if old >= 3: game.zsave["iso_armed"] = true
	_build_ui()
	if not game.zsave.get("bunker_awake",false) and int(game.zsave.get("iso_objective",0)) == 0:
		call_deferred("_wake")
	_update_ui()

func _panel_color() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.055, 0.88)
	style.border_color = Color(0.33, 0.47, 0.50, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	return style

func _label(parent: Node, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(18, 22)
	top.custom_minimum_size = Vector2(350, 86)
	top.add_theme_stylebox_override("panel", _panel_color())
	root.add_child(top)
	var top_column := VBoxContainer.new()
	top.add_child(top_column)
	_label(top_column, "ОБЪЕКТ «ЗАРЯ» · ВОЛКОВ / V-17", 14, Color("#9db5ba"))
	objective_label = _label(top_column, "", 20, Color("#e0e3da"))
	var status := PanelContainer.new()
	status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -294
	status.offset_top = 22
	status.offset_right = -18
	status.offset_bottom = 108
	status.add_theme_stylebox_override("panel", _panel_color())
	root.add_child(status)
	var status_column := VBoxContainer.new()
	status.add_child(status_column)
	area_label = _label(status_column, "", 14, Color("#8faeac"))
	vitals_label = _label(status_column, "", 18, Color("#e2e6dc"))
	prompt_label = _label(root, "", 17, Color("#e4d3ae"))
	prompt_label.position = Vector2(20, 120)
	prompt_label.custom_minimum_size = Vector2(480, 50)
	message_label = _label(root, "", 18, Color("#d9ded9"))
	message_label.position = Vector2(20, 172)
	message_label.custom_minimum_size = Vector2(570, 150)
	var controls := _label(root, "WASD — движение  ·  Shift — бег  ·  колесо — масштаб  ·  Esc — меню", 14, Color("#c8d3d2"))
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 20
	controls.offset_top = -42
	controls.offset_right = 740
	controls.offset_bottom = -12
	var quick_bar := HBoxContainer.new()
	quick_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quick_bar.offset_left = -520
	quick_bar.offset_top = -74
	quick_bar.offset_right = -18
	quick_bar.offset_bottom = -20
	quick_bar.add_theme_constant_override("separation", 6)
	root.add_child(quick_bar)
	_quick_button(quick_bar, "ВЗАИМОДЕЙСТВИЕ", _interact)
	_quick_button(quick_bar, "СНАРЯЖЕНИЕ", _toggle_inventory)
	_quick_button(quick_bar, "КПК", _toggle_map)
	var fire := Button.new()
	fire.text = "ОГОНЬ"
	fire.custom_minimum_size = Vector2(90,52)
	fire.add_theme_stylebox_override("normal",_panel_color())
	fire.button_down.connect(func(): world.get_node("Volkov").shooting = true)
	fire.button_up.connect(func(): world.get_node("Volkov").shooting = false)
	quick_bar.add_child(fire)
	inventory_panel = PanelContainer.new()
	inventory_panel.position = Vector2(18, 330)
	inventory_panel.custom_minimum_size = Vector2(410, 220)
	inventory_panel.add_theme_stylebox_override("panel", _panel_color())
	inventory_panel.visible = false
	root.add_child(inventory_panel)
	var inventory_column := VBoxContainer.new()
	inventory_panel.add_child(inventory_column)
	_label(inventory_column, "СОСТОЯНИЕ И РЮКЗАК", 19, Color("#e0e3da"))
	inventory_label = _label(inventory_column, "", 16, Color("#b8c9c8"))
	var archive_button := Button.new()
	archive_button.text = "ЗАПИСИ КПК"
	archive_button.pressed.connect(_open_archive)
	inventory_column.add_child(archive_button)
	var bandage := Button.new()
	bandage.text = "Использовать бинт"
	bandage.pressed.connect(_use_bandage)
	inventory_column.add_child(bandage)
	map_panel = PanelContainer.new()
	map_panel.set_anchors_preset(Control.PRESET_CENTER)
	map_panel.offset_left = -500
	map_panel.offset_top = -388
	map_panel.offset_right = 500
	map_panel.offset_bottom = 388
	map_panel.add_theme_stylebox_override("panel", _panel_color())
	map_panel.visible = false
	root.add_child(map_panel)
	var map_column := VBoxContainer.new()
	map_panel.add_child(map_column)
	map_position = _label(map_column, "", 16, Color("#e0e3da"))
	var atlas := TextureRect.new()
	atlas.texture = preload("res://assets/world/world_concept_reference.jpg")
	atlas.custom_minimum_size = Vector2(960, 720)
	atlas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	atlas.stretch_mode = TextureRect.STRETCH_SCALE
	map_column.add_child(atlas)

func _quick_button(parent: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(128, 52)
	button.add_theme_stylebox_override("normal",_panel_color())
	button.add_theme_color_override("font_color",Color("#b8d4d9"))
	button.pressed.connect(callback)
	parent.add_child(button)

func _toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible: map_panel.visible = false

func _toggle_map() -> void:
	map_panel.visible = not map_panel.visible
	if map_panel.visible: inventory_panel.visible = false

func _process(delta: float) -> void:
	_save_clock += delta
	if _save_clock > 8.0:
		_save_clock = 0.0
		_save()
	if _message_clock > 0.0:
		_message_clock -= delta
		if _message_clock <= 0.0: message_label.text = ""
	_find_nearest()
	_update_ui()

func _find_nearest() -> void:
	_nearest = null
	var player: Node3D = world.get_node("Volkov")
	var distance := 2.8
	for candidate in get_tree().get_nodes_in_group("iso_interactables"):
		if not candidate is Node3D: continue
		var object: Node3D = candidate
		var d := player.global_position.distance_to(object.global_position)
		if d < distance:
			_nearest = object
			distance = d

func _update_ui() -> void:
	var index := int(game.zsave.get("iso_objective", 0))
	objective_label.text = STORY[index]["title"] if index < STORY.size() else "Исследовать Северный регион"
	var underground := str(game.zsave.get("iso_layer", "bunker")) != "surface"
	area_label.text = "ПОДЗЕМНЫЙ УРОВЕНЬ · ЗАРЯ" if underground else "СЕВЕРНЫЙ РЕГИОН · ПОВЕРХНОСТЬ"
	vitals_label.text = "ЗДОРОВЬЕ %d%%    ПАТРОНЫ %d" % [int(game.zsave.get("iso_health", 100)), int(game.zsave.get("ammo", {}).get("pistol", 0))]
	var nearest_name := str(_nearest.get("display_name")) if _nearest != null else ""
	prompt_label.text = "E · " + nearest_name if not nearest_name.is_empty() else ""
	if inventory_panel.visible:
		var inv: Dictionary = game.zsave.get("inv", {})
		inventory_label.text = "Здоровье: %d / 100
Бинты: %d  ·  Жгуты: %d  ·  Морфин: %d
Патроны: %d  ·  Еда: %d" % [int(game.zsave.get("iso_health", 100)), int(inv.get("band", 0)), int(inv.get("tq", 0)), int(inv.get("morph", 0)), int(game.zsave.get("ammo", {}).get("pistol", 0)), int(inv.get("food", 0))]
	if map_panel.visible:
		var pos: Vector3 = world.get_node("Volkov").global_position
		map_position.text = "СЕВЕРНЫЙ РЕГИОН   ·   ВОЛКОВ: сектор %d, %d   ·   M — закрыть" % [floori(pos.x / 64.0), floori(pos.z / 64.0)]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_E: _interact()
		KEY_TAB: _toggle_inventory()
		KEY_M: _toggle_map()

func _interact() -> void:
	if _nearest == null or action_busy: return
	var id := str(_nearest.get("story_id"))
	var index := int(game.zsave.get("iso_objective", 0))
	if index >= STORY.size() or id != STORY[index]["id"]:
		_show_message("Здесь пока нет нужного следа. Цель: " + objective_label.text)
		return
	if id == "hold":
		action_busy = true
		_show_message("Удержание питания шлюза… 6 секунд")
		_spawn_threat(Vector3(18,0.95,23))
		_spawn_threat(Vector3(22,0.95,24))
		await get_tree().create_timer(6.0).timeout
		action_busy = false
	var entry: Dictionary = STORY[index]
	var rec := str(entry.get("record",""))
	if not rec.is_empty():
		var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://iso/bunker_records.json"))
		if records.has(rec):
			var archive: Dictionary = game.zsave.get("bunker_archive",{})
			archive[rec] = records[rec]
			game.zsave["bunker_archive"] = archive
			_show_message(str(records[rec]["title"])+"\n"+str(records[rec]["body"]))
	else: _show_message(entry["message"])
	game.zsave["iso_objective"] = index + 1
	if id == "gear":
		game.zsave["iso_armed"] = true
		_spawn_threat(Vector3(-7,0.95,8))
		var inv: Dictionary = game.zsave.get("inv", {})
		inv["band"] = int(inv.get("band", 0)) + 1
		game.zsave["inv"] = inv
	if id == "exit":
		game.zsave["sector"] = 1
		world.get_node("Volkov").global_position = Vector3(3620, 0.95, 2900)
		game.zsave["iso_layer"] = "surface"
	_save()
	if id == "exit":
		var mains := get_tree().get_nodes_in_group("main_root")
		if not mains.is_empty() and mains[0].has_method("enter_surface_world"):
			mains[0].enter_surface_world()

func _show_message(value: String) -> void:
	message_label.text = value
	_message_clock = 18.0

func _use_bandage() -> void:
	var inv: Dictionary = game.zsave.get("inv", {})
	if int(inv.get("band", 0)) <= 0: return
	inv["band"] = int(inv["band"]) - 1
	game.zsave["inv"] = inv
	game.zsave["iso_health"] = mini(100, int(game.zsave.get("iso_health", 100)) + 25)
	_save()

func _save() -> void:
	if not is_instance_valid(world) or not world.has_node("Volkov"): return
	game.zsave["iso_position"] = world.get_node("Volkov").global_position
	game.write_save()

func _exit_tree() -> void:
	_save()



func _wake() -> void:
	if game.get_meta("qa8",false): return
	var player = world.get_node("Volkov")
	var capsule = world.get_node("Sectors/Sector_55_45/Bunker/V17Capsule")
	player.set_physics_process(false)
	player.global_position = capsule.global_position + Vector3(0,1.0,0)
	var visual: Node3D = player.get_node("Visual")
	visual.rotation.z = PI/2
	_show_message("Нейросвязь восстановлена. Пациент V-17 проявляет признаки сознания.")
	await get_tree().create_timer(1.5).timeout
	var shell = capsule.get_node("Generated").find_child("Glass shell",false,false)
	if shell != null:
		var opening := create_tween()
		opening.tween_property(shell,"position:z",-1.2,1.2)
		await opening.finished
	var rise := create_tween().set_parallel(true)
	rise.tween_property(visual,"rotation:z",0.0,1.3)
	rise.tween_property(player,"global_position",capsule.global_position+Vector3(-0.2,0.95,1.35),1.3)
	await rise.finished
	player.set_physics_process(true)
	game.zsave["bunker_awake"] = true
	_save()
	_show_message("Волков… Это я? Что со мной сделали?")

func _spawn_threat(at: Vector3) -> void:
	var enemy := preload("res://iso/bunker_threat.gd").new()
	world.add_child(enemy)
	enemy.global_position = world.get_node("Sectors/Sector_55_45/Bunker").to_global(at)

func _open_archive() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -260
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override("panel",_panel_color())
	get_child(0).add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_label(column,"КПК / АРХИВ НАБЛЮДЕНИЯ",20,Color("#abcbd2"))
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(660,400)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry in game.zsave.get("bunker_archive",{}).values():
		text.text += str(entry["title"])+"\n\n"+str(entry["body"])+"\n\n────────\n\n"
	if text.text.is_empty(): text.text = "Нет загруженных записей."
	column.add_child(text)
	var close := Button.new()
	close.text = "ЗАКРЫТЬ АРХИВ"
	close.pressed.connect(panel.queue_free)
	column.add_child(close)
