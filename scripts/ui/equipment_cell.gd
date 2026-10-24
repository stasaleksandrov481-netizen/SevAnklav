extends Button
var b
var place:="bag"
var index:=0
var item:=""
var count:=0
var selected:=false
var seen_revision:=-1
var was_dragged:=false
func _ready() -> void:
    focus_mode=Control.FOCUS_NONE
    var normal:=ZUI.panel_style(Color(0.025,0.042,0.052,0.82),Color(0.17,0.28,0.33,0.65),8)
    normal.set_corner_radius_all(3)
    add_theme_stylebox_override("normal",normal)
    var hot:=normal.duplicate();hot.border_color=Color(0.45,0.66,0.73);hot.bg_color=Color(0.045,0.08,0.10,0.9)
    for state in ["hover","pressed","focus"]: add_theme_stylebox_override(state,hot)
    button_down.connect(func(): was_dragged=false)
    pressed.connect(_activate)
    refresh()
func _process(_delta: float) -> void:
    if b.inventory_revision7!=seen_revision: refresh()
func refresh() -> void:
    seen_revision=b.inventory_revision7
    match place:
        "hand": item=str(b.loadout7.hands()[index])
        "quick": item=str(G.zsave.get("quick",["","","","","",""])[index])
        "bag":
            var grid: Array=b.loadout7.slots()
            item=str(grid[index]) if index<grid.size() else ""
    count=b.loadout7.in_bag(item) if place=="bag" else (1 if place=="hand" and item!="" else b.loadout7.total(item))
    selected=item!="" and b._med_sel_item==item
    tooltip_text=b.loadout7.name_of(item) if item!="" else "Пусто"
    queue_redraw()
func _activate() -> void:
    if was_dragged or item=="": return
    if place=="hand": b.loadout7.put_away(index)
    elif place=="quick": b._quick_use_item(item)
    else: b.loadout7.equip(item)
func _draw() -> void:
    if selected: draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color(0.48,0.70,0.78,0.7),false,1)
    var heading: String=("ЛЕВАЯ" if index==0 else "ПРАВАЯ") if place=="hand" else (str(index+1) if place=="quick" else "")
    draw_string(ThemeDB.fallback_font,Vector2(7,15),heading,HORIZONTAL_ALIGNMENT_LEFT,size.x-14,10,Color(0.40,0.57,0.64))
    if item!="":
        var tex: Texture2D=b.loadout7.icon_of(item)
        if tex!=null:
            var extent:=minf(size.x-22,size.y-40)
            var picture:=tex.get_size()*minf(extent/tex.get_width(),extent/tex.get_height())
            draw_texture_rect(tex,Rect2(Vector2((size.x-picture.x)*0.5,20+(extent-picture.y)*0.5),picture),false,Color(0.88,0.94,0.95))
        var label: String=b.loadout7.name_of(item)
        if size.x<90:
            if item.begins_with("weapon:"): label={"pistol":"ПМ","rifle":"АК-74М","smg":"ПП","shotgun":"САЙГА","knife":"НОЖ"}.get(item.trim_prefix("weapon:"),label)
            elif label.length()>10: label=label.left(9)+"…"
        draw_string(ThemeDB.fallback_font,Vector2(4,size.y-7),label,HORIZONTAL_ALIGNMENT_CENTER,size.x-8,10,Color(0.64,0.75,0.80))
        if count>1: draw_string(ThemeDB.fallback_font,Vector2(size.x-31,17),"×"+str(count),HORIZONTAL_ALIGNMENT_RIGHT,25,11,Color(0.74,0.86,0.88))
        if b.loadout7.two_handed(item): draw_string(ThemeDB.fallback_font,Vector2(7,29),"2 РУКИ",HORIZONTAL_ALIGNMENT_LEFT,size.x-14,9,Color(0.59,0.71,0.77))
    else:
        var c:=size*0.5
        draw_line(c-Vector2(6,0),c+Vector2(6,0),Color(0.3,0.45,0.51,0.24),1)
        draw_line(c-Vector2(0,6),c+Vector2(0,6),Color(0.3,0.45,0.51,0.24),1)
func _get_drag_data(_at: Vector2) -> Variant:
    if item=="": return null
    was_dragged=true
    var preview:=TextureRect.new();preview.texture=b.loadout7.icon_of(item)
    preview.custom_minimum_size=Vector2(54,54);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    set_drag_preview(preview)
    return {"kind":"med_item" if G.ZITEMS.has(item) else "equipment7","item":item,"from":place,"idx":index}
func _can_drop_data(_at: Vector2,data: Variant) -> bool:
    return data is Dictionary and data.has("item") and b.loadout7.total(str(data["item"]))>0
func _drop_data(_at: Vector2,data: Variant) -> void:
    var id:=str(data["item"])
    var source:=str(data.get("from",""))
    if place=="hand": b.loadout7.equip(id,index)
    elif place=="quick": b._assign_quick(index,id)
    elif source=="hand": b.loadout7.put_away(int(data["idx"]))
    elif source=="quick": b._quick_to_grid(int(data["idx"]),index)
    elif source in ["bag","grid"]: b.loadout7.move_bag(int(data["idx"]),index)
