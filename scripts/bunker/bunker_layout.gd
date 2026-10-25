extends RefCounted
# Authored footprint: long observation spine, dog-leg, lab branches and a lower service run.
const FLOOR := [
    [Rect2(120,160,760,600),"med",0],
    [Rect2(880,390,1440,180),"corridor",1],
    [Rect2(2140,570,180,550),"corridor",1],
    [Rect2(1750,120,540,270),"observation",1],
    [Rect2(1340,1120,980,620),"lab",2],
    [Rect2(1340,880,430,240),"lab",2],
    [Rect2(2320,1430,400,310),"archive",2],
    [Rect2(1080,1430,260,180),"tech",3],
    [Rect2(120,1180,960,700),"tech",3],
    [Rect2(120,980,370,200),"tech",3],
    [Rect2(470,1880,180,360),"stairs",4],
    [Rect2(120,2240,1100,500),"quarantine",4],
    [Rect2(1220,2440,580,180),"quarantine",4],
    [Rect2(1800,2030,1160,710),"cargo",5],
    [Rect2(2640,1770,320,260),"cargo",5],
    [Rect2(2320,740,60,140),"corridor",1],
    [Rect2(2380,640,380,420),"office",1],
    [Rect2(720,760,140,90),"med",0],
    [Rect2(650,850,360,300),"staff",0]
]
const ROOMS := [Rect2(120,160,760,600),Rect2(880,120,1440,1000),Rect2(1340,880,1380,860),Rect2(120,980,1220,900),Rect2(120,1880,1680,860),Rect2(1800,1770,1160,970)]
const PORTALS := [
    ["medical",Vector2(880,480),true,180.0],
    ["science",Vector2(2230,1120),false,180.0],
    ["technical",Vector2(1340,1520),true,180.0],
    ["lower",Vector2(560,1880),false,180.0],
    ["cargo",Vector2(1800,2530),true,180.0]
]
const PROPS := [
    # Revival workstation: capsule, monitoring, diagnostic trolley and storage are one system.
    ["z_capsule",Vector2(395,420),70.0,"capsule"],
    ["z_terminal",Vector2(680,320),42.0,"cryo_terminal"],
    ["z_gurney",Vector2(555,420),28.0,"workcart"],
    ["z_medtable",Vector2(310,650),48.0,"medtable"],
    ["z_cabinet",Vector2(225,245),34.0,"cabinet"],
    ["z_cabinet",Vector2(370,245),34.0,"cabinet"],
    ["z_server",Vector2(760,650),38.0,"server"],
    # Sealed observation bay and security desk tucked against the corridor wall.
    ["z_gurney",Vector2(2155,210),38.0,"medtable"],
    ["z_terminal",Vector2(1510,428),25.0,"cams_terminal"],
    ["z_medtable",Vector2(1980,429),16.0,"gear_table"],
    ["z_crate_z",Vector2(2165,2650),26.0,"loot_crate"],
    # Two laboratory islands and a side archive, never a furniture scatter.
    ["z_terminal",Vector2(1495,1000),40.0,"exp12_video"],
    ["z_terminal",Vector2(2570,1490),30.0,"journal"],
    ["z_capsule",Vector2(2140,1295),68.0,"exp12_capsule"],
    ["z_labdesk",Vector2(1575,1190),48.0,"labdesk"],
    ["z_labdesk",Vector2(1550,1650),48.0,"labdesk"],
    ["z_centrifuge",Vector2(1850,1600),33.0,"centrifuge"],
    ["z_shelf",Vector2(2590,1690),36.0,"shelf"],
    ["z_cabinet",Vector2(2260,1640),32.0,"cabinet"],
    # Machine hall has a central generator and two maintenance aisles.
    ["z_reactor",Vector2(470,1450),80.0,"generator"],
    ["z_server",Vector2(230,1085),40.0,"server"],
    ["z_server",Vector2(365,1085),40.0,"server"],
    ["z_scanner",Vector2(785,1290),18.0,"gen_panel"],
    ["z_ventplant",Vector2(295,1760),52.0,"ventplant"],
    ["z_crate_z",Vector2(905,1760),27.0,"fuse_crate"],
    ["z_stairs",Vector2(560,1830),38.0,"stairs_transition"],
    # Quarantine is a broken inspection bay, not an open combat arena.
    ["z_scanner",Vector2(290,2390),18.0,"iso_panel"],
    ["z_terminal",Vector2(1045,2630),40.0,"obs_terminal"],
    ["z_medtable",Vector2(500,2610),45.0,"medtable"],
    ["z_cabinet",Vector2(215,2630),32.0,"cabinet"],
    # Cargo mechanisms around the room edge, with a clear route to each switch.
    ["z_scanner",Vector2(1950,2230),18.0,"hydro"],
    ["z_scanner",Vector2(2310,2620),18.0,"hydro_lever"],
    ["z_scanner",Vector2(2800,1920),18.0,"power_hold"],
    ["z_airlock",Vector2(2820,2350),60.0,"exit_gate"],
    ["z_crate_z",Vector2(1970,2650),26.0,"loot_crate"],
    ["z_crate_z",Vector2(2070,2650),26.0,"loot_crate"],
    ["z_crate_z",Vector2(2750,2650),26.0,"loot_crate"],
    ["z_barrel",Vector2(2870,2620),24.0,"barrel"]
]

static func build(b) -> void:
    b.story_rooms = ROOMS.duplicate()
    b._scene_spawn = Vector2(395,470)
    for f in FLOOR:
        b.floor_zones.append({"rect":f[0],"kind":f[1],"sector":f[2]})
    # Merge exposed tile edges into long wall runs. No walls inside a connected corridor.
    var cells := {}
    const STEP := 10
    for f in FLOOR:
        var r: Rect2 = f[0]
        for y in range(int(r.position.y)/STEP,int(r.end.y)/STEP):
            for x in range(int(r.position.x)/STEP,int(r.end.x)/STEP): cells[Vector2i(x,y)] = true
    var horizontal := {}
    var vertical := {}
    for cell in cells:
        for side in [Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,0),Vector2i(1,0)]:
            if cells.has(cell+side): continue
            if side.y != 0:
                var key: int = (cell.y+(1 if side.y>0 else 0))*STEP
                if not horizontal.has(key): horizontal[key] = []
                horizontal[key].append(cell.x*STEP)
            else:
                var key: int = (cell.x+(1 if side.x>0 else 0))*STEP
                if not vertical.has(key): vertical[key] = []
                vertical[key].append(cell.y*STEP)
    for set_pair in [[horizontal,false],[vertical,true]]:
        for key in set_pair[0]:
            var values: Array = set_pair[0][key]
            values.sort()
            var first: int = values[0]
            var last := first
            for i in range(1,values.size()+1):
                if i < values.size() and int(values[i]) <= last+STEP:
                    last = int(values[i])
                    continue
                if set_pair[1]: b._wall(float(key)-17,first,34,last-first+STEP)
                else: b._wall(first,float(key)-17,last-first+STEP,34)
                if i < values.size():
                    first = int(values[i]); last = first
    # Inaccessible viewing room remains behind physical safety glazing.
    b._wall(1750,375,540,30)
    for portal in PORTALS: b._door(portal[0],portal[1],portal[2],portal[3])
    for p in PROPS: b._prop(p[0],p[1],p[2],p[3])
    b.safe_figure = b._mk_spr("z_zombie_sci_w0",Vector2(1930,270),0.68,8)
    b.safe_figure.texture = preload("res://assets/bunker/scientist0.png")
    b.safe_figure.scale = Vector2(0.27,0.27)
    # Nonblocking incident dressing and workstation chairs.
    for p in [["z_chair",Vector2(680,405),24.0,"seat"],["z_fallen_chair",Vector2(600,560),24.0,"incident"],["z_tools",Vector2(535,550),16.0,"incident"],["z_chair",Vector2(1575,1280),24.0,"seat"],["z_chair",Vector2(1550,1560),24.0,"seat"],["z_conduit",Vector2(935,1225),26.0,"communication"]]:
        b._prop(p[0],p[1],p[2],p[3],1.42,false)
    b._spawn_zombie("sci",Vector2(1970,1470))
    b._spawn_zombie("walk",Vector2(2520,1660))
    b._spawn_zombie("cop",Vector2(760,2590))
    b._spawn_zombie("walk",Vector2(1120,2390))
    b._spawn_corpse("guard",Vector2(800,2380))
    b.corpses[-1]["bonus"] = ["air_key"]
