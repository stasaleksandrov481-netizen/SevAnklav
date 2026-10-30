extends RefCounted
const Region=preload("res://iso/maps/level2/region.gd")
const Door=preload("res://iso/maps/level2/door.gd")
static func build(world:Node3D)->bool:
 # A cosmetic mask must never make the script fail to compile and leave the
 # independently created HUD running over an empty legacy world.
 var path="res://iso/maps/level2/Zarya_Level_Minus_2.tscn"
 if not ResourceLoader.exists(path,"PackedScene"):
  world.startup_error="Не найден файл сцены бункера.";return false
 var scene=load(path) as PackedScene
 if scene==null:world.startup_error="Не удалось прочитать сцену бункера.";return false
 var regions_path="res://iso/maps/level2/regions.json"
 if not FileAccess.file_exists(regions_path):
  world.startup_error="Не найден план помещений: regions.json.";return false
 for data_path in ["res://iso/maps/level2/furnishing.json","res://iso/maps/level2/wall_sections.json"]:
  if not FileAccess.file_exists(data_path):world.startup_error="Не найден файл данных бункера: "+data_path.get_file();return false
 var specs=JSON.parse_string(FileAccess.get_file_as_string(regions_path))
 if not specs is Array or specs.is_empty():
  world.startup_error="Не удалось прочитать план помещений бункера.";return false
 var map=scene.instantiate()
 map.name="LevelMinusTwo";map.position=world.ORIGIN;world.add_child(map)
 world.custom_layout=true;world.story_enabled=true;world.state_key="zarya_layout3"
 world.state=world.State.new(world.get_node("/root/G").zsave,world.state_key)
 world.state.data.flags["power"]=true
 world.layout={"rooms":[],"links":[],"actions":[]}
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
 var section_map:Texture2D
 var section_path="res://iso/maps/level2/wall_section_ids.png"
 if ResourceLoader.exists(section_path,"Texture2D"):section_map=load(section_path) as Texture2D
 world.set_meta("wall_section_map_fallback",section_map==null)
 for name in ["WallMesh","SkirtMesh","CapMesh"]:
  var material=ShaderMaterial.new();material.shader=preload("res://iso/maps/level2/wall_sections.gdshader")
  material.set_shader_parameter("concrete",preload("res://iso/maps/level2/textures/concrete_panels.png"))
  material.set_shader_parameter("use_section_map",section_map!=null)
  if section_map!=null:material.set_shader_parameter("section_ids",section_map)
  material.set_shader_parameter("origin",world.ORIGIN)
  material.set_shader_parameter("textured",name=="WallMesh")
  material.set_shader_parameter("boundary_padding",.55)
  material.set_shader_parameter("tint",Vector3(0.64,0.70,0.72) if name=="WallMesh" else Vector3(0.2,0.27,0.31))
  map.get_node(name).mesh=load("res://iso/maps/level2/"+name+"Sections.res")
  map.get_node(name).material_override=material;cut_materials.append(material)
  # Keep the existing one-argument call compatible with an editor that still
  # holds the pre-update helper. Apply contact height to the native node here.
  var wall=map.get_node(name)
  preload("res://iso/maps/level2/opaque_shadow.gd").attach(wall)
  var shadow=wall.get_node_or_null("OpaqueShadow")
  if shadow!=null and wall.mesh.get_aabb().end.y>.18:shadow.scale.y=.18/wall.mesh.get_aabb().end.y
 var floor_material=ShaderMaterial.new();floor_material.shader=preload("res://iso/maps/level2/cutaway.gdshader")
 floor_material.set_shader_parameter("concrete",preload("res://iso/maps/level2/textures/floor.png"));floor_material.set_shader_parameter("floor_surface",true);floor_material.set_shader_parameter("tint",Vector3(0.6,0.67,0.69))
 map.get_node("FloorMesh").material_override=floor_material;cut_materials.append(floor_material)
 world.set_meta("cut_materials",cut_materials)
 # One shared mesh closes floor seams below all 25 existing doorway thresholds.
 var threshold_builder=SurfaceTool.new();threshold_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 for door in world.doors:
  var threshold=BoxMesh.new();threshold.size=Vector3(door.leaf.size.x-.02,.12,.8)
  var at:Transform3D=map.global_transform.affine_inverse()*door.global_transform;at.origin.y=-.06
  threshold_builder.append_from(threshold,0,at)
 var thresholds=MeshInstance3D.new();thresholds.name="DoorThresholds";thresholds.mesh=threshold_builder.commit();thresholds.material_override=floor_material
 map.add_child(thresholds);thresholds.create_trimesh_collision()
 # The original floor follows the former wall footprint. Fill the widened strip
 # and the server doorway so neither the visible floor nor collision has a gap.
 for spec in [[Vector3(5.47,0.12,1.77),Vector3(-13.915,-.06,1.715)],[Vector3(1.52,0.12,1.4),Vector3(-11.94,-.06,2.9)]]:
  var floor_patch=world.box(map,spec[0],spec[1],Color("#626969"),true)
  floor_patch.material_override=floor_material
 var furnishings=preload("res://iso/maps/level2/furniture.gd").new()
 furnishings.name="Furnishings";map.add_child(furnishings);furnishings.build(world)
 if furnishings.authored.size()<145 or world.stations.is_empty():
  world.startup_error="Не удалось загрузить обстановку и объекты бункера.";return false
 var atmosphere=preload("res://iso/maps/level2/atmosphere.gd").new()
 atmosphere.name="Atmosphere";map.add_child(atmosphere);atmosphere.build(world)
 var investigation=preload("res://iso/maps/level2/investigation.gd").new()
 investigation.name="Investigation";map.add_child(investigation);investigation.build(world)
 return map.has_node("V17Capsule/Generated") and world.rooms.size()==specs.size()
