extends Node2D
func _draw() -> void:
    var shape:=PackedVector2Array([Vector2(-35,0),Vector2(35,0),Vector2(43,126),Vector2(24,150),Vector2(-24,150),Vector2(-43,126)])
    draw_colored_polygon(shape,Color(0.10,0.23,0.27,0.88))
    var edge:=shape.duplicate();edge.append(shape[0]);draw_polyline(edge,Color(0.48,0.65,0.67),5,true)
    draw_line(Vector2(-23,18),Vector2(18,125),Color(0.70,0.84,0.83,0.22),4,true)
    for x in [-30,30]: draw_circle(Vector2(x,6),5,Color(0.43,0.51,0.52))
    draw_line(Vector2(-16,132),Vector2(16,132),Color(0.64,0.72,0.68),5,true)
