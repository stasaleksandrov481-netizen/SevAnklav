extends Node2D
# Jointed photographic atlas; no direction bins or rotation of a whole character image.
const ATLAS=preload("res://assets/bunker/v6/volkov_parts.png")
var b=null
var heading:=PI/2
var torso_heading:=PI/2
var gait:=0.0
var speed:=0.0
var armed:=false
var parts: Dictionary={}
var initialized:=false
func _ready() -> void:
    var regions: Dictionary=preload("res://scripts/bunker/v6_assets.gd").REGIONS
    for key in ["leg_l","leg_r","arm_l","arm_r","torso","head"]:
        var rect: Array=regions[key]
        var tex:=AtlasTexture.new();tex.atlas=ATLAS
        tex.region=Rect2(Vector2(rect[0],rect[1])*ATLAS.get_size(),Vector2(rect[2],rect[3])*ATLAS.get_size())
        var spr:=Sprite2D.new();spr.texture=tex
        var size: Vector2=Vector2(11,30) if key.begins_with("leg") else (Vector2(10,26) if key.begins_with("arm") else (Vector2(38,24) if key=="torso" else Vector2(17,19)))
        spr.scale=size/tex.get_size()
        spr.z_index=2 if key=="torso" else (3 if key=="head" else 0)
        add_child(spr);parts[key]=spr
    modulate=Color(1.5,1.5,1.5,1)
    initialized=true
    pose(PI/2,0,Vector2.ZERO,false,0.1)
func pose(look: float, walk: float, velocity: Vector2, holding: bool, delta: float) -> void:
    if not initialized: return
    heading=lerp_angle(heading,look,1-exp(-delta*18))
    torso_heading=lerp_angle(torso_heading,heading,1-exp(-delta*11))
    armed=holding
    gait=walk;speed=clampf(velocity.length()/105.0,0,1)
    var f:=Vector2.from_angle(torso_heading)
    var side:=f.rotated(PI/2)
    var step:=sin(gait)*speed
    for sign in [-1,1]:
        var leg: Sprite2D=parts["leg_l" if sign<0 else "leg_r"]
        leg.position=-f*10+side*sign*8+f*(step*sign*5)
        leg.rotation=torso_heading+PI/2+sign*sin(gait)*speed*0.10
        var arm: Sprite2D=parts["arm_l" if sign<0 else "arm_r"]
        arm.position=side*sign*(11 if armed else 17)+f*(8 if armed else 1)+f*step*sign*(0.4 if armed else 2.0)
        arm.rotation=torso_heading+PI/2-sign*(0.55 if armed else 0.10+step*0.08)
    var torso: Sprite2D=parts.torso
    torso.rotation=torso_heading+PI/2
    torso.position=f*sin(gait*2)*speed*0.45
    var head: Sprite2D=parts.head
    head.position=Vector2.from_angle(heading)*6
    head.rotation=heading+PI/2
    queue_redraw()
func _draw() -> void:
    draw_circle(Vector2(2,3),17,Color(0,0,0,0.20))

func _process(_delta: float) -> void:
    if b==null or b.player.is_empty(): return
    var anchor: Sprite2D=b.player["spr"]
    position=anchor.position
    visible=anchor.visible
    modulate.a=anchor.modulate.a
