extends Button
# Thin, open touch targets; no raster bezel and no keyboard-like button blocks.
const V=preload("res://scripts/ui/visual_theme.gd")
var symbol:="hand"
var caption:=""
var large:=false
var warmth:=0.0
func _ready() -> void:
    focus_mode=Control.FOCUS_NONE;text=""
    for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(delta: float) -> void:
    var target:=0.0 if disabled else (1.0 if is_pressed() or is_hovered() else 0.25)
    var previous:=warmth;warmth=move_toward(warmth,target,delta*5)
    if previous!=warmth: queue_redraw()
func _control_center7() -> Vector2: return Vector2(size.x*0.5,37 if large else 25)
func _control_radius7() -> float: return 31.0 if large else 23.0
func _draw() -> void:
    var c:=_control_center7();var r:=_control_radius7()
    var alpha:=0.24 if disabled else 0.82
    draw_circle(c,r,Color(0.025,0.045,0.06,0.30+warmth*0.12))
    draw_arc(c,r,-PI*0.76,PI*0.76,32,Color(0.56,0.73,0.80,alpha*(0.23+warmth*0.4)),1,true)
    var tex:=ZUI.icon(symbol)
    if tex!=null:
        var width:=25.0 if large else 21.0
        draw_texture_rect(tex,Rect2(c-Vector2.ONE*width*0.5,Vector2.ONE*width),false,Color(0.75,0.85,0.89,alpha))
    if button_pressed and toggle_mode: draw_circle(c+Vector2(r-3,-r+6),2.5,V.ICE)
    var lines:=caption.split("\n");var y:=c.y+r+15
    for line in lines:
        draw_string(ThemeDB.fallback_font,Vector2(0,y),line,HORIZONTAL_ALIGNMENT_CENTER,size.x,10,Color(0.66,0.76,0.81,alpha));y+=13
func _has_point(point: Vector2) -> bool:
    return point.distance_squared_to(_control_center7())<=pow(_control_radius7()+10,2)
