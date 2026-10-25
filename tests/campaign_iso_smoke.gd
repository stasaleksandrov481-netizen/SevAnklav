extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	root.get_node("G").set_meta("qa8", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.boot_loading7_done = true
	root.add_child(main)
	await process_frame
	await process_frame
	var menu: Node = main.current_screen
	if menu == null or menu.has_signal("iso_pressed") or menu.has_signal("atlas_pressed"):
		push_error("Main menu still exposes prototype buttons")
		quit(1)
		return
	main.start_new_iso_campaign()
	await process_frame
	if not main.current_screen is CanvasLayer or main.current_screen == menu:
		push_error("New game did not start the story prologue")
		quit(1)
		return
	main._enter_iso_world()
	await process_frame
	var world: Node = main.current_screen
	if world == null or not world.has_node("CampaignHUD") or world.get_node("Sectors").get_child_count() != 1:
		push_error("Isometric campaign world did not start")
		quit(1)
		return
	print("CAMPAIGN_ISO_OK menu->prologue->underground bunker, HUD")
	quit(0)
