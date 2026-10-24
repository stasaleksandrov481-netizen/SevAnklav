# ============================================================
# PLAYER.GD — главный персонаж, Top-Down на CharacterBody2D
#
# УПРАВЛЕНИЕ
#   • Ходьба: WASD / стрелки / левый стик геймпада /
#     виртуальный джойстик (укажи Joystick Path в инспекторе,
#     у узла должен быть метод get_move_vector() -> Vector2).
#   • БЕГ: двойной тап по направлению (потянул-отпустил-
#     потянул быстро) — бег, пока держишь. Отпустил стик и
#     снова потянул — снова обычный шаг. На ПК ещё и Shift.
#   • Стрельба (демо): ЛКМ / Пробел / кнопка Shoot.
#
# КОНТРАКТЫ, КОТОРЫЕ УЖЕ ПОДДЕРЖАНЫ:
#   • is_hidden  — кусты (Bush.tscn) включают/выключают сами;
#   • speed_mult — окопы (Trench.tscn) замедляют автоматически;
#   • in_trench  — флаг «я в окопе» для твоего ИИ.
# Ботам достаточно завести те же три переменные в своих скриптах.
#
# Сцена: scenes/props/Player.tscn (спрайт/коллизия/камера внутри)
# ============================================================
class_name Player
extends CharacterBody2D

@export var walk_speed: float = 160.0
@export var run_speed: float = 250.0          # ~x1.55, как в боевой системе
@export var acceleration: float = 1500.0
## (необязательно) узел виртуального джойстика с методом get_move_vector()
@export var joystick_path: NodePath
## сцена пули для демо-стрельбы (можно очистить — стрельба отключится)
@export var bullet_scene: PackedScene

var is_hidden: bool = false      # трогают кусты (Bush.gd)
var speed_mult: float = 1.0      # трогают окопы (Trench.gd)
var in_trench: bool = false      # трогают окопы (Trench.gd)
var facing := Vector2.UP         # куда смотрит персонаж

const DOUBLE_TAP_MS := 300       # окно двойного тапа для бега

var _run := false
var _was_moving := false
var _release_ms := -10000

@onready var sprite: Sprite2D = $Sprite as Sprite2D


func _physics_process(delta: float) -> void:
	var dir := _move_dir()
	_update_run_state(dir)
	facing = dir if dir.length() > 0.1 else facing

	var speed := (run_speed if _is_running(dir) else walk_speed) * speed_mult
	velocity = velocity.move_toward(dir * speed, acceleration * delta)
	move_and_slide()

	_update_visuals(dir)


# ---------------------- ВВОД ----------------------
func _move_dir() -> Vector2:
	var v := Vector2.ZERO
	if InputMap.has_action("move_left") and InputMap.has_action("move_right") \
			and InputMap.has_action("move_up") and InputMap.has_action("move_down"):
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not joystick_path.is_empty():
		var j := get_node_or_null(joystick_path)
		if j != null and j.has_method("get_move_vector"):
			var jv: Vector2 = j.get_move_vector()
			if jv.length() > 0.2:
				v = jv
	return v


# Бег: двойной тап по направлению = бег до отпускания.
# Отпустил и снова потянул = снова шаг (как на мобильных стиках).
func _update_run_state(dir: Vector2) -> void:
	var moving := dir.length() > 0.2
	var now := Time.get_ticks_msec()
	if moving and not _was_moving:
		_run = (now - _release_ms) <= DOUBLE_TAP_MS
	if not moving and _was_moving:
		_release_ms = now
		_run = false
	_was_moving = moving
	if Input.is_key_pressed(KEY_SHIFT) and moving:
		_run = true


func _is_running(dir: Vector2) -> bool:
	return _run and dir.length() > 0.1 and speed_mult > 0.99


func _unhandled_input(event: InputEvent) -> void:
	if bullet_scene != null and event.is_action_pressed("shoot"):
		_shoot()


# ---------------------- ВИЗУАЛ ----------------------
func _update_visuals(dir: Vector2) -> void:
	if absf(dir.x) > 0.05:
		sprite.flip_h = dir.x < 0.0
	# лёгкое покачивание при ходьбе, чтобы персонаж «жил»
	if velocity.length() > 10.0:
		sprite.offset.y = -absf(sin(Time.get_ticks_msec() * 0.012 * speed_mult)) * 3.0
	else:
		sprite.offset.y = 0.0


# ---------------- ДЕМО-СТРЕЛЬБА ----------------
# Проверка урона по забору. Не нужна — очисти Bullet Scene
# в инспекторе, и стрельба отключится.
func _shoot() -> void:
	var aim := _aim_dir()
	var b := bullet_scene.instantiate() as Bullet
	get_parent().add_child(b)
	b.global_position = global_position + aim * 26.0
	b.launch(aim)


func _aim_dir() -> Vector2:
	# на ПК целимся мышью, на таче — по направлению движения
	if not DisplayServer.is_touchscreen_available():
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 6.0:
			return to_mouse.normalized()
	return facing
