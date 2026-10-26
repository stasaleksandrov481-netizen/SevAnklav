extends Control
var ui
var zones := {}
func _ready() -> void:
	zones={"Голова":Rect2(145,20,50,60),"Торс":Rect2(125,85,90,135),"Левая рука":Rect2(85,90,35,150),"Правая рука":Rect2(220,90,35,150),"Левая нога":Rect2(128,225,38,165),"Правая нога":Rect2(175,225,38,165)}
func _draw() -> void:
	for id in zones:
		var wound: Dictionary=ui.world.state.data.wounds[id]
		var color:=Color("#a55745") if float(wound.damage)>0 else Color("#526e7b")
		var r: Rect2=zones[id]
		if id=="Голова":
			draw_circle(r.get_center(),25,color)
			draw_line(Vector2(160,75),Vector2(160,88),color,10)
		elif id=="Торс":
			draw_colored_polygon(PackedVector2Array([Vector2(125,90),Vector2(150,82),Vector2(190,82),Vector2(215,90),Vector2(203,148),Vector2(198,188),Vector2(210,220),Vector2(130,220),Vector2(142,188),Vector2(137,148)]),color)
			draw_line(Vector2(170,100),Vector2(170,175),Color("#29404b"),2)
		else:
			var middle:=r.position+Vector2(r.size.x/2,18)
			var end:=r.end-Vector2(r.size.x/2,18)
			draw_line(middle,end,color,r.size.x-8,true)
			draw_circle(middle,(r.size.x-8)/2,color)
			draw_circle(end,(r.size.x-8)/2,color)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		for id in zones:
			if zones[id].has_point(event.position): ui.selected_zone=id; ui.notify("ВЫБРАНО: "+id)
