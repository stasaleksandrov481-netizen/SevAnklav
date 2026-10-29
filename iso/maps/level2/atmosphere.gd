extends Node3D
# Local machine beds and sparse authored incidents; respects the existing SFX bus.
var world
var sources: Array[AudioStreamPlayer3D] = []
var beacons: Array[OmniLight3D] = []
var pump: AudioStreamPlayer3D
var receiver: AudioStreamPlayer3D
var clock := 0.0
var event_clock := 0.0
var last_relay := false
var last_valve := false
var vapor: Array[CPUParticles3D]=[]
const VENT=preload("res://assets/audio/bunker/vent.wav")
const PUMP=preload("res://assets/audio/bunker/pump.wav")
const RELAY=preload("res://assets/audio/bunker/relay.wav")
const PIPE=preload("res://assets/audio/bunker/pipe.wav")
const RADIO=preload("res://assets/audio/bunker/radio.wav")
func receiver_noise(at: Vector3) -> void:
 if not is_instance_valid(receiver):receiver=sound(RADIO,to_local(at),-20)
 receiver.play()
func _exit_tree() -> void:
 for source in sources:
  if is_instance_valid(source):
   source.stop()
   source.stream=null
func sound(stream: AudioStreamWAV, at: Vector3, db: float, loop := false) -> AudioStreamPlayer3D:
 var source=AudioStreamPlayer3D.new();source.stream=stream.duplicate();source.position=at;source.bus="SFX";source.unit_size=3;source.max_distance=20;source.volume_db=db;source.max_db=-12
 if loop:
  source.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;source.stream.loop_begin=0;source.stream.loop_end=int(source.stream.get_length()*source.stream.mix_rate)
 add_child(source);sources.append(source)
 if loop:source.play()
 return source
func build(level: Node3D) -> void:
 world=level
 if not world.state.data.has("environment_events"):world.state.data.environment_events={}
 for at in [Vector3(-29,2.4,-8),Vector3(-8,2.4,-10),Vector3(14,2.4,-9),Vector3(19,2.4,0)]:sound(VENT,at,-26,true)
 pump=sound(PUMP,Vector3(11,0.8,7),-31,true)
 for at in [Vector3(12,2.3,1.8),Vector3(23,2.3,-5),Vector3(-6,2.3,8)]:
  var light=OmniLight3D.new();light.position=at;light.light_color=Color("#d94c3d");light.omni_range=3;light.light_energy=0.22;light.shadow_enabled=false;add_child(light);beacons.append(light)
 last_relay=world.state.flag("relay_k2");last_valve=world.state.flag("pump_valve")
 world.state.changed.connect(on_state_changed)
 build_vapor()
func build_vapor() -> void:
 var gradient=Gradient.new();gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
 var texture=GradientTexture2D.new();texture.gradient=gradient;texture.width=32;texture.height=32;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.albedo_texture=texture;material.vertex_color_use_as_albedo=true
 var mesh=QuadMesh.new();mesh.size=Vector2(.3,.3);mesh.material=material
 for id in ["relay_k2","pump_valve"]:
  var action: Dictionary=world.stations.filter(func(a):return a.id==id)[0]
  var emitter=CPUParticles3D.new();emitter.name="RelayHaze" if id=="relay_k2" else "PipeVapor";emitter.mesh=mesh;emitter.amount=8;emitter.lifetime=2.2;emitter.emitting=false;emitter.visible=false
  emitter.direction=Vector3.UP;emitter.spread=18;emitter.gravity=Vector3(.02,.06,0);emitter.initial_velocity_min=.08;emitter.initial_velocity_max=.18;emitter.scale_amount_min=.5;emitter.scale_amount_max=1.4;emitter.color=Color(.65,.75,.78,.28);emitter.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  emitter.position=to_local(action.node.global_position)+Vector3(.1,.1,.08);emitter.set_meta("room",action.room);emitter.set_meta("repair",id);add_child(emitter);vapor.append(emitter)
func sync_vapor() -> void:
 if world==null:return
 var controller=world.visibility_controller
 var allowed: bool=controller!=null and controller.profile!="low" and bool(world.get_node("/root/G").zsave.get("bunker_visual",{}).get("particles",true))
 for emitter in vapor:
  var enabled: bool=allowed and controller.active==str(emitter.get_meta("room")) and not world.state.flag(str(emitter.get_meta("repair")))
  emitter.visible=enabled
  if emitter.emitting!=enabled:emitter.emitting=enabled
  emitter.speed_scale=0.0 if world.paused or not enabled else .65
func on_state_changed() -> void:
 var relay:bool=world.state.flag("relay_k2");var valve:bool=world.state.flag("pump_valve")
 if relay and not last_relay:sound(RELAY,Vector3(-6.5,1,9),-14).play()
 if valve and not last_valve:sound(RELAY,Vector3(10.5,1,6),-17).play()
 last_relay=relay;last_valve=valve
 sync_vapor()
func _process(delta: float) -> void:
 if world==null:return
 for source in sources:source.stream_paused=world.paused
 for emitter in vapor:emitter.speed_scale=0.0 if world.paused or not emitter.visible else .65
 if world.paused:return
 clock+=delta;event_clock+=delta
 for i in range(beacons.size()):
  var restored=world.state.flag("pump_valve") if i<2 else world.state.flag("relay_k2")
  var brightness: float=world.visibility_controller.brightness if world.visibility_controller!=null else 1.0
  beacons[i].light_energy=(0.06 if restored else 0.10+0.16*pow(maxf(0,sin(clock*2.0+i)),4))*brightness
  beacons[i].visible=world.visibility_controller!=null and str(beacons[i].get_meta("room_id",""))==world.visibility_controller.active
 pump.volume_db=move_toward(pump.volume_db,-23.0 if world.state.flag("pump_valve") else -31.0,delta*4)
 if event_clock<0.4:return
 event_clock=0
 # One restrained pipe knock on the first entry to the technical wing, never a jump-scare loop.
 if not world.state.data.environment_events.get("pipe_settle",false) and world.player.global_position.distance_to(global_position+Vector3(10,1,7))<7:
  world.state.data.environment_events.pipe_settle=true;sound(PIPE,Vector3(13,1.4,7),-24).play();world.save_state()
