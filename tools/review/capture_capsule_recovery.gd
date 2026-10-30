extends SceneTree
var out=OS.get_environment("BUNKER_REVIEW_OUT")
func _initialize():call_deferred("run")
func frames(n:int)->void:
 for i in n:await process_frame
func snap(name:String)->void:
 await frames(8);await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
func touch(control:Control,pressed:bool,index:int=4,local:Vector2=Vector2.INF)->void:
 var e=InputEventScreenTouch.new();e.index=index;e.pressed=pressed
 var point=control.size*.5 if local==Vector2.INF else local
 e.position=root.get_final_transform()*control.get_global_transform_with_canvas()*point
 Input.parse_input_event(e)
func click(control:Control)->void:
 touch(control,true);await frames(3);touch(control,false);await frames(3)
func run():
 assert(not out.is_empty());DirAccess.make_dir_recursive_absolute(out)
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await frames(110)
 var menu=main.current_screen
 await click(menu.menu_canvas.get_node("MenuAction2"));await frames(5)
 var intro
 for child in main.current_screen.get_children():
  if child.get_script()==load("res://scripts/zprologue_zarya.gd"):intro=child
 assert(intro!=null,"Touch on the new-game button failed")
 for step in 3:
  intro.reveal=1;intro._process(0);await click(intro.choices.get_child(0))
  await frames(22 if step<2 else 18)
 for i in 60:
  if main.current_screen.get_script()==load("res://iso/zarya/level.gd"):break
  await frames(1)
 var w=main.current_screen
 assert(w.get_script()==load("res://iso/zarya/level.gd"))
 await snap("01_waking")
 # Finish normally from the actual new-game route, without forcing awake.
 await frames(160)
 assert(w.state.data.awake and w.player.can_act(),"New game remains in capsule")
 await snap("02_awake")
 var start:Vector3=w.player.global_position
 var stick=w.hud.root.get_node("MoveStick")
 touch(stick,true,5,stick.size*Vector2(.88,.5));await frames(27);touch(stick,false,5);await frames(5)
 assert(w.player.global_position.distance_to(start)>.3,"Actual touchscreen joystick failed after waking")
 await snap("03_movement")
 w.hud.open_inventory();await snap("04_inventory");w.hud.close_modal()
 var f=w.get_node("LevelMinusTwo/Furnishings")
 print("CAPSULE CAPTURE PASS: actual menu/new game/intro, touch input, awake=",w.state.data.awake," movement=",w.player.global_position.distance_to(start)," authored_furniture=",f.authored.size()," items_built=",f.count)
 main.queue_free();await frames(8)
 for audio in g._sfx_pool:audio.stop();audio.stream=null
 OS.delay_msec(80);await frames(3);quit()
