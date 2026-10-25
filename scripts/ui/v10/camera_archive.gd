extends Control
const Furnish=preload("res://scripts/bunker/v10/furnishing.gd")
const Architecture=preload("res://assets/bunker/v10/architecture.png")
const Scientist=preload("res://assets/bunker/scientist0.png")
const Guard=preload("res://assets/bunker/guard0.png")
var frame:=0
func _ready() -> void:
    mouse_filter=MOUSE_FILTER_STOP
    tooltip_text="Коснитесь кадра, чтобы перейти к следующему"
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
        frame=(frame+1)%3;queue_redraw();accept_event()
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(.045,.075,.085))
    var area:=Rect2(12,30,size.x-24,size.y-54)
    var world:=Rect2(1710,100,620,500)
    var scale10:=minf(area.size.x/world.size.x,area.size.y/world.size.y)
    var origin:=area.get_center()-world.size*scale10*.5
    draw_texture_rect_region(Architecture,Rect2(origin,world.size*scale10),world,Color(.63,.75,.68))
    draw_set_transform(origin-world.position*scale10,0,Vector2.ONE*scale10)
    for station in [["research",Vector2(1820,195),138.0],["security",Vector2(2050,200),140.0],["archive",Vector2(2200,305),110.0]]:
        var extent:=Vector2(float(station[2]),float(station[2])*.56)
        draw_texture_rect(Furnish.texture(station[0]),Rect2(station[1]-extent*.5,extent),false,Color(.64,.76,.68))
    draw_line(Vector2(1750,390),Vector2(2290,390),Color(.47,.66,.65,.7),7)
    draw_circle(Vector2(2070,421),5,Color(.33,.61,.52) if frame==0 else Color(.72,.18,.14))
    if frame<2:
        draw_texture_rect(Scientist,Rect2(Vector2(2010,320)+Vector2(frame*28,0),Vector2(39,42)),false,Color(.76,.84,.76))
        draw_texture_rect(Guard,Rect2(Vector2(2045,445),Vector2(39,42)),false,Color(.68,.77,.71))
    if frame>0: draw_texture_rect(Scientist,Rect2(Vector2(2060,310),Vector2(39,42)),false,Color(.51,.66,.56))
    if frame==2: draw_texture_rect(Furnish.texture("paper"),Rect2(2050,451,12,16),false,Color(.8,.8,.7))
    draw_set_transform(Vector2.ZERO)
    draw_string(ThemeDB.fallback_font,Vector2(12,20),"КАМЕРА 02  /  21:14:%02d"%(3+frame*4),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.64,.77,.71))
    draw_string(ThemeDB.fallback_font,Vector2(12,size.y-8),"КАДР %d / 3   ·   КОСНИТЕСЬ ДЛЯ ПРОСМОТРА"%(frame+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(.59,.7,.66))
    for y in range(30,int(size.y)-20,5): draw_line(Vector2(0,y),Vector2(size.x,y),Color(0,0,0,.10),1)
