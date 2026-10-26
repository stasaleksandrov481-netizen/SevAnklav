extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G"); game.set_meta("qa8",true); game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave); state.data.awake=true
	var world=load("res://iso/bunker_world.tscn").instantiate(); root.add_child(world)
	await physics_frame; await physics_frame
	for id in world.rooms: state.data.visited[id]=true
	for i in range(10): world._process(0.071)
	for moving in [false,true]:
		var start:=Time.get_ticks_usec()
		for i in range(1000):
			if moving: world.player.position.x+=0.001
			world._process(0.071)
		print("VISIBILITY_CPU_US moving=",moving," mean=",(Time.get_ticks_usec()-start)/1000.0)
	quit()
