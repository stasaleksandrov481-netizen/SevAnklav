extends Node3D
# Articulated, smooth anatomical surfaces. World scale and gameplay collision stay unchanged.
var skeleton: Skeleton3D
var moving := 0.0
var aiming := false
var lying := 0.0
var phase := 0.0
var action := ""
var action_time := 0.0
var weapon: MeshInstance3D
var speed_blend := 0.0
var aim_blend := 0.0
var attachments := {}
var indices := {}
var materials := {}
var flash: Node3D
var flashlight_hand := ""
var weapon_hand := "right"
var flashlight_on := false
var fabric: NoiseTexture2D
const CLOTH=Color("#596069")
const PANTS=Color("#38443f")
const SKIN=Color("#ae8b74")
func _ready() -> void:
	skeleton=Skeleton3D.new(); skeleton.name="VolkovSkeleton"; add_child(skeleton)
	for spec in [["hips","",Vector3(0,-0.02,0)],["spine","hips",Vector3(0,0.12,0)],["head","spine",Vector3(0,0.52,0)],["arm_l","spine",Vector3(-0.25,0.29,0)],["arm_r","spine",Vector3(0.25,0.29,0)],["fore_l","arm_l",Vector3(0,-0.29,0)],["fore_r","arm_r",Vector3(0,-0.29,0)],["hand_l","fore_l",Vector3(0,-0.25,0)],["hand_r","fore_r",Vector3(0,-0.25,0)],["leg_l","hips",Vector3(-0.12,-0.06,0)],["leg_r","hips",Vector3(0.12,-0.06,0)],["shin_l","leg_l",Vector3(0,-0.40,0)],["shin_r","leg_r",Vector3(0,-0.40,0)],["foot_l","shin_l",Vector3(0,-0.37,0)],["foot_r","shin_r",Vector3(0,-0.37,0)]]:
		var i:=skeleton.get_bone_count(); skeleton.add_bone(spec[0]); indices[spec[0]]=i
		if spec[1]!="": skeleton.set_bone_parent(i,indices[spec[1]])
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,spec[2]))
		var a:=BoneAttachment3D.new(); a.bone_name=spec[0]; skeleton.add_child(a); attachments[spec[0]]=a
	skeleton.reset_bone_poses()
	loft("spine",[[ -0.13,.17,.115],[0,.185,.13],[.14,.225,.145],[.28,.245,.135],[.34,.19,.11],[.38,.09,.075]],CLOTH)
	oval("hips",Vector3(0,-.025,0),Vector3(.19,.13,.13),PANTS)
	oval("spine",Vector3(0,.39,0),Vector3(.072,.10,.067),SKIN)
	# Jaw, cheeks, brow and crown follow different contours; face points +Z.
	loft("head",[[-.04,.055,.061],[0,.079,.08],[.06,.094,.087],[.13,.098,.085],[.19,.089,.075],[.23,.055,.049],[.24,.015,.02]],SKIN)
	oval("head",Vector3(0,.105,.084),Vector3(.018,.029,.023),SKIN.darkened(.05))
	oval("head",Vector3(0,.015,.063),Vector3(.061,.027,.031),SKIN.darkened(.20))
	oval("head",Vector3(0,.211,-.009),Vector3(.092,.041,.081),Color("#302b29"))
	oval("head",Vector3(0,.030,.091),Vector3(.033,.004,.006),Color("#725549"))
	for side in [-1,1]:
		oval("head",Vector3(side*.095,.085,0),Vector3(.019,.038,.022),SKIN.darkened(.06))
		oval("head",Vector3(side*.039,.128,.077),Vector3(.026,.010,.013),Color("#55463f"))
		oval("head",Vector3(side*.039,.119,.085),Vector3(.014,.006,.005),Color("#747774"))
		oval("head",Vector3(side*.039,.119,.089),Vector3(.005,.005,.003),Color("#273231"))
		# Raised jacket collar, chest pocket flaps, shoulder seams: soft tailored volumes.
		oval("spine",Vector3(side*.085,.35,.068),Vector3(.04,.07,.054),CLOTH.darkened(.17))
		oval("spine",Vector3(side*.112,.23,.14),Vector3(.060,.006,.004),CLOTH.darkened(.25))
	oval("spine",Vector3(0,.10,.142),Vector3(.009,.225,.007),Color("#30383b"))
	oval("spine",Vector3(.12,.20,.151),Vector3(.045,.019,.004),Color("#a6b1b1"))
	for side in ["l","r"]:
		loft("arm_"+side,[[-.32,.063,.066],[-.24,.070,.073],[-.12,.085,.084],[-.015,.093,.09],[.025,.073,.073],[.065,.025,.025]],CLOTH)
		loft("fore_"+side,[[-.26,.045,.049],[-.21,.053,.058],[-.08,.068,.068],[.02,.061,.061]],CLOTH.darkened(.06))
		oval("fore_"+side,Vector3(0,-.22,0),Vector3(.054,.026,.06),CLOTH.darkened(.20))
		oval("hand_"+side,Vector3(0,-.046,.005),Vector3(.046,.070,.028),SKIN)
		for finger in range(4): oval("hand_"+side,Vector3(-.027+finger*.018,-.105,.013),Vector3(.010,.038,.012),SKIN.darkened(.04))
		oval("hand_"+side,Vector3(.045 if side=="l" else -.045,-.044,.018),Vector3(.017,.04,.02),SKIN)
		loft("leg_"+side,[[-.42,.071,.076],[-.30,.087,.094],[-.13,.105,.12],[.03,.10,.11]],PANTS)
		loft("shin_"+side,[[-.38,.061,.067],[-.26,.069,.073],[-.12,.078,.085],[.02,.073,.078]],PANTS.lightened(.04))
		oval("leg_"+side,Vector3(0,-.34,.073),Vector3(.060,.007,.006),PANTS.darkened(.12))
		oval("foot_"+side,Vector3(0,-.035,.06),Vector3(.083,.075,.155),Color("#252b2e"))
		oval("foot_"+side,Vector3(0,-.075,.055),Vector3(.086,.025,.158),Color("#151b1e"))
		for n in range(4): oval("foot_"+side,Vector3(0,.022,.035+n*.022),Vector3(.044,.004,.005),Color("#66706d"))
	# Weapon has a distinct slide, barrel, trigger guard and grip, attached to the hand.
	weapon=MeshInstance3D.new(); weapon.name="Pistol"; attachments.hand_r.add_child(weapon)
	var slide:=BoxMesh.new(); slide.size=Vector3(.042,.19,.045); weapon.mesh=slide; weapon.material_override=material(Color("#333d43")); weapon.position=Vector3(0,-.075,.035); weapon.visible=false
	var grip:=MeshInstance3D.new(); var gm:=BoxMesh.new(); gm.size=Vector3(.038,.07,.085); grip.mesh=gm; grip.position=Vector3(0,.045,-.04); grip.material_override=material(Color("#493c34")); weapon.add_child(grip)
	flash=Node3D.new(); flash.name="Flashlight"; attachments.hand_l.add_child(flash)
	var tube:=MeshInstance3D.new(); var cylinder:=CylinderMesh.new(); cylinder.top_radius=.025; cylinder.bottom_radius=.032; cylinder.height=.17; cylinder.radial_segments=12; tube.mesh=cylinder; tube.position.y=-.08; tube.material_override=material(Color("#303b3d")); flash.add_child(tube); flash.visible=false
	merge_parts()
func merge_parts() -> void:
	# One draw surface per articulated segment; clothing/skin colors live in vertices.
	var shared:=StandardMaterial3D.new(); shared.vertex_color_use_as_albedo=true; shared.vertex_color_is_srgb=true
	shared.roughness=.87; shared.albedo_texture=fabric; shared.uv1_triplanar=true; shared.uv1_scale=Vector3(5,5,5)
	for attachment in attachments.values():
		var sources: Array=[]
		for child in attachment.get_children():
			if child is MeshInstance3D and child!=weapon: sources.append(child)
		if sources.is_empty(): continue
		var builder:=SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for source in sources:
			var arrays: Array=source.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var order: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var normal_basis: Basis=source.transform.basis.inverse().transposed()
			for j in range(order.size() if not order.is_empty() else vertices.size()):
				var index: int=order[j] if not order.is_empty() else j
				builder.set_color(source.material_override.albedo_color)
				builder.set_normal((normal_basis*normals[index]).normalized())
				builder.add_vertex(source.transform*vertices[index])
		builder.index()
		var combined:=MeshInstance3D.new(); combined.mesh=builder.commit(); combined.material_override=shared; attachment.add_child(combined)
		for source in sources: attachment.remove_child(source); source.free()
func material(color: Color) -> StandardMaterial3D:
	var key:=color.to_html()
	if materials.has(key): return materials[key]
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=.87
	if color.b>color.r or color.g>color.r:
		if fabric==null:
			fabric=NoiseTexture2D.new(); fabric.width=128; fabric.height=128; fabric.seamless=true
			var noise:=FastNoiseLite.new(); noise.frequency=.12; noise.fractal_octaves=2; fabric.noise=noise
			var ramp:=Gradient.new(); ramp.set_color(0,Color(.74,.74,.74)); ramp.set_color(1,Color(1,1,1)); fabric.color_ramp=ramp
		m.albedo_texture=fabric; m.uv1_triplanar=true; m.uv1_scale=Vector3(5,5,5)
	materials[key]=m; return m
func oval(bone: String, at: Vector3, radii: Vector3, color: Color) -> void:
	var mesh:=SphereMesh.new(); mesh.radius=1; mesh.height=2; mesh.radial_segments=12; mesh.rings=6
	var v:=MeshInstance3D.new(); v.mesh=mesh; v.position=at; v.scale=radii; v.material_override=material(color); attachments[bone].add_child(v)
func loft(bone: String, rings: Array, color: Color) -> void:
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_smooth_group(0)
	var sides:=20
	for row in range(rings.size()-1):
		for col in range(sides):
			var vertices: Array[Vector3]=[]
			for pair in [[row,col],[row,col+1],[row+1,col],[row+1,col+1]]:
				var ring: Array=rings[pair[0]]; var angle: float=TAU*pair[1]/sides
				vertices.append(Vector3(cos(angle)*ring[1],ring[0],sin(angle)*ring[2]))
			for index in [0,1,2,1,3,2]:
				var r: int=row+(1 if index>=2 else 0)
				var ring: Array=rings[r]
				var prev: Array=rings[maxi(0,r-1)]; var next: Array=rings[mini(rings.size()-1,r+1)]
				var v: Vector3=vertices[index]
				var slope: float=((next[1]-prev[1])+(next[2]-prev[2]))*.5/maxf(.001,next[0]-prev[0])
				st.set_normal(Vector3(v.x/(ring[1]*ring[1]),-slope/maxf(.01,(ring[1]+ring[2])*.5),v.z/(ring[2]*ring[2])).normalized())
				st.add_vertex(v)
	for end in [0,rings.size()-1]:
		var ring: Array=rings[end]
		for col in range(sides):
			var a:=TAU*col/sides; var b:=TAU*(col+1)/sides
			var first:=Vector3(cos(a)*ring[1],ring[0],sin(a)*ring[2]); var second:=Vector3(cos(b)*ring[1],ring[0],sin(b)*ring[2])
			st.set_normal(Vector3.DOWN if end==0 else Vector3.UP); st.add_vertex(Vector3(0,ring[0],0)); st.add_vertex(first if end==0 else second); st.add_vertex(second if end==0 else first)
	st.index()
	var v:=MeshInstance3D.new(); v.mesh=st.commit(); v.material_override=material(color); attachments[bone].add_child(v)
func perform(id: String) -> void:
	action=id; action_time=0
func pose(bone: String, angles: Vector3, blend: float) -> void:
	var i: int=indices[bone]
	skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(Quaternion.from_euler(angles),blend))
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var blend:=1.0-exp(-delta*14)
	speed_blend=lerpf(speed_blend,moving,blend); aim_blend=lerpf(aim_blend,1.0 if aiming else 0.0,blend)
	phase+=delta*lerpf(13.6,18.0,clampf(speed_blend-1,0,1)); action_time+=delta
	var stride:=minf(speed_blend,1.6); var run:=clampf(speed_blend-1,0,1)
	var breath:=sin(Time.get_ticks_msec()*.0018)*.008
	skeleton.set_bone_pose_position(indices.hips,Vector3(0,-.02+absf(sin(phase))*.025*stride,0))
	pose("spine",Vector3(-run*.10+breath,sin(phase)*.045*stride,lying+sin(phase)*.022*stride),blend)
	pose("head",Vector3(-breath,0,-sin(phase)*.018*stride),blend)
	var duration:=2.4 if action=="repair" else (5.0 if action=="wake" else (1.4 if action=="reload" else (.8 if action=="check" else (.26 if action=="shoot" else .7))))
	var progress:=clampf(action_time/duration,0,1); var gesture:=sin(progress*PI) if action!="" else 0.0
	for side in ["l","r"]:
		var wave:=sin(phase+(PI if side=="r" else 0)); var arm_swing: float=wave*stride*.32
		pose("leg_"+side,Vector3(wave*stride*.50-(gesture*.40 if action=="wake" else 0.0),0,0),blend)
		pose("shin_"+side,Vector3(maxf(0,-wave)*stride*.7+.035+(gesture*.65 if action=="wake" else 0.0),0,0),blend)
		pose("foot_"+side,Vector3(-maxf(0,-wave)*stride*.24,0,0),blend)
		var holds: bool=(side=="l" and weapon_hand=="left") or (side=="r" and weapon_hand=="right")
		var arm:=lerpf(-arm_swing,-1.12,aim_blend if holds else aim_blend*.55)
		var elbow:=lerpf(-.14-run*.9,-.40,aim_blend)
		var yaw:=0.0
		if flashlight_on and ((side=="l" and flashlight_hand=="left") or (side=="r" and flashlight_hand=="right")): arm=-1.1; elbow=-.4
		if holds and action in ["reload","check"]: arm=lerpf(arm,-.85,gesture); elbow=lerpf(elbow,-1.25,gesture); yaw=-.25*gesture
		elif not holds and action=="reload": arm=lerpf(arm,-1.0,gesture); elbow=lerpf(elbow,-1.35,gesture); yaw=(.55 if side=="l" else -.55)*gesture
		if holds and action=="shoot": arm-=sin(progress*PI)*.17; elbow-=sin(progress*PI)*.12
		if action in ["pickup","use","treat","balance","wake"]: arm-=gesture*.35; elbow-=gesture*.45
		if action=="repair": arm=-0.85-gesture*0.2; elbow=-0.8-sin(progress*PI*6)*0.12
		var roll:=.07 if side=="r" else -.07
		if not holds and flashlight_hand.is_empty():
			roll=lerpf(roll,.7 if side=="l" else -.7,aim_blend)
			if action not in ["reload","wake"]:
				arm=lerpf(arm,-1.2,aim_blend); elbow=lerpf(elbow,-.3,aim_blend)
		pose("arm_"+side,Vector3(arm,yaw,roll),blend)
		pose("fore_"+side,Vector3(elbow,0,0),blend)
	if action_time>=duration: action=""
	var hand: String="hand_l" if weapon_hand=="left" else "hand_r"
	if weapon.get_parent()!=attachments[hand]: weapon.reparent(attachments[hand],false)
	flash.visible=not flashlight_hand.is_empty()
	if flash.visible:
		var target: String="hand_l" if flashlight_hand=="left" else "hand_r"
		if flash.get_parent()!=attachments[target]: flash.reparent(attachments[target],false)
