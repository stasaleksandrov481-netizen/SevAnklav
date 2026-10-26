extends SceneTree
var checks:=0
var failures:=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=root.get_node("G"); game.set_meta("qa8",true); game.zsave=game._default_zsave()
	var map=preload("res://iso/editor/map.gd").make_blank("qa_new_map")
	var room=map.get_child(0)
	var floor_piece=room.find_child("Floor",true,false); floor_piece.dimensions=Vector3(12,0.25,10)
	var prop=load("res://iso/editor/palette/desk.tscn").instantiate(); prop.name="MovedDesk"; prop.position=Vector3(-2,0,2); room.add_child(prop); prop.owner=map
	var station=preload("res://iso/editor/station.gd").new(); station.action_id="qa_container"; station.initial_contents.append({"id":"band","count":3,"condition":100}); station.position=Vector3(2,0,2); room.add_child(station); station.owner=map
	var scene:=PackedScene.new(); check(scene.pack(map)==OK,"Blank scene packs")
	var path:="res://tests/_runtime_map_tmp.tscn"; check(ResourceSaver.save(scene,path)==OK,"Blank scene saves")
	map.free()
	var world=load("res://iso/bunker_world.tscn").instantiate(); world.set_meta("map_path",path); root.add_child(world)
	await process_frame; await physics_frame
	check(world.rooms.size()==1,"Game loads authored blank map")
	check(world.state_key=="qa_new_map","Separate map save key")
	check(not world.story_enabled and world.state.data.awake,"Free map starts without bunker story assumptions")
	check(world.player.position.distance_to(world.ORIGIN+Vector3(0,0.95,0))<0.1,"Authored player start is used")
	check(world.lights.size()==1,"Authored light is connected")
	check(world.rooms.room_start.get_node("MovedDesk").position==Vector3(-2,0,2),"Moved furniture survives save/load")
	check(world.state.loot("qa_container",0),"Authored container transfers item")
	check(world.state.amount("band")==3 and world.state.data.containers.qa_container.is_empty(),"Container state is persistent")
	var old_state=preload("res://iso/zarya/state.gd").new(game.zsave)
	check(old_state.amount("band")==0,"New map does not overwrite bunker inventory")
	print("MAP_RUNTIME_CHECKS ",checks," FAILED ",failures)
	quit(1 if failures else 0)
