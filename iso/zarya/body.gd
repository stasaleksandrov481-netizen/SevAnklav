extends Control
var ui
var zones := {}
var outlines := {}
func _ready() -> void:
	zones={"Голова":Rect2(145,20,50,60),"Торс":Rect2(125,85,90,135),"Левая рука":Rect2(85,90,35,150),"Правая рука":Rect2(220,90,35,150),"Левая нога":Rect2(128,225,38,165),"Правая нога":Rect2(175,225,38,165)}
	outlines={
		"Голова":[Vector2(153,26),Vector2(170,19),Vector2(187,26),Vector2(192,45),Vector2(185,65),Vector2(178,72),Vector2(178,83),Vector2(162,83),Vector2(162,72),Vector2(155,65),Vector2(148,45)],
		"Торс":[Vector2(160,83),Vector2(144,88),Vector2(128,94),Vector2(133,131),Vector2(143,165),Vector2(139,190),Vector2(131,218),Vector2(153,225),Vector2(170,216),Vector2(187,225),Vector2(209,218),Vector2(201,190),Vector2(197,165),Vector2(207,131),Vector2(212,94),Vector2(196,88),Vector2(180,83)],
		"Левая рука":[Vector2(125,95),Vector2(112,102),Vector2(104,133),Vector2(102,159),Vector2(91,191),Vector2(87,214),Vector2(91,237),Vector2(99,239),Vector2(106,222),Vector2(104,211),Vector2(115,181),Vector2(120,159),Vector2(126,141)],
		"Правая рука":[Vector2(215,95),Vector2(228,102),Vector2(236,133),Vector2(238,159),Vector2(249,191),Vector2(253,214),Vector2(249,237),Vector2(241,239),Vector2(234,222),Vector2(236,211),Vector2(225,181),Vector2(220,159),Vector2(214,141)],
		"Левая нога":[Vector2(132,225),Vector2(166,229),Vector2(163,268),Vector2(160,295),Vector2(158,328),Vector2(152,368),Vector2(153,382),Vector2(148,392),Vector2(128,392),Vector2(129,381),Vector2(137,364),Vector2(133,329),Vector2(136,296),Vector2(128,266)],
		"Правая нога":[Vector2(208,225),Vector2(174,229),Vector2(177,268),Vector2(180,295),Vector2(182,328),Vector2(188,368),Vector2(187,382),Vector2(192,392),Vector2(212,392),Vector2(211,381),Vector2(203,364),Vector2(207,329),Vector2(204,296),Vector2(212,266)]}
func _draw() -> void:
	for id in outlines:
		var wound: Dictionary=ui.world.state.data.wounds[id]
		var injured: bool=float(wound.damage)>0 or float(wound.bleeding)>0 or float(wound.pain)>0
		var edge:=Color("#dc776b") if injured else Color("#79a5ae")
		var fill:=Color("#783c38") if injured else Color("#14303a")
		var points:=PackedVector2Array(outlines[id])
		draw_colored_polygon(points,fill)
		points.append(points[0]); draw_polyline(points,edge,2,true)
		if ui.selected_zone==id and scale.x>0.5:
			draw_polyline(points,Color(.35,.8,.82,.15),9,true);draw_polyline(points,Color("#b1e6e2"),2,true)
	# Sternum, ribs, pelvis and joints remain restrained, legible at HUD scale.
	draw_line(Vector2(170,99),Vector2(170,180),Color("#627b87"),1,true)
	for y in [112,123,134,145]:
		draw_polyline(PackedVector2Array([Vector2(139,y),Vector2(151,y+6),Vector2(170,y+8),Vector2(189,y+6),Vector2(201,y)]),Color("#4b626d"),1,true)
	for at in [Vector2(148,295),Vector2(192,295),Vector2(112,159),Vector2(228,159)]: draw_arc(at,7,0,TAU,20,Color("#607781"),1,true)
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		for id in zones:
			if zones[id].has_point(event.position):
				ui.select_zone(id);queue_redraw();accept_event();return
