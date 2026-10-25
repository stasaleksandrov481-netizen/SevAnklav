extends "res://scripts/ui/v10/field_panel.gd"
var b
var source: Dictionary
var source_box: VBoxContainer
var inventory_box: VBoxContainer
var title:="ОБЫСК"
var busy:=false
func _ready() -> void:
    title=title.replace("GUARD","ОХРАННИК").replace("SCI","СОТРУДНИК ЛАБОРАТОРИИ").replace("ZMB","НЕИЗВЕСТНЫЙ СОТРУДНИК").replace("guard","охранник")
    caption=title;extent=Vector2(1000,620);super._ready()
    column.add_child(ZUI.wrap_label("Коснитесь находки или перетащите её в рюкзак.",15,V.MUTED,0))
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);row.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(row)
    source_box=_column(row,"НАЙДЕНО",false);inventory_box=_column(row,"РЮКЗАК ВОЛКОВА",true);refresh()
func _column(parent: Node,label: String,target: bool) -> VBoxContainer:
    var panel: PanelContainer=DropBag.new() if target else PanelContainer.new()
    if target: panel.screen=self
    panel.size_flags_horizontal=SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",V.panel(Color(.085,.115,.14),V.EDGE,14));parent.add_child(panel)
    var box:=scroll_column(panel);box.add_child(ZUI.label(label,12,V.ICE));return box
func refresh() -> void:
    for box in [source_box,inventory_box]:
        for child in box.get_children():
            if child.get_index()>0: box.remove_child(child);child.queue_free()
    var counts: Dictionary={}
    for item in source.get("loot_items",[]): counts[item]=int(counts.get(item,0))+1
    for item in counts:
        var card10:=ItemCard.new();card10.screen=self;card10.item=item
        card10.text=b.loadout7.name_of(item)+"   ×"+str(counts[item]);card10.custom_minimum_size=Vector2(0,64)
        card10.icon=b.loadout7.icon_of(item);card10.expand_icon=true;card10.add_theme_constant_override("icon_max_width",42);card10.add_theme_constant_override("h_separation",14);card10.alignment=HORIZONTAL_ALIGNMENT_LEFT;card10.add_theme_font_size_override("font_size",16)
        card10.add_theme_stylebox_override("normal",V.panel(Color(.12,.16,.19),Color(.38,.52,.59,.45),10))
        for state in ["hover","pressed","focus"]: card10.add_theme_stylebox_override(state,V.panel(Color(.17,.24,.28),V.ICE,10))
        source_box.add_child(card10);card10.pressed.connect(func():
            if not card10.was_dragged: transfer(item,card10.global_position+card10.size*.5))
    if counts.is_empty(): source_box.add_child(ZUI.label("Осмотрено. Больше ничего нет.",15,V.MUTED))
    for item in b.loadout7.all_items():
        var count: int=b.loadout7.in_bag(item)
        if count<=0: continue
        var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);inventory_box.add_child(row)
        var picture:=TextureRect.new();picture.texture=b.loadout7.icon_of(item);picture.custom_minimum_size=Vector2(38,38);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(picture)
        var label:=ZUI.label(b.loadout7.name_of(item)+"  ×"+str(count),14,V.TEXT);label.size_flags_vertical=SIZE_SHRINK_CENTER;row.add_child(label)
func transfer(item: String,from: Vector2) -> void:
    if busy or not source.get("loot_items",[]).has(item): return
    busy=true
    var ghost:=TextureRect.new();ghost.texture=b.loadout7.icon_of(item);ghost.size=Vector2(46,46);ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ghost.mouse_filter=MOUSE_FILTER_IGNORE;add_child(ghost);ghost.global_position=from
    var tw:=create_tween().set_parallel(true);tw.tween_property(ghost,"global_position",inventory_box.global_position+Vector2(40,50),.24).set_trans(Tween.TRANS_QUAD);tw.tween_property(ghost,"modulate:a",.2,.24)
    await tw.finished
    if not is_inside_tree(): return
    b._take_loot_item(item);ghost.queue_free();busy=false;refresh()
func _close() -> void:
    if busy: return
    super._close()
class ItemCard extends Button:
    var screen
    var item: String
    var was_dragged:=false
    func _ready() -> void: button_down.connect(func(): was_dragged=false)
    func _get_drag_data(_at: Vector2) -> Variant:
        was_dragged=true;var preview:=ZUI.label(text,16,Color(.85,.92,.95));set_drag_preview(preview)
        return {"bunker_loot":item,"owner":screen}
class DropBag extends PanelContainer:
    var screen
    func _can_drop_data(_at: Vector2,data: Variant) -> bool: return data is Dictionary and data.get("owner")==screen and data.has("bunker_loot")
    func _drop_data(at: Vector2,data: Variant) -> void: screen.transfer(data.bunker_loot,global_position+at)
