extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=root.get_node("G");game.zsave=game._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=true
 var w=load("res://iso/bunker_world.tscn").instantiate();root.add_child(w)
 for i in 10:await physics_frame
 var missing=0;var views=0
 for d in w.doors:
  if d.adjacent.is_empty():missing+=1
  for room in d.adjacent:
   w.visibility_controller.switch_room(room)
   assert(d.visible,"Door hidden from an adjacent sector")
   views+=1
  print("DOOR ADJ ",d.name," ",d.adjacent)
 for pair in [["20_",["sector_6","sector_7"]],["21_",["sector_7","sector_8"]],["24_",["sector_9","sector_10"]],["25_",["sector_10","sector_15"]]]:
  var d=w.doors.filter(func(door):return door.info.id.begins_with(pair[0]))[0]
  for room in pair[1]:assert(room in d.adjacent,"Missing opposite room at vertical doorway")
 var gate=w.doors[0]
 assert(gate.info.kind=="sealed" and not gate.opened and is_zero_approx(gate.progress))
 var data=FileAccess.get_file_as_string("res://iso/maps/level2/Zarya_Level_Minus_2.tscn")
 assert(not data.contains("))\nrotation"),"Malformed transform lines remain")
 print("DOOR VISIBILITY PASS missing=",missing," / ",w.doors.size()," adjacent views=",views,"; vertical neighbours and sealed outer gate")
 assert(missing==0)
 w.queue_free()
 for i in 5:await process_frame
 quit(0)
