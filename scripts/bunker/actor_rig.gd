extends Node2D
# Jointed overhead figure: facing drives limbs, never rotates a whole portrait.
var heading := 0.0
var gait := 0.0
var speed := 0.0
var outfit := Color(0.52,0.57,0.56)
var infected := true
func update_pose(angle: float, walk: float, moving: float, delta: float) -> void:
    heading = lerp_angle(heading,angle,1.0-exp(-delta*9.0))
    gait = walk
    speed = clampf(moving/60.0,0,1)
    queue_redraw()
func _oval(p: Vector2, radii: Vector2, c: Color, angle := 0.0) -> void:
    var poly := PackedVector2Array()
    for i in range(16):
        var v := Vector2(cos(i*TAU/16),sin(i*TAU/16))*radii
        poly.append(p+v.rotated(angle))
    draw_colored_polygon(poly,c)
func _draw() -> void:
    var f := Vector2.from_angle(heading)
    var s := f.orthogonal()
    var sway := sin(gait)*speed
    var coat := outfit
    _oval(Vector2(2,4),Vector2(23,18),Color(0,0,0,0.22))
    for side in [-1.0,1.0]:
        var hip: Vector2 = -f*9+s*side*7
        var knee: Vector2 = hip-f*(8+side*sway*5)
        var foot: Vector2 = knee+f*(3+side*sway*8)
        draw_line(hip,knee,Color(0.10,0.14,0.17),10,true)
        draw_line(knee,foot,Color(0.15,0.19,0.21),8,true)
        _oval(foot,Vector2(9,5),Color(0.055,0.07,0.08),heading)
    _oval(-f*3,Vector2(18,14),coat.darkened(0.25),heading+PI/2)
    _oval(-f*1,Vector2(17,12),coat,heading+PI/2)
    draw_line(-f*12,-f*1,coat.lightened(0.14),2,true)
    for side in [-1.0,1.0]:
        var shoulder: Vector2 = s*side*15-f*2
        var elbow: Vector2 = shoulder+f*(5+side*sway*2)+s*side*4
        var hand: Vector2 = elbow+f*(10 if infected else 7)-s*side*3
        draw_line(shoulder,elbow,coat.darkened(0.2),9,true)
        draw_line(elbow,hand,coat,7,true)
        _oval(hand,Vector2(4.5,3.5),Color(0.48,0.47,0.39),heading)
        draw_line(shoulder-s*side*2,elbow,coat.lightened(0.18),1,true)
    _oval(f*4,Vector2(9,10),Color(0.37,0.34,0.29),heading)
    _oval(f*3,Vector2(8,9),Color(0.12,0.13,0.13),heading)
    _oval(f*10,Vector2(3,5),Color(0.51,0.48,0.40),heading)
    if infected: draw_line(s*9-f*7,s*11+f*2,Color(0.25,0.07,0.055),3,true)
