extends ZTerminal
func _ready() -> void:
    super._ready()
    _fit_viewport()
    get_viewport().size_changed.connect(_fit_viewport)
func _fit_viewport() -> void:
    set_anchors_preset(Control.PRESET_TOP_LEFT)
    size=get_viewport_rect().size

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        for child in get_children():
            if child is Button and not child.disabled:
                child.pressed.emit()
                get_viewport().set_input_as_handled()
                return
