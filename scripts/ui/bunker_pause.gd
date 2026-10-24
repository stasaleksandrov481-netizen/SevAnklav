extends "res://scripts/ui/viewport_control.gd"
const V=preload("res://scripts/ui/visual_theme.gd")
var b
func _ready() -> void:
    super._ready()
    mouse_filter=MOUSE_FILTER_STOP
    var shade:=ColorRect.new();shade.color=Color(0.003,0.009,0.015,0.93);shade.set_anchors_preset(PRESET_FULL_RECT);add_child(shade)
    var margin:=MarginContainer.new();margin.set_anchors_preset(PRESET_FULL_RECT)
    for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,36)
    add_child(margin)
    var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll)
    var root:=VBoxContainer.new();root.size_flags_horizontal=SIZE_EXPAND_FILL;root.add_theme_constant_override("separation",18);scroll.add_child(root)
    root.add_child(ZUI.label("СЕВЕРНЫЙ АНКЛАВ  /  ОБЪЕКТ ЗАРЯ",13,ZUI.ICE))
    root.add_child(ZUI.label("ПАУЗА",40,ZUI.TEXT))
    root.add_child(ZUI.label("Контрольная точка сохранена",14,ZUI.MUTED))
    _button(root,"ПРОДОЛЖИТЬ",func(): queue_free())
    var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",V.panel(Color(0.024,0.043,0.055),Color(0.18,0.32,0.39),18));root.add_child(card)
    var options:=VBoxContainer.new();options.add_theme_constant_override("separation",12);card.add_child(options)
    options.add_child(ZUI.label("ЗВУК И ИЗОБРАЖЕНИЕ",16,ZUI.ICE))
    _slider(options,"Музыка",G.music_vol,0,1,func(v): G.set_music_vol(v))
    _slider(options,"Звуки",G.sfx_vol,0,1,func(v): G.set_sfx_vol(v))
    var prefs: Dictionary=G.zsave.get("bunker_visual",{})
    _slider(options,"Яркость",float(prefs.get("brightness",1.0)),0.75,1.3,func(v):
        var visual: Dictionary=G.zsave.get("bunker_visual",{});visual["brightness"]=v;G.zsave["bunker_visual"]=visual)
    var full:=CheckButton.new();full.text="Полный экран";full.button_pressed=G.fullscreen;full.toggled.connect(func(on): G.set_fullscreen(on));options.add_child(full)
    var controls:=PanelContainer.new();controls.add_theme_stylebox_override("panel",V.panel(Color(0.018,0.032,0.041),Color(0.14,0.25,0.30),18));root.add_child(controls)
    var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",32);grid.add_theme_constant_override("v_separation",9);controls.add_child(grid)
    for entry in [["WASD / ЛЕВЫЙ СТИК","Движение"],["МЫШЬ / ПРАВЫЙ СТИК","Прицеливание"],["E / ДЕЙСТВИЕ","Взаимодействие"],["R","Перезарядка"],["F","Фонарь"],["ESC","Продолжить"]]:
        grid.add_child(ZUI.label(entry[0],12,ZUI.ICE));grid.add_child(ZUI.label(entry[1],14,ZUI.TEXT))
    _button(root,"СОХРАНИТЬ И ВЫЙТИ В МЕНЮ",func(): b._save_checkpoint();b.main_ref.to_main_menu())
    modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,0.18)
func _button(root: VBoxContainer,text: String,callback: Callable) -> void:
    var button:=Button.new();button.text=text;button.custom_minimum_size.y=54
    button.add_theme_stylebox_override("normal",V.panel(Color(0.04,0.08,0.10),Color(0.28,0.47,0.52),14))
    button.add_theme_stylebox_override("hover",V.panel(Color(0.08,0.15,0.18),Color(0.52,0.72,0.73),14));button.pressed.connect(callback);root.add_child(button)
func _slider(root: VBoxContainer,title: String,value: float,lo: float,hi: float,callback: Callable) -> void:
    var label:=ZUI.label(title+"  %d%%"%roundi(value*100),14,ZUI.MUTED);root.add_child(label)
    var slider:=HSlider.new();slider.min_value=lo;slider.max_value=hi;slider.step=0.01;slider.value=value;slider.custom_minimum_size.y=26;root.add_child(slider)
    slider.value_changed.connect(func(v): label.text=title+"  %d%%"%roundi(v*100);callback.call(v))
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        get_viewport().set_input_as_handled();queue_free()
