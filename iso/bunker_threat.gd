extends CharacterBody3D
var health := 100
var visual: Node3D
func _ready() -> void:
	visual = preload("res://iso/volkov_visual.gd").new()
	add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	collision.shape = shape
	add_child(collision)
	for mesh in visual.get_node("Generated").get_children():
		if mesh is MeshInstance3D:
			var material := mesh.material_override.duplicate() as StandardMaterial3D
			material.albedo_color = Color("#777d72") if mesh.name == "Head" else Color("#574c48")
			mesh.material_override = material
func _physics_process(delta: float) -> void:
	var world := get_parent()
	var bunker = world.get_node_or_null("Sectors/Sector_55_45/Bunker")
	if bunker == null: return
	var detail = bunker.get_node("Details")
	var local: Vector3 = detail.to_local(global_position)
	visible = detail.active_room.has_point(Vector2(local.x,local.z))
	if health <= 0 or not visible: return
	var player: Node3D = world.get_node("Volkov")
	var direction := player.global_position-global_position
	direction.y = 0
	if direction.length() < 1.0:
		var game = get_node("/root/G")
		game.zsave["iso_health"] = maxf(1,float(game.zsave.get("iso_health",100))-8*delta)
		velocity = Vector3.ZERO
	else:
		velocity = direction.normalized()*1.25
		velocity.y = -2
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),delta*4)
	move_and_slide()
func damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		collision_layer = 0
		collision_mask = 0
		var fall := create_tween()
		fall.tween_property(visual,"rotation:z",PI/2,0.5)
