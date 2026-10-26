@tool
extends Node3D
class_name IsoRoom

@export_range(2, 30) var width := 8:
	set(value):
		width = value
		_refresh()
@export_range(2, 30) var depth := 6:
	set(value):
		depth = value
		_refresh()
@export_enum("Concrete", "Laboratory", "Metal") var floor_finish := 0:
	set(value):
		floor_finish = value
		_refresh()
@export var north_door := false:
	set(value):
		north_door = value
		_refresh()
@export var south_door := true:
	set(value):
		south_door = value
		_refresh()
@export var east_door := false:
	set(value):
		east_door = value
		_refresh()
@export var west_door := false:
	set(value):
		west_door = value
		_refresh()
@export var roof_enabled := true:
	set(value):
		roof_enabled = value
		_refresh()

var _wall_visuals: Array[MeshInstance3D] = []
var _roof: Node3D
var _near_walls: Node3D

func _ready() -> void:
	add_to_group("iso_rooms")
	_rebuild()

func _refresh() -> void:
	if is_inside_tree(): call_deferred("_rebuild")

func _material(color: Color, concrete_texture: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if concrete_texture:
		mat.albedo_texture = load("res://assets/iso/concrete_panels.png") as Texture2D
	return mat

func _box(parent: Node3D, label: String, box_size: Vector3, at: Vector3, mat: Material, solid: bool = true, near_visual: bool = false) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = box_size
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = at
	if label.begins_with("North") or label.begins_with("South") or label.begins_with("East") or label.begins_with("West"):
		_wall_visuals.append(visual)
	if near_visual and is_instance_valid(_near_walls): _near_walls.add_child(visual)
	else: parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = box_size
		shape.shape = box
		body.add_child(shape)

func _wall(parent: Node3D, label: String, length: float, along_x: bool, center: Vector3, opening: bool, mat: Material) -> void:
	var height := 2.8
	var near := label == "South" or label == "East"
	if not opening or length <= 2.5:
		_box(parent, label, Vector3(length, height, 0.2) if along_x else Vector3(0.2, height, length), center + Vector3.UP * 1.4, mat, true, near)
		return
	var side := (length - 1.4) * 0.5
	for signum in [-1.0, 1.0]:
		var offset: float = float(signum) * (1.4 + side) * 0.5
		var at := center + (Vector3(offset, 1.4, 0) if along_x else Vector3(0, 1.4, offset))
		_box(parent, label + str(signum), Vector3(side, height, 0.2) if along_x else Vector3(0.2, height, side), at, mat, true, near)
	_box(parent, label + "Lintel", Vector3(1.4, 0.5, 0.2) if along_x else Vector3(0.2, 0.5, 1.4), center + Vector3.UP * 2.55, mat, true, near)

func _rebuild() -> void:
	_wall_visuals.clear()
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	_near_walls = Node3D.new()
	_near_walls.name = "CameraSideWalls"
	generated.add_child(_near_walls)
	var colors := [Color("#545e61"), Color("#879597"), Color("#404b53")]
	_box(generated, "Floor", Vector3(width, 0.18, depth), Vector3(0, -0.09, 0), _material(Color.WHITE if floor_finish == 0 else colors[floor_finish], floor_finish == 0))
	var wall_mat := _material(Color(0.82, 0.88, 0.90), true)
	_wall(generated, "North", width, true, Vector3(0, 0, -depth * 0.5), north_door, wall_mat)
	_wall(generated, "South", width, true, Vector3(0, 0, depth * 0.5), south_door, wall_mat)
	_wall(generated, "East", depth, false, Vector3(width * 0.5, 0, 0), east_door, wall_mat)
	_wall(generated, "West", depth, false, Vector3(-width * 0.5, 0, 0), west_door, wall_mat)
	_roof = Node3D.new()
	_roof.name = "Roof"
	generated.add_child(_roof)
	if roof_enabled:
		_box(_roof, "Ceiling", Vector3(width + 0.3, 0.16, depth + 0.3), Vector3(0, 2.9, 0), _material(Color("#303c43")), false)
	set_roof_visible(Engine.is_editor_hint())
	set_front_transparency(0.0)

func set_front_transparency(alpha: float) -> void:
	if not is_instance_valid(_near_walls): return
	for visual in _near_walls.get_children():
		if not visual is MeshInstance3D: continue
		if not visual.has_meta("opaque_material"):
			var opaque: Material = visual.material_override
			var faded := opaque.duplicate() as StandardMaterial3D
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var color := faded.albedo_color
			color.a = 0.12
			faded.albedo_color = color
			visual.set_meta("opaque_material", opaque)
			visual.set_meta("faded_material", faded)
		visual.material_override = visual.get_meta("faded_material") if alpha > 0.5 else visual.get_meta("opaque_material")

func set_roof_visible(show_roof: bool) -> void:
	if is_instance_valid(_roof): _roof.visible = show_roof and roof_enabled

func contains_world_point(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) < width * 0.5 and absf(local.z) < depth * 0.5

# Test the full body silhouette; opaque rooms stay on the opaque render path.
const Cutaway = preload("res://iso/wall_cutaway.gd")
func update_occlusion(point: Vector3, camera: Camera3D, delta: float, occupied_bounds := Rect2()) -> void:
	for visual in _wall_visuals:
		var front := false
		if occupied_bounds.has_area():
			var at := visual.global_position
			var axis := camera.global_basis.z
			var x_edge := occupied_bounds.end.x if axis.x > 0 else occupied_bounds.position.x
			var z_edge := occupied_bounds.end.y if axis.z > 0 else occupied_bounds.position.y
			# Include both faces of a shared wall. Otherwise the neighbouring
			# room's opaque duplicate still hides the occupied room's interior.
			front = (absf(at.x-x_edge) < 0.22 and at.z >= occupied_bounds.position.y and at.z <= occupied_bounds.end.y) or (absf(at.z-z_edge) < 0.22 and at.x >= occupied_bounds.position.x and at.x <= occupied_bounds.end.x)
		Cutaway.update(visual, point, camera, delta, front)
