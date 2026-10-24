# ============================================================
# BULLET.GD — простая пуля (Area2D), демонстрация урона
#
# Поведение:
#   • летит прямо, пока не кончится дальность;
#   • попав в объект со скриптом take_damage() (забор, дерево
#     с включённой разрушаемостью) — наносит урон и исчезает;
#   • попав в обычную стену (StaticBody2D без take_damage) —
#     просто гаснет;
#   • живые существа без take_damage пропускает насквозь
#     (в боевом коде замени на свою логику попаданий).
#
# Сцена: scenes/props/Bullet.tscn
# Спавн из кода:
#     var b := BULLET_SCENE.instantiate()
#     get_parent().add_child(b)
#     b.global_position = дуло
#     b.launch(направление)
# ============================================================
class_name Bullet
extends Area2D

@export var speed: float = 900.0
@export var damage: float = 12.0
@export var max_range: float = 900.0

var dir := Vector2.RIGHT
var _traveled := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(direction: Vector2) -> void:
	dir = direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	var step := dir * speed * delta
	position += step
	_traveled += step.length()
	if _traveled >= max_range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
		queue_free()
	elif body is StaticBody2D:
		# обычная стена/скала — пуля гаснет
		queue_free()
