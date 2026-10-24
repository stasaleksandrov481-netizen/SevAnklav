extends Node
var errors: Array=[]
var battle
func check(ok: bool,label: String) -> void:
    print("V8 ","PASS " if ok else "FAIL ",label)
    if not ok: errors.append(label)
func _ready() -> void:
    G.set_meta("qa8",true)
    G.zsave["bunker3"]={};G.zsave["pstate"]=preload("res://scripts/med.gd").mk_state()
    G.zsave["infect"]=0.0;G.zsave["weapons"]=["pistol","pistol","pm"]
    G.zsave["inv"]["pistol"]=1
    battle=preload("res://scripts/bunker_story.gd").new()
    battle.setup({"sector_idx":0,"mission":"bunker","sector_name":"ПРОВЕРКА V8"})
    battle.main_ref=self;add_child(battle)
    battle.set_meta("qa8",true)
    await get_tree().create_timer(4.2).timeout
    check(battle.player_rig6.emergence8 and battle.player_rig6.joints8["arm_l_lower"].visible,"capsule exit animates separate arm joints")
    check(battle.player["spr"].position.distance_to(Vector2(395,425))<1.0,"character does not slide while pushing lid")
    await capture("capsule_push")
    await get_tree().create_timer(2.9).timeout
    await capture("capsule_legs")
    await get_tree().create_timer(4.9).timeout
    check(not battle.starting and not battle.in_capsule,"capsule sequence completes")
    check(battle.player_rig6.recovery8==1.0 and not battle.player_rig6.emergence8,"player stands after emerging")
    var segment_scales: Dictionary={}
    for key in battle.player_rig6.joints8: segment_scales[key]=battle.player_rig6.joints8[key].scale
    var fixed_lengths:=true
    for stage in range(6):
        for sample in [0.0,0.25,0.5,0.75,1.0]:
            battle.player_rig6.exit_pose8(stage,sample)
            for key in segment_scales:
                if not battle.player_rig6.joints8[key].scale.is_equal_approx(segment_scales[key]): fixed_lengths=false
    check(fixed_lengths,"capsule limbs never stretch in any pose")
    battle.player_rig6.finish_exit8()
    check(G.zsave["weapons"].count("pistol")==1 and not G.zsave["inv"].has("pistol"),"one canonical Makarov")
    battle._story_action("cryo_terminal")
    await get_tree().create_timer(0.2).timeout
    var terminal=battle.zp_overlay_layer.get_child(0)
    check(not terminal.instant,"first terminal opening animated")
    for child in terminal.get_children():
        if child is Button: child.pressed.emit()
    await get_tree().create_timer(0.4).timeout
    var notes_before: int=battle.notes.size()
    battle._story_action("cryo_terminal")
    await get_tree().process_frame
    terminal=battle.zp_overlay_layer.get_child(0)
    check(terminal.instant,"repeat terminal opens instantly")
    await capture("terminal")
    check(battle.notes.size()==notes_before,"repeat terminal does not duplicate archive")
    for child in terminal.get_children():
        if child is Button: child.pressed.emit()
    await get_tree().create_timer(0.4).timeout
    var wall: Rect2=battle.doors["medical"]["wall"]
    await battle._open_door("medical")
    check(battle.doors["medical"]["opened"] and not battle.walls.has(wall),"door opening clears collision")
    check(not battle.doors["medical"]["pr"]["spr"].visible,"door leaf remains hidden")
    battle._complete_objective("gear");battle.loadout7.defaults()
    battle._open_inventory7("equipment")
    await get_tree().create_timer(0.5).timeout
    check(is_instance_valid(battle.inventory7),"inventory opens")
    check(battle.inventory7.get_combined_minimum_size().x<=get_viewport().get_visible_rect().size.x,"inventory fits viewport width")
    await capture("inventory")
    battle.inventory7.queue_free()
    await get_tree().create_timer(0.3).timeout
    battle._open_pause()
    await get_tree().create_timer(0.3).timeout
    check(is_instance_valid(battle.pause_win),"pause opens")
    await capture("pause")
    battle.pause_win.queue_free()
    await get_tree().create_timer(0.3).timeout
    var enemy: Dictionary=battle.zombies[0]
    battle._kill_zombie(enemy)
    await get_tree().create_timer(1.5).timeout
    check(enemy["rig5"].fallen and enemy["rig5"].fall_time>0.8,"articulated death reaches resting pose")
    battle.player["spr"].position=Vector2(710,530)
    battle._tick_player(0.1)
    await capture("bunker")
    battle.camera.zoom=Vector2(2.4,2.4)
    battle.camera.position=battle.player["spr"].position
    await capture("pose")
    var music:=preload("res://scripts/ui/menu_music.gd").new();add_child(music)
    await get_tree().create_timer(0.2).timeout
    check(music.repeat_timer.wait_time==30.0,"menu music repeat delay is 30 seconds")
    check(music.stream is AudioStreamWAV and music.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"menu track does not loop immediately")
    music.queue_free()
    print("V8 RESULT ",errors.size()," failures")
    get_tree().quit(0 if errors.is_empty() else 1)
func capture(label: String) -> void:
    if DisplayServer.get_name()=="headless": return
    await RenderingServer.frame_post_draw
    var folder: String=ProjectSettings.globalize_path("res://../qa-images")
    DirAccess.make_dir_recursive_absolute(folder)
    get_viewport().get_texture().get_image().save_png(folder+"/v8_"+label+".png")
func to_main_menu() -> void:
    pass
