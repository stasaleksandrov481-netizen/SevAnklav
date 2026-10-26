extends CharacterBody3D
var locked := false
var wake_light := 0.0
var move_vector := Vector2.ZERO
var aim_vector := Vector2.ZERO
var fire := false
var busy := 0.0
var checking := false
var reload_pending := false
var torch: SpotLight3D
var aim_direction := Vector3.FORWARD
@onready var world = get_parent()
@onready var rig = $Visual
func _ready() -> void:
	torch=SpotLight3D.new()
	torch.spot_range=13
	torch.spot_angle=27
	torch.light_energy=2.2
	torch.light_color=Color("#dbe2cc")
	torch.shadow_enabled=true
	torch.visible=false
	add_child(torch)
func _physics_process(delta: float) -> void:
	if locked or world.paused or float(world.state.data.health)<=0:
		velocity=Vector3.ZERO
		rig.moving=0
		return
	var input:=Input.get_vector("move_left","move_right","move_up","move_down")
	if move_vector.length()>0.05: input=move_vector
	var camera:=get_viewport().get_camera_3d()
	var right:=camera.global_basis.x; right.y=0
	var forward:=-camera.global_basis.z; forward.y=0
	var direction:=right.normalized()*input.x-forward.normalized()*input.y
	var speed:=6.0 if Input.is_action_pressed("run") else 3.7
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*16)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*16)
	velocity.y=-2
	move_and_slide()
	rig.moving=Vector2(velocity.x,velocity.z).length()/3.7
	var aim:=aim_vector
	if aim.length()>0.1:
		aim_direction=(right.normalized()*aim.x-forward.normalized()*aim.y).normalized()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse:=get_viewport().get_mouse_position()
		var ray:=camera.project_ray_origin(mouse)
		var vector:=camera.project_ray_normal(mouse)
		if absf(vector.y)>0.001:
			var hit:=ray+vector*((global_position.y-ray.y)/vector.y)
			aim_direction=(hit-global_position).normalized()
	elif direction.length()>0.1: aim_direction=direction.normalized()
	rig.rotation.y=lerp_angle(rig.rotation.y,atan2(aim_direction.x,aim_direction.z),minf(1,delta*13))
	var armed: bool=not world.state.weapon().is_empty()
	rig.weapon.visible=armed
	var left: String=world.state.data.slots.get("left",{}).get("id","")
	var right_item: String=world.state.data.slots.get("right",{}).get("id","")
	rig.weapon_hand="left" if left in ["pistol","rifle"] else "right"
	rig.flashlight_hand="left" if left=="flashlight" else ("right" if right_item=="flashlight" else "")
	torch.visible=(left=="flashlight" or right_item=="flashlight") and bool(world.state.data.get("flash_on",false))
	rig.flashlight_on=torch.visible
	if torch.visible: torch.global_position=rig.flash.to_global(Vector3(0,-.17,0))
	if aim_direction.length()>0.1: torch.look_at(torch.global_position+aim_direction)
	rig.aiming=armed and (aim.length()>0.1 or fire or Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	busy=maxf(0,busy-delta)
	if busy==0 and reload_pending:
		reload_pending=false
		var n:=mini(8-int(world.state.data.mag),world.state.amount("ammo"))
		if n>0: world.state.take("ammo",n); world.state.data.mag+=n
		if world.state.data.chamber==0 and world.state.data.mag>0:
			world.state.data.mag-=1; world.state.data.chamber=1
		world.state.data.checked=false
	if busy==0 and checking:
		checking=false
		world.state.data.checked=true
		world.notify("МАГАЗИН: "+("ПОЧТИ ПОЛНЫЙ" if world.state.data.mag>=6 else ("МЕНЬШЕ ПОЛОВИНЫ" if world.state.data.mag>0 else "ПУСТ"))+" / ПАТРОННИК: "+("ЕСТЬ ПАТРОН" if world.state.data.chamber else "ПУСТ"))
	if armed and busy==0 and (fire or Input.is_action_pressed("shoot")): shoot()
func shoot() -> void:
	if world.state.data.chamber==0: world.notify("ЩЕЛЧОК. ПРОВЕРЬТЕ ОРУЖИЕ."); busy=0.4; return
	world.state.data.chamber=0
	if world.state.data.mag>0: world.state.data.mag-=1; world.state.data.chamber=1
	world.state.data.checked=false
	busy=0.28
	rig.perform("shoot")
	var start:=global_position+Vector3.UP*0.25
	var query:=PhysicsRayQueryParameters3D.create(start,start+aim_direction*25)
	query.exclude=[get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("damage"): hit.collider.damage(34)
	for enemy in world.enemies: enemy.hear(global_position,18)
func reload() -> void:
	if busy>0 or world.state.weapon().is_empty(): return
	busy=1.4; reload_pending=true; rig.perform("reload")
func check_ammo() -> void:
	if busy>0 or world.state.weapon().is_empty(): return
	busy=0.8; checking=true; rig.perform("check")
func awaken() -> void:
	locked=true
	var capsule=world.rooms.capsule.get_node("V17Capsule")
	global_position=capsule.global_position+Vector3(0,1.1,0)
	rig.rotation.z=PI/2
	rig.perform("wake")
	var tween:=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self,"wake_light",1.0,1.8)
	await tween.finished
	var shell=capsule.get_node("Generated").find_child("Glass shell",false,false)
	if shell:
		tween=create_tween(); tween.tween_property(shell,"position:z",-1.3,1.2); await tween.finished
	tween=create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rig,"rotation:z",0.0,1.4)
	tween.tween_property(self,"global_position",capsule.global_position+Vector3(0,0.95,1.5),1.4)
	await tween.finished
	rig.perform("balance")
	await get_tree().create_timer(0.6).timeout
	world.state.data.awake=true
	world.save_state()
	locked=false
	world.notify("Волков… Это я? Что со мной сделали?")
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_E: world.interact()
		if event.keycode==KEY_R: reload()
		if event.keycode==KEY_C: check_ammo()
		if event.keycode==KEY_F: world.state.data["flash_on"]=not world.state.data.get("flash_on",false)
