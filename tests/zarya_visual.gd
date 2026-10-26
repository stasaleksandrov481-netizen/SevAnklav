extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G")
	game.set_meta("qa8",true)
	game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave)
	state.data.awake=true
	var world=load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.player.position=world.ORIGIN+Vector3(-24,0.95,-8.3)
	for frame in range(45):
		await process_frame
		await RenderingServer.frame_post_draw
	print("RENDER draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	root.get_texture().get_image().save_png("res://zarya_hud.png")
	world.hud.open_inventory()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://zarya_inventory.png")
	world.hud.close_modal()
	world.hud.open_medical()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://zarya_medical.png")
	print("ZARYA_VISUAL_OK")
	quit()
