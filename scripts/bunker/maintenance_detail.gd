extends Node2D
var b
func _draw() -> void:
    draw_rect(Rect2(720,1205,170,145),Color(0.07,0.11,0.13))
    draw_rect(Rect2(728,1213,154,129),Color(0.32,0.40,0.40),false,3)
    for i in range(3):
        var points:=PackedVector2Array([Vector2(790+i*13,1220),Vector2(790+i*13,1195),Vector2(940+i*8,1195),Vector2(940+i*8,1260)])
        draw_polyline(points,Color(0.02,0.035,0.04),7,true)
        draw_polyline(points,Color(0.25,0.31,0.31),2,true)
        draw_line(Vector2(940+i*8,1260),Vector2(931+i*14,1285+i*3),Color(0.42,0.27,0.13),2,true)
    draw_string(ThemeDB.fallback_font,Vector2(736,1234),"РЕЗЕРВ / 220 В",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.71,0.63,0.38))
    for i in range(5):
        draw_rect(Rect2(741+i*25,1301,12,25),Color(0.09,0.15,0.17))
        draw_line(Vector2(745+i*25,1306),Vector2(745+i*25,1322),Color(0.59,0.64,0.56),2)
    for i in range(9):
        draw_line(Vector2(710+i*23,1394),Vector2(721+i*23,1405),Color(0.58,0.46,0.23,0.6),5,true)
    draw_string(ThemeDB.fallback_font,Vector2(815,1712),"ЗАПАСНЫЕ ВСТАВКИ",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.51,0.60,0.58))
