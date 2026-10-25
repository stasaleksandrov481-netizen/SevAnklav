@tool
extends Node3D

func _ready() -> void:
	_rebuild()

func _material(color: Color, roughness := 0.86) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _part(parent: Node3D, label: String, mesh: Mesh, at: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = at
	visual.material_override = material
	parent.add_child(visual)

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var fabric := _material(Color("#263037"))
	var vest := _material(Color("#333b40"))
	var boots := _material(Color("#171d20"))
	var skin := _material(Color("#a38473"))
	var hair := _material(Color("#252321"))
	_part(generated, "Torso", _capsule(0.29, 0.88), Vector3(0, 0.08, 0), fabric)
	_part(generated, "ProtectiveVest", _box(Vector3(0.52, 0.55, 0.32)), Vector3(0, 0.08, 0.07), vest)
	_part(generated, "Head", _capsule(0.18, 0.39), Vector3(0, 0.68, 0), skin)
	_part(generated, "Hair", _capsule(0.18, 0.20), Vector3(0, 0.80, -0.02), hair)
	for side in [-1.0, 1.0]:
		var s: float = float(side)
		_part(generated, "Arm", _capsule(0.11, 0.68), Vector3(s * 0.37, 0.03, 0), fabric)
		_part(generated, "Hand", _capsule(0.085, 0.19), Vector3(s * 0.37, -0.35, 0.01), skin)
		_part(generated, "Leg", _capsule(0.13, 0.76), Vector3(s * 0.17, -0.51, 0), fabric)
		_part(generated, "Boot", _box(Vector3(0.24, 0.19, 0.36)), Vector3(s * 0.17, -0.85, 0.09), boots)
	_part(generated, "Backpack", _box(Vector3(0.38, 0.54, 0.20)), Vector3(0, 0.05, -0.24), _material(Color("#39443e")))
	_part(generated, "ArmBand", _box(Vector3(0.13, 0.10, 0.22)), Vector3(0.37, 0.18, 0), _material(Color("#8d4039")))
