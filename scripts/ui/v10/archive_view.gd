extends HBoxContainer
const V=preload("res://scripts/ui/visual_theme.gd")
const Data=preload("res://scripts/bunker/v10/archive_data.gd")
var b
var category:=-1
var selection:=""
var listing: VBoxContainer
var document: VBoxContainer
var categories: VBoxContainer
var entries: Array=[]
func _ready() -> void:
    add_theme_constant_override("separation",16)
    categories=VBoxContainer.new();categories.custom_minimum_size.x=174;categories.add_theme_constant_override("separation",6);add_child(categories)
    var list_scroll:=ScrollContainer.new();list_scroll.custom_minimum_size.x=260;list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list_scroll.size_flags_vertical=SIZE_EXPAND_FILL;add_child(list_scroll)
    listing=VBoxContainer.new();listing.size_flags_horizontal=SIZE_EXPAND_FILL;listing.add_theme_constant_override("separation",8);list_scroll.add_child(listing)
    var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",V.panel(Color(.082,.108,.13),V.EDGE,18));panel.size_flags_horizontal=SIZE_EXPAND_FILL;add_child(panel)
    document=preload("res://scripts/ui/v10/field_panel.gd").scroll_column(panel)
    entries=b.investigation10.entries();refresh_categories();select_category(-1)
func refresh_categories() -> void:
    for child in categories.get_children(): categories.remove_child(child);child.queue_free()
    categories.add_child(ZUI.label("АРХИВ ВОЛКОВА",11,V.ICE))
    for i in range(-1,Data.CATEGORIES.size()):
        var count:=0;var fresh:=0
        for entry in entries:
            if i<0 or entry.category==i: count+=1;fresh+=1 if entry.get("new",false) else 0
        var title: String=("Все материалы" if i<0 else Data.CATEGORIES[i])+" · "+str(count)+("  •" if fresh>0 else "")
        var button:=V.button(title);button.custom_minimum_size.x=174;button.add_theme_font_size_override("font_size",12);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;categories.add_child(button)
        var index:=i;button.pressed.connect(func(): select_category(index))
func select_category(index: int) -> void:
    category=index
    for child in listing.get_children(): listing.remove_child(child);child.queue_free()
    var first: Dictionary={}
    for entry in entries:
        if index>=0 and entry.category!=index: continue
        if first.is_empty(): first=entry
        var button:=V.button(("•  " if entry.get("new",false) else "")+str(entry.title))
        button.custom_minimum_size=Vector2(250,62);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",14)
        button.set_meta("entry10",str(entry.id))
        listing.add_child(button);button.pressed.connect(func(): show_entry(entry))
    if first.is_empty():
        listing.add_child(ZUI.wrap_label("Пока нет найденных материалов этой категории.",14,V.MUTED,250));clear_document()
        document.add_child(ZUI.wrap_label("Исследуйте рабочие места, личные вещи и бумажные документы. Важные находки сохраняются автоматически.",18,V.TEXT,0))
    else: show_entry(first,false)
func clear_document() -> void:
    for child in document.get_children(): document.remove_child(child);child.queue_free()
func show_entry(entry: Dictionary,mark:=true) -> void:
    selection=str(entry.id);clear_document()
    document.add_child(ZUI.wrap_label(entry.title,23,V.TEXT,0))
    document.add_child(ZUI.wrap_label(str(entry.get("author","Локальный контур"))+"\n"+str(entry.get("date","")),13,V.ICE,0))
    var body:=ZUI.wrap_label(str(entry.get("body","")),17,V.TEXT,0);body.add_theme_constant_override("line_spacing",5);document.add_child(body)
    if int(entry.category)==4:
        var camera:=preload("res://scripts/ui/v10/camera_archive.gd").new();camera.custom_minimum_size=Vector2(0,190);document.add_child(camera)
    if mark and not selection.begins_with("legacy:"):
        b.investigation10.mark_read(selection);entry["new"]=false;b._save_checkpoint();refresh_categories()
        for button in listing.get_children():
            if button.get_meta("entry10","")==selection: button.text=str(entry.title)
