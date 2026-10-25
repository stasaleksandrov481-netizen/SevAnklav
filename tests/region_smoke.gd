extends SceneTree
const Generator = preload("res://iso/region_generator.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var generator = Generator.new()
	var samples := [Vector2i(160, 105), Vector2i(250, 30), Vector2i(45, 155), Vector2i(270, 75), Vector2i(70, 100)]
	for coord in samples:
		var sector: Node3D = generator.make_sector(coord)
		if sector == null or sector.get_child_count() == 0:
			push_error("Region generation failed at %s" % coord)
			quit(1)
			return
		root.add_child(sector)
		print("REGION_SAMPLE coord=", coord, " area=", generator.area_at(coord), " children=", sector.get_child_count())
		root.remove_child(sector)
		sector.free()
	var scene := PackedScene.new()
	var editable: Node3D = generator.make_sector(Vector2i(250, 30))
	if scene.pack(editable) != OK or scene.get_state().get_node_count() < 2:
		push_error("Generated sector cannot be saved for editing")
		quit(1)
		return
	editable.free()
	print("REGION_OK 320x240 sectors with editable override")
	quit(0)
