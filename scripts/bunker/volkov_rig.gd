extends Node2D
# Jointed photographic atlas; no direction bins or rotation of a whole character image.
const ATLAS=preload("res://assets/bunker/v9/volkov_parts.png")
var b=null
var heading:=PI/2
var torso_heading:=PI/2
var gait:=0.0
var speed:=0.0
var armed:=false
var parts: Dictionary={}
var initialized:=false
var recovery8:=1.0
var emergence8:=false
var joints8: Dictionary={}
var cutscene_clock8:=0.0
var boots9: Dictionary={}
func _ready() -> void:
    var regions: Dictionary=preload("res://scripts/bunker/v6_assets.gd").REGIONS
    for key in ["leg_l","leg_r","arm_l","arm_r","torso","head"]:
        var rect: Array=regions[key]
        var tex:=AtlasTexture.new();tex.atlas=ATLAS
        tex.region=Rect2(Vector2(rect[0],rect[1])*ATLAS.get_size(),Vector2(rect[2],rect[3])*ATLAS.get_size())
        var spr:=Sprite2D.new();spr.texture=tex
        var size: Vector2=Vector2(12,16) if key.begins_with("leg") else (Vector2(10,26) if key.begins_with("arm") else (Vector2(38,24) if key=="torso" else Vector2(17,19)))
        spr.scale=size/tex.get_size()
        spr.z_index=2 if key=="torso" else (3 if key=="head" else 0)
        add_child(spr);parts[key]=spr
    for limb in ["arm_l","arm_r","leg_l","leg_r"]:
        var full: AtlasTexture=parts[limb].texture
        for segment in ["upper","lower"]:
            var tex:=AtlasTexture.new();tex.atlas=ATLAS
            var rect:=full.region
            var half: float=rect.size.y*0.5
            tex.region=Rect2(rect.position+Vector2(0,half if segment=="upper" else 0),Vector2(rect.size.x,half))
            if limb.begins_with("leg") and segment=="lower":
                # Calf fabric and boot are separate. A bent knee must never turn a toe backwards.
                tex.region=Rect2(rect.position+Vector2(0,rect.size.y*.22),Vector2(rect.size.x,rect.size.y*.35))
            var sprite:=Sprite2D.new();sprite.texture=tex;sprite.z_index=1;sprite.hide();add_child(sprite)
            var length: float=(14.0 if segment=="upper" else 15.0) if limb.begins_with("arm") else (14.0 if segment=="upper" else 16.0)
            var width: float=9.0 if limb.begins_with("arm") else 11.0
            sprite.scale=Vector2(width/tex.get_width(),length/tex.get_height())
            joints8[limb+"_"+segment]=sprite
        if limb.begins_with("leg"):
            var boot_tex:=AtlasTexture.new();boot_tex.atlas=ATLAS
            boot_tex.region=Rect2(full.region.position,Vector2(full.region.size.x,full.region.size.y*.24))
            var boot:=Sprite2D.new();boot.texture=boot_tex;boot.scale=Vector2(10,10)/boot_tex.get_size();boot.z_index=1;add_child(boot);boots9[limb]=boot
    modulate=Color.WHITE
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
    # The same fixed-length articulated limbs are used in the capsule and gameplay.
    # Switching to locomotion never swaps a long cutscene sprite for a different body.
    for key in ["arm_l","arm_r","leg_l","leg_r"]: parts[key].hide()
    for sign in [-1,1]:
        var suffix: String="_l" if sign<0 else "_r"
        var hip: Vector2=-f*5+side*sign*7
        var foot: Vector2=-f*(23-step*sign*5)+side*sign*8
        _limb8("leg"+suffix,hip,foot,hip+side*sign*6-f*11,14,16)
        var shoulder: Vector2=side*sign*15
        var hand: Vector2=side*sign*(11 if armed else 17)+f*(26 if armed else 16+step*sign*3)
        _limb8("arm"+suffix,shoulder,hand,shoulder+side*sign*6+f*9,14,15)
    var torso: Sprite2D=parts.torso
    torso.rotation=torso_heading+PI/2
    torso.position=f*sin(gait*2)*speed*0.8+side*sin(gait)*speed*0.6
    var head: Sprite2D=parts.head
    head.position=Vector2.from_angle(heading)*6
    head.rotation=heading+PI/2
    for key in parts:
        var part: Sprite2D=parts[key]
        part.position.y*=lerpf(0.58,1.0,recovery8)
        if key.begins_with("arm"):
            part.rotation+=(-0.65 if key=="arm_l" else 0.65)*(1.0-recovery8)
    queue_redraw()
func _draw() -> void:
    draw_circle(Vector2(2,3),17,Color(0,0,0,0.20))

func _process(_delta: float) -> void:
    if b==null or b.player.is_empty(): return
    var anchor: Sprite2D=b.player["spr"]
    position=anchor.position
    visible=anchor.visible
    modulate.a=anchor.modulate.a

# Authored poses: hands brace on the rim and each foot crosses it separately.
# Values are local joint positions, not a tween of the whole character sprite.
const EXIT_POSES8=[
    [Vector2(0,-5),Vector2(0,-22),Vector2(-22,1),Vector2(-17,15),Vector2(22,1),Vector2(17,15),Vector2(-9,22),Vector2(-10,39),Vector2(9,22),Vector2(10,39)],
    [Vector2(0,-4),Vector2(0,-23),Vector2(-27,-17),Vector2(-37,-32),Vector2(27,-17),Vector2(37,-32),Vector2(-10,22),Vector2(-10,39),Vector2(10,22),Vector2(10,39)],
    [Vector2(0,-1),Vector2(0,-21),Vector2(-29,-8),Vector2(-38,-23),Vector2(29,-8),Vector2(38,-23),Vector2(-12,23),Vector2(-14,37),Vector2(12,23),Vector2(14,37)],
    [Vector2(0,3),Vector2(0,-16),Vector2(-25,12),Vector2(-36,17),Vector2(25,12),Vector2(36,17),Vector2(-18,22),Vector2(-25,14),Vector2(18,22),Vector2(25,14)],
    [Vector2(11,6),Vector2(10,-13),Vector2(-23,15),Vector2(-36,17),Vector2(29,17),Vector2(36,17),Vector2(32,27),Vector2(52,38),Vector2(18,22),Vector2(25,14)],
    [Vector2(15,8),Vector2(15,-10),Vector2(-13,17),Vector2(-26,24),Vector2(32,19),Vector2(40,27),Vector2(34,25),Vector2(51,40),Vector2(39,31),Vector2(57,45)],
    [Vector2(0,0),Vector2(0,7),Vector2(-17,5),Vector2(-12,17),Vector2(17,5),Vector2(12,17),Vector2(-8,-14),Vector2(-9,-24),Vector2(8,-14),Vector2(9,-24)]
]
func _segment8(key: String,start: Vector2,end: Vector2,width: float) -> void:
    var sprite: Sprite2D=joints8[key]
    sprite.show();sprite.position=(start+end)*0.5
    sprite.rotation=(end-start).angle()+PI/2
    # Scale is authored once in _ready. Animation changes only rotation and position.
func exit_pose8(stage: int,progress: float) -> void:
    emergence8=true
    for key in ["leg_l","leg_r","arm_l","arm_r"]: parts[key].hide()
    var start: Array=EXIT_POSES8[mini(stage,5)]
    var end: Array=EXIT_POSES8[mini(stage+1,6)]
    var pose_points: Array[Vector2]=[]
    var t:=smoothstep(0.0,1.0,progress)
    for i in range(start.size()): pose_points.append(start[i].lerp(end[i],t))
    var body: Vector2=pose_points[0]
    parts.torso.position=body;parts.torso.rotation=0 if stage<5 else lerpf(0,PI,t)
    parts.head.position=pose_points[1];parts.head.rotation=parts.torso.rotation
    for side in [-1,1]:
        var key: String="_l" if side<0 else "_r"
        var arm_index: int=2 if side<0 else 4
        var leg_index: int=6 if side<0 else 8
        _limb8("arm"+key,body+Vector2(side*14,0),pose_points[arm_index+1],pose_points[arm_index],14.0,15.0)
        _limb8("leg"+key,body+Vector2(side*7,9),pose_points[leg_index+1],pose_points[leg_index],14.0,16.0)
    queue_redraw()
func finish_exit8() -> void:
    emergence8=false;recovery8=1.0
    for joint in joints8.values(): joint.hide()
    parts.torso.show();parts.head.show()
    heading=PI/2;torso_heading=PI/2
    pose(PI/2,0,Vector2.ZERO,false,0.2)

func _limb8(key: String,origin: Vector2,target: Vector2,bend_hint: Vector2,upper: float,lower: float) -> void:
    var delta:=target-origin
    var distance:=clampf(delta.length(),absf(upper-lower)+0.01,upper+lower-0.01)
    var direction:=delta.normalized() if delta.length()>0.001 else Vector2.DOWN
    var reach:=origin+direction*distance
    var along: float=(upper*upper-lower*lower+distance*distance)/(2.0*distance)
    var height:=sqrt(maxf(0,upper*upper-along*along))
    var sign: float=1.0 if direction.cross(bend_hint-origin)>=0 else -1.0
    var joint:=origin+direction*along+direction.orthogonal()*height*sign
    _segment8(key+"_upper",origin,joint,9)
    _segment8(key+"_lower",joint,reach,9)
    if key.begins_with("leg") and boots9.has(key):
        boots9[key].position=reach
        boots9[key].rotation=parts.torso.rotation if emergence8 else torso_heading+PI/2
