extends SceneTree
# Run through verify_startup_assets.py: its private fixture supplies the files
# intentionally missing or cached from the previous update.
var checks:=0
var cached:Array=[]
func _initialize():call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func touch(control:Control,pressed:bool,index:int=4,local:Vector2=Vector2.INF)->void:
 var e=InputEventScreenTouch.new();e.index=index;e.pressed=pressed
 var point=control.size*.5 if local==Vector2.INF else local
 e.position=root.get_final_transform()*control.get_global_transform_with_canvas()*point
 Input.parse_input_event(e)
func tap(control:Control)->void:
 touch(control,true);await frames(3);touch(control,false);await frames(3)
func snapshot(name:String)->void:
 var out=OS.get_environment("BUNKER_REVIEW_OUT")
 if out.is_empty() or DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(out)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
func warm_cache()->void:
 var pairs=JSON.parse_string(OS.get_environment("SEVANKLAV_RESTORE_FILES"))
 if not pairs is Dictionary:return
 for path in pairs:
  cached.append(load(path))
  var text=FileAccess.get_file_as_string(pairs[path])
  var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func run():
 warm_cache()
 var mode=OS.get_environment("SEVANKLAV_STARTUP_CASE")
 var g=root.get_node("G");g.zsave=g._default_zsave();g.zsave.seen_prologue=true
 var saved=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3")
 saved.give("band",2);saved.data.water=87;saved.data.records.keep={"title":"Старая запись","body":"Сохранить"}
 var before=saved.data.duplicate(true);g.write_save()
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await frames(110)
 main._enter_iso_world();await frames(20)
 var w=main.current_screen
 if mode=="critical_missing":
  if not check(not w.startup_ready and not w.startup_error.is_empty() and w.state_key=="zarya_layout3","Missing layout enters an empty legacy campaign"):return
  if not check(w.hud.modal!=null and w.hud.modal.name=="StartupFailure" and not w.hud.root.get_node("CapsuleWake").visible,"Failed scene still presents fake wake controls"):return
  w.player.request_wake();w.player._finish_wake();w.save_state();w.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
  if not check(g.zsave.zarya_layout3==before and not w.player.can_act() and not w.player.waking,"Failed startup advances/writes the real save"):return
  var cfg=ConfigFile.new();cfg.load("user://anklav_rts.cfg")
  if not check(cfg.get_value("zcamp","zsave").zarya_layout3==before,"Failed startup corrupted the saved position/items on disk"):return
  await snapshot("startup_recovery")
  await tap(w.hud.modal.find_child("StartupMenu",true,false));await frames(45)
  if not check(main.current_screen.get_script()==load("res://scripts/ui/main_menu.gd"),"Recovery screen cannot return to menu by touch"):return
  main._enter_iso_world();await frames(15);w=main.current_screen
  var file=FileAccess.open("res://iso/maps/level2/regions.json",FileAccess.WRITE)
  file.store_string(FileAccess.get_file_as_string(OS.get_environment("SEVANKLAV_REGIONS_SOURCE")));file.close()
  var retired=w
  await tap(w.hud.modal.find_child("RetryStartup",true,false));await frames(25);w=main.current_screen
  if not check(w!=retired and w.startup_ready,"Retry does not load the repaired files"):return
 if not check(w.startup_ready and w.custom_layout and w.state_key=="zarya_layout3" and w.rooms.size()==33,"No complete lower bunker after startup"):return
 if not check(w.doors.size()==25 and w.get_node("LevelMinusTwo/Furnishings").authored.size()==145,"Startup lost doors or furnishings"):return
 if not check(w.player_start.distance_to(w.ORIGIN)<60 and w.capsule_node()!=null and w.visibility_controller.ready_complete,"Player/camera bound to an unbuilt scene"):return
 if mode=="mask_missing":
  if not check(w.get_meta("wall_section_map_fallback",false),"Missing optional texture did not use baked section IDs"):return
  for name in ["WallMesh","SkirtMesh","CapMesh"]:
   if not check(not w.get_node("LevelMinusTwo/"+name).material_override.get_shader_parameter("use_section_map"),"Wall shader still samples the missing mask"):return
 if not w.state.data.awake:
  await tap(w.hud.root.get_node("CapsuleWake"));await frames(10)
 if not check(w.state.data.awake and w.player.can_act() and not w.player.waking,"Real touch cannot get out of the capsule"):return
 if not check(w.state.amount("band")==2 and w.state.data.records.has("keep") and w.state.data.water>86,"Existing inventory/records were reset"):return
 var f=w.get_node("LevelMinusTwo/Furnishings");var visible=0
 for owner in w.visibility_controller.visuals:
  if not owner.split("+").has("sector_0"):continue
  for node in w.visibility_controller.visuals[owner]:visible+=int(node.visible)
 if not check(visible>=15,"Capsule room is empty after recovery"):return
 await snapshot("recovered_capsule")
 var start:Vector3=w.player.global_position
 var stick=w.hud.root.get_node("MoveStick")
 touch(stick,true,5,stick.size*Vector2(.88,.5));await frames(42);touch(stick,false,5);await frames(4)
 if not check(w.player.global_position.distance_to(start)>.4,"Touch joystick remains inert after startup"):return
 await snapshot("touch_movement")
 var identity=w.stations.filter(func(a):return a.id=="identity_v17")[0]
 var approach=false
 for offset in [Vector3(1.3,0,0),Vector3(-1.3,0,0),Vector3(0,0,1.3),Vector3(0,0,-1.3)]:
  var at:Vector3=identity.node.global_position+offset;at.y=w.ORIGIN.y+.96
  if w.can_interact_from(identity,at):w.player.global_position=at;approach=true;break
 if not check(approach,"No reachable terminal approach after startup"):return
 w.interact(identity);await frames(5)
 if not check(w.hud.modal!=null and w.state.data.records.has("identity_v17"),"Terminal does not open after recovering startup"):return
 w.hud.close_modal();w.hud.open_inventory();await frames(5)
 if not check(w.hud.inventory_view!=null,"Inventory regressed after recovering the world"):return
 w.hud.close_modal();w.save_state();main.queue_free();await frames(10)
 for audio in g._sfx_pool:audio.stop();audio.stream=null
 OS.delay_msec(80);await frames(3)
 print("STARTUP ASSETS PASS: ",mode," / ",checks," checks; complete scene, actual touch, retained save, furniture, terminal and inventory")
 quit()
