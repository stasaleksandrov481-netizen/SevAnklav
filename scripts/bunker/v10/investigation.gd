extends RefCounted
const Data=preload("res://scripts/bunker/v10/archive_data.gd")
const Furnish=preload("res://scripts/bunker/v10/furnishing.gd")
var b
var state: Dictionary={}
var timer:=0.0
const FINDS=[
 ["med_chart",Vector2(665,701)],["levin_early",Vector2(298,388)],["somova_personal",Vector2(550,700)],
 ["guard_shift",Vector2(1740,532)],["pay_message",Vector2(850,996)],["staff_card",Vector2(925,940)],
 ["stable_report",Vector2(1630,1295)],["maintenance",Vector2(700,1650)],["security_last",Vector2(875,2380)],
 ["override_order",Vector2(2460,997)],["levin_last",Vector2(2640,783)],["archive_desk",Vector2(2550,1650)],
 ["cargo_note",Vector2(2620,2195)]
]
func ensure() -> void:
    var saved=G.zsave.get("investigation10",{})
    state=saved if saved is Dictionary else {}
    for key in ["found","read","inspected","events","known_rooms"]:
        if not (state.get(key) is Array): state[key]=[]
    G.zsave["investigation10"]=state
func build() -> void:
    ensure();Furnish.build(b)
    for find in FINDS: marker(find[0],find[1],"paper")
    marker("carrier",Vector2(820,1448),"carrier")
    marker("restore10",Vector2(995,1365),"access")
    marker("camera10",Vector2(1620,455),"security")
    marker("cache10",Vector2(955,1085),"locker")
    marker("monitor10",Vector2(1980,1390),"emergency")
    marker("tray10",Vector2(1780,1465),"research")
    marker("override10",Vector2(2220,1415),"access")
func marker(id: String,pos: Vector2,style: String) -> void:
    var sprite:=Sprite2D.new();sprite.texture=Furnish.texture(style);sprite.position=pos;sprite.z_index=5
    var width:=21.0 if style in ["paper","carrier"] else 36.0
    sprite.scale=Vector2.ONE*width/sprite.texture.get_width();sprite.rotation=-.10 if style=="paper" else 0.0;b.prop_layer.add_child(sprite)
    var prop: Dictionary={"kind":"evidence10","id10":id,"style10":style,"spr":sprite,"pos":pos,"solid":false,"radius":10,"half":Vector2.ONE*12}
    b.props.append(prop)
func nearest(point: Vector2) -> Dictionary:
    var closest: Dictionary={};var distance:=65.0
    for prop in b.props:
        if prop.kind!="evidence10": continue
        var d:=point.distance_to(prop.pos)
        if d<distance:
            distance=d;closest={"kind":"evidence10","action":prop.id10,"pos":prop.pos,"text":caption(prop.id10),"hold":.8 if prop.id10=="restore10" else 0.0}
    return closest
func caption(id: String) -> String:
    if Data.ENTRIES.has(id): return "ПРОЧИТАТЬ / "+str(Data.ENTRIES[id].title)
    return {"restore10":"СЕРВИСНАЯ СТОЙКА / НОСИТЕЛЬ","camera10":"АРХИВ КАМЕР / 3 КАДРА","cache10":"ШКАФ ДЕЖУРНОГО / КОД","monitor10":"ОСМОТРЕТЬ / РАЗБИТЫЙ МОНИТОР","tray10":"ОСМОТРЕТЬ / ОБРАЗЦЫ","override10":"ОСМОТРЕТЬ / РУЧНОЙ ПРИВОД"}.get(id,"ОСМОТРЕТЬ")
func discover(id: String,open_reader:=true) -> void:
    if not Data.ENTRIES.has(id): return
    var fresh: bool=not state.found.has(id)
    if fresh:
        state.found.append(id);b._toast("Новая запись: "+str(Data.ENTRIES[id].title))
        if id=="carrier": state["carrier"]=true
    if open_reader:
        mark_read(id);b._show_document10(Data.ENTRIES[id])
    b._save_checkpoint()
func mark_read(id: String) -> void:
    if not state.read.has(id): state.read.append(id)
func unread() -> int:
    var count:=0
    for id in state.found:
        if not state.read.has(id): count+=1
    return count
func entries() -> Array:
    var result: Array=[]
    for id in state.found:
        if Data.ENTRIES.has(id):
            var entry: Dictionary=Data.ENTRIES[id].duplicate();entry["id"]=id;entry["new"]=not state.read.has(id);result.append(entry)
    for index in range(b.notes.size()):
        var note: Dictionary=b.notes[index]
        var title:=str(note.get("title",""));var category:=1
        if title.contains("ПОСТ") or title.contains("НАБЛЮДЕНИЯ"): category=4
        elif title.contains("КАРАНТИН") or title.contains("КОНТУР"): category=3
        result.append({"id":"legacy:"+str(index),"category":category,"title":title,"body":note.get("body",""),"author":"Система «Заря» · локальная копия","date":"Сохранено Волковым","new":false})
    return result
func act(id: String) -> void:
    if Data.ENTRIES.has(id): discover(id);return
    match id:
        "camera10":
            if not b.records.has("cameras"): b._toast("Сначала подключитесь к посту наблюдения.");return
            discover("camera_17")
        "restore10":
            if not state.get("carrier",false): b._toast("Нужен внешний носитель. На ремонтном столе есть инженерная запись.");return
            if not b.records.has("power"): b._toast("Чтение прервано: сначала восстановите резервный контур.");return
            state["recovered"]=true;discover("raw_signal")
        "cache10":
            if state.get("cache_open",false): discover("cache");return
            b._open_keypad10("ШКАФ ДЕЖУРНОГО",func():
                if state.get("cache_open",false): return
                state["cache_open"]=true;b._receive_item("band",1);b._receive_item("food",2);discover("cache"))
        "monitor10","tray10","override10": inspect(id)
func inspect(id: String) -> void:
    if not state.inspected.has(id): state.inspected.append(id)
    var copy: Array={"monitor10":["Разбитый монитор","Стекло продавлено снаружи, возле клавиши аварийной остановки. На уцелевшей части экрана всё ещё горит «Норма»."],"tray10":["Оставленные образцы","Пробирки закрыты и подписаны. Лоток бросили в середине процедуры, не после её завершения."],"override10":["Ручной привод","На крышке свежие зарубки инструмента. Кто-то пытался снять блокировку, пока электрический привод уже не принимал команды."]}[id]
    b._show_document10({"title":copy[0],"body":copy[1],"author":"Волков · осмотр","date":"Лаборатория / место происшествия","category":-1})
    if state.inspected.size()==3 and not state.found.has("incident"):
        discover("incident",false);b._toast("Три следа сопоставлены. Вывод сохранён в КПК.")
    b._save_checkpoint()
func tick(delta: float) -> void:
    timer-=delta
    if timer>0: return
    timer=.25
    var point: Vector2=b.player.spr.position
    var floors: Array=b.Layout4.FLOOR
    for i in range(floors.size()):
        if floors[i][0].has_point(point) and not state.known_rooms.has(i): state.known_rooms.append(i)
    if b.records.has("cameras"): state["map_ready"]=true
    if Rect2(2140,680,180,420).has_point(point) and not state.events.has("shutter"):
        state.events.append("shutter");state["flicker"]=0.0
        b._toast("Холодный контур погас на мгновение. Резервная линия восстановлена.")
        b._save_checkpoint()
    if state.has("flicker"): state.flicker=float(state.flicker)+.25
    if Rect2(650,850,360,300).has_point(point): b.level_label.text="М–02 / КОМНАТА ОТДЫХА"
    elif Rect2(2380,640,380,420).has_point(point): b.level_label.text="Н–12 / КАБИНЕТ ИССЛЕДОВАТЕЛЯ"
    elif b.current_room>=0 and b.current_room<b.ROOM_NAMES.size(): b.level_label.text=b.ROOM_NAMES[b.current_room]
func snapshot() -> Dictionary: return state.duplicate(true)
