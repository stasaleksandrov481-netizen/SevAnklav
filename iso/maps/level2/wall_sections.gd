extends RefCounted
var world
var definitions:Array=[]
var image:Image
var texture:ImageTexture
var fade:=PackedFloat32Array()
var targets:=PackedFloat32Array()
var clock:=0.0
func setup(owner)->void:
 world=owner
 definitions=JSON.parse_string(FileAccess.get_file_as_string("res://iso/maps/level2/wall_sections.json")).sections
 image=Image.create(512,1,false,Image.FORMAT_RGBA8);image.fill(Color.BLACK);texture=ImageTexture.create_from_image(image)
 fade.resize(definitions.size());targets.resize(definitions.size())
 for spec in definitions:
  spec["rooms"]=[]
  var a=Vector2(spec.a[0],spec.a[1]);var b=Vector2(spec.b[0],spec.b[1]);var n=Vector2(spec.normal[0],spec.normal[1])
  spec["length"]=a.distance_to(b);spec["cap_neighbours"]=[]
  for t in [.15,.5,.85]:
   for side in [-1,1]:
    var at=a.lerp(b,t)+n*(float(spec.width)*.5+.38)*side
    var id:String=world.visibility_controller.room_for(world.ORIGIN+Vector3(at.x,0,at.y))
    if not id.is_empty() and not spec.rooms.has(id):spec.rooms.append(id)
 # Short return faces/end caps share the cutaway of the long wall they close.
 # Classifying their perpendicular plane alone leaves opaque triangular fins.
 for spec in definitions:
  if spec.length>1.35:continue
  var middle=(Vector2(spec.a[0],spec.a[1])+Vector2(spec.b[0],spec.b[1]))*.5
  for i in definitions.size():
   var other=definitions[i]
   if other.length<=1.35:continue
   var near=Geometry2D.get_closest_point_to_segment(middle,Vector2(other.a[0],other.a[1]),Vector2(other.b[0],other.b[1]))
   if near.distance_to(middle)<maxf(.75,(float(other.width)+float(spec.width))*.5+.18):spec.cap_neighbours.append(i)
func choose()->void:
 var camera:Vector3=world.get_node("Camera").global_position-world.ORIGIN
 var room:Dictionary=world.room_info(world.visibility_controller.active)
 var corners:Array=room.get("polygon",[])
 var center=Vector2(float(room.get("x",0)),float(room.get("z",0)))
 for i in definitions.size():
  var spec=definitions[i];var middle=Vector2((spec.a[0]+spec.b[0])*.5,(spec.a[1]+spec.b[1])*.5)
  var normal=Vector2(spec.normal[0],spec.normal[1]);var camera_side=(Vector2(camera.x,camera.z)-middle).dot(normal)
  var hide=false
  for id in spec.rooms:
   if id!=world.visibility_controller.active:continue
   # A concave room can have corners behind a wall even when its center and
   # camera are on the same side. Test the whole interior, not only its center.
   for point in corners:
    var interior=Vector2(point[0],point[1]).lerp(center,.02)
    var room_side=(interior-middle).dot(normal)
    if absf(room_side)>.08 and room_side*camera_side<0:hide=true;break
   if hide:break
  targets[i]=1.0 if hide else 0.0
 var straight=targets.duplicate()
 for i in definitions.size():
  for neighbour in definitions[i].cap_neighbours:
   if straight[neighbour]>.5:targets[i]=1.0;break
func update(delta:float)->void:
 clock+=delta
 if clock>=.12:clock=0;choose()
 var changed=false
 for i in fade.size():
  var value=move_toward(fade[i],targets[i],delta*5)
  if is_equal_approx(value,fade[i]):continue
  fade[i]=value;image.set_pixel(i+1,0,Color(value,value,value,1));changed=true
 if changed:texture.update(image)
