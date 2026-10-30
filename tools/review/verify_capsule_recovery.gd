extends SceneTree
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func frames(n:int)->void:
 for i in n:await physics_frame
func rect(control:Control)->Rect2:return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
func click(control:Control)->void:
 var at:Vector2=rect(control).get_center()
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=at;e.global_position=at
  root.push_input(e,true)
  await frames(2)
func touch_click(control:Control)->void:
 var at:Vector2=root.get_final_transform()*rect(control).get_center()
 for pressed in [true,false]:
  var e=InputEventScreenTouch.new();e.index=4;e.pressed=pressed;e.position=at
  Input.parse_input_event(e)
  await frames(3)
func mesh_vertices(mesh:Mesh)->PackedVector3Array:
 var result=PackedVector3Array()
 for surface in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var order:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
  for i in (order.size() if not order.is_empty() else vertices.size()):result.append(vertices[order[i] if not order.is_empty() else i])
 return result
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(15)
 var ui=w.hud
 if not check(not w.state.data.awake and ui.modal!=null and ui.modal.get_meta("prologue",false),"Fresh game has no accessible wake dialog"):return
 var open:Button
 for b in ui.modal.find_children("*","Button",true,false):
  if b.text=="ОТКРЫТЬ ГЛАЗА":open=b
 if not check(open!=null and rect(open).has_area() and Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(rect(open)),"Wake button is offscreen"):return
 await click(open)
 if not check(w.player.waking and ui.modal==null and not w.paused,"Actual GUI press did not start waking"):return
 var elapsed:float=w.player.wake_elapsed;ui.open_inventory();await frames(15)
 if not check(w.paused and is_equal_approx(w.player.wake_elapsed,elapsed),"Wake ignores a real open overlay"):return
 ui.close_modal()
 # Simulate an animation interruption. The old coroutine never released the lock.
 for tween in get_processed_tweens():tween.kill()
 await frames(330)
 if not check(w.state.data.awake and w.player.can_act() and not w.player.waking,"Interrupted animation stranded Volkov in capsule"):return
 if not check(w.player.global_position.distance_to(w.player_start)<.15 and w.player.wake_shell.position.z< -1.2,"Wake did not clear the closed capsule"):return
 var stick=ui.root.get_node("MoveStick")
 var touch=InputEventScreenTouch.new();touch.index=2;touch.pressed=true;touch.position=stick.size*Vector2(.88,.5);stick._gui_input(touch)
 var start:Vector3=w.player.global_position;await frames(40)
 touch.pressed=false;stick._input(touch);await frames(3)
 if not check(w.player.global_position.distance_to(start)>.35,"Movement stick does not move Volkov after waking"):return
 w.player.clear_controls()
 var f=w.get_node("LevelMinusTwo/Furnishings");var authored=JSON.parse_string(FileAccess.get_file_as_string("res://iso/maps/level2/furnishing.json"))
 if not check(f.authored.size()==authored.items.size() and f.skipped_ids.is_empty(),"Authored furniture was removed/skipped"):return
 var native_count=0
 for owner in w.visibility_controller.visuals:
  for node in w.visibility_controller.visuals[owner]:
   if not owner.split("+").has("sector_0"):continue
   if not check(node.visible,"Furniture/capsule vanished in current room: "+node.name):return
   for mesh in node.get_meta("masked_meshes",[]):
    if not check(mesh.material_override is StandardMaterial3D,"Visited furniture still depends on discovery shader"):return
    native_count+=1
 if not check(native_count>=10,"Capsule furniture batches missing"):return
 var v=w.visibility_controller;v.wall_controller.choose()
 if not check(v.wall_controller.targets[5]>.5,"Concave capsule-room wall still blocks its furnished corner"):return
 var rear=0
 for i in v.wall_controller.definitions.size():
  var spec=v.wall_controller.definitions[i]
  if maxf(spec.a[1],spec.b[1])< -11.3 and spec.a[0]< -20 and spec.b[0]< -20 and v.wall_controller.targets[i]<.5:rear+=1
 if not check(rear>0,"Cutaway fades the room's rear wall too"):return
 for name in ["WallMesh","SkirtMesh","CapMesh"]:
  var source=load("res://iso/maps/level2/"+name+".obj")
  var baked=load("res://iso/maps/level2/"+name+"Sections.res")
  if not check(mesh_vertices(source)==mesh_vertices(baked),"Wall geometry changed or was deleted: "+name):return
  var texture=w.get_node("LevelMinusTwo/"+name).material_override.get_shader_parameter("section_ids")
  if not check(texture!=null and texture.get_size()==Vector2(1024,512),"Wall section map missing"):return
  var shadow=w.get_node("LevelMinusTwo/"+name+"/OpaqueShadow")
  if not check(shadow.mesh.get_aabb().end.y*shadow.scale.y<=.181,"Invisible tall wall still casts an interior curtain"):return
 # Match the user's wide phone and verify the larger HUD, elevated interaction,
 # and unchanged reader/inventory scale after repeatedly opening overlays.
 for size in [Vector2i(1536,691),Vector2i(1600,900),Vector2i(960,540)]:
  root.size=size;await frames(6)
  var scale:float=ui.root.scale.x
  for id in ["Tasks","Vitals","Weapon","Map","MoveStick","AimStick","Interact","Belt"]:
   if not check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(rect(ui.root.get_node(id))),"HUD cropped: "+id+" "+str(size)):return
  if not check(not rect(ui.root.get_node("Vitals")).intersects(rect(ui.root.get_node("Weapon"))),"Enlarged HUD overlaps vitals and weapon"):return
  if not check(ui.root.get_node("Interact").position.y+72<ui.canvas_size.y-210,"Interaction was not raised"):return
  ui.open_inventory();await frames(4)
  if not check(is_equal_approx(ui.root.scale.x*1.1,scale),"HUD enlargement changes inventory scale"):return
  ui.close_modal();await frames(4)
  if not check(is_equal_approx(ui.root.scale.x,scale),"Closing inventory shrinks HUD again"):return
 w.queue_free();await frames(8)
 # Old asleep save, no intro marker, and a closed/missing prologue: there must
 # still be a visible usable action, without erasing the player's belongings.
 g.zsave=g._default_zsave()
 var saved=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3")
 saved.give("band",2);saved.data.records.keep={"title":"Сохранённая запись","body":"Не терять"};saved.data.water=83
 w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(12);ui=w.hud
 ui.modal.queue_free();await frames(12)
 if not check(ui.modal==null and not w.paused,"Retired overlay leaves a permanent pause/shade"):return
 if not check(ui.root.get_node("CapsuleWake").visible and not ui.root.get_node("Interact").disabled,"Lost dialog leaves no recovery action"):return
 await touch_click(ui.root.get_node("CapsuleWake"));await frames(35)
 w.notification(Node.NOTIFICATION_APPLICATION_PAUSED);w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 w.notification(Node.NOTIFICATION_APPLICATION_RESUMED);w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 if not check(g.zsave.zarya_layout3.get("wakeup_started",false) and not w.state.data.awake,"Interrupted wake is not persisted"):return
 var cfg=ConfigFile.new()
 if not check(cfg.load("user://anklav_rts.cfg")==OK and cfg.get_value("zcamp","zsave").zarya_layout3.get("wakeup_started",false),"Mobile suspension did not write interrupted wake to disk"):return
 w.queue_free();await frames(8);g._load_save()
 w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(15);ui=w.hud
 if not check(w.player.waking and ui.modal==null,"Continue does not resume an interrupted wake"):return
 w.player.set_process(false)
 w.paused=true # Retired overlay/application interruption, with no live dialog.
 for i in 30:w.player._process(.2)
 w.player.set_process(true);await frames(8)
 if not check(w.state.data.awake and w.player.can_act() and not w.paused,"Low-FPS/resumed wake left controls locked"):return
 if not check(w.state.amount("band")==2 and w.state.data.records.has("keep") and w.state.data.water>82,"Recovery resets inventory, records or health data"):return
 # The raised interaction button doubles as an explicit skip/recovery while
 # waking; an already awake save must never replay the opening.
 w.state.data.awake=false;w.player.waking=false;w.player.locked=true;w.player.awaken();ui._process(.2)
 await click(ui.root.get_node("Interact"));await frames(8)
 if not check(w.player.can_act() and not ui.root.get_node("CapsuleWake").visible,"Raised interaction button cannot finish waking"):return
 w.save_state();var snapshot=g.zsave.zarya_layout3.duplicate(true);w.queue_free();await frames(8)
 g.zsave.zarya_layout3=snapshot;w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(15)
 if not check(w.player.can_act() and not w.player.waking and w.player.wake_shell.position.z< -1.2,"Awake save replays intro or closes capsule again"):return
 w.queue_free();await frames(8)
 for audio in g._sfx_pool:audio.stop();audio.stream=null
 OS.delay_msec(80);await frames(3)
 print("CAPSULE RECOVERY PASS: ",checks," checks; GUI wake, interrupted animation, movement, retained furniture/walls, HUD, interrupted save, low FPS and raised interaction")
 quit()
