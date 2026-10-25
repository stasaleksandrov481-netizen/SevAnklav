extends Node
# Automated integration route; AI is disabled to isolate story gates and collision paths.
class RouteBattle:
    extends "res://scripts/bunker_story.gd"
    func _desktop_input() -> bool: return false
var b
var passed:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
    print("STORY10 ","PASS " if ok else "FAIL ",label)
    if ok: passed+=1
    else: failures.append(label)
func wait(seconds: float) -> void: await get_tree().create_timer(seconds).timeout
func _ready() -> void:
    G.set_meta("qa8",true);G.zsave.bunker3={};G.zsave.investigation10={};G.zsave.pstate=preload("res://scripts/med.gd").mk_state();G.zsave.inv={};G.zsave.hands7=["",""];G.zsave.weapons=[];G.zsave.erase("equipment_ready7")
    b=RouteBattle.new();b.set_meta("qa8",true);b.setup({"sector_idx":0,"mission":"bunker","sector_name":"STORY10"});add_child(b)
    await wait(12.8);b.set_process(false)
    check(not b.starting and not b.in_capsule,"capsule finishes before story route")
    check(not b._door_allowed("medical") and not b._door_allowed("science") and not b._door_allowed("technical") and not b._door_allowed("cargo"),"all core gates start locked")
    await action("cryo_terminal");check(b.records.has("terminal"),"dossier unlocks medical access")
    await door("medical");await action("cams_terminal");await action("gear_table")
    check(b._obj_done("gear") and b._has_weapon7(),"equipment grants weapon and original loadout")
    await door("science");await action("exp12_video")
    check(not b._door_allowed("technical"),"one journal fragment cannot bypass access")
    await action("journal");check(b._door_allowed("technical"),"both fragments grant technical access")
    await door("technical");await action("gen_panel");check(not b.records.has("power"),"power still requires physical fuse")
    await action("fuse_crate");await action("gen_panel");check(b.records.has("power") and G.zsave.inv.get("fuse",0)==0,"fuse is consumed on restoring power")
    await action("stairs_transition");await wait(6.3)
    check(b.records.has("lower") and b.player.spr.position.distance_to(Vector2(560,2220))<2,"stairs traverse same-scale physical centerline")
    await action("iso_panel");check(not b._door_allowed("cargo"),"quarantine alone cannot bypass archive")
    await action("obs_terminal");await door("cargo")
    await action("hydro_lever");check(b.zp_gate_state==0,"drive cannot start before pump")
    await action("hydro");await action("hydro_lever");await action("power_hold")
    check(b.zp_gate_state==3,"pump drive and power sequence starts evacuation")
    b._zpro_tick(7.1);await wait(3.2)
    check(b.zp_gate_state==4,"power hold completes original seven second phase")
    await action("exit_gate");await wait(4.4)
    check(b.battle_over=="win" and b.ending,"external airlock completes first location")
    check(not b.doors.office10.opened and not b.doors.staff10.opened,"optional rooms never gate main route")
    print("STORY10 RESULT ",passed," passed / ",failures.size()," failures")
    b.queue_free();b=null;await get_tree().process_frame;await wait(.5)
    get_tree().quit(0 if failures.is_empty() else 1)
func close_terminal() -> void:
    if is_instance_valid(b.zp_overlay_layer):
        var terminal=b.zp_overlay_layer.get_child(0)
        for child in terminal.get_children():
            if child is Button and child.text.contains("ЗАКРЫТЬ"): child.pressed.emit();break
    await wait(.3)
func action(kind: String) -> void:
    var info: Dictionary=reach(kind)
    check(not info.is_empty(),"reachable interaction "+kind)
    if info.is_empty(): return
    b._do_interact(info)
    await wait(.15)
    if get_tree().paused: await close_terminal()
func door(id: String) -> void:
    var info: Dictionary=reach("door",id)
    check(not info.is_empty(),"reachable door "+id)
    if info.is_empty(): return
    b._do_interact(info);await wait(1.6)
    check(b.doors[id].opened,"unlocked physical door "+id)
func reach(kind: String,id:="") -> Dictionary:
    var target: Dictionary={}
    for prop in b.props:
        if prop.kind==kind and (id.is_empty() or prop.get("door_id","")==id): target=prop;break
    if target.is_empty(): return {}
    var source: Vector2=b.player.spr.position
    var cells: Dictionary={}
    for zone in b.Layout4.FLOOR:
        var r: Rect2=zone[0]
        for y in range(ceili(r.position.y/20),floori(r.end.y/20)+1):
            for x in range(ceili(r.position.x/20),floori(r.end.x/20)+1):
                var p:=Vector2(x*20,y*20)
                if p.distance_to(b._collide_circle(p,15))<.5: cells[Vector2i(x,y)]=true
    var start: Vector2i=Vector2i((source/20).round())
    if not cells.has(start):
        var best:=INF
        for cell in cells:
            var d: float=(Vector2(cell)*20).distance_squared_to(source)
            if d<best: start=cell;best=d
    var visited: Dictionary={start:start};var queue: Array=[start];var index:=0;var found: Dictionary={};var finish:=start
    while index<queue.size():
        var here: Vector2i=queue[index];index+=1
        var p:=Vector2(here)*20
        if p.distance_to(target.pos)<250:
            b.player.spr.position=p
            var info: Dictionary=b._find_interact()
            if (kind=="door" and info.get("door_id","")==id) or info.get("action","")==kind or (kind=="gear_table" and info.get("kind","")=="gear"):
                found=info;finish=here;break
        for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var next: Vector2i=here+delta
            if cells.has(next) and not visited.has(next): visited[next]=here;queue.append(next)
    b.player.spr.position=source
    if found.is_empty(): return {}
    var path: Array=[finish]
    while path[-1]!=start: path.append(visited[path[-1]])
    path.reverse()
    for cell in path:
        var point:=Vector2(cell)*20
        # Use the same solver as movement, including intermediate sweeps.
        var from: Vector2=b.player.spr.position
        for step in range(1,5): b.player.spr.position=b._collide_circle(from.lerp(point,step/4.0),15)
    return b._find_interact()
