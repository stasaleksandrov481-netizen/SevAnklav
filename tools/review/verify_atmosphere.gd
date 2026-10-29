extends SceneTree
func _initialize():call_deferred("verify")
func approach(w,action):
 w.paused=false;w.player.locked=false
 w.visibility_controller.switch_room(action.room)
 var q=PhysicsShapeQueryParameters3D.new();q.shape=w.player.get_node("Collision").shape;q.exclude=[w.player.get_rid()]
 for x in range(-8,9):
  for z in range(-8,9):
   var at:Vector3=action.node.global_position+Vector3(x*.25,0,z*.25);at.y=1
   q.transform=Transform3D(Basis.IDENTITY,at)
   if w.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty() and w.can_interact_from(action,at):w.player.global_position=at;return
 assert(false,"Action inaccessible")
func verify():
 var game=root.get_node("G");game.set_meta("qa8",true);game.zsave=game._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(game.zsave,"zarya_layout3");prior.data.awake=true
 var scene=load("res://iso/bunker_world.tscn");var w=scene.instantiate();root.add_child(w)
 for i in range(30):await physics_frame
 w.paused=true;w.player.set_physics_process(false)
 var env=w.get_node("LevelMinusTwo/Atmosphere")
 assert(env.sources.size()==5)
 for source in env.sources:
  assert(source.bus=="SFX");assert(source.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 var note=w.stations.filter(func(a):return a.kind=="evidence")[0]
 assert(w.hud.interaction_text(note).begins_with("ПРОЧИТАТЬ"))
 approach(w,note);w.interact(note);assert(w.hud.interaction_text(note).begins_with("В КПК"));w.hud.close_modal();w.paused=true
 var relay=w.stations.filter(func(a):return a.id=="relay_k2")[0]
 var valve=w.stations.filter(func(a):return a.id=="pump_valve")[0]
 approach(w,relay);w.state.give("fuse");w.interact(relay);w._advance_repair(1)
 assert(not w.state.flag("relay_k2") and w.state.amount("fuse")==1)
 w.notification(Node.NOTIFICATION_APPLICATION_PAUSED);assert(w.repair_action.is_empty() and w.state.amount("fuse")==1)
 w.hud.close_modal()
 w.interact(relay);w._advance_repair(w.REPAIR_SECONDS);assert(w.state.flag("relay_k2") and w.state.amount("fuse")==0)
 approach(w,valve);w.interact(valve);w._advance_repair(w.REPAIR_SECONDS);assert(w.state.flag("pump_valve"))
 w.player.global_position=w.ORIGIN+Vector3(10,1,7);w.paused=false;env._process(.5)
 assert(w.state.data.environment_events.pipe_settle)
 var source_count=env.sources.size();env._process(.5);assert(env.sources.size()==source_count,"Incident repeats")
 w.paused=true;var clock=env.clock;env._process(1);assert(env.clock==clock)
 for source in env.sources.slice(0,5):assert(source.stream_paused,"Loop did not pause")
 game.set_sfx_vol(0);assert(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))<-50);game.set_sfx_vol(.9)
 for size in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
  root.size=size;for i in range(3):await process_frame
  w.hud.open_evidence({"title":"Проверка чтения","body":"Проверка длинной переписки и переносов. ".repeat(150)})
  for i in range(5):await process_frame
  var text=w.hud.modal.find_child("EvidenceText",true,false);assert(text.size.x<=text.get_parent().size.x+1)
  w.hud.close_modal();w.paused=true
 w.queue_free();await process_frame
 w=scene.instantiate();root.add_child(w)
 for i in range(3):await physics_frame
 env=w.get_node("LevelMinusTwo/Atmosphere");assert(env.sources.size()==5,"Saved incident replayed");assert(w.state.flag("pump_valve"))
 w.queue_free();await process_frame
 print("ATMOSPHERE PASS: local loops, SFX mute, one-shot persistence, pause, repair cancellation/completion, read-state hints, three reading sizes")
 quit()
