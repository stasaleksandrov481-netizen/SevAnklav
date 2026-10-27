extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G"); game.set_meta("qa8",true); game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave); state.data.awake=true
	var world=load("res://iso/bunker_world.tscn").instantiate(); root.add_child(world)
	await process_frame; await process_frame
	var ui=world.hud
	var failures:=0
	for kind in ["terminal","record","loot","locked"]:
		var found:=false
		for target in world.stations:
			if target.kind!=kind: continue
			world.player.global_position=target.node.global_position
			ui._update_interaction(); ui._update_world_marker()
			var button=ui.root.get_node("Interact")
			var expected="terminal" if kind in ["terminal","record"] else "search"
			if button.disabled or button.icon!=ui.interaction_icons[expected] or ui.interaction_hint.text!=target.title: failures+=1
			found=true; break
		if not found: failures+=1
	world.player.global_position=world.ORIGIN+Vector3(200,1,200)
	ui._update_interaction(); ui._update_world_marker()
	if not ui.root.get_node("Interact").disabled or ui.interaction_hint.text!="" or ui.interaction_marker.visible: failures+=1
	ui.open_inventory(); ui._update_world_marker()
	if ui.interaction_marker.visible: failures+=1
	print("DAY9_INTERACTION_CHECKS 6 FAILED ",failures)
	quit(1 if failures else 0)
