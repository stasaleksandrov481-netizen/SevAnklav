extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");prior.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 10:await physics_frame
 w.player.set_physics_process(false)
 for d in w.doors:
  if not d.opened:d.request()
 for i in 90:await physics_frame
 w.paused=true
 var missing=[]
 for d in w.doors:
  for step in [-.3,0.0,.3]:
   var at=d.global_position+d.global_basis.z*step;at.y=.5
   var ray=PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*.8);ray.exclude=[w.player.get_rid()]
   var hit=w.get_world_3d().direct_space_state.intersect_ray(ray)
   if hit.is_empty() or hit.normal.y<.8:missing.append({"door":d.name,"offset":step})
 print("DOOR FLOOR missing=",missing.size()," / 75 ",JSON.stringify(missing))
 w.queue_free()
 for i in 5:await process_frame
 quit()
