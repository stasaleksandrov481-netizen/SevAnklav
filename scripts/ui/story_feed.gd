extends Control
var b
var messages: Array=[]
var pending: Array=[]
var remaining:=0.0
var panel: PanelContainer
var speaker: Label
var body: Label
var fade:=0.0
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel",ZUI.panel_style(Color(0.018,0.032,0.043,0.95),Color(0.20,0.34,0.41,0.75),16))
    add_child(panel)
    var box:=VBoxContainer.new();box.add_theme_constant_override("separation",7);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(box)
    speaker=ZUI.label("",12,Color(0.48,0.67,0.74));box.add_child(speaker)
    body=ZUI.label("",18,Color(0.85,0.9,0.91));body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(body)
    panel.hide()
func push(text: String, tag: String="") -> void:
    if text.begins_with("Новая задача:") or text.begins_with("Задача выполнена:") or text.begins_with("ГРАФИКА:"): return
    for entry in pending:
        if entry[0]==text: return
    pending.append([text,tag])
    while pending.size()>5: pending.remove_at(0)
func _process(delta: float) -> void:
    if b==null or panel==null: return
    var vp:=get_viewport_rect().size
    var width:=minf(620,maxf(390,vp.x-780))
    panel.position=Vector2((vp.x-width)*0.5,60)
    panel.custom_minimum_size.x=width
    panel.size.x=width
    if remaining<=0 and not pending.is_empty():
        var msg: Array=pending.pop_front()
        speaker.text="ВОЛКОВ" if msg[1]=="ВОЛКОВ" else (str(msg[1]) if msg[1]!="" else "НАБЛЮДЕНИЕ")
        body.text=msg[0]
        remaining=clampf(body.text.length()*0.046,4.8,10.0)
        fade=0.0
    if not b.paused: remaining=maxf(0,remaining-delta)
    fade=move_toward(fade,1.0 if remaining>0.35 else 0.0,delta*4)
    panel.visible=fade>0.01 and not b.paused
    panel.modulate.a=fade
