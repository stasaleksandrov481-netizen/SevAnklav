# ============================================================
# КАМПАНИЯ «ЗЕМЛЯ МЕРТВЫХ» — ИНТЕРАКТИВНЫЙ ПРОЛОГ (по ТЗ №1)
# ЭКРАН 1: чёрный экран, кнопка с SVG-иконкой вопроса [ Где я?... ]
# ЭКРАН 2: диалог с ИИ (эффект печати) + выбор ответа А/Б
# ЭКРАН 3: тяжёлый удар в металл, искры, БЕЛАЯ ВСПЫШКА (flashbang)
#          и плавно затухающий звон в ушах (tinnitus)
# ЭКРАН 4: голос по рации сквозь помехи → [ ВЫБИТЬ СТЕКЛО И ПОДНЯТЬСЯ ]
#          → загрузка 2D-локации «Сектор 1».
# Пропуск: зажать кнопку внизу. Диалог — движок z_dialog.gd.
# ============================================================
extends Control

var main_ref = null

# ---------- узлы сцены ----------
var content: Control = null       # всё, что трясётся при ударе
var dialog: ZDialog = null
var start_btn: ZUI.ZButton = null
var flash_rect: ColorRect = null
var veil_rect: ColorRect = null     # темновая вуаль: свет возвращается медленно
var red_glow: ColorRect = null
var skip_btn: ZUI.ZHoldButton = null
var head_lbl: Label = null
var sparks: CPUParticles2D = null

var stage := 0                    # 1..4 (логические экраны ТЗ)
var heart_t := 0.6
var shake_t := 0.0
var finished := false

# реплика ИИ после выбора (зависит от варианта)
const AI_REPLY_A := "«Команды „отключить“ не найдено. Ошибка. Данные повреждены ЭМИ-импульсом. Вы — единственный выживший носитель нулевого штамма вируса в северном секторе. Ваш организм борется с мутацией. Вы — ключ к спасению или уничтожению Анклава...»"
const AI_REPLY_B := "«Пациент — вы. Нейро-связь — ваша. Ошибка. Данные повреждены ЭМИ-импульсом. Вы — единственный выживший носитель нулевого штамма вируса в северном секторе. Ваш организм борется с мутацией. Вы — ключ к спасению или уничтожению Анклава...»"

const RADIO_TEXT := "«Эй! Если ты там живой внутри капсулы — очнись! Наверху прорвало периметр! Выбивай стекло, хватай КПК со стола и беги через технический шлюз! Лаборатория кишит тварями!»"

# ---------- ОЗВУЧКА (чужие голоса: ИИ и рация) ----------
# Папка с файлами: assets/sfx/voice/prologue/
# Какой файл за какие слова — см. README_ОЗВУЧКА.txt в этой папке.
# Замените тихие заглушки на свои WAV, ИМЕНА ФАЙЛОВ МЕНЯТЬ НЕЛЬЗЯ.
const VDIR := "res://assets/sfx/voice/prologue/"
const VOICE_AI_INTRO := ["ai_01.wav", "ai_02.wav", "ai_03.wav"]
const VOICE_AI_A := ["ai_a_01.wav", "ai_a_02.wav", "ai_a_03.wav", "ai_a_04.wav", "ai_a_05.wav"]
# ответ Б: первые две фразы свои, дальше — ТЕ ЖЕ файлы, что в ответе А
const VOICE_AI_B := ["ai_b_01.wav", "ai_b_02.wav", "ai_a_03.wav", "ai_a_04.wav", "ai_a_05.wav"]
const VOICE_RADIO := ["radio_01.wav", "radio_02.wav", "radio_03.wav", "radio_04.wav"]

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        # Control под CanvasLayer: anchors не всегда пересчитывают layout
        size = get_viewport_rect().size
        get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
        G.set_music_track("z")
        _build_scene()
        _enter_screen(1)

# ---------- построение сцены ----------
func _build_scene() -> void:
        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.006, 0.007, 0.006)
        add_child(bg)
        # ржавое свечение по краям (едва заметное)
        red_glow = ColorRect.new()
        red_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
        red_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var glow_sh := Shader.new()
        glow_sh.code = """
shader_type canvas_item;
void fragment() {
        vec2 c = UV - vec2(0.5);
        float d = length(c) * 1.4;
        float a = smoothstep(0.55, 1.15, d) * 0.16;
        COLOR = vec4(0.35, 0.08, 0.05, a);
}
"""
        var gm := ShaderMaterial.new()
        gm.shader = glow_sh
        red_glow.material = gm
        add_child(red_glow)
        add_child(ZUI.scanlines())
        add_child(ZUI.vignette(0.62))
        # контейнер, который трясётся при ударе
        content = Control.new()
        content.set_anchors_preset(Control.PRESET_FULL_RECT)
        content.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(content)
        # заголовок кампании
        head_lbl = ZUI.label("— КАМПАНИЯ «ЗЕМЛЯ МЕРТВЫХ» · ПРОЛОГ —", 13, Color(0.40, 0.46, 0.40))
        head_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
        head_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
        head_lbl.offset_top = 24
        content.add_child(head_lbl)
        # ЭКРАН 1: кнопка [ Где я?... ] с SVG-иконкой вопроса
        start_btn = ZUI.ZButton.new("Где я?...", Vector2(380, 68), false, 21, "question")
        start_btn.set_anchors_preset(Control.PRESET_CENTER)
        start_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
        start_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
        start_btn.offset_left = -190
        start_btn.offset_right = 190
        start_btn.offset_top = -34
        start_btn.offset_bottom = 34
        start_btn.pressed.connect(func():
                G.play_sfx("z_static", -12.0)
                _enter_screen(2))
        content.add_child(start_btn)
        ZUI.entrance(start_btn, 0.7, 8)
        # ЭКРАНЫ 2-4: диалоговый движок (mouse_filter STOP внутри ZDialog)
        dialog = ZDialog.new()
        dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
        dialog.visible = false
        dialog.finished.connect(_finish_prologue)   # кнопка «ВЫБИТЬ СТЕКЛО...» → next: -1
        content.add_child(dialog)
        # искры (ЭКРАН 3)
        sparks = CPUParticles2D.new()
        sparks.emitting = false
        sparks.one_shot = true
        sparks.amount = 42
        sparks.lifetime = 0.7
        sparks.explosiveness = 0.95
        sparks.direction = Vector2(0, -1)
        sparks.spread = 180.0
        sparks.initial_velocity_min = 220.0
        sparks.initial_velocity_max = 520.0
        sparks.gravity = Vector2(0, 900)
        sparks.scale_amount_min = 1.6
        sparks.scale_amount_max = 3.4
        sparks.color = Color(1.0, 0.85, 0.5)
        sparks.position = size * 0.5
        add_child(sparks)
        # БЕЛАЯ ВСПЫШКА (поверх всего)
        flash_rect = ColorRect.new()
        flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        flash_rect.color = Color(1, 1, 1, 0)
        flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(flash_rect)
        # темновая вуаль (свет после вспышки возвращается медленно; под вспышкой)
        veil_rect = ColorRect.new()
        veil_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        veil_rect.color = Color(0.0, 0.0, 0.02, 0.0)
        veil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(veil_rect)
        # пропуск зажатием
        skip_btn = ZUI.ZHoldButton.new("ЗАЖМИТЕ, ЧТОБЫ ПРОПУСТИТЬ ПРОЛОГ", 1.1)
        skip_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        skip_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
        skip_btn.offset_left = -220
        skip_btn.offset_right = 220
        skip_btn.offset_top = -76
        skip_btn.offset_bottom = -32
        skip_btn.pressed.connect(func():
                G.play_sfx("ui_click", -10.0)
                _finish_prologue())
        add_child(skip_btn)

# ---------- стадии пролога ----------
func _v(names: Array) -> Array:
        # имена файлов → полные пути для ZVoice
        var out: Array = []
        for n in names:
                out.append(VDIR + str(n))
        return out

func _enter_screen(n: int) -> void:
        stage = n
        match n:
                1:
                        # ЭКРАН 1: тьма и вопрос
                        pass
                2:
                        # ЭКРАН 2: диалог с ИИ
                        start_btn.visible = false
                        dialog.visible = true
                        _heart_on()
                        dialog.set_stages(_dialog_stages())
                        dialog.start(0)

func _dialog_stages() -> Array:
        return [
                {
                        "speaker": "ИИ СИСТЕМЫ · КАПСУЛА РЕАНИМАЦИИ",
                        "col": ZUI.NEON,
                        "text": "«Внимание. Пациент проявляет признаки сознания. Нейро-связь восстановлена. Добро пожаловать домой, Командир.»",
                        "voice": _v(VOICE_AI_INTRO), "voice_db": 3.0,
                        "sfx": "z_hiss", "sfx_db": -14.0,
                        "choices": [
                                {"text": "А:  «Отключите эту систему! Где мои люди?»", "icon": "radio", "accent": false},
                                {"text": "Б:  «Какой пациент? Какая нейро-связь?»", "icon": "question", "accent": false},
                        ],
                        "on_choice": _on_ai_choice,
                },
                {
                        "speaker": "ИИ СИСТЕМЫ · ОШИБКА ЦЕЛОСТНОСТИ ДАННЫХ",
                        "col": ZUI.ALERT,
                        "text": "...",
                        "sfx": "z_infect", "sfx_db": -16.0,
                        "speed": 0.018,
                        "on_done": _strike_sequence,
                        "hold": true,   # дальше запустит сценарий удара (экран 3)
                },
                {
                        "speaker": "РАДИОЧАСТОТА · СИГНАЛ СЛАБЫЙ, СКВОЗЬ ПОМЕХИ",
                        "col": Color(0.85, 0.72, 0.42),
                        "text": RADIO_TEXT,
                        "voice": _v(VOICE_RADIO), "voice_db": 4.0,
                        "sfx": "z_static", "sfx_db": -8.0,
                        "btn": {"text": "ВЫБИТЬ СТЕКЛО И ПОДНЯТЬСЯ", "icon": "door"},
                        "next": -1,
                },
        ]

# выбор игрока: вариант реплики ИИ зависит от ответа А/Б
func _on_ai_choice(i: int) -> int:
        var st: Dictionary = dialog.stages[1]
        st["text"] = AI_REPLY_A if i == 0 else AI_REPLY_B
        st["voice"] = _v(VOICE_AI_A if i == 0 else VOICE_AI_B)
        st["voice_db"] = 3.0
        return 1

func _heart_on() -> void:
        heart_t = 0.3

# ЭКРАН 3: МОМЕНТ УДАРА И СБОЯ
func _strike_sequence() -> void:
        stage = 3
        # даём озвучке ИИ договорить до начала сбоя (пропуск — мгновенно тише)
        while dialog.voice.is_playing and not finished:
                await get_tree().create_timer(0.1).timeout
        if finished:
                return
        dialog.voice.stop()
        await get_tree().create_timer(0.45).timeout
        if finished:
                return
        G.play_sfx("z_spark", -6.0)
        sparks.restart()
        sparks.emitting = true
        await get_tree().create_timer(0.18).timeout
        if finished:
                return
        G.play_sfx("z_spark", -9.0, 1.3)   # FIX7v2: вторая очередь искр
        await get_tree().create_timer(0.16).timeout
        if finished:
                return
        # тяжёлый удар в металл + взрыв + вспышка + звон (FIX7v2: сочно)
        G.play_sfx("z_metal", -2.0)
        G.play_sfx("expl_s", -9.0)
        G.play_sfx("z_glass", -10.0)
        G.play_sfx("z_tinnitus", -4.0)
        shake_t = 0.9
        # свет появляется медленно (по ТЗ): нарастание ~0.6 секунды
        var tw := flash_rect.create_tween()
        tw.tween_property(flash_rect, "color:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        # белое держится, затем ОЧЕНЬ медленно рассеивается (по ТЗ)
        await get_tree().create_timer(2.4).timeout
        if finished:
                return
        var tw2 := flash_rect.create_tween()
        tw2.tween_property(flash_rect, "color:a", 0.0, 6.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        await get_tree().create_timer(6.5).timeout
        if finished:
                return
        # вспышка рассеялась: темнота, и только через 2-3 секунды — слова (по ТЗ)
        G.play_sfx("alarm", -26.0)   # FIX7v2: далёкая сирена за стеной
        veil_rect.color = Color(0.0, 0.0, 0.02, 0.55)
        await get_tree().create_timer(2.8).timeout
        if finished:
                return
        # ЭКРАН 4: рация — текст печатается, пока свет медленно возвращается
        var tw3 := veil_rect.create_tween()
        tw3.tween_property(veil_rect, "color:a", 0.0, 5.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _enter_screen(4)
        dialog.start(2)

func _process(delta: float) -> void:
        # тряска при ударе
        if shake_t > 0.0:
                shake_t = maxf(0.0, shake_t - delta)
                var k: float = shake_t / 0.9
                content.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 22.0 * k * k
        else:
                content.position = Vector2.ZERO
        # сердцебиение в темноте (экраны 1-2)
        if stage in [1, 2] and not finished:
                heart_t -= delta
                if heart_t <= 0.0:
                        heart_t = 1.35
                        G.play_sfx("z_heart", -18.0)

func _finish_prologue() -> void:
        if finished:
                return
        finished = true
        if dialog != null:
                dialog.stop_all()
        G.zsave["seen_prologue"] = true
        G.write_save()
        if main_ref != null:
                main_ref.prologue_done()
