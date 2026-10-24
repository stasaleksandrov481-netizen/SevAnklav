# ============================================================
# ZCUTSCENE — КИНЕМАТОГРАФИЧЕСКИЙ РЕЖИССЁР КАМПАНИИ «ЗЕМЛЯ МЕРТВЫХ»
# Движок кат-сцен пролога «ЗАРЯ»: letterbox-полосы, субтитры с
# посимвольной печатью, тряска экрана, вспышки, вуаль затемнения,
# аварийный красный пульс, синхронные аудио/озвучка-очереди.
#
# Используется:
#   • прологом (zprologue_zarya.gd) как полноэкранный режиссёр;
#   • боем (battle_z.gd) как оверлей поверх геймплея (CanvasLayer):
#     кат-сцены лифта, блокировки карантина, записи Морозовой,
#     V-18 у грузового шлюза, перехода «Снежная линия».
#
# Таймлайн — массив Cue (Dictionary). Поля (все опциональны):
#   wait      float  пауза перед cue (сек)
#   sfx       String имя SFX из G.play_sfx
#   sfx_db / sfx_pitch
#   voice     Array  пути WAV (ZVoice, играются последовательно)
#   voice_db  float  громкость озвучки
#   voice_wait bool  ждать окончания озвучки
#   speaker   String плашка говорящего над субтитрами
#   col       Color  цвет плашки/субтитров
#   text      String реплика (печатается посимвольно)
#   speed     float  сек на символ (0.03 по умолчанию)
#   hold      float  сколько секунд реплика висит после печати
#   shake     float  длительность тряски; shake_k — амплитуда (px)
#   flash     float  вспышка: время разгона до полного; flash_col
#   flash_hold float сколько держать полную вспышку; flash_fade — время спада
#   veil      float  затемнение: время разгона; veil_to — целевая альфа; veil_col
#   red       bool   включить аварийный красный пульс; red_off — выключить
#   call      Callable вызвать в момент cue; call_wait — ждать возврата корутины
#   advance   String ждать внешнего advance(tag) с этим тегом
#   hold_all  bool   после cue не двигаться дальше до advance()/skip()
#
# Пропуск: УДЕРЖАНИЕ в любой точке экрана — в правом нижнем углу
# заполняется кольцо (ZUI.ZSkipHold, skippable=true). Геймпад: START.
# Сигнал finished(is_skipped) после последнего cue.
# ============================================================
class_name ZCutscene
extends Control

signal finished(is_skipped: bool)
signal completed(is_skipped: bool)   # для await cs.play(...)

const TYPE_SPEED := 0.030
# палитра субтитров (по ролям сценария)
const C_AI := Color(0.42, 0.95, 0.60)          # ИИ «Заря» — зелёный терминал
const C_AI_WARN := Color(0.95, 0.62, 0.30)     # ИИ — предупреждение
const C_VOICE := Color(0.72, 0.58, 0.92)       # неизвестный женский голос
const C_RADIO := Color(0.85, 0.72, 0.42)       # рация
const C_VOLKOV := Color(0.88, 0.90, 0.86)      # Волков
const C_SEROV := Color(0.55, 0.78, 0.88)       # Серов
const C_SYSTEM := Color(0.90, 0.36, 0.30)      # системные сообщения объекта
const C_ALERT := Color(0.98, 0.48, 0.40)       # тревожные реплики (крик, опасность)
const C_MEMORY := Color(0.80, 0.85, 0.98)      # воспоминания

var main_ref = null
var skippable := true
var fast := false                 # smoke-режим: все тайминги x0.02

# стили карточек (по ТЗ: различать повествование и сообщения системы)
#   "system" — тег-заголовок в приглушённом цвете роли, фраза светло-серая
#   "story"  — чистая литературная фраза без плашки, чуть крупнее
#   "voice"  — реплика голоса/персонажа: тихий тег цвета роли, фраза светло-серая
#   "auto"   — как "voice" (по умолчанию: тег цвета роли, светло-серый текст)

var cues: Array = []
var cue_idx := -1
var running := false
var finished_flag := false

# узлы
var content: Control = null       # трясётся
var letter_top: ColorRect = null
var letter_bot: ColorRect = null
var card_root: VBoxContainer = null   # цельный блок карточки: тег + фраза
var speaker_lbl: Label = null
var text_lbl: Label = null
var flash_rect: ColorRect = null
var veil_rect: ColorRect = null
var red_rect: ColorRect = null
var skip_hold: ZUI.ZSkipHold = null
var voice: ZVoice = null

# состояние
var shake_t := 0.0
var shake_dur := 0.0
var shake_k := 12.0
var red_on := false
var red_t := 0.0
var _advance_tag := ""
var _hold_all := false
var _skip_guard := false

func _init() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
        # FIX v2.9: размер ведут якоря FULL_RECT — прямая установка size давала
        # предупреждение движка «non-equal opposite anchors» при каждом запуске
        get_viewport().size_changed.connect(func():
                _update_card_layout())
        _update_card_layout()
        _build()

func _build() -> void:
        content = Control.new()
        content.set_anchors_preset(Control.PRESET_FULL_RECT)
        content.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(content)
        # letterbox (кино-полосы) — начинаются открытыми, раскрываются в 0.55
        letter_top = ColorRect.new()
        letter_top.color = Color(0, 0, 0)
        letter_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
        letter_top.offset_bottom = 0
        letter_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(letter_top)
        letter_bot = ColorRect.new()
        letter_bot.color = Color(0, 0, 0)
        letter_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        letter_bot.offset_top = 0
        letter_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(letter_bot)
        # вуаль/вспышки ПОД субтитрами
        veil_rect = ColorRect.new()
        veil_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        veil_rect.color = Color(0, 0, 0, 0)
        veil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(veil_rect)
        red_rect = ColorRect.new()
        red_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        red_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        red_rect.color = Color(0.75, 0.05, 0.04, 0.0)
        # краевое аварийное свечение (по ТЗ п.6): только края, мягко и неровно,
        # центр остаётся чёрным; живое «дыхание» через TIME + альфа в _process.
        # COLOR.a на входе — альфа самого ColorRect: она управляет видимостью
        # (без этого свечение горело бы постоянно, независимо от red_on)
        var rsh := Shader.new()
        rsh.code = """
shader_type canvas_item;
void fragment() {
        vec2 c = UV - vec2(0.5);
        float d = length(c) * 1.18;
        float a = smoothstep(0.52, 1.12, d);
        float w = sin(TIME * 0.32) * 0.5 + 0.5;
        a *= 0.86 + 0.14 * w;
        float ang = atan(c.y, c.x);
        a *= 0.92 + 0.08 * sin(ang * 2.0 + 1.7);
        COLOR = vec4(0.46, 0.035, 0.025, a) * vec4(1.0, 1.0, 1.0, COLOR.a);
}
"""
        var rm := ShaderMaterial.new()
        rm.shader = rsh
        red_rect.material = rm
        content.add_child(red_rect)
        flash_rect = ColorRect.new()
        flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        flash_rect.color = Color(1, 1, 1, 0)
        flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(flash_rect)
        # --- карточка субтитров: цельный центрированный блок (ТЗ п.3) ---
        # тег системы прижимается к фразе, блок живёт в зоне 45–58% высоты,
        # ширина ограничена (комфортные боковые поля на широких экранах)
        card_root = VBoxContainer.new()
        card_root.set_anchors_preset(Control.PRESET_CENTER)
        card_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
        card_root.grow_vertical = Control.GROW_DIRECTION_BOTH
        card_root.offset_left = -470
        card_root.offset_right = 470
        card_root.add_theme_constant_override("separation", 14)
        card_root.alignment = BoxContainer.ALIGNMENT_CENTER
        card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(card_root)
        speaker_lbl = ZUI.label("", 12, C_AI)
        speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        speaker_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        speaker_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        speaker_lbl.add_theme_font_override("font", ZUI.tech_font(2))
        card_root.add_child(speaker_lbl)
        text_lbl = ZUI.label("", 23, ZUI.TEXT)
        text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_root.add_child(text_lbl)
        _update_card_layout()
        # голос
        voice = ZVoice.new()
        add_child(voice)
        # пропуск: удержание в любом месте + кольцо в правом нижнем углу
        skip_hold = ZUI.ZSkipHold.new(1.1)
        skip_hold.skip_requested.connect(func(): skip_now())
        add_child(skip_hold)
        skip_hold.visible = false

# ---------------- запуск ----------------
func play(cue_list: Array, on_done: Callable = Callable()) -> bool:
        cues = cue_list
        _on_done_cb = on_done
        finished_flag = false
        running = true
        cue_idx = -1
        _advance_tag = ""
        _hold_all = false
        skip_hold.visible = skippable
        _open_letterbox()
        _next_cue()
        # корутина: вызывающий может await-ить play() до конца сцены
        var sk: bool = await completed
        return sk

var _on_done_cb: Callable = Callable()

func _open_letterbox() -> void:
        var tw := letter_top.create_tween()
        tw.tween_property(letter_top, "offset_bottom", size.y * 0.075, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        var tw2 := letter_bot.create_tween()
        tw2.tween_property(letter_bot, "offset_top", -size.y * 0.075, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# карточка живёт своим центром на ~52% высоты (зона 45–58% по ТЗ);
# пересчитывается при смене разрешения/соотношения сторон
func _update_card_layout() -> void:
        if card_root == null:
                return
        var h := size.y
        if h < 100.0:
                h = get_viewport_rect().size.y
        var shift := roundf(h * 0.02)
        card_root.offset_top = int(shift)
        card_root.offset_bottom = int(shift)

func _close_letterbox() -> void:
        var tw := letter_top.create_tween()
        tw.tween_property(letter_top, "offset_bottom", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
        var tw2 := letter_bot.create_tween()
        tw2.tween_property(letter_bot, "offset_top", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _w(sec: float) -> float:
        return sec * 0.02 if fast else sec

# ---------------- таймлайн ----------------
func _next_cue() -> void:
        if finished_flag:
                return
        cue_idx += 1
        if cue_idx >= cues.size():
                _finish(false)
                return
        var c: Dictionary = cues[cue_idx]
        # --- мгновенные действия ---
        var call_cb: Callable = c.get("call", Callable())
        if call_cb.is_valid():
                call_cb.call()
        if bool(c.get("red", false)):
                red_on = true
        if bool(c.get("red_off", false)):
                red_on = false
        if c.has("shake"):
                start_shake(float(c["shake"]), float(c.get("shake_k", 12.0)))
        if c.has("flash"):
                _do_flash(c)
        if c.has("veil"):
                _do_veil(c)
        if str(c.get("sfx", "")) != "":
                G.play_sfx(str(c["sfx"]), float(c.get("sfx_db", -8.0)), float(c.get("sfx_pitch", 1.0)))
        # субтитры
        var txt: String = str(c.get("text", ""))
        if txt != "":
                await _show_sub(c)
                if finished_flag: return
        else:
                await _hide_sub(0.25)
                if finished_flag: return
        # пауза перед следующим cue
        var wait_t := float(c.get("wait", 0.0))
        var vlist: Array = c.get("voice", [])
        if not vlist.is_empty():
                voice.play_list(vlist, float(c.get("voice_db", 2.0)))
        # внешнее ожидание
        if str(c.get("advance", "")) != "":
                _advance_tag = str(c["advance"])
                _hold_all = bool(c.get("hold_all", true))
                return   # дальше двинет advance()
        if bool(c.get("hold_all", false)):
                _hold_all = true
                return
        # озвучка может растянуть паузу
        if bool(c.get("voice_wait", false)) and voice.is_playing:
                await _wait_voice_end()
                if finished_flag: return
        if wait_t > 0.0:
                await get_tree().create_timer(_w(wait_t)).timeout
                if finished_flag: return
        # чтение: фраза показывается целиком, время показа зависит от длины
        # (ТЗ п.7/8: игрок успевает прочитать; явный hold усиливает паузу)
        if txt != "":
                var need := _w(1.4 + float(txt.length()) / 16.0)
                var hold_t: float = maxf(float(c.get("hold", 0.0)), need)
                if hold_t > 0.0:
                        await get_tree().create_timer(_w(hold_t)).timeout
                        if finished_flag: return
        _next_cue()

func _wait_voice_end() -> void:
        while voice.is_playing and not finished_flag:
                await get_tree().create_timer(0.1).timeout

# ожидание внешнего события: advance("tag") или сигнала
func advance(tag: String = "") -> void:
        if finished_flag:
                return
        if _advance_tag != "" and tag != "" and tag != _advance_tag:
                return
        _advance_tag = ""
        if _hold_all:
                _hold_all = false
        # небольшой штифт, чтобы внешние эффекты успели развернуться
        await get_tree().create_timer(_w(0.12)).timeout
        if finished_flag:
                return
        _next_cue()

# ---------------- субтитры (ТЗ п.3–7) ----------------
# Карточка = цельный блок: тег-заголовок прижат к фразе, всё по центру.
# Появление: предыдущая реплика мягко уходит, затем тег и фраза входят
# с небольшим интервалом. Печать по буквам не используется.
var _card_tw: Tween = null

const TEXT_MAIN := Color(0.885, 0.905, 0.875)     # мягкий светло-серый основной текст

# приглушённая версия цвета роли: тег читается, но не кричит
static func _muted_tag(col: Color) -> Color:
        return ZUI.muted_tag(col)

func _show_sub(c: Dictionary) -> void:
        await _hide_sub(0.34)
        if finished_flag: return
        var style := str(c.get("style", "auto"))
        var tag := str(c.get("speaker", ""))
        var col: Color = c.get("col", C_AI)
        # тег по стилю: system/voice/auto — тихая плашка цвета роли;
        # story — чистая литературная фраза без плашки
        if style == "story":
                tag = ""
        speaker_lbl.text = tag
        speaker_lbl.visible = tag != ""
        if tag != "":
                speaker_lbl.add_theme_color_override("font_color", _muted_tag(col))
        # основной текст — всегда мягкий светло-серый (ТЗ п.5)
        text_lbl.add_theme_color_override("font_color", TEXT_MAIN)
        text_lbl.text = str(c["text"])
        text_lbl.add_theme_font_size_override("font_size", 24 if style == "story" else 23)
        # появление: тег первым, фраза следом с небольшим интервалом
        if _card_tw != null and _card_tw.is_valid():
                _card_tw.kill()
        if fast:
                speaker_lbl.modulate.a = 1.0
                text_lbl.modulate.a = 1.0
                return
        speaker_lbl.modulate.a = 0.0
        text_lbl.modulate.a = 0.0
        _card_tw = create_tween()
        _card_tw.set_parallel(true)
        _card_tw.tween_property(speaker_lbl, "modulate:a", 1.0, 0.32)
        _card_tw.tween_property(text_lbl, "modulate:a", 1.0, 0.62).set_delay(0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hide_sub(dur: float) -> void:
        if _card_tw != null and _card_tw.is_valid():
                _card_tw.kill()
                _card_tw = null
        var vis := speaker_lbl.modulate.a > 0.01 or text_lbl.modulate.a > 0.01
        if not vis or fast:
                speaker_lbl.modulate.a = 1.0
                text_lbl.modulate.a = 1.0
                return
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(speaker_lbl, "modulate:a", 0.0, dur)
        tw.tween_property(text_lbl, "modulate:a", 0.0, dur)
        await tw.finished

func _skip_type() -> void:
        # совместимость: печати больше нет — мгновенно показать карточку целиком
        if _card_tw != null and _card_tw.is_valid():
                _card_tw.kill()
        speaker_lbl.modulate.a = 1.0
        text_lbl.modulate.a = 1.0

# ---------------- эффекты ----------------
func start_shake(dur: float, k := 12.0) -> void:
        shake_dur = maxf(0.01, dur)
        shake_t = shake_dur
        shake_k = k

func _do_flash(c: Dictionary) -> void:
        var up := _w(float(c["flash"]))
        var hold := _w(float(c.get("flash_hold", 0.12)))
        var fade := _w(float(c.get("flash_fade", 1.2)))
        flash_rect.color = c.get("flash_col", Color(1, 1, 1, 0))
        var tw := flash_rect.create_tween()
        tw.tween_property(flash_rect, "color:a", 1.0, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.tween_interval(hold)
        tw.tween_property(flash_rect, "color:a", 0.0, fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _do_veil(c: Dictionary) -> void:
        var to: float = float(c.get("veil_to", 0.9))
        var dur := _w(float(c["veil"]))
        var col: Color = c.get("veil_col", Color(0, 0, 0, 0.0))
        veil_rect.color = Color(col.r, col.g, col.b, veil_rect.color.a)
        var tw := veil_rect.create_tween()
        tw.tween_property(veil_rect, "color:a", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func set_veil(a: float, col := Color(0, 0, 0)) -> void:
        if veil_rect != null:
                veil_rect.color = Color(col.r, col.g, col.b, a)

func _process(delta: float) -> void:
        # тряска
        if shake_t > 0.0:
                shake_t = maxf(0.0, shake_t - delta)
                var k: float = shake_t / shake_dur
                content.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_k * k * k
        else:
                content.position = Vector2.ZERO
        # аварийное красное свечение: медленное дыхание (ТЗ п.6 — без резких пульсаций)
        if red_on:
                red_t += delta
                var a := 0.30 + 0.15 * (0.5 + 0.5 * sin(red_t * 0.85))
                red_rect.color.a = a
        elif red_rect.color.a > 0.0:
                red_rect.color.a = maxf(0.0, red_rect.color.a - delta * 0.5)

# ---------------- пропуск и завершение ----------------
func skip() -> void:
        # мягкий скип (legacy): завершить сцену
        if finished_flag or not skippable:
                return
        _finish(true)

func skip_now() -> void:
        # жёсткий скип (удержание): мгновенно завершить сцену целиком
        if finished_flag or not skippable:
                return
        _skip_type()
        _finish(true)

func _finish(is_skipped: bool) -> void:
        if finished_flag:
                return
        finished_flag = true
        running = false
        _skip_type()
        voice.stop()
        red_on = false
        _close_letterbox()
        var tw := veil_rect.create_tween()
        tw.tween_property(veil_rect, "color:a", 0.0, 0.5)
        var tw2 := flash_rect.create_tween()
        tw2.tween_property(flash_rect, "color:a", 0.0, 0.2)
        skip_hold.visible = false
        completed.emit(is_skipped)
        finished.emit(is_skipped)
        if _on_done_cb.is_valid():
                var cb := _on_done_cb
                _on_done_cb = Callable()
                cb.call()

func stop_now() -> void:
        # жёсткий стоп без колбэков (покидаем сцену)
        finished_flag = true
        running = false
        _skip_type()
        voice.stop()

# ---------------- статические помощники ----------------
# тряска произвольного узла (камера боя, панель интерфейса) — через tween
static func shake_node(node: Node2D, k := 10.0, dur := 0.4) -> void:
        if node == null or not is_instance_valid(node):
                return
        var base: Vector2 = node.position
        var steps := maxi(2, int(dur / 0.033))
        var tw: Tween = node.create_tween()
        for i in range(steps):
                var decay := 1.0 - float(i) / float(steps)
                tw.tween_property(node, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * k * decay, 0.033)
        tw.tween_property(node, "position", base, 0.05)
