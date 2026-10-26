extends Control
var world
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.04,0.055,0.9))
	if world==null: return
	var bounds := Rect2()
	var first := true
	for entry in world.layout.rooms:
		var extent := Vector2(entry.get("width",12),entry.get("depth",10))
		var room_bounds := Rect2(Vector2(entry.x,entry.z)-extent/2,extent)
		bounds = room_bounds if first else bounds.merge(room_bounds)
		first = false
	if first: return
	var scale := minf((size.x-16)/maxf(bounds.size.x,1),(size.y-16)/maxf(bounds.size.y,1))
	var offset := (size-bounds.size*scale)/2-bounds.position*scale
	for entry in world.layout.rooms:
		if not world.state.data.visited.has(entry.id): continue
		var rect:=Rect2(Vector2(entry.x-entry.get("width",12)/2.0,entry.z-entry.get("depth",10)/2.0)*scale+offset,Vector2(entry.get("width",12),entry.get("depth",10))*scale)
		draw_rect(rect,Color("#263a44"))
		draw_rect(rect,Color("#728b95"),false,1)
	var pos: Vector3=world.player.position-world.ORIGIN
	draw_circle(Vector2(pos.x,pos.z)*scale+offset,3,Color("#b5e6f2"))
