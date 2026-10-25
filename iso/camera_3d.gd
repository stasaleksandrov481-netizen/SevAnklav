extends Camera3D

@export var target_path: NodePath = ^"../Volkov"
var target: Node3D
@export var follow_speed := 6.0
@export_range(8.0, 50.0) var distance := 24.0
@export_range(25.0, 60.0) var elevation_degrees := 35.264
@export_range(0.0, 360.0) var azimuth_degrees := 45.0
@export_range(10.0, 50.0) var initial_size := 25.0
var _offset := Vector3(16, 16, 16)

func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = initial_size
	far = 120.0
	var elevation := deg_to_rad(elevation_degrees)
	var azimuth := deg_to_rad(azimuth_degrees)
	var horizontal := distance * cos(elevation)
	_offset = Vector3(horizontal * sin(azimuth), distance * sin(elevation), horizontal * cos(azimuth))
	if target != null:
		global_position = target.global_position + _offset
		look_at(target.global_position + Vector3.UP)

func _process(delta: float) -> void:
	if target != null:
		var wanted := target.global_position + _offset
		global_position = global_position.lerp(wanted, minf(1.0, delta * follow_speed))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: size = maxf(10.0, size - 1.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: size = minf(48.0, size + 1.5)
