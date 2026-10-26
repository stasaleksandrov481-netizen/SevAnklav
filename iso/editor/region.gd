@tool
extends Node3D
@export var room_id := "room"
@export var title := "НОВАЯ КОМНАТА"
@export var width := 12.0
@export var depth := 10.0
@export_range(0,2) var floor_finish := 0
var _wall_visuals: Array[MeshInstance3D]=[]
const Cutaway=preload("res://iso/wall_cutaway.gd")
func contains_world_point(point: Vector3) -> bool:
	var p:=to_local(point)
	return absf(p.x)<width*0.5 and absf(p.z)<depth*0.5
func collect_walls() -> void:
	_wall_visuals.clear()
	for node in find_children("*","Node3D",true,false):
		if node.get_script()==preload("res://iso/editor/piece.gd") and node.kind=="Wall" and node.has_node("Generated/Surface"):
			_wall_visuals.append(node.get_node("Generated/Surface"))
func update_occlusion(point: Vector3, camera: Camera3D, delta: float, bounds:=Rect2()) -> void:
	if _wall_visuals.is_empty(): collect_walls()
	for visual in _wall_visuals:
		if not is_instance_valid(visual): continue
		var at:=visual.global_position; var axis:=camera.global_basis.z
		var x_edge:=bounds.end.x if axis.x>0 else bounds.position.x
		var z_edge:=bounds.end.y if axis.z>0 else bounds.position.y
		var front: bool=(absf(at.x-x_edge)<0.22 and at.z>=bounds.position.y and at.z<=bounds.end.y) or (absf(at.z-z_edge)<0.22 and at.x>=bounds.position.x and at.x<=bounds.end.x)
		Cutaway.update(visual,point,camera,delta,front)
