extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("Camera").size = 21.0
	var times: Array[float] = []
	for i in range(40):
		var start := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		if i >= 15: times.append((Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	print("BENCH median_ms=", times[times.size()/2], " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png("res://" + (args[0] if not args.is_empty() else "performance") + ".png")
	quit()
