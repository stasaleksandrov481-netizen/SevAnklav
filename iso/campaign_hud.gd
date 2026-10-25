extends CanvasLayer

const STORY := [
	{"id": "terminal", "title": "Осмотреть терминал персонала", "message": "Капсула V-17 отключилась во время аварии. Журнал персонала укажет, что произошло."},
	{"id": "door", "title": "Открыть служебную дверь", "message": "Доступ к восточному отсеку восстановлен."},
	{"id": "gear", "title": "Забрать КПК и снаряжение", "message": "На посту наблюдения остался КПК Волкова и небольшой запас медикаментов."},
	{"id": "journal", "title": "Найти журнал №12", "message": "Запись №12: эксперимент прервали после нарушения карантина."},
	{"id": "generator", "title": "Запустить резервное питание", "message": "Генератор ожил. Система выходного шлюза снова отвечает."},
	{"id": "exit", "title": "Покинуть бункер", "message": "Волков выходит на поверхность Северного региона."},
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
var _nearest: Node3D
var _save_clock := 0.0
var _message_clock := 0.0

func _ready() -> void:
	game = get_node("/root/G")
	world = get_parent() as Node3D
	_build_ui()
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
	top.position = Vector2(18, 58)
	top.custom_minimum_size = Vector2(430, 102)
	top.add_theme_stylebox_override("panel", _panel_color())
	root.add_child(top)
	var top_column := VBoxContainer.new()
	top.add_child(top_column)
	_label(top_column, "ОБЪЕКТ «ЗАРЯ» · ВОЛКОВ / V-17", 14, Color("#9db5ba"))
	objective_label = _label(top_column, "", 20, Color("#e0e3da"))
	var status := PanelContainer.new()
	status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -294
	status.offset_top = 58
	status.offset_right = -18
	status.offset_bottom = 158
	status.add_theme_stylebox_override("panel", _panel_color())
	root.add_child(status)
	var status_column := VBoxContainer.new()
	status.add_child(status_column)
	area_label = _label(status_column, "", 14, Color("#8faeac"))
	vitals_label = _label(status_column, "", 18, Color("#e2e6dc"))
	prompt_label = _label(root, "", 17, Color("#e4d3ae"))
	prompt_label.position = Vector2(20, 173)
	prompt_label.custom_minimum_size = Vector2(480, 50)
	message_label = _label(root, "", 18, Color("#d9ded9"))
	message_label.position = Vector2(20, 226)
	message_label.custom_minimum_size = Vector2(550, 94)
	var controls := _label(root, "WASD — движение  ·  Shift — бег  ·  колесо — масштаб  ·  Esc — меню", 14, Color("#c8d3d2"))
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 20
	controls.offset_top = -42
	controls.offset_right = 740
	controls.offset_bottom = -12
	var quick_bar := HBoxContainer.new()
	quick_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quick_bar.offset_left = -355
	quick_bar.offset_top = -74
	quick_bar.offset_right = -18
	quick_bar.offset_bottom = -20
	quick_bar.add_theme_constant_override("separation", 6)
	root.add_child(quick_bar)
	_quick_button(quick_bar, "Действие [E]", _interact)
	_quick_button(quick_bar, "Вещи [Tab]", _toggle_inventory)
	_quick_button(quick_bar, "Карта [M]", _toggle_map)
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
	button.custom_minimum_size = Vector2(105, 42)
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
	if _nearest == null: return
	var id := str(_nearest.get("story_id"))
	var index := int(game.zsave.get("iso_objective", 0))
	if index >= STORY.size() or id != STORY[index]["id"]:
		_show_message("Здесь пока нет нужного следа. Цель: " + objective_label.text)
		return
	_show_message(STORY[index]["message"])
	game.zsave["iso_objective"] = index + 1
	if id == "gear":
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
	_message_clock = 9.0

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


