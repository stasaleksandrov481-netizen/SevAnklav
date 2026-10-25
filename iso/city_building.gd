@tool
extends Node3D
class_name IsoCityBuilding

@export_enum("House", "Shop", "Workshop", "Apartment") var style := 0:
	set(value):
		style = value
		_refresh()
@export_range(6.0, 24.0, 1.0) var width := 12.0:
	set(value):
		width = value
		_refresh()
@export_range(6.0, 24.0, 1.0) var depth := 10.0:
	set(value):
		depth = value
		_refresh()
@export_range(1, 4, 1) var floors := 2:
	set(value):
		floors = value
		_refresh()
@export var entrance := true:
	set(value):
		entrance = value
		_refresh()

var _occluders: Node3D

func _ready() -> void:
	add_to_group("iso_buildings")
	_rebuild()

func _refresh() -> void:
	if is_inside_tree(): call_deferred("_rebuild")

func _mat(color: Color, metallic := 0.0, facade_texture := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.78
	if facade_texture:
		material.albedo_texture = load("res://assets/iso/facade_panels.png") as Texture2D
		material.uv1_scale = Vector3(3.0, 2.0, 1.0)
	return material

func _box(generated: Node3D, visual_parent: Node3D, label: String, box_size: Vector3, at: Vector3, material: Material, solid := false, angle := 0.0) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = box_size
	visual.mesh = mesh
	visual.position = at
	visual.rotation.x = angle
	visual.material_override = material
	visual_parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		generated.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)

func _window(generated: Node3D, visual_parent: Node3D, x: float, y: float, z: float, side := false) -> void:
	var glass := _mat(Color("#2c4852"), 0.35)
	var frame := _mat(Color("#c4c5bd"), 0.25)
	var glass_size := Vector3(0.05, 1.0, 1.35) if side else Vector3(1.35, 1.0, 0.05)
	_box(generated, visual_parent, "WindowGlass", glass_size, Vector3(x, y, z), glass)
	for a in [-0.72, 0.72]:
		var at := Vector3(x, y, z + a) if side else Vector3(x + a, y, z)
		_box(generated, visual_parent, "WindowFrame", Vector3(0.08, 1.14, 0.11), at, frame)
	for a in [-0.55, 0.55]:
		_box(generated, visual_parent, "WindowFrame", Vector3(0.11, 0.08, 1.5) if side else Vector3(1.5, 0.08, 0.11), Vector3(x, y + a, z), frame)

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	_occluders = Node3D.new()
	_occluders.name = "UpperAndFront"
	generated.add_child(_occluders)
	var height := float(floors) * 2.8
	var wall_colors := [Color("#828784"), Color("#777e7f"), Color("#626d70"), Color("#757f82")]
	var roof_colors := [Color("#484446"), Color("#484f54"), Color("#353c42"), Color("#414a50")]
	var wall := _mat(wall_colors[style], 0.0, true)
	var roof := _mat(roof_colors[style], 0.15)
	var trim := _mat(Color("#555d60"))
	_box(generated, generated, "Foundation", Vector3(width + 0.4, 0.28, depth + 0.4), Vector3(0, -0.12, 0), trim, true)
	_box(generated, generated, "NorthWall", Vector3(width, height, 0.22), Vector3(0, height * 0.5, -depth * 0.5), wall, true)
	_box(generated, generated, "WestWall", Vector3(0.22, height, depth), Vector3(-width * 0.5, height * 0.5, 0), wall, true)
	_box(generated, _occluders, "EastWall", Vector3(0.22, height, depth), Vector3(width * 0.5, height * 0.5, 0), wall, true)
	if entrance:
		var side_length := (width - 1.8) * 0.5
		for side in [-1.0, 1.0]:
			var x: float = float(side) * (1.8 + side_length) * 0.5
			_box(generated, _occluders, "SouthWall", Vector3(side_length, height, 0.22), Vector3(x, height * 0.5, depth * 0.5), wall, true)
		_box(generated, _occluders, "DoorLintel", Vector3(1.8, height - 2.3, 0.22), Vector3(0, 2.3 + (height - 2.3) * 0.5, depth * 0.5), wall, true)
		_box(generated, generated, "DoorThreshold", Vector3(1.7, 0.05, 0.6), Vector3(0, 0.025, depth * 0.5), trim)
	else:
		_box(generated, _occluders, "SouthWall", Vector3(width, height, 0.22), Vector3(0, height * 0.5, depth * 0.5), wall, true)
	for floor_index in range(floors):
		var center_y := float(floor_index) * 2.8 + 1.55
		var count := maxi(1, int(width / 4.0))
		for slot in range(count):
			var x := (float(slot) + 0.5) * width / float(count) - width * 0.5
			if floor_index == 0 and absf(x) < 1.25 and entrance: continue
			_window(generated, _occluders, x, center_y, depth * 0.5 + 0.14)
			_window(generated, generated, x, center_y, -depth * 0.5 - 0.14)
		if floor_index > 0:
			_box(generated, generated, "StoreyFloor", Vector3(width - 0.1, 0.14, depth - 0.1), Vector3(0, float(floor_index) * 2.8, 0), trim, true)
	for side in [-1.0, 1.0]:
		_window(generated, _occluders if side > 0 else generated, float(side) * (width * 0.5 + 0.14), 1.55, 0, true)
	if style == 0:
		var rise := minf(2.2, depth * 0.23)
		var slope := atan2(rise, depth * 0.5)
		var panel_length := sqrt((depth * 0.5) ** 2 + rise ** 2) + 0.5
		for side in [-1.0, 1.0]:
			_box(generated, _occluders, "GableRoof", Vector3(width + 0.7, 0.18, panel_length), Vector3(0, height + rise * 0.5, float(side) * depth * 0.25), roof, false, float(side) * slope)
	else:
		_box(generated, _occluders, "FlatRoof", Vector3(width + 0.55, 0.22, depth + 0.55), Vector3(0, height + 0.12, 0), roof)
		_box(generated, _occluders, "RoofPlant", Vector3(1.9, 0.65, 1.2), Vector3(width * 0.2, height + 0.5, 0), trim)
	set_occluders_visible(Engine.is_editor_hint())

func contains_world_point(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) < width * 0.5 and absf(local.z) < depth * 0.5

func set_occluders_visible(show_occluders: bool) -> void:
	if not is_instance_valid(_occluders): return
	_occluders.visible = true
	for visual in _occluders.get_children():
		if visual is MeshInstance3D:
			visual.transparency = 0.86 if not show_occluders else 0.0
