extends "res://scripts/ui/round_control.gd"
var btl
var held:=false
var progress:=0.0
var captured: Dictionary={}
var signature:=""
var committed:=false
func _ready() -> void:
    large=true;symbol="hand"
    custom_minimum_size=Vector2(112,112)
    super._ready()
    button_down.connect(func():
        if disabled: return
        captured=btl.cur_interact.duplicate()
        signature=_signature(captured)
        held=true;progress=0;committed=false)
    button_up.connect(func():
        if held and not committed and not disabled and signature==_signature(btl.cur_interact) and float(captured.get("hold",0))<=0:
            committed=true;btl._do_interact(captured)
        held=false;progress=0)
func _signature(info: Dictionary) -> String:
    return str(info.get("kind",""))+str(info.get("action",""))+str(info.get("door_id",""))+str(info.get("pos",Vector2.INF))
func _process(delta: float) -> void:
    visual_scale10=float(G.zsave.get("bunker_visual",{}).get("control_scale10",1))
    custom_minimum_size=Vector2(112,112)*visual_scale10
    size=custom_minimum_size
    position=btl._stick_base("r")+Vector2(-220,-40)*visual_scale10
    var info: Dictionary=btl.cur_interact
    disabled=info.is_empty() or btl.paused
    caption=_caption(info)
    symbol="hand" if info.get("kind","") not in ["story_door","door"] else "door"
    tooltip_text=str(info.get("text","Действие"))
    if held and (disabled or signature!=_signature(info)): held=false;progress=0
    if held:
        var duration:=float(captured.get("hold",0))
        if duration>0:
            progress+=delta
            if progress>=duration:
                committed=true;held=false;progress=0;btl._do_interact(captured)
    super._process(delta)
func _caption(info: Dictionary) -> String:
    if info.is_empty(): return "ДЕЙСТВИЕ"
    var kind:=str(info.get("kind",""))
    if kind=="evidence10":
        return {"cache10":"КОДОВЫЙ\nЗАМОК","restore10":"ВОССТАНОВИТЬ\nДАННЫЕ","camera10":"АРХИВ\nКАМЕР","monitor10":"ОСМОТРЕТЬ\nСЛЕДЫ","tray10":"ОСМОТРЕТЬ\nСЛЕДЫ","override10":"ОСМОТРЕТЬ\nСЛЕДЫ"}.get(str(info.get("action","")),"ПРОЧИТАТЬ\nЗАПИСЬ")
    if kind=="corpse": return "ОБЫСКАТЬ\nТЕЛО"
    if kind=="cabinet": return "ОБЫСКАТЬ\nШКАФ"
    if kind=="loot_crate": return "ОБЫСКАТЬ\nКОНТЕЙНЕР"
    if kind in ["story_door","door"]: return "ГЕРМОДВЕРЬ\nУДЕРЖИВАТЬ"
    if kind=="story" and str(info.get("action","")).contains("terminal"): return "ОТКРЫТЬ\nТЕРМИНАЛ"
    var raw:=str(info.get("text",btl._bubble_caption(kind,false))).replace(" / ","\n")
    return raw.left(32).to_upper()
func _draw() -> void:
    super._draw()
    if held and float(captured.get("hold",0))>0:
        var fraction:=clampf(progress/float(captured["hold"]),0,1)
        draw_arc(_control_center7(),_control_radius7()+3,-PI/2,-PI/2+fraction*TAU,48,Color(0.63,0.82,0.86,0.9),2.5,true)
