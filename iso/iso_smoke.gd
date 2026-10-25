extends SceneTree
func _initialize() -> void:
 var world: Node = load("res://iso/world_stream.tscn").instantiate()
 root.call_deferred("add_child", world)
 call_deferred("check", world)
func check(world: Node) -> void:
 var sectors: Node = world.get_node("Sectors")
 if sectors.get_child_count() != 1:
  push_error("Sector not loaded")
  quit(1)
  return
 var rooms := get_nodes_in_group("iso_rooms")
 if rooms.size() != 3:
  push_error("Room count: %d" % rooms.size())
  quit(1)
  return
 var scene := PackedScene.new()
 var room := Node3D.new()
 room.name = "Roundtrip"
 room.set_script(load("res://iso/room.gd"))
 room.set("width", 10)
 if scene.pack(room) != OK or ResourceSaver.save(scene, "res://iso/test_roundtrip.tscn") != OK:
  push_error("Save failed")
  quit(1)
  return
 room.free()
 var reopened: Node = load("res://iso/test_roundtrip.tscn").instantiate()
 if reopened.get("width") != 10:
  push_error("Roundtrip failed")
  quit(1)
  return
 reopened.free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path("res://iso/test_roundtrip.tscn"))
 print("ISO_SMOKE_OK sectors=1 rooms=3 room_save=ok")
 quit(0)
