extends SceneTree
func _initialize():call_deferred("run")
func run():
 var out=OS.get_environment("BUNKER_REVIEW_OUT")
 if out.is_empty():push_error("Set BUNKER_REVIEW_OUT");quit(1);return
 DirAccess.make_dir_recursive_absolute(out)
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var state=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");state.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 20:await physics_frame
 w.player.set_physics_process(false);w.player.locked=true
 var stats=[]
 for spec in [["corridor",Vector3(-16.4,.96,-4.9)],["staff",Vector3(-11,.96,-.3)],["workshop",Vector3(20.6,.96,7.4)],["cargo",Vector3(29.5,.96,7.2)],["capsule",Vector3(-27.2,.96,-4.8)]]:
  w.player.global_position=w.ORIGIN+spec[1];w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
  for i in 30:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/"+spec[0]+".png")
  stats.append({"view":spec[0],"room":w.visibility_controller.active,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
 # Same doorway from either side, with the real physical leaf open.
 var door=w.doors.filter(func(d):return d.info.id.begins_with("05_"))[0]
 door.opened=true
 for side in [-1,1]:
  w.player.global_position=door.global_transform*Vector3(0,-.29,side*1.25)
  w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
  for i in 50:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/open_door_"+str(side)+".png")
 # Isolate the requested look/turn/enter rule from previously visited rooms.
 w.state.data.visited={"sector_0":true}
 door.opened=true;w.player.global_position=door.global_transform*Vector3(0,-.29,-1.25);w.player.rig.rotation.y=0
 w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
 for i in 30:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/fov_peek.png")
 w.player.rig.rotation.y=PI
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/fov_turn.png")
 w.player.global_position=w.ORIGIN+Vector3(-11,.96,-.3)
 for i in 20:await process_frame
 w.player.global_position=door.global_transform*Vector3(0,-.29,-1.25);w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/fov_remember.png")
 w.player.global_position=w.player_start;w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
 for i in 20:await process_frame
 var terminal=w.stations.filter(func(a):return a.id=="identity_v17")[0];w.hud.open_evidence(terminal)
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/terminal.png");w.hud.close_modal()
 var camera=w.get_node("Camera");camera.set_process(false);camera.size=3.2;camera.global_position=w.player.global_position+Vector3(1.3,1.3,2.6);camera.look_at(w.player.global_position+Vector3(0,-.08,0));w.player.rig.rotation.y=.25;w.hud.root.hide()
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/volkov.png")
 var file=FileAccess.open(out+"/render_counts.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "));file.close()
 print("CAPTURE PASS ",JSON.stringify(stats))
 w.queue_free()
 for i in 8:await process_frame
 var menu=load("res://scripts/ui/main_menu.gd").new();root.add_child(menu)
 for i in 35:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/menu.png")
 menu.queue_free()
 for i in 8:await process_frame
 quit()
