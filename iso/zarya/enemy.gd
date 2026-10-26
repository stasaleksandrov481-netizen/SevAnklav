extends CharacterBody3D
var world
var id := ""
var spawn := Vector3.ZERO
var hp := 100
var target := Vector3.ZERO
var memory := 0.0
var cooldown := 0.0
var visual: Node3D
func _ready() -> void:
	var saved: Dictionary=world.state.data.enemies.get(id,{})
	var pos: Array=saved.get("position",[spawn.x,spawn.y,spawn.z])
	position=Vector3(pos[0],pos[1],pos[2])
	hp=int(saved.get("hp",100))
	visual=preload("res://iso/zarya/rig.gd").new()
	add_child(visual)
	var shape:=CapsuleShape3D.new(); shape.radius=0.3; shape.height=1.8
	var collision:=CollisionShape3D.new(); collision.shape=shape; add_child(collision)
	if hp<=0:
		visual.rotation.z=PI/2
		collision_layer=0
		call_deferred("_corpse")
func refresh_visibility() -> void:
	var room: String=world.room_at(global_position)
	visible=world.room_visible.has(room) and world.sees(world.player.global_position+Vector3.UP*0.3,global_position+Vector3.UP*0.3,[get_rid(),world.player.get_rid()])
func hear(at: Vector3, radius: float) -> void:
	if hp>0 and global_position.distance_to(at)<radius: target=at; memory=4
func _physics_process(delta: float) -> void:
	if hp<=0 or world.paused: return
	cooldown=maxf(0,cooldown-delta)
	var player=world.player
	var distance: float=global_position.distance_to(player.global_position)
	if distance<11 and world.sees(global_position,player.global_position,[get_rid(),player.get_rid()]):
		target=player.global_position; memory=3
	else: memory=maxf(0,memory-delta)
	if memory<=0: visual.moving=0; return
	var direction:=target-global_position; direction.y=0
	velocity=direction.normalized()*1.1 if direction.length()>0.8 else Vector3.ZERO
	velocity.y=-2
	move_and_slide()
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),delta*4)
	visual.moving=Vector2(velocity.x,velocity.z).length()
	if distance<1 and cooldown==0 and world.sees(global_position,player.global_position,[get_rid(),player.get_rid()]):
		world.state.hit("Левая рука",9)
		world.notify("УКУС / ЛЕВАЯ РУКА / КРОВОТЕЧЕНИЕ")
		cooldown=1.8
func damage(amount: int) -> void:
	hp-=amount
	if hp<=0:
		collision_layer=0
		var fall:=create_tween(); fall.tween_property(visual,"rotation:z",PI/2,0.5)
		_corpse()
	store()
func store() -> void:
	world.state.data.enemies[id]={"hp":hp,"position":[position.x,position.y,position.z]}

func _corpse() -> void:
	if not world.state.data.containers.has(id): world.state.data.containers[id]=[world.state.item("band")]
	world.stations.append({"id":id,"node":self,"room":world.room_at(global_position),"kind":"loot","title":"ТЕЛО СОТРУДНИКА","record":""})
