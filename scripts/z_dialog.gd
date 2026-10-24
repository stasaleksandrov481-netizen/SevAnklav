# ============================================================
# ZDIALOG — МОДУЛЬНАЯ ДИАЛОГОВАЯ СИСТЕМА КАМПАНИИ
# Эффект печатной машинки, реплики с указанием говорящего,
# варианты выбора, пропуск тапом/кликом, звуковые тики.
# Данные стадий описываются массивом словарей — движок
# переиспользуется: пролог, радиосообщения, терминал сканера.
#
# Стадия (Dictionary):
#   speaker: String      — кто говорит (плашка сверху)
#   col: Color           — цвет плашки говорящего
#   text: String         — реплика (печатается посимвольно)
#   choices: Array       — [{text, icon, accent, danger}] (опционально)
#   auto: float          — сек до авто-перехода (если нет choices)
#   btn: Dictionary      — {text, icon} единственная кнопка «дальше»
#   sfx: String          — звук при входе в стадию
#   voice: Array         — ОЗВУЧКА реплики: список путей WAV, играется
#                          последовательно (ZVoice). Скорость печати
#                          подгоняется под длительность озвучки. Отсутствующие
#                          файлы пропускаются — игра работает и без них.
#   voice_db: float      — громкость озвучки (по умолчанию 0 дБ: сами WAV-файлы уже
#                          нормализованы до -14 dBFS RMS с лимитером пиков)
#   on_choice: Callable  — fn(choice_idx) -> next_stage_idx
#   next: int            — индекс следующей стадии (или -1 = конец)
# ============================================================
class_name ZDialog
extends Control

signal stage_entered(idx: int)
signal finished()

var stages: Array = []
var stage_idx := -1
var typing := false
var type_idx := 0
var type_text := ""
var type_speed := 0.030          # сек на символ (чуть медленнее — текст не «бежит»)
var type_pause := 0              # тиков паузы после знака препинания/слова
var on_finished: Callable = Callable()

var speaker_lbl: Label = null
var text_lbl: Label = null
var card_root: VBoxContainer = null   # цельный блок: говорящий + реплика
var choice_row: VBoxContainer = null
var type_timer: Timer = null
var auto_timer: Timer = null
var click_hint: Label = null
var voice: ZVoice = null            # озвучка реплик (чужие голоса: ИИ, рация)

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_STOP
        _build_ui()
        type_timer = Timer.new()
        type_timer.wait_time = type_speed
        type_timer.timeout.connect(_type_tick)
        add_child(type_timer)
        auto_timer = Timer.new()
        auto_timer.one_shot = true
        auto_timer.timeout.connect(func(): _enter_stage(stage_idx + 1))
        add_child(auto_timer)
        voice = ZVoice.new()
        add_child(voice)

func _build_ui() -> void:
        # --- карточка реплики: говорящий прижат к тексту, цельный блок ---
        # по центру (чуть выше середины — ниже остаются выборы/кнопки)
        card_root = VBoxContainer.new()
        card_root.set_anchors_preset(Control.PRESET_CENTER)
        card_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
        card_root.grow_vertical = Control.GROW_DIRECTION_BOTH
        card_root.offset_left = -470
        card_root.offset_right = 470
        card_root.offset_top = -86
        card_root.offset_bottom = -86
        card_root.add_theme_constant_override("separation", 13)
        card_root.alignment = BoxContainer.ALIGNMENT_CENTER
        card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(card_root)
        # говорящий
        speaker_lbl = ZUI.label("", 12, ZUI.NEON)
        speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        speaker_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        speaker_lbl.add_theme_font_override("font", ZUI.tech_font(2))
        card_root.add_child(speaker_lbl)
        # текст реплики
        text_lbl = ZUI.label("", 23, ZUI.TEXT)
        text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card_root.add_child(text_lbl)
        # варианты выбора
        choice_row = VBoxContainer.new()
        choice_row.set_anchors_preset(Control.PRESET_CENTER)
        choice_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
        choice_row.grow_vertical = Control.GROW_DIRECTION_END
        choice_row.offset_left = -460
        choice_row.offset_right = 460
        choice_row.offset_top = 84
        choice_row.offset_bottom = 260
        choice_row.add_theme_constant_override("separation", 14)
        choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
        add_child(choice_row)
        # подсказка «тап — дальше»
        click_hint = ZUI.label("▾  тап, чтобы продолжить", 12, ZUI.FAINT)
        click_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        click_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
        click_hint.offset_left = -200
        click_hint.offset_right = 200
        click_hint.offset_top = -132
        click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        click_hint.visible = false
        add_child(click_hint)

func set_stages(list: Array) -> void:
        stages = list

func start(idx := 0) -> void:
        _enter_stage(idx)

# ---------- отрисовка стадии ----------
func _enter_stage(n: int) -> void:
        if n >= stages.size() or n < 0:
                _finish()
                return
        stage_idx = n
        voice.stop()                        # предыдущая озвучка замолкает
        var st: Dictionary = stages[n]
        _clear_choices()
        stage_entered.emit(n)
        if str(st.get("sfx", "")) != "":
                G.play_sfx(str(st["sfx"]), float(st.get("sfx_db", -10.0)))
        _set_speaker(str(st.get("speaker", "")), st.get("col", ZUI.NEON))
        var vlist: Array = st.get("voice", [])
        if not vlist.is_empty():
                voice.play_list(vlist, float(st.get("voice_db", 2.0)))   # FIX7v2: озвучка по умолчанию громче
        _type_out(str(st.get("text", "")), st)
        auto_timer.stop()

func _set_speaker(txt: String, col: Color) -> void:
        speaker_lbl.text = txt
        # тег говорящего — приглушённый (ТЗ п.5: не кричит, фраза — главный акцент)
        speaker_lbl.add_theme_color_override("font_color", ZUI.muted_tag(col))

func _type_out(text: String, st: Dictionary) -> void:
        type_text = text
        type_idx = 0
        type_pause = 0
        typing = true
        text_lbl.text = ""
        # если есть озвучка — печатаем текст примерно за время её звучания
        var spd: float = float(st.get("speed", type_speed))
        if voice.has_tracks and voice.total_len > 0.4 and text.length() > 0:
                spd = clampf(voice.total_len / float(text.length()), 0.016, 0.075)
        type_timer.wait_time = spd
        type_timer.start()
        click_hint.visible = false

func _type_tick() -> void:
        if not typing:
                return
        # пауза после знака/слова: слова появляются не «бегом», а с остановками
        if type_pause > 0:
                type_pause -= 1
                return
        if type_idx >= type_text.length():
                _type_done()
                return
        type_idx += 1
        text_lbl.text = type_text.substr(0, type_idx)
        var ch := type_text[type_idx - 1]
        # пауза ПОСЛЕ нужного слова: крупная на точке/многоточии, средняя на запятой,
        # лёгкая — после каждого слова
        if ch in [".", "!", "?", "…"]:
                type_pause = 16
        elif ch in [",", ":", ";"] or ch == "—":
                type_pause = 8
        elif ch == " ":
                type_pause = 2
        if type_idx % 6 == 0:
                G.play_sfx("ui_click", -26.0, 2.1)
        if type_idx >= type_text.length():
                _type_done()

func _type_done() -> void:
        typing = false
        type_timer.stop()
        var st: Dictionary = stages[stage_idx]
        # посценовый колбэк (эффекты, скриптовые реакции)
        var done_cb: Callable = st.get("on_done", Callable())
        if done_cb.is_valid():
                done_cb.call()
        var choices: Array = st.get("choices", [])
        if bool(st.get("hold", false)):
                return   # стадия ждёт внешнего управления (сценарные эффекты)
        if not choices.is_empty():
                _show_choices(choices, st)
        elif st.has("btn"):
                _show_next_btn(st)
        else:
                # без выборов: тап = дальше
                var delay: float = float(st.get("auto", 1.1))
                if delay <= 0.0:
                        click_hint.visible = true
                else:
                        auto_timer.wait_time = delay
                        auto_timer.start()
                        click_hint.visible = true

func _show_choices(choices: Array, st: Dictionary) -> void:
        var cb: Callable = st.get("on_choice", Callable())
        for i in range(choices.size()):
                var c: Dictionary = choices[i]
                var b := ZUI.ZButton.new(str(c.get("text", "...")), Vector2(560, 58), bool(c.get("accent", false)), 15, str(c.get("icon", "")))
                b.danger = bool(c.get("danger", false))
                b.pressed.connect(func():
                        G.play_sfx("ui_click", -8.0)
                        _clear_choices()
                        if cb.is_valid():
                                var nxt: int = cb.call(i)
                                _enter_stage(nxt)
                        else:
                                _enter_stage(int(c.get("next", stage_idx + 1))))
                choice_row.add_child(b)
                ZUI.entrance(b, 0.12 + i * 0.12, 10)

func _show_next_btn(st: Dictionary) -> void:
        var bd: Dictionary = st["btn"]
        var b := ZUI.ZButton.new(str(bd.get("text", "ДАЛЬШЕ")), Vector2(460, 60), true, 17, str(bd.get("icon", "")))
        b.pressed.connect(func():
                G.play_sfx("ui_click", -8.0)
                _enter_stage(int(st.get("next", stage_idx + 1))))
        choice_row.add_child(b)
        ZUI.entrance(b, 0.15, 8)

func _clear_choices() -> void:
        for c in choice_row.get_children():
                c.queue_free()

# клик по экрану: достроить печать мгновенно или перейти дальше
func _gui_input(ev: InputEvent) -> void:
        if stage_idx < 0 or stages.is_empty():
                return
        var mb := ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed
        var tc := ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed
        if mb or tc:
                if typing:
                        # мгновенно допечатать (пауза тоже сбрасывается)
                        type_pause = 0
                        type_idx = type_text.length()
                        text_lbl.text = type_text
                        _type_done()
                elif choice_row.get_child_count() == 0 and not bool(stages[stage_idx].get("hold", false)):
                        var st: Dictionary = stages[stage_idx]
                        if not st.has("btn") and st.get("choices", []).is_empty():
                                G.play_sfx("ui_click", -14.0)
                                auto_timer.stop()
                                _enter_stage(stage_idx + 1)

func _finish() -> void:
        voice.stop()
        finished.emit()
        if on_finished.is_valid():
                on_finished.call()

# полная тишина: остановить печать, таймеры и озвучку (кнопка пропуска)
func stop_all() -> void:
        typing = false
        type_pause = 0
        type_timer.stop()
        auto_timer.stop()
        voice.stop()
