# ============================================================
# FENCE.GD — забор (разрушаемый твёрдый объект)
#
# Поведение:
#   • непроходим (StaticBody2D): игрок и боты упираются;
#   • при попадании пули (Bullet.tscn → take_damage) принимает
#     урон, вспыхивает;
#   • при hp <= 0 разрушается: коллизия выключается, летят
#     щепки, объект исчезает.
#
# Сцена: scenes/props/Fence.tscn
# Вертикальный забор: поставь Fence и поверни на 90° (rotation),
# коллизия повернётся вместе с спрайтом.
# ============================================================
class_name Fence
extends PropBase


func _ready() -> void:
		# забор всегда разрушаем — можно переопределить в инспекторе
		destructible = true
		max_hp = 40.0
		super()
		destroyed.connect(_on_destroyed)


func _on_destroyed() -> void:
		_spawn_splinters()


func _spawn_splinters() -> void:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = 14
		p.lifetime = 0.55
		p.explosiveness = 1.0
		p.direction = Vector2(0, -1)
		p.spread = 70.0
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 220.0
		p.gravity = Vector2(0, 640)
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.5
		p.color = Color(0.55, 0.38, 0.22)
		p.z_index = 9
		# важно: добавляем щепки к РОДИТЕЛЮ, а не к забору —
		# забор растворится через 0.35 с и утащил бы частицы с собой
		var host := get_parent()
		if host == null:
				host = self
		host.add_child(p)
		p.global_position = global_position
		var tw := create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(p.queue_free)
