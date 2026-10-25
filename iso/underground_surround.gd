@tool
extends Node3D

# The bunker is cut into rock. This layer has no collisions, so room scenes
# remain the only editable gameplay geometry.
const SHALE := preload("res://assets/iso/dark_shale.png")

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Strata floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(20, -0.32, 18)
	var material := ShaderMaterial.new()
	material.shader = preload("res://iso/underground_surround.gdshader")
	material.set_shader_parameter("shale_texture", SHALE)
	floor_mesh.material_override = material
	generated.add_child(floor_mesh)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color("#242d30")
	rock_mat.roughness = 1.0
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color("#172023")
	edge_mat.roughness = 1.0
	var seed := RandomNumberGenerator.new()
	seed.seed = 193821
	for i in 58:
		var angle := TAU * float(i) / 58.0 + seed.randf_range(-0.08, 0.08)
		var radius := seed.randf_range(25.5, 34.0)
		var rock := MeshInstance3D.new()
		rock.name = "Bedrock %02d" % i
		var mesh := SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.radius = 1.0
		mesh.height = 2.0
		rock.mesh = mesh
		rock.scale = Vector3(seed.randf_range(1.2, 3.0), seed.randf_range(0.35, 1.15), seed.randf_range(1.0, 2.7))
		rock.position = Vector3(20 + cos(angle) * radius, -0.30, 18 + sin(angle) * radius)
		rock.rotation.y = seed.randf_range(0, TAU)
		rock.material_override = rock_mat if i % 3 == 0 else edge_mat
		generated.add_child(rock)
