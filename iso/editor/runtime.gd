extends RefCounted
const Region=preload("res://iso/editor/region.gd")
const Lamp=preload("res://iso/editor/lamp.gd")
const DoorMarker=preload("res://iso/editor/door_marker.gd")
const Station=preload("res://iso/editor/station.gd")
const Spawn=preload("res://iso/editor/spawn.gd")
const Piece=preload("res://iso/editor/piece.gd")
static func region_of(node: Node) -> Node:
	var p:=node.get_parent()
	while p:
		if p.get_script()==Region: return p
		p=p.get_parent()
	return null
static func build(world: Node3D, path: String) -> void:
	var map: Node3D=load(path).instantiate(); map.name="LevelMinusTwo"; map.position=world.ORIGIN
	world.add_child(map)
	world.state_key=map.map_id
	world.story_enabled=map.story_enabled
	if world.state_key!="zarya2": world.state=world.State.new(world.get_node("/root/G").zsave,world.state_key)
	if not world.story_enabled:
		world.state.data.awake=true; world.state.data.flags["power"]=true
	world.layout={"rooms":[],"links":[],"actions":[]}
	for node in map.find_children("*","Node3D",true,false):
		if node.get_script()==Region:
			world.rooms[node.room_id]=node
			var p: Vector3=map.to_local(node.global_position)
			world.layout.rooms.append({"id":node.room_id,"title":node.title,"x":p.x,"z":p.z,"width":node.width,"depth":node.depth,"finish":node.floor_finish})
	for node in map.find_children("*","Node3D",true,false):
		var region=region_of(node)
		var room: String=region.room_id if region else world.room_at(node.global_position)
		if node.get_script()==preload("res://iso/editor/player_start.gd"): world.player_start=node.global_position
		match node.get_script():
			Lamp:
				world.lights.append({"room":room,"node":node.get_node("Generated/Light"),"fixture":node.get_node("Generated/Fixture"),"normal":not node.emergency,"energy":node.energy})
			DoorMarker:
				var door=world.Door.new(); door.world=world
				door.info={"id":node.door_id,"a":node.room_a,"b":node.room_b,"kind":node.kind,"lock":node.lock}
				node.add_child(door); world.doors.append(door); world.layout.links.append(door.info)
			Station:
				var action={"id":node.action_id,"room":room,"title":node.title,"kind":node.kind,"record":node.record,"custom_text":node.custom_text,"node":node}
				world.stations.append(action); world.layout.actions.append(action)
				if not world.state.data.containers.has(node.action_id): world.state.data.containers[node.action_id]=node.initial_contents.duplicate(true)
			Spawn:
				var enemy=preload("res://iso/zarya/enemy.gd").new(); enemy.world=world; enemy.id=node.spawn_id; enemy.spawn=node.global_position
				world.add_child(enemy); world.enemies.append(enemy)
	if not world.story_enabled and not world.state.data.get("map_spawned",false):
		var start: Vector3=world.player_start-world.ORIGIN
		world.state.data.position=[start.x,start.y,start.z]
		world.state.data["map_spawned"]=true
	for room in world.rooms.values():
		room.collect_walls()
		batch(room)
static func batch(room: Node3D) -> void:
	var groups: Dictionary={}
	for visual in room.find_children("*","MeshInstance3D",true,false):
		var p=visual.get_parent(); var keep:=false
		while p!=room and p!=null:
			if p.get_script() in [Piece,Lamp,preload("res://iso/capsule.gd")]: keep=true; break
			p=p.get_parent()
		if keep or visual.material_override==null: continue
		var material=visual.material_override
		if not material is StandardMaterial3D: continue
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
