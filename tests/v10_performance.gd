extends Node
var b
func _ready() -> void:
    G.set_meta("qa8",true);G.zsave.bunker3={};G.zsave.investigation10={};G.zsave.pstate=preload("res://scripts/med.gd").mk_state()
    b=preload("res://scripts/bunker_story.gd").new();b.set_meta("qa8",true);b.setup({"sector_idx":0,"mission":"bunker","sector_name":"PERF10"});add_child(b)
    await get_tree().create_timer(13).timeout
    b.q_lock=true;b.q_level=1
    for position in [Vector2(630,530),Vector2(1850,1470)]:
        b.player.spr.position=position;b.camera.position=position;b.camera.reset_smoothing();b.camera.force_update_scroll()
        await get_tree().create_timer(.5).timeout
        var samples: Array=[];var draws: Array=[];var nodes: Array=[]
        for i in range(90):
            var start:=Time.get_ticks_usec();await get_tree().process_frame
            samples.append((Time.get_ticks_usec()-start)/1000.0)
            draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
            nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
        samples.sort();draws.sort();nodes.sort()
        print("PERF10 SCENE ",position," median_ms=",samples[45]," p95_ms=",samples[85]," draw_calls=",draws[45]," nodes=",nodes[45])
    var points: Array=[]
    for i in range(1600): points.append(Vector2(150+(i*137)%2750,200+(i*193)%2500))
    for indexed in [false,true]:
        b.indexed10=indexed
        var start:=Time.get_ticks_usec()
        for point in points: b._collide_circle(point,15)
        print("PERF10 COLLISION indexed=",indexed," queries=1600 ms=",(Time.get_ticks_usec()-start)/1000.0)
    b.indexed10=true
    # Three camera frames reuse the actual map, workstation atlas and character sprites.
    b._show_document10(b.investigation10.Data.ENTRIES.camera_17)
    await get_tree().create_timer(.4).timeout
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("res://../qa-images-v10/camera_archive.png")
    for child in b.ui_layer.get_children():
        if child.get_script()==preload("res://scripts/ui/v10/document_reader.gd"): child._close()
    await get_tree().create_timer(.3).timeout
    b.queue_free();await get_tree().process_frame;await get_tree().create_timer(.3).timeout
    get_tree().quit()
