extends SceneTree
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func frames(n):
 for i in n:await process_frame
func verify_layout(menu:Node)->bool:
 if not check(menu.has_node("MenuRoot/Background") and menu.has_node("MenuRoot/MenuCanvas"),"Menu has no authored winter-bunker layout"):return false
 var bg:TextureRect=menu.get_node("MenuRoot/Background")
 if not check(bg.texture.resource_path=="res://assets/ui/bunker/menu_background.png","Menu uses an obsolete background"):return false
 var canvas=menu.get_node("MenuRoot/MenuCanvas")
 var expected=["ПРОДОЛЖИТЬ","CO-OP ИГРА","НОВАЯ ИГРА","ЗАГРУЗИТЬ ИГРУ","НАСТРОЙКИ","ВЫХОД"]
 for i in 6:
  if not check(canvas.has_node("MenuAction"+str(i)) and canvas.get_node("MenuAction"+str(i)).text==expected[i],"Authored menu button missing or misordered"):return false
 if not check(not menu.has_node("Root") and menu.find_children("PlayBtn","",true,false).is_empty(),"Legacy menu nodes survived in the scene"):return false
 for label in menu.find_children("*","Label",true,false):
  if not check(not label.text.contains("сборка 2.1") and not label.text.contains("ПОСЛЕ ЭМИ-УДАРА"),"An old menu caption is still visible"):return false
 return true
func run():
 var game=root.get_node("G");game.zsave=game._default_zsave()
 var packed=load("res://scenes/ui/MainMenu.tscn")
 # Editor preview / missing controller: the scene must already contain the art.
 var raw=packed.instantiate();raw.set_script(null);root.add_child(raw)
 if not verify_layout(raw):return
 if not check(raw.get_node("MenuRoot/MenuCanvas/GameTitle").text=="СЕВЕРНЫЙ\nАНКЛАВ","Title is only created by runtime code"):return
 raw.queue_free();await frames(3)
 var script_only=load("res://scripts/ui/main_menu.gd").new();root.add_child(script_only);await frames(3)
 if not verify_layout(script_only):return
 script_only.menu_canvas.get_node("MenuAction1").pressed.emit()
 if not check(script_only.coop_modal!=null,"Script-only callers cannot use the canonical menu layout"):return
 script_only.queue_free();await frames(3)
 # Use the actual project entry rather than instantiating a menu in isolation.
 if not check(str(ProjectSettings.get_setting("application/run/main_scene"))=="res://scenes/main.tscn","Project starts at a different entry scene"):return
 change_scene_to_file("res://scenes/main.tscn");await frames(100)
 var main=current_scene;var menu=main.current_screen
 if not verify_layout(menu):return
 if not check(get_nodes_in_group("main_root").size()==1,"Project boot has no unique game controller"):return
 menu.menu_canvas.get_node("MenuAction1").pressed.emit()
 if not check(menu.coop_modal!=null,"Co-op action is disconnected"):return
 root.go_back_requested.emit()
 if not check(menu.coop_modal==null,"Co-op back action does not return to the new menu"):return
 menu.menu_canvas.get_node("MenuAction2").pressed.emit();await frames(6)
 if not check(main.current_screen!=menu and not game.zsave.seen_prologue,"New-game button did not enter the intro"):return
 main.to_main_menu();await frames(8);menu=main.current_screen
 if not verify_layout(menu):return
 for dimensions in [Vector2i(1600,900),Vector2i(2048,900),Vector2i(960,540),Vector2i(720,1280)]:
  root.size=dimensions;await frames(5)
  var viewport_size:Vector2=root.get_visible_rect().size
  var bg:TextureRect=menu.menu_root.get_node("Background")
  if not check(bg.get_global_rect().size.is_equal_approx(viewport_size),"Background leaves uncovered viewport space"):return
  for i in 6:
   var button:Button=menu.menu_canvas.get_node("MenuAction"+str(i))
   var rect:Rect2=button.get_global_transform()*Rect2(Vector2.ZERO,button.size)
   if not check(Rect2(Vector2.ZERO,viewport_size).encloses(rect),"Menu button lies outside the viewport"):return
 root.size=Vector2i(1600,900)
 # F6: directly running the menu must hand off to the same functioning game.
 change_scene_to_file("res://scenes/ui/MainMenu.tscn");await frames(100)
 if not check(current_scene.scene_file_path=="res://scenes/main.tscn" and get_nodes_in_group("main_root").size()==1,"Direct menu launch does not route to the game controller"):return
 if not verify_layout(current_scene.current_screen):return
 current_scene.queue_free();await frames(5)
 print("MENU ENTRY PASS: ",checks," checks; authored preview, project boot, new game, return, direct menu launch, four viewport sizes")
 quit()
