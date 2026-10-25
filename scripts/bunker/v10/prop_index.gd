extends RefCounted
const STEP=128
var cells: Dictionary={}
var dynamic: Array=[]
func build(props: Array) -> void:
    cells.clear();dynamic.clear()
    for prop in props:
        if not prop.get("solid",false): continue
        if prop.kind=="exit_gate": dynamic.append(prop);continue
        var r: Rect2=prop.get("bounds7",Rect2(prop.pos-prop.get("half",Vector2(30,30)),prop.get("half",Vector2(30,30))*2))
        for y in range(floori(r.position.y/STEP),floori(r.end.y/STEP)+1):
            for x in range(floori(r.position.x/STEP),floori(r.end.x/STEP)+1):
                var key:=Vector2i(x,y)
                if not cells.has(key): cells[key]=[]
                cells[key].append(prop)
func near(point: Vector2,radius: float) -> Array:
    var result: Array=dynamic.duplicate();var seen: Dictionary={}
    for y in range(floori((point.y-radius)/STEP),floori((point.y+radius)/STEP)+1):
        for x in range(floori((point.x-radius)/STEP),floori((point.x+radius)/STEP)+1):
            for prop in cells.get(Vector2i(x,y),[]):
                var id: int=prop.spr.get_instance_id()
                if not seen.has(id): seen[id]=true;result.append(prop)
    return result
