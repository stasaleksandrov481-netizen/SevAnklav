@tool
extends Path2D

@export var line_color := Color("#c8bdac"):
	set(value):
		line_color = value
		queue_redraw()
@export_range(1.0, 14.0, 1.0) var road_width := 4.0:
	set(value):
		road_width = value
		queue_redraw()

func _draw() -> void:
	if curve == null or curve.point_count < 2: return
	var points := curve.tessellate(4, 4)
	if points.size() < 2: return
	draw_polyline(points, Color(0.03, 0.05, 0.06, 0.85), road_width + 3.0, true)
	draw_polyline(points, line_color, road_width, true)
