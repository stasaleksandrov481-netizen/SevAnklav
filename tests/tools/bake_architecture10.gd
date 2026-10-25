extends Node
class BakeState:
    var map_size:=Vector2(3080,2840)
    var walls: Array=[]
    var doors: Dictionary={}
func _ready() -> void:
    G.set_meta("qa8",true);G.zsave.bunker3={}
    var battle:=preload("res://scripts/bunker_story.gd").new();battle.setup({"sector_idx":0,"mission":"bunker","sector_name":"BAKE"});add_child(battle)
    await get_tree().process_frame
    var state:=BakeState.new();state.doors=battle.doors
    for wall in battle.walls:
        var is_door:=false
        for id in battle.doors:
            if battle.doors[id].wall==wall: is_door=true;break
        if not is_door: state.walls.append(wall)
    var viewport:=SubViewport.new();viewport.size=Vector2i(3080,2840);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
    var base:=preload("res://scripts/bunker/bunker_environment.gd").new();base.b=state;base.baked_floor=null;base.z_index=-10;base.process_mode=PROCESS_MODE_DISABLED;viewport.add_child(base)
    var detail:=preload("res://scripts/bunker/surface_detail.gd").new();detail.b=state;viewport.add_child(detail)
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var image:=viewport.get_texture().get_image()
    var error:=image.save_png("res://assets/bunker/v10/architecture.png")
    print("BAKE10 ",error," ",image.get_size());get_tree().quit(0 if error==OK else 1)
