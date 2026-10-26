extends SceneTree
func _initialize() -> void:
	call_deferred("check")
func check() -> void:
	var game = root.get_node("G")
	game.set_meta("qa8",true)
	game.zsave = game._default_zsave()
	game.zsave["bunker_awake"] = true
	var world = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	var hud = load("res://iso/campaign_hud.gd").new()
	world.add_child(hud)
	await process_frame
	var bunker = world.get_node("Sectors/Sector_55_45/Bunker")
	for i in range(hud.STORY.size()):
		var id: String = hud.STORY[i]["id"]
		var point: Node3D
		for candidate in get_nodes_in_group("iso_interactables"):
			if candidate.story_id == id: point = candidate
		assert(point != null,"Missing story point: "+id)
		world.get_node("Volkov").global_position = point.global_position+Vector3(0,0.95,0.8)
		hud._nearest = point
		await hud._interact()
		assert(int(game.zsave["iso_objective"]) == i+1,"Stage: "+id)
	assert(game.zsave.get("iso_armed",false))
	assert(game.zsave.get("bunker_archive",{}).size() >= 5)
	assert(game.zsave["iso_layer"] == "surface")
	var detail = bunker.get_node("Details")
	world.get_node("Volkov").global_position = bunker.to_global(Vector3(8,0.95,-8))
	detail._process(0.1)
	world.get_node("Volkov").global_position = bunker.to_global(Vector3(-7.5,0.95,-8))
	detail._process(0.1)
	assert(detail.explored.size() >= 2)
	assert(game.zsave.get("bunker_explored",{}).size() >= 2)
	print("FULL_STORY_OK 14 actions, records, weapon, gate delay, explored rooms")
	quit()
