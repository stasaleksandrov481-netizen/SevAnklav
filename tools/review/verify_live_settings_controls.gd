extends SceneTree
var Pages: Script
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
	if not ok:push_error(message);quit(1);return false
	checks+=1;return true
func frames(n):
	for i in n:await process_frame
func rect(node:Control)->Rect2:return node.get_global_transform()*Rect2(Vector2.ZERO,node.size)
func press(stick,index:int,point:Vector2):
	var e=InputEventScreenTouch.new();e.index=index;e.pressed=true;e.position=point;stick._gui_input(e)
func release(stick,index:int):
	var e=InputEventScreenTouch.new();e.index=index;e.pressed=false;stick._input(e)
func run():
	Pages=load("res://scripts/ui/cinematic_pages.gd")
	var original:bool=quit_on_go_back
	var game=root.get_node("G");game.zsave=game._default_zsave()
	var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=true
	var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
	for i in 12:await physics_frame
	w.player.set_physics_process(false);var ui=w.hud;var visibility=w.visibility_controller;var atmosphere=w.get_node("LevelMinusTwo/Atmosphere")
	ui.pause_menu();var pause=ui.modal;var settings=Pages.open(null,ui,"settings")
	if not check(Pages.open(null,ui,"settings")==settings,"Repeated settings click created a second page"):return
	settings.settings.brightness=1.3;settings._save_settings()
	if not check(is_equal_approx(visibility.environment.ambient_light_energy,.18*1.3) and is_equal_approx(w.player.torch.light_energy,2.2*1.3),"Brightness setting did not reach the live environment and flashlight"):return
	settings.settings.brightness=.75;settings._save_settings()
	if not check(is_equal_approx(visibility.brightness,.75) and is_equal_approx(visibility.fallback.light_energy,(.55 if visibility.room_lights.is_empty() else .30)*.75),"Brightness change did not update current room lamps"):return
	var saved=ConfigFile.new()
	if not check(saved.load("user://anklav_rts.cfg")==OK and saved.get_value("zcamp","zsave").bunker_visual.brightness==.75,"Visual settings were not saved"):return
	for dimensions in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
		root.size=dimensions;await frames(8)
		for tab in ["ЗВУК","ЭКРАН","УПРАВЛЕНИЕ"]:
			settings.selected_tab=tab;settings._settings_page();await frames(4)
			var viewport_size:Vector2=settings.get_viewport_rect().size
			if not check(settings.size.x>=1599 and rect(settings).end.x<=viewport_size.x+1 and rect(settings).end.y<=viewport_size.y+1,"Settings canvas is cropped: viewport=%s page=%s scale=%s rect=%s" % [viewport_size,settings.size,settings.scale,rect(settings)]):return
			var scroll=settings.find_child("PageScroll",true,false)
			if not check(rect(scroll).end.x<=rect(settings).end.x+1 and settings.content.size.x<=scroll.size.x+1,"Settings controls overflow at "+tab):return
	root.go_back_requested.emit()
	if not check(settings.closing and ui.modal==pause and w.paused,"Native back closed the pause behind settings"):return
	root.go_back_requested.emit()
	if not check(ui.modal==pause and w.paused,"Repeated back during fade fell through to the paused world"):return
	await frames(18);root.go_back_requested.emit()
	if not check(ui.modal==null and not w.paused,"Back from the retained pause did not resume"):return
	root.size=Vector2i(1600,900);await frames(5)
	var relay=w.stations.filter(func(a):return a.id=="relay_k2")[0]
	var pump=w.stations.filter(func(a):return a.id=="pump_valve")[0]
	visibility.set_profile("balanced");visibility.switch_room(pump.room);atmosphere.sync_vapor()
	if not check(atmosphere.vapor.size()==2 and atmosphere.vapor.filter(func(e):return e.visible and e.emitting).size()==1 and atmosphere.vapor.all(func(e):return e.amount<=8),"Vapor is missing or active outside the current room"):return
	visibility.set_profile("low");atmosphere._process(.1)
	if not check(atmosphere.vapor.all(func(e):return not e.visible and not e.emitting and e.speed_scale==0),"Low graphics still simulates visible vapor"):return
	visibility.set_profile("balanced");game.zsave.bunker_visual.particles=false;visibility.apply_preferences()
	if not check(atmosphere.vapor.all(func(e):return not e.visible and not e.emitting),"Particle toggle did not disable the effect"):return
	game.zsave.bunker_visual.particles=true;visibility.apply_preferences();w.paused=true;atmosphere._process(.1)
	if not check(atmosphere.vapor.all(func(e):return e.speed_scale==0),"Particles continue moving during pause"):return
	w.paused=false;w.state.mark("pump_valve")
	if not check(atmosphere.vapor.all(func(e):return not e.visible),"Pump leak did not stop after repair"):return
	visibility.switch_room(relay.room)
	if not check(atmosphere.vapor.filter(func(e):return e.visible).size()==1,"Relay haze did not appear in its room"):return
	w.state.mark("relay_k2")
	if not check(atmosphere.vapor.all(func(e):return not e.visible),"Relay haze did not stop after repair"):return
	w.player.global_position=w.player_start;visibility.switch_room("sector_0");ui._process(0)
	var stick=ui.root.get_node("MoveStick");var point=stick.size*Vector2(.88,.5)
	var distances=[]
	for sprint in [false,true]:
		w.player.global_position=w.player_start;w.player.velocity=Vector3.ZERO;w.player.clear_controls();stick.reset()
		press(stick,2,point)
		if sprint:release(stick,2);press(stick,3,point)
		ui._process(0);var start:Vector3=w.player.global_position
		w.player.set_physics_process(true)
		for i in 55:await physics_frame
		w.player.set_physics_process(false);distances.append(w.player.global_position.distance_to(start));release(stick,3 if sprint else 2);ui._process(0)
		if not check(not w.player.sprinting and stick.get_move_vector()==Vector2.ZERO,"Sprint remained latched after release"):return
	if not check(distances[1]>distances[0]*1.2,"Double-tap sprint did not increase actual walking distance: "+str(distances)):return
	press(stick,4,point);release(stick,4);press(stick,5,point);ui._process(0);ui.open_inventory()
	if not check(not w.player.sprinting and not stick.double_held,"Opening a modal retained the sprint gesture"):return
	ui.close_modal();ui._process(0)
	w.state.data.slots={"left":w.state.item("pistol"),"bag0":w.state.item("ammo",8)};w.state.data.mag=0;w.state.data.chamber=0
	var aim=ui.root.get_node("AimStick");var aim_point=aim.size*.5
	press(aim,6,aim_point);release(aim,6);press(aim,7,aim_point)
	if not check(w.player.reload_pending and w.player.busy>0,"Double-tap aim did not request reload"):return
	release(aim,7);w.state.data.slots.left=w.state.item("pistol");w.player.busy=.01;w.player._physics_process(.02)
	if not check(not w.player.reload_pending and w.state.amount("ammo")==8 and w.state.data.mag==0,"Replacing the gun during reload consumed ammunition"):return
	w.player.reload();w.player._physics_process(1.5)
	if not check(w.state.amount("ammo")==0 and w.state.data.mag==7 and w.state.data.chamber==1,"Reloading the held gun failed"):return
	w.player.reload()
	if not check(w.player.busy==0 and not w.player.reload_pending,"Reload with no spare ammo starts a fake action"):return
	w.state.data.mag=8;w.state.data.chamber=1;w.state.give("ammo",2);w.player.reload()
	if not check(w.player.busy==0 and w.state.amount("ammo")==2,"Full magazine reload wastes time or ammo"):return
	w.state.data.slots.erase("bag0");w.state.data.mag=3;w.state.data.chamber=0;w.player.reload();w.player._physics_process(1.5)
	if not check(w.state.data.mag==2 and w.state.data.chamber==1,"Chambering an existing round requires spare ammo"):return
	w.queue_free();await frames(4)
	if not check(quit_on_go_back==original and not has_meta("anklav_native_back_router"),"Back router leaked its ownership after the last screen"):return
	print("LIVE SETTINGS CONTROLS PASS: ",checks," checks; native back stack, three layouts, brightness, particles, real sprint, reload, save")
	quit()
