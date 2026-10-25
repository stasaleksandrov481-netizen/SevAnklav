@tool
extends Node3D
class_name IsoCityCar

@export var body_color := Color("#48565a"):
	set(value):
		body_color = value
		if is_inside_tree(): call_deferred("_rebuild")

func _ready() -> void:
	_rebuild()

func _material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.56
	return mat

func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, mat: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = mat
	parent.add_child(visual)

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var paint := _material(body_color, 0.35)
	var glass := _material(Color("#263c43"), 0.3)
	var rubber := _material(Color("#171a1c"))
	var metal := _material(Color("#8a9695"), 0.6)
	_box(generated, "Chassis", Vector3(1.72, 0.55, 4.1), Vector3(0, 0.68, 0), paint)
	_box(generated, "Cabin", Vector3(1.38, 0.64, 2.05), Vector3(0, 1.24, -0.2), paint)
	_box(generated, "Windshield", Vector3(1.24, 0.46, 0.06), Vector3(0, 1.32, 0.86), glass)
	_box(generated, "RearGlass", Vector3(1.24, 0.46, 0.06), Vector3(0, 1.32, -1.26), glass)
	for side in [-1.0, 1.0]:
		var s: float = float(side)
		for front in [-1.4, 1.4]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.35
			cylinder.bottom_radius = 0.35
			cylinder.height = 0.2
			wheel.mesh = cylinder
			wheel.position = Vector3(s * 0.87, 0.37, front)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = rubber
			generated.add_child(wheel)
		_box(generated, "SideGlass", Vector3(0.05, 0.42, 1.65), Vector3(s * 0.72, 1.32, -0.2), glass)
		_box(generated, "Headlight", Vector3(0.32, 0.16, 0.05), Vector3(s * 0.58, 0.76, 2.08), metal)
		_box(generated, "TailLight", Vector3(0.30, 0.14, 0.05), Vector3(s * 0.58, 0.76, -2.08), _material(Color("#9b4038")))
	var body := StaticBody3D.new()
	generated.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.4, 4.2)
	collision.shape = shape
	collision.position.y = 0.7
	body.add_child(collision)
