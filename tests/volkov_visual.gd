extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1400,1000)
	var scene:=Node3D.new(); root.add_child(scene)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(2.7,1.65,4.3); camera.look_at(Vector3(0,.03,0)); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2.7; camera.current=true
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("#18222b"); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("#a3b6c3"); env.environment.ambient_light_energy=.6; scene.add_child(env)
	var key:=OmniLight3D.new(); key.position=Vector3(-2,3,3); key.omni_range=10; key.light_energy=3; scene.add_child(key)
	var rim:=OmniLight3D.new(); rim.position=Vector3(2,2,-2); rim.omni_range=8; rim.light_energy=2; rim.light_color=Color("#7d9eaf"); scene.add_child(rim)
	var rig=load("res://iso/characters/volkov.gd").new(); scene.add_child(rig)
	for frame in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://volkov_standing.png")
	rig.moving=1; rig.aiming=true; rig.weapon.visible=true
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://volkov_aim.png")
	DirAccess.make_dir_recursive_absolute("/tmp/volkov_frames")
	rig.set_process(false)
	for frame in range(240):
		rig.moving=1.0 if frame<65 else (1.6 if frame<110 else 0.0)
		rig.aiming=frame>=110; rig.rotation.y=sin(frame*.012)*.4
		if frame==135: rig.perform("shoot")
		if frame==155: rig.perform("reload")
		rig._process(1.0/30)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/volkov_frames/%04d.png"%frame)
	print("VOLKOV_VISUAL_OK"); quit()
