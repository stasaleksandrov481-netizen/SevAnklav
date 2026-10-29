extends SceneTree
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
	if not ok:push_error(message);quit(1);return false
	checks+=1;return true
func frames(n):
	for i in n:await process_frame
func rect(node:Control)->Rect2:return node.get_global_transform()*Rect2(Vector2.ZERO,node.size)
func prologue(main):
	for child in main.current_screen.get_children():
		if child.get_script()==load("res://scripts/zprologue_zarya.gd"):return child
	return null
func run():
	var original:bool=quit_on_go_back
	var game=root.get_node("G");game.zsave=game._default_zsave();game.zsave.bunker_visual={"brightness":1.2,"particles":false,"haptics":false}
	game.save.commander="DO NOT RESET";var war:Dictionary=game.save.duplicate(true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await frames(110)
	var menu=main.current_screen
	if not check(menu.get_script()==load("res://scripts/ui/main_menu.gd") and main.loading_layer==null,"Boot still waits artificially or did not reach menu"):return
	if not check(menu.menu_canvas.get_node("MenuAction0").disabled and menu.menu_canvas.get_node("MenuAction3").disabled,"Continue/load enabled without progress"):return
	menu.menu_canvas.get_node("MenuAction1").pressed.emit()
	if not check(menu.coop_modal!=null,"Co-op is no longer the second menu button"):return
	root.go_back_requested.emit()
	if not check(menu.coop_modal==null and menu.confirm_modal==null,"Native back from co-op opened an exit dialog"):return
	root.go_back_requested.emit()
	if not check(menu.confirm_modal!=null and menu.confirm_modal.get_meta("kind")=="quit","Root-menu back exits without confirmation"):return
	root.go_back_requested.emit()
	if not check(menu.confirm_modal==null and not menu.transitioning,"Cancelling exit left menu disabled"):return
	menu.menu_canvas.get_node("MenuAction2").pressed.emit();await frames(5)
	var intro=prologue(main)
	if not check(intro!=null and not game.zsave.seen_prologue,"New game did not enter its prologue"):return
	if not check(game.zsave.bunker_visual.brightness==1.2 and not game.zsave.bunker_visual.haptics and game.save==war,"New game reset settings or touched the second campaign"):return
	intro.reveal=1;intro._process(0);intro.choices.get_child(1).pressed.emit();await frames(22)
	if not check(intro.step==1 and game.zsave.intro_step==1,"Prologue choice was not persisted"):return
	root.go_back_requested.emit();await frames(6)
	menu=main.current_screen
	if not check(menu.get_script()==load("res://scripts/ui/main_menu.gd") and not menu.menu_canvas.get_node("MenuAction0").disabled,"Back from prologue lost the continuation path"):return
	menu.menu_canvas.get_node("MenuAction0").pressed.emit();await frames(5);intro=prologue(main)
	if not check(intro.step==1 and intro.branch=="listen","Continue replayed the introduction from its beginning"):return
	for dimensions in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
		root.size=dimensions;await frames(8)
		var viewport_size:Vector2=intro.get_viewport_rect().size
		if not check(rect(intro).end.x<=viewport_size.x+1 and rect(intro).end.y<=viewport_size.y+1 and rect(intro.body).end.x<=rect(intro).end.x+1,"Prologue overflows on resize"):return
	root.size=Vector2i(1600,900)
	intro.reveal=1;intro._process(0);intro.choices.get_child(0).pressed.emit();await frames(22)
	intro.reveal=1;intro._process(0);intro.choices.get_child(0).pressed.emit()
	await frames(130)
	var w=main.current_screen
	if not check(w.get_script()==load("res://iso/zarya/level.gd") and w.hud!=null,"The actual intro-to-bunker flow is broken"):return
	for i in 400:await physics_frame
	if not check(w.state.data.awake and not w.player.locked and w.hud.modal==null,"Player remains stuck in capsule after the full intro"):return
	w.visibility_controller.set_profile("low");w.state.data.records.flow_test={"title":"Проверка","body":"Сохранено"};w.save_state()
	main.to_main_menu();await frames(6);menu=main.current_screen
	var before:Dictionary=game.zsave.duplicate(true);menu.menu_canvas.get_node("MenuAction2").pressed.emit()
	if not check(menu.confirm_modal!=null and game.zsave==before,"New-game button destroys progress before confirmation"):return
	var retired_accept=menu.confirm_modal.find_child("ConfirmAccept",true,false)
	root.go_back_requested.emit()
	if not check(menu.confirm_modal==null and game.zsave==before,"Cancelling restart changed progress"):return
	retired_accept.pressed.emit()
	if not check(not menu.transitioning and game.zsave==before,"A cancelled confirmation still accepts a stale click"):return
	menu.menu_canvas.get_node("MenuAction0").pressed.emit();await frames(15);w=main.current_screen
	if not check(w.state.data.awake and w.state.data.records.has("flow_test"),"Continue lost the awake player or collected records"):return
	main.to_main_menu();await frames(6);menu=main.current_screen
	menu.menu_canvas.get_node("MenuAction2").pressed.emit();var accept=menu.confirm_modal.find_child("ConfirmAccept",true,false)
	var events={"count":0};menu.play_pressed.connect(func():events.count+=1)
	accept.pressed.emit();accept.pressed.emit();await frames(5)
	if not check(events.count==1 and not game.zsave.zarya_layout3.awake and game.zsave.zarya_layout3.records.is_empty(),"Confirming restart launches twice or retains the old run"):return
	if not check(game.zsave.bunker_visual.brightness==1.2 and game.zsave.zarya_layout3.graphics_profile=="low" and game.save==war,"Confirmed restart reset preferences or another campaign"):return
	main.queue_free();await frames(5)
	if not check(quit_on_go_back==original and not has_meta("anklav_native_back_router"),"Full scene transitions leaked back navigation ownership"):return
	# Fixed-fps simulation outruns the real audio mixer. Flush its pending click
	# before ending the test, while the engine and its audio thread are still alive.
	for player in game._sfx_pool:player.stop();player.stream=null
	OS.delay_msec(80);await frames(3)
	print("GLOBAL FLOW PASS: ",checks," checks; real boot, menu, confirmation, saved intro choices, capsule, continue and new-game preferences")
	quit()
