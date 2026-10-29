extends Control
# The same virtual canvas as the bunker HUD; typography and tap targets keep their sizes.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_page();get_viewport().size_changed.connect(_fit_page)
func _fit_page() -> void:
	var viewport_size:=get_viewport_rect().size
	var safe:=Rect2(Vector2.ZERO,viewport_size)
	if OS.has_feature("mobile"):
		var pixels:=DisplayServer.get_display_safe_area();var window_pixels:=Vector2(DisplayServer.window_get_size())
		if pixels.has_area() and window_pixels.x>0 and window_pixels.y>0:safe=Rect2(Vector2(pixels.position)*viewport_size/window_pixels,Vector2(pixels.size)*viewport_size/window_pixels).intersection(safe)
	var factor:=minf(1.0,minf(safe.size.x/1600.0,safe.size.y/900.0))
	if factor<=0:return
	scale=Vector2.ONE*factor;position=safe.position;size=safe.size/factor
