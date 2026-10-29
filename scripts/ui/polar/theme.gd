extends RefCounted
const TEXT=Color("#e1ebee")
const MUTED=Color("#819ca7")
const ICE=Color("#89cdd9")
const GOLD=Color("#d8b57a")
static func surface(padding:=14,accent:=false) -> StyleBoxFlat:
 var s=StyleBoxFlat.new()
 s.bg_color=Color("#101d26")
 s.border_color=Color("#38505d")
 s.set_border_width_all(1)
 s.border_width_top=2
 s.border_width_left=3 if accent else 1
 if accent:s.border_color=ICE
 s.set_corner_radius_all(5)
 s.set_content_margin_all(padding)
 s.shadow_color=Color(0,0,0,0.4)
 s.shadow_size=12
 s.shadow_offset=Vector2(0,5)
 return s
static func button(b:Button,primary:=false) -> void:
 var n=surface(12,primary)
 n.bg_color=Color("#18303b") if primary else Color("#13232d")
 n.border_color=Color("#76a7b9") if primary else Color("#3e5968")
 b.add_theme_stylebox_override("normal",n)
 var h=n.duplicate();h.bg_color=Color("#254452");h.border_color=ICE
 b.add_theme_stylebox_override("hover",h)
 var f=h.duplicate();f.set_border_width_all(2);b.add_theme_stylebox_override("focus",f)
 var pressed=n.duplicate();pressed.bg_color=Color("#0b1820");pressed.border_color=GOLD
 b.add_theme_stylebox_override("pressed",pressed)
 var disabled=n.duplicate();disabled.bg_color=Color("#10191f");disabled.border_color=Color("#263943")
 b.add_theme_stylebox_override("disabled",disabled)
 b.add_theme_color_override("font_color",TEXT)
 b.add_theme_color_override("font_hover_color",Color.WHITE)
 b.add_theme_color_override("font_focus_color",Color.WHITE)
 b.add_theme_color_override("font_disabled_color",MUTED)
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
static func make_theme()->Theme:
 var t=Theme.new();t.default_font_size=16
 t.set_color("font_color","Label",TEXT)
 t.set_color("font_color","CheckButton",TEXT)
 t.set_stylebox("panel","PanelContainer",surface())
 for kind in ["HSlider","VSlider"]:
  var line=surface(0);line.bg_color=Color("#203642");line.set_corner_radius_all(2);line.set_border_width_all(0)
  t.set_stylebox("slider",kind,line)
  var fill=line.duplicate();fill.bg_color=ICE;t.set_stylebox("grabber_area",kind,fill);t.set_stylebox("grabber_area_highlight",kind,fill)
 var sep=StyleBoxLine.new();sep.color=Color("#3a515d");sep.thickness=1;t.set_stylebox("separator","HSeparator",sep)
 return t
