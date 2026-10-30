extends Node3D
var world
var info:Dictionary
var opened:=false
var progress:=0.0
var leaf:CSGBox3D
var hinge:Node3D
var adjacent:Array=[]
var obstructed:=false
var sweep_shape:BoxShape3D
var guide_glow:MeshInstance3D
var guide_state := ""
var sight_seal:CollisionShape3D
func configure(source:CSGBox3D)->void:
 leaf=source
 for dz in [-1.2,1.2]:
  var room=world.room_at(global_transform*Vector3(0,0,dz))
  if not room.is_empty() and not adjacent.has(room):adjacent.append(room)
 var center_room=world.room_at(global_position)
 if not center_room.is_empty() and not adjacent.has(center_room):adjacent.append(center_room)
 var width=leaf.size.x
 for part in leaf.get_children():
  if part.name.begins_with("Рама") or part.name in ["Верх_рамы","Порог"]:part.reparent(self,true)
 hinge=Node3D.new();hinge.position=Vector3(-width/2,0,0);add_child(hinge)
 leaf.reparent(hinge,true)
 opened=bool(world.state.data.doors.get(info.id,false))
 if not world.state.data.has("door_progress"):world.state.data.door_progress={}
 progress=clampf(float(world.state.data.door_progress.get(info.id,1.0 if opened else 0.0)),0,1)
 if info.kind=="sealed":
  opened=false;progress=0;world.state.data.doors[info.id]=false;world.state.data.door_progress[info.id]=0.0
 hinge.rotation.y=-progress*PI/2
 sweep_shape=BoxShape3D.new();sweep_shape.size=leaf.size+Vector3(.18,.04,.18)
 # Close sub-player-width gaps between the authored jamb and the leaf for
 # eye rays. Layer 4 affects sight, not player movement or interaction rays.
 var seal=StaticBody3D.new();seal.name="SightSeal";seal.collision_layer=4;seal.collision_mask=0;add_child(seal)
 sight_seal=CollisionShape3D.new();var aperture=BoxShape3D.new();aperture.size=Vector3(width+.40,2.65,.62);sight_seal.shape=aperture;seal.add_child(sight_seal);sight_seal.disabled=progress>=.45
 preload("res://iso/maps/level2/door_readability.gd").build(self)
 preload("res://iso/maps/level2/door_readability.gd").sync(self)
func request()->String:
 if info.kind=="sealed":
  if not world.state.flag("relay_k2"):return "ШЛЮЗ БЕЗ ПИТАНИЯ / ВСТАВКА K-2 В МАСТЕРСКОЙ, УСТАНОВКА В ЭЛЕКТРОЩИТОВОЙ / 19"
  if not world.state.flag("pump_valve"):return "НЕТ ДАВЛЕНИЯ / ОТКРОЙТЕ РЕЗЕРВНЫЙ КЛАПАН В НАСОСНОЙ / 21"
  world.finish_bunker();return ""
 opened=not opened;obstructed=false;world.state.data.doors[info.id]=opened;world.save_state();return ""
func occupied(next_progress:float)->bool:
 var predicted=Transform3D(Basis(Vector3.UP,-next_progress*PI/2),hinge.position)
 var query=PhysicsShapeQueryParameters3D.new();query.shape=sweep_shape
 query.transform=global_transform*predicted*leaf.transform
 for hit in get_world_3d().direct_space_state.intersect_shape(query):
  if hit.collider==world.player:return true
 return false
func _process(delta:float)->void:
 if world==null or world.paused:return
 var next=move_toward(progress,1.0 if opened else 0.0,delta*1.5)
 if not is_equal_approx(next,progress) and occupied(next):
  if not obstructed:world.notify("ДВЕРЬ ОСТАНОВЛЕНА / ОСВОБОДИТЕ ПРОХОД")
  obstructed=true;return
 obstructed=false;progress=next
 if sight_seal.disabled!=(progress>=.45):sight_seal.set_deferred("disabled",progress>=.45)
 if hinge:hinge.rotation.y=-progress*PI/2
 world.state.data.door_progress[info.id]=progress
 preload("res://iso/maps/level2/door_readability.gd").sync(self)
func _exit_tree()->void:
 if guide_glow!=null:preload("res://iso/maps/level2/door_readability.gd").release()
