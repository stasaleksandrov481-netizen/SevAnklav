extends ZTerminal
const V=preload("res://scripts/ui/visual_theme.gd")
var instant:=false
var body_state: Dictionary={}
var power_ready:=false
var text_size8:=17
var diagnostic_panel: PanelContainer
func _ready() -> void:
    super._ready()
    _fit_viewport()
    get_viewport().size_changed.connect(_fit_viewport)
func _fit_viewport() -> void:
    set_anchors_preset(Control.PRESET_TOP_LEFT)
    size=get_viewport_rect().size
func _card8(parent: Node,tint: Color=Color(0.025,0.045,0.055)) -> VBoxContainer:
    var card:=PanelContainer.new()
    card.add_theme_stylebox_override("panel",V.panel(tint,Color(0.18,0.31,0.36),16))
    parent.add_child(card)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);card.add_child(column)
    return column
func _build() -> void:
    _bg=ColorRect.new();_bg.color=Color(0.003,0.009,0.014,0.96);_bg.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(_bg)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,38)
    margin.add_theme_constant_override("margin_top",28);margin.add_theme_constant_override("margin_bottom",118);add_child(margin)
    var frame:=PanelContainer.new();frame.add_theme_stylebox_override("panel",V.panel(Color(0.012,0.024,0.031),Color(0.32,0.48,0.52),20));margin.add_child(frame)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",16);frame.add_child(root)
    var mast:=HBoxContainer.new();root.add_child(mast)
    var brand:=ZUI.label("ЗАРЯ",28,Color(0.83,0.90,0.87));brand.size_flags_horizontal=SIZE_EXPAND_FILL;mast.add_child(brand)
    mast.add_child(ZUI.label("АВАРИЙНЫЙ ТЕРМИНАЛ  /  ЛОКАЛЬНЫЙ КОНТУР",12,Color(0.68,0.57,0.35)))
    root.add_child(ZUI.hdivider(2,Color(0.25,0.43,0.47)))
    var workspace:=HBoxContainer.new();workspace.add_theme_constant_override("separation",18);workspace.size_flags_vertical=SIZE_EXPAND_FILL;root.add_child(workspace)
    var navigation:=VBoxContainer.new();navigation.custom_minimum_size.x=180;navigation.add_theme_constant_override("separation",14);workspace.add_child(navigation)
    navigation.add_child(ZUI.label("СЕАНС / V-17",13,Color(0.52,0.70,0.71)))
    var file:=_card8(navigation,Color(0.045,0.082,0.092))
    file.add_child(ZUI.label("01  ДОКУМЕНТ",14,Color(0.80,0.88,0.84)))
    file.add_child(ZUI.wrap_label("Проверенная локальная копия",12,ZUI.MUTED,0))
    navigation.add_child(ZUI.label("СОСТОЯНИЕ КАНАЛОВ",10,ZUI.MUTED))
    for row in [["●  Локальный архив",Color(0.49,0.69,0.56)],["×  Внешняя сеть",Color(0.69,0.42,0.34)],["●  Резервное питание",Color(0.71,0.60,0.36)]]:
        navigation.add_child(ZUI.label(row[0],12,row[1]))
    var spacer:=Control.new();spacer.size_flags_vertical=SIZE_EXPAND_FILL;navigation.add_child(spacer)
    _button8(navigation,"РАЗМЕР ТЕКСТА  +",func():
        text_size8=17 if text_size8>=23 else text_size8+3
        for row in _lines.get_children(): row.add_theme_font_size_override("font_size",text_size8))
    _button8(navigation,"СХЕМА / СКРЫТЬ",func(): diagnostic_panel.visible=not diagnostic_panel.visible)
    var document:=VBoxContainer.new();document.size_flags_horizontal=SIZE_EXPAND_FILL;document.add_theme_constant_override("separation",14);workspace.add_child(document)
    document.add_child(ZUI.label("АРХИВ / ВОССТАНОВЛЕННЫЙ ФАЙЛ",11,Color(0.43,0.62,0.66)))
    _title_lbl=ZUI.wrap_label(title,23,Color(0.83,0.90,0.87),0);document.add_child(_title_lbl)
    var sheet:=PanelContainer.new();sheet.size_flags_vertical=SIZE_EXPAND_FILL
    sheet.add_theme_stylebox_override("panel",V.panel(Color(0.033,0.052,0.059),Color(0.16,0.29,0.32),20));document.add_child(sheet)
    var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sheet.add_child(scroll)
    _lines=VBoxContainer.new();_lines.add_theme_constant_override("separation",16);_lines.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(_lines)
    _cursor_lbl=ZUI.label("_",16,Color(0.52,0.74,0.73));document.add_child(_cursor_lbl)
    diagnostic_panel=PanelContainer.new();diagnostic_panel.custom_minimum_size.x=250
    diagnostic_panel.add_theme_stylebox_override("panel",V.panel(Color(0.018,0.035,0.043),Color(0.20,0.34,0.39),14));workspace.add_child(diagnostic_panel)
    var visual:=Diagnostic.new();visual.custom_minimum_size=Vector2(220,350)
    visual.medical=title.contains("V-17") or title.contains("МЕД") or title.contains("ПЕРСОНАЛ")
    visual.body=body_state;visual.powered=power_ready;diagnostic_panel.add_child(visual)
    if get_viewport_rect().size.x<1100: navigation.hide();diagnostic_panel.hide()
    root.add_child(ZUI.hdivider(1,Color(0.18,0.31,0.35)))
    var footer:=HBoxContainer.new();root.add_child(footer)
    _status_lbl=ZUI.label("ДОСТУП: ЧТЕНИЕ  /  ФАЙЛ СОХРАНЁН В КПК",11,Color(0.43,0.61,0.64));_status_lbl.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(_status_lbl)
    footer.add_child(ZUI.label("ОБЪЕКТ 12  •  СЕВЕРНЫЙ ПЕРИМЕТР",10,Color(0.35,0.50,0.53)))
func _button8(parent: Node,text: String,callback: Callable) -> void:
    var button:=Button.new();button.text=text;button.custom_minimum_size.y=38;button.add_theme_font_size_override("font_size",11)
    button.add_theme_stylebox_override("normal",V.panel(Color(0.025,0.05,0.06),Color(0.23,0.38,0.42),9))
    button.add_theme_stylebox_override("hover",V.panel(Color(0.06,0.11,0.13),Color(0.45,0.64,0.66),9));button.pressed.connect(callback);parent.add_child(button)
func _process(delta: float) -> void:
    _blink_t+=delta
    if _cursor_lbl!=null: _cursor_lbl.visible=not instant and fmod(_blink_t,1.4)<0.7
func print_lines(lines: Array,on_done: Callable=Callable()) -> void:
    if instant:
        for line in lines: _print_one(line)
        done.emit()
        if on_done.is_valid(): on_done.call()
    else: super.print_lines(lines,on_done)
func _print_one(line: Dictionary) -> void:
    if _closed: return
    var text: String=str(line.get("text",""))
    var row:=ZUI.wrap_label(text,text_size8,Color(0.75,0.83,0.80),0)
    row.add_theme_constant_override("line_spacing",7)
    _lines.add_child(row);_type_row(row,text,accent_col)
func _type_row(label: Label,text: String,col: Color) -> void:
    if instant: label.visible_characters=-1
    else: super._type_row(label,text,col)
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        for child in get_children():
            if child is Button and not child.disabled:
                child.pressed.emit();get_viewport().set_input_as_handled();return
class Diagnostic extends Control:
    var medical:=true
    var powered:=false
    var body: Dictionary={}
    func _draw() -> void:
        var ink:=Color(0.46,0.65,0.66)
        var muted:=Color(0.25,0.40,0.44)
        draw_string(ThemeDB.fallback_font,Vector2(4,18),"ДАТЧИКИ V-17" if medical else "СХЕМА КОНТУРА",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
        for y in range(44,260,20): draw_line(Vector2(4,y),Vector2(size.x-4,y),Color(0.10,0.22,0.26),1)
        for x in range(4,int(size.x)-4,20): draw_line(Vector2(x,44),Vector2(x,252),Color(0.10,0.22,0.26),1)
        var center:=Vector2(size.x*0.5,145)
        if medical:
            draw_circle(center+Vector2(0,-74),13,ink)
            var torso:=PackedVector2Array([center+Vector2(-13,-55),center+Vector2(-27,-45),center+Vector2(-18,-8),center+Vector2(-17,17),center+Vector2(17,17),center+Vector2(18,-8),center+Vector2(27,-45),center+Vector2(13,-55)])
            draw_colored_polygon(torso,Color(0.25,0.45,0.47))
            var outline:=torso.duplicate();outline.append(torso[0]);draw_polyline(outline,ink,1,true)
            for side in [-1,1]:
                var shoulder:=center+Vector2(side*25,-42)
                var elbow:=center+Vector2(side*34,-8)
                var hand:=center+Vector2(side*36,19)
                draw_line(shoulder,elbow,ink,10,true);draw_line(elbow,hand,ink,8,true)
                draw_circle(elbow,5,ink);draw_circle(hand,4,ink)
                var hip:=center+Vector2(side*10,17)
                var knee:=center+Vector2(side*12,52)
                var foot:=center+Vector2(side*14,90)
                draw_line(hip,knee,ink,13,true);draw_line(knee,foot,ink,10,true)
                draw_circle(knee,6,ink);draw_circle(foot,5,ink)
            draw_line(center+Vector2(0,-38),center+Vector2(0,3),Color(0.53,0.71,0.68),1)
        else:
            var nodes: Array[Vector2]=[Vector2(36,80),Vector2(size.x-36,80),Vector2(size.x*0.5,148),Vector2(36,221),Vector2(size.x-36,221)]
            for point in nodes:
                draw_line(point,nodes[2],muted,3,true)
                draw_rect(Rect2(point-Vector2(15,12),Vector2(30,24)),Color(0.08,0.17,0.19));draw_rect(Rect2(point-Vector2(15,12),Vector2(30,24)),ink,false,1)
                draw_circle(point,4,Color(0.50,0.69,0.48) if powered else Color(0.76,0.58,0.27))
        draw_string(ThemeDB.fallback_font,Vector2(4,280),"СХЕМА ПОДКЛЮЧЕНИЙ",HORIZONTAL_ALIGNMENT_LEFT,-1,10,muted)
        var trace:=PackedVector2Array()
        for i in range(90):
            var pulse: float=sin(float(i)*0.19)*3.0
            if i%27==11: pulse=-16
            if i%27==12: pulse=22
            trace.append(Vector2(4+float(i)*(size.x-8)/90.0,310+pulse))
        draw_polyline(trace,ink,1.5,true)
        draw_string(ThemeDB.fallback_font,Vector2(4,345),"●  ЛОКАЛЬНЫЙ КАНАЛ",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)
