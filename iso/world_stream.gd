extends Node3D

const SIDE := 64.0
const ACTIVE_RADIUS := 1
const SECTOR_DIR := "res://iso/sectors/"
const RoomScript = preload("res://iso/room.gd")
const BuildingScript = preload("res://iso/city_building.gd")
const RegionGenerator = preload("res://iso/region_generator.gd")
@export_enum("Bunker", "City") var lighting_profile := 0
@export var generate_region := true
@export_enum("Surface", "Underground") var world_layer := 0

@onready var player: Node3D = $Volkov
@onready var sectors_root: Node3D = $Sectors
var loaded: Dictionary = {}
var last_center := Vector2i(999999, 999999)
var generator: RefCounted

func _ready() -> void:
	_setup_environment()
	if generate_region: generator = RegionGenerator.new()
	$TouchControls.visible = DisplayServer.is_touchscreen_available()
	_update_sectors()

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#303c40") if lighting_profile == 1 else Color("#10191c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#91a2a6") if lighting_profile == 1 else Color("#8fa8b2")
	environment.ambient_light_energy = 0.50 if lighting_profile == 1 else 0.23
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world_environment.environment = environment
	add_child(world_environment)

func _process(_delta: float) -> void:
	var center := _sector_at(player.global_position)
	if center != last_center: _update_sectors()
	for room in get_tree().get_nodes_in_group("iso_rooms"):
		if room.get_script() == RoomScript:
			room.set_roof_visible(lighting_profile != 0 and not room.contains_world_point(player.global_position))
			room.set_front_transparency(0.82 if world_layer == 1 or room.contains_world_point(player.global_position) else 0.0)
	for building in get_tree().get_nodes_in_group("iso_buildings"):
		if building.get_script() == BuildingScript:
			building.set_occluders_visible(not building.contains_world_point(player.global_position))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var mains := get_tree().get_nodes_in_group("main_root")
		if not mains.is_empty() and mains[0].has_method("to_main_menu"):
			mains[0].to_main_menu()
		else:
			get_tree().change_scene_to_file("res://iso/atlas/world_atlas.tscn")

func _sector_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / SIDE), floori(point.z / SIDE))

func _update_sectors() -> void:
	var center := _sector_at(player.global_position)
	last_center = center
	var wanted := {}
	for z in range(center.y - ACTIVE_RADIUS, center.y + ACTIVE_RADIUS + 1):
		for x in range(center.x - ACTIVE_RADIUS, center.x + ACTIVE_RADIUS + 1):
			var key := Vector2i(x, z)
			wanted[key] = true
			if loaded.has(key): continue
			var sector_path := SECTOR_DIR + "sector_%d_%d.tscn" % [x, z]
			var node: Node3D
			if world_layer == 0 and key == Vector2i(55, 45):
				if generator != null: node = generator.make_sector(key)
			elif ResourceLoader.exists(sector_path):
				var scene := load(sector_path) as PackedScene
				if scene != null: node = scene.instantiate() as Node3D
			elif generator != null:
				node = generator.make_sector(key)
			if node == null: continue
			sectors_root.add_child(node)
			node.position = Vector3(x * SIDE, 0, z * SIDE)
			loaded[key] = node
	for key in loaded.keys():
		if wanted.has(key): continue
		loaded[key].queue_free()
		loaded.erase(key)
