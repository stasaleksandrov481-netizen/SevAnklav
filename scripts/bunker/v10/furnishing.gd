extends RefCounted
static var textures: Dictionary={}
const ATLAS=preload("res://assets/bunker/v10/furniture_atlas.svg")
const KINDS=["medical","research","security","archive","power","access","emergency","personal","server","locker","bench","gurney","sofa","coffee","paper","carrier"]
static func texture(kind: String) -> Texture2D:
    if not textures.has(kind):
        var index:=KINDS.find(kind)
        var extent:=Vector2(30,38) if kind=="paper" else (Vector2(22,35) if kind=="carrier" else Vector2(200,112))
        var tex:=AtlasTexture.new();tex.atlas=ATLAS
        tex.region=Rect2(Vector2((index%4)*200,(index/4)*112)+(Vector2(200,112)-extent)*.5,extent)
        textures[kind]=tex
    return textures[kind]
static func terminal_style(kind: String) -> String:
    return {"cryo_terminal":"medical","cams_terminal":"security","exp12_video":"research","journal":"archive","obs_terminal":"emergency","gen_panel":"power","iso_panel":"access","hydro":"power","hydro_lever":"access","power_hold":"emergency"}.get(kind,"")
static func make(b,kind: String,pos: Vector2,width: float,solid:=true,angle:=0.0) -> Dictionary:
    var sprite:=Sprite2D.new();sprite.texture=texture(kind);sprite.position=pos
    sprite.scale=Vector2.ONE*width/sprite.texture.get_width();sprite.rotation=angle;sprite.z_index=3
    b.prop_layer.add_child(sprite)
    var half:=sprite.texture.get_size()*.5
    var inset:=half*.06
    var r:=Rect2(-half+inset,half*2-inset*2)
    var footprint:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
    var prop: Dictionary={"spr":sprite,"pos":pos,"kind":"detail10","solid":solid,"half":half*sprite.scale,"radius":width*.4,"footprint10":footprint,"tall10":kind in ["server","locker"],"style10":kind}
    b.props.append(prop);b.PropGeometry7.build(prop)
    return prop
static func build(b) -> void:
    # Chairs face their workstation; cabinets remain on the room perimeter.
    var stations: Array=[
      ["medical",Vector2(630,665),142.0],["medical",Vector2(280,365),105.0],
      ["research",Vector2(1820,195),138.0],["security",Vector2(2050,200),140.0],["archive",Vector2(2200,305),110.0],
      ["research",Vector2(1880,1225),166.0],["medical",Vector2(1870,1410),150.0],
      ["archive",Vector2(2500,1605),124.0],
      ["bench",Vector2(780,1400),168.0],["power",Vector2(740,1600),160.0],["access",Vector2(995,1260),80.0],
      ["medical",Vector2(780,2460),152.0],["emergency",Vector2(1975,2110),140.0],
      ["personal",Vector2(2550,735),160.0],["archive",Vector2(2530,945),145.0],
      ["personal",Vector2(825,970),138.0]
    ]
    for spec in stations:
        make(b,spec[0],spec[1],spec[2])
        var chair: Dictionary=b._prop("z_chair",spec[1]+Vector2(0,float(spec[2])*.28+18),14.0,"seat",.84,true)
        chair["spr"].rotation=PI
        b.PropGeometry7.update(chair)
    for spec in [
       ["gurney",Vector2(270,535),117.0,PI/2],["locker",Vector2(820,360),66.0,PI/2],
       ["server",Vector2(1400,920),84.0,0.0],["server",Vector2(1510,920),84.0,0.0],
       ["server",Vector2(1620,920),84.0,0.0],
       ["locker",Vector2(2260,1530),80.0,PI/2],
       ["server",Vector2(200,1580),96.0,PI/2],["server",Vector2(200,1680),96.0,PI/2],
       ["locker",Vector2(2685,686),82.0,0.0],["server",Vector2(2685,966),80.0,0.0],
       ["sofa",Vector2(750,1085),150.0,0.0],["coffee",Vector2(945,900),61.0,0.0],
       ["locker",Vector2(955,1055),76.0,PI/2],["locker",Vector2(660,2510),75.0,PI/2],
       ["bench",Vector2(2620,2130),154.0,0.0]
    ]: make(b,spec[0],spec[1],spec[2],true,spec[3])
    # New doors are appended AFTER the legacy prop list: v3/v4 indexed saves keep their order.
    b._door("staff10",Vector2(790,850),false,140)
    b._door("office10",Vector2(2380,810),true,140)
    for prop in b.props:
        if prop.kind=="incident" and prop.pos==Vector2(600,560):
            prop.pos=Vector2(650,570);prop.spr.position=prop.pos;b.PropGeometry7.update(prop)
