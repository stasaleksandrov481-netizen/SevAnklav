extends SceneTree
func _initialize():call_deferred("run")
func run():
 var out=OS.get_environment("BUNKER_REVIEW_OUT");DirAccess.make_dir_recursive_absolute(out)
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");prior.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 8:await process_frame
 w.player.locked=true
 var stats=[]
 for spec in [["start",Vector3(-27.2,.96,-4.8)],["observation",Vector3(-28,.96,3.5)],["staff",Vector3(-11,.96,0)],["archive",Vector3(-8,.96,-10)],["lab1",Vector3(2,.96,-10)],["lab2",Vector3(15,.96,-9)],["server",Vector3(-15,.96,7)],["electrical",Vector3(-5.4,.96,7)],["generator",Vector3(4,.96,7)],["pump",Vector3(12,.96,7)],["workshop",Vector3(19,.96,7.5)],["quarantine",Vector3(18,.96,-1)],["isolation_a",Vector3(29,.96,-10)],["isolation_b",Vector3(29,.96,-3)],["control",Vector3(5,.96,-1)],["cargo",Vector3(29.8,.96,7)]]:
  w.player.global_position=w.ORIGIN+spec[1];w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
  for i in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/"+spec[0]+".png")
  var entry={"room":spec[0],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
  stats.append(entry);print("ROOM ",JSON.stringify(entry))
 var file=FileAccess.open(out+"/render_counts.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "));file.close()
 w.queue_free()
 for i in 5:await process_frame
 var menu=load("res://scripts/ui/main_menu.gd").new();root.add_child(menu)
 await create_timer(.6).timeout
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/menu.png")
 assert(menu.menu_canvas.get_node("MenuAction1").text=="CO-OP ИГРА")
 menu.menu_canvas.get_node("MenuAction1").pressed.emit();assert(menu.coop_modal!=null)
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/coop.png")
 menu.close_coop()
 var signals={"new":0,"load":0,"continue":0}
 menu.play_pressed.connect(func():signals["new"]+=1)
 menu.load_pressed.connect(func():signals["load"]+=1)
 menu.continue_pressed.connect(func():signals["continue"]+=1)
 menu.menu_canvas.get_node("MenuAction2").pressed.emit()
 menu.menu_canvas.get_node("MenuAction3").pressed.emit()
 menu.menu_canvas.get_node("MenuAction0").pressed.emit()
 assert(signals=={"new":1,"load":1,"continue":1},"Menu callbacks were reordered incorrectly")
 print("MENU PASS: co-op second, co-op dialog, New/Load/Continue callbacks")
 menu.queue_free()
 for i in 5:await process_frame
 quit()
