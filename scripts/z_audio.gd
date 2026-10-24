# ============================================================
# ZAMBIENCE — АУДИО-РЕЖИССЁР АТМОСФЕРЫ (кампания «Земля мёртвых»)
# Многослойные эмбиент-состояния с кроссфейдом, случайные
# «предвестники» (капли, реле, дальние рыки), радио-подложка,
# последовательные аудио-очереди (ai_*.wav / radio_*.wav).
#
# Состояния:
#   silence — гробовая тишина (всё приглушено почти в ноль)
#   bunker  — гул реактора + вентиляция + капли/реле
#   alarm   — аварийный режим: сирена + учащённые искры
#   gas     — утечка газа: шипение под давлением
#   snow    — поверхность: метель
#
# Лупы WAV включаются кодом (AudioStreamWAV.loop_mode), файлы
# лежат в assets/sfx/. Отсутствующие файлы пропускаются.
# ============================================================
class_name ZAmbience
extends Node

var _loops: Dictionary = {}          # имя → {p: AudioStreamPlayer, base_db}
var _mode := ""
var _mode_k := 0.0                   # 0..1 громкость текущего режима
var _mode_target := 0.0
var _rnd_t := 3.0
var _radio_p: AudioStreamPlayer = null
var _radio_on := false
var _voice_seq: AudioStreamPlayer = null
var _voice_queue: Array = []
var _voice_idx := 0
var _voice_db := 0.0
var muted := false

const DIR := "res://assets/sfx/"

# состав режимов: [файл, громкость дБ при полном включении]
const MODES := {
	"bunker": [["z_hum_reactor", -13.0], ["z_vent_loop", -19.0]],
	"alarm": [["z_hum_reactor", -11.0], ["z_vent_loop", -17.0], ["z_siren_near", -9.0]],
	"alarm_far": [["z_hum_reactor", -13.0], ["z_siren_far", -8.0]],
	"gas": [["z_hum_reactor", -15.0], ["z_pressure_hiss", -10.0]],
	"snow": [["z_blizzard_loop", -9.0]],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for f in ["z_hum_reactor", "z_vent_loop", "z_siren_near", "z_siren_far", "z_blizzard_loop"]:
		var path: String = DIR + str(f) + ".wav"
		if not ResourceLoader.exists(path):
			continue
		var st: AudioStream = load(path)
		if st is AudioStreamWAV:
			(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(st as AudioStreamWAV).loop_begin = 0
			(st as AudioStreamWAV).loop_end = (st as AudioStreamWAV).data.size() / 2
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = "SFX"
		p.volume_db = -80.0
		add_child(p)
		_loops[f] = {"p": p, "base_db": -13.0}
	# радио-подложка
	var rp := DIR + "z_radio_bed.wav"
	if ResourceLoader.exists(rp):
		var rs: AudioStream = load(rp)
		if rs is AudioStreamWAV:
			(rs as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(rs as AudioStreamWAV).loop_begin = 0
			(rs as AudioStreamWAV).loop_end = (rs as AudioStreamWAV).data.size() / 2
		_radio_p = AudioStreamPlayer.new()
		_radio_p.stream = rs
		_radio_p.bus = "SFX"
		_radio_p.volume_db = -80.0
		add_child(_radio_p)
	# последовательная озвучка (как ZVoice, но с очередями любых списков)
	_voice_seq = AudioStreamPlayer.new()
	_voice_seq.bus = "SFX"
	add_child(_voice_seq)
	_voice_seq.finished.connect(_on_voice_done)

func set_mode(mode: String, fade := 2.2) -> void:
	if _mode == mode:
		return
	_mode = mode
	# собрать целевые громкости
	var want: Dictionary = {}
	for f in _loops:
		want[f] = -80.0
	for entry in MODES.get(mode, []):
		if _loops.has(str(entry[0])):
			want[str(entry[0])] = float(entry[1])
	for f in _loops:
		var L: Dictionary = _loops[f]
		var p: AudioStreamPlayer = L["p"]
		var tgt: float = want[f]
		if not p.playing and tgt > -79.0:
			p.play()
		if tgt <= -79.0:
			# уходим в тишину и останавливаем
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -80.0, fade)
			tw.tween_callback(func(): p.stop())
		else:
			var tw2 := create_tween()
			tw2.tween_property(p, "volume_db", tgt, fade)

func silence(fade := 1.6) -> void:
	set_mode("silence", fade)

# случайные «предвестники»: капли, реле, дальние звуки
func _process(delta: float) -> void:
	if _mode == "":
		return
	_rnd_t -= delta
	if _rnd_t <= 0.0:
		_rnd_t = randf_range(2.4, 6.5)
		_random_one_shot()

func _random_one_shot() -> void:
	if muted:
		return
	match _mode:
		"bunker":
			var r := randi() % 5
			if r == 0: G.play_sfx("z_drip" + str(1 + randi() % 3), -14.0, randf_range(0.9, 1.15))
			elif r == 1: G.play_sfx("z_relay", -18.0, randf_range(0.85, 1.2))
			elif r == 2: G.play_sfx("z_growl", -26.0, 0.8)
			elif r == 3: G.play_sfx("z_pressure_hiss", -24.0, randf_range(0.9, 1.1))
		"alarm", "alarm_far":
			var r2 := randi() % 4
			if r2 == 0: G.play_sfx("z_spark", -12.0, randf_range(0.9, 1.2))
			elif r2 == 1: G.play_sfx("z_drip1", -16.0)
			elif r2 == 2: G.play_sfx("z_metal", -18.0, 0.9)
		"gas":
			if randf() < 0.5: G.play_sfx("z_drip2", -18.0)
		"snow":
			if randf() < 0.35: G.play_sfx("z_growl", -22.0, randf_range(0.75, 0.95))

# ---------- радио-подложка ----------
func radio_on(db := -14.0, fade := 0.4) -> void:
	if _radio_p == null:
		return
	_radio_on = true
	if not _radio_p.playing:
		_radio_p.play()
	var tw := create_tween()
	tw.tween_property(_radio_p, "volume_db", db, fade)

func radio_off(fade := 0.5) -> void:
	if _radio_p == null:
		return
	_radio_on = false
	var tw := create_tween()
	tw.tween_property(_radio_p, "volume_db", -80.0, fade)
	tw.tween_callback(func(): _radio_p.stop())

# ---------- последовательные аудио-очереди ----------
# paths: массив путей "res://assets/sfx/voice/prologue/ai_01.wav"
# играются подряд; сигнал voice_done после конца.
signal voice_done()

func play_voice_seq(paths: Array, db := 2.0) -> void:
	stop_voice()
	_voice_queue.clear()
	for p in paths:
		var path := str(p)
		if path != "" and ResourceLoader.exists(path):
			var st: AudioStream = load(path)
			if st != null:
				_voice_queue.append(st)
	_voice_idx = 0
	_voice_db = db
	if _voice_queue.is_empty():
		return
	_voice_seq.stream = _voice_queue[0]
	_voice_seq.volume_db = db
	_voice_seq.play()

func voice_playing() -> bool:
	return _voice_seq != null and _voice_seq.playing

func stop_voice() -> void:
	_voice_queue.clear()
	if _voice_seq != null:
		_voice_seq.stop()
		_voice_seq.stream = null

func _on_voice_done() -> void:
	if _voice_queue.is_empty():
		return
	_voice_idx += 1
	if _voice_idx >= _voice_queue.size():
		_voice_queue.clear()
		voice_done.emit()
		return
	_voice_seq.stream = _voice_queue[_voice_idx]
	_voice_seq.play()
