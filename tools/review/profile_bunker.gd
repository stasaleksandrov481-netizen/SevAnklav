extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");prior.data.awake=true
 var world=load("res://iso/bunker_world.tscn").instantiate();root.add_child(world)
 for i in 8:await process_frame
 if world.hud.modal!=null:world.hud.close_modal()
 world.player.locked=true;world.state.data.awake=true
 var results=[]
 var output=OS.get_environment("BUNKER_REVIEW_OUT")
 DirAccess.make_dir_recursive_absolute(output)
 for spec in [["capsule",Vector3(-27.2,.96,-4.8)],["observation",Vector3(-28,.96,3.5)],["corridor",Vector3(-17.4,.96,-1.0)],["lab",Vector3(3,.96,-8.5)],["quarantine",Vector3(18,.96,-1)],["technical",Vector3(-6,.96,7)]]:
  world.player.global_position=world.ORIGIN+spec[1];world.get_node("Camera").global_position=world.player.global_position+world.get_node("Camera")._offset
  for i in 12:await process_frame
  var frames=[];var process_ms=[];var physics_ms=[]
  for i in 12:
   var before=Time.get_ticks_usec();await process_frame;frames.append((Time.get_ticks_usec()-before)/1000.0)
   process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  frames.sort();process_ms.sort();physics_ms.sort()
  var visible_lights=0;var shadows=0
  for l in world.find_children("*","Light3D",true,false):
   if l.is_visible_in_tree():visible_lights+=1;shadows+=int(l.shadow_enabled)
  var entry={"location":spec[0],"median_frame_ms":frames[6],"p95_frame_ms":frames[11],"process_ms":process_ms[6],"physics_ms":physics_ms[6],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"lights":visible_lights,"shadows":shadows}
  results.append(entry);print("PROFILE ",JSON.stringify(entry))
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+"/"+spec[0]+".png")
 var file=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
 world.queue_free()
 for i in 10:await process_frame
 quit()
