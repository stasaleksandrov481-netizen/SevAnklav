extends SceneTree
const Generator = preload("res://iso/region_generator.gd")

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var generator = Generator.new()
	for coord in [Vector2i(250, 30), Vector2i(42, 155), Vector2i(35, 115), Vector2i(95, 150), Vector2i(270, 75)]:
		var path := "res://iso/sectors/sector_%d_%d.tscn" % [coord.x, coord.y]
		if ResourceLoader.exists(path): continue
		var sector: Node3D = generator.make_sector(coord)
		var scene := PackedScene.new()
		if scene.pack(sector) != OK or ResourceSaver.save(scene, path) != OK:
			push_error("Cannot save landmark sector: " + path)
			quit(1)
			return
		sector.free()
		print("BAKED ", path)
	print("LANDMARKS_OK")
	quit(0)
