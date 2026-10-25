extends Node
class MobileBattle:
    extends "res://scripts/bunker_story.gd"
    func _desktop_input() -> bool: return false
var b
var failures: Array=[]
var passed:=0
func check(ok: bool,label: String) -> void:
    print("V9 ","PASS " if ok else "FAIL ",label)
    if not ok: failures.append(label)
    else: passed+=1
func wait(seconds: float) -> void: await get_tree().create_timer(seconds).timeout
func _ready() -> void:
    G.set_meta("qa8",true)
    G.zsave.bunker3={};G.zsave.pstate=preload("res://scripts/med.gd").mk_state();G.zsave.infect=0
    G.zsave.weapons=["pistol","rifle"];G.zsave.hands7=["",""];G.zsave.inv={"band":3,"splint":1,"mag_pistol":2,"abx":1,"food":1}
    G.zsave.quick=["","","","","",""]
    b=MobileBattle.new();b.setup({"sector_idx":0,"mission":"bunker","sector_name":"QA9"});b.main_ref=self;add_child(b)
    await wait(4.2)
    check(b.player_rig6.emergence8,"capsule uses joint poses")
    var scales: Dictionary={}
    for key in b.player_rig6.joints8: scales[key]=b.player_rig6.joints8[key].scale
    await capture("capsule")
    await wait(2.4)
    await capture("capsule_open")
    await wait(6.1)
    check(not b.starting and not b.in_capsule and not b.paused,"capsule transfers control")
    check(b.player.spr.position.distance_to(b._collide_circle(b.player.spr.position,15))<4,"exit ends on clear floor")
    var lengths:=true
    for stage in range(6):
        for t in [0.0,.25,.5,.75,1.0]:
            b.player_rig6.exit_pose8(stage,t)
            for key in scales:
                if not b.player_rig6.joints8[key].scale.is_equal_approx(scales[key]): lengths=false
    b.player_rig6.finish_exit8();b.player_rig6.pose(1,4,Vector2(70,0),true,.1)
    for key in scales:
        if not b.player_rig6.joints8[key].scale.is_equal_approx(scales[key]): lengths=false
    check(lengths,"constant limb lengths in cutscene and walking")
    check(b.canvas_mod.color.r>=.25,"readable ambient floor")
    var shadows:=0
    for lamp in b.environment4.lights:
        if lamp.node.enabled and lamp.node.shadow_enabled: shadows+=1
    check(shadows<=5 and shadows>=1,"bounded local shadow lights")
    var red: Dictionary={}
    for lamp in b.environment4.lights:
        if lamp.kind=="red": red=lamp;break
    var first: float=red.node.energy
    b.environment4.phase+=1.9;b.environment4._process(.01)
    check(absf(first-red.node.energy)>.05,"alarm lamp intensity animates")
    b._complete_objective("gear");b.loadout7.defaults();b._inventory_changed7()
    b.loadout7.put_away(0);check(not b.player.light.enabled,"holstering lamp extinguishes cone")
    b.loadout7.equip("flashlight",0);b.zp.flash_off=false;b._tick_player(.016)
    check(b.player.light.enabled and b.player.light.position.distance_to(b._flash_origin7())<.01,"held lamp and cone share origin")
    b.loadout7.equip("weapon:rifle",1)
    check(b.loadout7.hands()==["weapon:rifle","weapon:rifle"] and b.loadout7.in_bag("weapon:rifle")==0,"two handed occupancy has no duplicate")
    b.loadout7.put_away(1);check(b.loadout7.hands()==["",""] and b.loadout7.in_bag("weapon:rifle")==1,"two hand holster restores single item")
    b.loadout7.equip("flashlight");b.loadout7.equip("weapon:pistol")
    check(b.loadout7.hands()==["flashlight","weapon:pistol"],"left then right hands")
    b.player.mag=5;b.player.reload_t=0;b.player.fire_cd=0
    b._start_ammo_check();var mag: int=b.player.mag;b._fire_player()
    check(b.player.mag==mag,"inspection does not discharge weapon")
    b._tick_ammo_check(1.1)
    check(b.ammo_result9>0 and b.ammo_text9.begins_with("Около") and b._ammo_result_t<=0,"approximate ammo check replaces old HUD")
    b._start_ammo_check();b.loadout7.put_away(1);b._tick_ammo_check(.1)
    check(b.ammo_check9<=0 and b.ammo_result9<=0,"inspection cancels on weapon change")
    b.loadout7.equip("weapon:pistol",1)
    b._open_inventory7("equipment");await wait(.3)
    var screen=b.inventory7
    check(is_instance_valid(screen),"new equipment screen opens")
    check(screen.get_combined_minimum_size().x<=get_viewport().get_visible_rect().size.x,"inventory fits viewport")
    b._assign_quick(2,"band")
    var fresh:=false
    for cell in screen.cells:
        if cell.place=="quick" and cell.index==2: fresh=cell.item=="band"
    check(fresh and b.quick_slots[2].item=="band","shortcut updates both views immediately")
    var zone=screen.b._med_doll
    var rr: Rect2=zone.image_rect9()
    check(zone._zone_at(rr.position+rr.size*Vector2(.5,.09))=="head","anatomy head hit region")
    check(zone._zone_at(rr.position+rr.size*Vector2(.5,.32))=="torso","anatomy torso hit region")
    b.player.st.body.la=.5;var count: int=G.zsave.inv.band
    zone._drop_data(rr.position+rr.size*Vector2(.27,.4),{"kind":"med_item","item":"band"})
    check(G.zsave.inv.band==count-1 and b.player.st.body.la>.5,"anatomical drag applies original medicine")
    screen.show_item9("band");await capture("inventory")
    screen.select_page("health");await capture("health")
    screen.select_page("tasks");check(screen.extras.get_child_count()>0,"task tab retains content")
    screen.select_page("records");check(screen.extras.get_child_count()>0,"records tab retains content")
    screen._close();await wait(.3)
    check(not b.paused and not is_instance_valid(b.inventory7),"closing inventory releases controls")
    var feed=b.story_feed6
    feed.pending.clear();feed.active={};feed.remaining=0;feed.push("Найден предмет","ХАБАР");feed._process(.01)
    feed.push("Укус. Кровотечение левой руки.")
    check(feed.remaining==0 and feed.pending[0].priority==3,"critical injury preempts pickup")
    feed._process(.01);check(feed.active.priority==3,"priority event becomes active")
    var queued: int=feed.pending.size();feed.push("Укус. Кровотечение левой руки.")
    check(feed.pending.size()==queued,"duplicate notifications coalesce")
    check(feed.classify("Доступ запрещён").priority==2 and feed.classify("Бинт применён").icon=="bandage","typed notification accents")
    b.player.spr.position=Vector2(710,530);b.camera.position=b.player.spr.position;await wait(.4);await capture("hud")
    check(b.mm_ref.size.x<=240 and b.quick_panel_ref.size.y<=80,"compact map and quick bar")
    var action_rect:=Rect2(b.action5.position,b.action5.size)
    check(not action_rect.intersects(Rect2(b._stick_base("r")-Vector2(90,90),Vector2(180,180))),"action target clears aim joystick")
    await b._open_door("medical");check(not b.walls.has(b.doors.medical.wall),"door clears physical wall")
    b.player.spr.position=Vector2(560,1805);b.camera.position=b.player.spr.position
    var scale: Vector2=b.player_rig6.scale;b._descend();await wait(6.3)
    check(b.records.has("lower") and not b.paused,"stair traversal completes story objective")
    check(b.player.spr.position.distance_to(Vector2(560,2220))<2 and b.player_rig6.scale==scale,"stairs preserve position and scale")
    var stair_clear:=true
    for y in range(1930,2220,15):
        if b._collide_circle(Vector2(560,y),15).distance_to(Vector2(560,y))>.5: stair_clear=false
    check(stair_clear,"stair centerline stays passable")
    b.player.spr.position=Vector2(570,2050);b.camera.position=b.player.spr.position;await wait(.4);await capture("stairs")
    b.loadout7.put_away(0);b.loadout7.put_away(1)
    var touch:=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=b._stick_base("l")+Vector2(20,0);b._unhandled_input(touch)
    var aim:=InputEventScreenTouch.new();aim.index=1;aim.pressed=true;aim.position=b._stick_base("r")+Vector2(45,0);b._unhandled_input(aim)
    b._tick_player(.016)
    check(b._stick_move_idx==0 and b._stick_aim_idx==1 and b.manual_aim,"independent multitouch sticks")
    check(not b.manual_fire and not b.aim_rig4.visible,"unarmed touch turns without gun sight")
    touch.pressed=false;aim.pressed=false;b._unhandled_input(touch);b._unhandled_input(aim)
    check(b._stick_move_idx<0 and b._stick_aim_idx<0 and b.direct_vec==Vector2.ZERO,"touch release clears both sticks")
    for id in b.doors:
        if not b.doors[id].opened: await b._open_door(id)
    validate_routes()
    for extent in [Vector2i(1280,720),Vector2i(1920,900),Vector2i(2160,1080)]:
        get_tree().root.content_scale_size=extent
        get_tree().root.size=extent
        await get_tree().process_frame
        b._open_inventory7("equipment");await wait(.25)
        var window=b.inventory7
        check(window.get_combined_minimum_size().x<=get_viewport().get_visible_rect().size.x,"inventory width "+str(extent))
        await capture("inventory_"+str(extent.x))
        window._close();await wait(.2)
    print("V9 RESULT ",passed," passed / ",failures.size()," failures")
    var report:=FileAccess.open("res://../v9-results.txt",FileAccess.WRITE);report.store_string("%d passed; %d failed\n%s"%[passed,failures.size(),str(failures)]);report.close()
    b.queue_free();await get_tree().process_frame;await get_tree().process_frame
    get_tree().quit(0 if failures.is_empty() else 1)
func capture(label: String) -> void:
    if DisplayServer.get_name()=="headless": return
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://../qa-images")
    get_viewport().get_texture().get_image().save_png("res://../qa-images/v9_"+label+".png")
func to_main_menu() -> void: pass

func validate_routes() -> void:
    var open: Dictionary={}
    var layout=preload("res://scripts/bunker/bunker_layout.gd")
    for floor_zone in layout.FLOOR:
        var r: Rect2=floor_zone[0]
        for y in range(ceili(r.position.y/24.0),floori(r.end.y/24.0)+1):
            for x in range(ceili(r.position.x/24.0),floori(r.end.x/24.0)+1):
                var p:=Vector2(x*24,y*24)
                if p.distance_to(b._collide_circle(p,15))<.5: open[Vector2i(x,y)]=true
    var source:=Vector2i(30,22)
    var visited: Dictionary={source:true};var queue: Array=[source];var index:=0
    while index<queue.size():
        var cell: Vector2i=queue[index];index+=1
        for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var next: Vector2i=cell+step
            if open.has(next) and not visited.has(next): visited[next]=true;queue.append(next)
    var targets: Array=["cryo_terminal","cams_terminal","gear_table","exp12_video","journal","fuse_crate","gen_panel","stairs_transition","iso_panel","obs_terminal","hydro","hydro_lever","power_hold","exit_gate"]
    for prop in b.props:
        if not targets.has(prop.kind): continue
        var reachable:=false
        for cell in visited:
            var point:=Vector2(cell)*24
            if point.distance_to(prop.pos)>260: continue
            if b.PropGeometry7.distance_to(prop,point)<75: reachable=true;break
        check(reachable,"walkable route to "+prop.kind)
