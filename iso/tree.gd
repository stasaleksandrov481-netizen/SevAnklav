@tool
extends Node3D
class_name IsoTree

@export_range(3.0, 9.0, 0.2) var height := 5.8:
	set(value):
		height = value
		_refresh()
@export_range(0, 10000, 1) var variation := 1:
	set(value):
		variation = value
		_refresh()

func _ready() -> void:
	_rebuild()

func _refresh() -> void:
	if is_inside_tree(): call_deferred("_rebuild")

func _rebuild() -> void:
	for child in get_children():
		if child.name == "Generated":
			remove_child(child)
			child.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var tree := Sprite3D.new()
	tree.name = "Spruce"
	tree.texture = preload("res://assets/iso/spruce_cutout.png")
	tree.pixel_size = height / 1536.0
	tree.position.y = height * 0.5
	tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tree.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	tree.alpha_scissor_threshold = 0.25
	tree.transparent = true
	tree.shaded = false
	tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var t := float(variation % 7) / 7.0
	tree.modulate = Color(0.75 + t * 0.12, 0.78 + t * 0.08, 0.74 + t * 0.10)
	generated.add_child(tree)
	var body := StaticBody3D.new()
	generated.add_child(body)
	var collision := CollisionShape3D.new()
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.22
	trunk.height = 1.8
	collision.shape = trunk
	collision.position.y = 0.9
	body.add_child(collision)
