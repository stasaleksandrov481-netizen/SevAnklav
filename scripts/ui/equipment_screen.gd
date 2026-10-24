extends "res://scripts/ui/viewport_control.gd"
var b
var page:="equipment"
var body_row: HBoxContainer
var medical: VBoxContainer
var content: VBoxContainer
var info: Label
var health_status: Label
var item_grid: GridContainer
var cells: Array=[]
var bag_cells: Array=[]
var tabs: Dictionary={}
var footer: HBoxContainer
var doll_frame: Control
func _ready() -> void:
    super._ready()
    mouse_filter=Control.MOUSE_FILTER_STOP
    var shade:=ColorRect.new();shade.set_anchors_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.006,0.013,0.020,0.97);add_child(shade)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,40)
    for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
    add_child(margin)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",12);margin.add_child(root)
    var header:=HBoxContainer.new();header.add_theme_constant_override("separation",18);root.add_child(header)
    var title:=ZUI.label("ВОЛКОВ / ПОЛЕВОЕ СНАРЯЖЕНИЕ",26,Color(0.78,0.85,0.88));title.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(title)
    var close:=_button("ЗАКРЫТЬ",130);close.pressed.connect(_close);header.add_child(close)
    var tab_row:=HBoxContainer.new();tab_row.add_theme_constant_override("separation",12);root.add_child(tab_row)
    for definition in [["equipment","СНАРЯЖЕНИЕ"],["health","ОРГАНИЗМ"],["tasks","ЗАДАЧИ"],["records","ЗАПИСИ"]]:
        var button:=_button(definition[1],156);var key: String=definition[0]
        button.pressed.connect(func(): select_page(key));tabs[key]=button;tab_row.add_child(button)
    var rule:=ColorRect.new();rule.color=Color(0.24,0.39,0.46,0.5);rule.custom_minimum_size.y=1;root.add_child(rule)
    body_row=HBoxContainer.new();body_row.add_theme_constant_override("separation",30);body_row.size_flags_vertical=SIZE_EXPAND_FILL;root.add_child(body_row)
    medical=VBoxContainer.new();medical.custom_minimum_size.x=250;medical.add_theme_constant_override("separation",8);body_row.add_child(medical)
    medical.add_child(ZUI.label("СОСТОЯНИЕ ОРГАНИЗМА",13,Color(0.43,0.61,0.69)))
    health_status=ZUI.wrap_label("",12,ZUI.MUTED,248);medical.add_child(health_status)
    var frame:=Control.new();doll_frame=frame;medical.add_child(frame)
    var doll:=ZMedUI.BodyDoll.new();doll.btl=b
    var k:=0.61 if get_viewport_rect().size.y<800 else 0.82
    doll.custom_minimum_size=Vector2(250,340);doll.size=Vector2(250,340);doll.scale=Vector2.ONE*k
    frame.custom_minimum_size=Vector2(250,340*k);frame.add_child(doll)
    b._med_doll=doll
    info=ZUI.wrap_label("Коснитесь части тела для осмотра. Предмет можно перетащить на повреждённую зону.",13,ZUI.MUTED,248);medical.add_child(info);b._med_info_lbl=info
    var use:=_button("ПРИМЕНИТЬ ВЫБРАННОЕ",240)
    use.pressed.connect(func():
        if b._med_sel_item!="": b._med_tap(b._med_sel_item)
        else: info.text="Возьмите медицинский предмет и выберите нужную часть тела.")
    medical.add_child(use)
    var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.size_flags_vertical=SIZE_EXPAND_FILL;body_row.add_child(scroll)
    content=VBoxContainer.new();content.size_flags_horizontal=SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
    footer=HBoxContainer.new();footer.add_theme_constant_override("separation",24);root.add_child(footer)
    var hand_box:=VBoxContainer.new();hand_box.add_theme_constant_override("separation",7);footer.add_child(hand_box)
    hand_box.add_child(ZUI.label("РУКИ / НАЖАТЬ — УБРАТЬ",11,ZUI.MUTED))
    var hands_row:=HBoxContainer.new();hands_row.add_theme_constant_override("separation",8);hand_box.add_child(hands_row)
    for i in range(2):
        var cell:=_cell("hand",i,Vector2(108,90));hands_row.add_child(cell)
    var access:=VBoxContainer.new();access.size_flags_horizontal=SIZE_EXPAND_FILL;access.add_theme_constant_override("separation",7);footer.add_child(access)
    access.add_child(ZUI.label("БЫСТРЫЙ ДОСТУП / ЯРЛЫКИ ПРЕДМЕТОВ",11,ZUI.MUTED))
    var quick_row:=HBoxContainer.new();quick_row.add_theme_constant_override("separation",8);access.add_child(quick_row)
    for i in range(6): quick_row.add_child(_cell("quick",i,Vector2(88,90)))
    select_page(page)
    modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,0.22)
func _button(caption: String,width: float) -> Button:
    var button:=Button.new();button.text=caption;button.custom_minimum_size=Vector2(width,40)
    button.add_theme_font_size_override("font_size",14)
    button.add_theme_stylebox_override("normal",ZUI.panel_style(Color(0.025,0.045,0.06,0.7),Color(0.20,0.34,0.41),10))
    var hot:=ZUI.panel_style(Color(0.06,0.11,0.14,0.9),Color(0.44,0.64,0.73),10)
    for state in ["hover","pressed","focus"]: button.add_theme_stylebox_override(state,hot)
    return button
func _cell(place: String,index: int,extent: Vector2) -> Button:
    var cell:=preload("res://scripts/ui/equipment_cell.gd").new();cell.b=b;cell.place=place;cell.index=index;cell.custom_minimum_size=extent
    cells.append(cell)
    return cell
func select_page(key: String) -> void:
    page=key
    for child in content.get_children(): content.remove_child(child);child.queue_free()
    cells=cells.filter(func(cell): return is_instance_valid(cell) and not cell.is_queued_for_deletion())
    bag_cells.clear()
    medical.visible=key in ["equipment","health"]
    footer.visible=key=="equipment"
    var scale_factor:=0.86 if key=="health" else (0.61 if get_viewport_rect().size.y<800 else 0.82)
    b._med_doll.scale=Vector2.ONE*scale_factor
    doll_frame.custom_minimum_size.y=340*scale_factor
    for id in tabs: tabs[id].add_theme_color_override("font_color",Color(0.85,0.93,0.96) if id==key else Color(0.40,0.57,0.65))
    if key in ["equipment","health"]:
        content.add_child(ZUI.label("РЮКЗАК",17,Color(0.66,0.79,0.84)))
        content.add_child(ZUI.wrap_label("Нажатие — взять в свободную руку: сначала левую, затем правую. Перетащите в слот руки для точного выбора. Оружие с отметкой «2 РУКИ» занимает обе.",13,ZUI.MUTED,800))
        item_grid=GridContainer.new();item_grid.columns=6;item_grid.add_theme_constant_override("h_separation",7);item_grid.add_theme_constant_override("v_separation",7);content.add_child(item_grid)
        var grid: Array=b.loadout7.slots()
        for i in range(grid.size()):
            var cell:=_cell("bag",i,Vector2(94,92));cell.size_flags_horizontal=SIZE_EXPAND_FILL;bag_cells.append(cell);item_grid.add_child(cell)
    elif key=="tasks": b._kpk_fill_tasks(content)
    elif key=="records": b._kpk_fill_diary(content)
    refresh()
func refresh() -> void:
    var state: Dictionary=b.player["st"]
    var health:=0.0
    for zone in state["body"]: health+=float(state["body"][zone])
    health/=maxi(1,state["body"].size())
    var bleeding:=0
    for wound in state["wounds"]:
        if not wound.get("tq",false) and not wound.get("clamp",false): bleeding+=int(wound.get("bleed",0))
    var infection: float=b.player["infect"]
    health_status.text="Целость %d%% · Кровь: %d\nЗаражение %d%% · %.1f°C\nПереломы: %d"%[roundi(health*100),bleeding,roundi(infection),36.6+infection*0.024,state.get("frac",[]).size()]
    health_status.add_theme_color_override("font_color",ZUI.ALERT if bleeding>0 else ZUI.MUTED)
    for cell in cells:
        if is_instance_valid(cell) and not cell.is_queued_for_deletion(): cell.refresh()
    if b._med_sel_item!="": info.text=b.loadout7.name_of(b._med_sel_item)+" выбрано. Перетащите на часть тела или нажмите нужную зону."
func _close() -> void:
    var tw:=create_tween();tw.tween_property(self,"modulate:a",0.0,0.16);tw.tween_callback(queue_free)
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        get_viewport().set_input_as_handled();_close()
