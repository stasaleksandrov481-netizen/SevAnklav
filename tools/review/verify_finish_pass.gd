extends SceneTree
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func frames(n:int)->void:
 for i in n:await physics_frame
func place(w,at:Vector3,yaw:float)->void:
 w.player.global_position=w.ORIGIN+at;w.player.rig.rotation.y=yaw;w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
 w.visibility_controller.switch_room(w.visibility_controller.room_for(w.player.global_position))
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");prior.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(25)
 w.player.set_physics_process(false);var v=w.visibility_controller
 var door=w.doors.filter(func(d):return d.info.id.begins_with("05_"))[0]
 var outside=door.position+Vector3(0,-.29,-1.25);var target=w.ORIGIN+door.position+Vector3(0,-.29,2.2)
 place(w,outside,0);await frames(2);v.refresh_sight()
 if not check(not v.sight.visible_at(target) and not v.can_see(target),"Closed door reveals the unvisited room"):return
 if not check(not w.state.data.visited.get("sector_2",false),"Standing outside marked staff room visited"):return
 door.opened=true;await frames(55);v.refresh_sight()
 if not check(v.can_see(target) and v.sight.visible_at(target),"Open doorway does not reveal what Volkov looks at"):return
 w.player.rig.rotation.y=PI;v.refresh_sight()
 if not check(not v.sight.visible_at(target) and not w.state.data.visited.get("sector_2",false),"A preview was remembered without entering the room"):return
 place(w,Vector3(-11,.96,-.3),PI);await frames(2);v.refresh_sight()
 if not check(w.state.data.visited.get("sector_2",false),"Entering the real room failed to remember it"):return
 place(w,outside,PI);await frames(2);v.refresh_sight()
 if not check(v.visible_rooms.has("sector_2") and v.known_image.get_pixel(3,0).r>.60,"Visited room vanished after returning to corridor"):return
 place(w,door.position+Vector3(0,-.29,0),0);v.refresh_sight()
 if not check(v.sight.visible_at(w.player.global_position),"Doorway became a blind standalone room"):return
 if not check(not w.state.data.visited.get("sector_12",false),"Unrelated room behind walls was discovered"):return
 place(w,Vector3(-11,.96,-.3),0);v.wall_controller.choose();v.wall_controller.update(.3)
 var hidden=0
 for value in v.wall_controller.fade:if value>.5:hidden+=1
 if not check(hidden>=2 and v.wall_controller.definitions.size()>20,"Whole wall sections failed to fade"):return
 var map=w.get_node("LevelMinusTwo")
 for name in ["WallMesh","SkirtMesh","CapMesh"]:
  var node=map.get_node(name)
  if not check(node.material_override.get_shader_parameter("wall_states")==v.wall_controller.texture and node.has_node("OpaqueShadow"),"Wall sides/caps lost section state or stable opaque shadow"):return
 var f=map.get_node("Furnishings");var styles={}
 for p in f.authored.values():
  if p.get_meta("furniture_kind","")=="crate":styles[p.get_meta("storage_style")]=true
 if not check(styles.size()==4,"Storage still uses a single repeated model"):return
 var rig=w.player.rig;rig.set_process(false);rig.moving=1.0
 var phase:float=rig.phase;var leg=rig.skeleton.get_bone_pose_rotation(rig.indices.leg_l)
 for i in 60:rig._process(1.0/60)
 if not check(rig.phase-phase>3 and rig.skeleton.get_bone_pose_rotation(rig.indices.leg_l).angle_to(leg)>.1,"Walking animation does not move the articulated legs"):return
 rig.moving=0
 for i in 120:rig._process(1.0/60)
 phase=rig.phase
 for i in 30:rig._process(1.0/60)
 if not check(absf(rig.phase-phase)<.002,"Idle character keeps stepping or sliding its gait"):return
 for side in ["l","r"]:
  var ankle:Vector3=rig.to_global(rig.skeleton.get_bone_global_pose(rig.indices["foot_"+side]).origin)
  if not check(ankle.y-w.ORIGIN.y>.04 and ankle.y-w.ORIGIN.y<.20,"Resting boot floats or penetrates the floor"):return
 rig.set_process(true)
 if not check(Vector2(f.authored.serov_tools_box.position.x-f.authored.workshop_bench_b.position.x,f.authored.serov_tools_box.position.z-f.authored.workshop_bench_b.position.z).length()<.05,"Serov case no longer follows its bench"):return
 var gate=w.doors.filter(func(d):return d.info.kind=="sealed")[0]
 if not check(not gate.request().is_empty() and not w.state.flag("bunker_complete"),"Exit completes before restoring reserve"):return
 var supplies=w.stations.filter(func(a):return a.id=="serov_tools")[0]
 var at:Vector3=supplies.node.global_position-w.ORIGIN;at.y=.96;at.z+=1.1
 place(w,at,PI);await frames(2);v.refresh_sight()
 if not check(w.can_interact_from(supplies,w.player.global_position),"Case cannot be reached after moving onto bench"):return
 w.interact(supplies);await frames(2)
 if not check(w.hud.modal!=null,"Actual case interaction did not open loot"):return
 w.hud.take_all(supplies);w.hud.close_modal()
 if not check(w.state.amount("fuse")==1 and w.state.amount("pistol")==1,"Taking the case lost fuse or weapon"):return
 var journal=load("res://iso/zarya/journal.gd")
 if not check(journal.next_step(w).id=="relay_k2","Weapon pickup hides the reserve objective"):return
 for id in ["relay_k2","pump_valve"]:
  var action=w.stations.filter(func(a):return a.id==id)[0]
  var point:Vector3=action.node.global_position-w.ORIGIN;point.y=.96;point.z-=1.1
  # Find a real approach rather than interacting through the servicing cabinet.
  var found=false
  for offset in [Vector3(0,0,1.25),Vector3(0,0,-1.25),Vector3(1.25,0,0),Vector3(-1.25,0,0)]:
   var p:Vector3=action.node.global_position-w.ORIGIN+offset;p.y=.96;place(w,p,0)
   if w.can_interact_from(action,w.player.global_position):found=true;break
  if not check(found,"No reachable approach to "+id):return
  w.begin_repair(action);w._advance_repair(1.1)
  if not check(w.player.locked and not w.state.flag(id),"Repair bypasses its visible timed action"):return
  w._advance_repair(1.4)
  if not check(w.state.flag(id) and not w.player.locked,"Repair fails to finish "+id):return
 if not check(w.state.amount("fuse")==0 and journal.next_step(w).id=="exit","Completed reserve does not lead to exit"):return
 var approach:Vector3=gate.global_position-w.ORIGIN-gate.global_basis.z*1.5;approach.y=.96
 if w.room_at(w.ORIGIN+approach).is_empty():approach=gate.global_position-w.ORIGIN+gate.global_basis.z*1.5;approach.y=.96
 place(w,approach,0);await frames(2);v.refresh_sight()
 if not check(w.can_interact_from({"kind":"door","node":gate},w.player.global_position),"Cargo gate cannot be reached from inside"):return
 w.interact({"kind":"door","node":gate});await frames(2)
 if not check(w.state.flag("bunker_complete") and w.hud.modal.name=="BunkerComplete","Final gate does not complete bunker"):return
 w.hud.close_modal();w.save_state()
 if not check(not w.paused and not gate.opened,"Completion strands player or exposes empty exterior"):return
 var data=prior.data.duplicate(true);w.queue_free();await frames(8)
 g.zsave.zarya_layout3=data
 w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(20)
 if not check(w.state.flag("bunker_complete") and w.state.data.visited.get("sector_2",false) and w.state.amount("fuse")==0,"Reload loses completion, explored rooms or spent fuse"):return
 w.queue_free();await frames(8)
 for audio in g._sfx_pool:audio.stop();audio.stream=null
 OS.delay_msec(80);await frames(3)
 print("FINISH PASS: ",checks," checks; ray occlusion, look/turn/enter memory, door thresholds, whole wall sections, reachable case, real repairs, final gate and reload")
 quit()
