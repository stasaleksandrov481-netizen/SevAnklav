extends Control
var t := 0.0
var helicopter_departed: bool:
	get: return t >= 21.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	t += delta
	queue_redraw()
func _draw() -> void:
	var k := size/Vector2(1536,864)
	draw_set_transform(Vector2.ZERO,0,k)
	# The cleaned sky has no baked aircraft. This actor flies out once, then is gone.
	if not helicopter_departed:
		var u := clampf(t/21.0,0,1)
		var p := Vector2(213,322)+Vector2(-410,-58)*(u*u*(3-2*u))
		var scale_f := 1.0-u*0.16
		draw_set_transform(p*k,-0.04,Vector2(-scale_f,scale_f)*k)
		var hull := PackedVector2Array([Vector2(-25,-8),Vector2(5,-12),Vector2(27,-6),Vector2(38,3),Vector2(33,13),Vector2(10,15),Vector2(-23,8)])
		draw_colored_polygon(hull,Color(0.035,0.065,0.078))
		draw_colored_polygon(PackedVector2Array([Vector2(-18,-3),Vector2(-70,-20),Vector2(-75,-15),Vector2(-27,4)]),Color(0.04,0.07,0.08))
		draw_colored_polygon(PackedVector2Array([Vector2(-73,-17),Vector2(-80,-36),Vector2(-85,-36),Vector2(-82,-15)]),Color(0.05,0.08,0.09))
		draw_line(Vector2(5,-12),Vector2(5,-22),Color(0.035,0.065,0.075),3)
		# Perspective rotor blades sweep with motion blur, separately from the fuselage.
		for j in range(3):
			var a := t*31.0+j*PI/3
			var v := Vector2(cos(a)*67,sin(a)*10)
			draw_line(Vector2(4,-22)-v,Vector2(4,-22)+v,Color(0.16,0.21,0.23,0.22),2)
		draw_line(Vector2(-12,20),Vector2(27,20),Color(0.04,0.07,0.08),2)
		draw_line(Vector2(-10,12),Vector2(-7,20),Color(0.04,0.07,0.08),2)
		draw_line(Vector2(22,12),Vector2(24,20),Color(0.04,0.07,0.08),2)
		draw_rect(Rect2(19,-3,10,6),Color(0.10,0.16,0.19))
		draw_circle(Vector2(-32,4),1.3,Color(0.62,0.04,0.015,0.55+0.45*sin(t*4)))
	draw_set_transform(Vector2.ZERO,0,k)
	# Tower beacon, drifting low fog, and warm exhaust at the blast door.
	draw_circle(Vector2(482,263),3.5,Color(1,0.08,0.025,0.15+0.22*(0.5+0.5*sin(t*2))))
	for i in range(9):
		var x := fposmod(440+i*91+t*5,820)
		var y := 654+sin(t*0.23+i)*17
		_draw_fog_ellipse(Rect2(x,y,170,24),Color(0.34,0.42,0.46,0.017))
	draw_set_transform(Vector2.ZERO,0)
func _draw_fog_ellipse(r: Rect2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var a := float(i)/28*TAU
		pts.append(r.get_center()+Vector2(cos(a),sin(a))*r.size*0.5)
	draw_colored_polygon(pts,col)
