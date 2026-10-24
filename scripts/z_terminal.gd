# ============================================================
# ZTERMINAL — ТЕРМИНАЛЫ ОБЪЕКТА «ЗАРЯ» (мрачный CRT-интерфейс)
# Зелёно-жёлтые панели, посимвольная печать строк, мигающий
# курсор, глитч-подёргивания, сканлайны, следы замерзающего
# стекла и царапины на экране.
#
# Используется: крио-терминал камеры пробуждения, медицинский
# терминал, распределительный шкаф генератора, панель изоляции
# карантина, архив Морозовой (АРХИВ ПОВРЕЖДЁН), протокол «Север».
#
# Строка вывода (Dictionary):
#   text  String — содержимое строки
#   col   Color  — цвет (по умолчанию зелёный CRT)
#   delay float  — пауза после строки
#   sfx   String — звук при выводе
#   glitch bool — одиночное подёргивание при выводе
#   blink bool  — строка мигает (статусы аварий)
# ============================================================
class_name ZTerminal
extends Control

signal done()

# CRT-палитра терминалов «Заря»
const CRT_GREEN := Color(0.36, 0.95, 0.50)
const CRT_GREEN_DIM := Color(0.22, 0.60, 0.32)
const CRT_AMBER := Color(0.98, 0.78, 0.30)
const CRT_RED := Color(1.0, 0.34, 0.28)
const CRT_WHITE := Color(0.86, 0.94, 0.86)

var title := "О. «ЗАРЯ» · ТЕРМИНАЛ"
var accent_col := CRT_GREEN

var _bg: ColorRect = null
var _glow: ColorRect = null
var _title_lbl: Label = null
var _status_lbl: Label = null
var _lines: VBoxContainer = null
var _cursor_lbl: Label = null
var _glitch_rect: ColorRect = null
var _frost_rect: ColorRect = null
var _scr_rect: ColorRect = null
var _closed := false
var _blink_t := 0.0

func _init(term_title := "О. «ЗАРЯ» · ТЕРМИНАЛ", accent := CRT_GREEN) -> void:
        title = term_title
        accent_col = accent

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_STOP
        _build()

func _build() -> void:
        # фон экрана
        _bg = ColorRect.new()
        _bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        _bg.color = Color(0.012, 0.028, 0.016, 0.985)
        add_child(_bg)
        # мягкое свечение центра
        _glow = ColorRect.new()
        _glow.set_anchors_preset(Control.PRESET_FULL_RECT)
        _glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var gsh := Shader.new()
        gsh.code = """
shader_type canvas_item;
void fragment() {
        vec2 c = UV - vec2(0.5);
        float d = length(c) * 1.35;
        float a = smoothstep(0.85, 0.15, d) * 0.10;
        COLOR = vec4(0.30, 0.9, 0.45, a);
}
"""
        var gm := ShaderMaterial.new()
        gm.shader = gsh
        _glow.material = gm
        add_child(_glow)
        add_child(ZUI.scanlines())
        # глитч-подёргивания: горизонтальный сдвиг всего экрана
        _glitch_rect = ColorRect.new()
        _glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        _glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var lsh := Shader.new()
        lsh.code = """
shader_type canvas_item;
uniform float amp = 0.0;
void fragment() {
        vec2 uv = UV;
        float band = step(0.985 - amp * 0.06, fract(sin(floor(uv.y * 90.0) * 12.9898 + TIME * 21.0) * 43758.5453));
        uv.x += band * amp * (fract(sin(floor(uv.y * 40.0) * 7.9898 + TIME * 31.0) * 27158.5453) - 0.5) * 0.06;
        COLOR = vec4(0.36, 0.95, 0.50, band * amp * 0.05);
}
"""
        var lm := ShaderMaterial.new()
        lm.shader = lsh
        _glitch_rect.material = lm
        add_child(_glitch_rect)
        # контент
        var root := VBoxContainer.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.offset_left = 72
        root.offset_right = -72
        root.offset_top = 40
        root.offset_bottom = -120
        root.add_theme_constant_override("separation", 6)
        add_child(root)
        _title_lbl = ZUI.label(title, 19, accent_col)
        root.add_child(_title_lbl)
        root.add_child(ZUI.hdivider(2, Color(accent_col.r, accent_col.g, accent_col.b, 0.5)))
        _lines = VBoxContainer.new()
        _lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _lines.add_theme_constant_override("separation", 7)
        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        _lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(_lines)
        root.add_child(scroll)
        _cursor_lbl = ZUI.label("█", 18, accent_col)
        root.add_child(_cursor_lbl)
        var spacer := Control.new()
        spacer.custom_minimum_size = Vector2(0, 10)
        root.add_child(spacer)
        _status_lbl = ZUI.label("СВЯЗЬ: ЛОКАЛЬНАЯ   ·   ПИТАНИЕ: РЕЗЕРВ   ·   СЕТЬ: РАЗОРВАНА", 12, CRT_GREEN_DIM)
        root.add_child(_status_lbl)
        # царапины на стекле
        _scr_rect = ColorRect.new()
        _scr_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        _scr_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _scr_rect.material = scratch_material()
        add_child(_scr_rect)
        # мороз (включается зонами холода)
        _frost_rect = ColorRect.new()
        _frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        _frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _frost_rect.material = frost_material(0.35)
        _frost_rect.visible = false
        add_child(_frost_rect)
        set_status("")

func _process(delta: float) -> void:
        _blink_t += delta
        if _cursor_lbl != null:
                _cursor_lbl.visible = fmod(_blink_t, 1.0) < 0.6
        # редкие глитчи
        if _glitch_rect != null and randf() < delta * 0.7:
                var mat: ShaderMaterial = _glitch_rect.material
                var tw := create_tween()
                mat.set_shader_parameter("amp", randf_range(0.4, 1.0))
                tw.tween_method(func(v: float): mat.set_shader_parameter("amp", v), mat.get_shader_parameter("amp"), 0.0, 0.22)

func set_status(txt: String, col := CRT_GREEN_DIM) -> void:
        if _status_lbl != null:
                _status_lbl.text = txt
                _status_lbl.add_theme_color_override("font_color", col)

func set_frost(a: float) -> void:
        if _frost_rect == null:
                return
        _frost_rect.visible = a > 0.01
        if _frost_rect.material != null:
                _frost_rect.material.set_shader_parameter("strength", clampf(a, 0.0, 1.0))

# ---------- печать строк ----------
func print_lines(lines: Array, on_done: Callable = Callable()) -> void:
        _print_seq(lines, 0, on_done)

func _print_seq(lines: Array, i: int, on_done: Callable) -> void:
        if _closed:
                return
        if i >= lines.size():
                done.emit()
                if on_done.is_valid():
                        on_done.call()
                return
        var L: Dictionary = lines[i]
        _print_one(L)
        var nxt := func(): _print_seq(lines, i + 1, on_done)
        var dl := maxf(float(L.get("delay", 0.35)),clampf(str(L.get("text","")).length()*0.014,0.12,3.0))
        if dl <= 0.0:
                nxt.call()
        else:
                get_tree().create_timer(dl).timeout.connect(nxt)

func _print_one(L: Dictionary) -> void:
        if _closed:
                return
        var txt: String = str(L.get("text", ""))
        var col: Color = L.get("col", accent_col)
        var gl := bool(L.get("glitch", false))
        if str(L.get("sfx", "")) != "":
                G.play_sfx(str(L["sfx"]), float(L.get("sfx_db", -18.0)), float(L.get("sfx_pitch", 1.0)))
        if gl:
                var mat: ShaderMaterial = _glitch_rect.material
                mat.set_shader_parameter("amp", 1.0)
                var tw := create_tween()
                tw.tween_method(func(v: float): mat.set_shader_parameter("amp", v), 1.0, 0.0, 0.3)
                G.play_sfx("z_spark", -20.0)
        var row: Control
        if bool(L.get("blink", false)):
                row = _make_blink_label(txt, col)
        else:
                row = ZUI.wrap_label(txt, int(L.get("size", 17)), col, 1080.0)
        _lines.add_child(row)
        if row is Label:
                # печать посимвольно (быстро — 0.008/символ), тап не нужен
                _type_row(row as Label, txt, col)

func _type_row(lbl: Label, txt: String, _col: Color) -> void:
        lbl.visible_characters = 0
        var tw := lbl.create_tween()
        tw.tween_property(lbl,"visible_characters",txt.length(),clampf(txt.length()*0.014,0.12,3.0))

func _make_blink_label(txt: String, col: Color) -> Label:
        var l := ZUI.wrap_label(txt, 17, col, 1080.0)
        var tw := l.create_tween()
        tw.set_loops()
        tw.tween_property(l, "modulate:a", 0.25, 0.55)
        tw.tween_property(l, "modulate:a", 1.0, 0.55)
        return l

func close_terminal() -> void:
        if _closed:
                return
        _closed = true
        # экран гаснет сверху вниз
        var tw := _bg.create_tween()
        tw.tween_property(_bg, "color:a", 0.0, 0.28)
        for c in _lines.get_children():
                var t2 := (c as Control).create_tween()
                t2.tween_property(c, "modulate:a", 0.0, 0.22)
        var t3 := create_tween()
        t3.tween_interval(0.32)
        t3.tween_callback(queue_free)

# ================= ШЕЙДЕРЫ: МОРОЗ И ЦАРАПИНЫ (статические) =================
# Полупрозрачный слой «замёрзшего стекла» — используется и на
# терминалах, и поверх боя в холодных зонах (утечка газа, тоннель).
static func frost_material(strength := 0.5) -> ShaderMaterial:
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
uniform float strength = 0.5;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
        vec2 i = floor(p); vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash(i), b = hash(i + vec2(1,0)), c = hash(i + vec2(0,1)), d = hash(i + vec2(1,1));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
        vec2 uv = UV;
        // кристаллы инея по краям, гуще к углам
        float edge = smoothstep(0.22, 0.75, length(uv - vec2(0.5)) * 1.35);
        float crystals = 0.0;
        for (int k = 1; k <= 3; k++) {
                float sc = float(k) * 5.5;
                crystals += noise(uv * sc + vec2(float(k) * 13.7, float(k) * 7.1)) / float(k);
        }
        crystals = pow(clamp(crystals - 0.35, 0.0, 1.0), 1.6);
        float frost = clamp(edge * crystals * 2.2, 0.0, 1.0) * strength;
        // лёгкое белое свечение инея
        vec3 ice = vec3(0.72, 0.82, 0.92);
        COLOR = vec4(ice, frost * 0.85);
}
"""
        var m := ShaderMaterial.new()
        m.shader = sh
        m.set_shader_parameter("strength", strength)
        return m

# Полноэкранный оверлей мороза (бой: холодные зоны)
static func frost_overlay(strength := 0.5) -> ColorRect:
        var r := ColorRect.new()
        r.set_anchors_preset(Control.PRESET_FULL_RECT)
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        r.material = frost_material(strength)
        return r

# Царапины на экране КПК/терминала (лёгкие белёсые линии)
static func scratch_material() -> ShaderMaterial:
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
        float s = 0.0;
        // три «царапины»: полосы с шумом по кромке
        for (int i = 0; i < 3; i++) {
                float fi = float(i);
                float y = 0.22 + fi * 0.27 + sin(UV.x * (3.0 + fi) + fi * 2.1) * 0.03;
                float d = abs(UV.y - y);
                float line = smoothstep(0.0035, 0.0008, d);
                float seg = smoothstep(0.1, 0.25, UV.x + hash(vec2(fi, 3.0)) * 0.4) * step(UV.x, 0.62 + hash(vec2(fi, 7.0)) * 0.3);
                s += line * seg * (0.10 + 0.05 * hash(UV * 90.0));
        }
        COLOR = vec4(0.9, 0.94, 0.9, s);
}
"""
        var m := ShaderMaterial.new()
        m.shader = sh
        return m
