# ============================================================
# ZVOICE — ПРОИГРЫВАТЕЛЬ ОЗВУЧКИ ДИАЛОГОВ
# Играет список WAV-файлов ПОСЛЕДОВАТЕЛЬНО (фраза за фразой),
# без случайного питча (в отличие от G.play_sfx — речь не «плавает»).
# Отсутствующие файлы молча пропускаются: игра работает и без озвучки.
# Как заменить голоса: папка assets/sfx/voice/prologue/ — см. README.
# ============================================================
class_name ZVoice
extends Node

signal finished_all()

var total_len := 0.0        # суммарная длительность загруженных фраз (сек)
var is_playing := false
var has_tracks := false     # нашлась ли хотя бы одна реальная озвучка

var _player: AudioStreamPlayer = null
var _queue: Array = []      # готовые AudioStream
var _idx := 0
var _db := 0.0

func _init() -> void:
        _player = AudioStreamPlayer.new()
        _player.bus = "SFX"
        _player.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(_player)
        _player.finished.connect(_on_track_done)

# paths — массив строк вида "res://assets/sfx/voice/prologue/ai_01.wav"
func play_list(paths: Array, volume_db := 0.0) -> void:
        stop()
        _db = volume_db
        _queue.clear()
        total_len = 0.0
        has_tracks = false
        for p in paths:
                var path := str(p)
                if path == "" or not ResourceLoader.exists(path):
                        continue
                var st: AudioStream = load(path)
                if st == null:
                        continue
                _queue.append(st)
                total_len += st.get_length()
        has_tracks = not _queue.is_empty()
        if not has_tracks:
                return
        _idx = 0
        is_playing = true
        _play_current()

func _play_current() -> void:
        if _idx >= _queue.size():
                stop()
                finished_all.emit()
                return
        _player.stream = _queue[_idx]
        _player.volume_db = _db
        _player.play()

func _on_track_done() -> void:
        if not is_playing:
                return
        _idx += 1
        _play_current()

func stop() -> void:
        is_playing = false
        _player.stop()
        _player.stream = null
