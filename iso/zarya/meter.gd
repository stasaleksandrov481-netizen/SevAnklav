extends Control
var tint:=Color.WHITE
var value:=100.0:
 set(next):
  var clamped=clampf(next,0,100)
  var redraw_needed=roundi(value)!=roundi(clamped)
  value=clamped
  if redraw_needed:queue_redraw()
func _draw()->void:
 var length=maxf(8,size.x-48)
 draw_style_box(_bar(Color("#243946")),Rect2(0,6,length,7))
 var portion=clampf(value/100.0,0,1)
 if portion>0:draw_style_box(_bar(tint),Rect2(0,6,length*portion,7))
 draw_string(ThemeDB.fallback_font,Vector2(size.x-39,15),str(roundi(value))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#cfdee4"))
func _bar(color:Color)->StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(2);return s
