# ============================================================
# ЕДИНЫЙ ВОЕННЫЙ ИНТЕРФЕЙС-НАБОР «ШТАБ»
# Палитра тёмного командного пункта: асфальт + хаки + янтарь.
# Кнопки с анимациями, модальные окна по центру с затемнением,
# эмблемы фракций, топографический фон, кнопка с удержанием.
# Используется: главное меню, контракт, настройки, карта кампании, HUD.
# ============================================================
class_name UiKit

# ---------- палитра ----------
const BG := Color(0.055, 0.062, 0.05)
const PANEL := Color(0.10, 0.11, 0.088, 0.98)
const PANEL_DIM := Color(0.075, 0.085, 0.07, 0.96)
const BORDER := Color(0.33, 0.35, 0.26)
const BORDER_SOFT := Color(0.24, 0.26, 0.20)
const AMBER := Color(0.85, 0.65, 0.28)
const AMBER_BRIGHT := Color(1.0, 0.80, 0.40)
const TEXT := Color(0.90, 0.89, 0.82)
const MUTED := Color(0.62, 0.64, 0.54)
const FAINT := Color(0.44, 0.46, 0.39)
const OK := Color(0.55, 0.75, 0.45)
const RED := Color(0.82, 0.42, 0.34)

# ================= БАЗОВЫЕ ЭЛЕМЕНТЫ =================
static func label(text: String, size: int, col := TEXT) -> Label:
        var l := Label.new()
        l.text = text
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
        l.add_theme_constant_override("shadow_offset_x", 1)
        l.add_theme_constant_override("shadow_offset_y", 1)
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return l

static func wrap_label(text: String, size: int, col := TEXT, width := 460.0) -> Label:
        var l := label(text, size, col)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(width, 0)
        return l

static func hdivider(width := 2.0, col := AMBER) -> ColorRect:
        var r := ColorRect.new()
        r.color = col
        r.custom_minimum_size = Vector2(width, 2)
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return r

static func panel_style(bg := PANEL, border := BORDER, margin := 18.0) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.border_color = border
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(4)
        sb.content_margin_left = margin
        sb.content_margin_right = margin
        sb.content_margin_top = margin * 0.7
        sb.content_margin_bottom = margin * 0.8
        return sb

# ================= ВОЕННАЯ КНОПКА =================
# Тёмная плита с янтарной планкой слева; при наведении планка растёт,
# плита чуть увеличивается, текст светлеет. Звук наведения/нажатия.
class MilButton extends Button:
        var bar: ColorRect
        var accent := false

        func _init(txt: String, msize := Vector2(320, 52), is_accent := false, fsize := 17) -> void:
                accent = is_accent
                text = txt
                custom_minimum_size = msize
                add_theme_font_size_override("font_size", fsize)
                focus_mode = Control.FOCUS_NONE
                _restyle()
                bar = ColorRect.new()
                bar.color = AMBER if accent else Color(0.5, 0.55, 0.4)
                bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
                bar.offset_left = 0
                bar.offset_right = 3
                bar.offset_top = 6
                bar.offset_bottom = -6
                bar.modulate.a = 0.35
                add_child(bar)

        func _restyle() -> void:
                var sb := StyleBoxFlat.new()
                var sbh: StyleBoxFlat
                var sbp: StyleBoxFlat
                if accent:
                        sb.bg_color = Color(0.26, 0.205, 0.10)
                        sb.border_color = Color(0.62, 0.48, 0.22)
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.36, 0.28, 0.13)
                        sbh.border_color = AMBER_BRIGHT
                        sbp = sbh.duplicate()
                        sbp.bg_color = Color(0.20, 0.16, 0.08)
                else:
                        sb.bg_color = Color(0.115, 0.125, 0.10)
                        sb.border_color = BORDER_SOFT
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.17, 0.185, 0.145)
                        sbh.border_color = Color(0.52, 0.54, 0.40)
                        sbp = sbh.duplicate()
                        sbp.bg_color = Color(0.08, 0.09, 0.07)
                sb.set_corner_radius_all(3)
                sbh.set_corner_radius_all(3)
                sbp.set_corner_radius_all(3)
                add_theme_stylebox_override("normal", sb)
                add_theme_stylebox_override("hover", sbh)
                add_theme_stylebox_override("pressed", sbp)
                add_theme_stylebox_override("disabled", sb.duplicate())
                var tc := AMBER_BRIGHT if accent else TEXT
                add_theme_color_override("font_color", tc)
                add_theme_color_override("font_hover_color", AMBER_BRIGHT if accent else Color(1, 0.98, 0.9))
                add_theme_color_override("font_pressed_color", tc)
                add_theme_color_override("font_disabled_color", FAINT)

        func _ready() -> void:
                mouse_entered.connect(_on_enter)
                mouse_exited.connect(_on_exit)
                button_down.connect(_on_down)
                button_up.connect(_on_up)
                pivot_offset = size / 2.0

        func _notification(what: int) -> void:
                if what == Control.NOTIFICATION_RESIZED:
                        pivot_offset = size / 2.0

        func _on_enter() -> void:
                G.play_sfx("ui_click", -20.0, 1.7)
                bar.modulate.a = 1.0
                bar.offset_right = 5
                var tw := create_tween()
                tw.tween_property(self, "scale", Vector2(1.025, 1.025), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

        func _on_exit() -> void:
                bar.modulate.a = 0.35
                bar.offset_right = 3
                var tw := create_tween()
                tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

        func _on_down() -> void:
                var tw := create_tween()
                tw.tween_property(self, "scale", Vector2(0.975, 0.975), 0.05)

        func _on_up() -> void:
                var tw := create_tween()
                tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

# ================= КНОПКА ГЛАВНОГО МЕНЮ (FIX7: стильная, с SVG-иконкой) =================
# Тёмная стальная плита со скошенным янтарным краем, слева иконка,
# справа «шеврон-указатель», выезжающий при наведении. Акцентная
# кнопка (основное действие) — тёплая янтарная подсветка.
class MenuBtn extends Button:
        var icon_name := ""
        var accent := false
        var _ic: TextureRect = null
        var _chev: Label = null

        func _init(txt: String, msize := Vector2(620, 62), is_accent := false, fsize := 19, ic := "") -> void:
                accent = is_accent
                text = txt
                icon_name = ic
                custom_minimum_size = msize
                add_theme_font_size_override("font_size", fsize)
                focus_mode = Control.FOCUS_NONE
                _restyle()
                if icon_name != "":
                        # FIX7v2: гнездо-подложка под иконку (глубина)
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
                        _ic.texture = G.tex(icon_name) if G.tex(icon_name) != null else _svg_tex(icon_name)
                        _ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                        _ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                        _ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        _ic.custom_minimum_size = Vector2(28, 28)
                        _ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
                        _ic.offset_left = 20
                        _ic.offset_right = 48
                        _ic.offset_top = -14
                        _ic.offset_bottom = 14
                        _ic.modulate = AMBER_BRIGHT if accent else MUTED
                        add_child(_ic)
                _chev = Label.new()
                _chev.text = "›"
                _chev.add_theme_font_size_override("font_size", fsize + 8)
                _chev.add_theme_color_override("font_color", AMBER)
                _chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _chev.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
                _chev.offset_left = -40
                _chev.offset_right = -16
                _chev.offset_top = -20
                _chev.offset_bottom = 20
                _chev.modulate.a = 0.25
                add_child(_chev)
                # FIX7v2: глянец сверху и внутренняя тень снизу — «стальная плита»
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

        func _svg_tex(nm: String) -> Texture2D:
                var p := "res://assets/icons/%s.svg" % nm
                if ResourceLoader.exists(p):
                        return load(p)
                return null

        func _restyle() -> void:
                var sb := StyleBoxFlat.new()
                var sbh: StyleBoxFlat
                var sbp: StyleBoxFlat
                if accent:
                        sb.bg_color = Color(0.185, 0.14, 0.065, 0.94)
                        sb.border_color = Color(0.62, 0.48, 0.22)
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.27, 0.205, 0.09, 0.97)
                        sbh.border_color = AMBER_BRIGHT
                        sbp = sbh.duplicate()
                        sbp.bg_color = Color(0.13, 0.10, 0.05)
                else:
                        sb.bg_color = Color(0.078, 0.088, 0.074, 0.92)
                        sb.border_color = Color(0.30, 0.325, 0.255, 0.95)
                        sbh = sb.duplicate()
                        sbh.bg_color = Color(0.115, 0.128, 0.105, 0.94)
                        sbh.border_color = AMBER
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
                add_theme_color_override("font_color", AMBER_BRIGHT if accent else TEXT)
                add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.78) if not accent else Color(1.0, 0.95, 0.85))
                add_theme_color_override("font_pressed_color", TEXT)
                add_theme_color_override("font_disabled_color", FAINT)

        func _ready() -> void:
                mouse_entered.connect(_on_enter)
                mouse_exited.connect(_on_exit)
                button_down.connect(func(): scale = Vector2(0.985, 0.985))
                button_up.connect(func(): scale = Vector2.ONE)
                pivot_offset = size / 2.0

        func _notification(what: int) -> void:
                if what == Control.NOTIFICATION_RESIZED:
                        pivot_offset = size / 2.0

        func _on_enter() -> void:
                G.play_sfx("ui_click", -20.0, 1.7)
                if _ic != null:
                        _ic.modulate = AMBER_BRIGHT
                var tw := create_tween()
                tw.set_parallel(true)
                tw.tween_property(_chev, "modulate:a", 1.0, 0.12)
                tw.tween_property(_chev, "offset_left", -34.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                tw.tween_property(self, "scale", Vector2(1.015, 1.015), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

        func _on_exit() -> void:
                if _ic != null:
                        _ic.modulate = AMBER_BRIGHT if accent else MUTED
                var tw := create_tween()
                tw.set_parallel(true)
                tw.tween_property(_chev, "modulate:a", 0.25, 0.16)
                tw.tween_property(_chev, "offset_left", -40.0, 0.16)
                tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ================= ФОН ГЛАВНОГО МЕНЮ: СЕВЕРНАЯ ПУСТОШЬ (шейдер) =================
# Ночное небо с северным сиянием, силуэты мёртвого города с редкими
# горящими окнами, радиовышка с мигающим огнём, зарево пожара, снег.
# Всё в одном шейдере — один draw call, дёшево даже на телефоне.
static func make_menu_scene() -> ColorRect:
        var rect := ColorRect.new()
        rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
        vec2 i = floor(p); vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
        float v = 0.0; float a = 0.5;
        for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + vec2(17.3, 9.1); a *= 0.5; }
        return v;
}
void fragment() {
        vec2 uv = UV;
        vec3 col = vec3(0.020, 0.028, 0.033);
        // холодный градиент к горизонту
        col += vec3(0.014, 0.022, 0.020) * smoothstep(0.1, 0.9, uv.y);
        // северное сияние — ленты
        float band = fbm(vec2(uv.x * 2.6 + TIME * 0.045, uv.y * 1.2 - TIME * 0.018));
        float aur = smoothstep(0.40, 0.0, abs(uv.y - 0.22 - band * 0.20));
        aur *= 0.55 + 0.45 * sin(uv.x * 7.0 + TIME * 0.3);
        col += vec3(0.05, 0.26, 0.14) * aur * 0.6;
        // звёзды
        float st = step(0.9925, hash(floor(uv * vec2(140.0, 80.0))));
        st *= 0.45 + 0.55 * sin(TIME * 1.6 + hash(floor(uv * vec2(140.0, 80.0)) + 7.1) * 6.28);
        col += vec3(0.75, 0.82, 0.9) * st * 0.6 * smoothstep(0.6, 0.05, uv.y);
        // тусклая луна с ореолом
        float md = length((uv - vec2(0.80, 0.14)) * vec2(1.75, 1.0));
        col += vec3(0.62, 0.70, 0.80) * (smoothstep(0.052, 0.044, md) * 0.5 + smoothstep(0.16, 0.05, md) * 0.10);
        // зарево пожара на горизонте
        float fire = smoothstep(0.68, 1.0, uv.y) * smoothstep(0.42, 0.0, abs(uv.x - 0.22 + 0.03 * sin(TIME * 0.6)));
        col += vec3(0.28, 0.11, 0.03) * fire * (0.7 + 0.3 * sin(TIME * 2.1));
        // два слоя силуэтов мёртвого города
        for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float y0 = 0.78 - fl * 0.03;
                float sx = uv.x * (9.0 + fl * 7.0) + fl * 13.7;
                float id = floor(sx);
                float h = 0.05 + hash(vec2(id, fl + 4.2)) * (0.16 - fl * 0.05);
                float bx = fract(sx);
                float btop = y0 - h;
                if (uv.y > btop) {
                        float shade = 0.55 + fl * 0.45;
                        col = mix(col, vec3(0.012, 0.016, 0.019) * shade, 0.96);
                        // редкие горящие окна
                        float wx = step(0.18, fract(bx * 4.0)) * step(fract(bx * 4.0), 0.82);
                        float wy = step(0.25, fract((btop - uv.y) * 16.0)) * step(fract((btop - uv.y) * 16.0), 0.75);
                        float lit = step(0.90, hash(vec2(id * 4.0 + floor(bx * 4.0), floor((btop - uv.y) * 16.0))));
                        float flick = 0.55 + 0.45 * sin(TIME * (1.0 + hash(vec2(id, fl)) * 2.2) + id);
                        col += vec3(0.50, 0.28, 0.09) * wx * wy * lit * flick * (0.5 - fl * 0.15);
                }
        }
        // радиовышка с мигающим красным огнём
        float th = 0.34;
        float tw_top = 0.80 - th;
        if (uv.y > tw_top && uv.y < 0.80) {
                float twid = 0.0035 + (uv.y - tw_top) * 0.012;
                if (abs(uv.x - 0.115) < twid) { col = mix(col, vec3(0.010, 0.013, 0.015), 0.95); }
        }
        float blink = step(0.55, fract(TIME * 0.7));
        col += vec3(0.85, 0.12, 0.08) * smoothstep(0.010, 0.0, length((uv - vec2(0.115, tw_top)) * vec2(1.8, 1.0))) * blink * 0.9;
        // снег: два слоя
        for (int S = 0; S < 2; S++) {
                float fs = float(S);
                vec2 sp = vec2(uv.x * (5.0 + fs * 4.0) + TIME * (0.20 + fs * 0.30), uv.y * (3.5 + fs * 2.5) - TIME * (0.45 + fs * 0.45));
                vec2 f2 = fract(sp) - 0.5;
                float sn = step(0.975 - fs * 0.01, hash(floor(sp))) * smoothstep(0.18, 0.02, length(f2));
                col += vec3(0.82, 0.88, 0.94) * sn * (0.34 - fs * 0.14);
        }
        // виньетка
        float d = length(uv - vec2(0.5)) * 1.32;
        col *= 1.0 - smoothstep(0.42, 0.98, d) * 0.5;
        COLOR = vec4(col * strength, 1.0);
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        rect.material = mat
        return rect

# ================= КНОПКА С УДЕРЖАНИЕМ =================
# «Зажмите, чтобы пропустить»: заполняющаяся полоса снизу,
# по завершении удержания — сигнал hold_done.
class HoldButton extends Button:
        var hold_time := 0.9
        var filling := false
        var fill_t := 0.0
        var hold_done := false
        var bar: ColorRect
        var cap: ColorRect

        func _init(txt: String, dur := 0.9) -> void:
                text = txt
                hold_time = dur
                custom_minimum_size = Vector2(360, 44)
                add_theme_font_size_override("font_size", 14)
                focus_mode = Control.FOCUS_NONE
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.09, 0.10, 0.08, 0.9)
                sb.border_color = BORDER
                sb.set_corner_radius_all(3)
                add_theme_stylebox_override("normal", sb)
                add_theme_stylebox_override("hover", sb.duplicate())
                add_theme_stylebox_override("pressed", sb.duplicate())
                add_theme_color_override("font_color", MUTED)
                add_theme_color_override("font_hover_color", TEXT)
                add_theme_color_override("font_pressed_color", TEXT)
                bar = ColorRect.new()
                bar.color = Color(AMBER.r, AMBER.g, AMBER.b, 0.45)
                bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
                bar.offset_left = 0
                bar.offset_right = 0
                bar.offset_bottom = 0
                bar.offset_top = 0
                add_child(bar)
                cap = ColorRect.new()
                cap.color = Color(0, 0, 0, 0)
                cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
                add_child(cap)

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

# ================= ЭМБЛЕМА ФРАКЦИИ =================
# Круг-эмблема: кольцо + звезда в цвете фракции.
class FactionEmblem extends Control:
        var fac := "sak"

        func _init(faction: String, d := 44.0) -> void:
                fac = faction
                custom_minimum_size = Vector2(d, d)
                mouse_filter = Control.MOUSE_FILTER_IGNORE

        func _draw() -> void:
                var c := size / 2.0
                var rad: float = minf(size.x, size.y) / 2.0 - 2.0
                var col: Color = G.FACTION_COLOR.get(fac, AMBER)
                draw_circle(c, rad, Color(col.r, col.g, col.b, 0.20))
                draw_arc(c, rad, 0, TAU, 40, col, 2.0)
                draw_arc(c, rad * 0.72, 0, TAU, 32, Color(col.r, col.g, col.b, 0.55), 1.0)
                # звезда (5 лучей)
                var pts := PackedVector2Array()
                for i in range(10):
                        var ang: float = -PI / 2.0 + i * PI / 5.0
                        var rr: float = rad * 0.62 if i % 2 == 0 else rad * 0.26
                        pts.append(c + Vector2.from_angle(ang) * rr)
                draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.9))

# ================= МОДАЛЬНОЕ ОКНО ПО ЦЕНТРУ =================
# Затемнение фона + плита по центру с «выпрыгивающей» анимацией.
# Содержимое обёрнуто в прокрутку: на низких/узких экранах окно
# ужимается под видимую область и скроллится, но НЕ вылезает за края.
# Возвращает словарь: overlay, panel, vb (контейнер содержимого).
static func open_window(parent: Node, title: String, min_size := Vector2(640, 0), closable := true) -> Dictionary:
        var overlay := Control.new()
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.mouse_filter = Control.MOUSE_FILTER_STOP
        var dim := ColorRect.new()
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.color = Color(0, 0, 0, 0.0)
        dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(dim)
        var panel := PanelContainer.new()
        panel.set_anchors_preset(Control.PRESET_CENTER)
        panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel.grow_vertical = Control.GROW_DIRECTION_BOTH
        panel.custom_minimum_size = Vector2(min_size.x, 0)
        panel.add_theme_stylebox_override("panel", panel_style(PANEL, BORDER, 24))
        panel.modulate.a = 0.0
        panel.scale = Vector2(0.92, 0.92)
        # прокрутка содержимого (адаптация высоты — в _fit_window)
        var scroll := ScrollContainer.new()
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        panel.add_child(scroll)
        var vb := VBoxContainer.new()
        vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vb.add_theme_constant_override("separation", 8)
        scroll.add_child(vb)
        # шапка окна
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 12)
        vb.add_child(head)
        var corner := ColorRect.new()
        corner.color = AMBER
        corner.custom_minimum_size = Vector2(6, 26)
        head.add_child(corner)
        var tl := label(title, 24, AMBER_BRIGHT)
        tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(tl)
        if closable:
                var xbtn := Button.new()
                xbtn.text = "✕"
                xbtn.focus_mode = Control.FOCUS_NONE
                xbtn.custom_minimum_size = Vector2(34, 30)
                xbtn.add_theme_font_size_override("font_size", 16)
                xbtn.add_theme_color_override("font_color", MUTED)
                xbtn.add_theme_color_override("font_hover_color", RED)
                var xsb := StyleBoxFlat.new()
                xsb.bg_color = Color(0, 0, 0, 0)
                xbtn.add_theme_stylebox_override("normal", xsb)
                xbtn.add_theme_stylebox_override("hover", xsb.duplicate())
                xbtn.add_theme_stylebox_override("pressed", xsb.duplicate())
                xbtn.pressed.connect(func():
                        G.play_sfx("ui_click", -12.0, 0.9)
                        close_window(overlay))
                head.add_child(xbtn)
        vb.add_child(hdivider())
        overlay.add_child(panel)
        parent.add_child(overlay)
        # тап/клик мимо плиты закрывает окно (удобно на телефоне)
        if closable:
                overlay.gui_input.connect(func(ev: InputEvent):
                        if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
                                G.play_sfx("ui_click", -14.0, 0.9)
                                close_window(overlay))
        # затемнение + выпрыгивание
        var tw := dim.create_tween()
        tw.tween_property(dim, "color", Color(0, 0, 0, 0.58), 0.18)
        var tw2 := panel.create_tween()
        tw2.set_parallel(true)
        tw2.tween_property(panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw2.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        overlay.set_meta("panel", panel)
        # подгон окна под фактический экран (после того как контент уже добавлен)
        _fit_window.call_deferred(panel, overlay, vb, min_size)
        return {"overlay": overlay, "panel": panel, "vb": vb}

static func _fit_window(panel: PanelContainer, overlay: Control, vb: VBoxContainer, min_size: Vector2) -> void:
        var tree := panel.get_tree()
        if tree == null:
                return
        await tree.process_frame
        await tree.process_frame
        if not is_instance_valid(panel) or not is_instance_valid(overlay) or not is_instance_valid(vb):
                return
        var avail := overlay.size
        if avail.x < 40.0 or avail.y < 40.0:
                return
        # ширина: не шире 94% экрана
        var want_w := maxf(min_size.x, vb.get_combined_minimum_size().x)
        panel.custom_minimum_size.x = minf(want_w, avail.x * 0.94)
        # высота: по содержимому, но не выше 95% экрана — дальше прокрутка
        var max_h := avail.y * 0.95 - 34.0   # минус панельные отступы
        var want_h := vb.get_combined_minimum_size().y
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

# ================= АНИМАЦИЯ ПОЯВЛЕНИЯ =================
# Последовательное «выплывание» элементов меню. Внутри контейнеров
# (VBox/HBox) двигать position нельзя — контейнер управляет раскладкой,
# поэтому там анимируем только прозрачность.
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

# ================= ФОНОВЫЕ ШЕЙДЕРЫ =================
static func make_topo_material() -> ShaderMaterial:
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
                v += a * noise(p);
                p = p * 2.03 + vec2(17.3, 9.1);
                a *= 0.5;
        }
        return v;
}
void fragment() {
        vec2 p = UV * vec2(6.0, 3.4) + vec2(TIME * 0.010, -TIME * 0.016);
        float h = fbm(p);
        float c1 = abs(fract(h * 14.0) - 0.5);
        float line1 = smoothstep(0.055, 0.0, c1) * 0.16;
        float c2 = abs(fract(h * 6.0 + 0.25) - 0.5);
        float line2 = smoothstep(0.045, 0.0, c2) * 0.10;
        COLOR = vec4(0.34, 0.38, 0.27, (line1 + line2) * strength);
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        return mat

static func make_vignette(strength := 0.42) -> ColorRect:
        var vg := ColorRect.new()
        vg.set_anchors_preset(Control.PRESET_FULL_RECT)
        vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
uniform float amount = 0.42;
void fragment() {
        vec2 c = UV - vec2(0.5);
        float d = length(c) * 1.35;
        float a = smoothstep(0.5, 1.2, d) * amount;
        COLOR = vec4(0.01, 0.01, 0.005, a);
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        mat.set_shader_parameter("amount", strength)
        vg.material = mat
        return vg

static func make_grain(strength := 0.05) -> ColorRect:
        var rect := ColorRect.new()
        rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 0.3) = 0.05;
float rnd(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
        float g = rnd(UV * vec2(1345.0, 923.0) + vec2(TIME * 11.3, TIME * 7.7));
        COLOR = vec4(0.5, 0.5, 0.5, (g - 0.5) * strength * 2.0);
}
"""
        var mat := ShaderMaterial.new()
        mat.shader = sh
        mat.set_shader_parameter("strength", strength)
        rect.material = mat
        return rect
