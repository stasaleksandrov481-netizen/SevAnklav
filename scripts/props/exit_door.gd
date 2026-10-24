# ============================================================
# FIX9: ДВЕРЬ-ПЕРЕХОД МЕЖДУ ЛОКАЦИЯМИ (префаб ExitDoor.tscn)
# Поставь её на сцену локации, в инспекторе укажи:
#   target_scene — путь к сцене, куда ведёт дверь
#                  (например res://scenes/locations/Surface.tscn)
#   target_spawn — имя точки входа в той сцене (узел Spawns/<имя>)
#   door_label   — подпись над дверью
#   locked_text  — НЕ пусто = дверь заперта (покажет сообщение)
#   ends_chapter — true = дверь завершает главу (финальный экран)
# Игрок вошёл в зону -> загрузка целевой сцены через main.open_location.
# ============================================================
class_name ExitDoor
extends Area2D

@export_file("*.tscn") var target_scene := ""
@export var target_spawn := "Main"
@export var door_label := "ВЫХОД"
@export var locked_text := ""          # пусто = открыта
@export var ends_chapter := false

var _used := false
var _label_default := ""

@onready var _lbl: Label = get_node_or_null("Label")


func _ready() -> void:
	if _lbl != null:
		_label_default = _lbl.text
		_lbl.text = door_label
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if _used or not (b is Player):
		return
	if locked_text != "":
		_show_locked()
		return
	_used = true
	var mains := get_tree().get_nodes_in_group("main_root")
	if mains.size() == 0:
		_used = false
		return
	var m: Node = mains[0]
	if ends_chapter and m.has_method("end_of_chapter"):
		m.end_of_chapter()
	elif target_scene != "" and m.has_method("open_location"):
		m.open_location(target_scene, target_spawn)
	else:
		_used = false


func _show_locked() -> void:
	G.play_sfx("ui_click", -8.0, 0.8)
	if _lbl == null:
		return
	_lbl.text = locked_text
	_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	var t := get_tree().create_timer(2.2)
	t.timeout.connect(func():
		if is_instance_valid(_lbl):
			_lbl.text = door_label
			_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4)))
