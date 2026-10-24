# ============================================================
# BUSH.GD — куст (зона маскировки, Area2D)
#
# Поведение:
#   • НЕ блокирует движение — в куст можно зайти;
#   • как только игрок или бот заходит внутрь, у него
#     включается переменная is_hidden = true;
#   • когда выходит из куста — is_hidden = false;
#   • корректно работает с несколькими пересекающимися
#     кустами (скрытие снимается только после выхода из ВСЕХ).
#
# КОНТРАКТ ДЛЯ БОТОВ: чтобы куст скрывал твоего бота, в скрипте
# бота должна быть переменная:
#     var is_hidden: bool = false
# и ИИ бота должен её проверять (не видеть скрытые цели).
# Игрок (Player.tscn) уже поддерживает это из коробки.
# ============================================================
class_name Bush
extends Area2D

## Выдаётся, когда у юнита изменилась маскировка: (юнит, скрыт?)
signal concealment_changed(body: Node2D, hidden: bool)

## кто сейчас внутри (юнит -> счётчик вхождений)
var _inside: Dictionary = {}


func _ready() -> void:
	add_to_group("bushes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not _supports_hidden(body):
		return
	_inside[body] = int(_inside.get(body, 0)) + 1
	if int(_inside[body]) == 1:
		_apply(body, true)


func _on_body_exited(body: Node2D) -> void:
	if not _inside.has(body):
		return
	_inside[body] = int(_inside[body]) - 1
	if int(_inside[body]) <= 0:
		_inside.erase(body)
		_apply(body, false)


func _apply(body: Node2D, hidden: bool) -> void:
	if body.has_method("set_is_hidden"):
		body.set_is_hidden(hidden)
	elif "is_hidden" in body:
		body.is_hidden = hidden
	concealment_changed.emit(body, hidden)


func _supports_hidden(body: Node2D) -> bool:
	return body.has_method("set_is_hidden") or body.get("is_hidden") != null
