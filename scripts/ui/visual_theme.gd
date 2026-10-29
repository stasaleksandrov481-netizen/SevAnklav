extends RefCounted
# One restrained equipment language for location one's UI.
const INK=Color(0.027,0.041,0.054,0.96)
const PANEL=Color(0.075,0.10,0.125,0.96)
const EDGE=Color(0.31,0.44,0.50,0.34)
const TEXT=Color(0.88,0.93,0.95)
const MUTED=Color(0.59,0.70,0.76)
const ICE=Color(0.56,0.77,0.84)
const ALERT=Color(0.89,0.35,0.30)
const WARN=Color(0.77,0.60,0.36)
static func panel(fill: Color=PANEL,outline: Color=EDGE,padding: int=12) -> StyleBoxFlat:
    var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=outline
    s.set_border_width_all(1);s.set_corner_radius_all(5)
    s.content_margin_left=padding;s.content_margin_right=padding;s.content_margin_top=padding;s.content_margin_bottom=padding
    return s
static func button(label: String) -> Button:
    var b:=Button.new();b.text=label;b.custom_minimum_size.y=42;b.focus_mode=Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size",14);b.add_theme_color_override("font_color",TEXT)
    b.add_theme_stylebox_override("normal",panel(Color(0.10,0.14,0.17,0.94),Color.TRANSPARENT,10))
    for state in ["hover","pressed","focus"]: b.add_theme_stylebox_override(state,panel(Color(0.17,0.23,0.27),EDGE,10))
    preload("res://scripts/ui/polar/theme.gd").button(b)
    return b
