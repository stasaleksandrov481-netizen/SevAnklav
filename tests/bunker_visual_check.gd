extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var mode := "city"
 var args := OS.get_cmdline_user_args()
 if not args.is_empty(): mode = args[0]
 var scene := "res://iso/city_world.tscn"
 if mode == "bunker" or mode == "campaign": scene = "res://iso/bunker_world.tscn"
 elif mode == "atlas": scene = "res://iso/atlas/world_atlas.tscn"
 var world: Node = load(scene).instantiate()
 if mode == "base": world.get_node("Volkov").position = Vector3(250 * 64 + 32, 0.95, 30 * 64 + 32)
 elif mode == "farm": world.get_node("Volkov").position = Vector3(45 * 64 + 32, 0.95, 155 * 64 + 32)
 elif mode == "forest": world.get_node("Volkov").position = Vector3(95 * 64 + 32, 0.95, 150 * 64 + 32)
 elif mode == "generated_city": world.get_node("Volkov").position = Vector3(170 * 64 + 32, 0.95, 115 * 64 + 32)
 root.add_child(world)
 if mode == "campaign": world.add_child(preload("res://iso/campaign_hud.gd").new())
 await process_frame
 await process_frame
 if mode != "atlas":
  var cam: Camera3D = world.get_node("Camera")
  print("CAM_DEBUG target=", cam.target, " current=", cam.current, " position=", cam.global_position, " player=", world.get_node("Volkov").global_position, " sectors=", world.get_node("Sectors").get_child_count())
 for frame in range(60):
  await process_frame
 await RenderingServer.frame_post_draw
 var img := root.get_texture().get_image()
 if img == null:
  push_error("No rendered image")
  quit(1)
  return
 var result := img.save_png("res://" + mode + "_preview.png")
 print("CAPTURE_RESULT ", result, " size=", img.get_size())
 quit(0)
