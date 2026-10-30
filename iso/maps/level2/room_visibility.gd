extends Node3D
# One rendered sector; physics, inventories, flags and enemy logic stay alive.
var world
var active := ""
var visuals := {}
var lamps := []
var shader_materials := []
var reveal := 1.0
var elapsed := 0.0
var room_texture = preload("res://iso/maps/level2/room_ids.png")
var fallback: OmniLight3D
var profile := "balanced"
var budget := 1
var shader_point := Vector3.INF
var shader_camera := Vector3.INF
var shader_reveal := -1.0
var brightness:=1.0
var environment: Environment
var room_lights: Array=[]
func room_for(point: Vector3) -> String:
 var id: String=world.room_at(point)
 if not id.is_empty():return id
 var local: Vector3=point-world.ORIGIN
 var nearest := ""
 var best := 1.1
 for entry in world.layout.rooms:
  var poly: Array=entry.polygon
  for i in range(poly.size()):
   var a=Vector2(poly[i][0],poly[i][1]);var b=Vector2(poly[(i+1)%poly.size()][0],poly[(i+1)%poly.size()][1])
   var distance=Geometry2D.get_closest_point_to_segment(Vector2(local.x,local.z),a,b).distance_to(Vector2(local.x,local.z))
   if distance<best:best=distance;nearest=entry.id
 return nearest
func register_visual(node: Node3D, id: String) -> void:
 if id.is_empty():id=room_for(node.global_position)
 if not visuals.has(id):visuals[id]=[]
 visuals[id].append(node)
 node.visible=false
func add_material(material: ShaderMaterial) -> void:
 material.set_shader_parameter("room_ids",room_texture)
 material.set_shader_parameter("origin",world.ORIGIN)
 shader_materials.append(material)
func build(level: Node3D) -> void:
 world=level
 var map=world.get_node("LevelMinusTwo")
 for n in map.get_node("Furnishings").get_children():
  if n is VisualInstance3D or (n is Node3D and n.get_meta("room_visual",false)):register_visual(n,str(n.get_meta("room_id",room_for(n.global_position))))
 var capsule=map.get_node("V17Capsule")
 register_visual(capsule,"sector_0")
 for source in map.get_node("Свет").get_children():
  if source is DirectionalLight3D:source.visible=false
  elif source is OmniLight3D:
   source.set_meta("room_id",room_for(source.global_position));source.set_meta("base_energy",source.light_energy)
   source.visible=false;source.shadow_enabled=false;lamps.append(source)
  elif source is GeometryInstance3D:register_visual(source,room_for(source.global_position))
 for light in map.get_node("Atmosphere").beacons:
  light.set_meta("room_id",room_for(light.global_position));light.visible=false;lamps.append(light)
 var env=map.get_node("Окружение").environment
 environment=env;add_to_group("bunker_visual_preferences")
 env.background_color=Color.BLACK;env.ambient_light_color=Color("#8299a7");env.ambient_light_energy=0.13
 fallback=OmniLight3D.new();fallback.light_color=Color("#9abac8");fallback.omni_range=4.8;fallback.light_energy=0.8;fallback.shadow_enabled=false;add_child(fallback)
 # Shader masks make even the floor of an unentered sector exactly black.
 for material in world.get_meta("cut_materials",[]):add_material(material)
 for patch in map.get_children():
  if patch is MeshInstance3D and patch.material_override is ShaderMaterial and not shader_materials.has(patch.material_override):add_material(patch.material_override)
 var f=map.get_node("Furnishings")
 for material in f.materials.values():
  if material is ShaderMaterial:add_material(material)
 set_profile(str(world.state.data.get("graphics_profile","balanced")))
 apply_preferences()
 switch_room(room_for(world.player.global_position))
func apply_preferences() -> void:
 brightness=clampf(float(world.get_node("/root/G").zsave.get("bunker_visual",{}).get("brightness",1.0)),.75,1.3)
 if environment:environment.ambient_light_energy=.13*brightness
 world.player.torch.light_energy=2.2*brightness
 refresh_lights()
 world.get_node("LevelMinusTwo/Atmosphere").sync_vapor()
func set_profile(value: String) -> void:
 profile=value if value in ["low","balanced","quality"] else "balanced"
 budget={"low":0,"balanced":1,"quality":2}[profile]
 var viewport=world.get_viewport()
 viewport.msaa_3d=Viewport.MSAA_DISABLED if profile!="quality" else Viewport.MSAA_2X
 viewport.scaling_3d_scale={"low":0.65,"balanced":0.85,"quality":1.0}[profile]
 world.player.torch.shadow_enabled=profile=="quality"
 viewport.positional_shadow_atlas_size=1024 if profile=="low" else (4096 if profile=="quality" else 2048)
 world.state.data["graphics_profile"]=profile
 elapsed=1
 refresh_lights()
 world.get_node("LevelMinusTwo/Atmosphere").sync_vapor()
func switch_room(id: String) -> void:
 if id.is_empty() or id==active:return
 active=id;world.current=id;world.room_visible={id:true};world.state.data.visited[id]=true
 reveal=0.12
 _select_room_lights()
 for owner in visuals:
  for n in visuals[owner]:n.visible=active in owner.split("+")
 for m in shader_materials:m.set_shader_parameter("active_room",float(id.trim_prefix("sector_").to_int()+1))
 for entry in world.get_node("LevelMinusTwo/Investigation").markers.values():entry.node.visible=false
 for enemy in world.enemies:enemy.refresh_visibility()
 for door in world.doors:door.visible=active in door.adjacent
 refresh_lights()
 world.get_node("LevelMinusTwo/Atmosphere").sync_vapor()
func _select_room_lights() -> void:
 # Fixed room coordinates, never the moving player: no source swaps mid-room.
 var center: Vector3=world.rooms[active].global_position
 room_lights=lamps.filter(func(light):return str(light.get_meta("room_id",""))==active and light.has_meta("base_energy"))
 room_lights.sort_custom(func(a,b):
  var a_red: bool=a.light_color.r>a.light_color.b*1.35
  var b_red: bool=b.light_color.r>b.light_color.b*1.35
  if a_red!=b_red:return not a_red
  var da: float=a.global_position.distance_squared_to(center)
  var db: float=b.global_position.distance_squared_to(center)
  return str(a.name)<str(b.name) if is_equal_approx(da,db) else da<db)
 for light in room_lights:
  light.shadow_bias=.025;light.shadow_normal_bias=.25
 fallback.global_position=center+Vector3(0,1.65,0)
func refresh_lights() -> void:
 var remaining: int=maxi(0,budget-int(world.player.torch.visible and world.player.torch.shadow_enabled))
 for light in lamps:
  var index: int=room_lights.find(light)
  var in_room: bool=str(light.get_meta("room_id",""))==active
  light.visible=in_room and (index<3 if light.has_meta("base_energy") else true)
  var casts: bool=light.visible and index>=0 and index<remaining
  if light.shadow_enabled!=casts:light.shadow_enabled=casts
  if index>=0:
   light.light_color=Color("#ba493c") if light.light_color.r>light.light_color.b*1.35 else Color("#a2c0d0")
   light.light_energy=float(light.get_meta("base_energy"))*1.05*brightness
 fallback.visible=true;fallback.light_energy=(0.75 if room_lights.is_empty() else 0.26)*brightness
func _process(delta: float) -> void:
 if world==null or world.paused:return
 elapsed+=delta
 if elapsed>0.1:
  elapsed=0
  switch_room(room_for(world.player.global_position))
  refresh_lights()
  for enemy in world.enemies:enemy.refresh_visibility()
 reveal=move_toward(reveal,1.0,delta*3.5)
 var camera: Vector3=world.get_node("Camera").global_position
 if shader_point.distance_squared_to(world.player.global_position)>.0001 or shader_camera.distance_squared_to(camera)>.0001 or shader_reveal!=reveal:
  for m in shader_materials:
   m.set_shader_parameter("reveal",reveal)
   m.set_shader_parameter("player_position",world.player.global_position)
   m.set_shader_parameter("camera_position",camera)
  shader_point=world.player.global_position;shader_camera=camera;shader_reveal=reveal
