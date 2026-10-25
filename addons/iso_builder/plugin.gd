@tool
extends EditorPlugin

const RoomScript = preload("res://iso/room.gd")
const PropScript = preload("res://iso/prop.gd")
const SectorScript = preload("res://iso/sector.gd")
const RoadScript = preload("res://iso/road.gd")
const BuildingScript = preload("res://iso/city_building.gd")
const RegionGenerator = preload("res://iso/region_generator.gd")

var dock: VBoxContainer
var dock_scroller: ScrollContainer
var width_spin: SpinBox
var depth_spin: SpinBox
var prop_choice: OptionButton
var note: Label
var x_spin: SpinBox
var z_spin: SpinBox
var road_width_spin: SpinBox
var road_direction: OptionButton
var building_style: OptionButton

func _enter_tree() -> void:
	dock_scroller = ScrollContainer.new()
	dock_scroller.name = "Анклав 3D"
	dock_scroller.custom_minimum_size = Vector2(320, 0)
	dock = VBoxContainer.new()
	dock.custom_minimum_size = Vector2(320, 0)
	dock_scroller.add_child(dock)
	var title := Label.new()
	title.text = "КОНСТРУКТОР ЛОКАЦИИ"
	dock.add_child(title)
	var atlas_button := Button.new()
	atlas_button.text = "Открыть атлас региона"
	atlas_button.pressed.connect(func(): get_editor_interface().open_scene_from_path("res://iso/atlas/world_atlas.tscn"))
	dock.add_child(atlas_button)
	var city_button := Button.new()
	city_button.text = "Открыть центр Северограда"
	city_button.pressed.connect(func(): get_editor_interface().open_scene_from_path("res://iso/sectors/sector_160_105.tscn"))
	dock.add_child(city_button)
	var sector_label := Label.new()
	sector_label.text = "Выберите участок на карте (64 × 64 м)"
	dock.add_child(sector_label)
	var overview := TextureRect.new()
	overview.texture = preload("res://assets/world/world_concept_reference.jpg")
	overview.custom_minimum_size = Vector2(320, 240)
	overview.stretch_mode = TextureRect.STRETCH_SCALE
	overview.mouse_filter = Control.MOUSE_FILTER_STOP
	overview.gui_input.connect(_overview_input.bind(overview))
	dock.add_child(overview)
	x_spin = _sector_spin("Координата X")
	z_spin = _sector_spin("Координата Z")
	var sector_button := Button.new()
	sector_button.text = "Открыть / создать выбранный участок"
	sector_button.pressed.connect(_create_sector)
	dock.add_child(sector_button)
	width_spin = _spin("Ширина комнаты, м", 8)
	depth_spin = _spin("Глубина комнаты, м", 6)
	var room_button := Button.new()
	room_button.text = "Создать комнату"
	room_button.pressed.connect(_add_room)
	dock.add_child(room_button)
	var building_label := Label.new()
	building_label.text = "Городское здание"
	dock.add_child(building_label)
	building_style = OptionButton.new()
	for label in ["Жилой дом", "Магазин", "Мастерская", "Многоквартирный дом"]:
		building_style.add_item(label)
	dock.add_child(building_style)
	var building_button := Button.new()
	building_button.text = "Разместить здание"
	building_button.pressed.connect(_add_building)
	dock.add_child(building_button)
	road_direction = OptionButton.new()
	road_direction.add_item("Дорога восток — запад")
	road_direction.add_item("Дорога север — юг")
	dock.add_child(road_direction)
	road_width_spin = _spin("Ширина дороги, м", 10)
	var road_button := Button.new()
	road_button.text = "Разместить дорогу"
	road_button.pressed.connect(_add_road)
	dock.add_child(road_button)
	var caption := Label.new()
	caption.text = "Объект"
	dock.add_child(caption)
	prop_choice = OptionButton.new()
	for label in ["Стол", "Шкаф", "Медицинская койка", "Терминал", "Своя GLB/GLTF модель"]:
		prop_choice.add_item(label)
	dock.add_child(prop_choice)
	var prop_button := Button.new()
	prop_button.text = "Разместить объект"
	prop_button.pressed.connect(_add_prop)
	dock.add_child(prop_button)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Выберите созданный узел. Размеры, проёмы, модель, масштаб и поворот меняются в Инспекторе. Перемещайте узлы в 3D-виде и сохраняйте сцену Ctrl+S."
	dock.add_child(note)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_scroller)

func _exit_tree() -> void:
	remove_control_from_docks(dock_scroller)
	dock_scroller.queue_free()

func _spin(label_text: String, initial: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	dock.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 2
	spin.max_value = 30
	spin.step = 1
	spin.value = initial
	dock.add_child(spin)
	return spin

func _sector_spin(label_text: String) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	dock.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = -1024
	spin.max_value = 1024
	spin.step = 1
	dock.add_child(spin)
	return spin

func _overview_input(event: InputEvent, overview: TextureRect) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		x_spin.value = clampi(floori(event.position.x / overview.size.x * RegionGenerator.MAX_X), 0, RegionGenerator.MAX_X - 1)
		z_spin.value = clampi(floori(event.position.y / overview.size.y * RegionGenerator.MAX_Z), 0, RegionGenerator.MAX_Z - 1)
		note.text = "Участок (%d, %d). Нажмите кнопку ниже, чтобы открыть его для правки." % [int(x_spin.value), int(z_spin.value)]

func _create_sector() -> void:
	var x := int(x_spin.value)
	var z := int(z_spin.value)
	var sector_path := "res://iso/sectors/sector_%d_%d.tscn" % [x, z]
	if ResourceLoader.exists(sector_path):
		get_editor_interface().open_scene_from_path(sector_path)
		note.text = "Открыт сохранённый участок: " + sector_path
		return
	var root: Node3D = RegionGenerator.new().make_sector(Vector2i(x, z))
	if root == null:
		note.text = "Координаты вне региона. Выберите участок на карте."
		return
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		root.free()
		note.text = "Не удалось создать сектор."
		return
	root.free()
	if ResourceSaver.save(scene, sector_path) != OK:
		note.text = "Не удалось сохранить сектор."
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().open_scene_from_path(sector_path)
	note.text = "Сектор сгенерирован. Исправьте дома, дороги и объекты, затем Ctrl+S."

func _scene_root() -> Node3D:
	var root := get_editor_interface().get_edited_scene_root()
	if root is Node3D: return root
	push_warning("Откройте 3D-сцену с корневым Node3D, например iso/demo_world.tscn")
	return null

func _selected_position(root: Node3D) -> Vector3:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() > 0 and selected[0] is Node3D:
		var pivot: Node3D = selected[0]
		if pivot.get_script() == RoomScript:
			return pivot.global_position + Vector3(pivot.width, 0, 0)
		return pivot.global_position + Vector3(1, 0, 1)
	return root.global_position

func _add_room() -> void:
	var root := _scene_root()
	if root == null: return
	var node := Node3D.new()
	node.name = "Room"
	node.set_script(RoomScript)
	node.set("width", int(width_spin.value))
	node.set("depth", int(depth_spin.value))
	var at := _selected_position(root)
	root.add_child(node)
	node.owner = root
	node.global_position = at
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	note.text = "Комната добавлена. Настройте проёмы и материал в Инспекторе, затем Ctrl+S."

func _add_prop() -> void:
	var root := _scene_root()
	if root == null: return
	var node := Node3D.new()
	node.name = "Prop"
	node.set_script(PropScript)
	node.set("kind", prop_choice.selected)
	var at := _selected_position(root)
	root.add_child(node)
	node.owner = root
	node.global_position = at
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	note.text = "Объект добавлен. Для GLB установите Model в Инспекторе и при необходимости измените Model Scale и Collision Size."

func _add_building() -> void:
	var root := _scene_root()
	if root == null: return
	var at := _selected_position(root)
	var node := Node3D.new()
	node.name = "CityBuilding"
	node.set_script(BuildingScript)
	node.set("style", building_style.selected)
	root.add_child(node)
	node.owner = root
	node.global_position = at
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	note.text = "Здание добавлено. Размер, этажи и тип фасада меняются в Инспекторе."

func _add_road() -> void:
	var root := _scene_root()
	if root == null: return
	var at := _selected_position(root)
	var node := Node3D.new()
	node.name = "Road"
	node.set_script(RoadScript)
	node.set("direction", road_direction.selected)
	node.set("width", road_width_spin.value)
	root.add_child(node)
	node.owner = root
	node.global_position = at
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	note.text = "Дорога добавлена. Выставьте Length, Width и положение в Инспекторе; соседние сегменты стыкуются по границе сектора."
