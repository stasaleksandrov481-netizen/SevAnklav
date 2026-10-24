extends "res://scripts/battle_z.gd"
const PropGeometry7=preload("res://scripts/bunker/prop_geometry.gd")
const Layout4 = preload("res://scripts/bunker/bunker_layout.gd")

# Location 1 owns its story state. Combat, body injuries, inventory and mobile sticks
# remain inherited from battle_z. Nothing in the war campaign uses this class.
var records: Dictionary = {}
var notes: Array = []
var current_room := -1
var safe_figure: Sprite2D
var starting := true
var ending := false
var shutter: ColorRect
var level_label: Label
var lamp_clock := 0.0
var gate_progress := 0.0
var lower_tween: Tween
var story_rooms := [Rect2(40,40,1140,740),Rect2(1220,40,1140,740),Rect2(1220,820,1140,760),Rect2(40,820,1140,760),Rect2(40,1620,1140,740),Rect2(1220,1620,1140,740)]
const ROOM_NAMES := ["01 / МЕДИЦИНСКИЙ БЛОК", "02 / СЛУЖЕБНЫЙ КОРИДОР", "03 / НАУЧНЫЙ СЕКТОР", "04 / РЕЗЕРВНОЕ ПИТАНИЕ", "05 / КАРАНТИН", "06 / ГРУЗОВОЙ ШЛЮЗ"]
const ART := {
    "z_oxygen_rack":["oxygen_rack",94.0],"z_sink":["sink",110.0],"z_sample_rack":["sample_rack",85.0],"z_first_aid":["first_aid",58.0],"z_cable_spool":["cable_spool",68.0],"z_tool_tray":["tool_tray",72.0],"z_camera_unit":["camera_unit",48.0],
    "z_capsule":["capsule",215.0],"z_terminal":["terminal",155.0],
    "z_medtable":["scanner_bed",170.0],"z_gurney":["trolley",85.0],
    "z_cabinet":["cabinet",118.0],"z_shelf":["cabinet",160.0],
    "z_server":["server",108.0],"z_reactor":["generator",235.0],
    "z_crate_z":["crate",82.0],"z_vent":["ventplant",90.0],
    "z_labdesk":["labdesk",180.0],"z_centrifuge":["centrifuge",95.0],
    "z_ventplant":["ventplant",155.0],"z_chair":["chair",55.0],
    "z_fallen_chair":["fallen_chair",60.0],"z_tools":["tools",55.0],
    "z_conduit":["conduit",115.0],"z_scanner":["access",54.0],
    "z_stairs":["stairs",155.0],"z_airlock":["airlock",230.0],"z_barrel":["barrel",55.0]
}
var environment4 = null
var recoil4 := 0.0
var shot_heat4 := 0.0
var dry_latched4 := false
var directional4: Array = []
var direction4 := 1
var aim_rig4: Node2D
var awareness5
var figure_rig5: Node2D
var action5: Button
var smooth_aim5 := PI/2
var view_timer5 := 0.0
var restoring5 := false
var old_direction5 := 1
var turn5 := 1.0
var player_blend5: ShaderMaterial
var player_rig6: Node2D
var story_feed6: Control
var flash_button6: Button
var inventory7=null
var inventory_revision7:=0
var loadout7=preload("res://scripts/bunker/loadout.gd").new()
var hand_visual7: Node2D
var atlas_regions6: Dictionary={}


func map_size_for() -> Vector2:
    return Vector2(3080,2840)

func _mk_spr(tex: String, pos: Vector2, scl := 1.42, z := 5, mod := Color(1,1,1)) -> Sprite2D:
    var s := super._mk_spr(tex,pos,scl,z,mod)
    if ART.has(tex):
        var a: Array = ART[tex]
        s.texture = _art_texture4(str(a[0]))
        var k: float = float(a[1]) / maxf(s.texture.get_width(),s.texture.get_height()) * scl / 1.42
        s.scale = Vector2(k,k)
    return s

func _room_rect_at(p: Vector2) -> Rect2:
    for r in story_rooms:
        if r.grow(20).has_point(p): return r
    return Rect2(Vector2.ZERO,map_size)

func _build_bunker() -> void:
    Layout4.build(self)
    for decoration in [["z_oxygen_rack",Vector2(165,530)],["z_sink",Vector2(605,210)],["z_first_aid",Vector2(845,300)],["z_camera_unit",Vector2(840,690)],["z_sample_rack",Vector2(1575,1190)],["z_sample_rack",Vector2(1550,1650)],["z_oxygen_rack",Vector2(1390,1640)],["z_camera_unit",Vector2(2265,1350)],["z_tool_tray",Vector2(700,1770)],["z_cable_spool",Vector2(180,1510)],["z_cable_spool",Vector2(940,1640)],["z_first_aid",Vector2(1048,1340)],["z_camera_unit",Vector2(1190,2500)],["z_oxygen_rack",Vector2(175,2430)],["z_cable_spool",Vector2(2610,2680)]]:
        _prop(decoration[0],decoration[1],14.0,"equipment_detail",1.42,false)
    for detail in [["z_cabinet",Vector2(820,210),23.0,"wall_storage"],["z_server",Vector2(1410,930),24.0,"wall_server"],["z_sink",Vector2(1910,1690),15.0,"equipment_detail"],["z_tool_tray",Vector2(620,1760),12.0,"equipment_detail"],["z_camera_unit",Vector2(1180,430),10.0,"equipment_detail"],["z_first_aid",Vector2(1820,2400),12.0,"equipment_detail"],["z_oxygen_rack",Vector2(290,2300),17.0,"equipment_detail"]]:
        _prop(detail[0],detail[1],detail[2],detail[3],1.0,false)
    zp = {"hypo":0.0,"seen":{},"gas_fixed":true,"gen_on":false,"iso_active":false,"iso_off":false,"escape_on":false}
    zp["flash_off"]=bool(G.zsave.get("flash_off7",false))
    zp_amb = ZAmbience.new()
    add_child(zp_amb)
    zp_amb.set_mode("bunker",3.0)
    _add_objective("capsule","Дождаться разгерметизации капсулы V-17",0)
    _add_objective("terminal","Осмотреть терминал персонала",1)
    _add_objective("corridor","Открыть служебную дверь медицинского блока",2)
    _add_objective("gear","Найти КПК, фонарь и оружие у поста наблюдения",3)
    _add_objective("journal_a","Найти первый фрагмент журнала №12",4)
    _add_objective("journal_b","Найти второй фрагмент журнала №12",4)
    _add_objective("fuse","Найти резервный предохранитель в техсекторе",5)
    _add_objective("gen18","Установить предохранитель и переключить питание",6)
    _add_objective("lower","Спуститься через служебный переход",7)
    _add_objective("iso","Снять блокировку карантинного перехода",8)
    _add_objective("frost","Прочитать аварийный архив наблюдения",9)
    _add_objective("hydro","Грузовой шлюз: насос → привод → питание",10)
    _add_objective("evac","Дойти до порога внешнего шлюза",11)
    _occluder_for_walls()

func _ready() -> void:
    loadout7.b=self
    loadout7.ensure()
    set_meta("bunker_v6",true)
    set_meta("bunker_v5",true)
    super._ready()
    var previous_floor := floor_node
    floor_node = preload("res://scenes/locations/Bunker_Architecture.tscn").instantiate()
    add_child(floor_node)
    floor_node.configure(self)
    environment4 = floor_node
    var maintenance:=preload("res://scripts/bunker/maintenance_detail.gd").new()
    maintenance.b=self;maintenance.z_index=1;add_child(maintenance)
    previous_floor.queue_free()
    canvas_mod.color = Color(0.25,0.30,0.35)
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = int(map_size.x)
    camera.limit_bottom = int(map_size.y)
    q_lock = OS.get_cmdline_user_args().has("--quality-lock")
    player["light"].texture = preload("res://assets/bunker/v8/flashlight.svg")
    player["light"].texture_scale = 0.92
    player["light"].energy = 0.70
    player["light"].color = Color(1.0,0.93,0.80)
    player["light"].enabled = false
    player["halo"].modulate.a=0.0
    player["light"].offset = Vector2(110,0)
    player["light"].shadow_enabled = true
    player["light"].shadow_filter = Light2D.SHADOW_FILTER_PCF13
    player["light"].shadow_filter_smooth = 4.0
    player["light"].range_z_min = -20
    player["light"].range_z_max = 30
    awareness5 = preload("res://scripts/bunker/awareness.gd").new()
    awareness5.b = self
    add_child(awareness5)
    figure_rig5 = preload("res://scripts/bunker/actor_rig.gd").new()
    figure_rig5.position = safe_figure.position
    figure_rig5.heading = PI/2
    figure_rig5.z_index = 8
    unit_layer.add_child(figure_rig5)
    obj_panel.position.y = 44
    if tut != null:
        tut.queue_free()
        tut = null
    var h := CanvasLayer.new()
    h.layer = 12
    add_child(h)
    level_label = ZUI.label(ROOM_NAMES[0],13,ZUI.ICE)
    level_label.position = Vector2(28,12)
    level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.add_child(level_label)

    paused = true
    var layer := CanvasLayer.new()
    layer.layer = 45
    add_child(layer)
    shutter = ColorRect.new()
    shutter.color = Color(0.01,0.02,0.025,1.0)
    shutter.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(shutter)
    if _restore_checkpoint():
        starting = false
        paused = false
        in_capsule = false
        player["spr"].visible = true
        shutter.color.a = 0.0
        shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _apply_capsule_ui()
        return
    var tw := create_tween()
    tw.tween_property(shutter,"color:a",0.0,2.8)
    await tw.finished
    G.play_sfx("z_hiss",-13.0)
    var lid:=preload("res://scripts/bunker/capsule_lid.gd").new()
    lid.position=Vector2(395,345);lid.z_index=14;prop_layer.add_child(lid)
    player["spr"].position=Vector2(395,425)
    player["spr"].visible=true;player["spr"].modulate.a=1.0
    player_rig6.visible=true;player_rig6.exit_pose8(0,0)
    await _exit_phase8(0,0.85)
    G.play_sfx("z_relay",-17.0)
    var opening:=lid.create_tween()
    opening.tween_interval(0.35)
    opening.tween_property(lid,"rotation",-1.08,1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    opening.parallel().tween_property(lid,"position:x",346.0,1.15)
    await _exit_phase8(1,1.55)
    await _exit_phase8(2,1.2)
    await get_tree().create_timer(0.28).timeout
    await _exit_phase8(3,0.95)
    G.play_sfx("z_footstep",-18.0)
    await _exit_phase8(4,0.95)
    G.play_sfx("z_footstep",-17.0)
    var stand_origin: Vector2=player["spr"].position
    var stand:=create_tween()
    stand.tween_method(func(v: float):
        player["spr"].position=stand_origin+Vector2(40,42)*smoothstep(0,1,v)
        player_rig6.exit_pose8(5,v),0.0,1.0,1.15)
    await stand.finished
    player_rig6.finish_exit8()
    # Two discrete weight-bearing steps, with a planted-foot pause between them.
    for step in range(2):
        var step_start: Vector2=player["spr"].position
        var walking:=create_tween()
        walking.tween_method(func(v: float):
            var lift: float=sin(v*PI)
            player["spr"].position=step_start+Vector2(15,19)*smoothstep(0.05,0.88,v)
            player_rig6.pose(PI/2,float(step)*PI+v*PI,Vector2(35,42),false,0.1)
            player_rig6.parts.torso.position.y-=lift*1.8,0.0,1.0,0.55)
        await walking.finished
        G.play_sfx("z_footstep",-18.0)
        await get_tree().create_timer(0.14).timeout
    in_capsule = false
    starting = false
    paused = false
    shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _apply_capsule_ui()
    _complete_objective("capsule")
    _log("Маркировка капсулы: V-17 / эксперимент №12.",ZUI.ICE,"НАБЛЮДЕНИЕ")
    _toast("Левый стик — движение. Осмотрите терминал у капсулы.")
    _save_checkpoint()

func _find_interact() -> Dictionary:
    if starting or ending: return {}
    var pp: Vector2 = player["spr"].position
    for pr in props:
        var k: String = pr["kind"]
        var distance: float=pp.distance_to(pr["pos"]) if k in ["door","exit_gate"] else PropGeometry7.distance_to(pr,pp)
        if distance>(120.0 if k in ["door","exit_gate"] else 75.0): continue
        if k == "door":
            var id: String = pr["door_id"]
            if not doors[id]["opened"]:
                return {"kind":"story_door","door_id":id,"text":"ГЕРМОДВЕРЬ / " + ("ОТКРЫТЬ" if _door_allowed(id) else "БЛОКИРОВКА"),"hold":0.7,"pos":pr["pos"]}
        var texts := {"cryo_terminal":"ТЕРМИНАЛ / ПЕРСОНАЛЬНОЕ ДОСЬЕ","cams_terminal":"ПОСТ НАБЛЮДЕНИЯ","exp12_video":"ЖУРНАЛ №12 / ФРАГМЕНТ 1","journal":"ЖУРНАЛ №12 / ФРАГМЕНТ 2","exp12_capsule":"ОСМОТРЕТЬ КАПСУЛУ","fuse_crate":"ВЗЯТЬ ПРЕДОХРАНИТЕЛЬ","gen_panel":"ВОССТАНОВИТЬ КОНТУР ДВЕРИ","generator":"РЕЗЕРВНЫЙ ГЕНЕРАТОР","stairs_transition":"СЛУЖЕБНЫЙ СПУСК","iso_panel":"ЛОКАЛЬНО СНЯТЬ БЛОКИРОВКУ","obs_terminal":"АВАРИЙНЫЙ АРХИВ / «СЕВЕР»","hydro":"1 / ЗАПУСТИТЬ НАСОС","hydro_lever":"2 / РАЗБЛОКИРОВАТЬ ПРИВОД","power_hold":"3 / УДЕРЖИВАТЬ ПИТАНИЕ","exit_gate":"ВНЕШНИЙ ШЛЮЗ"}
        if texts.has(k):
            if k == "fuse_crate" and records.has("fuse"): continue
            if k == "stairs_transition" and records.has("lower"): continue
            return {"kind":"story","action":k,"text":texts[k],"hold":1.2 if k in ["gen_panel","iso_panel","hydro","hydro_lever","power_hold"] else 0.5,"pos":pr["pos"]}
    var result := super._find_interact()
    if result.get("kind","") in ["stairs","airlock","scanner","scanner_no","capsule"]: return {}
    return result

func _door_allowed(id: String) -> bool:
    match id:
        "medical": return records.has("terminal")
        "science": return _obj_done("gear")
        "technical": return records.has("journal_a") and records.has("journal_b")
        "lower": return records.has("power") and records.has("lower")
        "cargo": return records.has("isolation") and records.has("archive")
    return true

func _do_interact(info: Dictionary) -> void:
    if info["kind"] == "story_door":
        var id: String = info["door_id"]
        if _door_allowed(id):
            _open_door(id)
            if id == "medical": _complete_objective("corridor")
        else:
            var reasons := {"medical":"Сначала проверьте терминал персонала.","science":"Сначала заберите снаряжение у поста наблюдения.","technical":"Допуск хранится в двух фрагментах журнала №12.","lower":"Восстановите питание и воспользуйтесь служебным спуском.","cargo":"Снимите блокировку на панели и проверьте архив наблюдения."}
            _toast(reasons[id])
        return
    if info["kind"] == "story":
        _story_action(str(info["action"]))
        _save_checkpoint()
        return
    if info["kind"] == "gear":
        _complete_objective("gear")
        G.zsave["ammo"]["pistol"] = 16
        G.zsave["weapons"] = ["pistol"]
        if not bool(G.zsave.get("equipment_ready7",false)): loadout7.defaults()
        loadout7.changed()
        G.z_give_item("band",2)
        G.z_give_item("mag_pistol",2)
        G.play_sfx("z_pickup",-10.0)
        _log("КПК подключён. Карта, задачи и найденные записи доступны в одном устройстве.",ZUI.ICE,"КПК")
        _toast("ПМ, два запасных магазина, фонарь и бинты получены. Правый стик — прицел и огонь; двойной тап — перезарядка.")
        return
    super._do_interact(info)

func _record(id: String, title: String, body: String) -> void:
    if records.has(id): records["terminal_seen:"+title]=true
    if not records.has(id):
        records[id] = true
        notes.append({"title":title,"body":body})
    zp_terminal_screen(title,ZUI.ICE,[{"text":body,"col":ZUI.TEXT,"delay":0.2}])
    _save_checkpoint()

func _story_action(action: String) -> void:
    var legacy_key: String={"cryo_terminal":"terminal","iso_panel":"isolation_note"}.get(action,"interaction:"+action)
    var first_visit: bool=not records.has("interaction:"+action) and not records.has(legacy_key)
    records["interaction:"+action]=true
    match action:
        "cryo_terminal":
            _record("terminal","V-17 / ПЕРСОНАЛЬНОЕ ДОСЬЕ","Пациент: А. Волков.\nЭксперимент №12.\nВосстановление сознания: подтверждено.\nПоследующая стабилизация: прервана.\n\nАварийный доступ: служебная дверь медицинского блока.")
            _complete_objective("terminal")
            if first_visit: _log("Волков… Это я? Что со мной сделали?",ZUI.TEXT,"ВОЛКОВ")
            if not records.has("symptom"):
                records["symptom"] = true
                _hit_vignette(0.12)
                player["st"]["stress"] = 12.0
        "cams_terminal":
            _record("cameras","ПОСТ НАБЛЮДЕНИЯ","Внутренняя изоляция нарушена.\nЧасть камер не отвечает.\nВ смотровой комнате — сотрудник. Его движения неестественны. Голосовой контакт отсутствует.\n\nЗащитное стекло удерживает перегородку. Пост охраны оставил оружие на соседнем столе.")
        "exp12_video":
            _record("journal_a","ЭКСПЕРИМЕНТ №12 / 1","V-17. До начала процедуры смерть пациента была зафиксирована.\nПолучен сознательный ответ. Возвращение жизненных функций подтверждено.\n\nРеакция V-17 не соответствует расчётной. Мы получили сознательный ответ, но показатели… [файл повреждён]")
            _complete_objective("journal_a")
            _experiment_access()
        "journal":
            _record("journal_b","ЭКСПЕРИМЕНТ №12 / 2","Последующая стабилизация прервана аварией. Последствия не установлены.\nПосле сбоя изоляции персонал перестал отвечать. Не открывайте переходы без подтверждения.\n\nВременный допуск в технический сектор восстановлен. Причина выбора пациента V-17: [данные недоступны].")
            _complete_objective("journal_b")
            _experiment_access()
        "exp12_capsule":
            _record("capsule_note","МАРКИРОВКА ОБОРУДОВАНИЯ","Та же серия капсул. Медицинские датчики ещё работают. Исследование продолжалось до самого сбоя; здесь не успели даже убрать инструменты.")
        "fuse_crate":
            records["fuse"] = true
            G.z_give_item("fuse",1)
            _complete_objective("fuse")
            _toast("Резервный предохранитель получен. Установите его в щит у генератора.")
            G.play_sfx("z_pickup",-9.0)
        "gen_panel":
            if not records.has("fuse"):
                _toast("Не хватает предохранителя. Проверьте ящик техсектора.")
                return
            if not records.has("power"):
                G.z_take_item("fuse",1)
                records["power"] = true
                zp["gen_on"] = true
                G.play_sfx("z_relay",-9.0)
                _complete_objective("gen18")
            _record("power_note","РЕЗЕРВНЫЙ КОНТУР","Предохранитель установлен. Питание переключено на служебный переход.\nОстальные отсеки остаются изолированы. Нижний уровень доступен через лестничный переход.")
        "generator":
            _toast("Генератор исправен. Цепь двери отключена — используйте распределительный щит.")
        "stairs_transition":
            if not records.has("power"):
                _toast("Сначала восстановите цепь питания двери.")
                return
            _descend()
        "iso_panel":
            if not records.has("lower"):
                _toast("Панель доступна после спуска на нижний уровень.")
                return
            records["isolation"] = true
            zp["iso_off"] = true
            _complete_objective("iso")
            _record("isolation_note","КАРАНТИН / ЛОКАЛЬНЫЙ ДОСТУП","Карантинный протокол активен. Подтверждение безопасности отсутствует.\nБлокировка введена автоматически после потери контроля над частью комплекса.\nАварийное снятие блокировки перехода: выполнено.")
            if first_visit: _log("Если всё было под контролем… почему они заперли здесь своих?",ZUI.TEXT,"ВОЛКОВ")
        "obs_terminal":
            _record("archive","АРХИВ НАБЛЮДЕНИЯ","Датчики зафиксировали нарушение изоляции. Сотрудники пытались закрыть переходы вручную.\n\nПротокол «Север»: распоряжение руководства в момент аварии. Назначение: [повреждено].\n\nЛичный фрагмент: «Алексей, ты обещал вернуться». Автор не определён.\n\nМаршрут аварийного выхода: грузовой шлюз.")
            _complete_objective("frost")
        "hydro":
            if not records.has("isolation") or not records.has("archive"):
                _toast("Необходимо завершить проверку карантинного сектора.")
                return
            if zp_gate_state == 0:
                zp_gate_state = 1
                G.play_sfx("z_hydro_loop",-13.0)
                _toast("Насос запущен. Разблокируйте привод у южной панели.")
        "hydro_lever":
            if zp_gate_state == 1:
                zp_gate_state = 2
                G.play_sfx("z_relay",-9.0)
                _toast("Привод разблокирован. Удерживайте питание у восточной панели.")
            else: _toast("Сначала запустите насос у входа в отсек.")
        "power_hold":
            if zp_gate_state == 2:
                zp_gate_state = 3
                gate_progress = 0.0
                _spawn_zombie("walk",Vector2(1860,2530))
                _spawn_zombie("sci",Vector2(2010,2470))
                _toast("Внешний шлюз. Аварийный доступ. Подтверждение безопасности отсутствует.")
            elif zp_gate_state < 2: _toast("Сначала запустите насос и разблокируйте привод.")
        "exit_gate":
            if zp_gate_state < 4:
                _toast("Шлюз закрыт. Насос → привод → питание.")
            else: _finish_location()

func _experiment_access() -> void:
    if records.has("journal_a") and records.has("journal_b"):
        _toast("Два фрагмента сопоставлены. Допуск технического сектора восстановлен.")
        _log("Я был мёртв… Они действительно вернули меня.",ZUI.TEXT,"ВОЛКОВ")

func _descend() -> void:
    if lower_tween != null and lower_tween.is_running(): return
    records["lower"] = true
    _open_door("lower")
    paused = true
    direct_vec = Vector2.ZERO
    var spr: Sprite2D = player["spr"]
    lower_tween = create_tween()
    lower_tween.tween_property(spr,"position",Vector2(560,1830),0.8)
    lower_tween.tween_property(spr,"position",Vector2(560,2180),3.4).set_trans(Tween.TRANS_SINE)
    lower_tween.tween_callback(func():
        paused = false
        _complete_objective("lower")
        _save_checkpoint()
        _toast("Нижний уровень. Карантинный сектор."))
    G.play_sfx("z_footstep",-12.0)

func _zpro_tick(delta: float) -> void:
    if starting or ending: return
    checkpoint_timer += delta
    if checkpoint_timer > 15.0:
        checkpoint_timer = 0.0
        _save_checkpoint()
    var p: Vector2 = player["spr"].position
    for i in range(story_rooms.size()):
        if story_rooms[i].has_point(p) and current_room != i:
            current_room = i
            if level_label != null: level_label.text = ROOM_NAMES[i]
            if i == 1 and not records.has("encounter"):
                records["encounter"] = true
                _log("Эй! Вы меня слышите?..",ZUI.TEXT,"ВОЛКОВ")
                _log("Фигура за стеклом резко дёргается к вам. Защитная перегородка закрыта.",ZUI.WARN,"НАБЛЮДЕНИЕ")
                G.play_sfx("z_glass_hit3",-15.0)
            if i == 2 and not records.has("science_seen"):
                records["science_seen"] = true
                _toast("Ищите два фрагмента журнала №12. При необходимости можно отступить к двери.")
    if safe_figure != null:
        safe_figure.rotation = 0
        if is_instance_valid(figure_rig5): figure_rig5.update_pose(PI/2,sin(time_alive*0.7),0.1,delta)
    if kills > 0 and not records.has("first_fight"):
        records["first_fight"] = true
        _log("Этого не может быть…",ZUI.TEXT,"ВОЛКОВ")
        _log("На мгновение дрожь исчезла. Реакция организма после процедуры не объяснена.",ZUI.ICE,"НАБЛЮДЕНИЕ")
    if zp_gate_state == 3:
        gate_progress += delta
        if gate_progress >= 7.0:
            zp_gate_state = 4
            _complete_objective("hydro")
            _toast("Материалы эксперимента №12 частично уцелели. Шлюз открыт.")
            for pr in props:
                if pr["kind"] == "exit_gate":
                    var tw := create_tween()
                    tw.tween_property(pr["spr"],"position",pr["pos"]+Vector2(0,-160),3.0)

func _check_bunker_corridor() -> void:
    pass

func _tick_extraction(_delta: float) -> void:
    pass

func _fire_player() -> void:
    if not _obj_done("gear") or starting or ending or not _has_weapon7(): return
    var wd: Dictionary = G.ZWEAPONS[player["weapon"]]
    if bool(wd.get("melee",false)):
        super._fire_player()
        return
    if player["reload_t"] > 0 or player["fire_cd"] > 0: return
    if int(player["mag"]) <= 0:
        if not dry_latched4:
            G.play_sfx("z_dry",-13)
            _toast("Магазин пуст. Перезарядите оружие.")
            dry_latched4 = true
        player["fire_cd"] = 0.25
        return
    dry_latched4 = false
    player["mag"] = int(player["mag"])-1
    player["fire_cd"] = maxf(float(wd["rof"]),0.26)
    var move_spread := clampf(player_velocity.length()/150.0,0.0,1.0)*0.065
    var injury_spread: float = (1.0-float(player["st"]["body"]["ra"]))*0.17
    var angle: float = player["aim"]+randf_range(-1,1)*(0.009+shot_heat4*0.035+move_spread+injury_spread)
    var origin: Vector2 = _weapon_origin7()
    var direction := Vector2.from_angle(angle)
    var distance: float = _ray_wall_dist(origin,direction,float(wd["rng"]))
    var target = null
    for z in zombies:
        if not z["alive"]: continue
        var rel: Vector2 = z["spr"].position-origin
        var projection := rel.dot(direction)
        if projection>0 and projection<distance and absf(rel.cross(direction))<float(z["radius"])+5:
            target = z;distance = projection
    var impact := origin+direction*distance
    if target != null:
        _damage_zombie(target,float(wd["dmg"])*randf_range(0.92,1.08),direction)
        blood_burst.append({"pos":impact,"t":0.20,"ang":angle})
    else:
        flash_fx.append({"pos":impact,"t":0.075})
        G.play_sfx("z_metal",-27,randf_range(1.1,1.4))
    # Brief muzzle plume instead of a permanent laser across the room.
    tracer_fx.append({"a":origin,"b":impact,"t":0.025})
    flash_fx.append({"pos":origin,"t":0.055})
    _eject_shell(origin,angle,false)
    if environment4 != null: environment4.muzzle_flash(origin)
    G.play_sfx(str(wd["sfx"]),-8,randf_range(0.98,1.03))
    if OS.has_feature("mobile") and bool(G.zsave.get("bunker_visual",{}).get("haptics",true)):
        Input.vibrate_handheld(28,0.25)
    recoil4 = 1.0
    shot_heat4 = minf(1.0,shot_heat4+0.28)
    shake_camera(0.10)
    _alert_zombies(origin,560)

func _finish_location() -> void:
    if ending: return
    ending = true
    paused = true
    _log("Вы вернули меня… Зачем?",ZUI.TEXT,"ВОЛКОВ")
    _complete_objective("evac")
    var tw := create_tween()
    tw.tween_property(shutter,"color",Color(0.68,0.8,0.87,0.95),3.0)
    tw.tween_interval(1.0)
    tw.tween_callback(func(): _win())

func _zpro_obj_pos() -> Vector2:
    var target := ""
    for o in objectives:
        if not o["done"]:
            target = str(o["id"])
            break
    var kinds := {"terminal":"cryo_terminal","gear":"gear_table","journal_a":"exp12_video","journal_b":"journal","fuse":"fuse_crate","gen18":"gen_panel","lower":"stairs_transition","iso":"iso_panel","frost":"obs_terminal","hydro":"hydro","evac":"exit_gate"}
    if target == "corridor": return Vector2(880,480)
    if target == "hydro":
        if zp_gate_state == 1: target = "hydro_lever"
        elif zp_gate_state == 2: target = "power_hold"
        else: target = "hydro"
    else: target = str(kinds.get(target,""))
    for pr in props:
        if pr["kind"] == target: return pr["pos"]
    return Vector2.INF

func _kpk_fill_diary(pg: VBoxContainer) -> void:
    pg.add_child(ZUI.label("АРХИВ V-17 / НАЙДЕННЫЕ ЗАПИСИ",18,ZUI.ICE))
    if notes.is_empty():
        pg.add_child(ZUI.wrap_label("Найденные документы будут сохранены здесь после чтения терминалов.",15,ZUI.MUTED,700))
    for note in notes:
        pg.add_child(ZUI.hdivider(1,ZUI.BORDER_SOFT))
        pg.add_child(ZUI.label(note["title"],17,ZUI.ICE))
        pg.add_child(ZUI.wrap_label(note["body"],15,ZUI.TEXT,700))

func _prop(tex: String, pos: Vector2, radius: float, kind := "", scl := 1.42, solid := true, z := 3) -> Dictionary:
    var pr := super._prop(tex,pos,radius,kind,scl,solid,z)
    if ART.has(tex):
        var a: Array = ["security",155.0] if kind=="cams_terminal" else ART[tex]
        var s: Sprite2D = pr["spr"]
        s.texture = _art_texture4(str(a[0]))
        var k: float = float(a[1]) / maxf(s.texture.get_width(),s.texture.get_height()) * scl / 1.42
        s.scale = Vector2(k,k)
        for child in s.get_children(): child.queue_free()
        pr["half"] = s.texture.get_size()*s.scale*0.43
        # Shadows use the replacement texture footprint.
        _add_shadow(s,0.9,0.65,0.22)
    var replacement: String=""
    var width:=150.0
    if kind=="gear_table": replacement="security_rack";width=140.0
    elif kind=="cryo_terminal": replacement=""
    elif kind=="labdesk": replacement="lab_bench";width=178.0
    elif kind=="medtable" and pos.y>2200:
        replacement="medical_station";width=138.0
    if replacement!="":
        if atlas_regions6.is_empty(): atlas_regions6=preload("res://scripts/bunker/v6_assets.gd").REGIONS
        var full: Texture2D=preload("res://scripts/bunker/v6_assets.gd").TEXTURES[replacement]
        var uv: Array=atlas_regions6[replacement]
        var cropped_tex:=AtlasTexture.new();cropped_tex.atlas=full
        cropped_tex.region=Rect2(Vector2(uv[0],uv[1])*full.get_size(),Vector2(uv[2],uv[3])*full.get_size())
        var spr: Sprite2D=pr["spr"]
        spr.texture=cropped_tex;spr.scale=Vector2.ONE*width/cropped_tex.get_width()
        pr["half"]=cropped_tex.get_size()*spr.scale*0.46
        if kind=="gear_table": pr["radius"]=16.0
        for c in spr.get_children(): c.queue_free()
        _add_shadow(spr,0.93,0.60,0.24)
    if tex in ["z_oxygen_rack","z_cable_spool"] or kind=="seat": pr["solid"]=true
    if tex=="z_first_aid":
        pr["spr"].z_index=15
        pr["spr"].rotation=PI/2
        pr["spr"].scale*=0.78
    PropGeometry7.build(pr)
    return pr

func _bake_light_pool_textures() -> void:
    # The old room-wide additive fill washed the materials out. Use local lights.
    light_pools.clear()

func _glow(pos: Vector2, scl: float, col: Color, a: float) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = _light_tex()
    s.position = pos
    s.scale = Vector2(scl,scl)*0.65
    s.modulate = Color(col.r,col.g,col.b,a*0.35)
    s.z_index = 11
    var mat := ShaderMaterial.new()
    var shader := Shader.new()
    shader.code = "shader_type canvas_item; render_mode blend_add; varying vec4 tint; varying vec2 wpos; uniform vec4 bounds; void vertex(){ tint=COLOR; wpos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; } void fragment(){ vec2 lo=bounds.xy; vec2 hi=lo+bounds.zw; float inside=step(lo.x,wpos.x)*step(lo.y,wpos.y)*step(wpos.x,hi.x)*step(wpos.y,hi.y); COLOR=texture(TEXTURE,UV)*tint; COLOR.a*=inside; }"
    mat.shader = shader
    var r := _room_rect_at(pos)
    mat.set_shader_parameter("bounds",Vector4(r.position.x,r.position.y,r.size.x,r.size.y))
    s.material = mat
    fx_layer.add_child(s)
    return s

func _ambient_tick(delta: float) -> void:
    lamp_clock += delta
    # Lighting belongs to the actual local lamps, never a pulsing screen tint.
    pass

var emergency_spills: Array = []

func _door(id: String, pos: Vector2, vertical: bool, gap_w: float) -> Dictionary:
    var door := super._door(id,pos,vertical,gap_w)
    var s: Sprite2D = door["pr"]["spr"]
    s.texture = preload("res://assets/bunker/airlock.png")
    # The image's long axis is vertical. It lies along the partition.
    s.rotation = 0.0 if vertical else PI/2.0
    s.scale = Vector2(0.18,gap_w/s.texture.get_height())
    return door

func _spawn_player() -> void:
    super._spawn_player()
    add_child(player["light"])
    player["frames"]=[]
    player["bscale"]=0.30
    player["spr"].scale=Vector2(0.30,0.30)
    player["spr"].self_modulate.a=0.0
    for c in player["spr"].get_children(): c.queue_free()
    player_rig6=preload("res://scripts/bunker/volkov_rig.gd").new()
    player_rig6.b=self
    player_rig6.visible=false
    player_rig6.z_index=8
    unit_layer.add_child(player_rig6)
    aim_rig4 = WeaponRig.new()
    aim_rig4.b = self
    aim_rig4.z_index = 13
    unit_layer.add_child(aim_rig4)
    hand_visual7=preload("res://scripts/bunker/held_items.gd").new();hand_visual7.b=self;hand_visual7.z_index=13
    unit_layer.add_child(hand_visual7)


func _spawn_zombie(kind: String, pos: Vector2) -> void:
    super._spawn_zombie(kind,pos)
    var z: Dictionary = zombies[-1]
    var name := "scientist" if kind == "sci" else ("guard" if kind == "cop" else "worker")
    var frames: Array = []
    for i in range(4): frames.append(load("res://assets/bunker/%s%d.png" % [name,i]))
    z["frames"] = frames
    z["idle_tex"] = frames[0]
    z["spr"].texture = frames[0]
    z["spr"].scale = Vector2(0.27,0.27)
    z["base_scale"] = Vector2(0.27,0.27)
    var rig:=preload("res://scripts/bunker/actor_rig.gd").new()
    rig.position=pos;rig.z_index=8;rig.b=self
    rig.outfit=Color(0.65,0.69,0.66) if kind=="sci" else (Color(0.16,0.23,0.28) if kind=="cop" else Color(0.34,0.36,0.29))
    unit_layer.add_child(rig)
    z["rig5"]=rig
    z["spr"].hide()
    for c in z["spr"].get_children(): c.queue_free()

func _log(text: String, col := Color(0.8,0.8,0.75), tag := "") -> void:
    super._log(text,col,tag)
    while log_lines.size() > 3: log_lines.pop_front()
    if is_instance_valid(story_feed6): story_feed6.push(text,tag)

var checkpoint_timer := 0.0
func _save_checkpoint() -> void:
    if starting or ending or player.is_empty() or not player["alive"]: return
    var ds := {}
    for id in doors: ds[id] = bool(doors[id]["opened"])
    var done: Array = []
    for o in objectives:
        if o["done"]: done.append(o["id"])
    var enemies: Array = []
    for z in zombies:
        var p: Vector2 = z["spr"].position
        enemies.append({"kind":z["kind"],"pos":[p.x,p.y],"hp":z["hp"],"alive":z["alive"]})
    var searched: Array = []
    for c in corpses: searched.append(bool(c.get("searched",false)))
    var used: Array = []
    for pr in props: used.append({"used":bool(pr.get("used",false)),"loot":pr.get("loot_items",[])})
    var p: Vector2 = player["spr"].position
    G.zsave["bunker3"] = {"version":3,"layout":4,"records":records,"notes":notes,"doors":ds,"done":done,"enemies":enemies,"searched":searched,"used":used,"pos":[p.x,p.y],"st":player["st"],"infect":player["infect"],"mag":player["mag"],"gate":zp_gate_state,"gate_progress":gate_progress}
    G.write_save()

func _restore_checkpoint() -> bool:
    var data: Dictionary = G.zsave.get("bunker3",{})
    if int(data.get("version",0)) != 3: return false
    records = data.get("records",{})
    notes = data.get("notes",[])
    restoring5 = true
    for id in data.get("doors",{}):
        if data["doors"][id]: _open_door(id)
    restoring5 = false
    for o in objectives: o["done"] = data.get("done",[]).has(o["id"])
    for i in range(data.get("enemies",[]).size()):
        var e: Dictionary = data["enemies"][i]
        var pos := Vector2(float(e["pos"][0]),float(e["pos"][1]))
        if i >= zombies.size(): _spawn_zombie(str(e["kind"]),pos)
        var z: Dictionary = zombies[i]
        z["spr"].position = pos
        z["hp"] = float(e["hp"])
        z["alive"] = bool(e["alive"])
        z["spr"].visible = z["alive"]
        if not z["alive"] and z.has("rig5"):
            var dead_rig=z["rig5"]
            dead_rig.position=pos;dead_rig.fall(Vector2.ZERO);dead_rig.fall_time=1.4;dead_rig.z_index=2
            corpses.append({"spr":z["spr"],"kind":"zmb","searched":false,"pos":pos,"loot":z["loot"]})
    for i in range(mini(corpses.size(),data.get("searched",[]).size())):
        corpses[i]["searched"] = bool(data["searched"][i])
    for i in range(mini(props.size(),data.get("used",[]).size())):
        props[i]["used"] = bool(data["used"][i]["used"])
        if props[i]["used"] and int(data.get("layout",3)) >= 4: props[i]["loot_items"] = data["used"][i]["loot"]
    var p: Array = data.get("pos",[460,490])
    player["spr"].position = Vector2(float(p[0]),float(p[1]))
    player["st"] = data.get("st",Med.mk_state())
    player["infect"] = float(data.get("infect",0.0))
    player["mag"] = int(data.get("mag",8))
    zp_gate_state = int(data.get("gate",0))
    gate_progress = float(data.get("gate_progress",0.0))
    zp["gen_on"] = records.has("power")
    zp["iso_off"] = records.has("isolation")
    if zp_gate_state == 4:
        for pr in props:
            if pr["kind"] == "exit_gate": pr["spr"].position = pr["pos"]+Vector2(0,-160)
    if int(data.get("layout",3)) < 4:
        var stage_positions := [Vector2(460,490),Vector2(990,480),Vector2(1850,1200),Vector2(830,1520),Vector2(600,2400),Vector2(2040,2460)]
        var stage := 0
        if records.has("terminal"): stage = 1
        if _obj_done("gear"): stage = 2
        if records.has("journal_a") and records.has("journal_b"): stage = 3
        if records.has("lower"): stage = 4
        if records.has("archive") and records.has("isolation"): stage = 5
        player["spr"].position = stage_positions[stage]
        var spawn_positions := [Vector2(1970,1470),Vector2(2520,1660),Vector2(760,2590),Vector2(1120,2390),Vector2(1860,2530),Vector2(2010,2470)]
        for i in range(mini(zombies.size(),spawn_positions.size())): zombies[i]["spr"].position = spawn_positions[i]
    player["spr"].position=_collide_circle(player["spr"].position,15)
    camera.position = player["spr"].position
    camera.reset_smoothing()
    _refresh_obj_labels()
    return true

func _open_pause() -> void:
    if is_instance_valid(pause_win): return
    _release_controls5();_save_checkpoint();paused=true
    var panel:=preload("res://scripts/ui/bunker_pause.gd").new();panel.b=self
    pause_win=panel;panel.tree_exiting.connect(_pause_closed);ui_layer.add_child(panel)

func _notification(what: int) -> void:
    if has_meta("qa8"): return
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_checkpoint()
    super._notification(what)

func _complete_objective(id: String) -> void:
    super._complete_objective(id)
    _save_checkpoint()

func _spawn_corpse(kind: String, pos: Vector2) -> void:
    super._spawn_corpse(kind,pos)
    var spr: Sprite2D = corpses[-1]["spr"]
    spr.texture = preload("res://assets/bunker/guard0.png") if kind == "guard" else preload("res://assets/bunker/scientist0.png")
    spr.scale = Vector2(0.28,0.20)
    spr.modulate = Color(0.55,0.58,0.6)
    for child in spr.get_children(): child.queue_free()

func _tick_player(delta: float) -> void:
    recoil4 = maxf(0,recoil4-delta*6.5)
    shot_heat4 = maxf(0,shot_heat4-delta*0.65)
    var target: float = manual_ang if manual_aim else (player_velocity.angle() if player_velocity.length()>4 else smooth_aim5)
    smooth_aim5 = lerp_angle(smooth_aim5,target,1.0-exp(-delta*12.0))
    var input_angle := manual_ang
    manual_ang = smooth_aim5
    if not _has_weapon7(): manual_fire=false
    super._tick_player(delta)
    manual_ang = input_angle
    player["aim"] = smooth_aim5
    var face := Vector2.from_angle(smooth_aim5)
    player["spr"].rotation=0.0
    player["spr"].self_modulate.a=0.0
    player_rig6.visible=player["spr"].visible
    player_rig6.position=player["spr"].position
    player_rig6.modulate.a=player["spr"].modulate.a
    player_rig6.pose(smooth_aim5,player_walk_t,player_velocity,_has_weapon7() or loadout7.hands().has("flashlight"),delta)
    # Texture starts at its left edge; its apex is now exactly the lamp origin.
    player["halo"].hide()
    player["light"].position = _flash_origin7()
    player["light"].enabled = _obj_done("gear") and player["alive"] and loadout7.hands().has("flashlight") and not bool(zp.get("flash_off",false))
    player["light"].rotation = smooth_aim5
    if is_instance_valid(_hand_ind): _hand_ind.visible=false
    aim_rig4.visible = _has_weapon7() and player["spr"].visible
    var two: bool=loadout7.two_handed("weapon:"+loadout7.weapon())
    aim_rig4.position = player["spr"].position+face.rotated(PI/2)*(0 if two else (7 if _weapon_hand7()==1 else -7))
    aim_rig4.rotation = smooth_aim5
    aim_rig4.queue_redraw()

class WeaponRig extends Node2D:
    const PM=preload("res://assets/bunker/v8/pm_top.svg")
    var b = null
    func _draw() -> void:
        if b == null: return
        var kick: float = b.recoil4*4.0
        if b.player["weapon"]=="knife":
            draw_line(Vector2(14,0),Vector2(23,0),Color(0.10,0.13,0.14),4)
            draw_colored_polygon(PackedVector2Array([Vector2(23,-2),Vector2(35,0),Vector2(23,2)]),Color(0.62,0.71,0.73))
            return
        if b.loadout7.two_handed("weapon:"+b.player["weapon"]):
            draw_rect(Rect2(4-kick,-3,28,6),Color(0.09,0.13,0.15))
            draw_line(Vector2(27-kick,0),Vector2(43-kick,0),Color(0.27,0.33,0.35),3)
            draw_rect(Rect2(17-kick,3,6,7),Color(0.055,0.08,0.09))
            return
        draw_circle(Vector2(13-kick,3),3.5,Color(0.55,0.43,0.35))
        draw_texture_rect(PM,Rect2(8-kick,-5,25,11),false)
        # Ejection port and rearward slide movement remain readable at game scale.
        if kick>0.2:
            draw_line(Vector2(15-kick,-4),Vector2(28-kick,-4),Color(0.60,0.69,0.71),0.8,true)

func _art_texture4(name: String) -> Texture2D:
    if name in ["sink","terminal","security","first_aid"]:
        return load("res://assets/bunker/v8/"+("terminal" if name=="security" else name)+".svg")
    for dir in ["res://assets/bunker/v6/","res://assets/bunker/v5/","res://assets/bunker/v4/","res://assets/bunker/"]:
        for ext in [".png",".svg"]:
            if ResourceLoader.exists(dir+name+ext): return load(dir+name+ext)
    return null

func _bubble_caption(kind: String, holding: bool) -> String:
    if kind in ["story","story_door"]:
        return "выполняется…" if holding else str(cur_interact.get("text","действие")).to_lower()
    return super._bubble_caption(kind,holding)


func _build_hud() -> void:
    super._build_hud()
    loadout7.ensure()
    for child in quick_panel_ref.get_children(): quick_panel_ref.remove_child(child);child.queue_free()
    quick_panel_ref.add_theme_constant_override("separation",6)
    var ammo:=preload("res://scripts/ui/round_control.gd").new()
    ammo.symbol="ammo";ammo.caption="ПАТРОНЫ";ammo.custom_minimum_size=Vector2(64,88)
    ammo.pressed.connect(_start_ammo_check);quick_panel_ref.add_child(ammo)
    for i in range(2):
        var hand:=preload("res://scripts/ui/equipment_cell.gd").new()
        hand.b=self;hand.place="hand";hand.index=i;hand.custom_minimum_size=Vector2(74,88);quick_panel_ref.add_child(hand)
    quick_slots.clear()
    for i in range(6):
        var slot:=preload("res://scripts/ui/equipment_cell.gd").new()
        slot.b=self;slot.place="quick";slot.index=i;slot.custom_minimum_size=Vector2(68,88)
        quick_panel_ref.add_child(slot);quick_slots.append(slot)
    # Replace only location one's map and action button.
    for c in ui_layer.get_children():
        if c.get_script() == MiniMap:
            c.set_script(preload("res://scripts/bunker/route_map.gd"))
            c.btl=self
            c.set_process(true)
    if is_instance_valid(interact_bubble):
        interact_bubble.hide()
        interact_bubble.set_process(false)
    var controls:=preload("res://scripts/ui/mobile_hud_v6.gd").new()
    controls.b=self;ui_layer.add_child(controls)
    story_feed6=preload("res://scripts/ui/story_feed.gd").new()
    story_feed6.b=self
    ui_layer.add_child(story_feed6)
    for child in menu_btns_ref.get_children(): menu_btns_ref.remove_child(child);child.queue_free()
    menu_btns_ref.offset_left=-284;menu_btns_ref.offset_right=-16
    menu_btns_ref.offset_top=214;menu_btns_ref.offset_bottom=306
    var dock:=HBoxContainer.new();dock.add_theme_constant_override("separation",4);menu_btns_ref.add_child(dock)
    for definition in [["bag","РЮКЗАК"],["pda","КПК"],["flashlight","СВЕТ"],["pause","ПАУЗА"]]:
        var control:=preload("res://scripts/ui/round_control.gd").new()
        control.symbol=definition[0];control.caption=definition[1];control.custom_minimum_size=Vector2(64,88)
        dock.add_child(control)
        match definition[0]:
            "bag": control.pressed.connect(_open_med)
            "pda": control.pressed.connect(_open_kpk)
            "flashlight":
                control.toggle_mode=true;control.pressed.connect(_zpro_toggle_flash);flash_button6=control
            "pause": control.pressed.connect(_open_pause)
    action5=preload("res://scripts/bunker/action_control.gd").new()
    action5.btl=self
    ui_layer.add_child(action5)
    var sight:=preload("res://scripts/bunker/aim_indicator.gd").new()
    sight.btl=self
    ui_layer.add_child(sight)

func _update_interact(_delta: float=0.0) -> void:
    _update_flash_control6()
    cur_interact={} if paused or in_capsule else _find_interact()
    if is_instance_valid(interact_bubble): interact_bubble.visible=false

func _tick_zombies(delta: float) -> void:
    var positions: Array[Vector2]=[]
    for z in zombies: positions.append(z["spr"].position)
    super._tick_zombies(delta)
    for i in range(zombies.size()):
        var z: Dictionary=zombies[i]
        if not z.has("rig5"): continue
        var rig: Node2D=z["rig5"]
        if not z["alive"]: continue
        var velocity: Vector2=(z["spr"].position-positions[i])/maxf(delta,0.001)
        var heading: float=velocity.angle() if velocity.length()>1 else rig.heading
        rig.position=z["spr"].position
        rig.update_pose(heading,float(z["walk_t"]),velocity.length(),delta)
        z["spr"].rotation=0
        z["spr"].visible=false

func _cull_offscreen() -> void:
    super._cull_offscreen()
    # Never resurrect a door leaf already moved into its wall pocket.
    for id in doors:
        if doors[id]["opened"] or doors[id].get("opening",false): doors[id]["pr"]["spr"].visible=false
    for z in zombies:
        if z.has("rig5"): z["spr"].visible=false

func _open_door(id: String) -> void:
    var door: Dictionary=doors.get(id,{})
    if door.is_empty() or door["opened"] or door.get("opening",false): return
    var original: Sprite2D=door["pr"]["spr"]
    original.hide()
    if not restoring5:
        door["opening"]=true
        G.play_sfx("z_door",-12.0)
        var extent: Vector2=original.texture.get_size()*original.scale
        var frame:=Polygon2D.new()
        frame.polygon=PackedVector2Array([Vector2(-extent.x/2,-extent.y/2),Vector2(extent.x/2,-extent.y/2),extent/2,Vector2(-extent.x/2,extent.y/2)])
        frame.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
        frame.position=door["pr"]["pos"];frame.rotation=original.rotation;frame.z_index=5
        prop_layer.add_child(frame)
        for side in [-1,1]:
            var leaf:=Sprite2D.new();leaf.texture=original.texture;leaf.region_enabled=true
            var half: float=original.texture.get_height()*0.5
            leaf.region_rect=Rect2(0,0 if side<0 else half,original.texture.get_width(),half)
            leaf.scale=original.scale;leaf.position=Vector2(0,side*extent.y*0.25);frame.add_child(leaf)
            var tw:=leaf.create_tween();tw.tween_interval(0.18)
            tw.tween_property(leaf,"position:y",side*extent.y*0.80,1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        await get_tree().create_timer(1.24).timeout
        frame.queue_free()
    original.hide()
    door["opened"]=true;door["opening"]=false
    walls.erase(door["wall"])
    if wall_occluders.has(door["wall"]):
        var occ=wall_occluders[door["wall"]]
        if is_instance_valid(occ): occ.queue_free()
        wall_occluders.erase(door["wall"])
    if environment4!=null: environment4.redraw_all()
    if not restoring5: _save_checkpoint()

func _open_loot_window(title: String, source: Dictionary) -> void:
    if is_instance_valid(loot_win): return
    paused=true
    _release_controls5()
    loot_source=source
    var screen:=preload("res://scripts/bunker/loot_screen.gd").new()
    screen.b=self;screen.source=source;screen.title=title
    loot_win=screen
    screen.tree_exiting.connect(_loot_closed)
    ui_layer.add_child(screen)

func zp_terminal_screen(title: String, accent: Color, lines: Array, on_done: Callable=Callable(), status: String="") -> void:
    if is_instance_valid(zp_overlay_layer): return
    paused=true
    _release_controls5()
    var layer:=CanvasLayer.new();layer.layer=41;add_child(layer)
    zp_overlay_layer=layer
    var replay: bool=records.has("terminal_seen:"+title)
    records["terminal_seen:"+title]=true
    var terminal:=preload("res://scripts/bunker/terminal_view.gd").new(title,accent)
    terminal.instant=replay
    terminal.body_state=player["st"].get("body",{}).duplicate()
    terminal.power_ready=records.has("power")
    layer.add_child(terminal)
    terminal.modulate.a=1.0 if replay else 0.0
    if not replay: terminal.create_tween().tween_property(terminal,"modulate:a",1.0,0.32)
    if status!="": terminal.set_status(status)
    var close:=Button.new();close.text="ЗАКРЫТЬ ТЕРМИНАЛ";close.custom_minimum_size=Vector2(280,56)
    close.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    close.offset_left=-350;close.offset_right=-70;close.offset_top=-100;close.offset_bottom=-44
    close.add_theme_stylebox_override("normal",ZUI.panel_style(Color(0.04,0.085,0.10),Color(0.31,0.50,0.54),14))
    close.add_theme_stylebox_override("hover",ZUI.panel_style(Color(0.08,0.15,0.18),Color(0.55,0.72,0.72),14))
    close.disabled=false;terminal.add_child(close)
    var finish:=func():
        if close.disabled: return
        close.disabled=true
        var tw:=terminal.create_tween()
        tw.tween_property(terminal,"modulate:a",0.0,0.25)
        tw.tween_callback(func():
            layer.queue_free();zp_overlay_layer=null
            if battle_over=="": paused=false
            if on_done.is_valid(): on_done.call())
    close.pressed.connect(finish)
    terminal.print_lines(lines,func(): close.disabled=false)

func _tick_territory(_delta: float) -> void:
    # Location one uses an explored trail, not campaign influence simulation.
    pass

func _unhandled_input(event: InputEvent) -> void:
    if paused:
        manual_fire=false
        direct_vec=Vector2.ZERO
        _stick_move_idx=-1
        _stick_aim_idx=-1
        return
    super._unhandled_input(event)

func _release_controls5() -> void:
    direct_vec=Vector2.ZERO
    manual_fire=false
    _stick_move_idx=-1
    _stick_aim_idx=-1
    _touch_pts.clear()
    _run_mode=false

func _open_med() -> void:
    _open_inventory7("equipment")

func _open_kpk() -> void:
    _open_inventory7("records")

func _spawn_ally(squad_member: Dictionary={}) -> void:
    super._spawn_ally(squad_member)
    var actor: Dictionary=allies[-1]
    var rig:=preload("res://scripts/bunker/actor_rig.gd").new()
    rig.infected=false;rig.outfit=Color(0.18,0.25,0.29);rig.z_index=8
    rig.position=actor["spr"].position
    unit_layer.add_child(rig);actor["rig5"]=rig
    actor["spr"].hide()

func _tick_allies(delta: float) -> void:
    var positions: Array[Vector2]=[]
    for actor in allies: positions.append(actor["spr"].position)
    super._tick_allies(delta)
    for i in range(allies.size()):
        var actor: Dictionary=allies[i]
        if not actor.has("rig5"): continue
        var rig: Node2D=actor["rig5"]
        if not actor["alive"]: rig.hide();continue
        var velocity: Vector2=(actor["spr"].position-positions[i])/maxf(delta,0.001)
        rig.position=actor["spr"].position
        rig.update_pose(velocity.angle() if velocity.length()>1 else rig.heading,time_alive*7,velocity.length(),delta)
        actor["spr"].rotation=0;actor["spr"].hide()

func _toast(text: String) -> void:
    if is_instance_valid(story_feed6): story_feed6.push(text,"СИСТЕМА")

func _zpro_toggle_flash() -> void:
    if not _obj_done("gear") or paused: return
    if not loadout7.hands().has("flashlight"):
        if not loadout7.equip("flashlight"): return
        zp["flash_off"]=false
    else: zp["flash_off"]=not bool(zp.get("flash_off",false))
    G.zsave["flash_off7"]=zp["flash_off"]
    player["light"].enabled=loadout7.hands().has("flashlight") and not zp["flash_off"]
    player["light"].energy=0.7
    if is_instance_valid(flash_button6): flash_button6.set_pressed_no_signal(player["light"].enabled)
    G.play_sfx("z_relay",-22.0,1.2)
    G.write_save()

func _update_flash_control6() -> void:
    if not is_instance_valid(flash_button6): return
    flash_button6.visible=true
    flash_button6.disabled=paused or not _obj_done("gear")
    flash_button6.set_pressed_no_signal(loadout7.hands().has("flashlight") and not bool(zp.get("flash_off",false)))

func _add_shadow(_spr: Sprite2D, _wf: float, _hf: float, _a: float, _dy:=0.0) -> void:
    # Each furniture prop receives one matching contour shadow after its final texture is set.
    pass

func _collide_circle(pos: Vector2, radius: float) -> Vector2:
    var result:=pos
    for iteration in range(3):
        var before:=result
        for wall in walls:
            if not wall.grow(radius).has_point(result): continue
            var closest:=Vector2(clampf(result.x,wall.position.x,wall.end.x),clampf(result.y,wall.position.y,wall.end.y))
            var delta:=result-closest
            if delta.length_squared()<0.00001:
                var choices: Array=[Vector2(wall.position.x-radius-0.08,result.y),Vector2(wall.end.x+radius+0.08,result.y),Vector2(result.x,wall.position.y-radius-0.08),Vector2(result.x,wall.end.y+radius+0.08)]
                var best:=INF
                for point in choices:
                    var distance: float=result.distance_squared_to(point)
                    if distance<best: best=distance;closest=point
                result=closest
            elif delta.length_squared()<radius*radius:
                result=closest+delta.normalized()*(radius+0.08)
        for prop in props:
            if prop["solid"]: result=PropGeometry7.push_out(prop,result,radius)
        if result.distance_squared_to(before)<0.00001: break
    return result.clamp(Vector2(60,60),map_size-Vector2(60,60))

func _los_clear(a: Vector2, endpoint: Vector2) -> bool:
    for wall in walls:
        if _seg_rect_hit(a,endpoint,wall): return false
    for prop in props:
        if prop.get("blocks_view7",false) and PropGeometry7.segment_entry(prop,a,endpoint)!=Vector2.INF: return false
    return true

func _ray_wall_dist(origin: Vector2, direction: Vector2, max_distance: float) -> float:
    var distance:=super._ray_wall_dist(origin,direction,max_distance)
    var endpoint:=origin+direction*distance
    for prop in props:
        if not prop["solid"]: continue
        var hit:=PropGeometry7.segment_entry(prop,origin,endpoint)
        if hit!=Vector2.INF: distance=minf(distance,origin.distance_to(hit))
    return distance

func _has_weapon7() -> bool:
    return loadout7.weapon()!=""
func _weapon_hand7() -> int:
    var weapon:=loadout7.weapon()
    return loadout7.hand_of("weapon:"+weapon) if weapon!="" else -1
func _weapon_origin7() -> Vector2:
    var face:=Vector2.from_angle(player["aim"])
    var two: bool=loadout7.two_handed("weapon:"+loadout7.weapon())
    return player["spr"].position+face*(43 if two else 33)+face.rotated(PI/2)*(0 if two else (7 if _weapon_hand7()==1 else -7))
func _flash_origin7() -> Vector2:
    var face:=Vector2.from_angle(player["aim"])
    return player["spr"].position+face*29+face.rotated(PI/2)*(-11 if loadout7.hand_of("flashlight")==0 else 11)
func _open_inventory7(tab: String) -> void:
    if is_instance_valid(inventory7): inventory7.select_page(tab);return
    _release_controls5();paused=true;loadout7.ensure()
    var screen:=preload("res://scripts/ui/equipment_screen.gd").new();screen.b=self;screen.page=tab
    inventory7=screen
    if tab=="equipment": med_win=screen
    else: kpk_win=screen
    screen.tree_exiting.connect(_inventory_closed7)
    ui_layer.add_child(screen)
func _inventory_closed7() -> void:
    inventory7=null;med_win=null;kpk_win=null
    _med_doll=null;_med_info_lbl=null
    paused=false
func _inventory_changed7() -> void:
    if not player.is_empty() and player.has("light"):
        player["light"].enabled=player["alive"] and _obj_done("gear") and loadout7.hands().has("flashlight") and not bool(zp.get("flash_off",false))
    if is_instance_valid(aim_rig4):
        aim_rig4.visible=_has_weapon7() and player["spr"].visible
        aim_rig4.queue_redraw()
    inventory_revision7+=1
    _refresh_quick_slots()
    if is_instance_valid(inventory7): inventory7.refresh()
func _inventory_message7(message: String) -> void:
    if is_instance_valid(inventory7): inventory7.info.text=message
    else: _toast(message)
func _refresh_quick_slots() -> void:
    for slot in quick_slots:
        if is_instance_valid(slot) and slot.has_method("refresh"): slot.refresh()
func _refresh_med_window() -> void:
    loadout7.ensure();_inventory_changed7()
func _refresh_kpk() -> void:
    loadout7.ensure();_inventory_changed7()
func _refresh_after_item_use() -> void:
    loadout7.ensure();_inventory_changed7();G.write_save()
func _assign_quick(index: int,item: String) -> void:
    loadout7.assign_quick(index,item)
func _swap_quick(a: int,c: int) -> void:
    if mini(a,c)<0 or maxi(a,c)>=6: return
    var values: Array=G.zsave["quick"]
    var item=values[a];values[a]=values[c];values[c]=item
    loadout7.changed()
func _quick_to_grid(index: int,target: int) -> void:
    if index<0 or index>=6: return
    var item:=str(G.zsave["quick"][index]);G.zsave["quick"][index]=""
    var slots:=loadout7.slots();var from:=slots.find(item)
    if from>=0 and target>=0 and target<slots.size(): loadout7.move_bag(from,target)
    else: loadout7.changed()
func _move_inv_slot(a: int,c: int) -> void:
    loadout7.move_bag(a,c)
func _quick_use_item(item: String) -> void:
    if item=="flashlight" or item.begins_with("weapon:"):
        if loadout7.hands().has(item): loadout7.put_away(loadout7.hand_of(item))
        else: loadout7.equip(item)
        return
    super._quick_use_item(item)
    loadout7.ensure();_inventory_changed7()
func _reload_player() -> void:
    if _has_weapon7(): super._reload_player()
func _select_weapon(index: int) -> void:
    var weapons: Array=G.zsave.get("weapons",[])
    if index<0 or index>=weapons.size(): return
    var side:=_weapon_hand7()
    loadout7.equip("weapon:"+str(weapons[index]),side)
func _cycle_weapon() -> void:
    var weapons: Array=G.zsave.get("weapons",[])
    if weapons.is_empty(): return
    _select_weapon((weapons.find(loadout7.weapon())+1)%weapons.size())

func _receive_item(item: String,count: int) -> void:
    super._receive_item(item,count)
    loadout7.ensure();_inventory_changed7()

func _damage_zombie(z: Dictionary, damage: float, direction: Vector2) -> void:
    z["impact8"]=direction
    super._damage_zombie(z,damage,direction)
func _kill_zombie(z: Dictionary) -> void:
    if not z["alive"]: return
    super._kill_zombie(z)
    z["spr"].hide()
    if z.has("rig5"):
        z["rig5"].z_index=2
        z["rig5"].fall(z.get("impact8",Vector2.from_angle(z["rig5"].heading)))

func _exit_phase8(stage: int,duration: float) -> void:
    var phase:=create_tween()
    phase.tween_method(func(v: float): player_rig6.exit_pose8(stage,v),0.0,1.0,duration)
    await phase.finished
