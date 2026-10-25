extends Control
const V=preload("res://scripts/ui/visual_theme.gd")
var btl
var timer:=0.0
var panel_style: StyleBoxFlat
func _ready() -> void:
    mouse_filter=MOUSE_FILTER_IGNORE
    panel_style=V.panel(Color(.045,.075,.095,.86),Color(.39,.54,.6,.25),8)
func _process(delta: float) -> void:
    if btl!=null and btl.paused: return
    timer+=delta
    if timer>.2: timer=0;queue_redraw()
func _draw() -> void:
    if panel_style!=null: draw_style_box(panel_style,Rect2(Vector2.ZERO,size))
    draw_string(ThemeDB.fallback_font,Vector2(12,18),"ИНЕРЦИАЛЬНЫЙ СЛЕД",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,10,V.ICE)
    if btl==null or btl.awareness5==null: return
    var state: Dictionary=btl.investigation10.state
    var here: Vector2=btl.player.spr.position;var center:=size*.5+Vector2(0,7);var last:=Vector2.INF
    var clip:=Rect2(Vector2(12,28),size-Vector2(24,48));var scale10:=.10
    if state.get("map_ready",false):
        var floors: Array=btl.Layout4.FLOOR
        for index in state.known_rooms:
            if int(index)<0 or int(index)>=floors.size(): continue
            var world: Rect2=floors[int(index)][0]
            var rect:=Rect2(center+(world.position-here)*scale10,world.size*scale10)
            if not rect.intersects(clip): continue
            var visible_rect:=rect.intersection(clip)
            draw_rect(visible_rect,Color(.14,.24,.28,.25));draw_rect(visible_rect,Color(.37,.54,.61,.35),false,1)
    for p in btl.awareness5.explored:
        var q: Vector2=center+(p-here)*scale10
        if not clip.has_point(q): last=Vector2.INF;continue
        if last!=Vector2.INF: draw_line(last,q,Color(.53,.76,.82,.85),1.5,true)
        last=q
    var f:=Vector2.from_angle(btl.player.aim);var side:=f.orthogonal()
    draw_colored_polygon(PackedVector2Array([center+f*5,center-f*3+side*3,center-f*3-side*3]),V.TEXT)
    draw_string(ThemeDB.fallback_font,Vector2(12,size.y-9),"ТОЛЬКО ИЗВЕСТНЫЕ ОТСЕКИ" if state.get("map_ready",false) else "ПЛАН НЕ ЗАГРУЖЕН / ПУТЬ ЗАПИСЫВАЕТСЯ",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,8,V.MUTED)
