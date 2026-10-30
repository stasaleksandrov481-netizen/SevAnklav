extends SceneTree
# Development tool. Final positions are saved in the authored furnishing JSON.
func _initialize():call_deferred("run")
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var saved=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");saved.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 20:await physics_frame
 w.paused=true;w.player.set_physics_process(false)
 var f=w.get_node("LevelMinusTwo/Furnishings");var moved={};var space=w.get_world_3d().direct_space_state
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://iso/maps/level2/furnishing.json"))
 for entry in data.items:
  if entry.kind not in ["pc","desk","bench"]:continue
  var p=f.authored[entry.id];var exclude:Array[RID]=[]
  for body in p.get_children():
   if body is StaticBody3D:exclude.append(body.get_rid())
  var back:Vector3=-p.global_basis.z;var start:Vector3=p.global_position+Vector3.UP*.48
  var ray=PhysicsRayQueryParameters3D.create(start,start+back*2.5);ray.exclude=exclude
  var hit=space.intersect_ray(ray)
  if hit.is_empty() or not str(hit.collider.get_path()).contains("WallMesh"):continue
  var gap:float=start.distance_to(hit.position)-.375
  if gap<.12:continue
  var delta=back*(gap-.10);var target:Vector3=p.global_position+delta
  var query=PhysicsShapeQueryParameters3D.new();var shape=BoxShape3D.new();shape.size=Vector3(1.6,.85,.75)
  query.shape=shape;query.exclude=exclude;query.margin=.005;query.transform=Transform3D(p.global_basis,target+Vector3.UP*.425)
  if not space.intersect_shape(query,1).is_empty():continue
  entry.x+=delta.x;entry.z+=delta.z;moved[entry.id]=delta
  print("ALIGNED ",entry.id," move=",delta)
 for entry in data.items:
  if entry.has("faces") and moved.has(entry.faces):entry.x+=moved[entry.faces].x;entry.z+=moved[entry.faces].z
  if entry.id=="serov_tools_box" and moved.has("workshop_bench_b"):entry.x+=moved.workshop_bench_b.x;entry.z+=moved.workshop_bench_b.z
 var file=FileAccess.open("res://iso/maps/level2/furnishing.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"  ",false)+"\n");file.close()
 print("ALIGN PASS ",moved.size()," workstations; matching seats and the tool case follow their actual surfaces")
 w.queue_free()
 for i in 8:await process_frame
 quit()
