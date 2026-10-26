extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G")
	game.set_meta("qa8",true)
	game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave)
	state.data.awake=true
	# Representative acquired loadout for UI screenshots; production spawn is unchanged.
	state.data.slots={"left":state.item("flashlight"),"right":state.item("pistol"),"quick0":state.item("medkit",2),"quick1":state.item("band",3),"quick2":state.item("morph"),"quick3":state.item("tool"),"bag0":state.item("ammo",24),"bag1":state.item("food",2),"bag2":state.item("water",2),"bag3":state.item("card"),"bag4":state.item("fuse"),"clothes":state.item("uniform")}
	state.data.food=68; state.data.water=74; state.data.mag=6; state.data.chamber=1; state.data.checked=true
	state.data.wounds["Левая рука"].damage=12
	state.data.records.qa={"title":"МЕДИЦИНСКИЙ СЕКТОР / V-17","body":"Восстановление сознания подтверждено.\n\nОператору: проверьте состояние пациента и дождитесь ответа контрольного поста.\n\nСВЯЗЬ С КОНТРОЛЬНЫМ ПОСТОМ ПОТЕРЯНА."}
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
	world.hud.selected="right"; world.hud.refresh_slots(); world.hud.update_details()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://zarya_inventory.png")
	world.hud.close_modal()
	world.hud.open_medical()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://zarya_medical.png")
	world.hud.open_loot({"id":"guard","title":"ТЕЛО СОТРУДНИКА ОХРАНЫ"})
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://zarya_loot.png")
	world.hud.open_pda()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://zarya_pda.png")
	print("ZARYA_VISUAL_OK")
	quit()
