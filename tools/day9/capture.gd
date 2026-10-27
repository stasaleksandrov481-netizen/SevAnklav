extends SceneTree
var world
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G")
	game.set_meta("qa8",true)
	game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave)
	state.data.awake=true
	state.data.slots={"left":state.item("flashlight"),"right":state.item("pistol"),"quick0":state.item("medkit",2),"quick1":state.item("band",3)}
	state.data.flags["power"]=true
	world=load("res://iso/bunker_world.tscn").instantiate(); root.add_child(world)
	await process_frame
	for enemy in world.enemies: enemy.set_physics_process(false); enemy.set_process(false)
	var clip:=OS.get_environment("ANKLAV_CLIP")
	world.player.position=world.ORIGIN+Vector3(-24,0.95,-8.3)
	if clip=="staff": world.player.position=world.ORIGIN+Vector3(-12,0.95,1.5)
	if clip=="interaction":
		for action in world.stations:
			if action.kind=="terminal":
				world.player.global_position=action.node.global_position+Vector3(0,0.95,1.2)
				break
	var camera=world.get_node("Camera")
	camera.position=world.player.position+camera._offset
	world.hud.root.visible=clip in ["ui","interaction"]
	for frame in range(30): await process_frame
	for frame in range(150):
		if clip not in ["ui","interaction"]: Input.action_press("move_up",0.3); Input.action_press("move_right",0.2)
		if clip=="interaction" and frame==75: world.interact()
		if clip=="ui" and frame==60: world.hud.open_inventory()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame==45: root.get_texture().get_image().save_png(OS.get_environment("ANKLAV_SHOT"))
	print("DAY9_CAPTURE_OK ",clip)
	quit()
