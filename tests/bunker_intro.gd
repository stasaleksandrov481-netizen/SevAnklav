extends SceneTree
func _initialize() -> void:
	call_deferred("check")
func check() -> void:
	var game = root.get_node("G")
	game.zsave = game._default_zsave()
	game.zsave["iso_objective"] = 0
	var world = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	world.add_child(load("res://iso/campaign_hud.gd").new())
	await create_timer(0.3).timeout
	assert(not world.get_node("Volkov").is_physics_processing())
	await create_timer(4.8).timeout
	assert(game.zsave.get("bunker_awake",false))
	assert(world.get_node("Volkov").is_physics_processing())
	assert(world.get_node("Volkov/Visual").scale == Vector3.ONE)
	assert(absf(world.get_node("Volkov/Visual").rotation.z) < 0.01)
	print("INTRO_OK capsule opens, actor rises without scaling, controls restored")
	quit()
