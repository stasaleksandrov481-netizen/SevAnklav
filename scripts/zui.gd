# ============================================================
# ZUI — ЕДИНЫЙ ИНТЕРФЕЙС-НАБОР КАМПАНИИ «ЗЕМЛЯ МЕРТВЫХ»
# Мрачный милитари-постапокалипсис: графит, ржавый металл,
# полупрозрачные плашки, неоново-зелёные и аварийно-красные акценты.
# ИКОНКИ: SVG-файлы из assets/icons (TextureRect / modulate-tint).
# Используется: пролог, бой бункера/секторов, медицина, КПК,
# карта кампании. Военная тема (UiKit, янтарь) не тронута.
# ============================================================
class_name ZUI

# ---------- палитра «северный бункер» ----------
const BG := Color(0.018,0.027,0.036)                 # почти чёрный, холодный
const PANEL := Color(0.047,0.070,0.088,0.97)        # графит
const PANEL_DIM := Color(0.026,0.043,0.057,0.97)    # тёмный графит
const PANEL_RUST := Color(0.075,0.038,0.035,0.97)   # ржавый металл
const BORDER := Color(0.30,0.41,0.47)                # сталь
const BORDER_SOFT := Color(0.16,0.25,0.31)
const BORDER_RUST := Color(0.46, 0.30, 0.20)           # ржавая кромка
const NEON := Color(0.40,0.70,0.79)                  # неоново-зелёный (аварийные выходы)
const NEON_BRIGHT := Color(0.67,0.88,0.94)
const NEON_DIM := Color(0.18,0.36,0.43)
const ALERT := Color(0.95,0.28,0.22)                 # аварийно-красный
const ALERT_DIM := Color(0.52, 0.18, 0.15)
const WARN := Color(0.90, 0.66, 0.25)                  # предупреждение (ржаво-янтарный)
const TEXT := Color(0.85,0.89,0.91)                  # пыльно-белый
const MUTED := Color(0.54,0.64,0.69)
const FAINT := Color(0.36,0.46,0.52)
const BLOOD := Color(0.72, 0.16, 0.12)
const ICE := Color(0.62, 0.74, 0.86)                   # зимний север (карта)

# ---------- SVG-ИКОНКИ ----------
# Файлы лежат в assets/icons/<name>.svg. Загружаются лениво, кэшируются.
static var _icon_cache: Dictionary = {}

static func icon(name: String) -> Texture2D:
        if _icon_cache.has(name):
                return _icon_cache[name]
        var p := "res://assets/icons/%s.svg" % name
        var t: Texture2D = null
        if ResourceLoader.exists(p):
                t = load(p)
        _icon_cache[name] = t
        return t

# TextureRect с SVG-иконкой (чётко на любых разрешениях)
static func icon_rect(name: String, px := 22.0, tint := TEXT) -> TextureRect:
        var tr := TextureRect.new()
        var t := icon(name)
        tr.texture = t
        tr.custom_minimum_size = Vector2(px, px)
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tr.modulate = tint
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return tr

# ---------- базовые элементы ----------
static func label(text: String, size: int, col := TEXT) -> Label:
        var l := Label.new()
        l.text = text
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
        l.add_theme_constant_override("shadow_offset_x", 1)
        l.add_theme_constant_override("shadow_offset_y", 1)
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return l

static func wrap_label(text: String, size: int, col := TEXT, width := 460.0) -> Label:
        var l := label(text, size, col)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(width, 0)
        return l

# технический шрифт: тот же базовый шрифт + межбуквенный интервал —
# для служебных строк, тегов системы и архивных дат (ТЗ п.4)
static func tech_font(spacing := 2) -> FontVariation:
        var fv := FontVariation.new()
        fv.base_font = ThemeDB.fallback_font
        fv.spacing_glyph = spacing
        return fv

# приглушённая версия цвета роли для тегов: читается, но не кричит
static func muted_tag(col: Color) -> Color:
        return col.lerp(Color(0.58, 0.62, 0.58), 0.42).darkened(0.04)

static func hdivider(width := 2.0, col := BORDER_SOFT) -> ColorRect:
        var r := ColorRect.new()
        r.color = col
        r.custom_minimum_size = Vector2(width, 2)
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return r

# панель: тёмный металл с полупрозрачностью, ржавая или стальная кромка
static func panel_style(bg := PANEL, border := BORDER_SOFT, margin := 16.0, rust := false) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.border_color = BORDER_RUST if rust else border
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(4)
        sb.content_margin_left = margin
        sb.content_margin_right = margin
        sb.content_margin_top = margin * 0.7
        sb.content_margin_bottom = margin * 0.8
        if rust:
                # ржавая плашка: светлая полоса износа сверху
                sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
                sb.shadow_size = 6
        return sb

# шапка секции: SVG-иконка + заголовок (стиль КПК)
static func section_head(vb: VBoxContainer, text: String, icon_name := "gear", col := NEON, isize := 20.0) -> void:
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 10)
        var ic := icon_rect(icon_name, isize, col)
        ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        head.add_child(ic)
        var tl := label(text, 15, col)
        tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        head.add_child(tl)
        vb.add_child(head)
        vb.add_child(hdivider(1, BORDER_SOFT))

# чип статуса: SVG-иконка + подпись (кровь, перелом, заражение, патроны...)
static func chip(icon_name: String, text: String, col := TEXT, isize := 20.0, fsize := 13) -> HBoxContainer:
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 7)
        h.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.add_child(icon_rect(icon_name, isize, col))
        var l := label(text, fsize, col)
        l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        h.add_child(l)
        return h

# ---------- КНОПКА «ЖЕЛЕЗО» ----------
# Графитовая плита с неоновой/ржавой планкой слева; при наведении
# планка разгорается, плита чуть подаётся вперёд. Звук клика.
class ZButton extends Button:
        var bar: ColorRect
        var accent := false          # true — неоново-зелёная (основное действие)
        var danger := false          # true — аварийно-красная
        var ic_name := ""            # SVG-иконка слева от текста (опционально)
        var icon_size := 26.0
        var _icon_tr: TextureRect = null
        var _label: Label = null

        func _init(txt: String, msize := Vector2(320, 52), is_accent := false, fsize := 16, icon_nm := "") -> void:
                accent = is_accent
                ic_name = icon_nm
                text = txt
                custom_minimum_size = msize
                add_theme_font_size_override("font_size", fsize)
                focus_mode = Control.FOCUS_NONE
                _restyle()
                bar = ColorRect.new()
                bar.color = _bar_color(false)
                bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
                bar.offset_left = 0
                bar.offset_right = 3
                bar.offset_top = 6
                bar.offset_bottom = -6
                bar.modulate.a = 0.4
                add_child(bar)
                # иконка поверх кнопки (текст рисуется темой кнопки)
                if ic_name != "":
                        _icon_tr = TextureRect.new()
                        _icon_tr.texture = ZUI.icon(ic_name)
                        _icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                        _icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                        _icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        _icon_tr.custom_minimum_size = Vector2(icon_size, icon_size)
                        _icon_tr.set_anchors_preset(Control.PRESET_CENTER_LEFT)
                        _icon_tr.offset_left = 16
                        _icon_tr.offset_right = 16 + icon_size
                        _icon_tr.offset_top = -icon_size / 2.0
                        _icon_tr.offset_bottom = icon_size / 2.0
                        _icon_tr.modulate = _text_color()
                        add_child(_icon_tr)

        func _bar_color(hot: bool) -> Color:
                if danger:
                        return ALERT if hot else ALERT_DIM
                if accent:
                        return NEON_BRIGHT if hot else NEON
                return Color(0.45, 0.50, 0.46) if hot else Color(0.30, 0.34, 0.31)

        func _text_color() -> Color:
                if danger:
                        return Color(0.98, 0.62, 0.55)
                if accent:
                        return NEON_BRIGHT
                return TEXT

        func _restyle() -> void:
                var sb := StyleBoxFlat.new()
                var sbh: StyleBoxFlat
                var sbp: StyleBoxFlat
                if danger:
                        sb.bg_color = Color(0.16, 0.062, 0.05)
                        sb.border_color = ALERT_DIM
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.23, 0.085, 0.068)
                        sbh.border_color = ALERT
                        sbp = sbh.duplicate()
                        sbp.bg_color = Color(0.11, 0.045, 0.038)
                elif accent:
                        sb.bg_color = Color(0.055, 0.115, 0.075)
                        sb.border_color = Color(0.16, 0.42, 0.26)
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.075, 0.165, 0.105)
                        sbh.border_color = NEON
                        sbp = sbh.duplicate()
                        sbp.bg_color = Color(0.04, 0.085, 0.055)
                else:
                        sb.bg_color = Color(0.10, 0.11, 0.12)
                        sb.border_color = BORDER_SOFT
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.15, 0.165, 0.175)
                        sbh.border_color = BORDER
                        sbp = sbh.duplicate()
                        sbp.bg_color = Color(0.065, 0.07, 0.078)
                sb.set_corner_radius_all(3)
                sbh.set_corner_radius_all(3)
                sbp.set_corner_radius_all(3)
                add_theme_stylebox_override("normal", sb)
                add_theme_stylebox_override("hover", sbh)
                add_theme_stylebox_override("pressed", sbp)
                add_theme_stylebox_override("disabled", sb.duplicate())
                var tc := _text_color()
                add_theme_color_override("font_color", tc)
                add_theme_color_override("font_hover_color", Color(1, 1, 0.98) if not danger else Color(1, 0.72, 0.65))
                add_theme_color_override("font_pressed_color", tc)
                add_theme_color_override("font_disabled_color", FAINT)

        func set_icon(nm: String) -> void:
                ic_name = nm
                if _icon_tr != null:
                        _icon_tr.texture = ZUI.icon(nm)
                elif nm != "":
                        _icon_tr = TextureRect.new()
                        _icon_tr.texture = ZUI.icon(nm)
                        _icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                        _icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                        _icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        _icon_tr.custom_minimum_size = Vector2(icon_size, icon_size)
                        _icon_tr.set_anchors_preset(Control.PRESET_CENTER_LEFT)
                        _icon_tr.offset_left = 16
                        _icon_tr.offset_right = 16 + icon_size
                        _icon_tr.offset_top = -icon_size / 2.0
                        _icon_tr.offset_bottom = icon_size / 2.0
                        _icon_tr.modulate = _text_color()
                        add_child(_icon_tr)

        func _ready() -> void:
                mouse_entered.connect(_on_enter)
                mouse_exited.connect(_on_exit)
                button_down.connect(func(): scale = Vector2(0.975, 0.975))
                button_up.connect(func(): scale = Vector2.ONE)
                pivot_offset = size / 2.0

        func _notification(what: int) -> void:
                if what == Control.NOTIFICATION_RESIZED:
                        pivot_offset = size / 2.0

        func _on_enter() -> void:
                G.play_sfx("ui_click", -20.0, 1.7)
                bar.modulate.a = 1.0
                bar.offset_right = 5
                if _icon_tr != null:
                        _icon_tr.modulate = Color(1, 1, 0.98)
                var tw := create_tween()
                tw.tween_property(self, "scale", Vector2(1.025, 1.025), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

        func _on_exit() -> void:
                bar.modulate.a = 0.4
                bar.offset_right = 3
                if _icon_tr != null:
                        _icon_tr.modulate = _text_color()
                var tw := create_tween()
                tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ---------- КНОПКА С УДЕРЖАНИЕМ ----------
class ZHoldButton extends Button:
        var hold_time := 0.9
        var filling := false
        var fill_t := 0.0
        var hold_done := false
        var bar: ColorRect

        func _init(txt: String, dur := 0.9) -> void:
                text = txt
                hold_time = dur
                custom_minimum_size = Vector2(360, 44)
                add_theme_font_size_override("font_size", 19)
                focus_mode = Control.FOCUS_NONE
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.07, 0.08, 0.09, 0.92)
                sb.border_color = BORDER
                sb.set_corner_radius_all(3)
                add_theme_stylebox_override("normal", sb)
                add_theme_stylebox_override("hover", sb.duplicate())
                add_theme_stylebox_override("pressed", sb.duplicate())
                add_theme_color_override("font_color", MUTED)
                add_theme_color_override("font_hover_color", TEXT)
                add_theme_color_override("font_pressed_color", TEXT)
                bar = ColorRect.new()
                bar.color = Color(NEON.r, NEON.g, NEON.b, 0.45)
                bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
                bar.offset_left = 0
                bar.offset_right = 0
                bar.offset_bottom = 0
                bar.offset_top = 0
                add_child(bar)

        func _ready() -> void:
                set_process(true)
                button_down.connect(func(): filling = true)
                button_up.connect(func(): filling = false)

        func _process(delta: float) -> void:
                if hold_done:
                        return
                if filling:
                        fill_t += delta
                        var frac: float = clampf(fill_t / hold_time, 0.0, 1.0)
                        bar.offset_top = -size.y * frac
                        if frac >= 1.0:
                                hold_done = true
                                filling = false
                                emit_signal("pressed")
                else:
                        if fill_t > 0.0:
                                fill_t = maxf(0.0, fill_t - delta * 2.2)
                        bar.offset_top = -size.y * clampf(fill_t / hold_time, 0.0, 1.0)

# ---------- ПРОПУСК КАТ-СЦЕН: УДЕРЖАНИЕ В ЛЮБОМ МЕСТЕ ----------
# Замена старой кнопки «ПРОПУСТИТЬ». Сцена пропускается удержанием
# пальца/мыши В ЛЮБОЙ точке экрана: в правом нижнем углу рисуется
# кольцо, которое заполняется, пока игрок держит. Контрол полностью
# прозрачен для GUI (IGNORE): кнопки выборов/панели продолжают
# получать свой ввод, а событие «держу» ловится через _input —
# поэтому зажимать можно даже поверх кнопок и стиков.
# Процесс всегда активен (PROCESS_MODE_ALWAYS): скип работает и на
# паузах боя (кат-сцены zp_scene ставят paused=true).
class ZSkipHold extends Control:
        signal skip_requested()

        var hold_time := 1.1
        var _t := 0.0
        var _done := false
        var _touches := {}          # index → true (мультитач)
        var _mouse_held := false
        var _last_frac := -1.0
        const RING_R := 30.0

        func _init(dur := 1.1) -> void:
                hold_time = maxf(0.4, dur)
                set_anchors_preset(Control.PRESET_FULL_RECT)
                mouse_filter = Control.MOUSE_FILTER_IGNORE
                process_mode = Node.PROCESS_MODE_ALWAYS

        func _ready() -> void:
                set_process_input(true)

        func _input(ev: InputEvent) -> void:
                if _done or not visible:
                        return
                if ev is InputEventScreenTouch:
                        var tc := ev as InputEventScreenTouch
                        if tc.pressed:
                                _touches[tc.index] = true
                        else:
                                _touches.erase(tc.index)
                elif ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                        _mouse_held = (ev as InputEventMouseButton).pressed
                elif ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed \
                                and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_START:
                        # геймпад: START = мгновенный пропуск
                        _fire()

        func _holding() -> bool:
                return _mouse_held or not _touches.is_empty()

        func _fire() -> void:
                if _done:
                        return
                _done = true
                _t = hold_time
                queue_redraw()
                skip_requested.emit()

        func _process(delta: float) -> void:
                if _done:
                        return
                var frac := _t / hold_time
                if _holding():
                        _t = minf(_t + delta, hold_time)
                        if _t >= hold_time:
                                _fire()
                                return
                elif _t > 0.0:
                        _t = maxf(0.0, _t - delta * 2.6)   # быстрый спад при отпускании
                frac = _t / hold_time
                if absf(frac - _last_frac) > 0.004:
                        _last_frac = frac
                        queue_redraw()

        func _draw() -> void:
                # ТЗ п.10: аккуратная минималистичная кнопка ПРОПУСК — тонкое
                # кольцо, двойная стрелка, подпись под кольцом; спокойные
                # состояния, контраст растёт по мере удержания
                var vp := get_viewport_rect().size
                var c := vp + Vector2(-46.0, -56.0)
                var frac: float = clampf(_t / hold_time, 0.0, 1.0)
                var hot := frac > 0.02
                # подпись под кольцом
                var lc := Color(0.66, 0.70, 0.66, 0.30 + 0.42 * frac)
                draw_string(ThemeDB.fallback_font, c + Vector2(-60.0, RING_R + 24.0),
                                "ПРОПУСК", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 10, lc)
                # тонкое внешнее кольцо (спокойное по умолчанию)
                draw_arc(c, RING_R, 0, TAU, 48, Color(0.72, 0.76, 0.72, 0.20 + 0.24 * frac), 1.6)
                # дуга прогресса удержания — сдержанный зелёный
                if frac > 0.001:
                        draw_arc(c, RING_R, -PI / 2.0, -PI / 2.0 + TAU * frac, 48,
                                        Color(0.55, 0.90, 0.62, 0.30 + 0.62 * frac), 2.6)
                        draw_arc(c, RING_R - 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40,
                                        Color(0.55, 0.90, 0.62, 0.10 + 0.22 * frac), 1.2)
                # двойная стрелка «быстрая перемотка» — два сдержанных треугольника
                var tri_col := Color(0.86, 0.90, 0.85, 0.40 + 0.5 * frac) if hot else Color(0.66, 0.70, 0.66, 0.38)
                var s := 7.0
                for k in range(2):
                        var o := c + Vector2(-s * 0.55 + k * (s * 1.1), 0.0)
                        draw_colored_polygon(PackedVector2Array([
                                        o + Vector2(-s * 0.5, -s * 0.62), o + Vector2(-s * 0.5, s * 0.62), o + Vector2(s * 0.6, 0.0)
                        ]), tri_col)
                # мягкая заливка при полном кольце (мгновение перед скипом)
                if frac >= 0.999:
                        draw_circle(c, RING_R - 2.0, Color(0.55, 0.90, 0.62, 0.20))

# ---------- МОДАЛЬНОЕ ОКНО (зомби-стиль) ----------
# Затемнение + графитовая плита по центру, «выпрыгивание», скролл внутри.
# Возвращает {overlay, panel, vb}.
static func open_window(parent: Node, title: String, min_size := Vector2(640, 0), closable := true, title_col := NEON_BRIGHT) -> Dictionary:
        var overlay := Control.new()
        overlay.set_script(preload("res://scripts/ui/viewport_control.gd"))
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.mouse_filter = Control.MOUSE_FILTER_STOP
        var dim := ColorRect.new()
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.color = Color(0, 0, 0, 0.0)
        dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(dim)
        var panel := PanelContainer.new()
        panel.mouse_filter = Control.MOUSE_FILTER_STOP
        panel.set_anchors_preset(Control.PRESET_CENTER)
        panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel.grow_vertical = Control.GROW_DIRECTION_BOTH
        panel.custom_minimum_size = Vector2(min_size.x, 0)
        var pst := panel_style(PANEL, BORDER, 22)
        pst.border_width_top = 2
        pst.border_color = Color(BORDER.r, BORDER.g, BORDER.b, 0.8)
        panel.add_theme_stylebox_override("panel", pst)
        panel.modulate.a = 0.0
        panel.scale = Vector2(0.92, 0.92)
        var scroll := ScrollContainer.new()
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        panel.add_child(scroll)
        var vb := VBoxContainer.new()
        vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vb.add_theme_constant_override("separation", 8)
        scroll.add_child(vb)
        # шапка: неоновый уголок + заголовок
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 12)
        vb.add_child(head)
        var corner := ColorRect.new()
        corner.color = title_col
        corner.custom_minimum_size = Vector2(6, 26)
        head.add_child(corner)
        var tl := label(title, 22, title_col)
        tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(tl)
        if closable:
                var xbtn := Button.new()
                xbtn.text = "✕"
                xbtn.focus_mode = Control.FOCUS_NONE
                xbtn.custom_minimum_size = Vector2(34, 30)
                xbtn.add_theme_font_size_override("font_size", 16)
                xbtn.add_theme_color_override("font_color", MUTED)
                xbtn.add_theme_color_override("font_hover_color", ALERT)
                var xsb := StyleBoxFlat.new()
                xsb.bg_color = Color(0, 0, 0, 0)
                xbtn.add_theme_stylebox_override("normal", xsb)
                xbtn.add_theme_stylebox_override("hover", xsb.duplicate())
                xbtn.add_theme_stylebox_override("pressed", xsb.duplicate())
                xbtn.pressed.connect(func():
                        G.play_sfx("ui_click", -12.0, 0.9)
                        close_window(overlay))
                head.add_child(xbtn)
        vb.add_child(hdivider(1, BORDER_SOFT))
        overlay.add_child(panel)
        parent.add_child(overlay)
        overlay.size=overlay.get_viewport_rect().size
        var tw := dim.create_tween()
        tw.tween_property(dim, "color", Color(0, 0, 0, 0.62), 0.18)
        var tw2 := panel.create_tween()
        tw2.set_parallel(true)
        tw2.tween_property(panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw2.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        overlay.set_meta("panel", panel)
        _fit_window.call_deferred(panel, overlay, vb, min_size)
        return {"overlay": overlay, "panel": panel, "vb": vb}

static func _fit_window(panel, overlay, vb, min_size: Vector2) -> void:
        if not is_instance_valid(panel) or not is_instance_valid(overlay) or not is_instance_valid(vb):
                return
        var tree: SceneTree = panel.get_tree()
        if tree == null:
                return
        await tree.process_frame
        await tree.process_frame
        if not is_instance_valid(panel) or not is_instance_valid(overlay) or not is_instance_valid(vb):
                return
        var avail: Vector2 = overlay.size
        if avail.x < 40.0 or avail.y < 40.0:
                return
        var want_w := maxf(min_size.x, vb.get_combined_minimum_size().x)
        panel.custom_minimum_size.x = minf(want_w, avail.x * 0.94)
        var max_h := avail.y * 0.95 - 34.0
        var want_h: float = vb.get_combined_minimum_size().y
        var scroll: ScrollContainer = vb.get_parent()
        scroll.custom_minimum_size = Vector2(0, maxf(0.0, minf(want_h, max_h)))

static func close_window(overlay: Control) -> void:
        if overlay == null or not is_instance_valid(overlay):
                return
        var panel: Control = overlay.get_meta("panel", null)
        if panel != null and is_instance_valid(panel):
                var tw := panel.create_tween()
                tw.set_parallel(true)
                tw.tween_property(panel, "modulate:a", 0.0, 0.14)
                tw.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.14)
                tw.chain().tween_callback(overlay.queue_free)
        else:
                overlay.queue_free()

# ---------- АНИМАЦИЯ ПОЯВЛЕНИЯ ----------
static func entrance(node: CanvasItem, delay := 0.0, slide := 16.0) -> void:
        node.modulate.a = 0.0
        var tw: Tween = node.create_tween()
        tw.tween_interval(maxf(0.01, delay))
        var parent_ctrl := node.get_parent() as Control
        if parent_ctrl is Container:
                tw.set_parallel(true)
                tw.tween_property(node, "modulate:a", 1.0, 0.30)
                return
        var target: Vector2 = node.position
        node.position = target + Vector2(0, slide)
        tw.set_parallel(true)
        tw.tween_property(node, "modulate:a", 1.0, 0.30)
        tw.tween_property(node, "position", target, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ---------- ЭФФЕКТЫ ЭКРАНА ----------
static func vignette(strength := 0.5) -> ColorRect:
        return UiKit.make_vignette(strength)

static func grain(strength := 0.055) -> ColorRect:
        return UiKit.make_grain(strength)

# ржавая рамка-сканлайн поверх экрана (для КПК/пролога)
static func scanlines() -> ColorRect:
        var rect := ColorRect.new()
        rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
void fragment() {
        float line = smoothstep(0.5, 0.48, abs(fract(UV.y * 220.0 + TIME * 0.6) - 0.5));
        COLOR = vec4(0.05, 0.09, 0.06, line * 0.06);
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        rect.material = mat
        return rect
