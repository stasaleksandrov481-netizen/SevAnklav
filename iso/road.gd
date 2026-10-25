@tool
extends Node3D
class_name IsoRoad

@export_enum("East-West", "North-South") var direction := 0:
	set(value):
		direction = value
		_refresh()
@export_range(8.0, 256.0, 1.0) var length := 64.0:
	set(value):
		length = value
		_refresh()
@export_range(4.0, 20.0, 1.0) var width := 10.0:
	set(value):
		width = value
		_refresh()
@export var intersection_at_center := true:
	set(value):
		intersection_at_center = value
		_refresh()

func _ready() -> void:
	_rebuild()

func _refresh() -> void:
	if is_inside_tree(): call_deferred("_rebuild")

func _mat(color: Color, texture: Texture2D = null) -> Material:
	if texture != null:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = preload("res://iso/surface.gdshader")
		shader_mat.set_shader_parameter("albedo_texture", texture)
		shader_mat.set_shader_parameter("tint", color)
		return shader_mat
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	return mat

func _box(parent: Node3D, label: String, along: float, across: float, height: float, longitudinal: float, lateral: float, y: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var box := BoxMesh.new()
	box.size = Vector3(along, height, across) if direction == 0 else Vector3(across, height, along)
	node.mesh = box
	node.position = Vector3(longitudinal, y, lateral) if direction == 0 else Vector3(lateral, y, longitudinal)
	node.material_override = material
	parent.add_child(node)

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var asphalt := _mat(Color(0.72, 0.76, 0.78), load("res://assets/iso/asphalt.png") as Texture2D)
	var concrete := _mat(Color(0.62, 0.68, 0.69), load("res://assets/iso/concrete_panels.png") as Texture2D)
	var paint := _mat(Color("#aaa89e"))
	var curb_mat := _mat(Color("#727979"))
	_box(generated, "Asphalt", length, width, 0.04, 0, 0, 0.00, asphalt)
	var gap := width + 6.0 if intersection_at_center else 0.0
	var side_length := (length - gap) * 0.5
	for side in [-1.0, 1.0]:
		var lateral: float = float(side) * (width * 0.5 + 1.05)
		if intersection_at_center:
			for end in [-1.0, 1.0]:
				var longitudinal: float = float(end) * (gap + side_length) * 0.5
				_box(generated, "Sidewalk", side_length, 2.0, 0.12, longitudinal, lateral, 0.04, concrete)
				_box(generated, "Curb", side_length, 0.14, 0.15, longitudinal, float(side) * width * 0.5, 0.05, curb_mat)
		else:
			_box(generated, "Sidewalk", length, 2.0, 0.12, 0, lateral, 0.04, concrete)
			_box(generated, "Curb", length, 0.14, 0.15, 0, float(side) * width * 0.5, 0.05, curb_mat)
	for i in range(-int(length / 12), int(length / 12) + 1):
		var longitudinal := float(i) * 6.0
		if absf(longitudinal) > length * 0.5 - 2.0: continue
		if intersection_at_center and absf(longitudinal) < gap * 0.5: continue
		_box(generated, "LaneDash", 2.6, 0.10, 0.006, longitudinal, 0, 0.025, paint)
	if intersection_at_center:
		for end in [-1.0, 1.0]:
			var cross_at: float = float(end) * (width * 0.5 + 2.0)
			for stripe in range(-int(width * 0.5), int(width * 0.5) + 1, 2):
				_box(generated, "Crosswalk", 1.25, 0.75, 0.006, cross_at, float(stripe), 0.027, paint)
