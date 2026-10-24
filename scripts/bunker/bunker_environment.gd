extends Node2D
const Layout = preload("res://scripts/bunker/bunker_layout.gd")
var b = null
var textures := {}
var baked_floor: Texture2D = preload("res://assets/bunker/v5/architecture.png")

var lights: Array = []
var phase := 0.0
var refresh := 0.0
var wall_snapshot: Array = []
var doors_snapshot: Array = []
var effects: Node2D
var light_texture: GradientTexture2D
var muzzle: PointLight2D
var muzzle_time := 0.0

func configure(battle) -> void:
    b = battle
    z_index = -10
    light_texture = GradientTexture2D.new()
    light_texture.width = 256; light_texture.height = 256
    light_texture.fill = GradientTexture2D.FILL_RADIAL
    light_texture.fill_from = Vector2(0.5,0.5); light_texture.fill_to = Vector2(1.0,0.5)
    var g := Gradient.new()
    g.set_color(0,Color(1,1,1,1)); g.set_color(1,Color(1,1,1,0))
    g.add_point(0.18,Color(1,1,1,0.85));g.add_point(0.65,Color(1,1,1,0.18))
    light_texture.gradient = g
    # Shadow walls follow door removal; static large furniture casts short silhouettes.
    for w in b.walls:
        var occ := _occluder(w)
        wall_snapshot.append({"rect":w,"node":occ})
    # Furniture occluders are children of their sprites and share the physical silhouette.
    # Cold ceiling islands leave deliberate dark intervals.
    for p in [Vector2(440,300),Vector2(1560,450),Vector2(1950,445),Vector2(1120,470),Vector2(2210,690),Vector2(1620,1240),Vector2(2520,1500),Vector2(340,1340),Vector2(890,1530),Vector2(320,2400),Vector2(2070,2200),Vector2(2810,1840)]:
        _light(p,Color(0.63,0.78,0.85),390 if p.x<880 else 330,0.95,"cold")
    for p in [Vector2(810,510),Vector2(1700,515),Vector2(2185,1030),Vector2(2200,1650),Vector2(950,1230),Vector2(520,2100),Vector2(1110,2580),Vector2(1720,2510),Vector2(2870,2300)]:
        _light(p,Color(1.0,0.055,0.018),340,1.35,"red")
    # Low intensity local monitor spill, never a room fill.
    for p in b.props:
        if p["kind"] in ["cryo_terminal","cams_terminal","exp12_video","journal","obs_terminal","gen_panel"]:
            _light(p["pos"]+Vector2(0,32),Color(0.30,0.72,0.86),120,0.6,"screen")
    effects = Node2D.new()
    effects.z_index = 12
    b.add_child(effects)
    for p in [Vector2(850,1310),Vector2(2185,920),Vector2(1410,1680)]: _steam(p)
    var damage := Damage.new()
    damage.b = b
    effects.add_child(damage)
    muzzle = PointLight2D.new()
    muzzle.texture = light_texture; muzzle.texture_scale = 1.35
    muzzle.color = Color(1.0,0.66,0.28); muzzle.energy = 0
    muzzle.range_z_min = -20; muzzle.range_z_max = 30
    effects.add_child(muzzle)
    queue_redraw()

func _occluder(rect: Rect2) -> LightOccluder2D:
    var occ := LightOccluder2D.new()
    var poly := OccluderPolygon2D.new()
    poly.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
    occ.occluder = poly
    add_child(occ)
    return occ

func _light(pos: Vector2, color: Color, radius: float, energy: float, kind: String) -> void:
    var p := PointLight2D.new()
    p.texture = light_texture
    p.texture_scale = radius/128.0
    if kind in ["red","cold"]: pos = _fixture_position(pos)
    p.position = pos; p.color = color; p.energy = energy
    p.range_z_min = -20; p.range_z_max = 30
    p.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    p.shadow_color = Color(0.015,0.018,0.025,0.84)
    p.shadow_filter_smooth = 1.5
    p.enabled = false
    add_child(p)
    var entry: Dictionary={"node":p,"energy":energy,"kind":kind,"radius":radius,"fixture":null,"lens":null}
    lights.append(entry)
    if kind in ["red","cold"]:
        var fixture := Sprite2D.new()
        fixture.texture = preload("res://assets/bunker/wallamp_red.png") if kind=="red" else preload("res://assets/bunker/wallamp.png")
        fixture.position = pos
        var distance := INF
        for wall in b.walls:
            var q:=Vector2(clampf(pos.x,wall.position.x,wall.end.x),clampf(pos.y,wall.position.y,wall.end.y))
            if pos.distance_squared_to(q)<distance:
                distance=pos.distance_squared_to(q)
                fixture.rotation=PI/2 if wall.size.y>wall.size.x else 0.0
        fixture.scale = Vector2(0.14,0.14)
        fixture.z_index = 15
        var material := CanvasItemMaterial.new()
        material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
        fixture.material = material
        fixture.modulate.a = 0.70
        entry["fixture"]=fixture
        var lens:=Sprite2D.new()
        lens.texture=light_texture
        lens.position=pos
        lens.scale=Vector2(0.20,0.20)
        lens.z_index=16
        var emission:=CanvasItemMaterial.new()
        emission.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
        emission.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
        lens.material=emission
        lens.modulate=Color(1,0.035,0.01,0.45) if kind=="red" else Color(0.52,0.75,0.83,0.16)
        entry["lens"]=lens
        add_child(lens)
        add_child(fixture)

func _fixture_position(hint: Vector2) -> Vector2:
    var best := hint
    var distance := INF
    for w in b.walls:
        var is_door := false
        for id in b.doors:
            if b.doors[id]["wall"]==w: is_door=true
        if is_door: continue
        var q := Vector2(clampf(hint.x,w.position.x,w.end.x),clampf(hint.y,w.position.y,w.end.y))
        var d := hint.distance_squared_to(q)
        if d<distance:
            distance=d
            best=q+(hint-q).normalized()*10
    return best

func _steam(pos: Vector2) -> void:
    var steam := CPUParticles2D.new()
    steam.position = pos
    steam.texture = light_texture
    steam.amount = 5
    steam.lifetime = 2.8
    steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    steam.emission_rect_extents = Vector2(14,5)
    steam.direction = Vector2(1,-0.4);steam.spread = 14
    steam.gravity = Vector2(6,-8)
    steam.initial_velocity_min = 16;steam.initial_velocity_max = 34
    steam.scale_amount_min = 0.10;steam.scale_amount_max = 0.24
    steam.color = Color(0.50,0.63,0.68,0.08)
    effects.add_child(steam)
    b.steam_particles.append(steam)

func muzzle_flash(pos: Vector2) -> void:
    muzzle.position = pos
    muzzle_time = 0.075

func _process(delta: float) -> void:
    if b == null: return
    phase += delta
    var prefs: Dictionary = G.zsave.get("bunker_visual",{})
    var brightness: float = clampf(float(prefs.get("brightness",1.0)),0.75,1.3)
    b.canvas_mod.color = Color(0.18,0.215,0.25)*brightness
    for particle in b.steam_particles:
        if is_instance_valid(particle): particle.emitting = bool(prefs.get("particles",true)) and b.q_level>0 and particle.position.distance_to(b.player["spr"].position)<700
    if muzzle_time > 0:
        muzzle_time = maxf(0,muzzle_time-delta)
        muzzle.energy = muzzle_time/0.075*1.5
    refresh -= delta
    if refresh <= 0:
        refresh = 0.25
        # Camera distance bounds light work. Two lamp shadow maps plus the player cone.
        var visible: Array = []
        var view: Vector2 = b.get_viewport_rect().size/b.camera.zoom
        var bounds := Rect2(b.camera.get_screen_center_position()-view*0.5,view).grow(240)
        for l in lights:
            var node: PointLight2D = l["node"]
            node.enabled = bounds.has_point(node.position)
            node.shadow_enabled = false
            if node.enabled: visible.append(l)
        visible.sort_custom(func(a,c): return a["node"].position.distance_squared_to(b.player["spr"].position)<c["node"].position.distance_squared_to(b.player["spr"].position))
        # Reserve a slot for the alarm. Sorting all sources together used to erase its light.
        var chosen: Array=[]
        for kind in ["red","cold"]:
            for entry in visible:
                if entry["kind"]==kind:
                    chosen.append(entry)
                    break
        if b.q_level>0:
            for entry in visible:
                if entry["kind"]=="screen": chosen.append(entry);break
        for entry in visible:
            var lamp: PointLight2D=entry["node"]
            lamp.enabled=chosen.has(entry)
            lamp.shadow_enabled=lamp.enabled and entry["kind"]!="screen"
            lamp.shadow_filter=Light2D.SHADOW_FILTER_PCF5 if b.q_level>0 else Light2D.SHADOW_FILTER_NONE

    for i in range(lights.size()):
        var l: Dictionary = lights[i]
        var node: PointLight2D = l["node"]
        var k := 1.0
        if l["kind"] == "red":
            # A short beacon hold and long blackout: the emitter and the actual lens agree.
            var cycle:=fposmod(phase+float(i)*0.37,3.8)
            k=0.06+0.94*smoothstep(0.0,0.14,cycle)*(1.0-smoothstep(1.65,2.15,cycle))
        elif l["kind"] == "screen": k = 0.94+0.06*sin(phase*1.4+i)
        else: k = 0.98+0.02*sin(phase*1.7+i)
        node.energy = float(l["energy"])*k
        if is_instance_valid(l["fixture"]): l["fixture"].modulate=Color(1,1,1,0.10+0.90*k)
        if is_instance_valid(l["lens"]): l["lens"].modulate.a=(0.60 if l["kind"]=="red" else 0.14)*k

func redraw_all() -> void:
    for w in wall_snapshot: w["node"].visible = b.walls.has(w["rect"])
    queue_redraw()

func _draw() -> void:
    if b == null: return
    if baked_floor!=null:
        draw_texture_rect(baked_floor,Rect2(Vector2.ZERO,b.map_size),false)
        return
    _draw_architecture()

func _draw_architecture() -> void:
    if textures.is_empty():
        for name in ["medical","laboratory","technical","cargo"]:
            textures[name]=load("res://assets/bunker/v4/surface_"+name+".svg")
    draw_rect(Rect2(Vector2.ZERO,b.map_size),Color(0.018,0.022,0.027))
    for f in Layout.FLOOR:
        var r: Rect2 = f[0]
        var kind: String = f[1]
        var tex: Texture2D = textures["technical" if kind in ["corridor","tech","stairs"] else ("medical" if kind in ["med","quarantine","observation"] else ("cargo" if kind=="cargo" else "laboratory"))]
        draw_texture_rect(tex,r,false)
        # Perimeter coving and recessed skirting; no tiled-square floor pattern.
        for i in range(3): draw_rect(r.grow(-float(i)*3),Color(0.015,0.025,0.03,0.12),false,7)
        if kind in ["corridor","stairs"]:
            var horizontal: bool = r.size.x > r.size.y
            var line_a := r.position+Vector2(28,28)
            var line_b := Vector2(r.end.x-28,r.position.y+28) if horizontal else Vector2(r.position.x+28,r.end.y-28)
            draw_line(line_a,line_b,Color(0.38,0.51,0.55,0.5),3)
            # Long recessed service strip, with small grates only on its edge.
            _grate(Rect2(r.position+Vector2(8,40),Vector2(18,r.size.y-80)) if not horizontal else Rect2(r.position+Vector2(40,r.size.y-30),Vector2(r.size.x-80,18)))
        elif kind == "tech":
            _grate(Rect2(r.position+Vector2(40,r.size.y-50),Vector2(r.size.x-80,28)))
    # Deliberately placed large sealed panels and workstation footprints.
    for r in [Rect2(265,320,320,240),Rect2(1390,1190,470,210),Rect2(1390,1480,470,210),Rect2(210,1320,510,270),Rect2(2000,2240,500,220)]:
        draw_rect(r,Color(0.48,0.57,0.59,0.12))
        draw_rect(r.grow(-3),Color(0.13,0.21,0.25,0.45),false,2)
        for v in [Vector2(10,10),Vector2(r.size.x-10,10),Vector2(10,r.size.y-10),r.size-Vector2(10,10)]:
            draw_circle(r.position+v,2,Color(0.42,0.48,0.50))
    # Flush access covers, direction marks and expansion joints follow each sector.
    for f in Layout.FLOOR:
        var r: Rect2=f[0]
        if r.size.x<300 or r.size.y<250: continue
        var access:=Rect2(r.end-Vector2(135,90),Vector2(92,52))
        draw_rect(access,Color(0.12,0.18,0.21))
        draw_rect(access.grow(-4),Color(0.36,0.44,0.47),false,1.5)
        for side in [-1,1]:
            draw_circle(access.get_center()+Vector2(side*36,0),2.5,Color(0.07,0.11,0.13))
        for x in range(int(r.position.x+90),int(r.end.x-60),240):
            draw_line(Vector2(x,r.position.y+52),Vector2(x+110,r.position.y+52),Color(0.06,0.11,0.14,0.55),1.5)
        var origin:=r.position+Vector2(45,r.size.y-65)
        draw_string(ThemeDB.fallback_font,origin,"0%d / %s"%[int(f[2])+1,str(f[1]).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.53,0.64,0.66,0.42))
    # Revival unit's hoses terminate at diagnostic trolley and personnel terminal.
    _cable([Vector2(430,430),Vector2(510,455),Vector2(570,440),Vector2(570,330),Vector2(655,330)],Color(0.04,0.1,0.13),7)
    _cable([Vector2(400,385),Vector2(420,290),Vector2(660,290)],Color(0.11,0.24,0.29),4)
    _pipe(Vector2(165,1230),Vector2(1010,1230))
    _pipe(Vector2(1260,1480),Vector2(1260,1560))
    _pipe(Vector2(2720,1815),Vector2(2890,1815))
    for r in [Rect2(300,600,190,15),Rect2(450,1810,220,13),Rect2(2765,2245,16,210),Rect2(960,1250,14,140)]: _hazard(r)
    for w in b.walls:
        # Wide load-bearing wall cap, internal recess, fasteners and door returns.
        draw_rect(w.grow(24),Color(0,0,0,0.13))
        draw_rect(w.grow(13),Color(0,0,0,0.24))
        draw_rect(w.grow(5),Color(0.035,0.048,0.058))
        draw_rect(w,Color(0.20,0.26,0.30))
        draw_rect(w.grow(-5),Color(0.12,0.17,0.21))
        var vertical: bool = w.size.y>w.size.x
        var length: float = maxf(w.size.x,w.size.y)
        var start: Vector2 = w.position+Vector2(4,4)
        var end := Vector2(w.position.x+4,w.end.y-4) if vertical else Vector2(w.end.x-4,w.position.y+4)
        draw_line(start,end,Color(0.48,0.58,0.63),2)
        for j in range(30,int(length),180):
            var p: Vector2 = w.position+(Vector2(0,j) if vertical else Vector2(j,0))
            draw_rect(Rect2(p,Vector2(w.size.x,6) if vertical else Vector2(6,w.size.y)),Color(0.045,0.075,0.09))
            draw_circle(p+Vector2(7,7),1.8,Color(0.52,0.60,0.63))
    for portal in Layout.PORTALS:
        var p: Vector2 = portal[1]
        var vertical: bool = portal[2]
        for d in [-1,1]:
            var r := Rect2(p+Vector2(-30,d*100-15),Vector2(60,30)) if vertical else Rect2(p+Vector2(d*100-15,-30),Vector2(30,60))
            draw_rect(r,Color(0.28,0.35,0.38))
            draw_rect(r.grow(-6),Color(0.08,0.12,0.15))
        draw_circle(p+(Vector2(-30,-82) if vertical else Vector2(-82,-30)),4,Color(0.72,0.06,0.02))
    # Glass and room signage stay within actual architecture.
    draw_rect(Rect2(1750,375,540,22),Color(0.20,0.52,0.62,0.35))
    for i in range(1760,2280,100): draw_line(Vector2(i,377),Vector2(i+38,392),Color(0.49,0.74,0.81,0.25),2)
    for text_pos in [["V-17 / ВОССТАНОВЛЕНИЕ",Vector2(260,710)],["B-02 → НАБЛЮДЕНИЕ",Vector2(990,525)],["C / ИССЛЕДОВАНИЯ",Vector2(1390,1720)],["D / РЕЗЕРВНЫЙ КОНТУР",Vector2(580,1830)],["КАРАНТИН",Vector2(150,2710)],["ГРУЗОВОЙ ШЛЮЗ",Vector2(2020,2690)]]:
        draw_string(ThemeDB.fallback_font,text_pos[1],text_pos[0],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.47,0.61,0.63,0.6))

func _grate(r: Rect2) -> void:
    draw_rect(r,Color(0.055,0.085,0.10))
    if r.size.x > r.size.y:
        for x in range(int(r.position.x)+4,int(r.end.x)-4,9): draw_line(Vector2(x,r.position.y+3),Vector2(x,r.end.y-3),Color(0.33,0.40,0.43),2)
    else:
        for y in range(int(r.position.y)+4,int(r.end.y)-4,9): draw_line(Vector2(r.position.x+3,y),Vector2(r.end.x-3,y),Color(0.33,0.40,0.43),2)
func _cable(points: Array, col: Color, width: float) -> void:
    draw_polyline(PackedVector2Array(points),Color(0,0,0,0.5),width+4,true)
    draw_polyline(PackedVector2Array(points),col,width,true)
func _pipe(a: Vector2, c: Vector2) -> void:
    var dir := (c-a).normalized();var n := Vector2(-dir.y,dir.x)
    for off in [-8,8]:
        draw_line(a+n*off,c+n*off,Color(0.07,0.12,0.15),7)
        draw_line(a+n*(off-2),c+n*(off-2),Color(0.39,0.47,0.50),1.5)
    for j in range(20,int(a.distance_to(c)),90):
        var p := a+dir*j
        draw_line(p-n*14,p+n*14,Color(0.24,0.32,0.36),4)
func _hazard(r: Rect2) -> void:
    draw_rect(r,Color(0.045,0.055,0.065))
    var horizontal := r.size.x>r.size.y
    for j in range(4,int(maxf(r.size.x,r.size.y))-8,24):
        var p := r.position+(Vector2(j,0) if horizontal else Vector2(0,j))
        draw_line(p,p+Vector2(10,10),Color(0.65,0.48,0.18,0.75),7)

class Damage extends Node2D:
    var b = null
    var t := 0.0
    var refresh := 0.0
    func _process(delta: float) -> void:
        t += delta
        refresh -= delta
        if refresh<=0:
            refresh=0.12
            queue_redraw()
    func _draw() -> void:
        # Static accident dressing is part of the cached architecture texture.
        if fposmod(t,6.8) < 0.16:
            for i in range(5):
                var p := Vector2(880,1310)
                draw_line(p,p+Vector2.from_angle(t*8+i)*float(8+i*5),Color(1,0.72,0.34,0.8),1.5)
