@tool
extends Node3D
@export var map_id := "zarya2"
@export var title := "Бункер Заря / уровень −2"
func _ready() -> void:
	if not Engine.is_editor_hint() and get_parent()==get_tree().root: call_deferred("preview")
func preview() -> void:
	# F6 runs the saved scene using the real level controller, in a separate test save.
	var game=get_node("/root/G"); game.set_meta("qa8",true); game.zsave=game._default_zsave()
	var world=load("res://iso/bunker_world.tscn").instantiate()
	world.set_meta("map_path",scene_file_path)
	get_tree().root.add_child(world)
	queue_free()

@export var story_enabled := true
static func make_blank(id: String) -> Node3D:
	var map=load("res://iso/editor/map.gd").new(); map.name="Новая_локация"; map.map_id=id; map.title="Новая локация"; map.story_enabled=false
	var region=preload("res://iso/editor/region.gd").new(); region.name="Комната"; region.room_id="room_start"; region.width=12; region.depth=10; map.add_child(region)
	var pieces: Array=[[Vector3(12,0.18,10),Vector3(0,-0.09,0),"Floor"],[Vector3(12,2.8,0.2),Vector3(0,1.4,-5),"Wall"],[Vector3(12,2.8,0.2),Vector3(0,1.4,5),"Wall"],[Vector3(0.2,2.8,10),Vector3(-6,1.4,0),"Wall"],[Vector3(0.2,2.8,10),Vector3(6,1.4,0),"Wall"]]
	for spec in pieces:
		var p=preload("res://iso/editor/piece.gd").new(); p.name=spec[2]; p.dimensions=spec[0]; p.position=spec[1]; p.kind=spec[2]; region.add_child(p,true); p.owner=map
	var lamp=preload("res://iso/editor/lamp.gd").new(); lamp.position=Vector3(0,2.1,-4.65); region.add_child(lamp); lamp.owner=map
	var start=preload("res://iso/editor/player_start.gd").new(); start.name="Старт_игрока"; start.position=Vector3(0,0.95,0); region.add_child(start); start.owner=map; region.owner=map
	return map
