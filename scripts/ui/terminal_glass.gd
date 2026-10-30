extends Control
# Native translucent glass, drawn behind real controls. No baked UI screenshot.
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);resized.connect(queue_redraw)
func _draw()->void:
 var edge=Color(.39,.78,.83,.40)
 for corner in [Vector2(12,12),Vector2(size.x-12,12),Vector2(12,size.y-12),size-Vector2(12,12)]:
  var sx=1 if corner.x<size.x*.5 else -1;var sy=1 if corner.y<size.y*.5 else -1
  draw_line(corner,corner+Vector2(26*sx,0),edge,2);draw_line(corner,corner+Vector2(0,26*sy),edge,2)
 for y in range(28,int(size.y)-20,10):draw_line(Vector2(20,y),Vector2(size.x-20,y),Color(.38,.74,.77,.018),1)
 draw_line(Vector2(28,72),Vector2(size.x-28,72),Color(.32,.67,.73,.19),1)
