extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var g=root.get_node("G");g.set_meta("qa8",true);g.zsave=g._default_zsave()
 var prior=load("res://iso/zarya/state.gd").new(g.zsave,"zarya_layout3");prior.data.awake=true
 var scene=load("res://iso/bunker_world.tscn");var w=scene.instantiate();root.add_child(w)
 for i in range(30):await physics_frame
 w.paused=true;w.player.set_physics_process(false)
 var door=w.doors[1];door.opened=false;door.progress=.6;door.hinge.rotation.y=-.6*PI/2
 var predicted=Transform3D(Basis(Vector3.UP,-.5*PI/2),door.hinge.position)
 var leaf_transform:Transform3D=door.global_transform*predicted*door.leaf.transform
 w.player.global_position=leaf_transform.origin;w.player.global_position.y=1
 await physics_frame
 w.paused=false;door._process(.0666667);w.paused=true
 assert(is_equal_approx(door.progress,.6),"Door moved into player")
 assert(door.obstructed)
 w.player.position=w.ORIGIN+Vector3(-28,1,-7);await physics_frame
 w.paused=false;door._process(.1);w.paused=true
 assert(door.progress<.6,"Door did not resume after passage cleared")
 var saved_progress:float=door.progress;w.save_state()
 assert(is_equal_approx(w.state.data.door_progress[door.info.id],saved_progress))
 w.state.data.records={"volkov_tag":{"title":"Армейский жетон","body":"НЕ ВЕРЬ ГОЛОСУ"},"shift":{"title":"Сменный лист","body":"Марина Белова / пациент V-17"},"guard_log":{"title":"Охрана","body":"Эвакуацию отменили"}}
 for size in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
  root.size=size
  for i in range(3):await process_frame
  w.hud.open_pda()
  for i in range(5):await process_frame
  var search=w.hud.modal.find_child("ArchiveSearch",true,false);var entries=w.hud.modal.find_child("ArchiveEntries",true,false)
  search.text="бЕЛоВА";search.text_changed.emit(search.text);await process_frame
  var results=entries.get_children().filter(func(n):return n is Button)
  assert(results.size()==1);assert(results[0].get_meta("record_id")=="shift","Body search failed")
  results[0].pressed.emit();assert(w.state.data.pda_selected=="shift")
  assert(w.hud.modal.find_child("ArchiveBody",true,false).text.contains("Белова"))
  var pin=w.hud.modal.find_child("ArchivePin",true,false);pin.pressed.emit();await process_frame
  assert(w.state.data.tracked_record=="shift");assert(w.hud.modal.find_child("ArchiveHeading",true,false).text=="Сменный лист")
  pin=w.hud.modal.find_child("ArchivePin",true,false);pin.pressed.emit();await process_frame
  assert(w.state.data.tracked_record=="")
  search=w.hud.modal.find_child("ArchiveSearch",true,false);search.text="несуществующий_текст";search.text_changed.emit(search.text);await process_frame
  assert(w.hud.modal.find_child("ArchiveEntries",true,false).get_children().filter(func(n):return n is Button).is_empty())
  var body=w.hud.modal.find_child("ArchiveBody",true,false)
  assert(w.hud.modal.size.x<=w.hud.canvas_size.x);assert(body.size.x<=w.hud.modal.size.x)
  w.hud.close_modal();w.paused=true
 w.queue_free();await process_frame
 w=scene.instantiate();root.add_child(w);w.paused=true
 assert(is_equal_approx(w.doors[1].progress,saved_progress),"Partial door state not restored")
 assert(w.state.data.pda_selected=="shift")
 w.queue_free();await process_frame
 print("DEEP PASS: door obstruction/resume and partial reload; body/title search, selection, pin toggle, empty results, 3 viewport sizes")
 quit()
