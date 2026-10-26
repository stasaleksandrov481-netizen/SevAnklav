extends CharacterBody3D

@export var walk_speed := 4.0
@export var run_speed := 6.5
@export var acceleration := 18.0

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch_pad := get_node_or_null("../TouchControls/Root/Pad")
	if touch_pad != null and touch_pad.has_method("get_move_vector"):
		var touch_input: Vector2 = touch_pad.get_move_vector()
		if touch_input.length() > 0.1: input = touch_input
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3(input.x, 0, input.y)
	if camera != null:
		var right := camera.global_basis.x
		var forward := -camera.global_basis.z
		right.y = 0
		forward.y = 0
		direction = right.normalized() * input.x - forward.normalized() * input.y
	if direction.length() > 1: direction = direction.normalized()
	var run_button := get_node_or_null("../TouchControls/Root/Run") as Button
	var speed := run_speed if Input.is_action_pressed("run") or (run_button != null and run_button.button_pressed) else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if direction.length() > 0.1:
		$Visual.rotation.y = lerp_angle($Visual.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))

var shooting := false
var shot_clock := 0.0
func _process(delta: float) -> void:
	shot_clock = maxf(0,shot_clock-delta)
	var game = get_node("/root/G")
	var armed := bool(game.zsave.get("iso_armed",false))
	var gun = get_node_or_null("Visual/Weapon")
	if gun == null:
		gun = MeshInstance3D.new()
		gun.name = "Weapon"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12,0.14,0.42)
		gun.mesh = mesh
		gun.position = Vector3(0.35,0.12,0.32)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#596970")
		gun.material_override = material
		$Visual.add_child(gun)
	gun.visible = armed
	if not armed or not is_physics_processing(): return
	if (Input.is_action_pressed("shoot") or shooting) and shot_clock <= 0:
		var ammo: Dictionary = game.zsave.get("ammo",{})
		if int(ammo.get("pistol",0)) <= 0: return
		ammo["pistol"] = int(ammo["pistol"])-1
		game.zsave["ammo"] = ammo
		shot_clock = 0.32
		var start := global_position + Vector3.UP*0.25
		var direction: Vector3 = $Visual.global_basis.z
		var query := PhysicsRayQueryParameters3D.create(start,start+direction*22)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.has_method("damage"): hit.collider.damage(34)
