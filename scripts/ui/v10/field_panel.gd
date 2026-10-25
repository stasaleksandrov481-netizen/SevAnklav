extends "res://scripts/ui/viewport_control.gd"
const V=preload("res://scripts/ui/visual_theme.gd")
var extent:=Vector2(1120,700)
var card: PanelContainer
var column: VBoxContainer
var heading: Label
var close_button: Button
var caption:="ПЕРСОНАЛЬНЫЙ КОНТУР"
var closing:=false
func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    super._ready();mouse_filter=MOUSE_FILTER_STOP
    var shade:=ColorRect.new();shade.set_anchors_preset(PRESET_FULL_RECT);shade.color=Color(.015,.025,.04,.64);add_child(shade)
    card=PanelContainer.new();card.add_theme_stylebox_override("panel",V.panel(Color(.065,.087,.108,.98),Color(.34,.47,.54,.6),20));add_child(card)
    column=VBoxContainer.new();column.add_theme_constant_override("separation",12);card.add_child(column)
    var mast:=HBoxContainer.new();mast.add_theme_constant_override("separation",16);column.add_child(mast)
    heading=ZUI.label(caption,18,V.TEXT);heading.size_flags_horizontal=SIZE_EXPAND_FILL;mast.add_child(heading)
    close_button=V.button("ЗАКРЫТЬ  ×");close_button.custom_minimum_size=Vector2(122,44);close_button.pressed.connect(_close);mast.add_child(close_button)
    var line:=ColorRect.new();line.custom_minimum_size.y=1;line.color=Color(.4,.55,.62,.3);column.add_child(line)
    _fit_viewport()
    modulate.a=0;create_tween().tween_property(self,"modulate:a",1,.08 if G.zsave.get("bunker_visual",{}).get("reduced_motion10",false) else .18)
func _fit_viewport() -> void:
    super._fit_viewport()
    if card!=null:
        var vp:=get_viewport_rect().size
        card.size=Vector2(minf(extent.x,vp.x-32),minf(extent.y,vp.y-32));card.position=(vp-card.size)*.5
func _close() -> void:
    if closing: return
    closing=true;close_button.disabled=true
    var tw:=create_tween();tw.tween_property(self,"modulate:a",0,.14);tw.tween_callback(queue_free)
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        get_viewport().set_input_as_handled();_close()
static func scroll_column(parent: Node) -> VBoxContainer:
    var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.size_flags_vertical=SIZE_EXPAND_FILL;parent.add_child(scroll)
    var result:=VBoxContainer.new();result.size_flags_horizontal=SIZE_EXPAND_FILL;result.add_theme_constant_override("separation",12);scroll.add_child(result)
    return result
