extends "res://scripts/ui/page_canvas.gd"
const Back=preload("res://scripts/ui/native_back.gd")
var main_ref = null
var finished := false
var step := 0
var body: Label
var choices: VBoxContainer
var root: VBoxContainer
var reveal := 0.0
var branch := ""
var transitioning := false
var content_margin: MarginContainer
var background: TextureRect
func _ready() -> void:
    super._ready()
    Back.install(self,_back_to_menu)
    step=clampi(int(G.zsave.get("intro_step",0)),0,2)
    if step>0:branch="memory" if int(G.zsave.get("intro_response_0",0))==0 else "listen"
    mouse_filter=Control.MOUSE_FILTER_STOP
    background=TextureRect.new(); background.texture=preload("res://assets/ui/prologue/capsule_v17.png"); background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
    var bg:=ColorRect.new();bg.color=Color(0.003,0.005,0.007,0.30);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
    var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,100)
    for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,55)
    add_child(margin); content_margin=margin
    resized.connect(_layout_prologue)
    root=VBoxContainer.new();root.alignment=BoxContainer.ALIGNMENT_CENTER;root.add_theme_constant_override("separation",28);margin.add_child(root)
    _layout_prologue()
    _page()
func _layout_prologue() -> void:
    if not content_margin: return
    content_margin.add_theme_constant_override("margin_left",int(maxf(32,size.x*0.055)))
    content_margin.add_theme_constant_override("margin_right",int(maxf(32,size.x*0.35)))
func _page() -> void:
    transitioning=false
    for c in root.get_children(): root.remove_child(c);c.queue_free()
    var tag:=ZUI.label("СЕВЕРНЫЙ АНКЛАВ   /   ОБЪЕКТ «ЗАРЯ»   /   0%d — 03"%(step+1),15,Color(0.49,0.61,0.67));root.add_child(tag)
    var heading:=ZUI.label(["ВОЗВРАЩЕНИЕ", "СОЗНАНИЕ ВОССТАНОВЛЕНО", "АЛЕКСЕЙ ВОЛКОВ"][step],34,Color(0.88,0.91,0.91));root.add_child(heading)
    root.add_child(HSeparator.new())
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
    body=ZUI.wrap_label(text,24,Color(0.78,0.82,0.82),0)
    body.custom_minimum_size=Vector2(0,220);root.add_child(body)
    body.visible_ratio=0;reveal=0
    choices=VBoxContainer.new();choices.add_theme_constant_override("separation",12);root.add_child(choices)
    for i in range(answers.size()):
        var button:=Button.new();button.text="0%d   /   "% (i+1)+answers[i];button.alignment=HORIZONTAL_ALIGNMENT_LEFT
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
    tw.tween_callback(func(): step+=1;G.zsave["intro_step"]=step;G.write_save();_page())
func _back_to_menu() -> void:
    if finished or main_ref==null:return
    G.zsave["intro_step"]=step;G.write_save();main_ref.to_main_menu()
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:Back.request(get_tree());get_viewport().set_input_as_handled()
func _exit_tree() -> void:Back.remove(self)
func _finish_prologue() -> void:
    if finished: return
    finished=true
    G.zsave["seen_prologue"]=true;G.write_save()
    var tw:=create_tween();tw.tween_property(root,"modulate:a",0.0,0.45)
    tw.tween_callback(func():
        if main_ref!=null: main_ref.prologue_done())
