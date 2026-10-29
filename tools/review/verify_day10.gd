extends SceneTree
var checks := 0
func _initialize():call_deferred("run")
func check(ok: bool, message: String) -> bool:
 if not ok:push_error(message);quit(1);return false
 checks+=1;return true
func run():
 var state_script=load("res://iso/zarya/state.gd")
 var s=state_script.new({})
 s.data.slots={"bag0":{"id":"water","count":1,"condition":100},"bag1":{"id":"water","count":2,"condition":62,"serial":"B"}}
 s.data.water=50
 if not check(s.consume_slot("bag1") and s.data.slots.bag0.count==1 and s.data.slots.bag1.count==1 and s.data.slots.bag1.condition==62 and s.data.water==80,"Consumption used a different slot"):return
 if not check(s.consume_slot("bag1") and not s.data.slots.has("bag1") and s.data.water==100,"Last selected item was not removed"):return
 if not check(not s.consume_slot("bag0") and s.data.slots.bag0.count==1,"Full water meter wasted an item"):return
 s.data.water=99.99
 if not check(not s.consume_slot("bag0") and s.data.slots.bag0.count==1,"A tiny survival tick allowed wasting another drink"):return
 var meter=load("res://iso/zarya/meter.gd").new();root.add_child(meter);meter.value=99.9;meter.value=99.8
 if not check(is_equal_approx(meter.value,99.8),"Meter discarded changes within its current display bucket"):return
 meter.queue_free()
 if not check(not s.consume_slot("missing"),"Empty slot consumed"):return
 s.data.slots.bag2=s.item("fuse")
 if not check(not s.consume_slot("bag2") and s.amount("fuse")==1,"Non-consumable item used"):return
 s.data.slots.bag3=s.item("food");s.data.food=90
 if not check(s.consume_slot("bag3") and s.data.food==100,"Food consumption did not clamp to maximum"):return
 s.data.slots.bag4=s.item("band",2)
 if not check(not s.can_treat("Торс","band") and not s.treat("Торс","band") and s.amount("band")==2,"Unneeded treatment consumed medicine"):return
 s.data.wounds["Торс"].bleeding=.5
 if not check(not s.treat("Торс","fuse") and s.amount("fuse")==1,"Unknown medicine consumed an unrelated item"):return
 if not check(not s.treat("unknown","band") and s.amount("band")==2,"Unknown body zone consumed medicine"):return
 if not check(s.can_treat("Торс","band") and s.treat("Торс","band") and s.data.wounds["Торс"].bleeding==0 and s.amount("band")==1,"Bandage treatment failed"):return
 var game=root.get_node("G");game.zsave=game._default_zsave()
 var prior=state_script.new(game.zsave,"zarya_layout3");prior.data.awake=true
 var original_back: bool=quit_on_go_back
 var scene=load("res://iso/bunker_world.tscn");var w=scene.instantiate();root.add_child(w)
 for i in 12:await physics_frame
 w.player.set_physics_process(false)
 var ui=w.hud
 if not check(not quit_on_go_back,"Bunker did not take ownership of native back"):return
 w.state.data.slots={"quick0":w.state.item("band",2),"quick1":w.state.item("water",2),"bag0":w.state.item("medkit"),"bag1":w.state.item("morph")}
 w.state.data.health=66;w.state.data.water=70
 w.state.data.wounds["Левая рука"]={"damage":34.0,"bleeding":.7,"pain":45.0}
 ui.activate_shortcut("quick0")
 if not check(ui.modal!=null and ui.modal.get_meta("medical",false) and ui.selected_zone=="Левая рука","Medical shortcut did not choose the injured zone"):return
 if not check(ui.medical_heading.text.contains("Левая рука") and ui.medical_zones["Левая рука"].button_pressed,"Selected body zone has no visible selection"):return
 if not check(not ui.medical_actions.band.disabled and not ui.medical_actions.medkit.disabled and not ui.medical_actions.morph.disabled,"Available treatment buttons disabled"):return
 ui.treat_selected("band")
 if not check(w.state.amount("band")==1 and w.state.data.wounds["Левая рука"].bleeding==0 and ui.medical_actions.band.disabled,"Treatment button did not refresh after applying bandage"):return
 var touch=InputEventScreenTouch.new();touch.pressed=true;touch.index=2;touch.position=Vector2(170,40);ui.medical_body._gui_input(touch)
 if not check(ui.selected_zone=="Голова" and ui.medical_actions.medkit.disabled and ui.medical_actions.morph.disabled,"Touch body selection failed"):return
 ui.select_zone("Левая рука");ui.treat_selected("medkit")
 if not check(w.state.data.health==81 and w.state.data.wounds["Левая рука"].damage==12 and ui.medical_actions.medkit.disabled,"Medkit counts or selected-zone readings did not update"):return
 ui.treat_selected("morph")
 if not check(w.state.data.wounds["Левая рука"].pain==15 and ui.medical_actions.morph.disabled,"Pain medication was not reflected"):return
 root.go_back_requested.emit()
 if not check(ui.modal==null and not w.paused,"Native back did not close the medical window"):return
 root.go_back_requested.emit()
 if not check(ui.modal!=null and w.paused,"Native back did not pause gameplay"):return
 root.go_back_requested.emit()
 if not check(ui.modal==null and not w.paused,"Native back did not return from pause"):return
 ui.activate_shortcut("quick1")
 if not check(w.state.data.water==100 and w.state.data.slots.quick1.count==1 and ui.modal==null,"Water shortcut did not consume in place"):return
 ui.activate_shortcut("quick1")
 if not check(w.state.data.slots.quick1.count==1,"Repeated full-meter shortcut wasted water"):return
 ui.activate_shortcut("quick2")
 if not check(ui.modal!=null and ui.selected=="quick2" and ui.modal_feedback.visible,"Empty shortcut has no configuration path"):return
 var count: int=w.state.data.slots.quick1.count;ui.activate_shortcut("quick1")
 if not check(w.state.data.slots.quick1.count==count,"HUD shortcut ran behind an open window"):return
 ui.close_modal();w.state.data.slots.quick3=w.state.item("flashlight")
 ui.activate_shortcut("quick3")
 if not check(w.state.data.slots.left.id=="flashlight" and w.state.data.flash_on and not w.state.data.slots.has("quick3"),"Flashlight shortcut did not equip into a free hand"):return
 ui.activate_shortcut("left")
 if not check(not w.state.data.flash_on,"Held flashlight did not toggle"):return
 w.state.data.slots={"left":w.state.item("pistol"),"right":w.state.item("flashlight"),"quick3":w.state.item("flashlight")}
 var before=w.state.data.slots.duplicate(true);ui.activate_shortcut("quick3")
 if not check(w.state.data.slots==before and ui.modal!=null,"Flashlight silently replaced occupied hands"):return
 ui.close_modal();ui.open_medical()
 for size in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
  root.size=size
  for i in 5:await process_frame
  if not check(ui.modal.size.x<=ui.canvas_size.x and ui.medical_actions.band.get_global_rect().end.x<=ui.modal.get_global_rect().end.x+1,"Medical controls overflow on resize"):return
 w.save_state()
 var w2=scene.instantiate();root.add_child(w2)
 for i in 5:await physics_frame
 w.queue_free()
 for i in 5:await process_frame
 if not check(not quit_on_go_back,"An old HUD restored the back policy while another bunker was alive"):return
 w2.queue_free()
 for i in 5:await process_frame
 if not check(quit_on_go_back==original_back and not has_meta("bunker_original_back_policy"),"Leaving the bunker did not restore native back policy"):return
 game.zsave=game._default_zsave();w=scene.instantiate();root.add_child(w)
 for i in 10:await physics_frame
 var intro=w.hud.modal;root.go_back_requested.emit()
 if not check(w.hud.modal==intro and not w.state.data.awake,"Native back dismissed the capsule intro"):return
 w.queue_free()
 for i in 5:await process_frame
 print("DAY10 PASS: ",checks," checks; exact-slot consumption, treatment feedback, touch selection, shortcuts, native back ownership and intro")
 quit()
