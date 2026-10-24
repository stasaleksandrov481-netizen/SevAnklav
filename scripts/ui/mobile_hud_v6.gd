extends Control
var b
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
    if b==null or b.in_capsule: return
    for side in ["l","r"]:
        var center: Vector2=b._stick_base(side)
        var v: Vector2=b.direct_vec if side=="l" else (Vector2.from_angle(b.manual_ang)*(0.95 if b.manual_fire else 0.65) if b.manual_aim else Vector2.ZERO)
        var cold:=Color(0.49,0.66,0.73,0.32)
        draw_circle(center,110,Color(0.006,0.018,0.027,0.22))
        draw_arc(center,110,0,TAU,56,cold,1.4,true)
        draw_arc(center,99,0,TAU,56,Color(0.34,0.49,0.56,0.10),1,true)
        var knob: Vector2=center+v.limit_length(1)*b.STICK_KNOB
        draw_circle(knob,38,Color(0.09,0.17,0.21,0.46))
        draw_arc(knob,38,0,TAU,40,Color(0.63,0.77,0.81,0.48),1.6,true)
        draw_circle(knob,4,Color(0.68,0.8,0.84,0.28))
        if side=="l":
            var fraction:=clampf(b.stamina/100.0,0,1)
            draw_arc(center,117,-PI/2,-PI/2+TAU*fraction,48,Color(0.46,0.72,0.77,0.45),2,true)
        var caption: String="ХОД" if side=="l" else ("ПРИЦЕЛ" if b._has_weapon7() else "ВЗГЛЯД")
        draw_string(ThemeDB.fallback_font,center+Vector2(-48,143),caption,HORIZONTAL_ALIGNMENT_CENTER,96,14,Color(0.53,0.67,0.72,0.65))
