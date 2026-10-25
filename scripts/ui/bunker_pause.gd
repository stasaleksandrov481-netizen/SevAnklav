extends "res://scripts/ui/viewport_control.gd"
const V=preload("res://scripts/ui/visual_theme.gd")
var b
var panel: PanelContainer
var content: VBoxContainer
var closing:=false
var clock:=0.0
var signal_view: Control
var confirmation:=""
func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS;super._ready();mouse_filter=MOUSE_FILTER_STOP
    var shade:=ColorRect.new();shade.set_anchors_preset(PRESET_FULL_RECT);add_child(shade)
    var shader:=Shader.new();shader.code="shader_type canvas_item; uniform sampler2D screen_tex: hint_screen_texture, filter_linear; void fragment(){vec3 c=texture(screen_tex,SCREEN_UV).rgb;float g=dot(c,vec3(.2126,.7152,.0722));COLOR=vec4(mix(c,vec3(g),.55)*.68,1.0);}"
    var material:=ShaderMaterial.new();material.shader=shader;shade.material=material
    panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",V.panel(Color(.055,.08,.10,.94),Color(.42,.58,.64,.45),24));add_child(panel)
    content=VBoxContainer.new();content.add_theme_constant_override("separation",12);panel.add_child(content)
    content.add_child(ZUI.label("V–17 / ЛОКАЛЬНАЯ НЕЙРОСВЯЗЬ",12,V.ICE))
    content.add_child(ZUI.label("Замерший сигнал",28,V.TEXT))
    content.add_child(ZUI.label("Симуляция остановлена. Канал удерживается.",13,V.MUTED))
    signal_view=SignalTrace.new();signal_view.custom_minimum_size=Vector2(0,80);content.add_child(signal_view)
    for entry in [["Продолжить",resume],["Настройки",settings],["Загрузить контрольную точку",func(): confirm("checkpoint")],["Главное меню",func(): confirm("menu")]]:
        var button:=V.button(entry[0]);button.custom_minimum_size.y=48;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.pressed.connect(entry[1]);content.add_child(button)
    _fit_viewport();modulate.a=0;create_tween().tween_property(self,"modulate:a",1,.16)
func _fit_viewport() -> void:
    super._fit_viewport()
    if panel!=null:
        panel.size=Vector2(470,minf(530,size.y-40));panel.position=Vector2(clampf(size.x*.62,24,size.x-panel.size.x-24),(size.y-panel.size.y)*.5)
func settings() -> void:
    if confirmation!="": return
    var screen:=preload("res://scripts/ui/v10/settings.gd").new();screen.b=b;b.ui_layer.add_child(screen);b._freeze_ui10(screen)
func confirm(action: String) -> void:
    if confirmation!="": return
    confirmation=action
    var screen:=preload("res://scripts/ui/v10/field_panel.gd").new();screen.caption="ПОДТВЕРЖДЕНИЕ";screen.extent=Vector2(580,330);b.ui_layer.add_child(screen);b._freeze_ui10(screen)
    var text: String="Прогресс после последней контрольной точки будет заменён её состоянием." if action=="checkpoint" else "Выйти в главное меню? Текущее состояние будет сохранено."
    screen.column.add_child(ZUI.wrap_label(text,18,V.TEXT,0))
    var accept:=V.button("ЗАГРУЗИТЬ" if action=="checkpoint" else "СОХРАНИТЬ И ВЫЙТИ");accept.custom_minimum_size.y=50;screen.column.add_child(accept)
    screen.tree_exiting.connect(func(): confirmation="")
    accept.pressed.connect(func():
        accept.disabled=true
        if action=="checkpoint": b._reload_checkpoint10()
        else: b._save_checkpoint();get_tree().paused=false;b.main_ref.to_main_menu())
func resume() -> void:
    if closing or confirmation!="": return
    closing=true
    signal_view.running=true
    var tw:=create_tween();tw.tween_property(self,"modulate:a",0,.16);tw.tween_callback(queue_free)
func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        get_viewport().set_input_as_handled();resume()
class SignalTrace extends Control:
    var running:=false
    var phase:=0.0
    func _process(delta: float) -> void:
        phase+=delta
        if running or int(phase*8)!=int((phase-delta)*8): queue_redraw()
    func _draw() -> void:
        var points:=PackedVector2Array()
        for i in range(100):
            var x:=float(i)/99.0*size.x
            var p:=sin(float(i)*.10)*1.5
            if i%37==17: p=-12
            if i%37==18: p=22
            if i%37==19: p=-5
            if running: p+=sin(float(i)*.25+phase*9)*2
            points.append(Vector2(x,38+p))
        draw_line(Vector2(0,38),Vector2(size.x,38),Color(.2,.36,.43,.4),1)
        draw_polyline(points,Color(.6,.79,.84,.85),1.5,true)
        draw_circle(Vector2(size.x-2,38+sin(phase)*1.5),2,Color(.66,.84,.87,.65+.15*sin(phase)))
        draw_string(ThemeDB.fallback_font,Vector2(0,74),"СИГНАЛ ВОССТАНАВЛИВАЕТСЯ" if running else "ПОТОК ЗАФИКСИРОВАН",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(.49,.66,.74))
