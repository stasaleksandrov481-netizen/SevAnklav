extends SceneTree
const STEP=.5
const SIZE=Vector2i(140,60)
func _initialize():call_deferred("verify")
func at(cell: Vector2i) -> Vector3:return Vector3(-34+cell.x*STEP,1,-15+cell.y*STEP)
func id(cell: Vector2i) -> int:return cell.x*SIZE.y+cell.y
func verify():
 var game=root.get_node("G");game.set_meta("qa8",true);game.zsave=game._default_zsave()
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in range(30):await physics_frame
 if w.hud.modal!=null:w.hud.close_modal()
 w.state.data.awake=true;w.player.locked=true;w.player.global_position=w.player_start
 for door in w.doors:
  if not door.opened:door.request()
 for i in range(90):await physics_frame
 w.paused=true
 var space=w.get_world_3d().direct_space_state;var graph=AStar2D.new()
 var q=PhysicsShapeQueryParameters3D.new();q.shape=w.player.get_node("Collision").shape;q.exclude=[w.player.get_rid()];q.margin=.02
 var floor_ray=PhysicsRayQueryParameters3D.new();floor_ray.exclude=[w.player.get_rid()]
 for x in range(SIZE.x):
  for z in range(SIZE.y):
   var cell=Vector2i(x,z);var pos=w.ORIGIN+at(cell);q.transform=Transform3D(Basis.IDENTITY,pos)
   if not space.intersect_shape(q,1).is_empty():continue
   floor_ray.from=pos;floor_ray.to=pos-Vector3.UP*1.2
   if not space.intersect_ray(floor_ray).is_empty():graph.add_point(id(cell),Vector2(x,z))
 for x in range(SIZE.x):
  for z in range(SIZE.y):
   var cell=Vector2i(x,z)
   if not graph.has_point(id(cell)):continue
   for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
    var next=cell+offset
    if next.x>=SIZE.x or next.y>=SIZE.y or not graph.has_point(id(next)):continue
    q.transform=Transform3D(Basis.IDENTITY,w.ORIGIN+at(cell));q.motion=at(next)-at(cell)
    if space.cast_motion(q)[0]>.99:graph.connect_points(id(cell),id(next))
 var pos:Vector3=w.player_start-w.ORIGIN
 var start=Vector2i(roundi((pos.x+34)/STEP),roundi((pos.z+15)/STEP))
 assert(graph.has_point(id(start)))
 var passed=0
 for action in w.stations:
  w.visibility_controller.switch_room(action.room)
  var local:Vector3=action.node.global_position-w.ORIGIN;var target=Vector2i(roundi((local.x+34)/STEP),roundi((local.z+15)/STEP));var reached=false
  for x in range(-4,5):
   if reached:break
   for z in range(-4,5):
    var cell=target+Vector2i(x,z)
    if cell.x<0 or cell.y<0 or cell.x>=SIZE.x or cell.y>=SIZE.y or not graph.has_point(id(cell)):continue
    if not w.can_interact_from(action,w.ORIGIN+at(cell)):continue
    if not graph.get_id_path(id(start),id(cell)).is_empty():reached=true;break
  print("ROUTE ",action.id," ",reached)
  assert(reached,"Interaction unreachable")
  passed+=1
 print("ROUTES PASS ",passed," / ",w.stations.size(),"; floor, capsule sweep and interaction sightline")
 w.queue_free();await process_frame;quit()
