extends Node3D
var world
var active := ""
var visuals := {}
var lamps := []
var shader_materials := []
var reveal := 1.0
var elapsed := 0.0
var room_texture=preload("res://iso/maps/level2/room_ids.png")
var fallback:OmniLight3D
var profile := "balanced"
var budget := 1
var brightness := 1.0
var environment:Environment
var room_lights:Array=[]
var visible_rooms:Dictionary={}
var known_image:Image
var known_texture:ImageTexture
var sight=preload("res://iso/maps/level2/field_of_view.gd").new()
var shader_point := Vector3.INF
var shader_camera := Vector3.INF
var shader_reveal := -1.0
var wall_controller
func room_for(point:Vector3)->String:
 var id:String=world.room_at(point)
 if not id.is_empty():return id
 var local:Vector3=point-world.ORIGIN
 var nearest := "";var best := 1.1
 for entry in world.layout.rooms:
  var poly:Array=entry.polygon
  for i in poly.size():
   var a=Vector2(poly[i][0],poly[i][1]);var b=Vector2(poly[(i+1)%poly.size()][0],poly[(i+1)%poly.size()][1])
   var distance=Geometry2D.get_closest_point_to_segment(Vector2(local.x,local.z),a,b).distance_to(Vector2(local.x,local.z))
   if distance<best:best=distance;nearest=entry.id
 return nearest
func register_visual(node:Node3D,id:String)->void:
 if id.is_empty():id=room_for(node.global_position)
 if not visuals.has(id):visuals[id]=[]
 visuals[id].append(node);node.visible=false
 # Remembered interiors use opaque native materials, independently of the
 # per-fragment discovery mask. The mask is only needed for a doorway preview.
 var meshes=[]
 if node is MeshInstance3D:meshes.append(node)
 meshes.append_array(node.find_children("*","MeshInstance3D",true,false))
 var furniture=world.get_node("LevelMinusTwo/Furnishings")
 var masked=[]
 for mesh in meshes:
  var m=mesh.material_override
  if not m is ShaderMaterial or m.shader!=preload("res://iso/maps/level2/furniture_visibility.gdshader"):continue
  mesh.set_meta("preview_material",m)
  mesh.set_meta("known_material",furniture.native_material(m.get_shader_parameter("color"),int(m.get_shader_parameter("surface_tile"))))
  mesh.set_meta("remembered_material",furniture.native_material(m.get_shader_parameter("color"),int(m.get_shader_parameter("surface_tile")),true))
  masked.append(mesh)
 node.set_meta("masked_meshes",masked)
func add_material(material:ShaderMaterial)->void:
 material.set_shader_parameter("room_ids",room_texture);material.set_shader_parameter("origin",world.ORIGIN)
 material.set_shader_parameter("known_rooms",known_texture);material.set_shader_parameter("visibility_map",sight.texture)
 shader_materials.append(material)
func build(level:Node3D)->void:
 world=level;sight.setup(world)
 if room_for(world.player.global_position)=="sector_0":world.state.data.visited["sector_0"]=true
 known_image=Image.create(64,1,false,Image.FORMAT_RGBA8);known_image.fill(Color.BLACK);known_texture=ImageTexture.create_from_image(known_image)
 var map=world.get_node("LevelMinusTwo")
 for n in map.get_node("Furnishings").get_children():
  if n is VisualInstance3D or (n is Node3D and n.get_meta("room_visual",false)):register_visual(n,str(n.get_meta("room_id",room_for(n.global_position))))
 register_visual(map.get_node("V17Capsule"),"sector_0")
 for source in map.get_node("Свет").get_children():
  if source is DirectionalLight3D:source.visible=false
  elif source is OmniLight3D:
   source.set_meta("room_id",room_for(source.global_position));source.set_meta("base_energy",source.light_energy);source.set_meta("base_color",source.light_color)
   source.visible=false;source.shadow_enabled=false;lamps.append(source)
  elif source is GeometryInstance3D:register_visual(source,room_for(source.global_position))
 for light in map.get_node("Atmosphere").beacons:
  light.set_meta("room_id",room_for(light.global_position));light.visible=false;lamps.append(light)
 environment=map.get_node("Окружение").environment;environment.background_color=Color.BLACK;environment.ambient_light_color=Color("#8299a7")
 add_to_group("bunker_visual_preferences")
 fallback=OmniLight3D.new();fallback.light_color=Color("#9abac8");fallback.omni_range=7;fallback.shadow_enabled=false;add_child(fallback)
 for material in world.get_meta("cut_materials",[]):add_material(material)
 for patch in map.get_children():
  if patch is MeshInstance3D and patch.material_override is ShaderMaterial and not shader_materials.has(patch.material_override):add_material(patch.material_override)
 for material in map.get_node("Furnishings").materials.values():
  if material is ShaderMaterial:add_material(material)
 wall_controller=preload("res://iso/maps/level2/wall_sections.gd").new();wall_controller.setup(world)
 for material in shader_materials:
  if material.shader==preload("res://iso/maps/level2/wall_sections.gdshader"):material.set_shader_parameter("wall_states",wall_controller.texture)
 set_profile(str(world.state.data.get("graphics_profile","balanced")));apply_preferences();switch_room(room_for(world.player.global_position))
func remember_room(id:String)->void:
 if int(id.trim_prefix("sector_"))>16:return
 # A threshold is a connection, not a new empty room. Enter fully before the
 # whole interior is committed; looking through a door only reveals live sight.
 for offset in [Vector3(.38,0,0),Vector3(-.38,0,0),Vector3(0,0,.38),Vector3(0,0,-.38)]:
  if world.room_at(world.player.global_position+offset)!=id:return
 world.state.data.visited[id]=true
func update_known()->void:
 known_image.fill(Color.BLACK)
 for id in world.state.data.visited:
  var index=int(str(id).trim_prefix("sector_"))
  if index>16 or not world.state.data.visited[id]:continue
  var weight=1.0 if id==active else .65
  known_image.set_pixel(index+1,0,Color(weight,weight,weight,1))
 known_texture.update(known_image)
func refresh_sight()->void:
 remember_room(active);update_known();sight.update({"low":60,"balanced":88,"quality":120}[profile])
 visible_rooms=sight.visible_rooms.duplicate()
 for id in world.state.data.visited:
  if int(str(id).trim_prefix("sector_"))<=16 and world.state.data.visited[id]:visible_rooms[id]=true
 if not active.is_empty():visible_rooms[active]=true
 world.room_visible=visible_rooms.duplicate()
 for owner in visuals:
  var show=false
  for id in owner.split("+"):
   if visible_rooms.has(id):show=true
  var known=false
  var current=false
  for id in owner.split("+"):
   if int(id.trim_prefix("sector_"))<=16 and world.state.data.visited.get(id,false):known=true
   if id==active:current=true
  for node in visuals[owner]:
   for mesh in node.get_meta("masked_meshes",[]):
    var m=mesh.get_meta("known_material" if current else "remembered_material") if known else mesh.get_meta("preview_material")
    if mesh.material_override!=m:mesh.material_override=m
   var clipped=node is MeshInstance3D and node.has_meta("preview_material")
   node.visible=show and (known or clipped or sight.visible_at(node.global_position))
 for door in world.doors:
  door.visible=sight.visible_at(door.global_position)
  for id in door.adjacent:
   if int(str(id).trim_prefix("sector_"))<=16 and world.state.data.visited.get(id,false):door.visible=true
 for enemy in world.enemies:enemy.refresh_visibility()
 refresh_lights()
func can_see(point:Vector3)->bool:return sight.can_see(point)
func apply_preferences()->void:
 brightness=clampf(float(world.get_node("/root/G").zsave.get("bunker_visual",{}).get("brightness",1.0)),.75,1.3)
 if environment:environment.ambient_light_energy=.18*brightness
 world.player.torch.light_energy=2.2*brightness;refresh_lights();world.get_node("LevelMinusTwo/Atmosphere").sync_vapor()
func set_profile(value:String)->void:
 profile=value if value in ["low","balanced","quality"] else "balanced";budget={"low":0,"balanced":1,"quality":2}[profile]
 var viewport=world.get_viewport();viewport.msaa_3d=Viewport.MSAA_2X if profile=="quality" else Viewport.MSAA_DISABLED
 viewport.scaling_3d_scale={"low":.65,"balanced":.85,"quality":1.0}[profile]
 world.player.torch.shadow_enabled=profile=="quality";viewport.positional_shadow_atlas_size=1024 if profile=="low" else (4096 if profile=="quality" else 2048)
 world.state.data.graphics_profile=profile;elapsed=1;refresh_lights();world.get_node("LevelMinusTwo/Atmosphere").sync_vapor()
func switch_room(id:String)->void:
 if id.is_empty():return
 if id!=active:active=id;world.current=id;_select_room_lights()
 refresh_sight();world.get_node("LevelMinusTwo/Atmosphere").sync_vapor()
func _select_room_lights()->void:
 var center:Vector3=world.rooms[active].global_position
 room_lights=lamps.filter(func(light):return str(light.get_meta("room_id",""))==active and light.has_meta("base_energy"))
 room_lights.sort_custom(func(a,b):return a.global_position.distance_squared_to(center)<b.global_position.distance_squared_to(center))
 for light in room_lights:light.shadow_bias=.025;light.shadow_normal_bias=.25
 fallback.global_position=center+Vector3(0,1.65,0)
func refresh_lights()->void:
 if world==null:return
 var remaining=maxi(0,budget-int(world.player.torch.visible and world.player.torch.shadow_enabled))
 var extra=0;var limit={"low":2,"balanced":4,"quality":6}[profile]
 for light in lamps:
  var id:String=str(light.get_meta("room_id",""));var index=room_lights.find(light)
  var own=id==active and (index<3 if light.has_meta("base_energy") else true)
  var neighbour=not own and visible_rooms.has(id) and light.global_position.distance_to(fallback.global_position)<16 and extra<limit
  light.visible=own or neighbour
  if neighbour:extra+=1
  light.shadow_enabled=own and index>=0 and index<remaining
  if light.has_meta("base_energy"):
   var base:Color=light.get_meta("base_color")
   light.light_color=Color("#ba493c") if base.r>base.b*1.35 else Color("#a2c0d0")
   light.light_energy=float(light.get_meta("base_energy"))*brightness*(1.05 if own else .65)
 fallback.visible=not active.is_empty();fallback.light_energy=(.55 if room_lights.is_empty() else .30)*brightness
func _process(delta:float)->void:
 if world==null or world.paused:return
 elapsed+=delta
 if elapsed>=({"low":.18,"balanced":.125,"quality":.10}[profile]):
  elapsed=0;switch_room(room_for(world.player.global_position))
 if wall_controller!=null:wall_controller.update(delta)
