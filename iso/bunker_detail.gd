@tool
extends Node3D

# Decorative layer for the editable rooms and corridor in bunker_start.tscn.
# All parts are visuals; the room and prop scenes own collisions.

func _ready() -> void:
	_rebuild()

func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.18
	material.roughness = 0.72
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
	return material

func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color, glow := false) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.material_override = _mat(color, glow)
	parent.add_child(part)

func _light(parent: Node3D, at: Vector3, color: Color, strength: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = strength
	lamp.omni_range = 7.5
	lamp.shadow_enabled = false
	parent.add_child(lamp)
	_box(parent, "Lamp", Vector3(2.3, 0.08, 0.14), at + Vector3(0, 0.12, 0), color, true)

func _room(parent: Node3D, label: String, center: Vector3, width: float, depth: float, accent: Color) -> void:
	var outline := Color("#1a3039")
	for signum in [-1.0, 1.0]:
		_box(parent, label + " floor rail", Vector3(width - 0.65, 0.025, 0.11), center + Vector3(0, 0.025, signum * (depth * 0.5 - 0.42)), accent)
		_box(parent, label + " side rail", Vector3(0.11, 0.025, depth - 0.65), center + Vector3(signum * (width * 0.5 - 0.42), 0.025, 0), accent)
		_box(parent, label + " wall band", Vector3(width - 0.45, 0.12, 0.06), center + Vector3(0, 1.45, signum * (depth * 0.5 - 0.1)), outline)
	_box(parent, label + " overhead conduit", Vector3(0.12, 0.12, depth - 0.7), center + Vector3(-width * 0.5 + 0.55, 2.55, 0), Color("#30444b"))
	_light(parent, center + Vector3(0, 2.45, 0), accent.lightened(0.26), 0.67)
	for side in [-1.0, 1.0]:
		_box(parent, label + " wall service pipe", Vector3(width - 1.0, 0.075, 0.075), center + Vector3(0, 2.15, side * (depth * 0.5 - 0.16)), Color("#425258"))
		_box(parent, label + " pipe bracket", Vector3(0.12, 0.30, 0.18), center + Vector3(-width * 0.25, 2.1, side * (depth * 0.5 - 0.16)), Color("#242e34"))

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	_room(generated, "Laboratory", Vector3(-7.5, 0, -8), 11, 8, Color("#67a9b4"))
	_room(generated, "Staff quarters", Vector3(-7.5, 0, -15), 11, 6, Color("#8d9aa0"))
	_room(generated, "Records", Vector3(19, 0, -8), 10, 8, Color("#879b8a"))
	_room(generated, "Medical", Vector3(8, 0, -8), 12, 8, Color("#8bc5ac"))
	_room(generated, "Storage", Vector3(5.5, 0, 0), 7, 8, Color("#b38e59"))
	_room(generated, "Generator", Vector3(8, 0, 8), 12, 8, Color("#c47b4e"))
	_room(generated, "Security", Vector3(-6, 0, 0), 8, 8, Color("#8a9db7"))
	_room(generated, "Quarantine", Vector3(-7, 0, 8), 10, 8, Color("#a65e5a"))
	for z in [-8.0, 0.0, 8.0]:
		_room(generated, "Corridor", Vector3(0, 0, z), 4, 8, Color("#677c81"))
	for x in [-1.48, 1.48]:
		_box(generated, "Main ventilation duct", Vector3(0.42, 0.3, 22.8), Vector3(x, 2.55, 0), Color("#3c4b51"))
		_box(generated, "Emergency guide", Vector3(0.10, 0.025, 22.2), Vector3(x * 0.68, 0.04, 0), Color("#9d6f4d"))
	for z in [-8.0, 0.0, 8.0]:
		_box(generated, "Corridor overhead light", Vector3(1.4, 0.06, 0.16), Vector3(0, 2.72, z), Color("#b2c4c3"), true)
	for x in [-11.0, -10.45, -9.9]:
		_box(generated, "Lab hazard marking", Vector3(0.14, 0.03, 1.0), Vector3(x, 0.04, -5.1), Color("#cb9f4c"))
	_box(generated, "Generator base", Vector3(2.8, 0.28, 1.5), Vector3(10.2, 0.14, 9.7), Color("#30414a"))
	for x in [9.3, 10.2, 11.1]:
		_box(generated, "Generator coil", Vector3(0.55, 0.8, 0.9), Vector3(x, 0.69, 9.7), Color("#455761"))
		_box(generated, "Generator status", Vector3(0.2, 0.08, 0.04), Vector3(x, 1.13, 10.2), Color("#e39b5a"), true)
	_box(generated, "Medical cross vertical", Vector3(0.22, 0.03, 1.1), Vector3(5.1, 0.04, -10.3), Color("#e2e9dc"))
	_box(generated, "Medical cross horizontal", Vector3(1.1, 0.03, 0.22), Vector3(5.1, 0.045, -10.3), Color("#e2e9dc"))
	for z in [5.0, 5.45, 5.9]:
		_box(generated, "Quarantine warning", Vector3(4.7, 0.03, 0.12), Vector3(-7, 0.04, z), Color("#bd5c4e"))
	_light(generated, Vector3(-7, 2.55, 8), Color("#b24136"), 0.85)
	_light(generated, Vector3(8, 2.55, 8), Color("#d38c53"), 0.76)
	for x in [-11.6, -10.6, -9.6]:
		_box(generated, "Records archive cabinet", Vector3(0.82, 1.72, 0.52), Vector3(x + 29.8, 0.86, -11.0), Color("#344249"))
		_box(generated, "Archive label", Vector3(0.40, 0.12, 0.025), Vector3(x + 29.8, 1.38, -10.72), Color("#a3a69d"))
	for x in [3.6, 4.65, 5.7]:
		_box(generated, "Supply crate", Vector3(0.78, 0.72, 0.82), Vector3(x, 0.36, 2.3), Color("#6a6150"))
		_box(generated, "Crate steel band", Vector3(0.81, 0.09, 0.83), Vector3(x, 0.59, 2.3), Color("#343d40"))
	for z in [-2.9, -2.15]:
		_box(generated, "Security filing cabinet", Vector3(0.70, 1.20, 0.63), Vector3(-8.8, 0.6, z), Color("#3f5059"))
		_box(generated, "Security drawer handle", Vector3(0.10, 0.05, 0.26), Vector3(-8.43, 0.85, z), Color("#aeb5ae"))
	for z in [-14.4, -13.8, -13.2]:
		_box(generated, "Staff locker", Vector3(0.68, 1.70, 0.55), Vector3(-11.8, 0.85, z), Color("#425059"))
		_box(generated, "Locker handle", Vector3(0.04, 0.14, 0.05), Vector3(-11.42, 0.95, z), Color("#b1b5ac"))
