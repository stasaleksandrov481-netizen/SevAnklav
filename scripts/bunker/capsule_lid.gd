extends Node2D
const GLASS=preload("res://assets/bunker/v9/capsule_glass.svg")
func _draw() -> void:
    draw_texture_rect(GLASS,Rect2(-44,0,88,154),false)
