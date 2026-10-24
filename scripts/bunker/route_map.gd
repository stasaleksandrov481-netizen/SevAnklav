extends Control
const V=preload("res://scripts/ui/visual_theme.gd")
var btl
var timer:=0.0
func _process(delta: float) -> void:
    timer+=delta
    if timer>.2: timer=0;queue_redraw()
func _draw() -> void:
    draw_style_box(V.panel(Color(.025,.042,.055,.67),Color.TRANSPARENT,8),Rect2(Vector2.ZERO,size))
    draw_string(ThemeDB.fallback_font,Vector2(12,18),"ИНЕРЦИАЛЬНЫЙ СЛЕД",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,9,V.MUTED)
    if btl==null or btl.awareness5==null: return
    var here: Vector2=btl.player.spr.position;var center:=size*.5+Vector2(0,7);var last:=Vector2.INF
    var clip:=Rect2(Vector2(12,28),size-Vector2(24,48))
    for p in btl.awareness5.explored:
        var q: Vector2=center+(p-here)*.10
        if not clip.has_point(q): last=Vector2.INF;continue
        if last!=Vector2.INF: draw_line(last,q,Color(.40,.61,.68,.65),1.5,true)
        last=q
    var f:=Vector2.from_angle(btl.player.aim);var s:=f.orthogonal()
    draw_colored_polygon(PackedVector2Array([center+f*5,center-f*3+s*3,center-f*3-s*3]),V.TEXT)
    draw_string(ThemeDB.fallback_font,Vector2(12,size.y-9),"ПЛАН НЕ ЗАГРУЖЕН",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,8,V.MUTED)
