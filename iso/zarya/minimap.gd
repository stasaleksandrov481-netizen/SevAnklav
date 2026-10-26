extends Control
var world
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.04,0.055,0.9))
	if world==null: return
	var scale:=minf(size.x/96,size.y/46)
	var offset:=Vector2(33,21)*scale
	for entry in world.layout.rooms:
		if not world.state.data.visited.has(entry.id): continue
		var rect:=Rect2(Vector2(entry.x-6,entry.z-5)*scale+offset,Vector2(12,10)*scale)
		draw_rect(rect,Color("#263a44"))
		draw_rect(rect,Color("#728b95"),false,1)
	var pos: Vector3=world.player.position-world.ORIGIN
	draw_circle(Vector2(pos.x,pos.z)*scale+offset,3,Color("#b5e6f2"))
