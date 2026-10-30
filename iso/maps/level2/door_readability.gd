extends RefCounted
# Passive photoluminescent markings remain readable without another light or
# shadow map. Real leaf/hinge/collision and sealed-gate rules stay authoritative.
static var materials := {}
static var users:=0
static func material(key:String,color:Color,emission:float)->StandardMaterial3D:
 if not materials.has(key):
  var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.82;m.metallic=.35
  m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=emission
  materials[key]=m
 return materials[key]
static func box(st:SurfaceTool,size:Vector3,at:Vector3)->void:
 var mesh=BoxMesh.new();mesh.size=size;st.append_from(mesh,0,Transform3D(Basis.IDENTITY,at))
static func batch(parent:Node3D,name:String,st:SurfaceTool,mat:Material)->MeshInstance3D:
 var mesh=MeshInstance3D.new();mesh.name=name;mesh.mesh=st.commit();mesh.material_override=mat
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);return mesh
static func build(door)->void:
 users+=1
 var frame=material("frame",Color("#51646c"),.16)
 for child in door.get_children():
  if child is CSGBox3D:child.material=frame
 door.leaf.material=material("leaf",Color("#536974"),.085)
 var marker=SurfaceTool.new();marker.begin(Mesh.PRIMITIVE_TRIANGLES)
 var width:float=door.leaf.size.x
 for side in [-1,1]:
  for x in [-width*.5+.065,width*.5-.065]:
   box(marker,Vector3(.038,.68,.014),Vector3(x,-.65,side*.17))
   box(marker,Vector3(.095,.014,.48),Vector3(x,-1.212,side*.38))
  # Short threshold dashes point out the opening, without floating room text.
  for x in [-.32,0,.32]:box(marker,Vector3(.14,.012,.07),Vector3(x,-1.208,side*.59))
  box(marker,Vector3(width*.42,.045,.014),Vector3(0,1.08,side*.17))
 door.guide_glow=batch(door,"DoorGuide",marker,state_material("closed"))
 var detail=SurfaceTool.new();detail.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  box(detail,Vector3(width-.20,2.18,.018),Vector3(0,0,side*(door.leaf.size.z*.5+.012)))
  for y in [-.72,.62]:box(detail,Vector3(width-.28,.035,.03),Vector3(0,y,side*(door.leaf.size.z*.5+.031)))
  box(detail,Vector3(.11,.24,.032),Vector3(width*.23,-.22,side*(door.leaf.size.z*.5+.018)))
  box(detail,Vector3(.25,.035,.065),Vector3(width*.18,-.19,side*(door.leaf.size.z*.5+.045)))
  for x in [-width*.3,width*.3]:box(detail,Vector3(.035,1.45,.014),Vector3(x,0,side*(door.leaf.size.z*.5+.01)))
 batch(door.leaf,"LeafHardware",detail,material("hardware",Color("#6d858d"),.18))
static func state_material(state:String)->StandardMaterial3D:
 var color:Color={"closed":Color("#b09a67"),"open":Color("#719c91"),"ready":Color("#88b3a1"),"sealed":Color("#b7614c")}[state]
 return material("guide_"+state,color,.48)
static func sync(door)->void:
 var state=("ready" if door.world.state.flag("pump_valve") and door.world.state.flag("relay_k2") else "sealed") if door.info.kind=="sealed" else ("open" if door.progress>=.8 else "closed")
 if state==door.guide_state:return
 door.guide_state=state;door.guide_glow.material_override=state_material(state)
static func release()->void:
 users=maxi(0,users-1)
 if users==0:materials.clear()
