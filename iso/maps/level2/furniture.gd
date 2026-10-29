extends Node3D
# Shared-material mesh batches keep detailed furniture affordable on mobile.
var batches := {}
var materials := {}
var world
var count := 0
var decorated_count := 0
var indicators := {}
var valve_wheel: Node3D
var authored := {}
var skipped_ids := []
func set_repair_progress(id: String, progress: float) -> void:
 if id=="pump_valve" and is_instance_valid(valve_wheel):valve_wheel.rotation.y=float(valve_wheel.get_meta("base_angle",0.0))+progress*PI*1.5
const STEEL = Color("#435761")
const PALE = Color("#93aaa9")
const DARK = Color("#17282f")
const PAPER = Color("#c6c8b8")
const RED = Color("#963c35")
func material(c: Color) -> Material:
 var key = c.to_html()
 if not materials.has(key):
  var m: Material
  if c.a<1:
   m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=0.75;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  else:
   m=ShaderMaterial.new();m.shader=preload("res://iso/maps/level2/furniture_visibility.gdshader");m.set_shader_parameter("color",c)
  materials[key]=m
 return materials[key]
func part(root: Node3D, mesh: Mesh, at: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
 var owner: String=str(root.get_meta("room_id",world.room_at(root.global_position)))
 if owner.is_empty():
  var ancestor=root
  while ancestor!=self and ancestor!=null:
   if ancestor.has_meta("room_id"):owner=str(ancestor.get_meta("room_id"));break
   ancestor=ancestor.get_parent()
 if owner.is_empty():
  var best := INF
  var local: Vector3=root.global_position-world.ORIGIN
  for entry in world.layout.rooms:
   var poly: Array=entry.polygon
   for i in range(poly.size()):
    var a=Vector2(poly[i][0],poly[i][1]);var b=Vector2(poly[(i+1)%poly.size()][0],poly[(i+1)%poly.size()][1])
    var d=Geometry2D.get_closest_point_to_segment(Vector2(local.x,local.z),a,b).distance_squared_to(Vector2(local.x,local.z))
    if d<best:best=d;owner=entry.id
 root.set_meta("room_id",owner)
 var key = owner+"|"+color.to_html()
 if not batches.has(key):
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=st
 var basis=Basis.from_euler(rotation)
 var transform=global_transform.affine_inverse()*root.global_transform*Transform3D(basis,at)
 batches[key].append_from(mesh,0,transform)
func box(root: Node3D, size: Vector3, at: Vector3, c: Color) -> void:
 var mesh=BoxMesh.new();mesh.size=size;part(root,mesh,at,c)
func tube(root: Node3D, radius: float, height: float, at: Vector3, c: Color, rotation := Vector3.ZERO) -> void:
 var mesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12
 part(root,mesh,at,c,rotation)
func ring(root: Node3D, inner: float, outer: float, at: Vector3, c: Color, rotation := Vector3.ZERO) -> void:
 var mesh=TorusMesh.new();mesh.inner_radius=inner;mesh.outer_radius=outer;mesh.rings=16;mesh.ring_segments=8;part(root,mesh,at,c,rotation)
func soft(root: Node3D, size: Vector3, at: Vector3, c: Color) -> void:
 var mesh=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=16;mesh.rings=8
 var holder=Node3D.new();root.add_child(holder);holder.position=at;holder.scale=size/2
 part(holder,mesh,Vector3.ZERO,c);holder.free()
func collider(root: Node3D, size: Vector3, offset := Vector3.ZERO) -> void:
 var b=StaticBody3D.new();root.add_child(b)
 var c=CollisionShape3D.new();var s=BoxShape3D.new();s.size=size;c.shape=s;c.position=offset+Vector3(0,size.y/2,0);b.add_child(c)
func sign_at(text: String, at: Vector3, color := PALE) -> void:
 # Gameplay names are drawn in the HUD; no floating text through walls.
 pass
func place(kind: String, x: float, z: float, angle := 0.0, base_y := 0.06, identity := "") -> Node3D:
 var p=Node3D.new();p.name=kind+str(count);count+=1;add_child(p);p.position=Vector3(x,base_y,z);p.rotation.y=deg_to_rad(angle)
 p.set_meta("furniture_id",identity);p.set_meta("furniture_kind",kind);p.set_meta("room_id","sector_0+sector_1" if kind=="glass" and x<-20 else world.room_at(p.global_position))
 match kind:
  "desk", "pc", "bench", "lab":
   box(p,Vector3(1.6,0.09,0.75),Vector3(0,0.78,0),PALE)
   for a in [-0.68,0.68]:
    for b in [-0.26,0.26]:tube(p,0.035,0.735,Vector3(a,0.3675,b),STEEL)
   if kind=="pc":
    box(p,Vector3(0.55,0.36,0.07),Vector3(0,1.08,-0.17),DARK)
    box(p,Vector3(0.48,0.28,0.015),Vector3(0,1.08,-0.125),Color("#477780"))
    tube(p,0.04,0.16,Vector3(0,0.89,-0.17),STEEL)
    box(p,Vector3(0.46,0.025,0.16),Vector3(0,0.85,0.12),DARK)
   else:
    box(p,Vector3(0.30,0.012,0.22),Vector3(-0.25,0.84,0),PAPER)
    if kind=="lab":box(p,Vector3(.28,.035,.20),Vector3(.42,.85,.14),STEEL)
   if kind=="lab":
    tube(p,0.16,0.025,Vector3(-0.45,0.85,-0.1),DARK)
    tube(p,0.04,0.35,Vector3(-0.48,1.03,-0.19),STEEL)
    tube(p,0.04,0.25,Vector3(-0.42,1.22,-0.11),DARK,Vector3(0.5,0,0))
    box(p,Vector3(0.45,0.04,0.18),Vector3(0.25,0.87,-0.17),STEEL)
    for a in [0.1,0.2,0.3,0.4]:tube(p,0.027,0.20,Vector3(a,0.97,-0.17),Color("#669c9e"))
    tube(p,0.09,0.02,Vector3(-0.15,0.85,0.12),PALE)
   if kind=="bench":
    for a in [-0.3,0,0.3]:
     tube(p,0.018,0.3,Vector3(a,0.85,0),DARK,Vector3(PI/2,0,0))
     ring(p,0.025,0.045,Vector3(a,0.85,0.15),STEEL)
   collider(p,Vector3(1.6,0.85,0.75))
  "chair", "fallen_chair":
   var r=Node3D.new();p.add_child(r)
   if kind=="fallen_chair":r.rotation.z=PI/2;r.position=Vector3(0,0.275,0)
   soft(r,Vector3(0.55,0.12,0.5),Vector3(0,0.5,0),DARK)
   soft(r,Vector3(0.52,0.5,0.10),Vector3(0,0.82,-0.22),STEEL)
   for a in [-0.21,0.21]:
    for b in [-0.18,0.18]:tube(r,0.024,0.48,Vector3(a,0.24,b),STEEL)
   if kind=="fallen_chair":collider(p,Vector3(1.1,.64,.65),Vector3(-.5,0,0))
   else:collider(p,Vector3(0.65,0.6,0.6))
  "stool":
   tube(p,.24,.09,Vector3(0,.57,0),DARK)
   for i in range(4):
    var a=i*PI/2
    tube(p,.023,.54,Vector3(cos(a)*.17,.27,sin(a)*.17),STEEL)
   ring(p,.16,.18,Vector3(0,.24,0),STEEL)
   collider(p,Vector3(.52,.62,.52))
  "pallet":
   for z0 in [-.43,.43]:box(p,Vector3(2.7,.07,.12),Vector3(0,.035,z0),Color("#635f4b"))
   for i in range(9):box(p,Vector3(.23,.05,1.15),Vector3(-1.2+i*.3,.095,0),Color("#827c61"))
  "bed", "capsule":
   box(p,Vector3(2.1,0.15,0.92),Vector3(0,0.55,0),STEEL)
   soft(p,Vector3(2.03,0.28,0.9),Vector3(0,0.73,0),PALE)
   soft(p,Vector3(0.43,0.15,0.62),Vector3(-0.68,0.88,0),PAPER)
   for a in [-0.85,0.85]:
    for b in [-0.35,0.35]:tube(p,0.04,0.48,Vector3(a,0.24,b),STEEL)
   if kind=="capsule":
    for a in [-1.0,1.0]:
     ring(p,0.46,0.58,Vector3(a,1.0,0),STEEL,Vector3(0,0,PI/2))
    soft(p,Vector3(1.85,0.8,1.02),Vector3(0,1.12,0),Color(0.35,0.62,0.68,0.28))
    box(p,Vector3(0.2,0.08,0.1),Vector3(0.95,1.57,0),RED)
   else:
    for a in [-1.0,1.0]:box(p,Vector3(0.07,0.58,0.94),Vector3(a,0.7,0),STEEL)
   collider(p,Vector3(2.1,0.9,1.1))
  "locker", "server", "panel", "shelf":
   var height=2.05
   for a in [-0.44,0.44]:box(p,Vector3(0.06,height,0.62),Vector3(a,height/2,0),STEEL)
   box(p,Vector3(0.9,height,0.06),Vector3(0,height/2,-0.28),DARK)
   for h in [0.12,0.65,1.18,1.72,2.04]:
    box(p,Vector3(0.9,0.045,0.62),Vector3(0,h,0),STEEL)
    if kind=="shelf" and h<2:
     for a in [-0.27,0,0.27]:box(p,Vector3(0.21,0.3,0.32),Vector3(a,h+0.17,0),Color("#746c58"))
    if kind=="server":
     box(p,Vector3(0.76,0.32,0.48),Vector3(0,h+0.19,0),DARK)
     for a in [-0.3,-0.22,-0.14]:tube(p,0.015,0.02,Vector3(a,h+0.25,0.26),Color("#77ae9b"),Vector3(PI/2,0,0))
   if kind in ["locker","panel"]:
    box(p,Vector3(0.8,1.9,0.04),Vector3(0,1.04,0.30),PALE if kind=="locker" else STEEL)
    box(p,Vector3(0.025,0.22,0.06),Vector3(0.28,1.0,0.35),DARK)
    for h in [1.6,1.68,1.76]:box(p,Vector3(0.48,0.015,0.02),Vector3(0,h,0.33),DARK)
   collider(p,Vector3(0.94,2.1,0.65))
  "generator", "pump", "tank":
   box(p,Vector3(2.1,0.16,1.1),Vector3(0,0.08,0),DARK)
   if kind=="tank":tube(p,0.52,1.9,Vector3(0,1.11,0),PALE)
   else:
    for x0 in [-.47,.47]:box(p,Vector3(.24,.20,.96),Vector3(x0,.23,0),STEEL)
    tube(p,0.40,1.35,Vector3(0,0.7,0),STEEL,Vector3(0,0,PI/2))
    for a in [-0.4,-0.2,0,0.2,0.4]:tube(p,0.43,0.04,Vector3(a,0.7,0),DARK,Vector3(0,0,PI/2))
    box(p,Vector3(0.45,0.45,0.65),Vector3(0.75,0.6,0),PALE)
    tube(p,0.08,1.4,Vector3(-0.7,0.9,-0.35),STEEL)
    if identity!="pump_primary":ring(p,0.16,0.22,Vector3(-0.7,1.55,-0.35),RED)
   collider(p,Vector3(2.1,1.1,1.1))
  "cart":
   for h in [0.25,0.8]:box(p,Vector3(0.75,0.05,0.48),Vector3(0,h,0),PALE)
   for a in [-0.32,0.32]:
    for b in [-0.18,0.18]:
     tube(p,0.022,0.7,Vector3(a,0.43,b),STEEL)
     tube(p,0.065,0.05,Vector3(a,0.065,b),DARK,Vector3(0,0,PI/2))
   for a in [-0.2,0,0.2]:tube(p,0.045,0.17,Vector3(a,0.9,0),PAPER)
   collider(p,Vector3(0.8,0.9,0.55))
  "paper":
   box(p,Vector3(0.25,0.006,0.18),Vector3(0,0.012,0),PAPER)
   for h in [-0.04,0,0.04]:box(p,Vector3(0.17,0.003,0.007),Vector3(0,0.018,h),DARK)
  "trace":
   soft(p,Vector3(0.6,0.006,0.28),Vector3(0,0.018,0),Color("#44262a"))
   for a in [0.4,0.7,1.0]:soft(p,Vector3(0.07,0.006,0.14),Vector3(a,0.019,a*0.3),Color("#44262a"))
  "crate":
   box(p,Vector3(0.7,0.55,0.5),Vector3(0,0.28,0),Color("#6d725e"))
   for a in [-0.25,0.25]:box(p,Vector3(0.05,0.58,0.53),Vector3(a,0.29,0),DARK)
   collider(p,Vector3(0.72,0.58,0.53))
  "glass":
   box(p,Vector3(2.8,1.1,0.06),Vector3(0,1.45,0),Color(0.35,0.63,0.68,0.3))
   for a in [-1.43,1.43]:box(p,Vector3(0.06,2.1,0.09),Vector3(a,1.05,0),STEEL)
   for h in [0.9,2.02]:box(p,Vector3(2.9,0.06,0.09),Vector3(0,h,0),STEEL)
   collider(p,Vector3(2.9,2.1,0.12))
 if identity=="med_supplies_cabinet":
  box(p,Vector3(.28,.07,.012),Vector3(-.13,1.35,.333),RED)
  box(p,Vector3(.07,.28,.012),Vector3(-.13,1.35,.334),RED)
 preload("res://iso/maps/level2/detail_props.gd").decorate(self,p,kind,count)
 if kind not in ["paper","trace","glass"]:decorated_count+=1
 return p
func finish() -> void:
 for key in batches:
  var node=MeshInstance3D.new();node.mesh=batches[key].commit();node.material_override=material(Color(key.get_slice("|",1)));node.set_meta("room_id",key.get_slice("|",0))
  node.name="Batch_"+key.replace("|","_");node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;add_child(node)
 batches.clear()
func incident_details() -> void:
 # Cables, trays and broken safety glass are visual-only; no hidden movement blockers.
 for spec in [[Vector3(-30,0.1,-6),2.2],[Vector3(-17,0.1,8),1.8],[Vector3(17,0.1,6),1.6]]:
  var root=Node3D.new();root.position=spec[0];add_child(root)
  for i in range(10):
   var a=Vector3(i*0.19,0.0,sin(i*0.45)*0.14)
   tube(root,0.018,0.22,a,DARK,Vector3(0,0,PI/2))
  root.free()
 for at in [Vector3(20,0.075,-1),Vector3(28,0.075,-3.8)]:
  var root=Node3D.new();add_child(root);root.position=at
  for i in range(6):
   var mesh=PrismMesh.new();mesh.size=Vector3(0.06+i*0.015,0.008,0.14)
   part(root,mesh,Vector3(sin(i*2.1)*0.4,0,cos(i*1.7)*0.35),Color("#73979a"),Vector3(0,i*0.8,0))
  root.free()
 for spec in [[Vector3(-30,0,-4),"СВЯЗЬ / НЕТ ОТВЕТА"],[Vector3(16,0,-12),"БИОЗАЩИТА / КОНТУР ИЗОЛИРОВАН"],[Vector3(30,0,10),"ВЫХОД / ПОДТВЕРЖДЕНИЕ СВЕРХУ"]]:
  sign_at(spec[1],spec[0]+Vector3(0,1.8,0),Color("#acbba9"))
func refresh_indicators() -> void:
 for id in indicators:
  var active=world.state.flag(id)
  var m=StandardMaterial3D.new();m.albedo_color=Color("#68c8ab") if active else RED;m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=0.7
  indicators[id].material_override=m
func station(id: String, title: String, at: Vector3, kind: String) -> Dictionary:
 var node=Node3D.new();node.name=id;node.position=at;add_child(node)
 var action={"id":id,"title":title,"kind":kind,"node":node,"record":"","room":world.room_at(node.global_position)}
 world.stations.append(action)
 return action
func point_on(id: String, offset: Vector3, fallback: Vector3) -> Vector3:
 if not authored.has(id):return fallback
 return to_local(authored[id].to_global(offset))
func build(level: Node3D) -> void:
 world=level
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://iso/maps/level2/furnishing.json"))
 # Build work surfaces before seats so every chair can face its actual workstation.
 var ordered=[]
 for entry in data.items:
  if entry.kind not in ["chair","fallen_chair"]:ordered.append(entry)
 for entry in data.items:
  if entry.kind in ["chair","fallen_chair"]:ordered.append(entry)
 for entry in ordered:
  var pos=Vector3(entry.x,0.06,entry.z)
  var safe=true
  if entry.kind!="paper":
   for door in world.doors:
    if Vector2(door.global_position.x-world.ORIGIN.x,door.global_position.z-world.ORIGIN.z).distance_to(Vector2(pos.x,pos.z))<1.8:safe=false
   if Vector2(pos.x,pos.z).distance_to(Vector2(world.player_start.x-world.ORIGIN.x,world.player_start.z-world.ORIGIN.z))<1.7:safe=false
  if not safe:
   skipped_ids.append(str(entry.get("id","")));continue
  var angle: float=entry.angle
  if entry.has("faces") and authored.has(entry.faces):
   var direction: Vector3=authored[entry.faces].position-pos
   angle=rad_to_deg(atan2(direction.x,direction.z))+float(entry.get("facing_bias",0))
  var id: String=entry.get("id","")
  var placed=place(entry.kind,entry.x,entry.z,angle,float(entry.get("base_y",.06)),id)
  if not id.is_empty():authored[id]=placed
  if entry.has("faces"):placed.set_meta("faces",entry.faces)
 for entry in world.layout.rooms:
  if entry.id.trim_prefix("sector_").to_int()>16:continue
  var title=str(entry.title)
  if entry.id!="sector_16":title=title.substr(0,2)+"\n"+title.substr(3)
  var sign_pos=Vector3(entry.x-entry.width*0.24,1.65,entry.z-entry.depth/2+0.7)
  for door in world.doors:
   var local:Vector3=door.global_position-world.ORIGIN
   if Vector2(local.x,local.z).distance_to(Vector2(sign_pos.x,sign_pos.z))<1.8:sign_pos.x=entry.x+entry.width*0.24
  sign_at(title,sign_pos)
 for note in data.notes:
  var at=point_on(str(note.get("on","")),Vector3(note.get("offset",[0,0,0])[0],note.get("offset",[0,0,0])[1],note.get("offset",[0,0,0])[2]),Vector3(note.x,float(note.get("height",.08)),note.z))
  var action=station(note.id,note.title,at,"evidence")
  action.body=note.body
  if note.has("on"):action["anchor"]=note.on
  if note.id not in ["identity_v17","guard_log"]:
   var angle=17.0
   if authored.has(str(note.get("on",""))):angle+=rad_to_deg(authored[note.on].rotation.y)
   place("paper",at.x,at.z,angle,at.y-.012)
 var supplies=[
  ["med_supplies","Медицинский шкаф",Vector3(-31,0.5,-4),[["band",2],["water",1]],"med_supplies_cabinet",Vector3(0,1.05,.46)],
  ["serov_tools","Ящик Серова",Vector3(18.2,0.5,8),[["fuse",1],["tool",1],["flashlight",1],["pistol",1],["ammo",8]],"serov_tools_box",Vector3(0,.64,.36)]]
 for spec in supplies:
  if not authored.has(spec[4]):place("crate",spec[2].x,spec[2].z)
  var action=station(spec[0],spec[1],point_on(spec[4],spec[5],spec[2]),"loot");action["anchor"]=spec[4]
  if not world.state.data.containers.has(spec[0]):
   var loot=[]
   for item in spec[3]:loot.append(world.state.item(item[0],item[1]))
   world.state.data.containers[spec[0]]=loot
 station("relay_k2","КОНТУР K-2 / УСТАНОВИТЬ ПРЕДОХРАНИТЕЛЬ",point_on("electrical_relay",Vector3(0,1.1,.48),Vector3(-6.5,.8,9)),"repair")
 station("pump_valve","НАСОСНАЯ / ОТКРЫТЬ РЕЗЕРВНЫЙ КЛАПАН",point_on("pump_primary",Vector3(-.7,1.55,-.35),Vector3(10.5,.8,6)),"repair")
 for spec in [["relay_k2",point_on("electrical_relay",Vector3(.25,1.5,.34),Vector3(-6.5,1.5,9.3))],["pump_valve",point_on("pump_primary",Vector3(.75,.85,.34),Vector3(10.5,1.2,6.4))]]:
  var lamp=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=0.055;mesh.height=0.11;lamp.mesh=mesh;lamp.position=spec[1];add_child(lamp);indicators[spec[0]]=lamp
 refresh_indicators();world.state.changed.connect(refresh_indicators)
 valve_wheel=Node3D.new();valve_wheel.name="ReserveValve";add_child(valve_wheel)
 valve_wheel.position=point_on("pump_primary",Vector3(-.7,1.55,-.35),Vector3(10.5,1.15,6.15))
 valve_wheel.set_meta("room_id",world.room_at(valve_wheel.global_position));valve_wheel.set_meta("room_visual",true)
 var rim=MeshInstance3D.new();var valve_mesh=TorusMesh.new();valve_mesh.inner_radius=.16;valve_mesh.outer_radius=.22;valve_mesh.rings=16;valve_mesh.ring_segments=8;rim.mesh=valve_mesh;rim.material_override=material(RED);valve_wheel.add_child(rim)
 for angle in [0.0,PI/2]:
  var spoke=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=Vector3(.37,.025,.035);spoke.mesh=shape;spoke.material_override=material(RED);spoke.rotation.y=angle;valve_wheel.add_child(spoke)

 set_repair_progress("pump_valve",1.0 if world.state.flag("pump_valve") else 0.0)
 sign_at("K-2 / РЕЗЕРВ",Vector3(-6.5,2.1,9.6),Color("#d7af61"))
 sign_at("КАРАНТИН\nПРОВЕРЬТЕ ДАВЛЕНИЕ",Vector3(18,2.1,1.6),Color("#d7af61"))
 for x in [26,27,28,29,30,31,32,33]:
  var marker=Node3D.new();add_child(marker);marker.position=Vector3(x,0,4.2)
  box(marker,Vector3(0.4,0.008,0.22),Vector3(0,0.075,0),Color("#b69b50"));marker.free()
 incident_details()
 preload("res://iso/maps/level2/detail_props.gd").room_details(self)
 var receiver=Node3D.new();add_child(receiver);receiver.position=point_on("med_nurse",Vector3(-.53,.87,-.24),Vector3(-31.6,.92,-9.1));receiver.rotation.y=authored["med_nurse"].rotation.y if authored.has("med_nurse") else 0.0
 tube(receiver,.035,.28,Vector3.ZERO,DARK,Vector3(0,0,PI/2))
 for side in [-1,1]:soft(receiver,Vector3(.1,.07,.1),Vector3(side*.13,0,0),DARK)
 for i in range(5):ring(receiver,.014,.021,Vector3(.2+i*.035,-.01,.04),DARK,Vector3(PI/2,0,0))
 var receiver_at: Vector3=receiver.position
 receiver.free()
 var tag=Node3D.new();add_child(tag);tag.position=Vector3(-26.3,.085,-5.7)
 soft(tag,Vector3(.13,.009,.075),Vector3.ZERO,PALE)
 for i in range(7):ring(tag,.005,.009,Vector3(.07+i*.015,0,0),STEEL)
 tag.free()
 var broken=station("broken_receiver","Трубка внутренней связи",receiver_at,"inspect")
 broken.observation="В трубке только треск. Смена не отвечает."
 var identity=station("volkov_tag","Армейский жетон Волкова",Vector3(-26.3,.085,-5.7),"inspect")
 identity.observation="Это мой жетон. Но кто оставил надпись?"
 identity.body="ВОЛКОВ АЛЕКСЕЙ СЕРГЕЕВИЧ\n\nНа обороте нацарапано: «НЕ ВЕРЬ ГОЛОСУ»."
 var cart=station("abandoned_cart","Брошенная медицинская тележка",point_on("observation_cart",Vector3(0,.8,.32),Vector3(-29,.8,3)),"inspect")
 cart.observation="Бросили на ходу. Даже лекарства не забрали."
 finish()
 world.set_meta("furniture_count",count)
 world.set_meta("decorated_furniture_count",decorated_count)
