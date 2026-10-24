extends "res://scripts/ui/viewport_control.gd"
const V=preload("res://scripts/ui/visual_theme.gd")
var b
var page:="equipment"
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
var inspector: Label
var item_picture9: TextureRect
var body_row: HBoxContainer
var selected9:=""
var root9: VBoxContainer
func _ready() -> void:
    super._ready();mouse_filter=Control.MOUSE_FILTER_STOP
    var shade:=ColorRect.new();shade.set_anchors_preset(Control.PRESET_FULL_RECT);shade.color=V.INK;add_child(shade)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,28)
    for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,18)
    add_child(margin)
    var outer:=ScrollContainer.new();outer.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(outer)
    root9=VBoxContainer.new();root9.size_flags_horizontal=SIZE_EXPAND_FILL;root9.size_flags_vertical=SIZE_EXPAND_FILL;root9.add_theme_constant_override("separation",12);outer.add_child(root9)
    var header:=HBoxContainer.new();header.add_theme_constant_override("separation",12);root9.add_child(header)
    var brand:=VBoxContainer.new();brand.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(brand)
    brand.add_child(ZUI.label("V–17   /   ПЕРСОНАЛЬНЫЙ КОНТУР",10,V.MUTED))
    brand.add_child(ZUI.label("Волков",25,V.TEXT))
    var close:=V.button("ЗАКРЫТЬ  ×");close.custom_minimum_size.x=120;close.pressed.connect(_close);header.add_child(close)
    var nav:=HBoxContainer.new();nav.add_theme_constant_override("separation",8);root9.add_child(nav)
    for definition in [["equipment","Снаряжение"],["health","Организм"],["tasks","Задачи"],["records","Записи"]]:
        var button:=V.button(definition[1]);button.custom_minimum_size.x=128
        var key: String=definition[0];button.pressed.connect(func(): select_page(key));tabs[key]=button;nav.add_child(button)
    body_row=HBoxContainer.new();body_row.add_theme_constant_override("separation",26);body_row.size_flags_vertical=SIZE_EXPAND_FILL;root9.add_child(body_row)
    medical=VBoxContainer.new();medical.custom_minimum_size.x=280;medical.add_theme_constant_override("separation",8);body_row.add_child(medical)
    health_status=ZUI.wrap_label("",12,V.MUTED,280);medical.add_child(health_status)
    doll_frame=Control.new();doll_frame.custom_minimum_size=Vector2(280,230);doll_frame.size_flags_vertical=SIZE_EXPAND_FILL;medical.add_child(doll_frame)
    var doll:=preload("res://scripts/ui/anatomy_view.gd").new();doll.btl=b;doll.size=Vector2(280,230);doll_frame.add_child(doll);b._med_doll=doll
    doll_frame.resized.connect(func(): doll.size=doll_frame.size)
    var hands:=HBoxContainer.new();hands.add_theme_constant_override("separation",8);medical.add_child(hands)
    for i in range(2): hands.add_child(_cell("hand",i,Vector2(136,82)))
    info=ZUI.wrap_label("Выберите предмет. Медикамент можно перетащить на повреждённую часть тела.",12,V.MUTED,280);medical.add_child(info);b._med_info_lbl=info
    var use:=V.button("Применить выбранное");use.pressed.connect(func():
        if b._med_sel_item!="": b._med_tap(b._med_sel_item)
        else: info.text="Сначала выберите медицинский предмет.");medical.add_child(use)
    var right:=VBoxContainer.new();right.size_flags_horizontal=SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",10);body_row.add_child(right)
    var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=SIZE_EXPAND_FILL;right.add_child(scroll)
    content=VBoxContainer.new();content.size_flags_horizontal=SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
    var detail:=PanelContainer.new();detail.custom_minimum_size.x=214
    detail.add_theme_stylebox_override("panel",V.panel(Color(.04,.06,.075,.6),Color.TRANSPARENT,14));body_row.add_child(detail)
    var detail_column:=VBoxContainer.new();detail_column.add_theme_constant_override("separation",16);detail.add_child(detail_column)
    detail_column.add_child(ZUI.label("ПРЕДМЕТ / ОСМОТР",10,V.MUTED))
    item_picture9=TextureRect.new();item_picture9.custom_minimum_size=Vector2(180,150);item_picture9.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;item_picture9.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail_column.add_child(item_picture9)
    inspector=ZUI.wrap_label("",14,V.TEXT,184);detail_column.add_child(inspector)
    detail.set_meta("detail9",true)
    footer=HBoxContainer.new();footer.add_theme_constant_override("separation",8);root9.add_child(footer)
    var label:=ZUI.label("БЫСТРЫЙ ДОСТУП",10,V.MUTED);label.custom_minimum_size.x=280;label.size_flags_vertical=SIZE_SHRINK_CENTER;footer.add_child(label)
    for i in range(6): footer.add_child(_cell("quick",i,Vector2(76,62)))
    select_page(page);modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,0.22)
func _cell(place: String,index: int,extent: Vector2) -> Button:
    var cell:=preload("res://scripts/ui/equipment_cell.gd").new();cell.b=b;cell.place=place;cell.index=index;cell.custom_minimum_size=extent
    cell.mouse_entered.connect(func(): show_item9(cell.item))
    cell.button_down.connect(func(): show_item9(cell.item))
    cells.append(cell);return cell
func select_page(key: String) -> void:
    page=key
    for child in content.get_children(): content.remove_child(child);child.queue_free()
    cells=cells.filter(func(cell): return is_instance_valid(cell) and not cell.is_queued_for_deletion());bag_cells.clear()
    medical.visible=key in ["equipment","health"];footer.visible=medical.visible;inspector.get_parent().get_parent().visible=medical.visible
    for id in tabs:
        tabs[id].add_theme_stylebox_override("normal",V.panel(Color(0.08,0.13,0.16,0.8) if id==key else Color.TRANSPARENT,V.EDGE if id==key else Color.TRANSPARENT,10))
        tabs[id].add_theme_color_override("font_color",V.TEXT if id==key else V.MUTED)
    if key in ["equipment","health"]:
        content.add_child(ZUI.label("МЕДИЦИНСКОЕ СНАРЯЖЕНИЕ" if key=="health" else "НОСИМОЕ СНАРЯЖЕНИЕ",12,V.ICE))
        content.add_child(ZUI.wrap_label("Коснитесь предмета — взять в свободную руку. Перетащите на руку, быстрый слот или часть тела.",13,V.MUTED,0))
        item_grid=GridContainer.new();item_grid.columns=3 if get_viewport_rect().size.x<1450 else 4;item_grid.size_flags_horizontal=SIZE_SHRINK_BEGIN;item_grid.add_theme_constant_override("h_separation",10);item_grid.add_theme_constant_override("v_separation",10);content.add_child(item_grid)
        for i in range(b.loadout7.slots().size()):
            var cell:=_cell("bag",i,Vector2(138,112));cell.size_flags_horizontal=SIZE_SHRINK_BEGIN;bag_cells.append(cell);item_grid.add_child(cell)
        show_item9(selected9)
    elif key=="tasks": b._kpk_fill_tasks(content)
    elif key=="records": b._kpk_fill_diary(content)
    if key in ["tasks","records"]: _restyle9(content)
    refresh()
func show_item9(id: String) -> void:
    selected9=id
    item_picture9.texture=b.loadout7.icon_of(id) if id!="" else null
    if id=="": inspector.text="РУКИ И ПЕРЕНОСКА\nПервый предмет — левая рука, следующий — правая. Нажмите слот руки, чтобы убрать предмет.";return
    var details: String=""
    if G.ZITEMS.has(id): details=str(G.ZITEMS[id].get("desc","Перетащите на нужную часть тела для применения."))
    elif id=="flashlight": details="Направленный свет. Работает в любой руке; уберите в рюкзак, чтобы освободить руку."
    elif id.begins_with("weapon:"): details="Занимает обе руки." if b.loadout7.two_handed(id) else "Занимает одну руку. Во второй можно держать фонарь."
    inspector.text=b.loadout7.name_of(id).to_upper()+"\n"+details
func refresh() -> void:
    var state: Dictionary=b.player["st"];var integrity:=0.0;var bleeding:=0
    for zone in state.body: integrity+=float(state.body[zone])
    for wound in state.wounds:
        if not wound.get("tq",false) and not wound.get("clamp",false): bleeding+=int(wound.get("bleed",0))
    health_status.text="БИОМЕТРИЯ   /   V–17\nЦелость %d%%  ·  Заражение %d%%\nКровотечений: %d  ·  Переломов: %d"%[roundi(integrity/maxi(1,state.body.size())*100),roundi(b.player.infect),bleeding,state.get("frac",[]).size()]
    health_status.add_theme_color_override("font_color",V.ALERT if bleeding>0 else V.MUTED)
    if page in ["equipment","health"] and item_grid!=null:
        var capacity: int=b.loadout7.slots().size()
        for i in range(bag_cells.size(),capacity):
            var cell:=_cell("bag",i,Vector2(138,112));bag_cells.append(cell);item_grid.add_child(cell)
    var empty:=0
    for cell in cells:
        if is_instance_valid(cell) and not cell.is_queued_for_deletion():
            cell.refresh()
            if cell.place=="bag":
                if cell.item=="": empty+=1
                cell.visible=cell.item!="" or empty<=2
    if b._med_sel_item!="": info.text=b.loadout7.name_of(b._med_sel_item)+" выбрано. Коснитесь части тела для применения."
func _close() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    var tw:=create_tween();tw.tween_property(self,"modulate:a",0.0,0.16);tw.tween_callback(queue_free)
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        get_viewport().set_input_as_handled();_close()

func _restyle9(node: Node) -> void:
    for child in node.get_children():
        if child is PanelContainer: child.add_theme_stylebox_override("panel",V.panel())
        if child is Label: child.add_theme_color_override("font_color",V.TEXT)
        if child is Button:
            child.add_theme_stylebox_override("normal",V.panel(Color(.04,.06,.075,.5),Color.TRANSPARENT,10))
            child.add_theme_color_override("font_color",V.TEXT)
        _restyle9(child)
