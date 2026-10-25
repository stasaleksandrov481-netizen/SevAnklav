extends RefCounted

# One 64 m sector = 4 atlas pixels. The same coordinates are used by the
# runtime streamer and by the editor's sector export action.
const MAX_X := 320
const MAX_Z := 240
const SECTOR_METERS := 64.0
const METERS_PER_ATLAS_PIXEL := 16.0
const SectorScript = preload("res://iso/sector.gd")
const RoadScript = preload("res://iso/road.gd")
const BuildingScript = preload("res://iso/city_building.gd")
const TreeScript = preload("res://iso/tree.gd")
const CarScript = preload("res://iso/city_car.gd")

enum Area { FOREST, CITY, MILITARY, FARM, VILLAGE, QUARANTINE, WATER, INDUSTRY }

var _roads: Array[PackedVector2Array] = []
var _zones: Array[Dictionary] = []
var _asphalt: Material
var _shoulder: Material

func _init() -> void:
	var atlas := preload("res://iso/atlas/world_atlas.tscn").instantiate()
	for road in atlas.get_node("EditableRoads").get_children():
		_roads.append(road.curve.get_baked_points())
	for zone in atlas.get_node("EditableZones").get_children():
		var type := -1
		match zone.name:
			"Severograd": type = Area.CITY
			"NorthernLake", "WesternLake", "SouthernReservoir": type = Area.WATER
			"MilitaryBase": type = Area.MILITARY
			"Quarantine": type = Area.QUARANTINE
			"SouthwestFarms": type = Area.FARM
		if type >= 0: _zones.append({"area": type, "polygon": zone.polygon})
	atlas.free()
	var asphalt := ShaderMaterial.new()
	asphalt.shader = preload("res://iso/surface.gdshader")
	asphalt.set_shader_parameter("albedo_texture", preload("res://assets/iso/asphalt.png"))
	asphalt.set_shader_parameter("tint", Color(0.68, 0.72, 0.73))
	_asphalt = asphalt
	var shoulder := StandardMaterial3D.new()
	shoulder.albedo_color = Color("#545451")
	shoulder.roughness = 1.0
	_shoulder = shoulder

static func in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < MAX_X and coord.y < MAX_Z

func area_at(coord: Vector2i) -> Area:
	var p := Vector2(coord.x * 4 + 2, coord.y * 4 + 2)
	for zone in _zones:
		if zone["area"] == Area.WATER and Geometry2D.is_point_in_polygon(p, zone["polygon"]): return Area.WATER
	for zone in _zones:
		if zone["area"] != Area.WATER and Geometry2D.is_point_in_polygon(p, zone["polygon"]): return zone["area"]
	if ((p - Vector2(260, 390)) / Vector2(135, 75)).length_squared() < 1.0: return Area.WATER
	if ((p - Vector2(650, 82)) / Vector2(115, 74)).length_squared() < 1.0: return Area.WATER
	if ((p - Vector2(730, 681)) / Vector2(172, 104)).length_squared() < 1.0: return Area.WATER
	if ((p - Vector2(1120, 664)) / Vector2(110, 90)).length_squared() < 1.0: return Area.WATER
	if p.x > 475 and p.x < 950 and p.y > 280 and p.y < 570:
		return Area.CITY if ((p - Vector2(705, 425)) / Vector2(235, 150)).length_squared() < 1.0 else Area.FOREST
	if p.x > 860 and p.x < 1170 and p.y > 40 and p.y < 190: return Area.MILITARY
	if ((p - Vector2(1100, 305)) / Vector2(175, 112)).length_squared() < 1.0: return Area.QUARANTINE
	if ((p - Vector2(180, 625)) / Vector2(150, 110)).length_squared() < 1.0: return Area.FARM
	if ((p - Vector2(1060, 510)) / Vector2(115, 75)).length_squared() < 1.0: return Area.FARM
	if ((p - Vector2(430, 660)) / Vector2(75, 60)).length_squared() < 1.0: return Area.INDUSTRY
	if ((p - Vector2(855, 675)) / Vector2(90, 65)).length_squared() < 1.0: return Area.INDUSTRY
	for village in [Vector2(140, 465), Vector2(450, 520), Vector2(470, 225), Vector2(1150, 560), Vector2(1180, 820)]:
		if p.distance_to(village) < 42.0: return Area.VILLAGE
	return Area.FOREST

func make_sector(coord: Vector2i) -> Node3D:
	if not in_bounds(coord): return null
	var area := area_at(coord)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(coord.x * 73856093) ^ int(coord.y * 19349663) ^ 0x5E71A
	var sector := Node3D.new()
	sector.name = "Sector_%d_%d" % [coord.x, coord.y]
	sector.set_script(SectorScript)
	sector.set("ground_kind", 1 if area == Area.CITY or area == Area.MILITARY or area == Area.INDUSTRY else 3)
	match area:
		Area.CITY:
			_urban(sector, coord, rng, false)
		Area.MILITARY:
			_urban(sector, coord, rng, true)
		Area.VILLAGE:
			_village(sector, coord, rng)
		Area.FARM:
			_farm(sector, coord, rng)
		Area.INDUSTRY:
			_industry(sector, coord, rng)
		Area.QUARANTINE:
			_quarantine(sector, coord, rng)
		Area.WATER:
			_water(sector)
		_:
			_forest(sector, coord, rng)
	if area != Area.CITY and area != Area.MILITARY:
		_regional_roads(sector, coord)
	return sector

func _node(parent: Node3D, script: Script, name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = name
	node.set_script(script)
	node.position = at
	parent.add_child(node)
	node.owner = parent
	return node

func _building(parent: Node3D, name: String, at: Vector3, style: int, w: float, d: float, floors: int) -> void:
	var building := _node(parent, BuildingScript, name, at)
	building.set("style", style)
	building.set("width", w)
	building.set("depth", d)
	building.set("floors", floors)

func _tree(parent: Node3D, at: Vector3, seed: int) -> void:
	var tree := _node(parent, TreeScript, "Tree_%d" % seed, at)
	tree.set("height", 5.4 + float(seed % 12) * 0.28)
	tree.set("variation", seed)

func _road(parent: Node3D, name: String, horizontal: bool, offset: float, width: float) -> void:
	var at := Vector3(32, 0.03, offset) if horizontal else Vector3(offset, 0.03, 32)
	var road := _node(parent, RoadScript, name, at)
	road.set("direction", 0 if horizontal else 1)
	road.set("width", width)
	road.set("intersection_at_center", false)

func _urban(parent: Node3D, coord: Vector2i, rng: RandomNumberGenerator, military: bool) -> void:
	var vertical := coord.x % (4 if military else 2) == 0
	var horizontal := coord.y % (4 if military else 2) == 0
	if vertical: _road(parent, "NorthSouthRoad", false, 32, 12 if military else 10)
	if horizontal: _road(parent, "EastWestRoad", true, 32, 12 if military else 10)
	var spots := [Vector3(15, 0, 15), Vector3(49, 0, 15), Vector3(15, 0, 49), Vector3(49, 0, 49)]
	var count := 0
	for i in range(spots.size()):
		var at: Vector3 = spots[i]
		if vertical and absf(at.x - 32) < 20: continue
		if horizontal and absf(at.z - 32) < 20: continue
		if rng.randf() < (0.16 if military else 0.12): continue
		var style := (2 if rng.randf() < 0.4 else 3) if military else rng.randi_range(0, 3)
		_box(parent, "BuildingPad_%d" % i, Vector3(18, 0.05, 18), Vector3(at.x, 0.025, at.z), _shoulder)
		_building(parent, "Facility_%d" % i if military else "Building_%d" % i, at, style, rng.randf_range(10, 14), rng.randf_range(9, 13), rng.randi_range(1, 3))
		count += 1
	if count == 0 and not vertical and not horizontal:
		_building(parent, "Building_0", Vector3(32, 0, 32), 2 if military else 0, 16, 12, 1)
	if rng.randf() < 0.25 and (vertical or horizontal):
		_node(parent, CarScript, "ParkedCar", Vector3(24, 0.02, 24))
	if military:
		_military_details(parent, coord)
	else:
		for i in range(3):
			var at := Vector3(rng.randf_range(4, 60), 0, rng.randf_range(4, 60))
			if absf(at.x - 32) > 12 and absf(at.z - 32) > 12: _tree(parent, at, i + int(rng.seed % 10000))

func _military_details(parent: Node3D, coord: Vector2i) -> void:
	if coord.x % 5 == 0 and coord.y % 5 == 0:
		_box(parent, "LandingApron", Vector3(27, 0.05, 27), Vector3(32, 0.035, 32), _asphalt)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("#c5c5b3")
		for side in [-1.0, 1.0]:
			_box(parent, "HelipadH", Vector3(0.65, 0.01, 9.0), Vector3(32 + side * 2.8, 0.07, 32), paint)
		_box(parent, "HelipadCrossbar", Vector3(6.4, 0.01, 0.7), Vector3(32, 0.075, 32), paint)
	else:
		for slot in range(3):
			_box(parent, "ParkingLine_%d" % slot, Vector3(0.1, 0.01, 5.4), Vector3(25 + slot * 5, 0.04, 5.5), _shoulder)
	if coord.x == 215 or coord.x == 291:
		for i in range(8): _box(parent, "FencePost_%d" % i, Vector3(0.15, 2.5, 0.15), Vector3(2 if coord.x == 215 else 62, 1.25, 4 + i * 8), _shoulder)
		_box(parent, "FenceRail", Vector3(0.08, 0.12, 64), Vector3(2 if coord.x == 215 else 62, 1.3, 32), _shoulder)
	if coord.y == 10 or coord.y == 47:
		for i in range(8): _box(parent, "FencePostZ_%d" % i, Vector3(0.15, 2.5, 0.15), Vector3(4 + i * 8, 1.25, 2 if coord.y == 10 else 62), _shoulder)
		_box(parent, "FenceRailZ", Vector3(64, 0.12, 0.08), Vector3(32, 1.3, 2 if coord.y == 10 else 62), _shoulder)

func _forest(parent: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	for i in range(22):
		_tree(parent, Vector3(rng.randf_range(3, 61), 0, rng.randf_range(3, 61)), i + int(rng.seed % 10000))

func _village(parent: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	if coord.y % 2 == 0: _road(parent, "VillageStreet", true, 32, 7)
	for i in range(3):
		_building(parent, "House_%d" % i, Vector3(12 + i * 19, 0, 14 if i % 2 == 0 else 50), 0, 9, 8, 1)
	for i in range(4): _tree(parent, Vector3(rng.randf_range(4, 60), 0, rng.randf_range(4, 60)), i + int(rng.seed % 10000))

func _farm(parent: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://iso/surface.gdshader")
	soil.set_shader_parameter("albedo_texture", preload("res://assets/iso/grass_soil.png"))
	soil.set_shader_parameter("tint", Color(0.58, 0.45, 0.34))
	for i in range(8):
		_box(parent, "Furrow_%d" % i, Vector3(52, 0.04, 2.5), Vector3(32, 0.02, 6 + i * 7.0), soil)
	var crop_mat := StandardMaterial3D.new()
	crop_mat.albedo_color = Color("#60744c")
	crop_mat.roughness = 0.98
	crop_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crop_mesh := CylinderMesh.new()
	crop_mesh.top_radius = 0.06
	crop_mesh.bottom_radius = 0.22
	crop_mesh.height = 0.75
	crop_mesh.radial_segments = 3
	crop_mesh.material = crop_mat
	var crops := MultiMesh.new()
	crops.transform_format = MultiMesh.TRANSFORM_3D
	crops.mesh = crop_mesh
	crops.instance_count = 8 * 46
	for row in range(8):
		for plant in range(46):
			var at := Vector3(6.0 + plant * 1.15, 0.40, 6.0 + row * 7.0)
			at.x += rng.randf_range(-0.15, 0.15)
			at.z += rng.randf_range(-0.25, 0.25)
			crops.set_instance_transform(row * 46 + plant, Transform3D(Basis(), at))
	var crop_instance := MultiMeshInstance3D.new()
	crop_instance.name = "CropPlants"
	crop_instance.multimesh = crops
	parent.add_child(crop_instance)
	crop_instance.owner = parent
	if coord.x % 7 == 0 and coord.y % 5 == 0:
		_building(parent, "Farmhouse", Vector3(18, 0, 19), 0, 12, 10, 2)
		_building(parent, "Barn", Vector3(45, 0, 42), 2, 18, 14, 1)
		var silo_mat := StandardMaterial3D.new()
		silo_mat.albedo_color = Color("#6e7670")
		silo_mat.metallic = 0.4
		var silo := MeshInstance3D.new()
		silo.name = "GrainSilo"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.1
		cylinder.bottom_radius = 2.1
		cylinder.height = 7.0
		silo.mesh = cylinder
		silo.material_override = silo_mat
		silo.position = Vector3(48, 3.5, 16)
		parent.add_child(silo)
		silo.owner = parent
	for i in range(2): _tree(parent, Vector3(rng.randf_range(4, 60), 0, rng.randf_range(4, 60)), i + int(rng.seed % 10000))

func _industry(parent: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	if coord.x % 3 == 0: _road(parent, "ServiceRoad", false, 32, 9)
	_building(parent, "Warehouse", Vector3(32, 0, 32), 2, 22, 18, 1)
	if rng.randf() < 0.4: _node(parent, CarScript, "UtilityVehicle", Vector3(12, 0.02, 13))

func _quarantine(parent: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	for i in range(5): _tree(parent, Vector3(rng.randf_range(3, 61), 0, rng.randf_range(3, 61)), i + int(rng.seed % 10000))
	if coord.x % 4 == 0 or coord.y % 4 == 0:
		_building(parent, "AbandonedFacility", Vector3(32, 0, 32), 2, 16, 14, 1)

func _water(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.20, 0.25, 0.88)
	material.metallic = 0.2
	material.roughness = 0.22
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(parent, "Water", Vector3(64, 0.05, 64), Vector3(32, 0.015, 32), material)

func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, material: Material, angle := 0.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.rotation.y = angle
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.owner = parent

func _regional_roads(parent: Node3D, coord: Vector2i) -> void:
	var origin := Vector2(coord.x * SECTOR_METERS, coord.y * SECTOR_METERS)
	for index in range(_roads.size()):
		var points: PackedVector2Array = _roads[index]
		for i in range(points.size() - 1):
			var a: Vector2 = points[i] * METERS_PER_ATLAS_PIXEL
			var b: Vector2 = points[i + 1] * METERS_PER_ATLAS_PIXEL
			var clipped := _clip_segment(a, b, origin, origin + Vector2.ONE * SECTOR_METERS)
			if clipped.size() != 2: continue
			var start: Vector2 = clipped[0] - origin
			var end: Vector2 = clipped[1] - origin
			var delta := end - start
			if delta.length() < 0.25: continue
			var center := (start + end) * 0.5
			var angle := -atan2(delta.y, delta.x)
			_box(parent, "RoadShoulder_%d_%d" % [index, i], Vector3(delta.length() + 0.3, 0.05, 9.8), Vector3(center.x, 0.01, center.y), _shoulder, angle)
			_box(parent, "RegionalRoad_%d_%d" % [index, i], Vector3(delta.length() + 0.3, 0.06, 8.5), Vector3(center.x, 0.05, center.y), _asphalt, angle)

func _clip_segment(a: Vector2, b: Vector2, low: Vector2, high: Vector2) -> PackedVector2Array:
	var delta := b - a
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [a.x - low.x, high.x - a.x, a.y - low.y, high.y - a.y]
	var first := 0.0
	var last := 1.0
	for i in range(4):
		if absf(p[i]) < 0.00001:
			if q[i] < 0.0: return PackedVector2Array()
		else:
			var t: float = q[i] / p[i]
			if p[i] < 0.0: first = maxf(first, t)
			else: last = minf(last, t)
			if first > last: return PackedVector2Array()
	return PackedVector2Array([a + delta * first, a + delta * last])
