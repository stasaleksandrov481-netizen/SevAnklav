extends Control
# Static draw commands: no full-screen animated shader or per-frame noise.
var kind: String="metal"
var bleed:=0.0
var image:Texture2D
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw()->void:
 var extent:Vector2=size+Vector2.ONE*bleed*2
 draw_set_transform(-Vector2.ONE*bleed)
 if image!=null:
  draw_texture_rect(image,Rect2(Vector2.ZERO,extent),false)
  if kind=="paper":return
 var rng=RandomNumberGenerator.new();rng.seed=742
 if kind=="paper":
  if extent.x<40 or extent.y<40:return
  var points=PackedVector2Array([Vector2(12,12)])
  for i in range(1,25):points.append(Vector2(12+float(i)/25*(extent.x-24),rand_edge(rng)))
  points.append(Vector2(extent.x-12,12))
  for i in range(1,25):points.append(Vector2(extent.x-rand_edge(rng),12+float(i)/25*(extent.y-24)))
  points.append(extent-Vector2(12,12))
  for i in range(1,25):points.append(Vector2(extent.x-12-float(i)/25*(extent.x-24),extent.y-rand_edge(rng)))
  points.append(Vector2(12,extent.y-12))
  for i in range(1,25):points.append(Vector2(rand_edge(rng),extent.y-12-float(i)/25*(extent.y-24)))
  var shadow=PackedVector2Array()
  for p in points:shadow.append(p+Vector2(7,9))
  draw_colored_polygon(shadow,Color(0,0,0,.45));draw_colored_polygon(points,Color("#d0c7ac"))
  var edge=points.duplicate();edge.append(points[0]);draw_polyline(edge,Color("#776d54"),2,true)
  for i in 700:
   var at=Vector2(rng.randf_range(12,extent.x-12),rng.randf_range(12,extent.y-12))
   draw_line(at,at+Vector2(rng.randf_range(1,5),.3),Color(.28,.23,.15,rng.randf_range(.02,.08)),.7,true)
  for x in [.33,.67]:
   draw_line(Vector2(extent.x*x,18),Vector2(extent.x*x+5,extent.y-18),Color(.3,.25,.17,.09),2,true)
   draw_line(Vector2(extent.x*x+2,18),Vector2(extent.x*x+7,extent.y-18),Color(1,.96,.8,.13),1,true)
  draw_line(Vector2(18,extent.y*.5),Vector2(extent.x-18,extent.y*.5+2),Color(.3,.25,.17,.1),2,true)
 else:
  for i in 200:
   var at=Vector2(rng.randf()*extent.x,rng.randf()*extent.y)
   draw_line(at,at+Vector2(rng.randf_range(1,9),0),Color(.56,.7,.72,rng.randf_range(.01,.05)),1)
  if kind=="terminal":
   for y in range(5,int(extent.y),5):draw_line(Vector2(3,y),Vector2(extent.x-3,y),Color(.08,.3,.26,.045),1)
   for at in ([] if image!=null else [Vector2(9,9),Vector2(extent.x-9,9),Vector2(9,extent.y-9),extent-Vector2(9,9)]):
    draw_circle(at,5,Color("#272a27"));draw_arc(at,5,0,TAU,20,Color("#6e6b57"),1,true);draw_line(at-Vector2(3,1),at+Vector2(3,1),Color("#101b1b"),2,true)
func rand_edge(rng:RandomNumberGenerator)->float:return rng.randf_range(0,10)
