extends "res://scripts/ui/v10/field_panel.gd"
var b
var content: VBoxContainer
var active:="Звук"
var buttons: Dictionary={}
func _ready() -> void:
    extent=Vector2(850,570);caption="V–17 / ПАРАМЕТРЫ КОНТУРА";super._ready()
    var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",8);column.add_child(tabs)
    for title in ["Звук","Изображение","Управление","Дополнительно"]:
        var button:=V.button(title);button.size_flags_horizontal=SIZE_EXPAND_FILL;tabs.add_child(button);buttons[title]=button
        button.pressed.connect(func(): select_page(title))
    content=VBoxContainer.new();content.add_theme_constant_override("separation",14);content.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(content)
    select_page(active)
func prefs() -> Dictionary: return G.zsave.get("bunker_visual",{})
func set_pref(key: String,value) -> void:
    var data:=prefs();data[key]=value;G.zsave["bunker_visual"]=data;G.write_save()
func select_page(title: String) -> void:
    active=title
    for child in content.get_children(): content.remove_child(child);child.queue_free()
    for key in buttons: buttons[key].add_theme_color_override("font_color",V.ICE if key==title else V.MUTED)
    match title:
        "Звук":
            slider("Музыка",G.music_vol,0,1,func(value): G.set_music_vol(value),true)
            slider("Эффекты",G.sfx_vol,0,1,func(value): G.set_sfx_vol(value),true)
            content.add_child(ZUI.wrap_label("Уровни применяются сразу и сохраняются для следующего запуска.",14,V.MUTED,0))
        "Изображение":
            slider("Яркость комплекса",float(prefs().get("brightness",1)),.85,1.45,func(value): set_pref("brightness",value),true)
            var row:=HBoxContainer.new();content.add_child(row);row.add_child(ZUI.label("Качество света",16,V.TEXT))
            var options:=OptionButton.new();options.custom_minimum_size=Vector2(260,48)
            for label in ["Автоматически","Экономия","Сбалансированное","Высокое"]: options.add_item(label)
            options.selected=int(prefs().get("quality10",0));row.add_child(options)
            options.item_selected.connect(func(index): set_pref("quality10",index);b.q_lock=index>0;b.q_level=clampi(index-1,0,2) if index>0 else b.q_level)
            toggle("Пар и локальные частицы",bool(prefs().get("particles",true)),func(on): set_pref("particles",on))
            toggle("Полный экран",G.fullscreen,func(on): G.set_fullscreen(on))
        "Управление":
            slider("Масштаб сенсорных элементов",float(prefs().get("control_scale10",1)),.85,1.15,func(value): set_pref("control_scale10",value),true)
            slider("Плавность поворота",float(prefs().get("turn10",1)),.65,1.5,func(value): set_pref("turn10",value),true)
            toggle("Виброотклик",bool(prefs().get("haptics",true)),func(on): set_pref("haptics",on))
            content.add_child(ZUI.wrap_label("Левый стик — движение; двойное нажатие — бег. Правый — взгляд и огонь с оружием; двойное нажатие — перезарядка. Без оружия прицел скрыт.",14,V.MUTED,0))
        "Дополнительно":
            toggle("Показывать частоту кадров",bool(prefs().get("fps10",false)),func(on): set_pref("fps10",on))
            toggle("Сдержанные эффекты интерфейса",bool(prefs().get("reduced_motion10",false)),func(on): set_pref("reduced_motion10",on))
            content.add_child(ZUI.wrap_label("Материалы КПК, положение экипировки и настройки сохраняются вместе с прогрессом. Возврат к контрольной точке находится в меню «Замерший сигнал».",14,V.MUTED,0))
func slider(title: String,value: float,minimum: float,maximum: float,callback: Callable,percent: bool) -> void:
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);content.add_child(row)
    var label:=ZUI.label(title,15,V.TEXT);label.custom_minimum_size.x=285;row.add_child(label)
    var control:=HSlider.new();control.min_value=minimum;control.max_value=maximum;control.step=.01;control.value=value;control.custom_minimum_size=Vector2(210,48);control.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(control)
    var amount:=ZUI.label(str(roundi(value*100))+"%" if percent else str(value),14,V.ICE);amount.custom_minimum_size.x=60;row.add_child(amount)
    control.value_changed.connect(func(next): amount.text=str(roundi(next*100))+"%" if percent else str(next);callback.call(next))
func toggle(title: String,enabled: bool,callback: Callable) -> void:
    var button:=CheckButton.new();button.text=title;button.button_pressed=enabled;button.custom_minimum_size.y=44;button.add_theme_font_size_override("font_size",15);button.toggled.connect(callback);content.add_child(button)
