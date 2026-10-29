extends SceneTree
var output := ""
func _initialize():call_deferred("run")
func capture(name: String):
 await create_timer(.4).timeout
 await RenderingServer.frame_post_draw
 var result=root.get_texture().get_image().save_png(output+"/"+name+".png")
 assert(result==OK);print("CAPTURE ",name)
func run():
 output=OS.get_environment("BUNKER_REVIEW_OUT");DirAccess.make_dir_recursive_absolute(output)
 var game=root.get_node("G");game.zsave=game._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 12:await physics_frame
 w.player.set_physics_process(false)
 var ui=w.hud
 # Real authored records, unlocked for this review capture only.
 for action in w.stations:
  if action.kind=="evidence":w.state.data.records[action.id]={"title":action.title,"body":action.body}
 w.state.data.pda_selected="shift";w.state.data.pda_search="смен"
 ui.open_pda();ui.modal.find_child("ReaderIncrease",true,false).pressed.emit()
 await capture("pda_search_reader")
 root.size=Vector2i(960,540)
 for i in 6:await process_frame
 await capture("pda_960x540")
 root.size=Vector2i(1600,900)
 for i in 6:await process_frame
 var supplies=w.stations.filter(func(action):return action.id=="med_supplies")[0]
 w.state.data.slots={"bag0":w.state.item("water",2)}
 var kinds=["pistol","flashlight","tool","medkit","fuse","band","uniform"]
 for i in range(1,18):
  var item=w.state.item(kinds[(i-1)%kinds.size()]);item.condition=55+i;w.state.data.slots["bag"+str(i)]=item
 ui.open_loot(supplies);ui.take_all(supplies)
 await capture("loot_full_bag")
 w.state.data.slots.left=w.state.item("flashlight");w.state.data.slots.right=w.state.item("pistol");w.state.data.slots.bag1=w.state.item("rifle")
 ui.selected="bag1";ui.open_inventory();ui.equip_selected()
 await capture("inventory_feedback")
 var note=w.stations.filter(func(action):return action.id=="archive_chat")[0]
 ui.open_evidence(note)
 await capture("evidence_reader")
 ui.close_modal();w.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 await capture("focus_pause")
 ui.close_modal();w.player.global_position=w.ORIGIN+Vector3(33.1,.96,7.9);w.get_node("Camera").global_position=w.player.global_position+w.get_node("Camera")._offset
 for i in 12:await process_frame
 await capture("cargo_gate_closed")
 w.queue_free()
 for i in 5:await process_frame
 print("POLISH CAPTURE PASS")
 quit()
