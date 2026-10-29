extends SceneTree

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var game = root.get_node("G")
	game.set_meta("qa8", true)
	game.zsave = game._default_zsave()
	var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=true
	var world = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	for i in range(30): await physics_frame
	world.player.set_physics_process(false)
	for door in world.doors:
		if door.info.kind=="sealed":
			assert(not door.request().is_empty() and not door.opened and is_zero_approx(door.progress),"Outer gate must remain sealed")
			continue
		if not door.opened: door.request()
	for i in range(90): await physics_frame
	world.paused = true
	var shape = world.player.get_node("Collision").shape
	print("PLAYER height=", shape.height, " diameter=", shape.radius * 2)
	var failures := 0
	var passed := 0
	var sealed := 0
	for door in world.doors:
		var normal: Vector3 = door.global_basis.z.normalized()
		var center: Vector3 = door.global_position
		center.y = world.ORIGIN.y + 1.0
		var fractions := []
		for side in [-1, 1]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, center + normal * 1.2 * side)
			query.motion = normal * -2.4 * side
			query.exclude = [world.player.get_rid()]
			query.margin = 0.02
			var hit = world.get_world_3d().direct_space_state.cast_motion(query)
			fractions.append(snappedf(hit[0], 0.001))
			if door.info.kind=="sealed":
				assert(hit[0]<.99,"Outer gate allowed an unsupported exit")
				sealed+=1
			elif hit[0] < 0.99:
				failures += 1
				query.transform.origin += query.motion * minf(1.0, hit[1] + 0.02)
				for contact in world.get_world_3d().direct_space_state.intersect_shape(query):
					print("  OBSTACLE ", contact.collider.get_path(), " at ", center-world.ORIGIN)
			else:passed+=1
		print(door.name, " width=", door.leaf.size.x, " crossing=", fractions)
	print("AUDIT PASS free sweeps=",passed," sealed gate checks=",sealed," unexpected obstacles=",failures)
	assert(failures==0,"Doorway movement blocked")
	for segment in [[Vector3(-14.5,1,1.6),Vector3(-11.94,1,1.6)],[Vector3(-11.94,1,1.6),Vector3(-11.94,1,4.0)]]:
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,world.ORIGIN+segment[0]);query.motion=segment[1]-segment[0];query.exclude=[world.player.get_rid()];query.margin=0.02
		assert(world.get_world_3d().direct_space_state.cast_motion(query)[0]>0.99,"Server corridor turn blocked")
	print("SERVER CORRIDOR PASS: approach and turn into server room")
	for point in [Vector3(-14.5,1,1.6),Vector3(-13,1,1.6),Vector3(-11.94,1,1.6),Vector3(-11.94,1,2.5),Vector3(-11.94,1,4)]:
		var ray:=PhysicsRayQueryParameters3D.create(world.ORIGIN+point,world.ORIGIN+point-Vector3.UP*2);ray.exclude=[world.player.get_rid()]
		assert(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Floor missing under repaired corridor")
	var center: Vector3 = world.ORIGIN + Vector3(-11.94, 1, 2.0)
	var edges := []
	for side in [-1, 1]:
		var ray := PhysicsRayQueryParameters3D.create(center, center + Vector3(0, 0, side * 2.0))
		ray.exclude = [world.player.get_rid()]
		var hit = world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): edges.append(hit.position.z-world.ORIGIN.z)
	print("SERVER NORTH CORRIDOR wall edges z=", edges)
	world.queue_free()
	await process_frame
	quit(0)
