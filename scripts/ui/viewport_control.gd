extends Control
# Bind resizing to the actual control, so the viewport disconnects it on deletion.
func _ready() -> void:
    set_anchors_preset(Control.PRESET_TOP_LEFT)
    _fit_viewport()
    get_viewport().size_changed.connect(_fit_viewport)
func _fit_viewport() -> void:
    size=get_viewport_rect().size

func _unhandled_key_input(event: InputEvent) -> void:
    if has_meta("panel") and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        mouse_filter=Control.MOUSE_FILTER_STOP
        var tw:=create_tween()
        tw.tween_property(self,"modulate:a",0.0,0.14)
        tw.tween_callback(queue_free)
