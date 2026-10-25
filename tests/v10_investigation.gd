extends Node
class MobileBattle:
    extends "res://scripts/bunker_story.gd"
    func _desktop_input() -> bool: return false
var b
var failures: Array=[]
var passed:=0
var restarted:=false
func check(ok: bool,label: String) -> void:
    print("V10 ","PASS " if ok else "FAIL ",label)
    if ok: passed+=1
    else: failures.append(label)
func wait(seconds: float) -> void: await get_tree().create_timer(seconds).timeout
func fresh() -> void:
    G.set_meta("qa8",true);G.zsave.bunker3={};G.zsave.investigation10={};G.zsave.pstate=preload("res://scripts/med.gd").mk_state();G.zsave.infect=0
    G.zsave.weapons=["pistol","rifle"];G.zsave.inv={"band":4,"food":1,"splint":1,"mag_pistol":2};G.zsave.hands7=["",""];G.zsave.quick=["","","","","",""]
func spawn() -> void:
    b=MobileBattle.new();b.set_meta("qa8",true);b.setup({"sector_idx":0,"mission":"bunker","sector_name":"QA V10"});b.main_ref=self;add_child(b)
func _ready() -> void:
    fresh();spawn();await wait(4.3);await capture("capsule_awake");await wait(2.5);await capture("capsule_open");await wait(6)
    check(not b.starting and not b.in_capsule,"capsule gives control")
    check(b.props.size()>100,"functional furnished rooms")
    check(b.doors.has("staff10") and b.doors.has("office10"),"optional rooms have physical doors")
    var uniform:=true
    for sprite in b.player_rig6.parts.values():
        if not is_equal_approx(sprite.scale.x,sprite.scale.y): uniform=false
    for sprite in b.player_rig6.joints8.values():
        if not is_equal_approx(sprite.scale.x,sprite.scale.y): uniform=false
    check(uniform,"character modules use uniform authored scale")
    var scales: Dictionary={}
    for key in b.player_rig6.joints8: scales[key]=b.player_rig6.joints8[key].scale
    for angle in range(16):
        b.player_rig6.pose(angle*TAU/16,angle*.3,Vector2(80,0),true,.1)
        for key in scales:
            if scales[key]!=b.player_rig6.joints8[key].scale: uniform=false
    check(uniform,"turning and gait never stretch limbs")
    b._complete_objective("gear");b.loadout7.defaults();b.loadout7.changed()
    b._open_pause();await wait(.3)
    check(get_tree().paused and b.paused,"pause freezes SceneTree")
    var at: float=b.time_alive;var lamp: float=b.environment4.phase;var position: Vector2=b.camera.position
    var fire: float=b.player.fire_cd;b.player.reload_t=.8
    await capture("pause");await wait(.5)
    check(b.time_alive==at and b.environment4.phase==lamp and b.camera.position==position and b.player.reload_t==.8,"world clocks lighting camera reload stay frozen")
    b.pause_win.settings();await wait(.2)
    var settings=b.ui_layer.get_child(b.ui_layer.get_child_count()-1)
    check(settings.active=="Звук","settings open independently in pause")
    settings.select_page("Изображение");settings.set_pref("brightness",1.12)
    check(is_equal_approx(float(G.zsave.bunker_visual.brightness),1.12),"settings update persistent preferences")
    settings.select_page("Управление");settings.select_page("Дополнительно");await capture("settings")
    settings._close();await wait(.2)
    check(get_tree().paused and b.paused,"closing settings keeps underlying pause")
    b.pause_win.resume();await wait(.25)
    check(not get_tree().paused and not b.paused,"resume releases world after fade")
    b.player.reload_t=0
    b.investigation10.discover("guard_shift");await wait(.2)
    check(b.investigation10.state.found.has("guard_shift") and get_tree().paused,"paper discovery persists and opens reader")
    await capture("document");await close_documents()
    var before: int=b.investigation10.state.found.size();b.investigation10.discover("guard_shift",false)
    check(b.investigation10.state.found.size()==before,"rereading never duplicates archive entries")
    b.investigation10.discover("levin_early",false);b.investigation10.discover("pay_message",false)
    b.investigation10.discover("stable_report",false);b.investigation10.discover("camera_17",false)
    check(b.investigation10.unread()>=4,"unread record markers are tracked")
    b._open_inventory7("records");await wait(.25)
    var archive=b.inventory7.extras.get_child(0)
    check(archive.entries.size()>=5 and archive.categories.get_child_count()==7,"archive categories include all material types")
    archive.select_category(0);archive.show_entry(b.investigation10.entries().filter(func(entry): return entry.id=="levin_early")[0])
    check(b.investigation10.state.read.has("levin_early"),"reading archive clears unread state")
    await capture("archive");b.inventory7._close();await wait(.2)
    b._do_interact({"kind":"story_door","door_id":"office10","pos":Vector2(2380,810)})
    await wait(.2)
    var keypad=b.ui_layer.get_child(b.ui_layer.get_child_count()-1)
    for digit in ["1","1","1","1","ВВОД"]: keypad.enter(digit)
    check(not b.records.get("office_unlocked10",false),"incorrect code preserves office lock")
    await capture("keypad")
    for digit in ["0","4","1","2","ВВОД"]: keypad.enter(digit)
    await wait(1.8)
    check(b.doors.office10.opened and not get_tree().paused,"correct code opens optional office without lingering pause")
    var band: int=G.zsave.inv.band;var food: int=G.zsave.inv.food
    b.investigation10.act("cache10");await wait(.15);keypad=b.ui_layer.get_child(b.ui_layer.get_child_count()-1)
    for digit in ["0","4","1","2","ВВОД"]: keypad.enter(digit)
    await wait(.3);await close_documents()
    check(G.zsave.inv.band==band+1 and G.zsave.inv.food==food+2,"optional cache grants original inventory items")
    b.investigation10.act("cache10");await wait(.2);await close_documents()
    check(G.zsave.inv.band==band+1 and G.zsave.inv.food==food+2,"cache is not farmable")
    b.investigation10.act("restore10")
    check(not b.investigation10.state.get("recovered",false),"archive recovery requires carrier")
    b.investigation10.discover("carrier",false);b.investigation10.act("restore10")
    check(not b.investigation10.state.get("recovered",false),"carrier does not bypass main power objective")
    b.records["power"]=true;b.investigation10.act("restore10");await wait(.2);await close_documents()
    check(b.investigation10.state.found.has("raw_signal") and b.investigation10.state.get("recovered",false),"carrier plus power recover hidden original data")
    for id in ["monitor10","tray10","override10"]:
        b.investigation10.act(id);await wait(.15);await close_documents()
    check(b.investigation10.state.inspected.size()==3 and b.investigation10.state.found.has("incident"),"three inspected traces produce a new conclusion")
    var conclusion_count: int=b.investigation10.state.found.size();b.investigation10.inspect("monitor10");await wait(.15);await close_documents()
    check(b.investigation10.state.found.size()==conclusion_count,"repeat inspection does not duplicate conclusion")
    b.records["cameras"]=true;b.investigation10.tick(.3)
    check(b.investigation10.state.get("map_ready",false) and b.investigation10.state.known_rooms.size()<b.Layout4.FLOOR.size(),"navigation reveals only visited rooms")
    var loot: Dictionary={"loot_items":["band","food"],"pos":b.player.spr.position}
    b._open_loot_window("ОБЫСК: GUARD",loot);await wait(.2)
    check(not b.loot_win.title.contains("GUARD"),"loot uses Russian identity labels")
    band=G.zsave.inv.band;b.loot_win.transfer("band",b.loot_win.source_box.global_position);await wait(.4)
    check(G.zsave.inv.band==band+1 and not loot.loot_items.has("band"),"loot transfer changes source and bag once")
    await capture("loot");b.loot_win._close();await wait(.2)
    check(not b.paused and not get_tree().paused,"loot close restores controls")
    b._open_inventory7("equipment");await wait(.2)
    b._assign_quick(0,"band");var equipped:=false
    for cell in b.inventory7.cells:
        if cell.place=="quick" and cell.index==0: equipped=cell.item=="band"
    check(equipped and b.quick_slots[0].item=="band","inventory shortcuts refresh in both panels")
    for viewport_size in [Vector2i(1280,720),Vector2i(1920,900),Vector2i(2160,1080)]:
        get_tree().root.content_scale_size=viewport_size;get_tree().root.size=viewport_size
        await wait(.1)
        var panel=b.inventory7
        check(panel.card.size.x<=panel.size.x-20 and panel.card.size.y<=panel.size.y-20,"bounded equipment viewport "+str(viewport_size))
        check(panel.medical.get_combined_minimum_size().y<=panel.body_row.size.y+2,"medical column fits height "+str(viewport_size))
        await capture("inventory_"+str(viewport_size.x))
    b.inventory7._close();await wait(.2)
    await validate_paths()
    for view in [["staff_room",Vector2(830,1000)],["office",Vector2(2560,850)],["laboratory",Vector2(1850,1470)],["technical",Vector2(750,1480)]]:
        b.player.spr.position=view[1];b.camera.position=view[1];b.camera.reset_smoothing();b.camera.force_update_scroll();b._cull_offscreen();await wait(.7)
        var visible_props:=0
        for prop in b.props:
            if prop.kind=="detail10" and prop.pos.distance_to(view[1])<200 and prop.spr.visible: visible_props+=1
        check(visible_props>0,"furnished room survives culling "+str(view[0]))
        await capture(view[0])
    b._save_checkpoint();var snapshot: Dictionary=G.zsave.bunker3.duplicate(true)
    var checkpoint_band: int=snapshot.inventory10.inv.band
    b.investigation10.state.found.append("cargo_note");G.zsave.inv.band+=3;b.records["transient10"]=true
    check(not snapshot.records.has("transient10") and not snapshot.investigation10.found.has("cargo_note"),"checkpoint owns independent deep data")
    var serialized=JSON.parse_string(JSON.stringify(snapshot))
    check(serialized is Dictionary and serialized.inventory10.inv.band==checkpoint_band,"checkpoint survives JSON disk round trip")
    b._reload_checkpoint10()
    check(restarted and G.zsave.inv.band==checkpoint_band and not G.zsave.investigation10.found.has("cargo_note"),"checkpoint reload restores inventory and discoveries together")
    b.queue_free();await get_tree().process_frame;await get_tree().process_frame
    spawn();await wait(.5)
    check(not b.starting and b.doors.office10.opened and b.investigation10.state.found.has("incident"),"fresh scene restores current checkpoint and optional doors")
    check(not b.records.has("transient10"),"transient story data do not leak into checkpoint")
    # Load a v9-style checkpoint which has no optional-system fields.
    var old: Dictionary=snapshot.duplicate(true)
    old.erase("inventory10");old.erase("investigation10");old.erase("props10")
    G.zsave.bunker3=old;G.zsave.investigation10={}
    b.queue_free();await get_tree().process_frame;await get_tree().process_frame
    spawn();await wait(.5)
    check(not b.starting and b.records.has("power"),"v9 checkpoint migrates without losing primary story")
    check(b.investigation10.state.found.is_empty(),"old saves start optional discovery safely")
    await capture("medical")
    b._show_document10(b.investigation10.Data.ENTRIES.camera_17);await wait(.25)
    var reader=b.ui_layer.get_child(b.ui_layer.get_child_count()-1)
    var cameras=reader.find_children("","Control",true,false).filter(func(node): return node.get_script()==preload("res://scripts/ui/v10/camera_archive.gd"))
    check(cameras.size()==1,"camera record contains authored archive viewer")
    if not cameras.is_empty():
        var tap:=InputEventMouseButton.new();tap.button_index=MOUSE_BUTTON_LEFT;tap.pressed=true
        cameras[0]._gui_input(tap);check(cameras[0].frame==1,"camera archive cycles original scene frames")
    await capture("camera_archive");await close_documents()
    print("V10 RESULT ",passed," passed / ",failures.size()," failures")
    var file:=FileAccess.open("res://../v10-results.txt",FileAccess.WRITE);file.store_string("%d passed / %d failed\n%s"%[passed,failures.size(),str(failures)]);file.close()
    b.queue_free();b=null;await get_tree().process_frame;await wait(.5);get_tree().quit(0 if failures.is_empty() else 1)
func close_documents() -> void:
    for child in b.ui_layer.get_children():
        if child.get_script()==preload("res://scripts/ui/v10/document_reader.gd"): child._close()
    await wait(.22)
func capture(label: String) -> void:
    if DisplayServer.get_name()=="headless": return
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://../qa-images-v10")
    get_viewport().get_texture().get_image().save_png("res://../qa-images-v10/"+label+".png")
func start_zbattle() -> void: restarted=true
func to_main_menu() -> void: pass
func validate_paths() -> void:
    for id in b.doors:
        if not b.doors[id].opened: await b._open_door(id)
    var cells: Dictionary={}
    for zone in b.Layout4.FLOOR:
        var r: Rect2=zone[0]
        for y in range(ceili(r.position.y/20),floori(r.end.y/20)+1):
            for x in range(ceili(r.position.x/20),floori(r.end.x/20)+1):
                var point:=Vector2(x*20,y*20)
                if point.distance_to(b._collide_circle(point,15))<.5: cells[Vector2i(x,y)]=true
    var start:=Vector2i(35,26);var visited: Dictionary={start:true};var queue: Array=[start];var index:=0
    while index<queue.size():
        var here: Vector2i=queue[index];index+=1
        for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var next: Vector2i=here+delta
            if cells.has(next) and not visited.has(next): visited[next]=true;queue.append(next)
    for prop in b.props:
        if prop.kind!="evidence10" and prop.kind not in ["cryo_terminal","cams_terminal","gear_table","exp12_video","journal","fuse_crate","gen_panel","stairs_transition","iso_panel","obs_terminal","hydro","hydro_lever","power_hold","exit_gate"]: continue
        var reached:=false
        for cell in visited:
            var point:=Vector2(cell)*20
            if point.distance_to(prop.pos)>260: continue
            if (point.distance_to(prop.pos)<65 if prop.kind=="evidence10" else b.PropGeometry7.distance_to(prop,point)<75): reached=true;break
        check(reached,"physical route "+str(prop.get("id10",prop.kind)))
    var matching:=true
    for prop in b.props:
        if not prop.solid or not prop.has("shape7"): continue
        for sample in [prop.pos,prop.bounds7.position+Vector2(2,2)]:
            var indexed: Vector2=b._collide_circle(sample,15)
            b.indexed10=false;var reference: Vector2=b._collide_circle(sample,15);b.indexed10=true
            if indexed.distance_to(reference)>.05: matching=false
    check(matching,"spatial collision index matches full scan")
