extends Control
var world
func _draw()->void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("#0a151e"))
 if world==null:return
 var bounds=Rect2();var first=true
 for entry in world.layout.rooms:
  var extent=Vector2(entry.get("width",12),entry.get("depth",10))
  var r=Rect2(Vector2(entry.x,entry.z)-extent/2,extent)
  bounds=r if first else bounds.merge(r);first=false
 if first:return
 var k=minf((size.x-16)/maxf(bounds.size.x,1),(size.y-16)/maxf(bounds.size.y,1))
 var offset=(size-bounds.size*k)/2-bounds.position*k
 for entry in world.layout.rooms:
  var known=world.state.data.visited.has(entry.id)
  if world.custom_layout and not known:continue
  var points=PackedVector2Array()
  if entry.has("polygon"):
   for p in entry.polygon:points.append(Vector2(p[0],p[1])*k+offset)
  else:
   var p=Vector2(entry.x-entry.get("width",12)/2.0,entry.z-entry.get("depth",10)/2.0)*k+offset
   var extent=Vector2(entry.get("width",12),entry.get("depth",10))*k
   points=PackedVector2Array([p,p+Vector2(extent.x,0),p+extent,p+Vector2(0,extent.y)])
  if known:draw_colored_polygon(points,Color("#294653"))
  points.append(points[0]);draw_polyline(points,Color("#6c99a9") if known else Color("#20333e"),1,true)
 var pos:Vector3=world.player.position-world.ORIGIN
 var tracked:String=world.state.data.get("tracked_record","")
 if not tracked.is_empty() and world.state.data.records.has(tracked):
  for action in world.stations:
   if action.id!=tracked:continue
   var local:Vector3=action.node.global_position-world.ORIGIN
   var marker=Vector2(local.x,local.z)*k+offset
   draw_circle(marker,4,Color("#d8b57a"));draw_circle(marker,2,Color("#152731"))
   break
 var at=Vector2(pos.x,pos.z)*k+offset
 draw_circle(at,6,Color(0.5,0.85,0.94,0.15));draw_circle(at,2.5,Color("#a7e2ed"))
