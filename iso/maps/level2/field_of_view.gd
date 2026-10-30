extends RefCounted
# CPU ray fan + native scanline fills. No per-pixel physics or polygon tests.
const SIZE=Vector2i(256,128)
const RANGE=13.0
const HALF_ANGLE=deg_to_rad(78.0)
var world
var image:Image
var trail:Image
var texture:ImageTexture
var room_image:Image
var visible_rooms := {}
var walked := {}
var last_stamp := Vector3.INF
func setup(owner)->void:
 world=owner;room_image=load("res://iso/maps/level2/room_ids.png").get_image()
 image=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8);trail=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8);trail.fill(Color.BLACK)
 for entry in world.state.data.get("explored_floor",[]):
  var at=Vector2i(int(entry[0]),int(entry[1]))
  if at.x>=0 and at.y>=0 and at.x<SIZE.x and at.y<SIZE.y:walked[at]=true;trail.set_pixelv(at,Color(0,.75,0,1))
 image.copy_from(trail);texture=ImageTexture.create_from_image(image)
func pixel(point:Vector3)->Vector2:
 var p:Vector3=point-world.ORIGIN
 return Vector2((p.x+35.0)*SIZE.x/70.0,(p.z+15.0)*SIZE.y/30.0)
func room_code(at:Vector2i)->int:
 return roundi(room_image.get_pixel(clampi(at.x*4,0,1023),clampi(at.y*4,0,511)).r*255)
func cast(eye:Vector3,direction:Vector3,distance:float)->Vector3:
 var q=PhysicsRayQueryParameters3D.create(eye,eye+direction*distance);q.exclude=[world.player.get_rid()];q.collision_mask=5
 var hit=world.get_world_3d().direct_space_state.intersect_ray(q)
 return eye+direction*distance if hit.is_empty() else hit.position
func fill_polygon(points:PackedVector2Array)->void:
 if points.size()<3:return
 var top=SIZE.y;var bottom=0
 for p in points:top=mini(top,int(floor(p.y)));bottom=maxi(bottom,int(ceil(p.y)))
 for y in range(maxi(0,top),mini(SIZE.y,bottom+1)):
  var crossings=[];var scan=y+.5
  for i in points.size():
   var a=points[i];var b=points[(i+1)%points.size()]
   if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan):crossings.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
  crossings.sort()
  for i in range(0,crossings.size()-1,2):
   var left=clampi(int(floor(crossings[i])),0,SIZE.x-1);var right=clampi(int(ceil(crossings[i+1])),0,SIZE.x-1)
   image.fill_rect(Rect2i(left,y,right-left+1,1),Color(1,1,0,1))
   if y%3==0:
    for x in range(left,right+1,3):
     var code=room_code(Vector2i(x,y))
     if code>0:visible_rooms["sector_"+str(code-1)]=true
func update(ray_count:int)->void:
 image.copy_from(trail);visible_rooms.clear()
 var player=world.player;var eye:Vector3=player.global_position+Vector3.UP*.66
 var forward:Vector3=player.rig.global_basis.z;forward.y=0;forward=forward.normalized()
 var direction=atan2(forward.x,forward.z)
 var fan=PackedVector2Array([pixel(eye)])
 for i in ray_count+1:
  var angle=direction-HALF_ANGLE+float(i)*HALF_ANGLE*2/ray_count
  fan.append(pixel(cast(eye,Vector3(sin(angle),0,cos(angle)),RANGE)))
 fill_polygon(fan)
 # Contact/peripheral awareness never sees through a nearby solid wall.
 var near=PackedVector2Array()
 for i in 28:
  var angle=i*TAU/28;near.append(pixel(cast(eye,Vector3(sin(angle),0,cos(angle)),1.05)))
 fill_polygon(near)
 if last_stamp.distance_squared_to(player.global_position)>.16:
  last_stamp=player.global_position;var center=pixel(last_stamp)
  for y in range(maxi(0,int(center.y)-5),mini(SIZE.y,int(center.y)+6)):
   for x in range(maxi(0,int(center.x)-5),mini(SIZE.x,int(center.x)+6)):
    var at=Vector2i(x,y)
    if Vector2(at).distance_to(center)>4 or image.get_pixelv(at).r<.5 or room_code(at)<18 or walked.has(at):continue
    walked[at]=true;trail.set_pixelv(at,Color(0,.75,0,1))
  world.state.data["explored_floor"]=walked.keys().map(func(p):return [p.x,p.y])
 texture.update(image)
func visible_at(point:Vector3)->bool:
 var at=Vector2i(pixel(point))
 return at.x>=0 and at.y>=0 and at.x<SIZE.x and at.y<SIZE.y and image.get_pixelv(at).r>.5
func can_see(point:Vector3)->bool:
 var eye:Vector3=world.player.global_position+Vector3.UP*.66
 var delta=point-eye;delta.y=0
 if delta.length()>RANGE:return false
 var forward:Vector3=world.player.rig.global_basis.z;forward.y=0
 if delta.length()>1.05 and forward.normalized().dot(delta.normalized())<cos(HALF_ANGLE):return false
 var target=point;target.y=eye.y
 var query=PhysicsRayQueryParameters3D.create(eye,target);query.exclude=[world.player.get_rid()];query.collision_mask=5
 return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
