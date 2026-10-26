extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	var bunker = world.get_node("Sectors/Sector_55_45/Bunker")
	for entry in [["medical",Vector3(8,0.95,-8)],["corridor",Vector3(0,0.95,0)],["laboratory",Vector3(-7.5,0.95,-8)]]:
		world.get_node("Volkov").global_position = bunker.to_global(entry[1])
		world.get_node("Camera").global_position = world.get_node("Volkov").global_position+world.get_node("Camera")._offset
		for frame in range(24):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://optimized_"+entry[0]+".png")
	quit()
