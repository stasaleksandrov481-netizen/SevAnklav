extends SceneTree
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func frames(n):
 for i in n:await process_frame
func run():
 var g=root.get_node("G");g.zsave=g._default_zsave()
 var saved=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");saved.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w);await frames(12)
 w.player.set_physics_process(false);var ui=w.hud;var visibility=w.visibility_controller
 if not check(not ui.root.get_node("Weapon").get_rect().intersects(ui.root.get_node("Map").get_rect()) and not ui.root.get_node("Weapon").get_rect().intersects(ui.root.get_node("Interact").get_rect()),"Weapon panel overlaps the map or interaction button"):return
 w.state.data.slots={"bag0":w.state.item("band",2),"bag1":w.state.item("medkit"),"bag2":w.state.item("morph"),"bag3":w.state.item("water",2)}
 w.state.data.wounds["Левая рука"]={"damage":30.0,"bleeding":.6,"pain":20.0};w.state.data.health=70
 ui.open_inventory();var inventory=ui.modal;await frames(4)
 if not check(ui.modal.get_meta("inventory",false) and ui.modal.find_child("InventoryColumns",true,false).get_child_count()==3,"Inventory lost its three functional columns"):return
 var touch=InputEventScreenTouch.new();touch.index=1;touch.pressed=true;touch.position=Vector2(103,150);ui.medical_body._gui_input(touch)
 if not check(ui.modal==inventory and ui.selected_zone=="Левая рука" and ui.inventory_view.panes.medical.visible,"Silhouette touch replaced inventory or failed to open limb treatment"):return
 ui.medical_actions.band.pressed.emit()
 if not check(w.state.amount("band")==1 and w.state.data.wounds["Левая рука"].bleeding==0 and ui.medical_actions.band.disabled,"Silhouette treatment did not consume exactly one useful bandage"):return
 ui.select_slot("bag3")
 if not check(ui.inventory_view.panes.item.visible and ui.modal==inventory,"Selecting an item did not restore its actions in the same window"):return
 ui._process(.2)
 if not check(ui.root.get_node("Interact").modulate.a==0 and not ui.notice_panel.visible,"Live HUD controls reappeared behind an open inventory"):return
 for dimensions in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
  root.size=dimensions;ui.open_medical();await frames(6)
  if not check(ui.modal.get_rect().end.y<=ui.canvas_size.y+1 and ui.medical_actions.morph.get_global_rect().end.y<=ui.modal.get_global_rect().end.y,"Treatment overflow: viewport=%s canvas=%s modal=%s min=%s medicine=%s" % [dimensions,ui.canvas_size,ui.modal.get_rect(),ui.modal.get_combined_minimum_size(),ui.medical_actions.morph.get_global_rect()]):return
  ui.begin_move();await frames(6)
  if not check(ui.modal.get_rect().end.y<=ui.canvas_size.y+1,"Inventory feedback pushes treatment outside the screen"):return
  ui.close_modal()
 root.size=Vector2i(1600,900);await frames(4)
 var note=w.stations.filter(func(a):return a.id=="gromov")[0];ui.open_evidence(note);await frames(4)
 if not check(ui.modal.get_meta("paper",false) and ui.modal.find_child("EvidenceText",true,false).text==note.body,"A physical note did not become a readable paper sheet"):return
 var text=ui.modal.find_child("EvidenceText",true,false);var font_size=int(w.state.data.get("reader_font_size",24))
 ui.modal.find_child("ReaderIncrease",true,false).pressed.emit()
 if not check(text.get_theme_font_size("normal_font_size")==font_size+2 and w.state.data.reader_font_size==font_size+2,"Paper reader font control lost its persistent setting"):return
 var terminal=w.stations.filter(func(a):return a.id=="identity_v17")[0];ui.open_evidence(terminal);await frames(4)
 if not check(ui.modal.get_meta("terminal",false) and ui.terminal_view.tabs.size()==6 and ui.modal.find_child("EvidenceText",true,false).text==terminal.body,"Electronic evidence did not open in the live terminal"):return
 var active=ui.terminal_view
 active.tabs.systems.pressed.emit();await frames(2)
 if not check(active.selected=="systems" and active.content.get_child_count()>1,"Terminal navigation is decorative"):return
 active.tabs.cameras.pressed.emit()
 if not check(active.content.get_child(0).text.contains("НЕДОСТУПЕН"),"Disconnected cameras pretend to show a live feed"):return
 active.tabs.access.pressed.emit()
 if not check(active.content.get_child(1).text.contains("НЕ ПРЕДЪЯВЛЕНА"),"Terminal grants an access card that is not in inventory"):return
 ui.close_modal();w.player.global_position=w.player_start;visibility.switch_room("sector_0")
 for profile in ["balanced","quality","low"]:
  visibility.set_profile(profile);visibility.refresh_lights()
  var sources=[]
  for lamp in visibility.lamps:
   if lamp.visible and lamp.shadow_enabled:sources.append(lamp.get_instance_id())
  if not check(sources.size()<=visibility.budget and (sources.size()==0 if profile=="low" else sources.size()>0),"Shadow profile exceeds budget or has no fixed light"):return
  var fixed_fill:Vector3=visibility.fallback.global_position
  var samples:=0
  for x in [-31.0,-29.0,-27.0,-25.0,-23.0]:
   for z in [-9.0,-6.0,-4.0]:
    var point:Vector3=w.ORIGIN+Vector3(x,.95,z)
    if visibility.room_for(point)!="sector_0":continue
    w.player.global_position=point;visibility._process(.12)
    var current=[]
    for lamp in visibility.lamps:
     if lamp.visible and lamp.shadow_enabled:current.append(lamp.get_instance_id())
    if not check(current==sources and visibility.fallback.global_position==fixed_fill,"Walking inside the capsule room reselected shadow lights or moved its fill"):return
    samples+=1
  if not check(samples>=10,"Not enough capsule-room positions were checked"):return
 if not check(visibility.room_lights.all(func(l):return l.shadow_normal_bias<=.3),"Room shadow bias still detaches shadows from their objects"):return
 visibility.set_profile("balanced");w.player.global_position=w.player_start;w.player.velocity=Vector3.ZERO
 var stick=ui.root.get_node("MoveStick");var distances=[]
 for running in [false,true]:
  w.player.global_position=w.player_start;w.player.velocity=Vector3.ZERO;stick.reset();ui._process(0)
  var event=InputEventScreenTouch.new();event.index=3;event.pressed=true;event.position=stick.size*Vector2(.88,.5);stick._gui_input(event)
  if running:stick.double_held=true
  ui._process(0);w.player.set_physics_process(true);var start:Vector3=w.player.global_position;var top:=0.0
  for i in 60:
   await physics_frame;top=maxf(top,Vector2(w.player.velocity.x,w.player.velocity.z).length())
  w.player.set_physics_process(false);distances.append(w.player.global_position.distance_to(start));stick.reset();ui._process(0)
  if not check(top<=(2.66 if running else 1.66),"Player still moves faster than the new speed limit"):return
 if not check(distances[0]>1.0 and distances[0]<1.8 and distances[1]>distances[0]*1.2 and distances[1]<2.8,"Slow walk/run do not produce the expected actual travel distances: "+str(distances)):return
 w.queue_free();await frames(5)
 print("UI SHADOWS PASS: ",checks," checks; silhouette treatment, paper, real terminal tabs, three layouts, fixed light sources across capsule-room positions, slow movement ",distances)
 quit()
