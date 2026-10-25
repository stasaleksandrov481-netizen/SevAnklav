@tool
extends Node3D

func _ready() -> void:
	_rebuild()

func _mat(color: Color, metal := 0.0, alpha := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.22 if alpha else 0.55
	if alpha: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var frame := _mat(Color("#536169"), 0.7)
	var interior := _mat(Color("#9aa6a5"))
	var glass := _mat(Color(0.34, 0.59, 0.66, 0.30), 0.1, true)
	var red := _mat(Color("#a44f39"), 0.2)
	_box(generated, "Base", Vector3(2.25, 0.45, 1.14), Vector3(0, 0.48, 0), frame)
	_box(generated, "Mattress", Vector3(1.85, 0.10, 0.80), Vector3(0, 0.76, 0), interior)
	for side in [-1.0, 1.0]:
		_box(generated, "Pressure rib", Vector3(0.09, 0.68, 1.16), Vector3(side * 1.05, 1.07, 0), frame)
		_box(generated, "Status lamp", Vector3(0.16, 0.08, 0.18), Vector3(side * 1.04, 1.43, -0.38), red)
	_box(generated, "Glass shell", Vector3(1.92, 0.06, 0.94), Vector3(0, 1.45, 0), glass)
	_box(generated, "Top rail", Vector3(2.14, 0.08, 0.10), Vector3(0, 1.46, -0.52), frame)
	var body := StaticBody3D.new()
	generated.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.25, 1.15, 1.14)
	collision.shape = shape
	collision.position.y = 0.57
	body.add_child(collision)
