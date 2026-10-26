extends Node3D
var skeleton: Skeleton3D
var phase := 0.0
var moving := 0.0
var aiming := false
var action := ""
var action_time := 0.0
var lying := 0.0
var weapon: MeshInstance3D
func _ready() -> void:
	skeleton=Skeleton3D.new()
	add_child(skeleton)
	var bones := [["hips",-1,Vector3.ZERO],["spine",0,Vector3(0,0.15,0)],["head",1,Vector3(0,0.55,0)],["arm_l",1,Vector3(-0.34,0.2,0)],["arm_r",1,Vector3(0.34,0.2,0)],["leg_l",0,Vector3(-0.16,-0.2,0)],["leg_r",0,Vector3(0.16,-0.2,0)]]
	for entry in bones:
		skeleton.add_bone(entry[0])
		var i := skeleton.get_bone_count()-1
		skeleton.set_bone_parent(i,entry[1])
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,entry[2]))
	skeleton.reset_bone_poses()
	_part("spine",Vector3(0,0.02,0),0.28,0.75,Color("#32424b"))
	_part("head",Vector3(0,0.12,0),0.18,0.36,Color("#a18e7e"))
	for side in ["l","r"]:
		_part("arm_"+side,Vector3(0,-0.26,0),0.10,0.65,Color("#3b4d56"))
		_part("leg_"+side,Vector3(0,-0.32,0),0.13,0.74,Color("#29383f"))
	_box_part("spine",Vector3(0,0.02,0.18),Vector3(0.49,0.5,0.16),Color("#4a5a5d"))
	_box_part("spine",Vector3(0,0.02,-0.28),Vector3(0.38,0.5,0.22),Color("#3d4d43"))
	for x in [-0.15,0.15]:
		_box_part("spine",Vector3(x,-0.12,0.28),Vector3(0.16,0.17,0.09),Color("#58675d"))
	for side in ["l","r"]:
		_box_part("leg_"+side,Vector3(0,-0.67,0.07),Vector3(0.23,0.18,0.36),Color("#1b262b"))
		_part("arm_"+side,Vector3(0,-0.6,0),0.075,0.17,Color("#9c8774"))
	_box_part("head",Vector3(0,0.24,-0.015),Vector3(0.29,0.16,0.26),Color("#293032"))
	var attach := BoneAttachment3D.new()
	attach.bone_name="arm_r"
	skeleton.add_child(attach)
	weapon=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(0.12,0.16,0.34)
	weapon.mesh=mesh
	weapon.position=Vector3(0,-0.56,0.06)
	attach.add_child(weapon)
func _part(bone: String, at: Vector3, radius: float, height: float, color: Color) -> void:
	var attachment:=BoneAttachment3D.new()
	attachment.bone_name=bone
	skeleton.add_child(attachment)
	var visual:=MeshInstance3D.new()
	var mesh:=CapsuleMesh.new()
	mesh.radius=radius
	mesh.height=height
	mesh.radial_segments=12
	mesh.rings=4
	visual.mesh=mesh
	visual.position=at
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.83
	visual.material_override=material
	attachment.add_child(visual)
func perform(id: String) -> void:
	action=id
	action_time=0
func _process(delta: float) -> void:
	phase+=delta*(10 if moving<1.1 else 14)
	if not is_visible_in_tree(): return
	action_time+=delta
	var gait:=sin(phase)*minf(moving,1.0)*0.5
	skeleton.set_bone_pose_rotation(5,Quaternion(Vector3.RIGHT,gait))
	skeleton.set_bone_pose_rotation(6,Quaternion(Vector3.RIGHT,-gait))
	var use:=sin(minf(action_time/0.8,1.0)*PI)*0.7 if not action.is_empty() else 0.0
	if action_time>0.8: action=""
	skeleton.set_bone_pose_rotation(3,Quaternion(Vector3.RIGHT,-gait*0.5-use))
	skeleton.set_bone_pose_rotation(4,Quaternion(Vector3.RIGHT,-1.4 if aiming else gait*0.5-use))
	skeleton.set_bone_pose_rotation(1,Quaternion(Vector3.FORWARD,lying))

func _box_part(bone: String, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var attachment:=BoneAttachment3D.new()
	attachment.bone_name=bone
	skeleton.add_child(attachment)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=dimensions
	visual.mesh=mesh
	visual.position=at
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.8
	visual.material_override=material
	attachment.add_child(visual)
