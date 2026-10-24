extends Control
const V=preload("res://scripts/ui/visual_theme.gd")
var b
var pending: Array=[]
var active: Dictionary={}
var remaining:=0.0
var panel: PanelContainer
var speaker: Label
var body: Label
var badge: TextureRect
var fade:=0.0
var duplicate_clock:=0.0
var history: Dictionary={}
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);panel.add_child(row)
    badge=TextureRect.new();badge.custom_minimum_size=Vector2(19,19);badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;badge.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;badge.size_flags_vertical=SIZE_SHRINK_BEGIN;row.add_child(badge)
    var box:=VBoxContainer.new();box.size_flags_horizontal=SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",3);row.add_child(box)
    speaker=ZUI.label("",10,V.MUTED);box.add_child(speaker)
    body=ZUI.label("",16,V.TEXT);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(body)
    panel.hide()
func classify(text: String,tag: String="") -> Dictionary:
    var s:=text.to_lower()
    var entry: Dictionary={"text":text,"tag":tag if tag!="" else "СИСТЕМА","priority":0,"icon":"check","color":V.TEXT}
    if s.contains("укус") or s.contains("кровотеч") or s.contains("перелом") or s.contains("поврежден") or s.contains("повреждён") or s.contains("травм") or s.contains("критич") or tag=="ШТАММ":
        entry.merge({"tag":"БИОМЕТРИЯ / ОПАСНОСТЬ","priority":3,"icon":"drop","color":V.ALERT},true)
    elif s.contains("примен") or s.contains("бинт") or s.contains("медикамент") or s.contains("антибиот") or s.contains("организм"):
        entry.merge({"tag":"МЕДИЦИНСКИЙ КОНТУР","priority":1,"icon":"bandage","color":V.ICE},true)
    elif s.contains("запрещ") or s.contains("блокир") or s.contains("карантин") or s.contains("недостат") or s.contains("не хватает") or s.contains("пуст") or s.contains("неисправ"):
        entry.merge({"tag":"ПРЕДУПРЕЖДЕНИЕ","priority":2,"icon":"eye","color":V.WARN},true)
    elif s.contains("задач") or s.contains("данн") or s.contains("доступ") or tag=="СИСТЕМА":
        entry.merge({"tag":"КОНТУР / ИНФОРМАЦИЯ","priority":1,"icon":"pda","color":V.ICE},true)
    return entry
func push(text: String,tag: String="") -> void:
    if text.begins_with("ГРАФИКА:"): return
    if duplicate_clock-float(history.get(text,-100.0))<2.5: return
    history[text]=duplicate_clock
    var entry:=classify(text,tag)
    if not active.is_empty() and int(entry.priority)>int(active.priority):
        # A critical injury interrupts a pickup; unfinished information returns to the queue.
        if remaining>1.0: active["resume"]=remaining;pending.append(active)
        active={};remaining=0
    pending.append(entry)
    pending.sort_custom(func(a,c): return int(a.priority)>int(c.priority))
    if pending.size()>12: pending.pop_back()
func _process(delta: float) -> void:
    duplicate_clock+=delta
    if b==null or panel==null: return
    if history.size()>100:
        for key in history.keys():
            if duplicate_clock-float(history[key])>10: history.erase(key)
    var vp:=get_viewport_rect().size
    var width:=minf(430.0,vp.x*0.37)
    panel.custom_minimum_size.x=width;panel.size=Vector2(width,0)
    if remaining<=0 and not pending.is_empty():
        active=pending.pop_front();speaker.text=active.tag;body.text=active.text
        speaker.add_theme_color_override("font_color",active.color);badge.texture=ZUI.icon(active.icon);badge.modulate=active.color
        var style:=V.panel(Color(0.025,0.042,0.055,0.93),Color.TRANSPARENT,10)
        style.set_border_width_all(0);style.border_width_left=2;style.border_color=active.color
        panel.add_theme_stylebox_override("panel",style)
        remaining=float(active.get("resume",clampf(body.text.length()*0.042,3.0,8.0)));fade=0
    if not b.paused: remaining=maxf(0,remaining-delta)
    fade=move_toward(fade,1.0 if remaining>0.35 else 0.0,delta*5)
    panel.position=Vector2((vp.x-width)*0.5,20+(1.0-fade)*-8)
    panel.visible=fade>0.01 and not b.paused;panel.modulate.a=fade
