extends SceneTree
func _initialize():call_deferred("verify")
func approach(w,action):
 w.paused=false;w.player.locked=false;w.player.set_physics_process(false)
 w.visibility_controller.switch_room(action.room)
 var q=PhysicsShapeQueryParameters3D.new();q.shape=w.player.get_node("Collision").shape;q.exclude=[w.player.get_rid()]
 for x in range(-8,9):
  for z in range(-8,9):
   var pos:Vector3=action.node.global_position+Vector3(x*.25,0,z*.25);pos.y=1;q.transform=Transform3D(Basis.IDENTITY,pos)
   if w.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty() and w.can_interact_from(action,pos):w.player.global_position=pos;return
 assert(false,"No interaction position")
func verify():
 var g=root.get_node("G");g.set_meta("qa8",true);g.zsave=g._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");prior.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in range(30):await physics_frame
 w.paused=true
 var f=w.get_node("LevelMinusTwo/Furnishings")
 print("FURNITURE ",w.get_meta("furniture_count")," actions ",w.stations.size())
 var overlaps=0
 for p in f.get_children():
  if not p is Node3D or not p.has_meta("furniture_kind"):continue
  for body in p.get_children():
   if not body is StaticBody3D:continue
   var c=body.get_child(0);var q=PhysicsShapeQueryParameters3D.new();q.shape=c.shape;q.transform=c.global_transform;q.exclude=[body.get_rid()];q.margin=-0.01
   for hit in w.get_world_3d().direct_space_state.intersect_shape(q):
    if str(hit.collider.get_path()).contains("WallMesh"):
     print("WALL_OVERLAP ",p.name," ",p.position);overlaps+=1
 var note=w.stations.filter(func(a):return a.kind=="evidence")[0]
 assert(overlaps==0,"Furniture intersects authored walls")
 assert(w.capsule_node().get_node("Generated/Glass shell")!=null,"Missing V-17")
 approach(w,note);w.interact(note);assert(w.state.data.records.has(note.id));assert(w.hud.modal!=null);w.hud.close_modal();w.paused=true
 var relay=w.stations.filter(func(a):return a.id=="relay_k2")[0]
 var valve=w.stations.filter(func(a):return a.id=="pump_valve")[0]
 approach(w,valve);w.interact(valve);assert(not w.state.flag("pump_valve"))
 approach(w,relay);w.interact(relay);assert(not w.state.flag("relay_k2"))
 w.state.give("fuse");w.interact(relay);w._advance_repair(w.REPAIR_SECONDS);assert(w.state.flag("relay_k2"));assert(w.state.amount("fuse")==0)
 approach(w,valve);w.interact(valve);w._advance_repair(w.REPAIR_SECONDS);assert(w.state.flag("pump_valve"))
 approach(w,relay);w.interact(relay);assert(w.state.flag("relay_k2"))
 print("FURNISHING PASS: evidence, PDA, fuse requirement, installation, valve, repeat interaction. WALL overlaps=",overlaps)
 w.queue_free();await process_frame;quit()
