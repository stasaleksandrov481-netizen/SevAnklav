# ============================================================
# FIX9: СВОБОДНАЯ ЛОКАЦИЯ (хаб) — базовый скрипт сцены-локации.
# Так работают scenes/locations/Surface.tscn и все твои будущие
# локации: игрок ходит по префабам (Bush/Tree/Fence...), а двери
# ExitDoor.tscn переводят его между сценами.
# Обязательная структура сцены:
#   Локация (Node2D, этот скрипт, Y Sort включён)
#   ├── Ground   — спрайт земли (region, tile)
#   ├── Walls    — StaticBody2D с границами карты
#   ├── Spawns   — Marker2D-точки входа (Main, FromBunker, ...)
#   ├── Player   — экземпляр Player.tscn
#   └── Exits    — экземпляры ExitDoor.tscn
# ESC — выход в главное меню.
# ============================================================
class_name FreeRoam
extends Node2D

@export var location_title := "ЛОКАЦИЯ"

var _leaving := false


func _ready() -> void:
	add_to_group("free_roam")


# main.gd вызывает после загрузки сцены: ставим игрока в точку входа
func enter(spawn_id: String = "Main") -> void:
	var pl := get_node_or_null("Player")
	var sp := get_node_or_null("Spawns/" + spawn_id)
	if pl == null:
		return
	if sp != null:
		pl.position = sp.position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


func _to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	var mains := get_tree().get_nodes_in_group("main_root")
	if mains.size() > 0 and mains[0].has_method("to_main_menu"):
		mains[0].to_main_menu()
	else:
		# сцена запущена отдельно (F6) — просто перезапуск
		get_tree().reload_current_scene()
