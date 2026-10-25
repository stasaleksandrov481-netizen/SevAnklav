@tool
extends Node2D

@export var title := "Локация":
	set(value):
		title = value
		queue_redraw()
@export_enum("City", "Bunker", "Military", "Danger", "Village", "Utility") var kind := 0:
	set(value):
		kind = value
		queue_redraw()
@export_file("*.tscn") var playable_scene := ""

func sector_coordinate() -> Vector2i:
	return Vector2i(floori(position.x / 4.0), floori(position.y / 4.0))

func _draw() -> void:
	var colors := [Color("#d9e3db"), Color("#8abce0"), Color("#a3bdc0"), Color("#d36a6a"), Color("#e0d3ad"), Color("#c7d5a8")]
	var color: Color = colors[kind]
	draw_circle(Vector2.ZERO, 8, Color(0.02, 0.04, 0.05, 0.8))
	draw_arc(Vector2.ZERO, 8, 0, TAU, 32, color, 2.0)
	draw_circle(Vector2.ZERO, 2.8, color)
	draw_string(ThemeDB.fallback_font, Vector2(12, -6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK, TextServer.JUSTIFICATION_NONE)
	draw_string(ThemeDB.fallback_font, Vector2(11, -7), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
