class_name MainMenuScreen
extends CanvasLayer
signal play_pressed
signal mil_pressed
signal settings_pressed
signal help_pressed
signal quit_pressed
signal continue_pressed
signal load_pressed
var menu_root: Control
var menu_canvas: Control

func _ready() -> void:
    for c in get_children():
        if c is CanvasItem: c.hide()
        c.queue_free()
    menu_root=Control.new()
    menu_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
    add_child(menu_root)
    menu_canvas=Control.new()
    menu_canvas.size=Vector2(1536,864)
    menu_root.add_child(menu_canvas)
    var canvas:=menu_canvas
    _fit_menu()
    get_viewport().size_changed.connect(_fit_menu)
    var bg := TextureRect.new()
    bg.texture = preload("res://assets/menu/north.jpg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://assets/menu/north.gdshader")
    mat.set_shader_parameter("clean_sky",preload("res://assets/menu/v4/sky_clean.png"))
    bg.material = mat
    canvas.add_child(bg)
    var callbacks := [func(): continue_pressed.emit(), func(): play_pressed.emit(), func(): load_pressed.emit(), func(): settings_pressed.emit(), func(): quit_pressed.emit()]
    var labels := ["Продолжить", "Новая игра", "Загрузить игру", "Настройки", "Выход"]
    for i in range(5):
        var b := Button.new()
        b.tooltip_text = labels[i]
        b.accessibility_name = labels[i]
        b.anchor_left = 0.399
        b.anchor_right = 0.603
        b.anchor_top = (363.0 + i * 65.0) / 864.0
        b.anchor_bottom = (412.0 + i * 65.0) / 864.0
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        var clear := StyleBoxFlat.new()
        clear.bg_color = Color(0,0,0,0)
        b.add_theme_stylebox_override("normal", clear)
        var hover := StyleBoxFlat.new()
        hover.bg_color = Color(0.5,0.8,0.9,0.08)
        hover.border_color = Color(0.65,0.85,0.94,0.7)
        hover.set_border_width_all(1)
        hover.set_corner_radius_all(5)
        b.add_theme_stylebox_override("hover", hover)
        b.add_theme_stylebox_override("focus", hover)
        b.add_theme_stylebox_override("pressed", hover)
        b.pressed.connect(callbacks[i])
        canvas.add_child(b)
    var atmosphere := Control.new()
    atmosphere.name = "MenuAtmosphere"
    atmosphere.set_script(preload("res://scripts/ui/menu_atmosphere.gd"))
    atmosphere.set_anchors_preset(Control.PRESET_FULL_RECT)
    canvas.add_child(atmosphere)
    var snow := Snow.new()
    snow.set_anchors_preset(Control.PRESET_FULL_RECT)
    snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(snow)

func _fit_menu() -> void:
    if menu_root==null or menu_canvas==null: return
    var vp:=get_viewport().get_visible_rect().size
    menu_root.size=vp
    var k:=maxf((vp.x+2)/1536.0,(vp.y+2)/864.0)
    menu_canvas.scale=Vector2(k,k)
    menu_canvas.position=(vp-Vector2(1536,864)*k)*0.5

class Snow extends Control:
    var t := 0.0
    var flakes: Array = []
    func _ready() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = 742
        for i in range(115):
            flakes.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.2,1.0), rng.randf_range(0.0,TAU)))
    func _process(delta: float) -> void:
        t += delta
        queue_redraw()
    func _draw() -> void:
        for f in flakes:
            var x := fposmod(f.x + t * (0.012 + f.z * 0.022) + sin(t * 0.3 + f.w) * 0.008, 1.0) * size.x
            var y := fposmod(f.y + t * (0.018 + f.z * 0.035), 1.0) * size.y
            draw_line(Vector2(x,y),Vector2(x+f.z*2.0,y+f.z*4.0),Color(0.83,0.92,1.0,0.10+f.z*0.25),0.5+f.z)
