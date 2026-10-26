extends Node3D
var world
var info: Dictionary
var opened := false
var progress := 0.0
var leaf: MeshInstance3D
var body: StaticBody3D
var collision: CollisionShape3D
var adjacent: Array = []
var width := 1.4
func _ready() -> void:
	width=3.0 if info.kind=="gate" else 1.4
	opened = bool(world.state.data.doors.get(info.id,false))
	progress = 1.0 if opened else 0.0
	leaf = world.box(self,Vector3(width-0.04,2.35,0.16),Vector3(0,1.175,0),Color("#4c626b"))
	world.box(self,Vector3(width+0.32,0.18,0.4),Vector3(0,2.55,0),Color("#263842"))
	for side in [-1,1]: world.box(self,Vector3(0.15,2.55,0.42),Vector3(side*(width/2+0.09),1.275,0),Color("#3e505a"))
	world.box(leaf,Vector3(0.10,0.25,0.06),Vector3(0.48,0,0.11),Color("#afbbb9"))
	body = StaticBody3D.new()
	add_child(body)
	collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width,2.5,0.25)
	collision.shape = shape
	collision.position.y = 1.25
	body.add_child(collision)
	collision.disabled = opened
func request() -> String:
	if info.kind == "damaged": return "ПРИВОД ПОВРЕЖДЁН. ИСПОЛЬЗУЙТЕ ОБХОДНОЙ МАРШРУТ."
	if not str(info.lock).is_empty() and not world.state.flag(info.lock): return "ДОСТУП ЗАКРЫТ / "+str(info.lock).to_upper()
	opened = not opened
	world.state.data.doors[info.id] = opened
	world.save_state()
	return ""
func _process(delta: float) -> void:
	if world.paused: return
	if info.kind == "auto" and not opened and world.player.global_position.distance_to(global_position)<2.2: request()
	progress = move_toward(progress,1.0 if opened else 0.0,delta*1.4)
	leaf.position.x = progress*(width+0.05)
	collision.set_deferred("disabled",progress>0.96)
