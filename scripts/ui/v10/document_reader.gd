extends "res://scripts/ui/v10/field_panel.gd"
var entry: Dictionary={}
func _ready() -> void:
    caption="V–17 / СОХРАНЁННЫЙ МАТЕРИАЛ";extent=Vector2(1000,640);super._ready()
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);row.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(row)
    var metadata:=VBoxContainer.new();metadata.custom_minimum_size.x=200;metadata.add_theme_constant_override("separation",16);row.add_child(metadata)
    metadata.add_child(ZUI.wrap_label(str(entry.get("author","Система «Заря»")),15,V.ICE,200))
    metadata.add_child(ZUI.wrap_label(str(entry.get("date","Локальный архив")),13,V.MUTED,200))
    metadata.add_child(ZUI.wrap_label("Копия добавлена в записи КПК. К ней можно вернуться после закрытия.",13,V.MUTED,200))
    var document:=scroll_column(row)
    document.add_child(ZUI.wrap_label(str(entry.get("title","Наблюдение")),25,V.TEXT,0))
    var body:=ZUI.wrap_label(str(entry.get("body","")),18,V.TEXT,0);body.add_theme_constant_override("line_spacing",5);document.add_child(body)
    if int(entry.get("category",-1))==4:
        var camera:=preload("res://scripts/ui/v10/camera_archive.gd").new();camera.custom_minimum_size=Vector2(0,210);document.add_child(camera)
