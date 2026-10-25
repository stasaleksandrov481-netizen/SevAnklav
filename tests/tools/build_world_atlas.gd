extends SceneTree

const AtlasScript = preload("res://iso/atlas/world_atlas.gd")
const PathScript = preload("res://iso/atlas/atlas_path.gd")
const MarkerScript = preload("res://iso/atlas/atlas_marker.gd")

func _initialize() -> void:
	var root_node := Node2D.new()
	root_node.name = "WorldAtlas"
	root_node.set_script(AtlasScript)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(640, 480)
	camera.zoom = Vector2(0.88, 0.88)
	camera.enabled = true
	root_node.add_child(camera)
	camera.owner = root_node
	var zones := Node2D.new()
	zones.name = "EditableZones"
	root_node.add_child(zones)
	zones.owner = root_node
	_zone(root_node, zones, "Severograd", [Vector2(475, 300), Vector2(855, 285), Vector2(940, 555), Vector2(510, 560)], Color(0.55, 0.60, 0.64, 0.20))
	_zone(root_node, zones, "NorthernLake", [Vector2(540, 20), Vector2(730, 5), Vector2(785, 130), Vector2(685, 175), Vector2(560, 145)], Color(0.12, 0.39, 0.56, 0.22))
	_zone(root_node, zones, "WesternLake", [Vector2(140, 350), Vector2(300, 320), Vector2(380, 385), Vector2(310, 460), Vector2(160, 455)], Color(0.12, 0.39, 0.56, 0.22))
	_zone(root_node, zones, "SouthernReservoir", [Vector2(540, 620), Vector2(745, 600), Vector2(900, 700), Vector2(825, 795), Vector2(610, 775)], Color(0.12, 0.39, 0.56, 0.25))
	_zone(root_node, zones, "MilitaryBase", [Vector2(870, 35), Vector2(1140, 35), Vector2(1160, 180), Vector2(860, 180)], Color(0.34, 0.41, 0.42, 0.25))
	_zone(root_node, zones, "Quarantine", [Vector2(990, 200), Vector2(1220, 215), Vector2(1265, 360), Vector2(1140, 425), Vector2(950, 355)], Color(0.6, 0.12, 0.12, 0.30))
	_zone(root_node, zones, "SouthwestFarms", [Vector2(80, 550), Vector2(350, 570), Vector2(330, 730), Vector2(90, 705)], Color(0.49, 0.41, 0.22, 0.25))
	var roads := Node2D.new()
	roads.name = "EditableRoads"
	root_node.add_child(roads)
	roads.owner = root_node
	_road(root_node, roads, "M7_Highway", [Vector2(0, 525), Vector2(200, 527), Vector2(390, 552), Vector2(565, 575), Vector2(750, 585), Vector2(935, 590), Vector2(1280, 585)], 6.0, Color("#d4c8b3"))
	_road(root_node, roads, "NorthernRoute", [Vector2(0, 350), Vector2(200, 340), Vector2(380, 285), Vector2(530, 225), Vector2(700, 190), Vector2(865, 168), Vector2(1190, 215)], 4.0, Color("#c5bfaf"))
	_road(root_node, roads, "BunkerApproach", [Vector2(220, 180), Vector2(290, 205), Vector2(380, 285)], 3.0, Color("#b2b8ad"))
	_road(root_node, roads, "CityRing", [Vector2(480, 335), Vector2(570, 295), Vector2(780, 290), Vector2(900, 355), Vector2(920, 515), Vector2(825, 565), Vector2(560, 550), Vector2(475, 450), Vector2(480, 335)], 4.0, Color("#c8c3b7"))
	_road(root_node, roads, "EastConnection", [Vector2(900, 355), Vector2(1025, 275), Vector2(1190, 215)], 4.0, Color("#b8b8ad"))
	_road(root_node, roads, "DamRoad", [Vector2(650, 550), Vector2(670, 625), Vector2(765, 755), Vector2(940, 870)], 3.0, Color("#b8b8ad"))
	_road(root_node, roads, "VillageRoad", [Vector2(80, 470), Vector2(230, 445), Vector2(390, 552)], 3.0, Color("#b8b8ad"))
	var markers := Node2D.new()
	markers.name = "Markers"
	root_node.add_child(markers)
	markers.owner = root_node
	_marker(root_node, markers, "Severograd", Vector2(640, 420), "Североград · игровая заготовка", 0, "res://iso/city_world.tscn")
	_marker(root_node, markers, "BunkerHorizon", Vector2(220, 180), "Бункер Горизонт · игровая заготовка", 1, "res://iso/bunker_world.tscn")
	_marker(root_node, markers, "MilitaryNorth", Vector2(1000, 125), "Военная база Северная", 2)
	_marker(root_node, markers, "RedForest", Vector2(1080, 310), "Рыжий Лес · карантин", 3)
	_marker(root_node, markers, "Farm", Vector2(185, 640), "Фермы Зеленые Луга", 4)
	_marker(root_node, markers, "Dam", Vector2(780, 760), "ГЭС Сосновая", 5)
	_marker(root_node, markers, "WestVillage", Vector2(185, 465), "Деревня Сосновка", 4)
	_marker(root_node, markers, "EasternPower", Vector2(1000, 580), "АЭС Рассвет", 5)
	var scene := PackedScene.new()
	if scene.pack(root_node) != OK:
		push_error("Cannot pack atlas")
		quit(1)
		return
	if ResourceSaver.save(scene, "res://iso/atlas/world_atlas.tscn") != OK:
		push_error("Cannot save atlas")
		quit(1)
		return
	root_node.free()
	print("ATLAS_OK 20.48x15.36km roads=7 markers=8")
	quit(0)

func _zone(owner_node: Node, parent: Node, label: String, points: Array[Vector2], color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.name = label
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	parent.add_child(polygon)
	polygon.owner = owner_node

func _road(owner_node: Node, parent: Node, label: String, points: Array[Vector2], road_width: float, color: Color) -> void:
	var path := Path2D.new()
	path.name = label
	path.set_script(PathScript)
	path.set("road_width", road_width)
	path.set("line_color", color)
	var curve := Curve2D.new()
	for i in range(points.size()):
		var tangent := Vector2.ZERO
		if i > 0 and i < points.size() - 1:
			tangent = (points[i + 1] - points[i - 1]) * 0.18
		curve.add_point(points[i], -tangent, tangent)
	path.curve = curve
	parent.add_child(path)
	path.owner = owner_node

func _marker(owner_node: Node, parent: Node, label: String, at: Vector2, title: String, kind: int, scene_path := "") -> void:
	var marker := Node2D.new()
	marker.name = label
	marker.position = at
	marker.set_script(MarkerScript)
	marker.set("title", title)
	marker.set("kind", kind)
	marker.set("playable_scene", scene_path)
	parent.add_child(marker)
	marker.owner = owner_node
