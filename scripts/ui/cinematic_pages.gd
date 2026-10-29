extends "res://scripts/ui/page_canvas.gd"
const Polar=preload("res://scripts/ui/polar/theme.gd")
const Back=preload("res://scripts/ui/native_back.gd")
# Fullscreen editorial pages over the live scene, with actual saved settings.
const INK := Color(0.88,0.9,0.89)
const MUTED := Color(0.56,0.66,0.71)
const LINE := Color(0.45,0.68,0.76,0.4)
var main = null
var mode := "settings"
var content: VBoxContainer
var subtitle: Label
var sidebar: VBoxContainer
var action_bar: HBoxContainer
var primary_button: Button
var selected := 0
var selected_tab := "ЗВУК"
var settings: Dictionary = {}
var tab_buttons: Array = []
var closing:=false

static func open(main_node, parent_ui: CanvasLayer, page: String) -> Control:
    var source=load("res://scripts/ui/cinematic_pages.gd")
    for child in parent_ui.get_children():
        if child.get_script()==source and not child.is_queued_for_deletion() and not child.closing:return child
    var scr = source.new()
    scr.main = main_node
    scr.mode = page
    parent_ui.add_child(scr)
    return scr

func _ready() -> void:
    Back.install(self,_close)
    super._ready()
    theme=Polar.make_theme()
    mouse_filter = Control.MOUSE_FILTER_STOP
    settings = G.zsave.get("bunker_visual",{"brightness":1.0,"particles":true,"haptics":true})
    var shade := ColorRect.new()
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    var shader := Shader.new()
    shader.code = "shader_type canvas_item; void fragment(){ float a=mix(0.96,0.75,smoothstep(0.15,1.0,UV.x)); COLOR=vec4(0.014,0.022,0.027,a); }"
    var mat := ShaderMaterial.new(); mat.shader = shader; shade.material = mat
    add_child(shade)
    var margin := MarginContainer.new();margin.name="PageMargin"
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for key in ["left","right"]: margin.add_theme_constant_override("margin_"+key,64)
    for key in ["top","bottom"]: margin.add_theme_constant_override("margin_"+key,42)
    add_child(margin)
    var all := VBoxContainer.new();all.add_theme_constant_override("separation",24)
    margin.add_child(all)
    var top := HBoxContainer.new();all.add_child(top)
    var back := _button("← НАЗАД",16)
    back.custom_minimum_size = Vector2(150,45)
    back.pressed.connect(_close)
    top.add_child(back)
    var mark := _label("СЕВЕРНЫЙ АНКЛАВ / АРХИВ ОБЪЕКТА",13,MUTED)
    mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    top.add_child(mark)
    var title := _label("НАСТРОЙКИ" if mode == "settings" else ("ВЫБОР СЛОЖНОСТИ" if mode=="difficulty" else ("УПРАВЛЕНИЕ" if mode=="help" else "ВЫБОР ИСТОРИИ")),42,INK)
    all.add_child(title)
    var divider := ColorRect.new();divider.color = LINE;divider.custom_minimum_size.y = 1
    all.add_child(divider)
    var row := HBoxContainer.new();row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation",60)
    all.add_child(row)
    sidebar = VBoxContainer.new();sidebar.custom_minimum_size.x = 310
    sidebar.add_theme_constant_override("separation",8);row.add_child(sidebar)
    var scroll := ScrollContainer.new();scroll.name="PageScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    row.add_child(scroll)
    content = VBoxContainer.new();content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",18);scroll.add_child(content)
    action_bar = HBoxContainer.new()
    action_bar.alignment = BoxContainer.ALIGNMENT_END
    action_bar.visible = mode in ["campaign","difficulty"]
    all.add_child(action_bar)
    var footer := _label("Изменения сохраняются автоматически." if mode=="settings" else "Две истории одного мира. Выбор кампании не меняет другую историю.",13,MUTED)
    all.add_child(footer)
    if mode == "settings":
        for name in ["ЗВУК","ЭКРАН","УПРАВЛЕНИЕ"]:
            var btn := _button(name,22)
            btn.custom_minimum_size = Vector2(290,62)
            btn.pressed.connect(func(): selected_tab = name; _settings_page())
            sidebar.add_child(btn)
            tab_buttons.append(btn)
        _settings_page()
    elif mode=="help":
        _paragraph("ВОЛКОВ / УПРАВЛЕНИЕ",INK,27)
        _paragraph("Левый стик — ходьба. Двойное касание левого стика — бег. Правый стик — взгляд; с оружием — прицеливание и огонь у края стика.",INK,20)
        _rule()
        _paragraph("Кнопка действия рядом с правым стиком — осмотр, обыск и двери. Кнопка с фонарём включает и выключает свет в руке. Рюкзак — предметы и экипировка. Схема тела — лечение. КПК — найденные записи, журнал — задачи.",MUTED,18)
        if not OS.has_feature("mobile"):_paragraph("ПК: WASD — ходьба · Shift — бег · R — перезарядка · E — действие · F — фонарь",MUTED,17)
    elif mode=="difficulty":
        selected=1
        for i in range(3):
            var btn:=_button("0%d   %s"%[i+1,str(G.ZDIFF_NAMES[i]).to_upper()],22)
            btn.custom_minimum_size=Vector2(310,76)
            var index:=i
            btn.pressed.connect(func(): selected=index;_difficulty_page())
            sidebar.add_child(btn);tab_buttons.append(btn)
        _difficulty_page()
    else:
        for i in range(2):
            var text := "01   ЗЕМЛЯ МЁРТВЫХ" if i == 0 else "02   ВОЕННЫЙ КОНФЛИКТ"
            var btn := _button(text,19)
            btn.custom_minimum_size = Vector2(310,76)
            var index := i
            btn.pressed.connect(func(): selected = index; _campaign_page())
            sidebar.add_child(btn);tab_buttons.append(btn)
        _campaign_page()
    modulate.a = 0
    create_tween().tween_property(self,"modulate:a",1.0,0.3)

func _exit_tree() -> void:Back.remove(self)

func _clear_content() -> void:
    for c in content.get_children(): content.remove_child(c);c.queue_free()
    if action_bar != null:
        for c in action_bar.get_children(): action_bar.remove_child(c);c.queue_free()
func _label(text: String, px: int, col: Color) -> Label:
    var l := Label.new();l.text = text;l.add_theme_font_size_override("font_size",px)
    l.add_theme_color_override("font_color",col)
    return l
func _button(text: String, px := 20) -> Button:
    var b := Button.new();b.text = text;b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.add_theme_font_size_override("font_size",px)
    b.add_theme_color_override("font_color",INK)
    b.add_theme_color_override("font_hover_color",Color(1,1,1))
    var normal := StyleBoxFlat.new();normal.bg_color = Color(0,0,0,0)
    normal.content_margin_left = 14;normal.content_margin_right = 14
    b.add_theme_stylebox_override("normal",normal)
    var hover := normal.duplicate();hover.bg_color = Color(0.65,0.77,0.79,0.08)
    hover.border_width_left = 2;hover.border_color = INK
    b.add_theme_stylebox_override("hover",hover)
    b.add_theme_stylebox_override("focus",hover)
    b.add_theme_stylebox_override("pressed",hover)
    Polar.button(b)
    return b
func _select_sidebar(index: int) -> void:
    for i in range(tab_buttons.size()):
        tab_buttons[i].add_theme_color_override("font_color",INK if i==index else MUTED)
func _paragraph(text: String, col := MUTED, px := 17) -> Label:
    var l := _label(text,px,col)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(l)
    return l
func _rule() -> void:
    var l := ColorRect.new();l.color=LINE;l.custom_minimum_size.y=1;content.add_child(l)

func _settings_page() -> void:
    _clear_content()
    _select_sidebar(["ЗВУК","ЭКРАН","УПРАВЛЕНИЕ"].find(selected_tab))
    content.add_child(_label(selected_tab,27,INK))
    match selected_tab:
        "ЗВУК":
            _paragraph("Тишина комплекса, близкие шаги и короткое эхо выстрелов.")
            _slider("Музыка",G.music_vol,0,1,func(v): G.set_music_vol(v); G.write_save())
            _slider("Звуковые эффекты",G.sfx_vol,0,1,func(v): G.set_sfx_vol(v); G.write_save())
            _paragraph("Для напряжённых сцен рекомендуются наушники.",MUTED,14)
        "ЭКРАН":
            _paragraph("В тёмном углу должны различаться контуры оборудования. Аварийная лампа остаётся яркой.")
            _slider("Яркость бункера",float(settings.get("brightness",1.0)),0.75,1.3,func(v): settings["brightness"]=v; _save_settings())
            _toggle("Пар и частицы",bool(settings.get("particles",true)),func(v): settings["particles"]=v; _save_settings())
            if not OS.has_feature("mobile"):
                _toggle("Полный экран",G.fullscreen,func(v): G.set_fullscreen(v); G.write_save())
        "УПРАВЛЕНИЕ":
            _paragraph("Левый стик — движение. Двойное касание с удержанием — бег до отпускания стика. Правый — взгляд и прицеливание; с оружием отклонение до края — огонь. Двойное касание правого стика — перезарядка. Фонарь переключается отдельной кнопкой.")
            _toggle("Отклик на выстрел",bool(settings.get("haptics",true)),func(v): settings["haptics"]=v; _save_settings())
            _rule()
            _paragraph("Взгляд и корпус Волкова поворачиваются плавно. Шаги, руки и голова анимируются отдельно.",INK,16)
            if not OS.has_feature("mobile"): _paragraph("WASD — движение · мышь — прицел · R — перезарядка · E — действие",MUTED,15)

func _slider(title: String, value: float, low: float, high: float, cb: Callable) -> void:
    var row := HBoxContainer.new();content.add_child(row)
    var l := _label(title,20,INK);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(l)
    var val := _label("%d" % roundi(value*100),18,MUTED);row.add_child(val)
    var sl := HSlider.new();sl.min_value=low;sl.max_value=high;sl.step=0.01;sl.value=value
    sl.custom_minimum_size=Vector2(480,40)
    var track := StyleBoxFlat.new();track.bg_color=Color(0.3,0.36,0.37,0.45)
    track.set_content_margin_all(2);track.set_corner_radius_all(0)
    var area := track.duplicate();area.bg_color=Color(0.79,0.85,0.84)
    sl.add_theme_stylebox_override("slider",track);sl.add_theme_stylebox_override("grabber_area",area)
    sl.add_theme_stylebox_override("grabber_area_highlight",area)
    sl.value_changed.connect(func(v): val.text="%d"%roundi(v*100);cb.call(v))
    content.add_child(sl);_rule()
func _toggle(title: String, state: bool, cb: Callable) -> void:
    var btn := _button(title+"    "+("ВКЛ" if state else "ВЫКЛ"),20)
    btn.custom_minimum_size.y=58
    btn.set_meta("enabled_value",state)
    btn.pressed.connect(func():
        var val: bool = not bool(btn.get_meta("enabled_value"))
        btn.set_meta("enabled_value",val)
        btn.text=title+"    "+("ВКЛ" if val else "ВЫКЛ")
        cb.call(val))
    content.add_child(btn);_rule()
func _save_settings() -> void:
    G.zsave["bunker_visual"] = settings
    get_tree().call_group("bunker_visual_preferences","apply_preferences")
    G.write_save()

func _campaign_page() -> void:
    _clear_content();_select_sidebar(selected)
    var img := TextureRect.new()
    img.texture=load("res://assets/menu/v4/story_zarya.png") if selected==0 and ResourceLoader.exists("res://assets/menu/v4/story_zarya.png") else G.tex("menu_z" if selected==0 else "menu_war")
    img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    img.custom_minimum_size=Vector2(0,180 if get_viewport_rect().size.y<800 else 230)
    img.modulate=Color(0.67,0.75,0.77)
    content.add_child(img)
    if selected == 0:
        content.add_child(_label("ЗЕМЛЯ МЁРТВЫХ",31,INK))
        _paragraph("ЛОКАЦИЯ 01  /  ОБЪЕКТ «ЗАРЯ»",MUTED,13)
        _paragraph("Капсула V-17 открывается после аварии. Найдите записи эксперимента №12 и путь через изолированные отсеки. Почему вернули именно вас — пока неизвестно.",INK,18)
        _rule()
        var has_save: bool = bool(G.zsave.get("seen_prologue",false)) and not main.pending_new_z
        var button := _button("ПРОДОЛЖИТЬ ИСТОРИЮ  →" if has_save else "НАЧАТЬ ИСТОРИЮ  →",24)
        button.custom_minimum_size.y=68
        button.pressed.connect(func(): _close();main.start_z_campaign())
        primary_button = button
        button.custom_minimum_size.x = 540
        action_bar.add_child(button)
        _paragraph("Контрольные точки сохраняют найденные записи, открытые двери и состояние организма.",MUTED,14)
    else:
        content.add_child(_label("ВОЕННЫЙ КОНФЛИКТ САК–ФОА",28,INK))
        _paragraph("АРХИВ ОПЕРАЦИЙ  /  ДОСТУП ОГРАНИЧЕН",MUTED,13)
        _paragraph("Хроника противостояния двух альянсов. Доступ к военной кампании сохранён через терминал допуска.",INK,18)
        _rule()
        _paragraph("ДОСТУП ПОКА ЗАКРЫТ",INK,22)
        _paragraph("Военная кампания находится в разработке. Вы можете вернуться к первой истории через список слева.",MUTED,17)

func _difficulty_page() -> void:
    _clear_content();_select_sidebar(selected)
    _paragraph("ОБЪЕКТ «ЗАРЯ» / ПАРАМЕТРЫ ВЫЖИВАНИЯ",MUTED,13)
    content.add_child(_label(str(G.ZDIFF_NAMES[selected]).to_upper(),38,INK))
    _paragraph(str(G.ZDIFF[selected]["desc"]),INK,22)
    _rule()
    _paragraph("РЕСУРСЫ И УГРОЗА",MUTED,14)
    _paragraph("Боезапас ×%s\nМедикаменты ×%s\nЗаметность ×%s"%[str(G.ZDIFF[selected]["ammo_k"]),str(G.ZDIFF[selected]["med_k"]),str(G.ZDIFF[selected]["notice_k"])],INK,20)
    _paragraph("Внимательно исследуйте помещения. Состояние тела и запас снаряжения сохраняются на контрольных точках.",MUTED,17)
    var begin:=_button("НАЧАТЬ  →",24);begin.custom_minimum_size=Vector2(400,68)
    begin.pressed.connect(func():
        begin.disabled=true
        G.zsave["zdiff"]=selected;G.zsave["zdiff_chosen"]=true;G.write_save()
        main._show_flash_warning())
    action_bar.add_child(begin);primary_button=begin

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        Back.request(get_tree());get_viewport().set_input_as_handled()
func _close() -> void:
    if closing:return
    closing=true
    if mode=="difficulty":
        main.to_main_menu()
        return
    mouse_filter = Control.MOUSE_FILTER_STOP
    for child in find_children("*","Button",true,false): child.disabled=true
    var tw := create_tween();tw.tween_property(self,"modulate:a",0,0.16)
    tw.tween_callback(queue_free)
