extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("check")
func verify(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
func check() -> void:
	var world = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var bunker = world.get_node("Sectors/Sector_55_45/Bunker")
	verify(world.find_children("*", "DirectionalLight3D", true, false).is_empty(), "No underground sun")
	verify(world.get_node("WorldEnvironment").environment.ambient_light_energy == 0.0, "No ambient fill")
	verify(world.get_node("Camera").size == 16.0, "Closer bunker camera")
	var lamps = bunker.get_node("Details").lamps
	verify(lamps.size() == 48, "All sixteen sectors have wall fixtures")
	for lamp in lamps:
		verify(lamp.shadow_enabled, "Fixture casts shadows")
		verify(lamp.get_parent().position.y < 2.2, "No ceiling lamp")
	# Walkable route: ray at torso height through every required passage.
	var route := [Vector3(7,1,-8), Vector3(0,1,-8), Vector3(-5,1,-8), Vector3(0,1,-8), Vector3(0,1,0), Vector3(-5,1,0), Vector3(0,1,0), Vector3(5,1,0), Vector3(0,1,0), Vector3(0,1,8), Vector3(8,1,8), Vector3(8,1,19), Vector3(20,1,19), Vector3(35,1,19), Vector3(35,1,24), Vector3(35,1,19), Vector3(20,1,19), Vector3(20,1,30)]
	for i in range(route.size()-1):
		var query := PhysicsRayQueryParameters3D.create(bunker.to_global(route[i]), bunker.to_global(route[i+1]))
		query.exclude = [world.get_node("Volkov").get_rid()]
		verify(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Blocked story passage %d" % i)
	var room = bunker.get_node("CorridorCenter")
	var point: Vector3 = room.global_position + Vector3(0,0.95,0)
	room.update_occlusion(point, world.get_node("Camera"), 1.0)
	var faded := 0
	for wall in room._wall_visuals:
		if wall.material_override.albedo_color.a < 0.5: faded += 1
	verify(faded > 0, "Camera-facing corridor wall cuts away")
	var detail = bunker.get_node("Details")
	for location in [Vector3(8,0.95,-8),Vector3(0,0.95,0),Vector3(35,0.95,19)]:
		world.get_node("Volkov").global_position = bunker.to_global(location)
		detail._process(0.016)
		var lit := 0
		for lamp in lamps:
			if lamp.is_visible_in_tree(): lit += 1
			verify(lamp.is_visible_in_tree() == lamp.get_parent().is_visible_in_tree(), "Diffuser and light culled together")
		verify(lit == 3, "Only occupied room fixtures active")
	# An opaque wall not covering the player must avoid transparency blending.
	var cut = load("res://iso/wall_cutaway.gd")
	world.get_node("Volkov").global_position = bunker.to_global(Vector3(0,0.95,0))
	for candidate in ["Medical", "CorridorCenter", "CorridorNorth", "PowerHall"]:
		var area = bunker.get_node(candidate)
		area.update_occlusion(world.get_node("Volkov").global_position, world.get_node("Camera"), 1.0)
		for wall in area._wall_visuals:
			var blocked = cut.blocks(wall,world.get_node("Volkov").global_position,world.get_node("Camera"))
			verify((wall.material_override.albedo_color.a < 0.5) == blocked, "Cutaway follows full-body camera rays")
			if not blocked: verify(wall.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Non-blocking wall stays opaque")
	verify(detail.get_node("Generated").get_children().filter(func(node): return node.has_meta("static_batch")).size() > 10, "Static geometry batched")
	print("BUNKER_LIGHTING_CHECK failures=", failures)
	quit(1 if failures else 0)
