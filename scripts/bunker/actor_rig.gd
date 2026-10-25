extends Node2D
var heading:=0.0
var gait:=0.0
var speed:=0.0
var outfit:=Color(0.52,0.57,0.56)
var infected:=true
var b=null
var fallen:=false
var fall_time:=0.0
var fall_angle:=0.0
var fall_origin:=Vector2.ZERO
var fall_target:=Vector2.ZERO
var phase:=randf()*TAU
const ATLAS=preload("res://assets/bunker/v10/volkov_modules.png")
var parts9: Dictionary={}
func _ready() -> void:
    var assets=preload("res://scripts/bunker/v10/actor_assets.gd")
    for key in ["torso","head"]: parts9[key]=assets.texture(key)
func update_pose(angle: float, _walk: float, moving: float, delta: float) -> void:
    if fallen: return
    heading=lerp_angle(heading,angle,1.0-exp(-delta*(4.5 if infected else 9.0)))
    speed=move_toward(speed,clampf(moving/55.0,0,1),delta*3)
    gait+=moving*delta/12.0
    queue_redraw()
func fall(direction: Vector2) -> void:
    fallen=true;fall_origin=position
    fall_target=position+direction.normalized()*23
    if b!=null: fall_target=b._collide_circle(fall_target,13)
    fall_angle=direction.angle()-heading+PI/2
    visible=true
func _process(delta: float) -> void:
    if not fallen or (b!=null and b.paused): return
    fall_time=minf(1.4,fall_time+delta)
    position=fall_origin.lerp(fall_target,smoothstep(0.0,0.75,fall_time))
    if b!=null: visible=b.awareness5.sees(position)
    queue_redraw()
func _oval(p: Vector2, radii: Vector2, col: Color, angle:=0.0) -> void:
    var points:=PackedVector2Array()
    for i in range(20): points.append(p+(Vector2.from_angle(i*TAU/20)*radii).rotated(angle))
    draw_colored_polygon(points,col)
func _draw() -> void:
    var collapse:=smoothstep(0.0,0.85,fall_time) if fallen else 0.0
    var f:=Vector2.from_angle(heading+fall_angle*collapse)
    var s:=f.orthogonal()
    var sway:=sin(gait+phase)*speed
    var tilt:=sin(gait*0.5+phase)*speed*(1.8 if infected else 0.6)
    var body:=s*tilt-f*collapse*9
    _oval(Vector2(2,5),Vector2(19+collapse*9,14),Color(0,0,0,0.26))
    for side in [-1.0,1.0]:
        var stride:=sin(gait+phase+(PI if side<0 else 0))*speed
        if infected and side<0: stride*=0.62
        var hip: Vector2=body-f*5+s*side*7
        var knee: Vector2=hip-f*5+f*stride*3+s*side*collapse*5
        var foot: Vector2=knee-f*5+f*stride*4+s*side*collapse*8
        draw_line(hip,knee,Color(0.12,0.17,0.20),9,true)
        draw_line(knee,foot,Color(0.17,0.21,0.23),7,true)
        _oval(foot,Vector2(9,5),Color(0.045,0.06,0.07),f.angle())
    _oval(body-f*2,Vector2(18,13),outfit.darkened(0.3),f.angle()+PI/2)
    _oval(body+f,Vector2(17,11),outfit,f.angle()+PI/2)
    # Textured shoulders, pockets and a recognisable crown replace plain circles.
    if parts9.has("torso"):
        draw_set_transform(body,heading+fall_angle*collapse+PI/2)
        draw_texture_rect(parts9.torso,Rect2(-17,-10.5,34,21),false,outfit.lightened(.4))
        draw_set_transform(Vector2.ZERO)
    draw_line(body-f*9,body+f*5,outfit.lightened(0.23),1.2,true)
    for side in [-1,1]:
        draw_line(body+s*side*11-f*5,body+s*side*11+f*6,outfit.lightened(.2),1,true)
    if infected:
        for i in range(4):
            var p:=body+s*(5+i*1.5)+f*(i*3-8)
            draw_line(p,p+s*4+f*3,Color(.26,.095,.08,.8),1.4,true)
    for side in [-1.0,1.0]:
        var shoulder: Vector2=body+s*side*15
        var elbow: Vector2=shoulder+f*(5+side*sway*3)+s*side*(3+collapse*8)
        var hand: Vector2=elbow+f*(10 if infected else 6)-s*side*2+s*side*collapse*9
        draw_line(shoulder,elbow,outfit.darkened(0.2),9,true)
        draw_line(elbow,hand,outfit,7,true)
        _oval(hand,Vector2(4,3),Color(0.48,0.46,0.37),f.angle())
    _oval(body+f*6,Vector2(9,10),Color(0.36,0.33,0.27),f.angle())
    _oval(body+f*5,Vector2(8,8),Color(0.12,0.13,0.13),f.angle())
    _oval(body+f*12,Vector2(3,5),Color(0.50,0.46,0.38),f.angle())
    if parts9.has("head"):
        draw_set_transform(body+f*6,heading+fall_angle*collapse+PI/2)
        draw_texture_rect(parts9.head,Rect2(-7,-8.5,14,17),false,Color(.78,.79,.72))
        draw_set_transform(Vector2.ZERO)
    if infected: draw_line(body+s*9-f*7,body+s*11+f*2,Color(0.25,0.07,0.055),3,true)
