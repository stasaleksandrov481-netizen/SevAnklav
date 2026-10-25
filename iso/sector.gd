@tool
extends Node3D
class_name IsoSector

const SIDE := 64.0

@export_enum("Earth", "Concrete", "Asphalt", "Grass") var ground_kind := 0:
	set(value):
		ground_kind = value
		if is_inside_tree(): call_deferred("_rebuild_ground")
@export var ground_enabled := true:
	set(value):
		ground_enabled = value
		if is_inside_tree(): call_deferred("_rebuild_ground")

func _ready() -> void:
	_rebuild_ground()

func _rebuild_ground() -> void:
	for child in get_children():
		if child.name == "GeneratedGround":
			remove_child(child)
			child.queue_free()
	if not ground_enabled: return
	var body := StaticBody3D.new()
	body.name = "GeneratedGround"
	body.position = Vector3(32, -0.2, 32)
	add_child(body)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SIDE, 0.2, SIDE)
	mesh_node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://iso/surface.gdshader")
	var textures := ["res://assets/iso/grass_soil.png", "res://assets/iso/concrete_panels.png", "res://assets/iso/asphalt.png", "res://assets/iso/grass_soil.png"]
	material.set_shader_parameter("albedo_texture", load(textures[ground_kind]))
	material.set_shader_parameter("tint", Color(0.62, 0.70, 0.67) if ground_kind == 3 else Color(0.70, 0.74, 0.74))
	mesh_node.material_override = material
	body.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
