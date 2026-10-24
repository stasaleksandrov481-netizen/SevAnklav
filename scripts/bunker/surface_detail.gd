extends Node2D
const MATERIAL=preload("res://assets/bunker/v9/materials.png")
const L=preload("res://scripts/bunker/bunker_layout.gd")
var b
func _ready() -> void:
    z_index=-9
func _draw() -> void:
    if b==null: return
    var half:=MATERIAL.get_size()*.5
    for f in L.FLOOR:
        var room: Rect2=f[0];var kind: String=f[1]
        var cell:=Vector2(0,0) if kind in ["med","quarantine"] else (Vector2(0,1) if kind in ["lab","archive","observation"] else Vector2(1,0))
        var r:=room.grow(-22)
        draw_texture_rect_region(MATERIAL,r,Rect2(cell*half,half),Color(.70,.75,.79))
        # Broad sealed edging and cable trench, not a small repeated tile grid.
        draw_rect(r,Color(.07,.11,.14,.55),false,6)
        var y:=r.position.y+18
        draw_line(Vector2(r.position.x+12,y),Vector2(r.end.x-12,y),Color(.35,.49,.54,.38),1,true)
        if room.size.x>450 and room.size.y>270:
            var hatch:=Rect2(room.end-Vector2(135,100),Vector2(76,44))
            draw_style_box(preload("res://scripts/ui/visual_theme.gd").panel(Color(.11,.16,.19,.3),Color(.44,.55,.59,.45),0),hatch)
            draw_line(hatch.position+Vector2(26,20),hatch.position+Vector2(50,20),Color(.05,.08,.10),3,true)
    for wall in b.walls:
        # Door collisions are excluded: dynamic leaves keep their own animated frame.
        var portal:=false
        for id in b.doors:
            if b.doors[id].wall==wall: portal=true;break
        if portal: continue
        var vertical: bool=wall.size.y>wall.size.x
        draw_texture_rect_region(MATERIAL,wall,Rect2(half,half),Color(.58,.66,.70))
        var n:=Vector2.RIGHT if vertical else Vector2.DOWN
        var a: Vector2=wall.position+n*5;var end: Vector2=wall.end-n*5
        draw_line(a,end,Color(.48,.58,.63,.55),1.5,true)
        if maxf(wall.size.x,wall.size.y)>250:
            var start: Vector2=wall.position+(Vector2(9,30) if vertical else Vector2(30,9))
            var finish: Vector2=wall.end-(Vector2(9,30) if vertical else Vector2(30,9))
            draw_line(start,finish,Color(.025,.045,.06),5,true)
            draw_line(start-n,finish-n,Color(.35,.43,.48),1,true)
    # Floor directions and bay identifiers stay sparse and lie on the floor plane.
    for datum in [[Vector2(250,700),"V–17  /  RECOVERY"],[Vector2(1780,515),"B–02  /  SECURITY"],[Vector2(1440,1540),"C–12  /  RESEARCH"],[Vector2(680,1680),"D–04  /  POWER"],[Vector2(700,2690),"Q–05  /  ISOLATION"]]:
        draw_string(ThemeDB.fallback_font,datum[0],datum[1],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(.64,.73,.76,.4))
