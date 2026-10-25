@tool
extends Node3D
class_name IsoProp

@export var story_id := ""
@export var display_name := ""

@export_enum("Desk", "Locker", "Medical bed", "Terminal", "Custom model") var kind := 0:
	set(value):
		kind = value
		_refresh()
@export var model: PackedScene:
	set(value):
		model = value
		_refresh()
@export_range(0.1, 10.0, 0.1) var model_scale := 1.0:
	set(value):
		model_scale = value
		_refresh()
@export var collision_size := Vector3(1.0, 1.0, 1.0):
	set(value):
		collision_size = value
		_refresh()

func _ready() -> void:
	add_to_group("iso_interactables")
	_rebuild()

func _refresh() -> void:
	if is_inside_tree(): call_deferred("_rebuild")

func _mat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.65
	return m

func _part(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color, metallic := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(color, metallic)
	parent.add_child(node)

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	if kind == 4:
		if model != null:
			var imported := model.instantiate()
			generated.add_child(imported)
			if imported is Node3D: imported.scale = Vector3.ONE * model_scale
	else:
		var steel := Color("#45545c")
		match kind:
			0:
				_part(generated, "Worktop", Vector3(1.6, 0.1, 0.8), Vector3(0, 0.75, 0), steel, 0.4)
				for x in [-0.68, 0.68]:
					for z in [-0.3, 0.3]:
						_part(generated, "Leg", Vector3(0.08, 0.7, 0.08), Vector3(x, 0.35, z), steel, 0.4)
			1:
				_part(generated, "Locker", Vector3(0.9, 2.0, 0.55), Vector3(0, 1, 0), steel, 0.65)
				_part(generated, "Door", Vector3(0.8, 1.85, 0.02), Vector3(0, 1, 0.29), Color("#687a80"), 0.5)
			2:
				_part(generated, "Bed frame", Vector3(2.0, 0.28, 0.9), Vector3(0, 0.58, 0), steel, 0.5)
				_part(generated, "Mattress", Vector3(1.85, 0.15, 0.8), Vector3(0, 0.78, 0), Color("#849595"))
				_part(generated, "Headboard", Vector3(0.12, 0.65, 0.9), Vector3(-0.95, 0.85, 0), steel, 0.5)
			3:
				_part(generated, "Console", Vector3(0.9, 1.2, 0.6), Vector3(0, 0.6, 0), steel, 0.5)
				_part(generated, "Display", Vector3(0.75, 0.48, 0.04), Vector3(0, 1.45, 0.12), Color("#315f68"))
	var body := StaticBody3D.new()
	generated.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = collision_size
	shape.shape = box
	shape.position.y = collision_size.y * 0.5
	body.add_child(shape)
