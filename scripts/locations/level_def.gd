# ============================================================
# FIX9: УЗЕЛ-ДЕФИНИЦИЯ РУКОПИСНОЙ ЛОКАЦИИ (bunker/surface)
# Раньше бункер собирался кодом: массивы _wall/_room/_prop с
# жёсткими координатами в battle_z.gd. Теперь каждый элемент
# уровня — узел LevelDef в сцене (см. scenes/locations/Bunker_Zarya.tscn).
# Дизайнер двигает узлы мышью в редакторе; движок боя при старте
# читает эти узлы и строит стены/мебель/зомби сам.
#
# ТИПЫ (def_type):
#   zone   — пол/зона пола: rect + kind ("metal","tile_lab","tile_med","conc")
#   wall   — прямоугольная стена: rect
#   room   — комната из 4 стен: rect + room_thickness + doors
#            doors = {"n":[[0.38,0.62]], "s":[...], "w":[...], "e":[...]}
#            (доли 0..1 вдоль стены — проёмы)
#   door   — гермодверь: def_id, gap_w, vertical
#   prop   — объект с геймплеем: tex, def_kind, def_radius, solid
#            (capsule, gear_table, cabinet, loot_crate, vent, scanner,
#             airlock, stairs, react...)
#   spr    — декор-спрайт: tex, def_scale, def_z
#   light_lab / light_red — светильники (wide у lab)
#   blood  — пятно крови (big)
#   corpse — труп: def_kind ("guard","sci") — лут
#   zombie — мёртвый: def_kind ("walk","run","sci","cop","brute")
#   spawn  — точка появления игрока (одна на сцену)
# ============================================================
@tool
class_name LevelDef
extends Node2D

@export_enum("zone", "wall", "room", "door", "prop", "spr", "light_lab", "light_red", "blood", "corpse", "zombie", "spawn") var def_type := "prop"
@export_group("Прямоугольники (zone/wall/room)")
@export var rect := Rect2(0, 0, 100, 100)
@export var room_thickness := 22.0
@export var doors := {}
@export_group("Дверь")
@export var def_id := ""
@export var gap_w := 210.0
@export var vertical := false
@export_group("Объект (prop/spr)")
@export var tex := ""              # имя текстуры в assets (без .png)
@export var def_kind := ""         # гейплей-тип (capsule, cabinet, loot_crate...)
@export var def_radius := 0.0      # радиус коллизии/обхода
@export var def_scale := 1.42
@export var def_z := 5
@export var solid := true
@export var rot_deg := 0.0         # поворот спрайта, градусы
@export var def_color := Color(1, 1, 1)
@export_group("Свет/кровь/сущности")
@export var wide := false          # lab-светильник широкий
@export var big := true            # кровь большая


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	match def_type:
		"zone":
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.4, 0.55, 0.7, 0.10), true)
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.5, 0.7, 0.9, 0.55), false, 2.0)
		"wall":
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.9, 0.35, 0.2, 0.28), true)
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(1.0, 0.45, 0.3, 0.8), false, 2.0)
		"room":
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(1.0, 0.6, 0.2, 0.07), true)
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(1.0, 0.65, 0.25, 0.85), false, 2.0)
		"door":
			draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.8, 0.3, 0.5))
			draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.85, 0.4, 0.95), false, 2.5)
		"spawn":
			draw_circle(Vector2.ZERO, 22.0, Color(0.3, 1.0, 0.4, 0.30), false, 3.0)
			draw_line(Vector2(-16, 0), Vector2(16, 0), Color(0.3, 1.0, 0.4, 0.9), 3.0)
			draw_line(Vector2(0, -16), Vector2(0, 16), Color(0.3, 1.0, 0.4, 0.9), 3.0)
		"light_lab", "light_red":
			var c := Color(1.0, 0.95, 0.6, 0.4) if def_type == "light_lab" else Color(1.0, 0.25, 0.2, 0.5)
			draw_circle(Vector2.ZERO, 12.0, c)
		"blood":
			draw_circle(Vector2.ZERO, 10.0 if big else 6.0, Color(0.55, 0.08, 0.08, 0.55))
		"corpse", "zombie":
			var c := Color(0.7, 0.2, 0.7, 0.5) if def_type == "zombie" else Color(0.6, 0.6, 0.65, 0.5)
			draw_rect(Rect2(-18, -18, 36, 36), c, false, 2.0)
		"prop", "spr":
			if get_child_count() == 0:
				draw_rect(Rect2(-20, -20, 40, 40), Color(0.3, 0.9, 0.9, 0.5), false, 2.0)
