# ============================================================
# PROP_BASE.GD — базовый класс всех ТВЁРДЫХ префабов
# (забор, дерево, камень, мебель, стена-укрытие и т.д.)
#
# Что даёт:
#   • StaticBody2D — игрок (CharacterBody2D) и боты физически
#     упираются в объект через move_and_slide().
#   • Пул урона (hp) и метод take_damage() — пули (Bullet.tscn)
#     вызывают его автоматически при попадании.
#   • Сигналы damaged / destroyed — чтобы реагировать из
#     других скриптов (квесты, звук, анимация разрушения).
#
# Как сделать свой объект: см. prop_template.gd / PropTemplate.tscn
# ============================================================
class_name PropBase
extends StaticBody2D

## Урон засчитывается только если включено (забор — да, скала — нет).
@export var destructible: bool = false
## Прочность объекта (условные единицы урона).
@export var max_hp: float = 60.0
## Цвет вспышки при попадании.
@export var hit_flash: Color = Color(1.0, 0.82, 0.55)

## Выдаётся, когда hp изменился (остаток передаётся аргументом).
signal damaged(hp_left: float)
## Выдаётся один раз при разрушении объекта.
signal destroyed

var hp: float = 0.0

@onready var _sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
@onready var _collision: CollisionShape2D = get_node_or_null("Collision") as CollisionShape2D


func _ready() -> void:
	hp = max_hp
	add_to_group("props")
	if destructible:
		add_to_group("damageable")


# ------------------------------------------------------------
# ЕДИНЫЙ КОНТРАКТ УРОНА.
# Любая пуля/взрыв вызывает take_damage(dmg, источник).
# ------------------------------------------------------------
func take_damage(amount: float, _source = null) -> void:
	if not destructible or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(hp)
	_flash()
	if hp <= 0.0:
		_destroy()


func _flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = hit_flash
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


func _destroy() -> void:
	destroyed.emit()
	if _collision != null:
		# deferred — вызов мог прийти из физического колбэка пули
		_collision.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
