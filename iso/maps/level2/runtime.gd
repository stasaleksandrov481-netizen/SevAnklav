extends RefCounted
const Region=preload("res://iso/maps/level2/region.gd")
const Door=preload("res://iso/maps/level2/door.gd")
static func build(world:Node3D)->void:
 var map=preload("res://iso/maps/level2/Zarya_Level_Minus_2.tscn").instantiate()
 map.name="LevelMinusTwo";map.position=world.ORIGIN;world.add_child(map)
 world.custom_layout=true;world.story_enabled=true;world.state_key="zarya_layout3"
 world.state=world.State.new(world.get_node("/root/G").zsave,world.state_key)
 world.state.data.flags["power"]=true
 world.layout={"rooms":[],"links":[],"actions":[]}
 var specs=JSON.parse_string(FileAccess.get_file_as_string("res://iso/maps/level2/regions.json"))
 for entry in specs:
  var region=Region.new();region.room_id=entry.id;region.title=entry.title;region.name=entry.id
  region.position=Vector3(entry.x,0,entry.z);region.width=entry.width;region.depth=entry.depth
  for point in entry.polygon:region.polygon.append(Vector2(point[0]-entry.x,point[1]-entry.z))
  map.add_child(region);world.rooms[entry.id]=region;world.layout.rooms.append(entry)
 var capsule=preload("res://iso/maps/level2/start_capsule.gd").new()
 capsule.name="V17Capsule";capsule.position=Vector3(-27.2,0.06,-6.3);map.add_child(capsule)
 var spawn=map.get_node("PlayerSpawn");spawn.position=Vector3(-27.2,0.96,-4.8);world.player_start=spawn.global_position
 if not world.state.data.get("map_spawned",false):world.state.data.position=[spawn.position.x,spawn.position.y,spawn.position.z];world.state.data.map_spawned=true
 for source in map.get_node("Двери").get_children():
  if not source is CSGBox3D:continue
  var door=Door.new();door.name="Door_"+source.name;door.world=world
  var room=world.room_at(source.global_position)
  door.info={"id":str(source.name),"a":room,"b":room,"kind":"manual","lock":""}
  if str(source.name).contains("Выход_на_поверхность"):door.info.kind="sealed"
  var transform=source.global_transform;map.add_child(door);door.global_transform=transform
  door.configure(source);world.doors.append(door)
 var cut_materials=[]
 for name in ["WallMesh","SkirtMesh","CapMesh"]:
  var material=ShaderMaterial.new();material.shader=preload("res://iso/maps/level2/cutaway.gdshader")
  material.set_shader_parameter("concrete",preload("res://iso/maps/level2/textures/concrete_panels.png"))
  material.set_shader_parameter("origin",world.ORIGIN)
  material.set_shader_parameter("textured",name=="WallMesh")
  material.set_shader_parameter("tint",Vector3(0.64,0.70,0.72) if name=="WallMesh" else Vector3(0.2,0.27,0.31))
  map.get_node(name).material_override=material;cut_materials.append(material)
 var floor_material=ShaderMaterial.new();floor_material.shader=preload("res://iso/maps/level2/cutaway.gdshader")
 floor_material.set_shader_parameter("concrete",preload("res://iso/maps/level2/textures/floor.png"));floor_material.set_shader_parameter("floor_surface",true);floor_material.set_shader_parameter("tint",Vector3(0.6,0.67,0.69))
 map.get_node("FloorMesh").material_override=floor_material;cut_materials.append(floor_material)
 world.set_meta("cut_materials",cut_materials)
 # One shared mesh closes floor seams below all 25 existing doorway thresholds.
 var threshold_builder=SurfaceTool.new();threshold_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 for door in world.doors:
  var threshold=BoxMesh.new();threshold.size=Vector3(door.leaf.size.x-.02,.12,.8)
  var at:Transform3D=map.global_transform.affine_inverse()*door.global_transform;at.origin.y=0
  threshold_builder.append_from(threshold,0,at)
 var thresholds=MeshInstance3D.new();thresholds.name="DoorThresholds";thresholds.mesh=threshold_builder.commit();thresholds.material_override=floor_material
 map.add_child(thresholds);thresholds.create_trimesh_collision()
 # The original floor follows the former wall footprint. Fill the widened strip
 # and the server doorway so neither the visible floor nor collision has a gap.
 for spec in [[Vector3(5.47,0.12,1.77),Vector3(-13.915,0,1.715)],[Vector3(1.52,0.12,1.4),Vector3(-11.94,0,2.9)]]:
  var floor_patch=world.box(map,spec[0],spec[1],Color("#626969"),true)
  floor_patch.material_override=floor_material
 var furnishings=preload("res://iso/maps/level2/furniture.gd").new()
 furnishings.name="Furnishings";map.add_child(furnishings);furnishings.build(world)
 var atmosphere=preload("res://iso/maps/level2/atmosphere.gd").new()
 atmosphere.name="Atmosphere";map.add_child(atmosphere);atmosphere.build(world)
 var investigation=preload("res://iso/maps/level2/investigation.gd").new()
 investigation.name="Investigation";map.add_child(investigation);investigation.build(world)
