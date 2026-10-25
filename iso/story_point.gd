@tool
extends Node3D

@export var story_id := ""
@export var display_name := ""

func _ready() -> void:
	add_to_group("iso_interactables")
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#3e4b51")
	metal.metallic = 0.6
	metal.roughness = 0.48
	var warning := StandardMaterial3D.new()
	warning.albedo_color = Color("#a86b42")
	warning.emission_enabled = true
	warning.emission = Color("#9c3e24")
	warning.emission_energy_multiplier = 1.6
	_part(generated, "Door frame left", Vector3(0.15, 2.55, 0.24), Vector3(-0.72, 1.275, 0), metal)
	_part(generated, "Door frame right", Vector3(0.15, 2.55, 0.24), Vector3(0.72, 1.275, 0), metal)
	_part(generated, "Door frame top", Vector3(1.65, 0.18, 0.24), Vector3(0, 2.48, 0), metal)
	_part(generated, "Door threshold", Vector3(1.6, 0.07, 0.6), Vector3(0, 0.035, 0), metal)
	_part(generated, "Access lamp", Vector3(0.22, 0.09, 0.08), Vector3(0.59, 1.45, 0.2), warning)

func _part(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
