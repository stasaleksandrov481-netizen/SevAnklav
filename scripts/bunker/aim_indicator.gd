extends Control
var btl
func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
    if btl==null or btl.paused or not btl._has_weapon7() or not btl.manual_aim or not btl.player["alive"]: return
    var origin: Vector2=btl.player["spr"].position
    var aim: float=btl.player["aim"]
    var dir:=Vector2.from_angle(aim)
    var distance: float=btl._ray_wall_dist(origin,dir,330.0)
    var p:=origin+dir*maxf(24,distance-6)
    var screen: Vector2=(p-btl.camera.get_screen_center_position())*btl.camera.zoom+get_viewport_rect().size*0.5
    var spread: float=3+btl.shot_heat4*10+btl.player_velocity.length()*0.035
    var col:=Color(0.77,0.85,0.84,0.65)
    # Subtle dispersion brackets, no laser line or large crosshair ring.
    for sign in [-1,1]:
        var side: Vector2=dir.orthogonal()*sign
        var edge: Vector2=screen+side*spread
        draw_line(edge-dir*3,edge+dir*3,col,1.2,true)
    draw_circle(screen,1.1,col)
