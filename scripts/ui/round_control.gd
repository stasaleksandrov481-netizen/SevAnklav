extends Button
const BEZEL=preload("res://assets/ui/v7/control_bezel.png")
var symbol:="hand"
var caption:=""
var large:=false
var warmth:=0.0
func _ready() -> void:
    focus_mode=Control.FOCUS_NONE
    text=""
    var empty:=StyleBoxEmpty.new()
    for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,empty)
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(delta: float) -> void:
    var target:=0.0 if disabled else (1.0 if is_pressed() or is_hovered() else 0.35)
    warmth=move_toward(warmth,target,delta*5)
    queue_redraw()
func _control_center7() -> Vector2: return Vector2(size.x*0.5,53 if large else 33)
func _control_radius7() -> float: return 47.0 if large else 29.0
func _draw() -> void:
    var c:=_control_center7();var r:=_control_radius7()
    var tint:=Color(0.73+warmth*0.22,0.82+warmth*0.15,0.86+warmth*0.12,0.35 if disabled else 0.94)
    draw_texture_rect(BEZEL,Rect2(c-Vector2.ONE*r*1.15,Vector2.ONE*r*2.30),false,tint)
    var tex:=ZUI.icon(symbol)
    if tex!=null:
        var width:=32.0 if large else 23.0
        draw_texture_rect(tex,Rect2(c-Vector2.ONE*width*0.5,Vector2.ONE*width),false,Color(0.64,0.77,0.81,0.28 if disabled else 0.7+warmth*0.3))
    if is_pressed() and not disabled: draw_arc(c,r-3,-PI*0.75,PI*0.25,32,Color(0.54,0.73,0.79,0.55),1.2,true)
    var lines:=caption.split("\n")
    var y:=c.y+r+18
    for line in lines:
        draw_string(ThemeDB.fallback_font,Vector2(0,y),line,HORIZONTAL_ALIGNMENT_CENTER,size.x,12 if large else 10,Color(0.63,0.73,0.77,0.32 if disabled else 0.92))
        y+=16 if large else 13

func _has_point(point: Vector2) -> bool:
    return point.distance_squared_to(_control_center7())<=pow(_control_radius7()+7,2)
