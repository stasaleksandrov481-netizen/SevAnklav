extends RefCounted
const FONT=preload("res://assets/ui/bunker/RobotoCondensed.ttf")
const TEXT=Color("#d2e0e3")
const MUTED=Color("#78939f")
const ICE=Color("#83bec5")
const GOLD=Color("#cbb688")
static func surface(padding:=14,accent:=false) -> StyleBoxFlat:
 var s=StyleBoxFlat.new()
 s.bg_color=Color(.021,.044,.055,.96);s.border_color=Color("#375967")
 s.set_border_width_all(1);s.set_corner_radius_all(6);s.set_content_margin_all(padding)
 if accent:s.border_color=ICE
 s.shadow_color=Color(0,0,0,.48);s.shadow_size=8;s.shadow_offset=Vector2(0,3)
 return s
static func button(b:Button,primary:=false) -> void:
 var n=surface(10,primary);n.bg_color=Color("#102129") if primary else Color("#09151c")
 b.add_theme_stylebox_override("normal",n)
 var h=n.duplicate();h.bg_color=Color("#19353b");h.border_color=ICE;b.add_theme_stylebox_override("hover",h)
 var p=n.duplicate();p.bg_color=Color("#29474a");p.border_color=Color("#c1e7e4");b.add_theme_stylebox_override("pressed",p)
 var f=n.duplicate();f.bg_color=Color.TRANSPARENT;f.border_color=ICE;f.set_border_width_all(2);b.add_theme_stylebox_override("focus",f)
 var d=n.duplicate();d.bg_color=Color("#080f14");d.border_color=Color("#253640");b.add_theme_stylebox_override("disabled",d)
 b.add_theme_color_override("font_color",TEXT);b.add_theme_color_override("font_hover_color",Color.WHITE)
 b.add_theme_color_override("font_disabled_color",Color("#657880"));b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
static func make_theme()->Theme:
 var t=preload("res://scripts/ui/polar/theme.gd").make_theme()
 t.default_font=FONT;t.default_font_size=19
 t.set_color("font_color","Label",TEXT);t.set_color("default_color","RichTextLabel",TEXT)
 t.set_stylebox("panel","PanelContainer",surface())
 t.set_stylebox("normal","LineEdit",surface(10));t.set_stylebox("focus","LineEdit",surface(10,true))
 t.set_color("font_color","LineEdit",TEXT);t.set_color("font_placeholder_color","LineEdit",MUTED)
 return t

static func paper_button(b:Button)->void:
 var n=surface(10);n.bg_color=Color("#b8af96");n.border_color=Color("#8b7b60");n.shadow_size=0
 b.add_theme_stylebox_override("normal",n)
 var h=n.duplicate();h.bg_color=Color("#dfd6bf");b.add_theme_stylebox_override("hover",h)
 var p=n.duplicate();p.bg_color=Color("#a59c81");b.add_theme_stylebox_override("pressed",p)
 b.add_theme_color_override("font_color",Color("#35372e"));b.add_theme_color_override("font_hover_color",Color("#22281e"));b.add_theme_color_override("icon_normal_color",Color("#34382f"))
