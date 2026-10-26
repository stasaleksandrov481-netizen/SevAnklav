extends Control
var tint:=Color.WHITE
var value:=100.0:
	set(next):
		if int(value)==int(next): return
		value=next; queue_redraw()
func _draw() -> void:
	var width: float=(size.x-48)/10.0
	for i in range(10):
		var r:=Rect2(i*width,6,width-3,8)
		draw_rect(r,Color("#20292e"))
		var fraction:=clampf(value/10.0-i,0,1)
		if fraction>0: draw_rect(Rect2(r.position,Vector2(r.size.x*fraction,r.size.y)),tint)
		draw_rect(r,Color("#5a666b"),false,0.7)
	draw_string(ThemeDB.fallback_font,Vector2(size.x-40,15),str(int(value))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#b8c4c9"))
