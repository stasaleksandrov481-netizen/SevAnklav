extends SceneTree
const STEP=.32
var cache={}
var space
var shape
var exclude:Array[RID]=[]
var origin:Vector3
func _initialize():call_deferred("run")
func point(cell:Vector2i)->Vector3:return origin+Vector3(-34+cell.x*STEP,.96,-14+cell.y*STEP)
func clear(cell:Vector2i)->bool:
 if cache.has(cell):return cache[cell]
 if cell.x<0 or cell.y<0 or cell.x>215 or cell.y>89:return false
 var at=point(cell)
 var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,at);q.exclude=exclude;q.margin=.008;q.collision_mask=3
 var ray=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.6,at-Vector3.UP*1.5);ray.exclude=exclude;ray.collision_mask=3
 var floor_hit=space.intersect_ray(ray)
 var valid=not floor_hit.is_empty() and floor_hit.position.y-origin.y<.10 and space.intersect_shape(q,1).is_empty()
 cache[cell]=valid;return valid
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var state=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");state.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 20:await physics_frame
 w.player.set_physics_process(false)
 for door in w.doors:
  if door.info.kind!="sealed":door.opened=true
 for i in 75:await physics_frame
 w.paused=true;space=w.get_world_3d().direct_space_state;origin=w.ORIGIN;shape=w.player.get_node("Collision").shape;exclude=[w.player.get_rid()]
 var start=Vector2i(roundi((w.player_start.x-origin.x+34)/STEP),roundi((w.player_start.z-origin.z+14)/STEP))
 if not clear(start):push_error("Spawn is blocked");quit(1);return
 var queue=[start];var parent={start:start};var found={};var cursor=0
 var targets=[]
 for id in ["identity_v17","serov_tools","relay_k2","pump_valve"]:
  var action=w.stations.filter(func(a):return a.id==id)[0];targets.append({"id":id,"at":action.node.global_position})
 var gate=w.doors.filter(func(d):return d.info.kind=="sealed")[0];targets.append({"id":"exit","at":gate.global_position})
 while cursor<queue.size():
  var cell:Vector2i=queue[cursor];cursor+=1;var at=point(cell)
  for target in targets:
   if found.has(target.id) or at.distance_to(target.at)>2.15:continue
   var ray=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.35,target.at);ray.exclude=exclude;ray.collision_mask=3
   var hit=space.intersect_ray(ray)
   if hit.is_empty() or (target.id=="exit" and hit.collider==gate.leaf):found[target.id]=cell
  if found.size()==targets.size():break
  for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next=cell+offset
   if parent.has(next) or not clear(next):continue
   var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,at);q.motion=point(next)-at;q.exclude=exclude;q.margin=.008;q.collision_mask=3
   if space.cast_motion(q)[0]<.999:continue
   parent[next]=cell;queue.append(next)
  if cursor%700==0:await process_frame
 if found.size()!=targets.size():push_error("Unreachable bunker targets: "+str(targets.filter(func(t):return not found.has(t.id))));quit(1);return
 var routes={}
 for id in found:
  var path=[];var cell:Vector2i=found[id]
  while cell!=start:
   var at=point(cell)-origin;path.append([snappedf(at.x,.001),snappedf(at.z,.001)]);cell=parent[cell]
  path.reverse();routes[id]=path
 var report={"reachable_cells":parent.size(),"capsule_radius":shape.radius,"step":STEP,"routes":routes}
 var out=OS.get_environment("BUNKER_REVIEW_OUT")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out);var file=FileAccess.open(out+"/walkable_routes.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("WALKABLE ROUTE PASS: ",parent.size()," reachable cells; spawn to medical PC, Serov case, relay, pump and exit; every step sweeps the real player capsule")
 w.queue_free()
 for i in 8:await process_frame
 quit()
