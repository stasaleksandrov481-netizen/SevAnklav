extends "res://scripts/ui/viewport_control.gd"
var main_ref = null
var finished := false
var step := 0
var body: Label
var choices: VBoxContainer
var root: VBoxContainer
var reveal := 0.0
var branch := ""
var transitioning := false
func _ready() -> void:
    super._ready()
    mouse_filter=Control.MOUSE_FILTER_STOP
    var bg:=ColorRect.new();bg.color=Color(0.003,0.005,0.007);bg.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(bg)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,100)
    for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,55)
    add_child(margin)
    root=VBoxContainer.new();root.alignment=BoxContainer.ALIGNMENT_CENTER;root.add_theme_constant_override("separation",28);margin.add_child(root)
    _page()
func _page() -> void:
    transitioning=false
    for c in root.get_children(): root.remove_child(c);c.queue_free()
    var tag:=ZUI.label("ОБЪЕКТ «ЗАРЯ»   /   V-17   /   %02d"%(step+1),14,Color(0.38,0.49,0.55));root.add_child(tag)
    var text: String
    var answers: Array
    match step:
        0:
            text="Сначала возвращается холод. Затем — собственное имя.\n\nВолков. Вы помните его, но не помните, как оказались здесь. Над лицом — стекло. За ним медленно мигает красный свет."
            answers=["Попытаться вспомнить последнее событие.","Прислушаться к тому, что происходит снаружи."]
        1:
            text=("Воспоминание обрывается раньше, чем удаётся различить лица. Остаётся только ощущение: вы не должны были проснуться здесь." if branch=="memory" else "За стеклом работает оборудование. Но никто не отвечает. Где-то щёлкает реле, и красный свет на мгновение становится ярче.")+"\n\nНа внутренней стороне капсулы загорается строка:\n«ПАЦИЕНТ V-17. СОЗНАНИЕ ВОССТАНОВЛЕНО. СТАБИЛИЗАЦИЯ ПРЕРВАНА»."
            answers=["«Здесь кто-нибудь есть?»", "Проверить, могу ли я двигаться."]
        _:
            text="Ответа нет. На запястье — метка: «ВОЛКОВ / ЭКСПЕРИМЕНТ №12».\n\nВы не знаете, что произошло с комплексом. Сначала нужно выбраться из капсулы и найти персонал."
            answers=["Открыть глаза."]
    body=ZUI.wrap_label(text,25,Color(0.78,0.82,0.82),1100);root.add_child(body)
    body.visible_ratio=0;reveal=0
    choices=VBoxContainer.new();choices.add_theme_constant_override("separation",12);root.add_child(choices)
    for i in range(answers.size()):
        var button:=Button.new();button.text="—  "+answers[i];button.alignment=HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size=Vector2(0,62);button.add_theme_font_size_override("font_size",18)
        var style:=ZUI.panel_style(Color(0.025,0.035,0.042),Color(0.16,0.23,0.27),18)
        button.add_theme_stylebox_override("normal",style)
        var hot:=style.duplicate();hot.border_color=Color(0.46,0.61,0.68);button.add_theme_stylebox_override("hover",hot);button.add_theme_stylebox_override("focus",hot)
        choices.add_child(button)
        var index:=i
        button.pressed.connect(func(): _choose(index))
    choices.modulate.a=0
    root.modulate.a=0;create_tween().tween_property(root,"modulate:a",1.0,0.45)
func _process(delta: float) -> void:
    if not is_instance_valid(body): return
    reveal=minf(1.0,reveal+delta*38.0/maxf(1,body.text.length()))
    body.visible_ratio=reveal
    choices.modulate.a=move_toward(choices.modulate.a,1.0 if reveal>0.75 else 0.0,delta*3)
    for c in choices.get_children(): c.disabled=transitioning or reveal<0.75
func _choose(index: int) -> void:
    if finished or transitioning: return
    transitioning=true
    if step==0: branch="memory" if index==0 else "listen"
    G.zsave["intro_response_%d"%step]=index
    if step>=2: _finish_prologue();return
    choices.mouse_filter=Control.MOUSE_FILTER_STOP
    for c in choices.get_children(): c.disabled=true
    var tw:=create_tween();tw.tween_property(root,"modulate:a",0.0,0.25)
    tw.tween_callback(func(): step+=1;_page())
func _finish_prologue() -> void:
    if finished: return
    finished=true
    G.zsave["seen_prologue"]=true;G.write_save()
    var tw:=create_tween();tw.tween_property(root,"modulate:a",0.0,0.45)
    tw.tween_callback(func():
        if main_ref!=null: main_ref.prologue_done())
