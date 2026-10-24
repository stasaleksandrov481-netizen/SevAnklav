# ============================================================
# TRENCH.GD — окоп (зона-траншея, Area2D)
#
# Поведение:
#   • не блокирует движение;
#   • юнит внутри движется медленнее (speed_mult = Speed Factor);
#   • юниту выставляется флаг in_trench = true — ИИ и стрельба
#     могут учитывать это как укрытие/маскировку.
#
# КОНТРАКТ ДЛЯ ЮНИТОВ (игрок уже поддерживает):
#     var speed_mult: float = 1.0   # множитель скорости
#     var in_trench: bool = false   # внутри окопа
#
# Сцена: scenes/props/Trench.tscn
# Ставь несколько Trench вплотную — получится линия окопов.
# ============================================================
class_name Trench
extends Area2D

## во сколько раз медленнее движение внутри окопа
@export var speed_factor: float = 0.55

var _inside: Dictionary = {}


func _ready() -> void:
	add_to_group("trenches")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.get("speed_mult") == null:
		return
	_inside[body] = int(_inside.get(body, 0)) + 1
	if int(_inside[body]) == 1:
		body.set("speed_mult", speed_factor)
		if "in_trench" in body:
			body.in_trench = true


func _on_body_exited(body: Node2D) -> void:
	if not _inside.has(body):
		return
	_inside[body] = int(_inside[body]) - 1
	if int(_inside[body]) <= 0:
		_inside.erase(body)
		body.set("speed_mult", 1.0)
		if "in_trench" in body:
			body.in_trench = false
