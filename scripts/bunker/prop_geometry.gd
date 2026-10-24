extends RefCounted
# One silhouette drives body collision, sight, projectile hits and light occlusion.
static var contours: Dictionary={}
static func _area(poly: PackedVector2Array) -> float:
    var total:=0.0
    for i in range(poly.size()): total+=poly[i].cross(poly[(i+1)%poly.size()])
    return absf(total)*0.5
static func build(prop: Dictionary) -> void:
    var spr: Sprite2D=prop["spr"]
    if spr.texture==null: return
    var key:=str(spr.texture.get_rid().get_id())+str(spr.texture.get_size())
    if spr.texture is AtlasTexture: key+=str(spr.texture.region)
    var contour:=PackedVector2Array()
    if contours.has(key): contour=contours[key]
    else:
        var image:=spr.texture.get_image()
        if image==null: return
        if image.is_compressed(): image.decompress()
        var bitmap:=BitMap.new()
        bitmap.create_from_image_alpha(image,0.45)
        var options:=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),maxf(2.0,image.get_size().length()*0.004))
        var largest:=0.0
        for option in options:
            var area:=_area(option)
            if area>largest: largest=area;contour=option
        contours[key]=contour
    if contour.size()<3: return
    var local:=PackedVector2Array()
    for point in contour:
        var q: Vector2=point-spr.texture.get_size()*0.5+spr.offset
        if spr.flip_h: q.x=-q.x
        if spr.flip_v: q.y=-q.y
        local.append(q)
    prop["shape_local7"]=local
    prop["shape_transform7"]=Transform2D(0,Vector2.INF)
    update(prop)
    # Grounding follows the silhouette instead of stretching an unrelated shadow blob.
    var contact:=Polygon2D.new()
    contact.polygon=local
    contact.position=Vector2(1.5,2.0).rotated(-spr.rotation)/spr.scale
    contact.color=Color(0,0,0,0.18)
    contact.show_behind_parent=true
    contact.z_index=-1
    spr.add_child(contact)
    var tall: bool=prop["kind"] in ["cabinet","wall_storage","server","wall_server","generator","capsule","exp12_capsule","ventplant","shelf"]
    prop["blocks_view7"]=tall
    if prop["solid"] or tall:
        var occ:=LightOccluder2D.new()
        var poly:=OccluderPolygon2D.new();poly.polygon=local
        occ.occluder=poly
        occ.sdf_collision=false
        spr.add_child(occ)
        prop["occluder7"]=occ
static func update(prop: Dictionary) -> void:
    if not prop.has("shape_local7"): return
    var spr: Sprite2D=prop["spr"]
    var transform: Transform2D=spr.transform
    if transform==prop["shape_transform7"]: return
    prop["shape_transform7"]=transform
    var world:=PackedVector2Array()
    for point in prop["shape_local7"]: world.append(transform*point)
    prop["shape7"]=world
    var bounds:=Rect2(world[0],Vector2.ZERO)
    for point in world: bounds=bounds.expand(point)
    prop["bounds7"]=bounds
static func nearest(poly: PackedVector2Array, point: Vector2) -> Vector2:
    var best:=Vector2.INF
    var distance:=INF
    for i in range(poly.size()):
        var q:=Geometry2D.get_closest_point_to_segment(point,poly[i],poly[(i+1)%poly.size()])
        var d:=point.distance_squared_to(q)
        if d<distance: distance=d;best=q
    return best
static func distance_to(prop: Dictionary, point: Vector2) -> float:
    update(prop)
    if not prop.has("shape7"): return point.distance_to(prop["pos"])
    var poly: PackedVector2Array=prop["shape7"]
    return 0.0 if Geometry2D.is_point_in_polygon(point,poly) else point.distance_to(nearest(poly,point))
static func _circle_clear(poly: PackedVector2Array, point: Vector2, radius: float) -> bool:
    return not Geometry2D.is_point_in_polygon(point,poly) and point.distance_squared_to(nearest(poly,point))>=radius*radius-0.001
static func push_out(prop: Dictionary, point: Vector2, radius: float) -> Vector2:
    update(prop)
    if not prop.has("shape7") or not prop["bounds7"].grow(radius).has_point(point): return point
    var poly: PackedVector2Array=prop["shape7"]
    if _circle_clear(poly,point,radius): return point
    var closest:=nearest(poly,point)
    var inside:=Geometry2D.is_point_in_polygon(point,poly)
    var normal:=((closest-point) if inside else (point-closest)).normalized()
    var candidate:=closest+normal*(radius+0.12)
    if normal.length_squared()>0.01 and _circle_clear(poly,candidate,radius): return candidate
    # Concave notches can be narrower than the player's diameter. Pick the nearest
    # valid offset edge, rather than alternating between two overlapping walls.
    var bounds: Rect2=prop["bounds7"]
    var options: Array[Vector2]=[Vector2(bounds.position.x-radius-0.12,point.y),Vector2(bounds.end.x+radius+0.12,point.y),Vector2(point.x,bounds.position.y-radius-0.12),Vector2(point.x,bounds.end.y+radius+0.12)]
    for i in range(poly.size()):
        var a:=poly[i];var c:=poly[(i+1)%poly.size()]
        var direction: Vector2=(c-a).orthogonal().normalized()
        if Geometry2D.is_point_in_polygon((a+c)*0.5+direction*0.25,poly): direction=-direction
        var q:=Geometry2D.get_closest_point_to_segment(point,a,c)
        options.append(q+direction*(radius+0.12))
    var best:=Vector2.INF
    var distance:=INF
    for option in options:
        var d:=point.distance_squared_to(option)
        if d<distance and _circle_clear(poly,option,radius): best=option;distance=d
    return best if best!=Vector2.INF else point
static func segment_entry(prop: Dictionary, a: Vector2, b: Vector2) -> Vector2:
    update(prop)
    if not prop.has("shape7"): return Vector2.INF
    var poly: PackedVector2Array=prop["shape7"]
    if Geometry2D.is_point_in_polygon(a,poly): return a
    var best:=Vector2.INF
    var distance:=INF
    for i in range(poly.size()):
        var hit=Geometry2D.segment_intersects_segment(a,b,poly[i],poly[(i+1)%poly.size()])
        if hit!=null:
            var d:=a.distance_squared_to(hit)
            if d<distance: best=hit;distance=d
    return best
