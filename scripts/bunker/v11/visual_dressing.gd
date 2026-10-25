extends Node2D
# Static, deterministic visual-only accident dressing for the working Zarya bunker.
# Drawn once below props: no collisions, saves, animation loops or new light maps.
const Layout = preload("res://scripts/bunker/bunker_layout.gd")
var b = null

func _ready() -> void:
    z_index = -8
    queue_redraw()

func _draw() -> void:
    if b == null:
        return
    _room_wear()
    _service_hatches()
    _technical_routes()
    _accident_traces()

func _room_wear() -> void:
    # Fine irregular usage marks concentrated near room edges, not noisy tiled dirt.
    for room_idx in range(Layout.FLOOR.size()):
        var zone: Rect2 = Layout.FLOOR[room_idx][0]
        var kind: String = Layout.FLOOR[room_idx][1]
        var rng := RandomNumberGenerator.new()
        rng.seed = 77031 + room_idx * 149
        var stains := 22 if kind in ["lab", "tech", "cargo"] else 13
        for i in range(stains):
            var x: float = rng.randf_range(zone.position.x + 22.0, zone.end.x - 22.0)
            var y: float = rng.randf_range(zone.position.y + 20.0, zone.end.y - 20.0)
            var length: float = rng.randf_range(4.0, 27.0)
            var angle: float = rng.randf_range(-PI, PI)
            var pos := Vector2(x, y)
            var step := Vector2.from_angle(angle) * length
            var dirt := Color(0.018, 0.028, 0.032, rng.randf_range(0.07, 0.19))
            draw_line(pos, pos + step, dirt, rng.randf_range(1.0, 3.5), true)
            if i % 7 == 0:
                draw_line(pos + Vector2(0.5, 1.0), pos + step * 0.72, Color(0.40, 0.52, 0.51, 0.055), 0.8, true)
        # Room walls still belong to the baked architecture; these are subtle
        # track marks just inside the wall/floor seam.
        if zone.size.x > 280.0 and zone.size.y > 220.0:
            for edge in range(2):
                var p := Vector2(zone.position.x + 38.0, zone.position.y + 30.0 + edge * (zone.size.y - 60.0))
                draw_line(p, p + Vector2(minf(zone.size.x * 0.42, 185.0), 0), Color(0.023, 0.036, 0.045, 0.12), 7.0, true)

func _service_hatches() -> void:
    for data in [
        [Vector2(1095, 440), Vector2(65, 40)],
        [Vector2(1740, 1480), Vector2(70, 46)],
        [Vector2(2520, 1880), Vector2(84, 46)],
        [Vector2(450, 1680), Vector2(76, 42)],
        [Vector2(930, 2410), Vector2(78, 43)]
    ]:
        var center: Vector2 = data[0]
        var size: Vector2 = data[1]
        var outer := Rect2(center - size * 0.5, size)
        draw_rect(outer.grow(4), Color(0.015, 0.025, 0.032, 0.26))
        draw_rect(outer, Color(0.090, 0.139, 0.159, 0.38))
        draw_rect(outer.grow(-4), Color(0.40, 0.48, 0.48, 0.35), false, 1.4)
        for corner in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(8, size.y - 8), size - Vector2(8, 8)]:
            draw_circle(outer.position + corner, 1.9, Color(0.57, 0.66, 0.63, 0.48))
        for i in range(3):
            var xx := center.x - 12.0 + i * 12.0
            draw_line(Vector2(xx, center.y - 7), Vector2(xx, center.y + 8), Color(0.017, 0.034, 0.043, 0.64), 3.2, true)

func _technical_routes() -> void:
    # Cable conduits connect plausible equipment locations; cosmetic only.
    _cable(PackedVector2Array([Vector2(1460, 940), Vector2(1460, 905), Vector2(1620, 905)]), Color(0.26, 0.42, 0.44, 0.48), 3.2)
    _cable(PackedVector2Array([Vector2(1620, 905), Vector2(1690, 905), Vector2(1690, 1040)]), Color(0.14, 0.25, 0.30, 0.53), 3.4)
    _cable(PackedVector2Array([Vector2(210, 1745), Vector2(210, 1820), Vector2(430, 1820)]), Color(0.31, 0.36, 0.29, 0.4), 3.7)
    _cable(PackedVector2Array([Vector2(2395, 1515), Vector2(2355, 1515), Vector2(2355, 1615)]), Color(0.27, 0.36, 0.39, 0.46), 3.0)
    for center in [Vector2(1347, 904), Vector2(1685, 1015), Vector2(211, 1790), Vector2(2356, 1565)]:
        draw_circle(center, 4.0, Color(0.018, 0.031, 0.037, 0.57))
        draw_circle(center, 1.8, Color(0.58, 0.64, 0.57, 0.46))
    # Safety paint has rubbed away at traffic bottlenecks.
    _warning_stripe(Vector2(1345, 1510), true, 97.0)
    _warning_stripe(Vector2(1812, 2528), false, 113.0)
    _warning_stripe(Vector2(752, 1188), false, 91.0)

func _accident_traces() -> void:
    # Recently spilled coolant and dry boot drag marks. No abandoned/ruined look.
    _spill(Vector2(800, 1318), 33.0, Color(0.073, 0.22, 0.24, 0.23), 1)
    _spill(Vector2(1715, 1620), 23.0, Color(0.071, 0.16, 0.17, 0.21), 2)
    _spill(Vector2(2425, 2205), 41.0, Color(0.052, 0.12, 0.14, 0.24), 3)
    _spill(Vector2(650, 564), 13.0, Color(0.20, 0.079, 0.067, 0.16), 4)
    for entry in [
        [Vector2(572, 558), 0.35], [Vector2(588, 565), 0.37],
        [Vector2(605, 572), 0.40], [Vector2(630, 583), 0.40],
        [Vector2(826, 1362), -0.7], [Vector2(839, 1340), -0.7]
    ]:
        var pos: Vector2 = entry[0]
        var angle: float = entry[1]
        var tangent := Vector2.from_angle(angle)
        draw_line(pos - tangent * 7.0, pos + tangent * 8.0, Color(0.035, 0.040, 0.040, 0.25), 3.0, true)
        draw_line(pos + tangent.orthogonal() * 3.0 - tangent * 5.0, pos + tangent.orthogonal() * 3.0 + tangent * 5.0, Color(0.05, 0.062, 0.062, 0.18), 1.1, true)
    # Ventilation moisture slowly gathered below active cooling units.
    for anchor in [Vector2(1478, 915), Vector2(1522, 916), Vector2(1612, 916)]:
        draw_circle(anchor, 5.0, Color(0.09, 0.26, 0.29, 0.10))

func _cable(points: PackedVector2Array, col: Color, width: float) -> void:
    draw_polyline(points, Color(0.005, 0.014, 0.02, 0.5), width + 3.0, true)
    draw_polyline(points, col, width, true)
    draw_polyline(points, Color(0.64, 0.71, 0.65, 0.17), 0.8, true)

func _warning_stripe(pos: Vector2, vertical: bool, length: float) -> void:
    var size := Vector2(11.0, length) if vertical else Vector2(length, 11.0)
    draw_rect(Rect2(pos, size), Color(0.026, 0.039, 0.041, 0.33))
    for j in range(3, int(length) - 7, 22):
        var at := pos + (Vector2(0, j) if vertical else Vector2(j, 0))
        draw_line(at, at + Vector2(9.0, 9.0), Color(0.59, 0.43, 0.19, 0.29), 4.5, true)

func _spill(pos: Vector2, radius: float, col: Color, seed: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed * 11939
    var perimeter := PackedVector2Array()
    for i in range(15):
        var theta := TAU * float(i) / 15.0
        var rr := radius * rng.randf_range(0.58, 1.16)
        perimeter.append(pos + Vector2(cos(theta), sin(theta) * 0.46) * rr)
    draw_colored_polygon(perimeter, col)
    draw_line(pos + Vector2(-radius * .55, 0), pos + Vector2(radius * .38, -radius * .10), Color(0.38, 0.58, 0.59, 0.08), 1.4, true)
