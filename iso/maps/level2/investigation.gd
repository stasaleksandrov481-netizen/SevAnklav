extends Node3D
# Environmental inspection and sparse text reactions; no new levels or mandatory terminals.
var world
var markers := {}
var clock := 0.0
var quiet_time := 0.0
var marker_clock := 0.0
const REACTIONS = {
 "identity_v17":"Волков… Это моё имя. Но почему здесь написано «смерть»?",
 "shift":"Она следила за мной ещё до аварии.",
 "guard_log":"Эвакуацию отменили. Значит, они не смогли просто уйти.",
 "gromov":"Охрана боялась тех, кто уже был внутри.",
 "technician":"Сначала вставка. Потом клапан. Ошибиться здесь нельзя.",
 "archive_chat":"Они пытались сохранить журнал.",
 "lab_observation":"Новые связи… Что тогда осталось от меня?",
 "quarantine_note":"Они ждали смену. Сколько времени?"
}
func build(level: Node3D) -> void:
 world=level
 if not world.state.data.has("investigation_seen"):world.state.data.investigation_seen={}
 if not world.state.data.has("pending_reactions"):world.state.data.pending_reactions=[]
 for action in world.stations:
  if action.kind not in ["evidence","inspect"]:continue
  var marker=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=0.12;mesh.outer_radius=0.16;mesh.rings=16;mesh.ring_segments=6;marker.mesh=mesh
  var m=StandardMaterial3D.new();m.albedo_color=Color("#d2bb83");m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=.2;marker.material_override=m
  add_child(marker);marker.global_position=action.node.global_position+Vector3.UP*.03
  marker.visible=false;markers[action.id]={"node":marker,"action":action}
func seen(action: Dictionary) -> bool:
 return world.state.data.records.has(action.id) or bool(world.state.data.investigation_seen.get(action.id,false))
func queue_reaction(id: String, line: String) -> void:
 if line.is_empty() or world.state.data.investigation_seen.get(id,false):return
 world.state.data.investigation_seen[id]=true
 world.state.data.pending_reactions.append(line)
 quiet_time=0
func discover(action: Dictionary) -> void:
 if not world.state.data.records.has(action.id):queue_reaction(action.id,REACTIONS.get(action.id,""))
func inspect(action: Dictionary) -> void:
 if world.state.data.investigation_seen.get(action.id,false):
  world.notify("УЖЕ ОСМОТРЕНО / "+action.title);return
 queue_reaction(action.id,action.observation)
 if action.has("body"):world.state.data.records[action.id]={"title":action.title,"body":action.body}
 if action.id=="broken_receiver":world.get_node("LevelMinusTwo/Atmosphere").receiver_noise(action.node.global_position)
 world.save_state()
func _process(delta: float) -> void:
 if world==null or world.hud==null:return
 clock+=delta
 var blocked=world.paused or world.hud.modal!=null or world.player.locked
 marker_clock+=delta
 for entry in (markers.values() if marker_clock>=0.12 else []):
  entry.node.visible=not blocked and not seen(entry.action) and world.can_interact_from(entry.action,world.player.global_position,4.5)
  if entry.node.visible:entry.node.material_override.emission_energy_multiplier=.15+.15*(.5+.5*sin(clock*2))
 if marker_clock>=0.12:marker_clock=0
 if blocked or world.hud.timer>0:
  quiet_time=0;return
 quiet_time+=delta
 if quiet_time<.5 or world.state.data.pending_reactions.is_empty():return
 var line: String=world.state.data.pending_reactions.pop_front()
 world.notify("Волков: «"+line+"»")
 quiet_time=0;world.save_state()
