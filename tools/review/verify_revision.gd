extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 12:await physics_frame
 assert(not w.state.data.awake,"Fresh game must preserve waking")
 assert(w.capsule_node().name=="V17Capsule")
 assert(w.capsule_node().get_node("Generated/Glass shell")!=null)
 assert(w.get_node("Camera").elevation_degrees==61)
 var ray=PhysicsRayQueryParameters3D.create(w.ORIGIN+Vector3(-23,1.45,-1.3),w.ORIGIN+Vector3(-23,1.45,.6))
 var window_hit=w.get_world_3d().direct_space_state.intersect_ray(ray)
 assert(not window_hit.is_empty() and window_hit.collider.get_parent().get_meta("furniture_kind","")=="glass","Observation glass missing or wall not cut")
 var v=w.visibility_controller
 assert(v.active=="sector_0")
 assert(w.get_viewport().msaa_3d==Viewport.MSAA_DISABLED,"Legacy profile overrode bunker settings")
 var total=0
 for nodes in v.visuals.values():total+=nodes.size()
 var before=w.player.global_position
 for id in ["sector_0","sector_2","sector_10"]:
  w.player.global_position=w.rooms[id].global_position+Vector3.UP*.96
  v.switch_room(id)
  assert(w.room_visible.has(id),"Current physical room is invisible")
  var shadows=0
  for light in v.lamps:shadows+=int(light.visible and light.shadow_enabled)
  assert(shadows<=v.budget,"Multiple remembered rooms exceed shadow budget")
 w.player.global_position=before
 for profile in ["low","balanced","quality"]:
  v.set_profile(profile);v.refresh_lights()
  var shadows=0
  for l in v.lamps:shadows+=int(l.visible and l.shadow_enabled)
  assert(shadows<=v.budget)
 v.set_profile("balanced");v.switch_room("sector_0")
 if w.hud.modal!=null:w.hud.close_modal()
 w.player.awaken()
 for i in 420:await physics_frame
 assert(w.state.data.awake and not w.player.locked,"Wake sequence failed")
 assert(w.player.global_position.distance_to(w.player_start)<.3)
 var origin=w.player.global_position
 w.save_state()
 var old=g.zsave[w.state_key].duplicate(true)
 w.queue_free()
 for i in 10:await process_frame
 g.zsave["zarya_layout3"]=old
 var w2=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w2)
 for i in 12:await physics_frame
 assert(w2.state.data.awake and not w2.player.locked,"Existing awake save replayed intro")
 assert(w2.player.global_position.distance_to(origin)<.3)
 print("REVISION PASS: remembered interiors, physical field of view, shadow budget, 3 profiles, awakening, old awake save. Visual groups: ",total)
 w2.queue_free()
 for i in 10:await process_frame
 quit()
