extends ZMedUI.BodyDoll
const SCAN=preload("res://assets/ui/v9/anatomy.png")
const V=preload("res://scripts/ui/visual_theme.gd")
const REGIONS9={
    "head":[Vector2(.41,.02),Vector2(.59,.02),Vector2(.59,.17),Vector2(.41,.17)],
    "torso":[Vector2(.32,.18),Vector2(.68,.18),Vector2(.64,.48),Vector2(.36,.48)],
    "la":[Vector2(.29,.18),Vector2(.36,.21),Vector2(.31,.39),Vector2(.27,.58),Vector2(.17,.58),Vector2(.23,.36)],
    "ra":[Vector2(.71,.18),Vector2(.64,.21),Vector2(.69,.39),Vector2(.73,.58),Vector2(.83,.58),Vector2(.77,.36)],
    "ll":[Vector2(.36,.48),Vector2(.49,.48),Vector2(.49,.98),Vector2(.29,.98),Vector2(.35,.73)],
    "rl":[Vector2(.51,.48),Vector2(.64,.48),Vector2(.65,.73),Vector2(.71,.98),Vector2(.51,.98)]
}
func image_rect9() -> Rect2:
    var k:=minf((size.x-24)/SCAN.get_width(),size.y/SCAN.get_height())
    var extent:=SCAN.get_size()*k
    return Rect2(Vector2((size.x-extent.x)*.5,0),extent)
func polygon9(zone: String) -> PackedVector2Array:
    var r:=image_rect9();var pts:=PackedVector2Array()
    for p in REGIONS9[zone]: pts.append(r.position+p*r.size)
    return pts
func _zone_at(p: Vector2) -> String:
    for zone in REGIONS9:
        if Geometry2D.is_point_in_polygon(p,polygon9(zone)): return zone
    return ""
func _draw() -> void:
    if btl==null: return
    var r:=image_rect9();draw_texture_rect(SCAN,r,false,Color(.74,.85,.91,.78))
    var st: Dictionary=btl.player.st
    var drag=get_viewport().gui_get_drag_data() if get_viewport().gui_is_dragging() else null
    var over:=_zone_at(get_local_mouse_position())
    for zone in REGIONS9:
        var integrity: float=st.body[zone];var bleed:=false;var treated:=false
        for wound in st.wounds:
            if wound.zone==zone and int(wound.bleed)>0:
                if wound.get("tq",false) or wound.get("clamp",false): treated=true
                else: bleed=true
        var broken: bool=st.frac.has(zone)
        var col: Color=V.ALERT if bleed or integrity<.45 else (V.WARN if broken or integrity<.8 else V.ICE)
        var points:=polygon9(zone)
        var targeted: bool=over==zone
        var usable: bool=drag is Dictionary and _zone_needs(zone,st,str(drag.get("item","")))
        if integrity<.9 or bleed or broken or targeted or usable:
            draw_colored_polygon(points,Color(col.r,col.g,col.b,.22 if targeted else .10))
            var contour:=points.duplicate();contour.append(points[0]);draw_polyline(contour,Color(col.r,col.g,col.b,.8 if targeted else .35),1,true)
        var center:=Vector2.ZERO
        for p in points: center+=p
        center/=points.size()
        var left: bool=zone in ["la","ll","head"]
        var label_pos:=Vector2(0 if left else size.x-65,center.y+(28 if zone=="ra" else (-15 if zone=="torso" else 0)))
        draw_line(center,Vector2(label_pos.x+(60 if left else 0),label_pos.y),Color(col.r,col.g,col.b,.3),1,true)
        draw_string(ThemeDB.fallback_font,label_pos+Vector2(0,-5),btl.Med.ZONE_RU[zone],HORIZONTAL_ALIGNMENT_LEFT,65,10,V.MUTED)
        draw_string(ThemeDB.fallback_font,label_pos+Vector2(0,8),"%d%%"%roundi(integrity*100),HORIZONTAL_ALIGNMENT_LEFT,65,11,col)
        var icon: Texture2D=ZUI.icon("drop" if bleed else ("bone" if broken else "bandage"))
        if bleed or broken or treated:
            if icon!=null: draw_texture_rect(icon,Rect2(label_pos+Vector2(0,14),Vector2(13,13)),false,col)
