extends "res://scripts/ui/viewport_control.gd"
const BACKGROUND=preload("res://assets/ui/v7/loading.png")
var message:=""
var entering:=false
var elapsed:=0.0
var phrase: Label
var strip: Control
var phrases: Array=[]
func _ready() -> void:
    super._ready()
    mouse_filter=Control.MOUSE_FILTER_STOP
    var image:=TextureRect.new();image.texture=BACKGROUND;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(image)
    var shade:=ColorRect.new();shade.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(shade)
    var shader:=Shader.new();shader.code="shader_type canvas_item;void fragment(){float a=(1.0-smoothstep(0.1,0.85,UV.x))*0.34+smoothstep(0.35,1.0,UV.y)*0.65;COLOR=vec4(0.003,0.008,0.014,clamp(a,0.12,0.88));}"
    var mat:=ShaderMaterial.new();mat.shader=shader;shade.material=mat
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",64);margin.add_theme_constant_override("margin_right",64)
    margin.add_theme_constant_override("margin_top",44);margin.add_theme_constant_override("margin_bottom",44);add_child(margin)
    var root:=VBoxContainer.new();root.add_theme_constant_override("separation",14);margin.add_child(root)
    root.add_child(ZUI.label("ОБЪЕКТ «ЗАРЯ» / СЕВЕРНЫЙ ПЕРИМЕТР",13,Color(0.54,0.67,0.72)))
    var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;root.add_child(spacer)
    root.add_child(ZUI.label("СЕВЕРНЫЙ АНКЛАВ",38,Color(0.82,0.88,0.89)))
    root.add_child(ZUI.label("ВОЗВРАЩЕНИЕ В КОМПЛЕКС" if entering else "ИНИЦИАЛИЗАЦИЯ",15,Color(0.43,0.61,0.69)))
    phrase=ZUI.label("",18,Color(0.68,0.77,0.81));phrase.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;root.add_child(phrase)
    strip=Control.new();strip.custom_minimum_size=Vector2(0,14);root.add_child(strip)
    phrases=["Фонарь можно убрать в рюкзак.","Перетащите бинт на повреждённую часть тела.","Для тяжёлого оружия нужны обе руки."] if entering else ["Каждая гермодверь отделяет один отсек от другого.","Быстрый слот позволяет выбрать предмет без открытия рюкзака.","Предметы можно держать в левой и правой руке."]
    modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,0.35)
func _process(delta: float) -> void:
    elapsed+=delta
    if phrase==null or phrases.is_empty(): return
    phrase.text=phrases[int(elapsed/1.05)%phrases.size()]
    phrase.modulate.a=0.6+0.4*smoothstep(0,0.2,fposmod(elapsed,1.05))
    queue_redraw()
func _draw() -> void:
    if strip==null: return
    var width:=minf(500,strip.size.x)
    var start:=strip.global_position
    draw_line(start+Vector2(0,7),start+Vector2(width,7),Color(0.35,0.49,0.55,0.22),1)
    var x:=fposmod(elapsed*135,width+90)-90
    draw_line(start+Vector2(maxf(0,x),7),start+Vector2(minf(width,x+90),7),Color(0.64,0.79,0.83,0.82),2,true)
func fade_out() -> void:
    var tw:=create_tween();tw.tween_property(self,"modulate:a",0.0,0.25)
    await tw.finished
