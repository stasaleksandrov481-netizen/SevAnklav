extends "res://scripts/ui/v10/field_panel.gd"
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
var bag_panel: VBoxContainer
var detail_panel: PanelContainer
var extras: Control
var subtitle: Label
func _ready() -> void:
    caption="V–17 / ПЕРСОНАЛЬНАЯ СИСТЕМА";extent=Vector2(1260,744);super._ready()
    var navigation:=HBoxContainer.new();navigation.add_theme_constant_override("separation",8);column.add_child(navigation)
    for definition in [["equipment","Снаряжение"],["health","Организм"],["tasks","Задачи"],["records","Записи"]]:
        var button:=V.button(definition[1]);button.size_flags_horizontal=SIZE_EXPAND_FILL;var key: String=definition[0];button.pressed.connect(func(): select_page(key));navigation.add_child(button);tabs[key]=button
    body_row=HBoxContainer.new();body_row.add_theme_constant_override("separation",16);body_row.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(body_row)
    medical=VBoxContainer.new();medical.custom_minimum_size.x=240;medical.add_theme_constant_override("separation",8);body_row.add_child(medical)
    health_status=ZUI.wrap_label("",13,V.ICE,240);medical.add_child(health_status)
    doll_frame=Control.new();doll_frame.custom_minimum_size=Vector2(240,170);doll_frame.size_flags_vertical=SIZE_EXPAND_FILL;medical.add_child(doll_frame)
    var doll:=preload("res://scripts/ui/anatomy_view.gd").new();doll.btl=b;doll.size=Vector2(240,220);doll_frame.add_child(doll);b._med_doll=doll
    doll_frame.resized.connect(func(): doll.size=doll_frame.size)
    var hands:=HBoxContainer.new();hands.add_theme_constant_override("separation",8);medical.add_child(hands)
    for i in range(2): hands.add_child(_cell("hand",i,Vector2(116,76)))
    info=ZUI.wrap_label("Медикамент можно перетащить на часть тела.",13,V.TEXT,240);info.custom_minimum_size.y=54
    var info_scroll:=ScrollContainer.new();info_scroll.custom_minimum_size=Vector2(240,72);info_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;medical.add_child(info_scroll);info_scroll.add_child(info);b._med_info_lbl=info
    var use:=V.button("Применить выбранное");use.pressed.connect(func():
        if b._med_sel_item!="": b._med_tap(b._med_sel_item)
        else: info.text="Выберите медицинский предмет.");medical.add_child(use)
    bag_panel=VBoxContainer.new();bag_panel.size_flags_horizontal=SIZE_EXPAND_FILL;bag_panel.add_theme_constant_override("separation",10);body_row.add_child(bag_panel)
    subtitle=ZUI.label("НОСИМОЕ СНАРЯЖЕНИЕ",12,V.ICE);bag_panel.add_child(subtitle)
    content=scroll_column(bag_panel)
    detail_panel=PanelContainer.new();detail_panel.custom_minimum_size.x=190;detail_panel.add_theme_stylebox_override("panel",V.panel(Color(.09,.12,.14),V.EDGE,12));body_row.add_child(detail_panel)
    var detail:=VBoxContainer.new();detail.add_theme_constant_override("separation",14);detail_panel.add_child(detail)
    detail.add_child(ZUI.label("ОСМОТР ПРЕДМЕТА",10,V.ICE))
    item_picture9=TextureRect.new();item_picture9.custom_minimum_size=Vector2(164,115);item_picture9.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;item_picture9.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail.add_child(item_picture9)
    inspector=ZUI.wrap_label("",15,V.TEXT,164);detail.add_child(inspector)
    extras=Control.new();extras.size_flags_vertical=SIZE_EXPAND_FILL;extras.size_flags_horizontal=SIZE_EXPAND_FILL;column.add_child(extras)
    footer=HBoxContainer.new();footer.add_theme_constant_override("separation",8);column.add_child(footer)
    var caption_label:=ZUI.label("БЫСТРЫЙ ДОСТУП",10,V.MUTED);caption_label.custom_minimum_size.x=240;caption_label.size_flags_vertical=SIZE_SHRINK_CENTER;footer.add_child(caption_label)
    for i in range(6): footer.add_child(_cell("quick",i,Vector2(72,58)))
    get_viewport().size_changed.connect(_responsive10);select_page(page)
func _responsive10() -> void:
    if not is_instance_valid(item_grid): return
    detail_panel.visible=card.size.x>=1100 and page in ["equipment","health"]
    var remaining:=card.size.x-296-(210 if detail_panel.visible else 0)
    item_grid.columns=maxi(2,floori(remaining/112.0))
func _cell(place: String,index: int,extent10: Vector2) -> Button:
    var cell:=preload("res://scripts/ui/equipment_cell.gd").new();cell.b=b;cell.place=place;cell.index=index;cell.custom_minimum_size=extent10
    cell.mouse_entered.connect(func(): show_item9(cell.item));cell.button_down.connect(func(): show_item9(cell.item));cells.append(cell);return cell
func select_page(key: String) -> void:
    page=key
    for child in content.get_children(): content.remove_child(child);child.queue_free()
    for child in extras.get_children(): extras.remove_child(child);child.queue_free()
    cells=cells.filter(func(cell): return is_instance_valid(cell) and not cell.is_queued_for_deletion());bag_cells.clear();item_grid=null
    var equipment: bool=key in ["equipment","health"]
    body_row.visible=equipment;extras.visible=not equipment;footer.visible=equipment
    for id in tabs:
        tabs[id].add_theme_color_override("font_color",V.TEXT if id==key else V.MUTED)
        tabs[id].add_theme_stylebox_override("normal",V.panel(Color(.13,.19,.22) if id==key else Color(.055,.08,.10),V.EDGE if id==key else Color.TRANSPARENT,8))
    tabs.records.text="Записи"+("  • "+str(b.investigation10.unread()) if b.investigation10.unread()>0 else "")
    if equipment:
        subtitle.text="ПОДГОТОВКА И ЛЕЧЕНИЕ" if key=="health" else "НОСИМОЕ СНАРЯЖЕНИЕ"
        item_grid=GridContainer.new();item_grid.add_theme_constant_override("h_separation",8);item_grid.add_theme_constant_override("v_separation",8);content.add_child(item_grid)
        _responsive10()
        for i in range(b.loadout7.slots().size()):
            var cell:=_cell("bag",i,Vector2(104,98));bag_cells.append(cell);item_grid.add_child(cell)
        show_item9(selected9)
    elif key=="records":
        var archive:=preload("res://scripts/ui/v10/archive_view.gd").new();archive.b=b;archive.set_anchors_preset(PRESET_FULL_RECT);extras.add_child(archive)
    else: _tasks10()
    refresh()
func _tasks10() -> void:
    var row:=HBoxContainer.new();row.set_anchors_preset(PRESET_FULL_RECT);row.add_theme_constant_override("separation",24);extras.add_child(row)
    var current:=VBoxContainer.new();current.custom_minimum_size.x=420;current.add_theme_constant_override("separation",16);row.add_child(current)
    current.add_child(ZUI.label("АКТИВНАЯ ЦЕЛЬ",12,V.ICE));var frontier: int=b._obj_frontier()
    for objective in b.objectives:
        if not objective.done and int(objective.get("grp",0))==frontier:
            current.add_child(ZUI.wrap_label(objective.text,21,V.TEXT,420))
    current.add_child(ZUI.label("НЕОБЯЗАТЕЛЬНОЕ ИССЛЕДОВАНИЕ",12,V.ICE))
    var state: Dictionary=b.investigation10.state
    for text in ["Архив Волкова: %d материалов"%state.found.size(),"Место происшествия: %d / 3 следа"%state.inspected.size(),"Внешний носитель: "+("восстановлен" if state.get("recovered",false) else "требуется проверка"),"Кабинет исследователя: "+("доступ открыт" if b.doors.office10.opened else "местная блокировка")]:
        current.add_child(ZUI.wrap_label(text,15,V.MUTED,420))
    var history:=scroll_column(row);history.add_child(ZUI.label("ИСТОРИЯ ПРОХОЖДЕНИЯ",12,V.ICE))
    for objective in b.objectives:
        if objective.done: history.add_child(ZUI.wrap_label("✓  "+str(objective.text),15,V.MUTED,0))
func show_item9(id: String) -> void:
    selected9=id;item_picture9.texture=b.loadout7.icon_of(id) if id!="" else null
    if id=="": inspector.text="ЛЕВАЯ / ПРАВАЯ\n\nНажатие на предмет — взять в свободную руку. Нажатие на руку — убрать предмет. Перетащите для точного выбора.";return
    var text: String=str(G.ZITEMS[id].get("desc","Выберите часть тела для применения.")) if G.ZITEMS.has(id) else ("Направленный свет. Работает в любой руке. Можно убрать в рюкзак." if id=="flashlight" else ("Занимает обе руки." if b.loadout7.two_handed(id) else "Занимает одну руку."))
    inspector.text=b.loadout7.name_of(id)+"\n\n"+text
    if not detail_panel.visible: info.text=b.loadout7.name_of(id)+": "+text
func refresh() -> void:
    var state: Dictionary=b.player.st;var total:=0.0;var bleeding:=0
    for zone in state.body: total+=float(state.body[zone])
    for wound in state.wounds:
        if not wound.get("tq",false) and not wound.get("clamp",false): bleeding+=int(wound.get("bleed",0))
    health_status.text="ВОЛКОВ / БИОМЕТРИЯ\nЦелость %d%% · Заражение %d%%\nКровотечений %d · Переломов %d"%[roundi(total/state.body.size()*100),roundi(b.player.infect),bleeding,state.frac.size()]
    health_status.add_theme_color_override("font_color",V.WARN if bleeding>0 else V.ICE)
    if is_instance_valid(item_grid):
        for i in range(bag_cells.size(),b.loadout7.slots().size()):
            var cell:=_cell("bag",i,Vector2(104,98));bag_cells.append(cell);item_grid.add_child(cell)
    var empty:=0
    for cell in cells:
        if not is_instance_valid(cell) or cell.is_queued_for_deletion(): continue
        cell.refresh()
        if cell.place=="bag":
            if cell.item=="": empty+=1
            cell.visible=(cell.item!="" or empty<=2) and (page!="health" or cell.item=="" or G.ZITEMS.has(cell.item))
    if b._med_sel_item!="": info.text=b.loadout7.name_of(b._med_sel_item)+" выбрано. Коснитесь нужной части тела."
