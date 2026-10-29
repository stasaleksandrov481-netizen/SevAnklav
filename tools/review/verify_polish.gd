extends SceneTree
var checks := 0
func _initialize():call_deferred("run")
func check(ok: bool, message: String) -> bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func approach(w, action) -> bool:
 var room: String=action.node.adjacent[0] if action.kind=="door" else action.room
 w.visibility_controller.switch_room(room)
 var query=PhysicsShapeQueryParameters3D.new();query.shape=w.player.get_node("Collision").shape;query.exclude=[w.player.get_rid()]
 for x in range(-8,9):
  for z in range(-8,9):
   var at: Vector3=action.node.global_position+Vector3(x*.25,0,z*.25);at.y=1
   query.transform=Transform3D(Basis.IDENTITY,at)
   if w.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty() and w.can_interact_from(action,at):w.player.global_position=at;return true
 return false
func run():
 var script=load("res://iso/zarya/state.gd")
 var s=script.new({})
 var damaged={"id":"pistol","count":1,"condition":37,"serial":"V17"}
 s.data.containers.test=[damaged]
 if not check(s.loot("test",0) and s.data.slots.bag0==damaged,"Loot changed condition or item metadata"):return
 damaged.condition=10
 if not check(s.data.slots.bag0.condition==37,"Loot retained a mutable alias"):return
 s.data.slots={"bag0":{"id":"water","count":2,"condition":55}}
 for i in range(1,18):s.data.slots["bag"+str(i)]=s.item("pistol")
 s.data.containers.test=[s.item("pistol"),{"id":"water","count":3,"condition":55},{"id":"water","count":1,"condition":20}]
 if not check(s.loot_all("test")==1 and s.data.slots.bag0.count==5 and s.data.containers.test.size()==2,"Take-all stopped before a compatible later stack"):return
 if not check(s.data.containers.test[1].condition==20,"Distinct-condition items merged"):return
 var before=s.data.slots.duplicate(true)
 if not check(not s.receive({"id":"unknown","count":1}) and not s.give("water",0) and s.data.slots==before,"Invalid receive mutated inventory"):return
 var game=root.get_node("G");game.zsave=game._default_zsave()
 var prior=script.new(game.zsave,"zarya_layout3");prior.data.awake=true
 var scene=load("res://iso/bunker_world.tscn");var w=scene.instantiate();root.add_child(w)
 for i in 12:await physics_frame
 w.player.set_physics_process(false)
 var ui=w.hud;var stick=ui.root.get_node("MoveStick")
 stick.set_input_enabled(true)
 var touch=InputEventScreenTouch.new();touch.pressed=true;touch.index=4;touch.position=stick.size*Vector2(.9,.5);stick._gui_input(touch)
 if not check(stick.get_move_vector().length()>.1,"Touch did not engage joystick"):return
 var release=InputEventScreenTouch.new();release.index=5;release.pressed=false;stick._input(release)
 if not check(stick.get_move_vector().length()>.1,"A second finger released the active stick"):return
 release.index=4;stick._input(release)
 if not check(stick.get_move_vector()==Vector2.ZERO and stick._pointer==-1,"Release outside control remained latched"):return
 stick._gui_input(touch);stick.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 if not check(stick.get_move_vector()==Vector2.ZERO,"Focus loss retained a joystick press"):return
 stick._gui_input(touch);w.player.move_vector=Vector2.ONE;w.player.fire=true
 ui.open_inventory()
 if not check(stick.get_move_vector()==Vector2.ZERO and not stick.input_enabled and not w.player.fire,"Inventory retained movement/fire"):return
 stick._gui_input(touch)
 if not check(stick.get_move_vector()==Vector2.ZERO,"Hidden joystick accepted a new press"):return
 ui.close_modal();ui._process(0)
 if not check(stick.get_move_vector()==Vector2.ZERO and stick.input_enabled,"Closing a window resurrected the old press"):return
 var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=Vector2(800,450);Input.parse_input_event(mouse)
 for i in 2:await process_frame
 if not check(w.player.world_trigger_pressed(),"World mouse click no longer fires"):return
 stick._gui_input(touch)
 if not check(not w.player.world_trigger_pressed(),"Touch joystick leaked an emulated mouse shot"):return
 stick.reset();mouse.pressed=false;Input.parse_input_event(mouse)
 Input.action_press("shoot")
 if not check(w.player.world_trigger_pressed(),"Keyboard shoot action blocked without a mouse press"):return
 Input.action_release("shoot")
 w.state.data.slots={"left":w.state.item("pistol"),"bag0":w.state.item("ammo",12)}
 var door=w.doors[1];var action={"kind":"door","node":door,"title":"Door"}
 if not check(approach(w,action),"No door approach for pause check"):return
 var opened: bool=door.opened;w.paused=true
 w.interact(action);w.player.reload();w.player.check_ammo();w.player.toggle_flashlight();w.player.shoot()
 if not check(door.opened==opened and w.player.busy==0 and not w.player.checking and not w.state.data.get("flash_on",false),"Gameplay actions ran while paused"):return
 w.paused=false;w.state.data.health=0
 w.player.reload();w.interact(action)
 if not check(door.opened==opened and w.player.busy==0,"Dead player performed an action"):return
 w.state.data.health=100
 w.player.move_vector=Vector2.ONE;w.player.fire=true
 w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 if not check(w.paused and ui.modal!=null and not w.player.fire and w.player.move_vector==Vector2.ZERO,"Focus loss did not stop and pause live play"):return
 var pause_window=ui.modal
 w.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 if not check(ui.modal==pause_window,"Suspension replaced an existing window"):return
 ui.close_modal()
 var relay=w.stations.filter(func(a):return a.id=="relay_k2")[0]
 if not check(approach(w,relay),"No relay approach"):return
 w.state.give("fuse");w.interact(relay);w._advance_repair(.5)
 if not check(not w.repair_action.is_empty(),"Repair never started"):return
 ui.open_inventory()
 if not check(w.repair_action.is_empty() and not w.player.locked and w.state.amount("fuse")==1,"Opening inventory retained or consumed a partial repair"):return
 w.state.data.records={"shift":{"title":"Сменный лист","body":"Марина Белова / V-17"},"other":{"title":"Другое","body":"Архив"}}
 ui.open_pda()
 var search=ui.modal.find_child("ArchiveSearch",true,false);search.text="бЕЛоВА";search.text_changed.emit(search.text)
 for i in 3:await process_frame
 var entries=ui.modal.find_child("ArchiveEntries",true,false).get_children().filter(func(n):return n is Button)
 if not check(entries.size()==1,"PDA body search failed"):return
 entries[0].pressed.emit();ui.modal.find_child("ArchivePin",true,false).pressed.emit()
 for i in 3:await process_frame
 search=ui.modal.find_child("ArchiveSearch",true,false)
 if not check(search.text=="бЕЛоВА" and w.state.data.tracked_record=="shift","Pinning lost the active search"):return
 if not check(ui.modal.find_child("ReaderIncrease",true,false).size.y<=64 and ui.modal.find_child("ReaderFontCaption",true,false).size.x>=150,"Reader controls stretched into a vertical column"):return
 ui.modal.find_child("ReaderIncrease",true,false).pressed.emit()
 if not check(w.state.data.reader_font_size==26 and ui.modal.find_child("ArchiveBody",true,false).get_theme_font_size("normal_font_size")==26,"PDA font adjustment failed"):return
 ui.open_evidence({"title":"Чтение","body":"Длинная запись. ".repeat(150)})
 if not check(ui.modal.find_child("EvidenceText",true,false).get_theme_font_size("normal_font_size")==26,"Reader font did not carry across windows"):return
 ui.notify("Проверка сообщения")
 if not check(ui.modal_feedback.visible and ui.modal_feedback.text=="Проверка сообщения","Feedback hidden behind window"):return
 for size in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
  root.size=size
  for i in 4:await process_frame
  var body=ui.modal.find_child("EvidenceText",true,false)
  if not check(ui.modal.size.x<=ui.canvas_size.x and body.size.x<=body.get_parent().size.x+1,"Reader spills beyond canvas"):return
  if not check(ui.modal.find_child("ReaderIncrease",true,false).size.y<=64,"Reader buttons stretched on resize"):return
 ui.close_modal();w.paused=false
 if not check(ui.timer==0 and not ui.notice_panel.visible,"Closed window leaked old feedback into gameplay"):return
 # Repeated drop/pickup must preserve fields and remove the empty floor object.
 w.state.data.slots={"bag0":{"id":"pistol","count":1,"condition":37,"serial":"V17"}}
 ui.selected="bag0";ui.open_inventory();ui.drop_selected()
 var drop_id: String=w.state.data.drops.back().id
 var drop_action=w.stations.filter(func(a):return a.id==drop_id)[0]
 if not check(w.state.data.containers[drop_id][0].condition==37,"Dropping changed condition"):return
 var here: String=w.visibility_controller.active
 w.visibility_controller.switch_room("sector_15" if here!="sector_15" else "sector_0")
 if not check(not drop_action.node.visible,"Dropped item visible in a different room"):return
 w.visibility_controller.switch_room(here)
 ui.transfer(drop_action,0)
 if not check(w.state.data.slots.bag0.condition==37 and w.state.data.slots.bag0.serial=="V17","Drop/pickup lost item properties"):return
 if not check(w.state.data.drops.is_empty() and not w.stations.any(func(a):return a.id==drop_id),"Empty floor item remained interactive"):return
 w.state.data.drops.append({"id":"drop_old_empty","item":w.state.item("water"),"position":[w.player.position.x,1,w.player.position.z]});w.state.data.containers.drop_old_empty=[]
 w.save_state();w.queue_free()
 for i in 5:await process_frame
 w=scene.instantiate();root.add_child(w)
 for i in 10:await physics_frame
 if not check(w.state.data.drops.is_empty() and not w.stations.any(func(a):return a.id=="drop_old_empty"),"Reload resurrected an old empty drop"):return
 if not check(w.state.data.reader_font_size==26 and w.state.data.pda_search=="бЕЛоВА","Reader settings lost after reload"):return
 w.queue_free()
 for i in 5:await process_frame
 # An accidental shortcut cannot dismiss the only path out of the capsule intro.
 game.zsave=game._default_zsave();w=scene.instantiate();root.add_child(w)
 for i in 10:await physics_frame
 ui=w.hud;var intro=ui.modal
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_ESCAPE;ui._unhandled_input(key);key.keycode=KEY_TAB;ui._unhandled_input(key)
 if not check(ui.modal==intro and intro.get_meta("prologue",false) and not intro.find_child("WindowClose",true,false).visible,"Intro can be dismissed without awakening"):return
 w.queue_free()
 for i in 5:await process_frame
 print("POLISH PASS: ",checks," checks; touch/focus, pause actions, loot metadata and full bag, drop cleanup, PDA search/font, intro guard")
 quit(0)
