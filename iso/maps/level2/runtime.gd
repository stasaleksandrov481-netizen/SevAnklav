extends RefCounted
const Region=preload("res://iso/maps/level2/region.gd")
const Door=preload("res://iso/maps/level2/door.gd")
static func build(world:Node3D)->bool:
 # A cosmetic mask must never make the script fail to compile and leave the
 # independently created HUD running over an empty legacy world.
 world.startup_stage="Загрузка планировки"
 var path="res://iso/maps/level2/Zarya_Level_Minus_2.tscn"
 if not ResourceLoader.exists(path,"PackedScene"):
  world.startup_error="Не найден файл сцены бункера.";return false
 var scene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
 if scene==null:world.startup_error="Не удалось прочитать сцену бункера.";return false
 var regions_path="res://iso/maps/level2/regions.json"
 if not FileAccess.file_exists(regions_path):
  world.startup_error="Не найден план помещений: regions.json.";return false
 for data_path in ["res://iso/maps/level2/furnishing.json","res://iso/maps/level2/wall_sections.json"]:
  if not FileAccess.file_exists(data_path):world.startup_error="Не найден файл данных бункера: "+data_path.get_file();return false
 world.startup_stage="Проверка данных помещений"
 var specs=read_data(world,regions_path)
 if not specs is Array or specs.is_empty():
  if world.startup_error.is_empty():world.startup_error="Неверный план помещений: regions.json."
  return false
 var room_ids={}
 for entry in specs:
  if not entry is Dictionary or not entry.has_all(["id","title","x","z","width","depth","polygon"]) or not entry.id is String or room_ids.has(entry.id) or not entry.polygon is Array or entry.polygon.size()<3:
   world.startup_error="Неполные или повторяющиеся помещения в regions.json.";return false
  room_ids[entry.id]=true
  for field in ["x","z","width","depth"]:
   if not is_number(entry[field]):world.startup_error="Неверные размеры помещения в regions.json.";return false
  for point in entry.polygon:
   if not is_pair(point):world.startup_error="Неверная граница помещения в regions.json.";return false
 var furnishing=read_data(world,"res://iso/maps/level2/furnishing.json")
 if not furnishing is Dictionary or not furnishing.get("items") is Array or not furnishing.get("notes") is Array:
  if world.startup_error.is_empty():world.startup_error="Неверные данные обстановки: furnishing.json."
  return false
 for entry in furnishing.items:
  if not entry is Dictionary or not entry.has_all(["id","kind","x","z","angle"]) or not is_number(entry.x) or not is_number(entry.z) or not is_number(entry.angle):
   world.startup_error="Неполный предмет обстановки в furnishing.json.";return false
 var wall_data=read_data(world,"res://iso/maps/level2/wall_sections.json")
 if not wall_data is Dictionary or not wall_data.get("sections") is Array or wall_data.sections.is_empty() or wall_data.sections.size()>511:
  if world.startup_error.is_empty():world.startup_error="Неверные участки стен: wall_sections.json."
  return false
 for entry in wall_data.sections:
  if not entry is Dictionary or not is_pair(entry.get("a")) or not is_pair(entry.get("b")) or not is_pair(entry.get("normal")) or not is_number(entry.get("width")):
   world.startup_error="Неполный участок стены в wall_sections.json.";return false
 world.startup_stage="Создание геометрии"
 var map=scene.instantiate()
 if not map is Node3D:
  if map!=null:map.free()
  world.startup_error="Сцена бункера не содержит трёхмерную планировку.";return false
 for node in ["PlayerSpawn","Двери","WallMesh","SkirtMesh","CapMesh","FloorMesh","Свет","Окружение"]:
  if not map.has_node(node):map.free();world.startup_error="В сцене бункера отсутствует узел: "+node+".";return false
 for node in ["WallMesh","SkirtMesh","CapMesh","FloorMesh"]:
  if not map.get_node(node) is MeshInstance3D or map.get_node(node).mesh==null:
   map.free();world.startup_error="Не загружена геометрия бункера: "+node+".";return false
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
 world.startup_stage="Создание капсулы V-17"
 var capsule=preload("res://iso/maps/level2/start_capsule.gd").new()
 capsule.name="V17Capsule";capsule.position=Vector3(-27.2,0.06,-6.3);map.add_child(capsule)
 # Explicitly complete generation, including after a stale/delayed lifecycle
 # callback. Merely finding an empty Generated holder is not readiness.
 if capsule.has_method("ensure_built"):
  if not capsule.ensure_built():world.startup_error="Не удалось создать корпус и выход капсулы V-17.";return false
 elif not capsule.has_node("Generated/Glass shell"):capsule._rebuild()
 if not capsule.has_node("Generated/Glass shell"):
  world.startup_error="Не удалось создать корпус капсулы V-17.";return false
 var spawn=map.get_node("PlayerSpawn");spawn.position=Vector3(-27.2,0.96,-4.8);world.player_start=spawn.global_position
 if not world.state.data.get("map_spawned",false):world.state.data.position=[spawn.position.x,spawn.position.y,spawn.position.z];world.state.data.map_spawned=true
 world.startup_stage="Создание дверей"
 for source in map.get_node("Двери").get_children():
  if not source is CSGBox3D:continue
  var door=Door.new();door.name="Door_"+source.name;door.world=world
  var room=world.room_at(source.global_position)
  door.info={"id":str(source.name),"a":room,"b":room,"kind":"manual","lock":""}
  if str(source.name).contains("Выход_на_поверхность"):door.info.kind="sealed"
  var transform=source.global_transform;map.add_child(door);door.global_transform=transform
  door.configure(source);world.doors.append(door)
 world.startup_stage="Подготовка стен"
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
  # The original mesh is already a scene dependency. A missing optimization
  # resource must neither erase a wall nor abort the whole bunker.
  var mesh_path="res://iso/maps/level2/"+name+"Sections.res"
  var baked:Mesh
  if ResourceLoader.exists(mesh_path,"Mesh"):baked=load(mesh_path) as Mesh
  if baked==null:
   baked=recover_wall_mesh(map.get_node(name).mesh,wall_data.sections)
   var recovered:Array=world.get_meta("recovered_wall_meshes",[]);recovered.append(name);world.set_meta("recovered_wall_meshes",recovered)
  if baked==null:world.startup_error="Не удалось подготовить геометрию стены: "+name+".";return false
  map.get_node(name).mesh=baked
  map.get_node(name).material_override=material;cut_materials.append(material)
  # Keep the existing one-argument call compatible with an editor that still
  # holds the pre-update helper. Apply contact height to the native node here.
  var wall=map.get_node(name)
  preload("res://iso/maps/level2/opaque_shadow.gd").attach(wall)
  var shadow=wall.get_node_or_null("OpaqueShadow")
  if shadow!=null and wall.mesh.get_aabb().end.y>.18:shadow.scale.y=.18/wall.mesh.get_aabb().end.y
 world.startup_stage="Подготовка пола и проходов"
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
 world.startup_stage="Создание мебели и объектов"
 var furnishings=preload("res://iso/maps/level2/furniture.gd").new()
 furnishings.name="Furnishings";map.add_child(furnishings);furnishings.build(world)
 if furnishings.authored.size()<145 or world.stations.is_empty():
  world.startup_error="Не удалось загрузить обстановку и объекты бункера.";return false
 world.startup_stage="Подготовка освещения и звука"
 var atmosphere=preload("res://iso/maps/level2/atmosphere.gd").new()
 atmosphere.name="Atmosphere";map.add_child(atmosphere);atmosphere.build(world)
 world.startup_stage="Подготовка сюжетных объектов"
 var investigation=preload("res://iso/maps/level2/investigation.gd").new()
 investigation.name="Investigation";map.add_child(investigation);investigation.build(world)
 world.startup_stage="Проверка готовности бункера"
 if not map.has_node("V17Capsule/Generated/Glass shell"):
  world.startup_error="Капсула V-17 не завершила подготовку.";return false
 if world.rooms.size()!=specs.size():
  world.startup_error="Количество созданных помещений не совпало с планом бункера.";return false
 return true
static func read_data(world:Node3D,path:String)->Variant:
 var parser=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path))!=OK:
  world.startup_error="Повреждён файл "+path.get_file()+", строка "+str(parser.get_error_line())+": "+parser.get_error_message()
  return null
 return parser.data
static func is_number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func is_pair(value:Variant)->bool:return value is Array and value.size()==2 and is_number(value[0]) and is_number(value[1])
static func recover_wall_mesh(original:Mesh,sections:Array)->ArrayMesh:
 if original==null:return null
 var recovered=ArrayMesh.new()
 for surface in original.get_surface_count():
  var tool=SurfaceTool.new();tool.create_from(original,surface);tool.deindex()
  var arrays=tool.commit_to_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var colors=PackedColorArray();colors.resize(vertices.size())
  for first in range(0,vertices.size(),3):
   var center=(vertices[first]+vertices[first+1]+vertices[first+2])/3.0
   var nearest=0;var distance=INF
   for i in sections.size():
    var spec=sections[i];var a=Vector2(spec.a[0],spec.a[1]);var b=Vector2(spec.b[0],spec.b[1])
    var d=Geometry2D.get_closest_point_to_segment(Vector2(center.x,center.z),a,b).distance_squared_to(Vector2(center.x,center.z))
    if d<distance:distance=d;nearest=i
   var code=nearest+1;var color=Color(float(code/256)/255.0,float(code%256)/255.0,0)
   for i in 3:colors[first+i]=color
  arrays[Mesh.ARRAY_COLOR]=colors
  recovered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return recovered
