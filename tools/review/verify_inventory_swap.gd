extends SceneTree
func _initialize():
 var state=load("res://iso/zarya/state.gd").new({})
 state.data.slots={"left":state.item("pistol"),"bag0":state.item("water",2)}
 var before=state.data.slots.duplicate(true)
 assert(not state.can_move_slot("left","bag0"));assert(not state.move_slot("left","bag0"));assert(state.data.slots==before,"Rejected swap lost an item")
 assert(state.move_slot("left","bag1"));assert(not state.data.slots.has("left"))
 assert(state.move_slot("bag1","right"));assert(state.weapon()=="pistol")
 state.data.slots.bag2=state.item("rifle");state.data.slots.left=state.item("flashlight")
 assert(not state.move_slot("bag2","right"),"Two-handed weapon occupied both hands")
 assert(state.move_slot("left","bag3"));assert(state.move_slot("bag2","right"))
 assert(state.data.slots.right.id=="rifle" and state.data.slots.bag2.id=="pistol")
 assert(state.move_slot("right","left"));assert(not state.data.slots.has("right"))
 assert(not state.can_move_slot("missing","bag0"));assert(not state.can_move_slot("bag0","bag0"))
 print("INVENTORY PASS: invalid reverse swap, no loss on rejection, two-handed swaps, hand transfer")
 quit()
