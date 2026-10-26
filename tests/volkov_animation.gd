extends SceneTree
var failures:=0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rig=load("res://iso/characters/volkov.gd").new(); root.add_child(rig); await process_frame
	rig.set_process(false)
	for speed in [0.0,1.0,1.6]:
		rig.moving=speed
		for frame in range(120): rig._process(1.0/60)
		check(rig.skeleton.get_bone_count()==15,"Articulated rig intact")
	for action in ["shoot","reload","check","pickup","use","treat","balance","wake"]:
		rig.perform(action)
		for frame in range(360 if action=="wake" else 100):
			rig._process(1.0/60)
			for i in range(15):
				check(rig.skeleton.get_bone_pose_scale(i).is_equal_approx(Vector3.ONE),"Animations do not stretch bones")
		check(rig.action.is_empty(),"Action completes")
	rig.weapon_hand="left"; rig.flashlight_hand="right"; rig._process(.1)
	check(rig.weapon.get_parent().bone_name=="hand_l","Weapon follows left hand")
	check(rig.flash.get_parent().bone_name=="hand_r","Flashlight follows right hand")
	rig.flashlight_hand=""; rig._process(.1); check(not rig.flash.visible,"Unequipped flashlight disappears")
	print("VOLKOV_ANIMATION_FAILURES ",failures); quit(1 if failures else 0)
