extends Node3D

const RoomScript = preload("res://iso/room.gd")

@onready var player: Node3D = $Volkov

func _process(_delta: float) -> void:
	for node in get_children():
		if node.get_script() == RoomScript:
			node.set_roof_visible(not node.contains_world_point(player.global_position))
