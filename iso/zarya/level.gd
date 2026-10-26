extends Node3D
const State = preload("res://iso/zarya/state.gd")
const Room = preload("res://iso/room.gd")
const Door = preload("res://iso/zarya/door.gd")
const Prop = preload("res://iso/prop.gd")
const ORIGIN := Vector3(3540,0,2900)
var state
var layout: Dictionary
var rooms := {}
var doors: Array = []
var stations: Array = []
var lights: Array = []
var enemies: Array = []
var room_visible := {}
var current := ""
var hud
var paused := false
var clock := 0.0
var save_clock := 0.0
var materials := {}
var message := ""
@onready var player: CharacterBody3D = $Volkov
func _ready() -> void:
	state = State.new(get_node("/root/G").zsave)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://iso/zarya/layout.json"))
	$TouchControls.visible = false
	_build()
	var pos: Array = state.data.position
	player.position = ORIGIN+Vector3(pos[0],pos[1],pos[2])
	if not state.data.awake: player.position = ORIGIN+Vector3(-24,1.1,-10)
	$Camera.position=player.position+$Camera._offset
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#070d11")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.0
	add_child(environment)
	for drop in state.data.drops: create_drop(drop)
	call_deferred("_start")
func _start() -> void:
	if hud == null: add_child(preload("res://iso/zarya/hud.gd").new())
	if not state.data.awake:
		player.locked = true
		if hud != null: hud.prologue()
func mat(color: Color, texture := false) -> StandardMaterial3D:
	var key := color.to_html()+str(texture)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	m.metallic = 0.18
	if texture: m.albedo_texture = preload("res://assets/iso/concrete_panels.png")
	materials[key] = m
	return m
func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = mat(color)
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		parent.add_child(body)
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		collider.shape = collision
		body.add_child(collider)
	return mesh
func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	visual.mesh = mesh
	visual.position = at
	visual.material_override = mat(color)
	parent.add_child(visual)
func _build() -> void:
	var root := Node3D.new()
	root.position = ORIGIN
	root.name = "LevelMinusTwo"
	add_child(root)
	var foundation:=MeshInstance3D.new()
	var bedrock:=PlaneMesh.new(); bedrock.size=Vector2(112,62)
	foundation.mesh=bedrock; foundation.position=Vector3(12,-0.23,0)
	var rock:=StandardMaterial3D.new()
	rock.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	rock.albedo_texture=preload("res://assets/iso/dark_shale.png")
	rock.albedo_color=Color(0.075,0.095,0.11)
	rock.uv1_scale=Vector3(10,6,1)
	foundation.material_override=rock
	foundation.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(foundation)
	for entry in layout.rooms:
		var room = Room.new()
		room.name = entry.id
		room.width = 12
		room.depth = 10
		room.floor_finish = entry.finish
		room.roof_enabled = false
		room.south_door = false
		room.position = Vector3(entry.x,0,entry.z)
		for link in layout.links:
			if entry.id != link.a and entry.id != link.b: continue
			var other: Dictionary = room_info(link.b if entry.id==link.a else link.a)
			if other.x > entry.x: room.east_door = true
			elif other.x < entry.x: room.west_door = true
			elif other.z > entry.z: room.south_door = true
			else: room.north_door = true
		for link in layout.links:
			if link.kind=="gate" and entry.id in [link.a,link.b]: room.door_widths["East" if entry.id==link.a else "West"]=3.0
		root.add_child(room)
		rooms[entry.id] = room
		_furnish(room,entry)
		_equipment(room,entry)
	for link in layout.links:
		var a := room_info(link.a)
		var b := room_info(link.b)
		var door = Door.new()
		door.world = self
		door.info = link.duplicate()
		door.info.id = link.a+":"+link.b
		door.position = Vector3((a.x+b.x)/2.0,0,(a.z+b.z)/2.0)
		if a.x != b.x: door.rotation.y = PI/2
		root.add_child(door)
		doors.append(door)
	for entry in layout.actions:
		var station := Node3D.new()
		station.name = entry.id
		station.position = Vector3(-2.8,0,-2.7)
		if entry.id in ["identity","weapon","card","secret"]: station.position.x = 2.7
		rooms[entry.room].add_child(station)
		var action: Dictionary = entry.duplicate()
		action.node = station
		stations.append(action)
		if entry.kind in ["loot","locked"]:
			box(station,Vector3(0.85,0.75,0.65),Vector3(0,0.375,0),Color("#50616a"),true)
		else:
			box(station,Vector3(0.8,0.8,0.65),Vector3(0,0.4,0),Color("#3f515d"),true)
			box(station,Vector3(0.7,0.48,0.08),Vector3(0,1.15,0),Color("#486d78"))
		if not state.data.containers.has(entry.id):
			var content := {"weapon":[state.item("pistol"),state.item("ammo",24),state.item("flashlight")],"card":[state.item("card"),state.item("tool")],"fuse":[state.item("fuse")],"guard":[state.item("band",2),state.item("food"),state.item("uniform")],"medical":[state.item("band",3),state.item("medkit"),state.item("morph"),state.item("water",2)],"secret":[state.item("medkit"),state.item("ammo",8)]}
			state.data.containers[entry.id] = content.get(entry.id,[])
	var capsule := preload("res://iso/capsule.gd").new()
	capsule.name = "V17Capsule"
	rooms.capsule.add_child(capsule)
	for spec in [["subject_a","isolation_a"],["subject_b","quarantine"],["subject_c","server"]]:
		var enemy = preload("res://iso/zarya/enemy.gd").new()
		enemy.world = self
		enemy.id = spec[0]
		enemy.spawn = ORIGIN+Vector3(room_info(spec[1]).x,0.95,room_info(spec[1]).z+2)
		add_child(enemy)
		enemies.append(enemy)
func room_info(id: String) -> Dictionary:
	for entry in layout.rooms:
		if entry.id == id: return entry
	return {}
func room_at(pos: Vector3) -> String:
	for id in rooms:
		if rooms[id].contains_world_point(pos): return id
	return ""
func sees(from: Vector3, to: Vector3, exclude: Array = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from,to)
	var exclusions: Array[RID]=[]
	exclusions.assign(exclude)
	q.exclude = exclusions
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func _process(delta: float) -> void:
	if paused: return
	clock += delta
	save_clock += delta
	if save_clock>6: save_state(); save_clock=0
	if clock<0.07: return
	var step := clock
	clock = 0
	current = room_at(player.global_position)
	if not current.is_empty(): state.data.visited[current] = true
	room_visible.clear()
	room_visible[current] = true
	for door in doors:
		if door.progress<0.96: continue
		var other := ""
		if door.info.a == current: other = door.info.b
		elif door.info.b == current: other = door.info.a
		if not other.is_empty() and player.global_position.distance_to(door.global_position)<7 and sees(player.global_position,door.global_position+Vector3.UP,[player.get_rid()]):
			room_visible[other] = true
	for id in rooms:
		var room = rooms[id]
		var known: bool = state.data.visited.has(id) or room_visible.has(id)
		room.visible = known
		if not known: continue
		var bounds := Rect2(Vector2(room.global_position.x-6,room.global_position.z-5),Vector2(12,10))
		room.update_occlusion(player.global_position,$Camera,step,bounds)
		for lamp in lights:
			if lamp.room != id: continue
			var target := 0.0
			if room_visible.has(id):
				target = 2.7 if lamp.normal and (state.flag("power") or id in ["capsule","observation","staff"]) else (1.4 if not lamp.normal else 0.0)
			elif state.data.visited.has(id): target = 0.17
			if not state.data.awake: target *= player.wake_light
			lamp.node.light_energy = move_toward(lamp.node.light_energy,target,step*2.5)
			lamp.node.visible = lamp.node.light_energy>0.01
			lamp.node.shadow_enabled = room_visible.has(id)
			lamp.fixture.visible = room_visible.has(id)
	for door in doors: door.visible = state.data.visited.has(door.info.a) or state.data.visited.has(door.info.b)
	for enemy in enemies: enemy.refresh_visibility()
	if state.data.awake:
		state.data.food = maxf(0,float(state.data.food)-step*0.008)
		state.data.water = maxf(0,float(state.data.water)-step*0.014)
		for wound in state.data.wounds.values(): state.data.health=maxf(0,float(state.data.health)-float(wound.bleeding)*step*0.07)
func save_state() -> void:
	if not is_instance_valid(player): return
	var local := player.position-ORIGIN
	state.data.position = [local.x,local.y,local.z]
	for enemy in enemies: enemy.store()
	get_node("/root/G").write_save()
func notify(text: String) -> void:
	message = text
	if hud != null: hud.notify(text)
func nearest() -> Dictionary:
	var result := {}
	var distance := 2.4
	for action in stations:
		var d: float = player.global_position.distance_to(action.node.global_position)
		if d<distance: result=action; distance=d
	for door in doors:
		var d: float = player.global_position.distance_to(door.global_position)
		if d<distance: result={"kind":"door","node":door,"title":"ДВЕРЬ / "+str(door.info.kind)}; distance=d
	return result
func interact(action: Dictionary = {}) -> void:
	if action.is_empty(): action=nearest()
	if action.is_empty() or player.locked: return
	if action.kind == "door": notify(action.node.request()); return
	if action.kind == "sealed": notify("ГРУЗОВОЙ ШЛЮЗ ЗАБЛОКИРОВАН. НЕТ РАЗРЕШЕНИЯ НА ВЫХОД."); return
	if action.kind == "stairs":
		if not state.flag("clearance"): notify("СНАЧАЛА СНИМИТЕ БЛОКИРОВКУ КАРАНТИНА."); return
		state.mark("level_complete")
		save_state()
		notify("ДОСТУП К ВЕРХНЕМУ УРОВНЮ ВРЕМЕННО НЕДОСТУПЕН")
		return
	if action.kind == "locked" and state.amount("card") == 0: notify("ТРЕБУЕТСЯ КАРТА ИНЖЕНЕРА"); return
	if action.kind in ["loot","locked"]: hud.open_loot(action); return
	hud.open_terminal(action)
func activate(id: String) -> bool:
	match id:
		"staff": state.mark("staff")
		"power":
			if state.amount("fuse")==0 and not state.flag("power"): notify("НУЖЕН РЕЗЕРВНЫЙ ПРЕДОХРАНИТЕЛЬ / СЕРВЕРНАЯ"); return false
			if not state.flag("power"): state.take("fuse")
			state.mark("power")
		"quarantine":
			if not state.flag("power") or not state.flag("experiment") or not state.flag("archive"): notify("НЕОБХОДИМЫ ПИТАНИЕ, ЗАПИСЬ ЭКСПЕРИМЕНТА И АРХИВ"); return false
			state.mark("clearance")
		_: state.mark(id)
	save_state()
	return true
func objective() -> String:
	for entry in [["staff","Осмотреть терминал персонала"],["armed","Найти оружие на контрольном посту"],["card","Найти карту инженера Серова"],["experiment","Изучить запись эксперимента"],["power","Восстановить питание / предохранитель в серверной"],["archive","Прочитать архив наблюдения"],["clearance","Снять карантинную блокировку"],["level_complete","Добраться до лестницы на уровень −1"]]:
		if not state.flag(entry[0]): return entry[1]
	return "Уровень −2 исследован. Ожидание доступа на −1."
func _furnish(room: Node3D, entry: Dictionary) -> void:
	var sign := Label3D.new()
	sign.text = entry.title
	sign.font_size=56
	sign.pixel_size=0.003
	sign.position=Vector3(0,1.9,-4.83)
	sign.shaded=true
	room.add_child(sign)
	for x in [-3.5,3.5]:
		var fixture := Node3D.new()
		fixture.position=Vector3(x,2.12,-4.65)
		fixture.set_meta("fixture",true)
		room.add_child(fixture)
		box(fixture,Vector3(0.95,0.25,0.18),Vector3.ZERO,Color("#a9bfc9"))
		var light := OmniLight3D.new()
		light.position=fixture.position+Vector3(0,0,0.25)
		light.omni_range=10
		light.light_color=Color("#bad2df")
		light.light_energy=0
		room.add_child(light)
		lights.append({"room":entry.id,"node":light,"fixture":fixture,"normal":true})
	var emergency := OmniLight3D.new()
	emergency.position=Vector3(4,1.9,4.5)
	emergency.omni_range=7
	emergency.light_color=Color("#e9533b")
	emergency.light_energy=0
	room.add_child(emergency)
	lights.append({"room":entry.id,"node":emergency,"fixture":box(room,Vector3(0.5,0.16,0.12),emergency.position,Color("#a34434")),"normal":false})
	# Keep all central door-to-door routes open; equipment sits in perimeter bays.
	for x in [-4.5,4.5]:
		for z in [-3.4,3.4]:
			if entry.id in ["corridor","service","stairs","capsule"]: continue
			var prop = Prop.new()
			prop.kind = 2 if entry.id in ["observation","isolation_a","isolation_b"] else (3 if entry.id in ["lab1","lab2","control"] else 1)
			prop.position=Vector3(x,0,z)
			prop.collision_size=Vector3(2,0.9,0.9) if prop.kind==2 else Vector3(0.9,1.8,0.65)
			room.add_child(prop)
			if entry.id in ["generator","pump","workshop"]:
				cylinder(room,Vector3(x,0.8,z),0.38,1.1,Color("#657983"))
	for z in [-4.5,4.5]:
		box(room,Vector3(11.2,0.06,0.08),Vector3(0,1.7,z),Color("#516773"))
	if entry.id in ["server","electrical"]:
		for x in [-3.8,-2.4,2.4,3.8]:
			box(room,Vector3(0.95,2.1,0.9),Vector3(x,1.05,-3.2),Color("#33454f"),true)
			for y in range(8): box(room,Vector3(0.85,0.08,0.06),Vector3(x,0.3+y*0.21,-2.7),Color("#7b8a8e"))
	if entry.id == "stairs":
		for i in range(11): box(room,Vector3(2,0.15,0.3),Vector3(0,0.12+i*0.14,2.0-i*0.3),Color("#6c7c83"))
		box(room,Vector3(2.4,0.15,0.8),Vector3(0,1.65,-1.5),Color("#485f6c"))
	for i in range(3):
		if entry.id in ["lab2","control","quarantine"]: box(room,Vector3(0.24,0.008,0.32),Vector3(2+i*0.3,0.018,2.8),Color("#b5b6a7"))

func create_drop(drop: Dictionary) -> void:
	if not state.data.containers.has(drop.id): state.data.containers[drop.id]=[drop.item]
	var node:=Node3D.new()
	node.position=Vector3(drop.position[0],drop.position[1]-0.85,drop.position[2])
	add_child(node)
	box(node,Vector3(0.28,0.1,0.22),Vector3.ZERO,Color("#849097"))
	stations.append({"id":drop.id,"node":node,"room":room_at(node.global_position),"kind":"loot","title":"ПРЕДМЕТ НА ПОЛУ","record":""})

func _equipment(room: Node3D, entry: Dictionary) -> void:
	var floor_mesh: MeshInstance3D=room.get_node("Generated/Floor")
	var floor_material:=StandardMaterial3D.new()
	floor_material.albedo_texture=preload("res://assets/bunker/v9/materials.png")
	floor_material.uv1_scale=Vector3(0.5,0.5,1)
	floor_material.uv1_offset=Vector3(0.0,0.5 if int(entry.finish)==1 else 0,0)
	floor_material.albedo_color=Color("#acbbc2")
	floor_material.roughness=0.74
	floor_mesh.material_override=floor_material
	var helper=preload("res://iso/bunker_detail.gd").new()
	if entry.id in ["capsule","observation","lab1","lab2","workshop"]:
		helper._trolley(room,Vector3(-4,0,1.8),entry.id in ["capsule","observation"])
	if entry.id in ["archive","workshop","pump","staff"]: helper._shelf(room,Vector3(3,0,-3.8),entry.id=="archive")
	helper.free()
	if entry.id in ["lab1","lab2","capsule"]:
		box(room,Vector3(2.4,0.12,0.9),Vector3(0,0.85,-3.7),Color("#81939b"),true)
		for x in [-0.9,0.9]: box(room,Vector3(0.08,0.8,0.7),Vector3(x,0.4,-3.7),Color("#3a4c55"))
		if entry.id=="lab1":
			cylinder(room,Vector3(0,1.1,-3.7),0.36,0.35,Color("#8c9fa4"))
			for x in [-0.7,0.7]: cylinder(room,Vector3(x,1.1,-3.7),0.08,0.4,Color("#84a8b1"))
		elif entry.id=="lab2":
			for x in [-0.6,-0.3,0,0.3,0.6]: cylinder(room,Vector3(x,1.08,-3.7),0.055,0.35,Color("#70939b"))
		else:
			box(room,Vector3(0.85,0.5,0.14),Vector3(0,1.25,-3.8),Color("#416d7b"))
	if entry.id in ["generator","pump"]:
		var motor:=Node3D.new(); motor.position=Vector3(3,0.85,2); motor.rotation.z=PI/2; room.add_child(motor)
		cylinder(motor,Vector3.ZERO,0.62,2.2,Color("#526e7a"))
		for y in [-0.8,-0.4,0.0,0.4,0.8]: cylinder(motor,Vector3(0,y,0),0.66,0.06,Color("#263e4a"))
		box(room,Vector3(3,0.25,1.6),Vector3(3,0.15,2),Color("#324b56"),true)
	# Merge static ornament meshes by material, while preserving walls,
	# articulated actors, animated doors and the capsule as independent nodes.
	var groups: Dictionary={}
	for visual in room.find_children("*","MeshInstance3D",true,false):
		if visual in room._wall_visuals or visual==floor_mesh or visual.get_parent().has_meta("fixture"): continue
		if visual.get_parent().get_script()==preload("res://iso/capsule.gd"): continue
		if visual.name in ["Glass shell","Top rail"]: continue
		if visual.material_override==null: continue
		var material: StandardMaterial3D=visual.material_override
		var key:=str(material.albedo_color)+str(material.albedo_texture)+str(material.metallic)+str(material.roughness)
		if not groups.has(key): groups[key]=[]
		groups[key].append(visual)
	for list in groups.values():
		if list.size()<2: continue
		var builder:=SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for visual in list:
			for surface in range(visual.mesh.get_surface_count()): builder.append_from(visual.mesh,surface,room.global_transform.affine_inverse()*visual.global_transform)
		var merged:=MeshInstance3D.new(); merged.mesh=builder.commit(); merged.material_override=list[0].material_override; room.add_child(merged)
		for visual in list: visual.get_parent().remove_child(visual); visual.free()
