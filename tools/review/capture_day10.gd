extends SceneTree
# Optional offline filming utility; it does not alter the saved project scenes.
var shot := ""
var seconds := 7
var w
var camera
var focus := Vector3.ZERO
var action := {}
var path := PackedVector3Array()
var waypoint := 1
func _initialize():call_deferred("record")
func place_player(at: Vector3) -> void:
 w.player.global_position=w.ORIGIN+at
 camera.global_position=w.player.global_position+camera._offset
 camera.look_at(w.player.global_position+Vector3.UP)
 var visibility=w.get_node_or_null("LevelMinusTwo/RoomVisibility")
 if visibility:visibility.switch_room(visibility.room_for(w.player.global_position))
func approach(target: Dictionary) -> bool:
 var visibility=w.get_node_or_null("LevelMinusTwo/RoomVisibility")
 if visibility:visibility.switch_room(target.room)
 var query=PhysicsShapeQueryParameters3D.new();query.shape=w.player.get_node("Collision").shape;query.exclude=[w.player.get_rid()];query.margin=.02
 for x in range(-8,9):
  for z in range(-8,9):
   var at: Vector3=target.node.global_position+Vector3(x*.25,0,z*.25);at.y=.96
   query.transform=Transform3D(Basis.IDENTITY,at)
   if w.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty() and w.can_interact_from(target,at):
    place_player(at-w.ORIGIN);return true
 return false
func move_towards(target: Vector3, strength := .42) -> void:
 var delta: Vector3=target-w.player.global_position;delta.y=0
 if delta.length()<.2:w.player.move_vector=Vector2.ZERO;return
 var direction=delta.normalized()*strength
 var right: Vector3=camera.global_basis.x;right.y=0;right=right.normalized()
 var forward: Vector3=-camera.global_basis.z;forward.y=0;forward=forward.normalized()
 w.player.move_vector=Vector2(direction.dot(right),-direction.dot(forward))
func medical_path() -> PackedVector3Array:
 var graph=AStar2D.new();var step=.4;var nx=35;var nz=28
 var query=PhysicsShapeQueryParameters3D.new();query.shape=w.player.get_node("Collision").shape;query.exclude=[w.player.get_rid()];query.margin=.025
 var floor_ray=PhysicsRayQueryParameters3D.new();floor_ray.exclude=[w.player.get_rid()]
 var space=w.get_world_3d().direct_space_state
 for x in nx:
  for z in nz:
   var local=Vector3(-33.2+x*step,1,-10.9+z*step);var at: Vector3=w.ORIGIN+local
   if w.room_at(at)!="sector_0":continue
   query.transform=Transform3D(Basis.IDENTITY,at)
   if not space.intersect_shape(query,1).is_empty():continue
   floor_ray.from=at;floor_ray.to=at-Vector3.UP*1.2
   if not space.intersect_ray(floor_ray).is_empty():graph.add_point(x*nz+z,Vector2(local.x,local.z))
 for x in nx:
  for z in nz:
   var id=x*nz+z
   if not graph.has_point(id):continue
   for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
    var next=Vector2i(x,z)+offset;var next_id=next.x*nz+next.y
    if next.x>=nx or next.y>=nz or not graph.has_point(next_id):continue
    var a=graph.get_point_position(id);var b=graph.get_point_position(next_id)
    query.transform=Transform3D(Basis.IDENTITY,w.ORIGIN+Vector3(a.x,1,a.y));query.motion=Vector3(b.x-a.x,0,b.y-a.y)
    if space.cast_motion(query)[0]>.99:graph.connect_points(id,next_id)
 var start=graph.get_closest_point(Vector2(-27.2,-4.8))
 var pending=[start];var seen={};seen[start]=true;var finish=start;var best=0.0
 while not pending.is_empty():
  var id=pending.pop_front()
  var distance=graph.get_point_position(start).distance_to(graph.get_point_position(id))
  if distance>best:best=distance;finish=id
  for next in graph.get_point_connections(id):
   if not seen.has(next):seen[next]=true;pending.append(next)
 var out=PackedVector3Array()
 for p in graph.get_point_path(start,finish):out.append(w.ORIGIN+Vector3(p.x,.96,p.y))
 print("WALK PLAN nodes=",out.size()," span=",best)
 return out
func record():
 shot=OS.get_environment("DAY10_SHOT");seconds=int(OS.get_environment("DAY10_SECONDS"));if seconds<=0:seconds=7
 var game=root.get_node("G");game.set_meta("qa8",true);game.zsave=game._default_zsave()
 if shot.ends_with("menu") or shot=="after_menu_coop":
  var menu=load("res://scripts/ui/main_menu.gd").new();root.add_child(menu)
  for i in 30:await process_frame
  print("CLIP START ",shot)
  for frame in seconds*30:
   if shot=="after_menu_coop" and frame==75:menu.menu_canvas.get_node("MenuAction1").pressed.emit()
   await process_frame
  finish();return
 var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=shot!="after_capsule"
 if shot=="after_pump":prior.data.flags.relay_k2=true
 w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);camera=w.get_node("Camera")
 for i in 8:await physics_frame
 if w.hud.modal!=null:w.hud.close_modal()
 w.paused=false;w.player.set_physics_process(false);camera.set_process(false)
 focus=Vector3(-27.2,.96,-4.8)
 if shot.contains("workshop"):focus=Vector3(19,.96,7.5)
 elif shot.contains("archive"):focus=Vector3(-8,.96,-10)
 elif shot.contains("laboratory"):focus=Vector3(2,.96,-10)
 elif shot=="after_door":focus=Vector3(-25.5,.96,-2.0)
 elif shot=="after_capsule":focus=Vector3(-27.2,.96,-5.7)
 var ui_shot=shot in ["after_pda","after_inventory","after_medical","after_quickslot"]
 if not ui_shot:w.hud.root.hide();w.hud.set_process(false)
 place_player(focus)
 if shot=="after_walk":
  path=medical_path()
  if path.size()<2:push_error("No connected filming path");quit(1);return
  w.player.global_position=path[0];focus=w.player.global_position-w.ORIGIN
 if shot in ["after_relay","after_pump"]:
  action=w.stations.filter(func(a):return a.id==("relay_k2" if shot=="after_relay" else "pump_valve"))[0]
  if shot=="after_relay":w.state.give("fuse")
  if not approach(action):push_error("Repair filming position inaccessible");quit(1);return
  focus=w.player.global_position-w.ORIGIN;camera.size=10;camera.desired_size=10
 if shot=="after_door":
  action={"kind":"door","node":w.doors.filter(func(d):return d.info.id.begins_with("03_"))[0],"title":"ОТКРЫТЬ ДВЕРЬ"}
  camera.size=10;camera.desired_size=10
 if shot=="after_pda":
  for clue in w.stations:
   if clue.kind=="evidence":w.state.data.records[clue.id]={"title":clue.title,"body":clue.body}
  w.state.data.pda_selected="shift";w.hud.open_pda()
 if shot=="after_inventory":
  w.state.data.slots={"bag0":{"id":"pistol","count":1,"condition":73},"bag1":w.state.item("flashlight"),"quick0":w.state.item("band",2),"quick1":w.state.item("water",2),"bag2":w.state.item("ammo",12),"bag3":w.state.item("fuse")}
  w.hud.selected="bag0";w.hud.open_inventory()
 if shot=="after_medical":
  w.state.data.slots={"quick0":w.state.item("band",2),"bag0":w.state.item("medkit"),"bag1":w.state.item("morph")}
  w.state.hit("Левая рука",34);w.hud.selected_zone="Торс";w.hud.open_medical()
 if shot=="after_quickslot":
  w.state.data.slots={"quick1":w.state.item("water",2)};w.state.data.water=44;w.hud.refresh_slots()
 for i in 24:await process_frame
 if shot in ["after_walk","after_door"]:w.player.set_physics_process(true)
 if shot=="after_capsule":w.player.awaken()
 print("CLIP START ",shot)
 for frame in seconds*30:
  var t=float(frame)/maxi(1,seconds*30-1)
  if shot=="after_walk":
   while waypoint<path.size()-1 and w.player.global_position.distance_to(path[waypoint])<.24:waypoint+=1
   move_towards(path[waypoint]);focus=w.player.global_position-w.ORIGIN
  if shot=="after_capsule" and w.state.data.awake and not w.player.is_physics_processing():w.player.set_physics_process(true)
  if shot=="after_door":
   if frame==30:w.interact(action)
   if frame>78:move_towards(w.ORIGIN+Vector3(-25.5,.96,2.2),.38)
   focus=w.player.global_position-w.ORIGIN
  if shot in ["after_relay","after_pump"] and frame==35:w.interact(action)
  if shot=="after_pda":
   if frame==45:
    var search=w.hud.modal.find_child("ArchiveSearch",true,false);search.text="смен";search.text_changed.emit(search.text)
   if frame==115:w.hud.modal.find_child("ReaderIncrease",true,false).pressed.emit()
   if frame==165:w.hud.modal.find_child("ArchivePin",true,false).pressed.emit()
  if shot=="after_inventory":
   if frame==70:w.hud.equip_selected()
   if frame==110:w.hud.selected="bag1";w.hud.refresh_slots();w.hud.update_details()
   if frame==155:w.hud.equip_selected()
  if shot=="after_medical":
   if frame==40:w.hud.select_zone("Левая рука")
   if frame==85:w.hud.treat_selected("band")
   if frame==130:w.hud.treat_selected("medkit")
   if frame==175:w.hud.treat_selected("morph")
  if shot=="after_quickslot" and frame in [45,105]:
   for cell in w.hud.slots:
    if cell.key=="quick1" and cell.get_meta("hud_shortcut",false):cell.grab_focus();cell.pressed.emit();break
  var drift=Vector3(lerpf(-.45,.45,t),0,lerpf(.16,-.16,t)) if not ui_shot else Vector3.ZERO
  camera.global_position=w.ORIGIN+focus+camera._offset+drift
  camera.look_at(w.ORIGIN+focus+Vector3.UP)
  await process_frame
 finish()
func finish() -> void:
 if shot=="after_walk":print("WALK END ",w.player.global_position-w.ORIGIN)
 if shot in ["after_relay","after_pump"] and not w.state.flag(action.id):push_error("Recorded repair did not complete");quit(1);return
 if shot=="after_door" and not action.node.opened:push_error("Recorded door did not open");quit(1);return
 var out=OS.get_environment("DAY10_STILL")
 if not out.is_empty():root.get_texture().get_image().save_png(out)
 print("CLIP PASS ",shot," seconds=",seconds)
 quit()
