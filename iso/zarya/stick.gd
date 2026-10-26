extends "res://iso/touch_pad.gd"
func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_pointer=-1; _mouse_down=false; _vector=Vector2.ZERO
func _draw() -> void:
	var center:=size*0.5
	var radius:=minf(size.x,size.y)*0.45
	draw_circle(center,radius,Color(0.025,0.04,0.05,0.52))
	draw_arc(center,radius,0,TAU,96,Color(0.52,0.61,0.65,0.7),1.2,true)
	draw_arc(center,radius-7,0,TAU,96,Color(0.25,0.33,0.38,0.7),1,true)
	var knob:=center+_vector*radius*0.55
	if get_meta("side",0)==0:
		for i in range(4):
			var angle:=i*PI/2
			var outward:=Vector2.from_angle(angle)
			var tip:=center+outward*(radius-20)
			var tangent:=outward.orthogonal()*5
			draw_colored_polygon(PackedVector2Array([tip,tip-outward*9+tangent,tip-outward*9-tangent]),Color("#62757e"))
		draw_circle(knob,radius*0.34,Color(0.30,0.38,0.43,0.65))
		draw_arc(knob,radius*0.34,0,TAU,64,Color("#94a4aa"),1,true)
	else:
		draw_arc(knob,radius*0.37,0,TAU,64,Color("#61737b"),1,true)
		for i in range(4):
			var axis:=Vector2.from_angle(i*PI/2)
			draw_line(center+axis*(radius-14),center+axis*(radius-39),Color("#7c8e96"),1,true)
			draw_line(knob+axis*6,knob+axis*16,Color("#a7b7bd"),1,true)
		draw_arc(knob,5,0,TAU,32,Color("#a7b7bd"),1,true)
