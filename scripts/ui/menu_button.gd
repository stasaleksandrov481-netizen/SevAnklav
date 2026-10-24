# ============================================================
# FIX9: КНОПКА ГЛАВНОГО МЕНЮ ДЛЯ СЦЕН (editor-friendly)
# Раньше кнопки меню создавались кодом (UiKit.MenuBtn.new) — их
# нельзя было двигать в редакторе. Теперь кнопка — обычный узел
# сцены MainMenu.tscn: двигай мышью, меняй текст/иконку/размер
# в инспекторе. Внешне повторяет стиль UiKit.MenuBtn 1:1.
# ============================================================
class_name MenuBtnEx
extends Button

@export var icon_name := ""          # имя иконки из assets/icons (без .svg)
@export var accent := false          # главная кнопка — янтарная подсветка
@export var font_size := 19          # размер шрифта

var _ic: TextureRect = null
var _chev: Label = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", font_size)
	_restyle()
	if icon_name != "":
		_build_icon()
	_build_chevron()
	_build_gloss()
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	button_down.connect(func(): scale = Vector2(0.985, 0.985))
	button_up.connect(func(): scale = Vector2.ONE)
	pivot_offset = size / 2.0


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


func _svg_tex(nm: String) -> Texture2D:
	var p := "res://assets/icons/%s.svg" % nm
	if ResourceLoader.exists(p):
		return load(p)
	return null


func _build_icon() -> void:
	# гнездо-подложка под иконку (глубина)
	var socket := Panel.new()
	var sks := StyleBoxFlat.new()
	sks.bg_color = Color(1, 1, 1, 0.045)
	sks.set_corner_radius_all(9)
	sks.border_color = Color(1, 1, 1, 0.06)
	sks.set_border_width_all(1)
	socket.add_theme_stylebox_override("panel", sks)
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	socket.offset_left = 14
	socket.offset_right = 54
	socket.offset_top = -20
	socket.offset_bottom = 20
	add_child(socket)
	_ic = TextureRect.new()
	var t := G.tex(icon_name)
	_ic.texture = t if t != null else _svg_tex(icon_name)
	_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ic.custom_minimum_size = Vector2(28, 28)
	_ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_ic.offset_left = 20
	_ic.offset_right = 48
	_ic.offset_top = -14
	_ic.offset_bottom = 14
	_ic.modulate = UiKit.AMBER_BRIGHT if accent else UiKit.MUTED
	add_child(_ic)


func _build_chevron() -> void:
	_chev = Label.new()
	_chev.text = "›"
	_chev.add_theme_font_size_override("font_size", font_size + 8)
	_chev.add_theme_color_override("font_color", UiKit.AMBER)
	_chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chev.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_chev.offset_left = -40
	_chev.offset_right = -16
	_chev.offset_top = -20
	_chev.offset_bottom = 20
	_chev.modulate.a = 0.25
	add_child(_chev)


func _build_gloss() -> void:
	# глянец сверху и внутренняя тень снизу — «стальная плита»
	var gloss := ColorRect.new()
	gloss.color = Color(1, 1, 1, 0.055)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 10
	gloss.offset_right = -10
	gloss.offset_top = 1
	gloss.offset_bottom = 3
	add_child(gloss)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.20)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_left = 10
	shade.offset_right = -10
	shade.offset_top = -4
	shade.offset_bottom = -2
	add_child(shade)


func _restyle() -> void:
	var sb := StyleBoxFlat.new()
	var sbh: StyleBoxFlat
	var sbp: StyleBoxFlat
	if accent:
		sb.bg_color = Color(0.185, 0.14, 0.065, 0.94)
		sb.border_color = Color(0.62, 0.48, 0.22)
		sbh = sb.duplicate()
		sbh.bg_color = Color(0.27, 0.205, 0.09, 0.97)
		sbh.border_color = UiKit.AMBER_BRIGHT
		sbp = sbh.duplicate()
		sbp.bg_color = Color(0.13, 0.10, 0.05)
	else:
		sb.bg_color = Color(0.078, 0.088, 0.074, 0.92)
		sb.border_color = Color(0.30, 0.325, 0.255, 0.95)
		sbh = sb.duplicate()
		sbh.bg_color = Color(0.115, 0.128, 0.105, 0.94)
		sbh.border_color = UiKit.AMBER
		sbp = sbh.duplicate()
		sbp.bg_color = Color(0.045, 0.052, 0.044)
	sb.set_corner_radius_all(10)
	sbh.set_corner_radius_all(10)
	sbp.set_corner_radius_all(10)
	# скошенный янтарный язык слева (полоска-«язычок»)
	sb.border_width_left = 4
	sbh.border_width_left = 5
	sbp.border_width_left = 4
	if accent:
		sb.border_color = Color(0.72, 0.55, 0.24)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	sbh.shadow_size = 16
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sbh)
	add_theme_stylebox_override("pressed", sbp)
	add_theme_stylebox_override("disabled", sb.duplicate())
	add_theme_color_override("font_color", UiKit.AMBER_BRIGHT if accent else UiKit.TEXT)
	add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.78) if not accent else Color(1.0, 0.95, 0.85))
	add_theme_color_override("font_pressed_color", UiKit.TEXT)
	add_theme_color_override("font_disabled_color", UiKit.FAINT)


func _on_enter() -> void:
	G.play_sfx("ui_click", -20.0, 1.7)
	if _ic != null:
		_ic.modulate = UiKit.AMBER_BRIGHT
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_chev, "modulate:a", 1.0, 0.12)
	tw.tween_property(_chev, "offset_left", -34.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.015, 1.015), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_exit() -> void:
	if _ic != null:
		_ic.modulate = UiKit.AMBER_BRIGHT if accent else UiKit.MUTED
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_chev, "modulate:a", 0.25, 0.16)
	tw.tween_property(_chev, "offset_left", -40.0, 0.16)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
