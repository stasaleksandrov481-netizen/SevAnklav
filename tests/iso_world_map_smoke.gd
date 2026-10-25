extends SceneTree
func _initialize() -> void:
 call_deferred("run_check")
func run_check() -> void:
 var atlas: Node = load("res://iso/atlas/world_atlas.tscn").instantiate()
 root.add_child(atlas)
 var markers: Node = atlas.get_node("Markers")
 var roads: Node = atlas.get_node("EditableRoads")
 var city_marker: Node = markers.get_node("Severograd")
 var bunker_marker: Node = markers.get_node("BunkerHorizon")
 if markers.get_child_count() != 8 or roads.get_child_count() != 7 or city_marker.sector_coordinate() != Vector2i(160,105) or bunker_marker.sector_coordinate() != Vector2i(55,45):
  push_error("Atlas content or coordinates failed")
  quit(1)
  return
 root.remove_child(atlas)
 atlas.free()
 var city: Node = load("res://iso/city_world.tscn").instantiate()
 root.add_child(city)
 if city.loaded.size() != 9:
  push_error("City sectors failed")
  quit(1)
  return
 var buildings := get_nodes_in_group("iso_buildings")
 if buildings.size() < 30:
  push_error("City buildings failed: %d" % buildings.size())
  quit(1)
  return
 city.get_node("Volkov").global_position = Vector3(162 * 64 + 32, 0.95, 105 * 64 + 32)
 city._process(0.016)
 if city.loaded.size() != 9:
  push_error("Sector update failed")
  quit(1)
  return
 await process_frame
 if city.get_node("Sectors").get_child_count() != 9 or city.loaded.has(Vector2i(160, 105)):
  push_error("Sector replacement failed")
  quit(1)
  return
 root.remove_child(city)
 city.free()
 var bunker: Node = load("res://iso/bunker_world.tscn").instantiate()
 root.add_child(bunker)
 if bunker.get_node("Sectors").get_child_count() != 1 or not bunker.loaded.has(Vector2i(55, 45)):
  push_error("Bunker and generated region failed")
  quit(1)
  return
 var bunker_rooms := get_nodes_in_group("iso_rooms")
 var bunker_details: Node = bunker.get_node("Sectors/Sector_55_45/Bunker/Details/Generated")
 if bunker_rooms.size() != 11 or bunker_details.get_child_count() < 85:
  push_error("Bunker interior failed: rooms=%d details=%d" % [bunker_rooms.size(), bunker_details.get_child_count()])
  quit(1)
  return
 print("WORLD_MAP_OK atlas=20.48x15.36km city_sectors=9 buildings>=30 streamed=9 bunker_rooms=11")
 root.remove_child(bunker)
 bunker.free()
 quit(0)
