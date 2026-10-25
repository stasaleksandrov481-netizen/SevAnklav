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
