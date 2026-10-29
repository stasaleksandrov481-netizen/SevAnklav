extends "res://iso/touch_pad.gd"
signal double_tapped
var input_enabled := true
var double_held:=false
var last_tap_ms:=-1000
var last_tap_point:=Vector2.ZERO
func reset(clear_taps:=true) -> void:
	double_held=false
	if clear_taps:last_tap_ms=-1000
	_pointer=-1; _mouse_down=false; _vector=Vector2.ZERO; queue_redraw()
func set_input_enabled(enabled: bool) -> void:
	if input_enabled==enabled:return
	input_enabled=enabled;reset()
	mouse_filter=Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		reset()
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:reset()
func _gui_input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree():return
	if event is InputEventMouse and _pointer!=-1:return
	var press: bool=(event is InputEventScreenTouch and event.pressed and _pointer==-1) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed)
	if press:
		var now:=Time.get_ticks_msec()
		var double: bool=(event is InputEventMouseButton and event.double_click) or (now-last_tap_ms<=320 and event.position.distance_to(last_tap_point)<=minf(size.x,size.y)*.25)
		last_tap_ms=-1000 if double else now;last_tap_point=event.position
		if double:double_held=true;double_tapped.emit()
	super._gui_input(event)
func _input(event: InputEvent) -> void:
	if not input_enabled:return
	# Releases outside the control must also release the captured finger.
	if event is InputEventScreenTouch and not event.pressed and event.index==_pointer:reset(false)
	elif event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and _mouse_down:reset(false)
	elif event is InputEventScreenDrag and event.index==_pointer:
		_set_from_point(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventMouseMotion and _mouse_down:
		_set_from_point(get_global_transform_with_canvas().affine_inverse()*event.position)
func _draw() -> void:
	var center:=size*0.5
	var radius:=minf(size.x,size.y)*0.39
	draw_circle(center,radius,Color(0.025,0.04,0.05,0.25))
	draw_arc(center,radius,0,TAU,96,Color(0.52,0.61,0.65,0.35),1.2,true)
	draw_arc(center,radius-7,0,TAU,96,Color(0.25,0.33,0.38,0.25),1,true)
	var knob:=center+_vector*radius*0.55
	if get_meta("side",0)==0:
		for i in range(4):
			var angle:=i*PI/2
			var outward:=Vector2.from_angle(angle)
			var tip:=center+outward*(radius-20)
			var tangent:=outward.orthogonal()*5
			draw_colored_polygon(PackedVector2Array([tip,tip-outward*9+tangent,tip-outward*9-tangent]),Color("#62757e"))
		draw_circle(knob,radius*0.34,Color(0.21,0.34,0.36,0.5))
		draw_arc(knob,radius*0.34,0,TAU,64,Color("#83b8b7"),1,true)
	else:
		draw_arc(knob,radius*0.37,0,TAU,64,Color("#61737b"),1,true)
		for i in range(4):
			var axis:=Vector2.from_angle(i*PI/2)
			draw_line(center+axis*(radius-14),center+axis*(radius-39),Color("#7c8e96"),1,true)
			draw_line(knob+axis*6,knob+axis*16,Color("#a7b7bd"),1,true)
		draw_arc(knob,5,0,TAU,32,Color("#a7b7bd"),1,true)
