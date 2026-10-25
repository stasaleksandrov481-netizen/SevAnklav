extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = root.get_node("G")
	game.set_meta("qa8", true)
	game.zsave = game._default_zsave()
	var world: Node3D = load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	var hud: CanvasLayer = preload("res://iso/campaign_hud.gd").new()
	world.add_child(hud)
	await process_frame
	var names := ["Terminal", "ServiceDoor", "SecurityDesk", "Locker", "GeneratorConsole", "ExitAirlock"]
	for index in range(names.size()):
		var point: Node3D = world.get_node("Sectors/Sector_55_45/Bunker/" + names[index])
		world.get_node("Volkov").global_position = point.global_position + Vector3(0, 0.95, 0.5)
		hud._find_nearest()
		hud._interact()
		if int(game.zsave.get("iso_objective", 0)) != index + 1:
			push_error("Story interaction failed at " + names[index])
			quit(1)
			return
	if int(game.zsave.get("sector", 0)) != 1:
		push_error("Bunker exit did not unlock region")
		quit(1)
		return
	print("STORY_INTERACTION_OK six story actions, inventory, exit into region")
	quit(0)
