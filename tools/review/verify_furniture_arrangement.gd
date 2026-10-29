extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var state=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");state.data.awake=true
 var scene=load("res://iso/bunker_world.tscn");var w=scene.instantiate();root.add_child(w)
 for i in 10:await physics_frame
 w.paused=true;w.player.set_physics_process(false)
 var f=w.get_node("LevelMinusTwo/Furnishings")
 print("AUTHORED ",f.authored.size()," SKIPPED ",f.skipped_ids)
 assert(f.skipped_ids.is_empty(),"A staged piece was silently skipped")
 var seats=0;var overlaps=0;var space=w.get_world_3d().direct_space_state
 for id in f.authored:
  var p=f.authored[id]
  if p.has_meta("faces"):
   var target=f.authored[str(p.get_meta("faces"))]
   var direction:Vector3=target.global_position-p.global_position;direction.y=0
   assert(p.global_basis.z.normalized().dot(direction.normalized())>.94,"Seat faces away from desk: "+id)
   seats+=1
  for body in p.get_children():
   if not body is StaticBody3D:continue
   var c=body.get_child(0);var q=PhysicsShapeQueryParameters3D.new();q.shape=c.shape;q.transform=c.global_transform;q.exclude=[body.get_rid()];q.margin=-.015
   for hit in space.intersect_shape(q,16):
    var other=hit.collider.get_parent()
    if other.has_meta("furniture_kind") or str(hit.collider.get_path()).contains("WallMesh"):
     print("OVERLAP ",id," / ",other.name);overlaps+=1
 assert(overlaps==0,"Staged furniture intersects")
 var attached=0
 for a in w.stations:
  if a.has("anchor"):
   assert(f.authored.has(a.anchor),"Missing physical anchor")
   assert(a.node.global_position.distance_to(f.authored[a.anchor].global_position)<1.8)
   attached+=1
 assert(attached>=10)
 var wheel=f.valve_wheel
 assert(wheel.get_child_count()==3)
 f.set_repair_progress("pump_valve",.5);assert(is_equal_approx(wheel.rotation.y,PI*.75))
 w.state.mark("pump_valve");w.save_state()
 w.queue_free()
 for i in 5:await process_frame
 # Existing save inside a moved workstation must recover locally, preserving progress.
 var data=state.data;data.position=[-12.2,.96,-2.6];data.map_spawned=true;data.awake=true;data.flags["arrangement_sentinel"]=true
 w=scene.instantiate();root.add_child(w)
 for i in 12:await physics_frame
 assert(w.get_meta("spawn_recovered",false),"Old save left inside furniture")
 var delta:Vector3=w.player.global_position-w.ORIGIN-Vector3(-12.2,.96,-2.6)
 assert(Vector2(delta.x,delta.z).length()<=2.51 and Vector2(delta.x,delta.z).length()>=.4)
 assert(w.room_at(w.player.global_position)=="sector_2")
 assert(w.state.flag("arrangement_sentinel") and w.state.flag("pump_valve"),"Recovery reset progress")
 assert(not w.player.locked)
 w.queue_free()
 for i in 5:await process_frame
 data.position=[-11,.96,-.2]
 w=scene.instantiate();root.add_child(w)
 for i in 12:await physics_frame
 assert(not w.get_meta("spawn_recovered",false),"Clear saved position moved unnecessarily")
 assert(Vector2(w.player.position.x-w.ORIGIN.x+11,w.player.position.z-w.ORIGIN.z+.2).length()<.02)
 print("ARRANGEMENT PASS: ",seats," seats face desks; ",attached," attached clues/containers; no prop/wall overlaps; real valve; safe old-save recovery")
 w.queue_free()
 for i in 5:await process_frame
 quit()
