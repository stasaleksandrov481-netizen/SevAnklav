extends ZTerminal
const V=preload("res://scripts/ui/visual_theme.gd")
var instant:=false
var body_state: Dictionary={}
var power_ready:=false
var text_size8:=18
var frame10: PanelContainer
func _ready() -> void:
    super._ready();_fit_viewport();get_viewport().size_changed.connect(_fit_viewport)
func panel_rect10() -> Rect2:
    var vp:=get_viewport_rect().size;var extent:=Vector2(minf(1100,vp.x-32),minf(650,vp.y-32));return Rect2((vp-extent)*.5,extent)
func _fit_viewport() -> void:
    set_anchors_preset(PRESET_TOP_LEFT);size=get_viewport_rect().size
    if frame10!=null:
        var r:=panel_rect10();frame10.position=r.position;frame10.size=r.size
func _build() -> void:
    _bg=ColorRect.new();_bg.color=Color(.015,.025,.04,.64);_bg.set_anchors_preset(PRESET_FULL_RECT);add_child(_bg)
    frame10=PanelContainer.new();frame10.add_theme_stylebox_override("panel",V.panel(Color(.065,.09,.11,.98),V.EDGE,24));add_child(frame10)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",14);frame10.add_child(root)
    root.add_child(ZUI.label("ЗАРЯ / ЛОКАЛЬНЫЙ ТЕРМИНАЛ",12,V.ICE))
    var space:=Control.new();space.custom_minimum_size.y=15;root.add_child(space)
    _title_lbl=ZUI.wrap_label(title,25,V.TEXT,0);root.add_child(_title_lbl)
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);row.size_flags_vertical=SIZE_EXPAND_FILL;root.add_child(row)
    var metadata:=VBoxContainer.new();metadata.custom_minimum_size.x=175;metadata.add_theme_constant_override("separation",16);row.add_child(metadata)
    metadata.add_child(ZUI.wrap_label("РЕЖИМ ЧТЕНИЯ\nЛокальный канал",14,V.ICE,175))
    metadata.add_child(ZUI.wrap_label("Внешняя сеть недоступна. Копия сохраняется в КПК Волкова.",14,V.MUTED,175))
    var plus:=V.button("Крупнее текст");metadata.add_child(plus);plus.pressed.connect(func():
        text_size8=18 if text_size8>=24 else text_size8+2
        for label in _lines.get_children(): label.add_theme_font_size_override("font_size",text_size8))
    var sheet:=PanelContainer.new();sheet.size_flags_horizontal=SIZE_EXPAND_FILL;sheet.add_theme_stylebox_override("panel",V.panel(Color(.09,.12,.14),Color(.3,.45,.52,.3),18));row.add_child(sheet)
    var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sheet.add_child(scroll)
    _lines=VBoxContainer.new();_lines.add_theme_constant_override("separation",16);_lines.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(_lines)
    _cursor_lbl=ZUI.label("",12,V.ICE);root.add_child(_cursor_lbl)
    _status_lbl=ZUI.label("ФАЙЛ СОХРАНЁН В ЗАПИСИ КПК",11,V.ICE);root.add_child(_status_lbl)
func _process(delta: float) -> void:
    _blink_t+=delta
    if _cursor_lbl!=null: _cursor_lbl.text="Получение локальной копии…" if not instant and fmod(_blink_t,1.3)<.65 else ""
func print_lines(lines: Array,on_done: Callable=Callable()) -> void:
    if instant:
        for line in lines: _print_one(line)
        done.emit()
        if on_done.is_valid(): on_done.call()
    else: super.print_lines(lines,on_done)
func _print_one(line: Dictionary) -> void:
    if _closed: return
    var text:=str(line.get("text",""));var label:=ZUI.wrap_label(text,text_size8,V.TEXT,0);label.add_theme_constant_override("line_spacing",5);_lines.add_child(label);_type_row(label,text,V.ICE)
func _type_row(label: Label,text: String,col: Color) -> void:
    if instant: label.visible_characters=-1
    else:
        label.visible_characters=0
        var tw:=label.create_tween();tw.tween_property(label,"visible_characters",text.length(),minf(1.2,text.length()*.008))
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        for child in get_children():
            if child is Button and not child.disabled:
                child.pressed.emit();get_viewport().set_input_as_handled();return
