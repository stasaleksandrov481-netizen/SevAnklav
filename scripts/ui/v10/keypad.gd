extends "res://scripts/ui/v10/field_panel.gd"
var on_success: Callable
var b
var code:=""
var display: Label
var feedback: Label
func _ready() -> void:
    extent=Vector2(440,500);super._ready()
    column.add_child(ZUI.wrap_label("Четыре цифры. Подсказка может быть в бумажной передаче поста.",14,V.MUTED,0))
    display=ZUI.label("— — — —",28,V.TEXT);display.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(display)
    var grid:=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);column.add_child(grid)
    for key in ["1","2","3","4","5","6","7","8","9","←","0","ВВОД"]:
        var button:=V.button(key);button.custom_minimum_size=Vector2(116,48);button.size_flags_horizontal=SIZE_EXPAND_FILL;grid.add_child(button)
        button.pressed.connect(func(): enter(key))
    feedback=ZUI.label("ЛОКАЛЬНЫЙ ЗАМОК / АВТОНОМНЫЙ",12,V.MUTED);column.add_child(feedback)
func enter(key: String) -> void:
    if key=="←": code=code.left(maxi(0,code.length()-1))
    elif key=="ВВОД":
        if code=="0412":
            feedback.text="Доступ разрешён";feedback.add_theme_color_override("font_color",V.ICE)
            if on_success.is_valid(): on_success.call()
            _close();return
        feedback.text="Код не принят";feedback.add_theme_color_override("font_color",V.WARN);code=""
    elif code.length()<4: code+=key
    display.text=code+"—".repeat(4-code.length())
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode>=KEY_0 and event.keycode<=KEY_9: enter(str(event.keycode-KEY_0));get_viewport().set_input_as_handled();return
        if event.keycode==KEY_ENTER: enter("ВВОД");get_viewport().set_input_as_handled();return
        if event.keycode==KEY_BACKSPACE: enter("←");get_viewport().set_input_as_handled();return
    super._unhandled_key_input(event)
