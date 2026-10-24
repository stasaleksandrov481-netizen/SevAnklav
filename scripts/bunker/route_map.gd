extends Control
var btl
var timer := 0.0
func _process(delta: float) -> void:
    timer+=delta
    if timer>0.25: timer=0;queue_redraw()
func _draw() -> void:
    draw_style_box(ZUI.panel_style(Color(0.025,0.04,0.05,0.86),Color(0.20,0.29,0.33),12),Rect2(Vector2.ZERO,size))
    draw_string(ThemeDB.fallback_font,Vector2(12,20),"ИНЕРЦИАЛЬНЫЙ МАРШРУТ",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.62,0.72,0.75))
    if btl==null or btl.awareness5==null: return
    var here: Vector2=btl.player["spr"].position
    var center:=size*0.5+Vector2(0,12)
    var last := Vector2.INF
    for p in btl.awareness5.explored:
        var q: Vector2=center+(p-here)*0.12
        if not Rect2(Vector2(12,30),size-Vector2(24,42)).has_point(q): last=Vector2.INF;continue
        if last!=Vector2.INF: draw_line(last,q,Color(0.34,0.53,0.58,0.7),2,true)
        last=q
    draw_circle(center,3,Color(0.8,0.9,0.9))
    draw_line(center,center+Vector2.from_angle(btl.player["aim"])*11,Color(0.8,0.9,0.9),2,true)
    draw_string(ThemeDB.fallback_font,Vector2(12,size.y-9),"ПЛАН ОБЪЕКТА НЕДОСТУПЕН",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.40,0.51,0.56))
