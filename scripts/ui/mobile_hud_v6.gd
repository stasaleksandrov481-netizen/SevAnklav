extends Control
const V=preload("res://scripts/ui/visual_theme.gd")
var b
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
    if b==null or b.in_capsule or b.paused: return
    for side in ["l","r"]:
        var center: Vector2=b._stick_base(side)
        var v: Vector2=b.direct_vec if side=="l" else (Vector2.from_angle(b.manual_ang)*(0.95 if b.manual_fire else 0.65) if b.manual_aim else Vector2.ZERO)
        var active: bool=b._stick_move_idx>=0 if side=="l" else b.manual_aim
        var opacity:=0.50 if active else 0.23
        draw_circle(center,86,Color(0.015,0.03,0.04,0.10))
        draw_arc(center,86,0,TAU,56,Color(0.62,0.76,0.82,opacity),1,true)
        for i in range(4):
            var n:=Vector2.from_angle(i*PI/2);draw_line(center+n*80,center+n*86,Color(0.6,0.76,0.8,opacity),1,true)
        var knob: Vector2=center+v.limit_length(1)*60
        draw_circle(knob,27,Color(0.11,0.18,0.22,0.36 if active else 0.2))
        draw_arc(knob,27,0,TAU,32,Color(0.65,0.79,0.84,opacity),1,true)
        draw_circle(knob,2,Color(0.68,0.8,0.84,opacity))
        if side=="l":
            draw_arc(center,92,PI*0.20,PI*0.80,28,Color(0.12,0.2,0.24,0.4),2,true)
            draw_arc(center,92,PI*0.20,PI*(0.20+0.60*clampf(b.stamina/100.0,0,1)),28,Color(0.48,0.68,0.75,0.5),2,true)
        var caption: String="ХОД" if side=="l" else ("ОГОНЬ" if b._has_weapon7() else "ВЗГЛЯД")
        draw_string(ThemeDB.fallback_font,center+Vector2(-40,116),caption,HORIZONTAL_ALIGNMENT_CENTER,80,10,V.MUTED)
    _ammunition()
func _ammunition() -> void:
    var checking: bool=b.ammo_check9>0
    if not checking and b.ammo_result9<=0: return
    var vp:=get_viewport_rect().size;var origin:=Vector2(vp.x*0.5-160,vp.y-172)
    var alpha:=minf(1,b.ammo_result9*3) if not checking else 1.0
    var style:=V.panel(Color(0.025,0.042,0.055,0.92*alpha),Color(0.3,0.46,0.53,0.2*alpha),8)
    draw_style_box(style,Rect2(origin,Vector2(320,67)))
    var tex: Texture2D=b.loadout7.icon_of("weapon:"+b.ammo_weapon9)
    if tex!=null:
        var k:=minf(65/tex.get_width(),39/tex.get_height())
        draw_texture_rect(tex,Rect2(origin+Vector2(10,10+sin((1-b.ammo_check9)*PI)*3),tex.get_size()*k),false,Color(0.8,0.88,0.91,alpha))
    draw_string(ThemeDB.fallback_font,origin+Vector2(88,21),"ОСМОТР МАГАЗИНА" if checking else "МАГАЗИН / НА ГЛАЗ",HORIZONTAL_ALIGNMENT_LEFT,224,10,Color(0.47,0.65,0.72,alpha))
    draw_string(ThemeDB.fallback_font,origin+Vector2(88,43),"Проверяю…" if checking else b.ammo_text9,HORIZONTAL_ALIGNMENT_LEFT,224,16,Color(0.84,0.9,0.93,alpha))
    if checking: draw_line(origin+Vector2(10,59),origin+Vector2(10+300*(1-b.ammo_check9),59),V.ICE,1.5,true)
    elif b.ammo_reserve9>=0: draw_string(ThemeDB.fallback_font,origin+Vector2(88,59),"В запасе: %d"%b.ammo_reserve9,HORIZONTAL_ALIGNMENT_LEFT,224,10,Color(0.47,0.65,0.72,alpha))
