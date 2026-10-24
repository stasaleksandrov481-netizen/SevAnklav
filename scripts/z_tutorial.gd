# ============================================================
# ZTUTORIAL — СИСТЕМА ИНТЕРАКТИВНЫХ ПОДСКАЗОК ОБУЧЕНИЯ
# Отдельный модуль (по ТЗ №1): контекстные подсказки
# «ОБУЧЕНИЕ» с SVG-иконкой, заголовком и текстом.
# Очередь с приоритетом, авто-скрытие, кнопка ПОНЯТНО,
# защита от повторов. Шаги Сектора 1 прописаны здесь.
# ============================================================
class_name ZTutorial
extends CanvasLayer

var host: Node = null               # battle-нод (для ui_layer-родителя)
var btl = null                      # battle_z: прячет подсказки, пока игрок в капсуле
var shown: Dictionary = {}          # id → true (показаны в этой сессии)
var queue: Array = []               # [{id, icon, title, text, prio}]
var cur: Dictionary = {}
var panel: PanelContainer = null
var text_lbl: Label = null
var title_lbl: Label = null
var icon_tr: TextureRect = null
var auto_t := 0.0
var slide_t: float = 0.0 # таймер анимации появления подсказки

func _ready() -> void:
				layer = 40
				_build_ui()

func _build_ui() -> void:
				var root := Control.new()
				root.set_anchors_preset(Control.PRESET_FULL_RECT)
				root.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(root)
				panel = PanelContainer.new()
				var sb := ZUI.panel_style(Color(0.045, 0.055, 0.048, 0.96), ZUI.NEON_DIM, 14)
				sb.border_width_left = 3
				panel.add_theme_stylebox_override("panel", sb)
				panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
				panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
				panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
				panel.offset_left = -330
				panel.offset_right = 330
				panel.offset_top = -222
				panel.offset_bottom = -154   # FIX7: выше опущенного бара быстрых слотов (-136..-44)
				panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.modulate.a = 0.0
				root.add_child(panel)
				var h := HBoxContainer.new()
				h.add_theme_constant_override("separation", 12)
				h.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.add_child(h)
				icon_tr = TextureRect.new()
				icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_tr.custom_minimum_size = Vector2(40, 40)
				icon_tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				h.add_child(icon_tr)
				var vb := VBoxContainer.new()
				vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vb.add_theme_constant_override("separation", 2)
				vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				h.add_child(vb)
				title_lbl = ZUI.label("", 14, ZUI.NEON_BRIGHT)
				vb.add_child(title_lbl)
				text_lbl = ZUI.wrap_label("", 13, ZUI.TEXT, 540.0)
				vb.add_child(text_lbl)
# FIX11: кнопка «ПОНЯТНО» — подсказку можно убрать сразу
				var ok_btn := Button.new()
				ok_btn.text = "ПОНЯТНО"
				ok_btn.focus_mode = Control.FOCUS_NONE
				ok_btn.mouse_filter = Control.MOUSE_FILTER_STOP
				ok_btn.custom_minimum_size = Vector2(112, 34)
				ok_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var obs := StyleBoxFlat.new()
				obs.bg_color = Color(0.07, 0.095, 0.08, 0.9)
				obs.border_color = ZUI.NEON_DIM
				obs.set_border_width_all(1)
				obs.set_corner_radius_all(10)
				ok_btn.add_theme_stylebox_override("normal", obs)
				var obh := obs.duplicate()
				obh.bg_color = Color(0.11, 0.15, 0.125, 0.95)
				obh.border_color = ZUI.NEON
				ok_btn.add_theme_stylebox_override("hover", obh)
				ok_btn.add_theme_color_override("font_color", ZUI.TEXT)
				ok_btn.add_theme_font_size_override("font_size", 12)
				ok_btn.pressed.connect(dismiss)
				h.add_child(ok_btn)

# ---------- публичный API ----------
func hint(id: String, icon_name: String, title: String, text: String, prio := 0) -> void:
				if shown.has(id):
								return
				# дубль в очереди не нужен
				for q in queue:
								if q["id"] == id:
												return
				queue.append({"id": id, "icon": icon_name, "title": title, "text": text, "prio": prio})
				queue.sort_custom(func(a, b): return int(a["prio"]) > int(b["prio"]))
				_try_next()

func _try_next() -> void:
				if not cur.is_empty() or queue.is_empty():
								return
				# в капсуле интерфейса нет — подсказка подождёт выхода
				if btl != null and bool(btl.get("in_capsule")):
								return
				# FIX7: пока открыт любой интерфейс (РЮКЗАК/КПК/пауза/обыск) — подсказка
				# НЕ выскакивает поверх окна и не висит поверх вкладок; подождёт закрытия
				if btl != null and bool(btl.get("paused")):
								return
				cur = queue.pop_front()
				shown[cur["id"]] = true
				icon_tr.texture = ZUI.icon(str(cur["icon"]))
				icon_tr.modulate = ZUI.NEON_BRIGHT
				title_lbl.text = "ОБУЧЕНИЕ · " + str(cur["title"])
				text_lbl.text = str(cur["text"])
				G.play_sfx("radio", -14.0)
				auto_t = 11.0
				slide_t = 0.0
				panel.modulate.a = 0.0
				if btl != null and bool(btl.get("in_capsule")):
								return
				var tw := panel.create_tween()
				tw.tween_property(panel, "modulate:a", 1.0, 0.3)

func dismiss() -> void:
				if cur.is_empty():
								return
				cur = {}
				var tw := panel.create_tween()
				tw.tween_property(panel, "modulate:a", 0.0, 0.22)
				tw.tween_callback(_try_next)

func _process(delta: float) -> void:
				if btl != null and bool(btl.get("in_capsule")):
								panel.visible = false
								return
				# FIX7: окно открыто — прячем панель обучения (не поверх вкладок!)
				if btl != null and bool(btl.get("paused")):
								panel.visible = false
								return
				panel.visible = true
				if cur.is_empty():
								return
				slide_t = minf(slide_t + delta, 1.0)
				auto_t -= delta
				if auto_t <= 0.0:
								dismiss()

# кнопка ПОНЯТНО вызывается из battle (по нажатию на панель — сделаем кнопку отдельной)
# ---------- ШАГИ ОБУЧЕНИЯ СЕКТОРА 1 (бункер «ЗАРЯ») ----------
func bunker_flow(host_btl) -> void:
				# вызывается из battle_z.gd при старте бункера.
				btl = host_btl
				# Шаги «лекарство/снаряжение/тело/сканер/лестница» приходят
				# контекстно из battle_z.gd — здесь только стартовая подсказка.
				# подсказка капсулы убрана: в капсуле по ТЗ нет интерфейса,
				# единственная кнопка [ВЫБИТЬ СТЕКЛО] видна и без обучения.
