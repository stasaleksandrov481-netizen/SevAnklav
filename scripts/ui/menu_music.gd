extends AudioStreamPlayer
const REPEAT_DELAY:=30.0
var repeat_timer: Timer
func _ready() -> void:
    bus="Music"
    for path in ["res://assets/audio/menu_music.ogg","res://assets/audio/menu_music.wav"]:
        if ResourceLoader.exists(path):
            stream=load(path).duplicate()
            break
    if stream==null: return
    if stream is AudioStreamWAV: stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
    if stream is AudioStreamOggVorbis: stream.loop=false
    repeat_timer=Timer.new();repeat_timer.wait_time=REPEAT_DELAY;repeat_timer.one_shot=true;add_child(repeat_timer)
    repeat_timer.timeout.connect(play)
    finished.connect(func(): repeat_timer.start())
    volume_db=linear_to_db(maxf(0.001,G.music_vol))
    play()
func _process(_delta: float) -> void:
    volume_db=linear_to_db(maxf(0.001,G.music_vol))
func _exit_tree() -> void:
    if is_instance_valid(repeat_timer):repeat_timer.stop()
    stop();stream=null
