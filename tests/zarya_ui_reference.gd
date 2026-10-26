extends SceneTree
var failures:=0
var checks:=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G"); game.set_meta("qa8",true); game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave); state.data.awake=true
	var world=load("res://iso/bunker_world.tscn").instantiate(); root.add_child(world)
	await process_frame; await process_frame
	var ui=world.hud
	check(not ui.bars.has("health"),"Health bar removed")
	check(ui.bars.size()==2,"Food and water retained")
	check(ui.hud_body.position.y<200,"Health silhouette is visible at top")
	var left=ui.root.get_node("MoveStick"); var right=ui.root.get_node("AimStick")
	var touch:=InputEventScreenTouch.new(); touch.index=1; touch.position=Vector2(220,120); touch.pressed=true; left._gui_input(touch)
	touch=InputEventScreenTouch.new(); touch.index=2; touch.position=Vector2(120,20); touch.pressed=true; right._gui_input(touch)
	check(left.get_move_vector().length()>0.5 and right.get_move_vector().length()>0.5,"Independent simultaneous sticks")
	ui.open_inventory(); await process_frame
	check(left.get_move_vector()==Vector2.ZERO and right.get_move_vector()==Vector2.ZERO,"Opening overlay releases both sticks")
	check(world.paused,"Inventory pauses simulation")
	state.give("pistol"); state.give("flashlight"); state.give("band",3)
	ui.selected="bag0"; ui.update_details()
	check(ui.detail_title.text.contains("ПМ"),"Selected item details resolve")
	var source
	for cell in ui.slots:
		if cell.key=="left": source=cell
	source._drop_data(Vector2.ZERO,"bag0")
	check(state.data.slots.left.id=="pistol","Drag equips left hand")
	check(source.icon!=null,"Hand refreshes immediately")
	check(state.equip("bag1"),"Other hand remains usable")
	ui.close_modal(); await process_frame
	check(not world.paused and left.visible,"Closing restores HUD and simulation")
	state.data.containers["ui_loot"]=[state.item("ammo",12)]
	var action={"id":"ui_loot","title":"ТЕЛО СОТРУДНИКА"}
	ui.open_loot(action); await process_frame
	ui.transfer(action,0); await process_frame
	check(state.amount("ammo")==12 and state.data.containers.ui_loot.is_empty(),"Loot transfers once")
	ui.open_loot(action); await process_frame
	check(state.data.containers.ui_loot.is_empty(),"Reopening keeps body empty")
	state.data.records.test={"title":"ЗАПИСЬ 01","body":"Тест записи"}; ui.open_pda(); await process_frame
	check(is_instance_valid(ui.modal),"PDA record browser opens")
	ui.open_medical(); await process_frame
	check(is_instance_valid(ui.modal),"Medical panel opens")
	ui.close_modal(); await process_frame
	for resolution in [Vector2i(1280,720),Vector2i(2340,1080),Vector2i(1024,768)]:
		root.size=resolution; await process_frame; ui._fit_canvas()
		var end: Vector2=ui.root.position+Vector2(1600,900)*ui.root.scale
		var logical_size:=root.get_visible_rect().size
		check(end.x<=logical_size.x+1 and end.y<=logical_size.y+1,"HUD fits "+str(resolution))
		var right_edge: float=ui.root.get_node("AimStick").get_global_rect().end.x
		var available: float=logical_size.x-right_edge
		check(available<40*ui.root.scale.x,"Right stick reaches safe screen edge "+str(resolution))
		check(ui.root.position.x<1,"No fixed-width horizontal letterboxing "+str(resolution))
	print("ZARYA_UI_CHECKS ",checks," FAILED ",failures)
	quit(1 if failures else 0)
