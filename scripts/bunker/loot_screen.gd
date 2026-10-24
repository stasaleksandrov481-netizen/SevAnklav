extends "res://scripts/ui/viewport_control.gd"
const V=preload("res://scripts/ui/visual_theme.gd")
var b
var source: Dictionary
var source_box: VBoxContainer
var inventory_box: VBoxContainer
var title := "ОБЫСК"
var busy := false
func _ready() -> void:
    super._ready()
    mouse_filter=Control.MOUSE_FILTER_STOP
    var bg:=ColorRect.new();bg.color=Color(0.005,0.012,0.02,0.94);bg.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(bg)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for key in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+key,48)
    add_child(margin)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",18);margin.add_child(root)
    var head:=HBoxContainer.new();root.add_child(head)
    var name_label:=ZUI.label(title,28,Color(0.77,0.85,0.87));name_label.size_flags_horizontal=SIZE_EXPAND_FILL;head.add_child(name_label)
    var close:=V.button("ЗАКРЫТЬ");close.custom_minimum_size=Vector2(160,52);head.add_child(close);close.pressed.connect(_close)
    root.add_child(ZUI.wrap_label("Перетащите предмет в рюкзак или коснитесь его, чтобы забрать.",16,ZUI.MUTED,1000))
    var row:=HBoxContainer.new();row.size_flags_vertical=SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",32);root.add_child(row)
    source_box=_column(row,"НАЙДЕННЫЕ ВЕЩИ",false)
    inventory_box=_column(row,"ВАШ РЮКЗАК",true)
    refresh()
    modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,0.24)
func _column(parent: HBoxContainer, caption: String, target: bool) -> VBoxContainer:
    var panel:=DropBag.new() if target else PanelContainer.new()
    if target: panel.screen=self
    panel.size_flags_horizontal=SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel",V.panel(Color(0.04,0.065,0.08),Color(0.22,0.34,0.39),22))
    parent.add_child(panel)
    var scroll:=ScrollContainer.new();panel.add_child(scroll)
    var vb:=VBoxContainer.new();vb.size_flags_horizontal=SIZE_EXPAND_FILL;vb.add_theme_constant_override("separation",10);scroll.add_child(vb)
    vb.add_child(ZUI.label(caption,18,Color(0.64,0.77,0.8)))
    return vb
func refresh() -> void:
    for box in [source_box,inventory_box]:
        for c in box.get_children():
            if c.get_index()>0: box.remove_child(c);c.queue_free()
    var counts: Dictionary={}
    for item in source.get("loot_items",[]): counts[item]=int(counts.get(item,0))+1
    for item in counts:
        var card:=ItemCard.new();card.screen=self;card.item=item
        card.text=b._inventory_item_name(item)+"   ×"+str(counts[item]);card.custom_minimum_size=Vector2(0,82)
        card.icon=G.tex("z_i_"+str(item))
        card.expand_icon=true
        card.add_theme_constant_override("icon_max_width",60)
        card.add_theme_constant_override("h_separation",20)
        card.alignment=HORIZONTAL_ALIGNMENT_LEFT
        card.add_theme_font_size_override("font_size",18)
        var style:=V.panel(Color(0.055,0.085,0.10),Color(0.20,0.31,0.36),14)
        card.add_theme_stylebox_override("normal",style)
        var hot:=style.duplicate();hot.border_color=Color(0.57,0.76,0.81);hot.bg_color=Color(0.07,0.12,0.14)
        for state in ["hover","pressed","focus"]: card.add_theme_stylebox_override(state,hot)
        source_box.add_child(card)
        card.pressed.connect(func(): transfer(item,card.global_position+card.size*0.5))
    if counts.is_empty(): source_box.add_child(ZUI.label("Осмотрено. Больше ничего нет.",16,ZUI.MUTED))
    var items: Array=b.loadout7.all_items()
    for item in items:
        var count:=int(b.loadout7.in_bag(item))
        if count>0:
            var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16)
            var thumb:=TextureRect.new();thumb.texture=b.loadout7.icon_of(item);thumb.custom_minimum_size=Vector2(52,52)
            thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE
            row.add_child(thumb)
            row.add_child(ZUI.label(b.loadout7.name_of(item)+"   ×"+str(count),16,ZUI.TEXT))
            inventory_box.add_child(row)
func transfer(item: String, from: Vector2) -> void:
    if busy or not source.get("loot_items",[]).has(item): return
    busy=true
    var ghost:=PanelContainer.new()
    ghost.add_theme_stylebox_override("panel",V.panel(Color(0.08,0.14,0.17,0.95),Color(0.47,0.68,0.74),10))
    var content:=HBoxContainer.new();ghost.add_child(content)
    var image:=TextureRect.new();image.texture=G.tex("z_i_"+item);image.custom_minimum_size=Vector2(44,44)
    image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    content.add_child(image);content.add_child(ZUI.label(b._inventory_item_name(item),17,Color(0.78,0.93,0.94)))
    ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ghost);ghost.global_position=from
    var tw:=create_tween().set_parallel(true)
    tw.tween_property(ghost,"global_position",inventory_box.global_position+Vector2(20,50),0.28).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(ghost,"modulate:a",0.2,0.28)
    await tw.finished
    if not is_inside_tree(): return
    b._take_loot_item(item)
    ghost.queue_free();busy=false;refresh()
func _close() -> void:
    if busy: return
    mouse_filter=Control.MOUSE_FILTER_STOP
    var tw:=create_tween();tw.tween_property(self,"modulate:a",0.0,0.18);tw.tween_callback(queue_free)
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        _close();get_viewport().set_input_as_handled()
class ItemCard extends Button:
    var screen
    var item: String
    func _get_drag_data(_at: Vector2) -> Variant:
        var preview:=ZUI.label(text,18,ZUI.TEXT)
        set_drag_preview(preview)
        return {"bunker_loot":item,"owner":screen}
class DropBag extends PanelContainer:
    var screen
    func _can_drop_data(_at: Vector2, data: Variant) -> bool:
        return data is Dictionary and data.get("owner")==screen and data.has("bunker_loot")
    func _drop_data(at: Vector2,data: Variant) -> void:
        screen.transfer(data["bunker_loot"],global_position+at)
