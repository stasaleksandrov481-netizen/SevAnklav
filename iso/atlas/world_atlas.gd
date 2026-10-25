@tool
extends Node2D

const REFERENCE_SIZE := Vector2(1280, 960)
const METERS_PER_PIXEL := 16.0
const SECTOR_METERS := 64.0
const REFERENCE := preload("res://assets/world/world_concept_reference.jpg")

@export var show_reference := true:
	set(value):
		show_reference = value
		queue_redraw()

var _dragging := false

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, REFERENCE_SIZE), Color("#24312c"), true)
	if show_reference:
		draw_texture_rect(REFERENCE, Rect2(Vector2.ZERO, REFERENCE_SIZE), false, Color(1, 1, 1, 0.75))
	for x in range(0, 1281, 64):
		draw_line(Vector2(x, 0), Vector2(x, 960), Color(0.73, 0.85, 0.88, 0.15), 1.0)
	for y in range(0, 961, 64):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.73, 0.85, 0.88, 0.15), 1.0)
	draw_rect(Rect2(636, 416, 12, 12), Color("#e5c67b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(18, 42), "АТЛАС РЕГИОНА · 20,48 × 15,36 КМ · СЕКТОР 64 М", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e7e7df"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 935), "Колесо — масштаб · ПКМ — перемещение · R — концепт-изображение · щелчок по маркеру — игровая сцена", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e7e7df"))

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			$Camera.zoom *= 1.18
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			$Camera.zoom /= 1.18
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click := get_global_mouse_position()
			for marker in $Markers.get_children():
				if marker.position.distance_to(click) < 12.0 and marker.playable_scene != "":
					get_tree().change_scene_to_file(marker.playable_scene)
					return
		$Camera.zoom = $Camera.zoom.clamp(Vector2(0.65, 0.65), Vector2(7, 7))
	elif event is InputEventMouseMotion and _dragging:
		$Camera.position -= event.relative / $Camera.zoom
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		show_reference = not show_reference
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
