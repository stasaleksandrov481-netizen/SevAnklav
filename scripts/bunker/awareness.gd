extends Node2D
const Layout = preload("res://scripts/bunker/bunker_layout.gd")
var b
var timer := 0.0
var explored: Array[Vector2] = []
var dim: Array[float] = [0.0,0.5,0.5,0.5,0.5,0.5]
var reachable := {0:true}
var veil: Polygon2D
func _ready() -> void:
    z_index = 28
    var unlit := CanvasItemMaterial.new()
    unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    material = unlit
    veil = Polygon2D.new()
    veil.polygon=PackedVector2Array([Vector2.ZERO,Vector2(3080,0),Vector2(3080,2840),Vector2(0,2840)])
    var mat := ShaderMaterial.new()
    mat.shader=preload("res://assets/bunker/v5/awareness.gdshader")
    veil.material=mat
    add_child(veil)
func clear_view(a: Vector2, p: Vector2) -> bool:
    for wall in b.walls:
        # The observation bay is safety glass: vision, never physical access.
        if wall == Rect2(1750,375,540,30): continue
        if b._seg_rect_hit(a,p,wall): return false
    for prop in b.props:
        if prop.get("blocks_view7",false) and b.PropGeometry7.segment_entry(prop,a,p)!=Vector2.INF: return false
    return true
func sees(p: Vector2) -> bool:
    var a: Vector2 = b.player["spr"].position
    var d := p-a
    return d.length()<850 and (d.length()<65 or d.normalized().dot(Vector2.from_angle(b.player["aim"]))>0.08) and clear_view(a,p)
func _process(delta: float) -> void:
    if b==null or b.player.is_empty(): return
    var pos: Vector2 = b.player["spr"].position
    veil.material.set_shader_parameter("observer",pos)
    veil.material.set_shader_parameter("facing",Vector2.from_angle(b.player["aim"]))
    for i in range(dim.size()): dim[i]=move_toward(dim[i],0.0 if reachable.has(i) else 0.48,delta*0.8)
    timer-=delta
    if timer<=0:
        timer=0.10
        reachable={0:true}
        var links := [["medical",0,1],["science",1,2],["technical",2,3],["lower",3,4],["cargo",4,5]]
        for link in links:
            if reachable.has(link[1]) and b.doors[link[0]]["opened"]: reachable[link[2]]=true
        if explored.is_empty() or explored[-1].distance_to(pos)>42: explored.append(pos)
        if explored.size()>900: explored.remove_at(0)
    # Cull may run in the base this frame; visibility is resolved afterwards here.
    for z in b.zombies+b.allies:
        if not z["alive"]: continue
        var spr: Sprite2D=z["spr"]
        var seen := sees(spr.position)
        z["view_alpha"]=move_toward(float(z.get("view_alpha",0.0)),1.0 if seen else 0.0,delta*9)
        spr.visible=false
        if z.has("rig5"):
            z["rig5"].visible=float(z["view_alpha"])>0.01
            z["rig5"].modulate.a=z["view_alpha"]
    if b.safe_figure!=null: b.safe_figure.visible=false
    if is_instance_valid(b.figure_rig5):
        b.figure_rig5.visible=sees(b.safe_figure.position)
    queue_redraw()
func _draw() -> void:
    for f in Layout.FLOOR:
        var alpha := dim[int(f[2])]
        if alpha>0.001: draw_rect(f[0],Color(0.005,0.012,0.02,alpha))
