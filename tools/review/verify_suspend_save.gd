extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		# Stop this coroutine immediately, including in release builds.
		assert(ok, message)

func verify() -> void:
	var game = root.get_node("G")
	game.zsave = game._default_zsave()
	var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=true
	var scene = load("res://iso/bunker_world.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	for i in range(30):
		await physics_frame
	var expected: Vector3
	for event in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		world.paused = true
		world.player.position.x += 0.1
		expected = world.player.position - world.ORIGIN
		world.notification(event)
		var saved := ConfigFile.new()
		check(saved.load("user://anklav_rts.cfg") == OK, "Save was not written")
		var position: Array = saved.get_value("zcamp", "zsave")[world.state_key].position
		check(Vector3(position[0], position[1], position[2]).is_equal_approx(expected), "Suspension lost the latest position")
		check(world.save_clock < 6.0, "Test must run before periodic autosave")
	world.queue_free()
	await process_frame
	game._load_save()
	world = scene.instantiate()
	root.add_child(world)
	check((world.player.position - world.ORIGIN).is_equal_approx(expected), "Reload did not restore the latest position")
	world.queue_free()
	await process_frame
	# A new game must still use the authored spawn, not the old position.
	game.zsave = game._default_zsave()
	world = scene.instantiate()
	root.add_child(world)
	check(world.player.global_position.is_equal_approx(world.capsule_node().global_position+Vector3(0,1.1,0)), "New game did not use PlayerSpawn")
	print("SUSPEND SAVE PASS: pause, focus loss, close, disk reload, fresh spawn")
	world.queue_free()
	await process_frame
	quit(0)
