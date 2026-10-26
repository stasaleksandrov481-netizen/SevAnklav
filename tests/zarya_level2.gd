extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func run() -> void:
	var game=root.get_node("G")
	game.set_meta("qa8",true)
	game.zsave=game._default_zsave()
	var state=preload("res://iso/zarya/state.gd").new(game.zsave)
	state.data.awake=true
	var world=load("res://iso/bunker_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	check(world.rooms.size()==19,"17 rooms + 2 connector galleries")
	check(world.doors.size()==24,"Every planned passage has a door")
	check(not world.rooms.has("level_minus_one"),"No upper floor")
	check(state.data.slots.is_empty(),"No starting weapon")
	state.give("pistol"); state.give("flashlight")
	check(state.equip("bag0"),"First item equips left hand")
	check(state.equip("bag1"),"Second item equips right hand")
	check(state.weapon()=="pistol","Weapon found in either hand")
	state.give("rifle")
	check(not state.move_slot("bag0","left"),"Two handed weapon rejects occupied other hand")
	state.data.slots.clear()
	check(world.activate("staff"),"Staff terminal unlocks access")
	check(not world.activate("power"),"Cannot restore power without fuse")
	state.give("card"); state.mark("card")
	check(world.activate("experiment"),"Experiment record")
	state.give("fuse")
	check(world.activate("power"),"Fuse restores power")
	check(state.amount("fuse")==0,"Fuse consumed")
	world.activate("archive")
	check(world.activate("quarantine"),"Quarantine requires evidence and power")
	for action in world.stations:
		if action.id=="stairs": world.interact(action)
	check(state.flag("level_complete"),"Final objective is staircase")
	check(not game.zsave.get("iso_layer","")=="surface","No premature surface exit")
	state.data.containers["test"]=[state.item("band",2)]
	check(state.loot("test",0),"Transfer from container")
	check(not state.loot("test",0),"Loot does not respawn")
	state.hit("Левая рука",15)
	check(state.treat("Левая рука","band"),"Bandage targets bleeding")
	check(float(state.data.wounds["Левая рука"].damage)==15,"Bandage does not magically heal damage")
	check(float(state.data.wounds["Торс"].damage)==0,"Unaffected body zone unchanged")
	world.player.position=world.ORIGIN+Vector3(-24,0.95,-10)
	world._process(0.1)
	world.player.position=world.ORIGIN+Vector3(-24,0.95,0)
	world._process(0.1)
	check(state.data.visited.size()>=2,"Explored room history")
	var clone=preload("res://iso/zarya/state.gd").new(game.zsave.duplicate(true))
	check(clone.data.visited==state.data.visited,"Exploration survives state reload")
	check(clone.data.containers.test.is_empty(),"Container depletion survives reload")
	world.hud.open_inventory()
	check(world.hud.modal!=null,"Inventory opens")
	world.hud.open_medical()
	check(world.hud.modal!=null,"Medical window opens")
	world.hud.close_modal()
	check(not world.paused,"Closing restores controls")
	world.hud.close_modal()
	for door in world.doors:
		var a: Dictionary=world.room_info(door.info.a)
		var b: Dictionary=world.room_info(door.info.b)
		check((absf(float(a.x)-float(b.x))==12 and a.z==b.z) or (a.x==b.x and absf(float(a.z)-float(b.z))==10),"Door connects adjacent cells: "+door.info.id)
		if door.info.kind=="damaged" or door.info.lock=="sealed": continue
		state.data.flags[door.info.lock]=true
		if not door.opened: door.request()
		door._process(1.0)
		await physics_frame
		await physics_frame
		var axis: Vector3=door.global_basis.z
		var center: Vector3=door.global_position+Vector3.UP
		check(world.sees(center-axis*0.6,center+axis*0.6,[world.player.get_rid()]),"Open passage is physically clear: "+door.info.id)
	state.data.slots.clear()
	state.give("pistol"); state.equip("bag0"); state.give("ammo",12)
	world.player.reload()
	world.player._physics_process(1.5)
	check(state.data.mag==7 and state.data.chamber==1,"Reload separates magazine and chamber")
	check(state.amount("ammo")==4,"Reload consumes reserve ammo")
	world.player.busy=0
	world.player.check_ammo()
	world.player._physics_process(1.0)
	check(state.data.checked,"Inspection completes independently of reload")
	var before_mag: int=state.data.mag
	world.player.busy=0
	world.player.shoot()
	check(state.data.mag==before_mag-1 and state.data.chamber==1,"Shot cycles next round into chamber")
	check(not state.data.checked,"Firing invalidates remembered magazine inspection")
	var cfg:=ConfigFile.new()
	world.save_state()
	cfg.set_value("test","save",game.zsave)
	check(cfg.save("user://zarya2_qa.cfg")==OK,"Save writes to disk")
	var restored:=ConfigFile.new()
	check(restored.load("user://zarya2_qa.cfg")==OK,"Save loads from disk")
	var disk=preload("res://iso/zarya/state.gd").new(restored.get_value("test","save"))
	check(disk.data.doors==state.data.doors,"Door states survive disk reload")
	for id in state.data.enemies:
		var before: Dictionary=state.data.enemies[id]
		var after: Dictionary=disk.data.enemies[id]
		check(before.hp==after.hp,"Enemy health survives disk reload")
		check(Vector3(before.position[0],before.position[1],before.position[2]).distance_to(Vector3(after.position[0],after.position[1],after.position[2]))<0.002,"Enemy position survives config float serialization")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://zarya2_qa.cfg"))
	world.player.locked=true
	await world.player.awaken()
	check(state.data.awake and not world.player.locked,"Awakening hands control to player")
	check(world.player.get_node("Visual").scale==Vector3.ONE,"Awakening never stretches model")
	check(world.player.get_node("Visual").skeleton.get_bone_count()==15,"Character has actual bone rig")
	check(world.player.get_node("Visual").skeleton.get_bone_global_pose(2).origin.y>0.5,"Bone rest translations retained")
	print("ZARYA_CHECKS ",checks," FAILED ",failures)
	quit(1 if failures else 0)
