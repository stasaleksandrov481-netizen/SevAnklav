extends Control

var _pointer := -1
var _mouse_down := false
var _vector := Vector2.ZERO

func get_move_vector() -> Vector2:
	return _vector

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == -1:
			_pointer = event.index
			_set_from_point(event.position)
		elif not event.pressed and event.index == _pointer:
			_pointer = -1
			_vector = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _pointer:
		_set_from_point(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
		if _mouse_down:
			_set_from_point(event.position)
		else:
			_reset_mouse()
	elif event is InputEventMouseMotion and _mouse_down:
		_set_from_point(event.position)

func _reset_mouse() -> void:
	_vector = Vector2.ZERO
	queue_redraw()

func _set_from_point(point: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.45
	_vector = ((point - size * 0.5) / radius).limit_length(1.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.45
	draw_circle(center, radius, Color(0.04, 0.10, 0.13, 0.45))
	draw_arc(center, radius, 0, TAU, 64, Color(0.7, 0.84, 0.87, 0.7), 3.0)
	draw_circle(center + _vector * radius * 0.55, radius * 0.3, Color(0.54, 0.7, 0.74, 0.75))
