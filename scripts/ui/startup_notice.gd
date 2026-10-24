extends "res://scripts/ui/viewport_control.gd"
var main
func _ready() -> void:
    super._ready()
    var bg:=ColorRect.new();bg.color=Color(0.005,0.01,0.015);bg.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(bg)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,90)
    for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,55)
    add_child(margin)
    var box:=VBoxContainer.new();box.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_theme_constant_override("separation",24);margin.add_child(box)
    box.add_child(ZUI.label("ПЕРЕД НАЧАЛОМ",14,Color(0.40,0.58,0.66)))
    box.add_child(ZUI.label("ОБЪЕКТ «ЗАРЯ»",38,Color(0.82,0.87,0.88)))
    box.add_child(ZUI.wrap_label("В игре есть мигающее аварийное освещение и вспышки выстрелов. При повышенной чувствительности к вспышкам не начинайте игру.",20,Color(0.62,0.72,0.76),1000))
    var button:=Button.new();button.text="ПРОДОЛЖИТЬ  →";button.custom_minimum_size=Vector2(0,66);button.add_theme_font_size_override("font_size",22)
    button.add_theme_stylebox_override("normal",ZUI.panel_style(Color(0.025,0.055,0.07),Color(0.27,0.43,0.50),16))
    button.pressed.connect(func(): button.disabled=true;main._flash_warning_done());box.add_child(button)
    modulate.a=0;create_tween().tween_property(self,"modulate:a",1,0.3)
