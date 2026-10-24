# ============================================================
# ЯДРО БОЯ «ЛИНИЯ ФРОНТА»
# Управление миром: слои, юниты, снаряды, туман войны,
# экономика реквизиции, тикеты, захват секторов, приказы игрока,
# способности (авиаудар/артналёт/дым/мины/дроны), миникарта-данные.
# ============================================================
extends Node2D

const UnitScript = preload("res://scripts/unit.gd")
const ProjScript = preload("res://scripts/projectile.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const FxScript = preload("res://scripts/fx.gd")
const AIScript = preload("res://scripts/ai_cmd.gd")
const UIScript = preload("res://scripts/ui_battle.gd")
const Med = preload("res://scripts/med.gd")
const TerrScript = preload("res://scripts/territory.gd")

# ---------- тайлы ----------
const T_GRASS := 0
const T_GRASS2 := 1
const T_DRY := 2
const T_DIRT := 3
const T_FIELD := 4
const T_FIELD2 := 5
const T_FOREST := 6
const T_ROAD := 7
const T_DROAD := 8
const T_WATER := 9
const T_BRIDGE := 10
const T_URBAN := 11
const T_TRENCH := 12
const T_CONCRETE := 13
const T_RUBBLE := 14
const T_MUD := 15

const TS := 128
const MAP_W := 64
const MAP_H := 44
const FOG_CELL := 64
const SPOT_TICK := 0.15

# ---------- ссылки на узлы ----------
var tile_layer: Node2D
var prop_layer: Node2D
var unit_layer: Node2D
var proj_layer: Node2D
var fx_layer: Node2D
var fog_layer: Node2D
var camera: Camera2D
var fx = null
var ui = null
var ai = null

# ---------- состояние мира ----------
var tiles: Array = []
var tvar: Array = []   # варианты тайлов дорог (hn/hs/vw/ve/x_nw/.../bhn/bhs)
var units: Array = []
var projs: Array = []
var obstacles: Array = []
var smoke_sources: Array = []
var decay_nodes: Array = []
var mines: Array = []
var points: Array = []
var fob_player := Vector2.ZERO
var fob_enemy := Vector2.ZERO
var jets: Array = []

# ---------- экономика и счёт ----------
var req := 1400.0
var tickets_player := 1000.0
var tickets_enemy := 1000.0
var deploy_queue: Array = []
var ability_cd := {}
var stats := {"kills": 0, "losses": 0, "spent": 0, "captured": 0, "time": 0.0}

# ---------- видимость ----------
var fog_w := 128
var fog_h := 88
var explored := []
var visible_cells := []
var vis_player := {}   # unit → true (видим игроку)
var vis_enemy := {}    # unit → true (видим врагу)
var fog_img: Image = null
var fog_tex: ImageTexture = null
var fog_sprite: Sprite2D = null
var fog_timer := 0.0
var spot_timer := 0.0

# ---------- выбор и ввод ----------
var selection: Array = []
var control_groups := {}
var drag_start := Vector2.ZERO
var dragging := false
var amove_mode := false
var garrison_mode := false
var evac_mode := false       # следующий тап — приказ эвакуации раненых
var paused := false
var battle_over := ""
# сенсорные приказы: кнопка «ПРИКАЗ» → следующий тап по карте отдаёт движение/атаку
var touch_order := false
# мультитач: два пальца — перетаскивание камеры, щипок — зум
var _touch_pts := {}
var _panning := false
var _pan_mid := Vector2.ZERO
var _pinch_dist := 0.0

# ---------- катсцена приезда (колонна КамАЗов) ----------
var cutscene := false
var convoy: Array = []       # {node, from, to, t, dur, state, deliver, dests, unloaded}
var cut_end_t := 0.0
var cut_done := false
var engine_player: AudioStreamPlayer = null

# ---------- прямое управление отрядом («играем за военного», twin-stick) ----------
var direct_ctrl := false
var direct_unit = null
var direct_vec := Vector2.ZERO
var joy_active := false
var joy_origin := Vector2.ZERO
var manual_aim := false       # правый стик / мышь — прицел
var manual_fire := false      # СИЛЬНЫЙ толчок правого стика — огонь
var manual_ang := 0.0
var r_joy_active := false
var r_joy_origin := Vector2.ZERO
var _stick_move_idx := -1     # индекс касания левого стика
var _stick_aim_idx := -1      # индекс касания правого стика
var _r_fire_latch := false    # гистерезис «толкни до упора — стреляй»
var touch_mode := false       # реальные касания (телефон)
var _prev_zoom := 0.8         # зум до входа в прямое управление

# ---------- ГЕОМЕТРИЯ СТИКОВ: ЗАКРЕПЛЁННЫЕ БАЗЫ В УГЛАХ ----------
# Стики строго симметричны и крупные: левый «ХОД», правый «ОГОНЬ».
# Захват — большой круг вокруг базы; огонь только ПОСЛЕ доводки ручки
# от центра к краю (нельзя выстрелить, просто коснувшись края стика).
const STICK_KNOB := 84.0      # радиус видимой базы стика (крупный)
const STICK_ACT_R := 175.0    # радиус зоны захвата касания
const STICK_FIRE_K := 0.66    # доля отклонения правого стика для ОГНЯ
const STICK_FIRE_OFF := 0.46  # отпустил ниже — огонь прекращается
var _r_was_center := false    # ручка была у центра — разрешаем залп доводкой

func stick_base(side: String) -> Vector2:
        # СТРОГО симметричные базы: одинаковый отступ от углов и от низа
        var vp := get_viewport_rect().size
        var y := vp.y - 236.0
        var x := maxf(220.0, vp.x * 0.085)
        if side == "l":
                return Vector2(x, y)
        return Vector2(vp.x - x, y)

# ---------- логистика: ящики снабжения и детонация боекомплекта ----------
var crates: Array = []        # {node: Sprite2D, t: float}
var pending_booms: Array = [] # детонация боекомплекта: {pos, t, size, src}

# ---------- носимая аптечка командира (ТЗ 4.3: сетка инвентаря) ----------
var cmd_items := {"band": 4, "tq": 2, "splint": 2, "morph": 2, "mag": 3}
var mag_blind := -1           # «на глаз»: примерное число патронов в магазине

# ---- КОМАНДИР (играем за него) и АВТОНОМНАЯ ДОКТРИНА ----
var cmdr = null                     # боец-командир (герой)
var cmdr_respawn := 0.0             # >0 — ждём прибытия заместителя
const CMDR_RESPAWN := 20.0
var auto_on := true                 # автономное наступление отрядов (WorldBox-стиль)
var auto_tick := 5.0

# ---- ДИНАМИЧЕСКАЯ ТЕРРИТОРИЯ ----
var territory = null
var FAC_COL_P := Color(0.45, 0.75, 0.4)
var FAC_COL_E := Color(0.8, 0.35, 0.3)

func use_cmd_item(item: String) -> void:
        if not direct_ctrl or not is_instance_valid(direct_unit):
                return
        if int(cmd_items.get(item, 0)) <= 0:
                add_log("Предметов нет — ищите снабжение", Color(0.9, 0.6, 0.5))
                return
        if item == "mag":
                if direct_unit.def["kind"] == "inf" and direct_unit.mags < direct_unit.mags_max:
                        direct_unit.mags = minf(direct_unit.mags_max, direct_unit.mags + 1.0)
                        cmd_items["mag"] = int(cmd_items["mag"]) - 1
                        add_log("Набит магазин: боезапас +1", Color(0.85, 0.85, 0.6))
                        G.play_sfx("ui_click", -8.0, 1.2)
                else:
                        add_log("Магазины полны", Color(0.7, 0.75, 0.6))
                return
        if direct_unit.def["kind"] != "inf":
                return
        # применяем к худшему раненому бойцу отряда командира
        var worst = null
        var wscore := -1.0
        for s in direct_unit.soldiers:
                if not s["alive"]:
                        continue
                var sc := 0.0
                if (s["st"] as Dictionary)["down"]:
                        sc = 3.0
                var wi: String = Med.worst_item(s)
                if wi == item:
                        sc += 2.0
                elif wi != "":
                        sc += 1.0
                if sc > wscore:
                        wscore = sc
                        worst = s
        if worst == null:
                add_log("В отряде нет раненых — предметы целы", Color(0.7, 0.75, 0.6))
                return
        var res: String = Med.treat(worst, item)
        if res == "":
                cmd_items[item] = int(cmd_items[item]) - 1
                add_log("%s: применено — состояние бойца улучшено" % Med.ITEM_RU.get(item, item), Color(0.6, 0.9, 0.6), "МЕДИК")
                G.play_sfx("ui_click", -6.0, 0.9)
        else:
                add_log(res, Color(0.8, 0.7, 0.5), "МЕДИК")

func check_mag_blind() -> void:
        # проверка магазина «на глаз» (взвешиванием): показываем приблизительно
        if not direct_ctrl or not is_instance_valid(direct_unit):
                return
        var real := int(round(direct_unit.mags))
        mag_blind = clampi(real + randi() % 5 - 2, 0, int(direct_unit.mags_max))
        add_log("НА ГЛАЗ: в подсумке примерно %d полных магазинов" % mag_blind, Color(0.8, 0.8, 0.6))

func use_cmd_item_zone(item: String, zone: String) -> void:
        # ПРЕДМЕТ НА ЗОНУ ТЕЛА (перетаскивание в санчасти): жгут — на раненую ногу,
        # бинт — на разбитую зону, шина — на перелом. Точный, «ручной» способ.
        if not direct_ctrl or not is_instance_valid(direct_unit):
                return
        if int(cmd_items.get(item, 0)) <= 0:
                add_log("Предметов нет — ищите снабжение", Color(0.9, 0.6, 0.5), "СНАРЯЖЕНИЕ")
                return
        if item == "mag":
                use_cmd_item("mag")   # магазин к схеме тела не относится — просто набиваем
                return
        if direct_unit.def["kind"] != "inf":
                add_log("Технике аптечка не нужна", Color(0.7, 0.75, 0.6), "СНАРЯЖЕНИЕ")
                return
        var worst = null
        var wscore := -1.0
        for s in direct_unit.soldiers:
                if not s["alive"]:
                        continue
                var sc := 0.0
                if (s["st"] as Dictionary)["down"]:
                        sc = 3.0
                if Med.worst_item(s) != "":
                        sc += 1.0
                # приоритет бойцу, у которого ранена ИМЕННО эта зона
                var b: float = (s["st"] as Dictionary)["body"][zone]
                sc += (1.0 - b) * 1.5
                if sc > wscore:
                        wscore = sc
                        worst = s
        if worst == null:
                add_log("В отряде нет бойцов", Color(0.7, 0.75, 0.6), "СНАРЯЖЕНИЕ")
                return
        var res: String = Med.treat_zone(worst, item, zone)
        if res == "":
                cmd_items[item] = int(cmd_items[item]) - 1
                add_log("%s → %s: применено, состояние улучшилось" % [Med.ITEM_RU.get(item, item), Med.ZONE_RU.get(zone, zone)], Color(0.6, 0.9, 0.6), "МЕДИК")
                G.play_sfx("ui_click", -6.0, 0.9)
        else:
                add_log(res, Color(0.8, 0.7, 0.5), "МЕДИК")
                G.play_sfx("ui_click", -14.0, 0.7)

# ---------- камера ----------
var cam_zoom := 0.8           # шире обзор: видно тактику, а не один куст
var shake_amt := 0.0
var map_size := Vector2(MAP_W * TS, MAP_H * TS)

# ---------- конфиг боя ----------
var faction_player := "sak"
var faction_enemy := "foa"
var sector_idx := 0
var sector_type := "outpost"
var heli_unlocked := false
var sound_marker_cd := 0.0
var radio_timer := 0.0
var heal_timer := 0.0
var end_timer := 0.0
var main_ref = null          # ссылка на main.gd (переходы между экранами)
var drag_start_screen := Vector2.ZERO  # рамка выделения в экранных координатах
var ambient_t := 5.0         # таймер «война вокруг»: дальние разрывы/всполохи

func setup(cfg: Dictionary) -> void:
        faction_player = cfg.get("faction_player", "sak")
        faction_enemy = cfg.get("faction_enemy", "foa")
        sector_idx = cfg.get("sector_idx", 0)
        sector_type = cfg.get("sector_type", "outpost")
        heli_unlocked = cfg.get("heli_unlocked", false)
        FAC_COL_P = G.FACTION_COLOR.get(faction_player, FAC_COL_P)
        FAC_COL_E = G.FACTION_COLOR.get(faction_enemy, FAC_COL_E)

func _ready() -> void:
        # ---------- слои ----------
        tile_layer = Node2D.new()
        prop_layer = Node2D.new()
        unit_layer = Node2D.new()
        proj_layer = Node2D.new()
        fx_layer = Node2D.new()
        fog_layer = Node2D.new()
        for l in [tile_layer, prop_layer, unit_layer, proj_layer, fx_layer, fog_layer]:
                add_child(l)
        fog_layer.z_index = 40
        # приглушённая мрачная палитра (север, дым)
        var cm := CanvasModulate.new()
        cm.color = Color(0.885, 0.885, 0.86)
        add_child(cm)
        # камера
        camera = Camera2D.new()
        camera.position = Vector2(map_size.x / 2.0, map_size.y * 0.75)
        camera.zoom = Vector2(cam_zoom, cam_zoom)
        camera.position_smoothing_enabled = true
        camera.position_smoothing_speed = 8.0
        add_child(camera)
        camera.make_current()
        # эффекты
        fx = FxScript.new()
        fx_layer.add_child(fx)
        fx.setup(self)
        # ---------- генерация карты ----------
        var gen = MapGen.generate(self, 1000 + sector_idx * 77 + randi() % 1000, sector_type)
        points = gen["points"]
        fob_player = gen["fob_player"]
        fob_enemy = gen["fob_enemy"]
        _init_fog()
        # ---------- динамическая территория (WorldBox-стиль) ----------
        territory = TerrScript.new()
        add_child(territory)
        territory.z_index = 1
        territory.z_as_relative = false
        territory.setup(self)
        # ---------- флаги и маркеры точек ----------
        for p in points:
                var flag := Sprite2D.new()
                flag.texture = G.tex("prop_flag")
                flag.position = p["pos"] + Vector2(0, -10)
                flag.z_index = 4
                prop_layer.add_child(flag)
                p["flag"] = flag
                var ring := Sprite2D.new()
                ring.texture = G.tex("fx_ring_big")
                ring.scale = Vector2(7.4, 7.4)
                ring.position = p["pos"]
                ring.z_index = 2
                ring.modulate = Color(0.9, 0.9, 0.85, 0.35)
                prop_layer.add_child(ring)
                p["ring"] = ring
        # ---------- стартовые армии ----------
        _spawn_enemy_army()
        # ---------- катсцена приезда: конвой КамАЗов доставляет группу ----------
        _start_arrival_cutscene()
        # ---------- UI и ИИ ----------
        ui = UIScript.new()
        add_child(ui)
        ui.setup(self)
        ai = AIScript.new()
        add_child(ai)
        ai.setup(self)
        # вступительный радио-лог
        add_log("ШТАБ: Операция начата. Сектор: " + G.SECTORS[sector_idx]["name"], Color(0.8, 0.85, 0.7))
        add_log("ШТАБ: Захватите и удерживайте точки. Противник: " + G.FACTION_NAMES[faction_enemy], Color(0.8, 0.85, 0.7))
        if G.save["upgrades"].get("prep", false):
                ability_cd["_ab_arty"] = 0.0

# ================= СТАРТ АРМИЙ =================
func _spawn_enemy_army() -> void:
        var ef: String = faction_enemy
        _spawn_unit(_any_id(ef, ["rifle", "militia", "m4"]), G.TEAM_ENEMY, fob_enemy + Vector2(-80, -40))
        _spawn_unit(_any_id(ef, ["mg", "militia", "m4", "m2", "assault"]), G.TEAM_ENEMY, fob_enemy + Vector2(80, -40))
        _spawn_unit(_any_id(ef, ["brdm", "tech_mg", "recon"]), G.TEAM_ENEMY, fob_enemy + Vector2(0, -110))
        _spawn_unit(_any_id(ef, ["ural", "supply"]), G.TEAM_ENEMY, fob_enemy + Vector2(160, -60))
        # враг сразу живёт: обороняющиеся группы выдвигаются к своим точкам
        for u in units:
                if is_instance_valid(u) and u.alive and u.team == G.TEAM_ENEMY and u.def["kind"] != "veh":
                        var gp := _nearest_objective(u, G.TEAM_ENEMY)
                        u.set_order_amove(gp)

# ближайшая цель наступления: незахваченная/вражеская точка или ФОБ противника
func _nearest_objective(u, for_team: int) -> Vector2:
        var best := Vector2.ZERO
        var bd := 1e18
        var foe_fob: Vector2 = fob_enemy if for_team == G.TEAM_PLAYER else fob_player
        for p in points:
                var want_capture: bool = (p["owner"] != for_team)
                if not want_capture:
                        continue
                var d: float = u.global_position.distance_to(p["pos"])
                if d < bd:
                        bd = d
                        best = p["pos"]
        if bd > 9e17:
                best = foe_fob   # все точки наши — давим на базу
        return clamp_to_map(best)

func _any_id(fac: String, roles: Array) -> String:
        for r in roles:
                var full: String = fac + "_" + r
                if G.DB.has(full):
                        return full
        # ищем по role
        for id in G.DB:
                if id.begins_with("_"):
                        continue
                var d: Dictionary = G.DB[id]
                if d["fac"] == fac and roles.has(d["role"]):
                        return id
        return fac + "_militia" if G.DB.has(fac + "_militia") else fac + "_rifle"

func _spawn_unit(id: String, team: int, pos: Vector2):
        if not G.DB.has(id):
                return null
        var u = UnitScript.new()
        unit_layer.add_child(u)
        u.setup(id, team, self)
        u.global_position = clamp_to_map(pos)
        u.facing = 0.0 if team == G.TEAM_PLAYER else PI
        units.append(u)
        if u.def.get("hero", false):
                cmdr = u
        return u

# ================= КАТСЦЕНА ПРИЕЗДА: КОЛОННА КАМАЗОВ =================
func _start_arrival_cutscene() -> void:
        cutscene = true
        var pf: String = faction_player
        var base := fob_player
        # состав группы игрока (как раньше — но теперь её привозит конвой)
        var group: Array = []
        group.append({"id": _any_id(pf, ["rifle", "m4", "militia"]), "dest": base + Vector2(-80, 40)})
        group.append({"id": _any_id(pf, ["mg", "militia", "m4", "m2", "assault"]), "dest": base + Vector2(80, 40)})
        group.append({"id": _any_id(pf, ["brdm", "tech_mg", "recon"]), "dest": base + Vector2(0, 110), "drive": true})
        group.append({"id": _any_id(pf, ["ural", "supply"]), "dest": base + Vector2(-160, 60), "drive": true})
        # КОМАНДИР прибывает вместе с колонной — за него играем
        if G.DB.has(pf + "_cmdr"):
                group.append({"id": pf + "_cmdr", "dest": base + Vector2(0, -40), "hero": true})
        var kit: int = G.save["kit"]
        if kit == 0 and G.DB.has(pf + "_rifle"):
                group.append({"id": pf + "_rifle", "dest": base + Vector2(-240, 60)})
                group.append({"id": pf + "_rifle", "dest": base + Vector2(240, 60)})
        elif kit == 1:
                group.append({"id": _any_id(pf, ["brdm", "tech_mg", "recon"]), "dest": base + Vector2(-260, 30), "drive": true})
                group.append({"id": _any_id(pf, ["sniper"]), "dest": base + Vector2(260, 30)})
                req += 200.0
        if G.save["upgrades"].get("scouts", false):
                group.append({"id": _any_id(pf, ["brdm", "tech_mg", "recon"]), "dest": base + Vector2(-330, 30), "drive": true})
        # пехота — в грузовики, техника — сама в колонне
        var inf: Array = []
        var veh: Array = []
        for g in group:
                if g.has("drive"):
                        veh.append(g)
                else:
                        inf.append(g)
        # КамАЗов — столько, сколько нужно: по отделению в кузов
        for ti in range(inf.size()):
                _make_truck(ti, [inf[ti]])
        # техника подъезжает сама, замыкая колонну
        for vi in range(veh.size()):
                var g2: Dictionary = veh[vi]
                var u = _spawn_unit(g2["id"], G.TEAM_PLAYER, Vector2(base.x - 120 + vi * 90, map_size.y - 140 - vi * 26))
                if u != null:
                        u.set_order_move(g2["dest"])
        # открываем обзор: район ФОБ и коридор въезда колонны
        _reveal_cells(base, 1050.0)
        for ti2 in range(inf.size()):
                var lane_x2: float = base.x + (-110.0 + ti2 * 110.0)
                _reveal_cells(Vector2(lane_x2, map_size.y - 260.0), 620.0)
        _update_fog_image()
        # камера у южного въезда
        camera.position = Vector2(base.x, map_size.y - 300.0)
        camera.position_smoothing_enabled = false
        # ротор двигателя колонны
        var ep := "res://assets/sfx/engine_loop.wav"
        if ResourceLoader.exists(ep):
                var st: AudioStreamWAV = load(ep)
                if st != null:
                        st.loop_mode = AudioStreamWAV.LOOP_FORWARD
                        st.loop_begin = 0
                        st.loop_end = st.data.size() / 2
                        engine_player = AudioStreamPlayer.new()
                        engine_player.stream = st
                        engine_player.bus = "SFX"
                        engine_player.volume_db = -12.0
                        add_child(engine_player)
                        engine_player.play()

func _make_truck(idx: int, deliver: Array) -> void:
        var pf: String = faction_player
        var base := fob_player
        var lane_x: float = base.x + (-110.0 + idx * 110.0)
        var start := Vector2(lane_x, map_size.y + 240.0 + idx * 42.0)
        var park := clamp_to_map(Vector2(lane_x, base.y + 150.0 + idx * 30.0))
        var node := Node2D.new()
        unit_layer.add_child(node)
        var sh := Sprite2D.new()
        var sh_tex = G.tex("veh_kamaz_" + pf + "_sh")
        if sh_tex != null:
                sh.texture = sh_tex
                sh.position = Vector2(0, 3)
                sh.z_index = -1
                node.add_child(sh)
        var body := Sprite2D.new()
        var b_tex = G.tex("veh_kamaz_" + pf)
        if b_tex != null:
                body.texture = b_tex
        node.add_child(body)
        var dests: Array = []
        for d in deliver:
                dests.append(d["dest"])
        convoy.append({
                "node": node, "from": start, "to": park,
                "t": -float(idx) * 0.9, "dur": maxf(0.6, (start.y - park.y) / 300.0),
                "state": "in", "deliver": deliver, "dests": dests,
                "unloaded": false,
        })

func _tick_cutscene(delta: float) -> void:
        var cam_target := fob_player
        var cam_set := false
        for e in convoy.duplicate():
                var n = e["node"]
                if not is_instance_valid(n):
                        convoy.erase(e)
                        continue
                e["t"] += delta
                if e["t"] < 0.0:
                        continue
                match e["state"]:
                        "in":
                                var k: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
                                n.position = e["from"].lerp(e["to"], k)
                                n.rotation = -PI / 2.0
                                if randf() < 0.4:
                                        spawn_tracks(n.position + Vector2(randf_range(-8, 8), 12), -PI / 2.0)
                                if not cam_set or k > 0.15:
                                        cam_target = n.position + Vector2(0, -180)
                                        cam_set = true
                                if k >= 1.0:
                                        e["state"] = "unload"
                                        e["t"] = 0.0
                                        fx.puff(n.position + Vector2(0, -16), 2)
                        "unload":
                                if e["t"] > 0.45 and not e["unloaded"]:
                                        e["unloaded"] = true
                                        _unload_truck(e)
                                if e["t"] > 2.1:
                                        e["state"] = "out"
                                        e["from"] = n.position
                                        e["to"] = Vector2(n.position.x + randf_range(-100, 100), map_size.y + 340.0)
                                        e["dur"] = maxf(0.6, (e["to"].y - n.position.y) / 330.0)
                                        e["t"] = 0.0
                                        G.play_sfx("engine_loop", -14.0, 1.1)
                        "out":
                                var k2: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
                                n.rotation = PI / 2.0
                                n.position = e["from"].lerp(e["to"], k2)
                                if randf() < 0.3:
                                        spawn_tracks(n.position + Vector2(randf_range(-8, 8), 12), PI / 2.0)
                                if k2 >= 1.0:
                                        n.queue_free()
                                        convoy.erase(e)
        # камера ведёт колонну, затем возвращается к ФОБ
        if cam_set:
                camera.position = camera.position.lerp(cam_target, minf(1.0, delta * 3.5))
        else:
                camera.position = camera.position.lerp(fob_player + Vector2(0, -60), minf(1.0, delta * 2.5))
        camera.position.y = clampf(camera.position.y, 400.0, map_size.y - 260.0)
        camera.position.x = clampf(camera.position.x, 400.0, map_size.x - 400.0)
        # конец: колонна убыла
        cut_end_t += delta
        if convoy.is_empty() and cut_end_t > 1.5:
                _finish_cutscene(false)

func _unload_truck(e: Dictionary) -> void:
        var n = e["node"]
        var at: Vector2 = n.position if is_instance_valid(n) else e["dests"][0]
        var di := 0
        for d in e["deliver"]:
                var u = _spawn_unit(d["id"], G.TEAM_PLAYER, at + Vector2(-34 + di * 68, -26))
                if u != null:
                        u.set_order_move(e["dests"][di])
                        u.facing = -PI / 2.0
                di += 1
        fx.puff(at + Vector2(0, -20), 2)
        G.play_sfx("radio", -16.0, 1.2)

func _finish_cutscene(skipped: bool) -> void:
        if cut_done:
                return
        cut_done = true
        if skipped:
                # мгновенно: всё недовезённое появляется на позициях
                for e in convoy:
                        if not e["unloaded"]:
                                var spawn_at: Vector2 = e["dests"][0] if e["state"] == "in" else e["node"].position
                                var di := 0
                                for d in e["deliver"]:
                                        var u = _spawn_unit(d["id"], G.TEAM_PLAYER, spawn_at + Vector2(-20 + di * 40, -20))
                                        if u != null:
                                                u.set_order_move(e["dests"][di])
                                        di += 1
                        if is_instance_valid(e["node"]):
                                e["node"].queue_free()
                convoy.clear()
        cutscene = false
        camera.position_smoothing_enabled = true
        if engine_player != null and is_instance_valid(engine_player):
                engine_player.stop()
                engine_player.queue_free()
                engine_player = null
        if ui != null:
                ui.on_cutscene_end()
        add_log("ШТАБ: Группа на позициях, конвой убыл на юг.", Color(0.8, 0.85, 0.7))
        add_log("ШТАБ: Стики в углах экрана: левый — ход, правый — прицел; толкни до упора — огонь.", Color(0.95, 0.85, 0.5))
        add_log("ШТАБ: Отряды наступают сами. Кнопкой ПРИКАЗ корректируйте их действия.", Color(0.75, 0.82, 0.65))
        # ---------- АВТОНОМНЫЙ СТАРТ: все сами идут воевать ----------
        for u in units:
                if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and not u.def.get("hero", false):
                        _give_auto_order(u, true)
        # ---------- ВСТУПАЕМ В РОЛЬ КОМАНДИРА: twin-stick сразу ----------
        if is_instance_valid(cmdr) and cmdr.alive:
                enter_commander_mode()

# ================= РЕЖИМ КОМАНДИРА (twin-stick, всегда доступен) =================
func enter_commander_mode() -> void:
        if not is_instance_valid(cmdr) or not cmdr.alive:
                return
        if mounted_in_valid(cmdr):
                _switch_direct_to(cmdr.mounted_in)
                return
        _switch_direct_to(cmdr)

func _switch_direct_to(u) -> void:
        direct_unit = u
        direct_ctrl = true
        direct_vec = Vector2.ZERO
        manual_aim = false
        manual_fire = false
        _stick_move_idx = -1
        _stick_aim_idx = -1
        _prev_zoom = cam_zoom
        cam_zoom = 0.95            # дальше от солдата: видно поле боя
        camera.zoom = Vector2(cam_zoom, cam_zoom)
        camera.position = u.global_position
        for other in selection:
                if is_instance_valid(other):
                        other.selected = false
                        other.ring.visible = false
        selection = [u]
        u.selected = true
        u.ring.visible = true
        if ui != null:
                ui.show_direct(true, u)

func mounted_in_valid(u) -> bool:
        return u != null and u.mounted_in != null and is_instance_valid(u.mounted_in)

func _cmdr_tick(delta: float) -> void:
        # респаун командира: замещающий офицер прибывает на ФОБ
        if cmdr_respawn > 0.0:
                cmdr_respawn -= delta
                if cmdr_respawn <= 0.0:
                        var pf: String = faction_player
                        var u = _spawn_unit(pf + "_cmdr", G.TEAM_PLAYER, fob_player + Vector2(0, 40))
                        if u != null:
                                u.facing = -PI / 2.0
                                fx.puff(u.global_position, 2)
                                enter_commander_mode()
                                add_log("ШТАБ: Заместитель принял командование. Месседж: «Заря-1, в строй!»", Color(0.7, 0.9, 0.6))
                                G.play_sfx("radio", -4.0)
        # командир вне прямого управления — не принуждаем: F переключает штаб/командир
        pass

func _mounted_hero_vehicle():
        if is_instance_valid(cmdr) and cmdr.mounted_in != null and is_instance_valid(cmdr.mounted_in):
                return cmdr.mounted_in
        return null

# ================= АВТОНОМНОЕ НАСТУПЛЕНИЕ (WorldBox-стиль) =================
func _give_auto_order(u, first := false) -> void:
        var obj := _nearest_objective(u, u.team)
        # ШИРОКИЙ ФРОНТ: отряды наступают вразнобой по широкой полосе,
        # а не сходятся в одну «стаю» на вершине точки
        var spread := Vector2(randf_range(-170, 170), randf_range(-120, 120))
        u.set_order_amove(clamp_to_map(obj + spread))
        u.last_auto_t = stats["time"]
        if first:
                u.last_player_order_t = -100.0

func _tick_auto_doctrine(delta: float) -> void:
        # отряды, стоящие без дела, сами выдвигаются к фронту и ищут бой
        if not auto_on:
                return
        auto_tick -= delta
        if auto_tick > 0.0:
                return
        auto_tick = 5.0
        for u in units:
                if not is_instance_valid(u) or not u.alive or u.def.get("hero", false):
                        continue
                if u.mounted_in != null:
                        continue
                # снабжение не бросается в огонь: держит тыл
                if u.def["kind"] == "veh" and u.def.get("role", "") == "supply":
                        continue
                # техника ждёт пехоту рядом; пустые БТР/технички едут сами
                if u.def["kind"] == "veh" and _friendly_inf_near(u, 300.0) and u.order["type"] == "idle":
                        continue
                var idle: bool = u.order["type"] == "idle" or (u.order["type"] == "amove" and stats["time"] - float(u.last_auto_t) > 22.0)
                if not idle:
                        continue
                if stats["time"] - float(u.last_player_order_t) < 9.0:
                        continue   # свежий приказ игрока — не мешаем
                if u.garrison_obj != null:
                        continue
                _give_auto_order(u)

func _friendly_inf_near(u, radius: float) -> bool:
        for o in units:
                if is_instance_valid(o) and o.alive and o.team == u.team and o.def["kind"] == "inf" and o.mounted_in == null and o != u:
                        if o.global_position.distance_to(u.global_position) < radius:
                                return true
        return false

# ================= ПОСАДКА В ТРАНСПОРТ =================
func veh_capacity(def: Dictionary) -> int:
        # сколько пехотных отделений влезает (отряд = 1 место)
        if def["kind"] != "veh":
                return 0
        match def.get("role", ""):
                "apc", "ifv":
                        return 2
                "supply":
                        return 3
                "recon", "cmd":
                        return 1
                _:
                        return 0

func issue_board(veh) -> void:
        if cutscene or not is_instance_valid(veh) or not veh.alive:
                return
        var cap := veh_capacity(veh.def)
        if cap <= 0:
                add_log("Эта техника не возит пехоту", Color(0.8, 0.8, 0.6))
                return
        var free: int = cap - int(veh.passengers.size())
        if free <= 0:
                add_log("В технике нет мест — она полная", Color(0.9, 0.6, 0.4))
                return
        var n := 0
        for u in _valid_selection():
                if u.def["kind"] != "inf" or u == veh or u.mounted_in == veh:
                        continue
                if n >= free:
                        break
                u.set_order_board(veh)
                n += 1
        if n > 0:
                # машина ждёт: пока пехота садится, водитель стоит
                veh.set_order_stop()
                veh.last_player_order_t = stats["time"]
                add_log("ПОСАДКА: %d — в машину «%s»" % [n, veh.def["name"]], Color(0.7, 0.85, 0.7))
                G.play_sfx("radio", -8.0)

func nearest_boardable(pos: Vector2, radius := 150.0):
        var best = null
        var bd := radius
        for u in units:
                if not is_instance_valid(u) or not u.alive or u.team != G.TEAM_PLAYER or u.def["kind"] != "veh":
                        continue
                if veh_capacity(u.def) - u.passengers.size() <= 0:
                        continue
                var d: float = pos.distance_to(u.global_position)
                if d < bd:
                        bd = d
                        best = u
        return best

# командир: сесть в технику рядом / выйти из неё
func cmdr_board_exit() -> void:
        if cutscene or battle_over != "":
                return
        if not is_instance_valid(cmdr) or not cmdr.alive:
                return
        if cmdr.mounted_in != null and is_instance_valid(cmdr.mounted_in):
                var veh = cmdr.mounted_in
                cmdr.dismount()
                if direct_unit == veh:
                        _switch_direct_to(cmdr)
                add_log("КОМАНДИР: вышел из машины — снова в строй на своих двоих", Color(0.8, 0.9, 0.7))
                G.play_sfx("ui_click", -6.0)
                return
        var veh2 = nearest_boardable(cmdr.global_position, 150.0)
        if veh2 == null:
                add_log("КОМАНДИР: рядом нет свободной техники (подъезжте ближе)", Color(0.9, 0.7, 0.5))
                return
        cmdr.set_order_board(veh2)
        add_log("КОМАНДИР: садится в «%s» — джойстики переключатся на машину" % veh2.def["name"], Color(0.7, 0.85, 0.7))
        G.play_sfx("radio", -8.0)

# ================= ОБРАБОТКА ПОСАДКИ (вызывается из unit.gd) =================
func on_mount(inf, veh) -> void:
        if inf.def.get("hero", false) and inf.team == G.TEAM_PLAYER:
                _switch_direct_to(veh)
                add_log("КОМАНДИР за рулём «%s»: левый стик — руль, правый — башня/огонь. G — выйти" % veh.def["name"], Color(0.95, 0.85, 0.5))

func on_dismount(inf, dangerous: bool) -> void:
        if dangerous:
                fx.puff(inf.global_position, 1)
                if inf.def.get("hero", false) and inf.team == G.TEAM_PLAYER and inf.alive:
                        # командир выжил в горящей технике — стики сразу возвращаются к нему
                        _switch_direct_to(inf)
                        add_log("КОМАНДИР: выбрался из горящей машины — снова в строю!", Color(0.95, 0.8, 0.4))
        if inf.def.get("hero", false) and inf.team == G.TEAM_PLAYER and not dangerous:
                pass   # переключение делает cmdr_board_exit

# ================= ПРЯМОЕ УПРАВЛЕНИЕ ОТРЯДОМ =================
func toggle_direct() -> void:
        if cutscene or battle_over != "":
                return
        if direct_ctrl:
                _exit_direct()
                return
        # по умолчанию берём управление КОМАНДИРОМ — мы играем за него
        if is_instance_valid(cmdr) and cmdr.alive:
                enter_commander_mode()
                return
        var sel := _valid_selection()
        if sel.is_empty():
                add_log("Командир павший. Управление вернётся с заместителем.", Color(0.9, 0.6, 0.5))
                return
        var u = sel[0]
        if u.def["kind"] == "drone":
                add_log("Дронами нельзя управлять напрямую.", Color(0.9, 0.6, 0.5))
                return
        _switch_direct_to(u)
        add_log("ПРЯМОЕ УПРАВЛЕНИЕ: левый стик — движение, правый — прицел; толкни до упора — огонь.", Color(0.95, 0.8, 0.4))

func _exit_direct() -> void:
        direct_ctrl = false
        direct_vec = Vector2.ZERO
        joy_active = false
        manual_aim = false
        manual_fire = false
        r_joy_active = false
        _r_fire_latch = false
        _stick_move_idx = -1
        _stick_aim_idx = -1
        cam_zoom = _prev_zoom
        camera.zoom = Vector2(cam_zoom, cam_zoom)
        for e in units:
                if is_instance_valid(e):
                        e.modulate.a = 1.0
        if is_instance_valid(direct_unit):
                direct_unit.set_order_stop()
        direct_unit = null
        if ui != null:
                ui.show_direct(false, null)

# ================= ТЕКСТУРЫ ТАЙЛОВ =================
var _tt_cache := {}
func tile_tex_for(x: int, y: int) -> Texture2D:
        var t: int = tiles[y][x]
        # вариант половины дороги/моста/квадранта перекрёстка задан картой
        var tv: String = ""
        if y < tvar.size() and x < (tvar[y] as Array).size():
                tv = tvar[y][x]
        var vidx: int = (x * 7 + y * 13) % 2
        if tv != "":
                var key := tv + str(vidx)
                if not _tt_cache.has(key):
                        var nm := "tile_grass_v0"
                        match tv:
                                "hn": nm = "tile_road_hn%d" % vidx
                                "hs": nm = "tile_road_hs%d" % vidx
                                "vw": nm = "tile_road_vw%d" % vidx
                                "ve": nm = "tile_road_ve%d" % vidx
                                "x_nw": nm = "tile_road_xnw%d" % vidx
                                "x_ne": nm = "tile_road_xne%d" % vidx
                                "x_sw": nm = "tile_road_xsw%d" % vidx
                                "x_se": nm = "tile_road_xse%d" % vidx
                                "bhn": nm = "tile_bridge_hn%d" % vidx
                                "bhs": nm = "tile_bridge_hs%d" % vidx
                                "bvw": nm = "tile_bridge_vw%d" % vidx
                                "bve": nm = "tile_bridge_ve%d" % vidx
                        _tt_cache[key] = G.tex(nm)
                return _tt_cache[key]
        match t:
                T_ROAD:
                        return _plain_tile("tile_road_hn%d" % vidx, t, vidx)
                T_DROAD:
                        var h := _same(x - 1, y, t) or _same(x + 1, y, t)
                        return _plain_tile("tile_droad_h" if h else "tile_droad_v", t, 0)
                T_BRIDGE:
                        return _plain_tile("tile_bridge_hn0", t, 0)
                T_TRENCH:
                        var h2 := _same(x - 1, y, t) or _same(x + 1, y, t)
                        return _plain_tile("tile_trench_h" if h2 else "tile_trench_v", t, 0)
                _:
                        var names := {
                                T_GRASS: "tile_grass_v%d" % ((x * 3 + y * 5) % 4),
                                T_GRASS2: "tile_grass2_v%d" % ((x + y) % 2),
                                T_DRY: "tile_dry",
                                T_DIRT: "tile_dirt_v%d" % ((x * 5 + y) % 2),
                                T_FIELD: "tile_field_v%d" % ((x + y) % 2),
                                T_FIELD2: "tile_field_v%d" % ((x + y + 1) % 2),
                                T_FOREST: "tile_forest_v%d" % ((x * 3 + y) % 2),
                                T_WATER: "tile_water",
                                T_URBAN: "tile_urban_v%d" % ((x + y) % 2),
                                T_CONCRETE: "tile_concrete",
                                T_RUBBLE: "tile_rubble",
                                T_MUD: "tile_mud",
                        }
                        return _plain_tile(names.get(t, "tile_grass_v0"), t, 0)

func _plain_tile(nm: String, t: int, vi: int) -> Texture2D:
        var key := nm + "#" + str(t) + "_" + str(vi)
        if not _tt_cache.has(key):
                var tex = G.tex(nm)
                if tex == null:
                        tex = G.tex("tile_grass_v0")
                _tt_cache[key] = tex
        return _tt_cache[key]

func _same(x: int, y: int, t: int) -> bool:
        if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
                return false
        return tiles[y][x] == t

# ================= ПОИСК УКРЫТИЯ (для ИИ бойца) =================
func find_cover(pos: Vector2, radius: float) -> Vector2:
        var best := Vector2.INF
        var best_score := -1e9
        var r: int = int(radius / TS) + 1
        var cx := int(pos.x / TS)
        var cy := int(pos.y / TS)
        for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                        var x := cx + dx
                        var y := cy + dy
                        if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
                                continue
                        var t: int = tiles[y][x]
                        var sc := -1.0
                        match t:
                                T_TRENCH: sc = 10.0
                                T_FOREST: sc = 7.0
                                T_RUBBLE: sc = 6.0
                                T_URBAN: sc = 5.0
                                T_MUD: sc = 2.0
                                T_CONCRETE: sc = 1.5
                        if sc <= 0.0:
                                continue
                        var cpos := Vector2((x + 0.5) * TS, (y + 0.5) * TS)
                        var d: float = pos.distance_to(cpos)
                        if d > radius:
                                continue
                        var score: float = sc * 100.0 - d
                        if score > best_score:
                                best_score = score
                                best = cpos
        return best

# ================= ЛАНДШАФТ =================
func tile_at(pos: Vector2) -> int:
        var x := int(pos.x / TS)
        var y := int(pos.y / TS)
        if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
                return T_GRASS
        return tiles[y][x]

func terrain_speed(pos: Vector2, is_air: bool) -> float:
        if is_air:
                return 1.0
        match tile_at(pos):
                T_ROAD: return 1.25
                T_DROAD: return 1.1
                T_CONCRETE: return 1.1
                T_BRIDGE: return 1.05
                T_FIELD, T_FIELD2: return 0.85
                T_DIRT: return 0.92
                T_URBAN: return 0.85
                T_RUBBLE: return 0.7
                T_FOREST: return 0.55
                T_MUD: return 0.5
                T_TRENCH:
                        return 0.9
                _: return 1.0

func tile_blocked(pos: Vector2) -> bool:
        return tile_at(pos) == T_WATER

func clamp_to_map(p: Vector2) -> Vector2:
        return Vector2(clampf(p.x, 40, map_size.x - 40), clampf(p.y, 40, map_size.y - 40))

# ================= РУЛЕНИЕ =================
func steer(u, dir: Vector2) -> Vector2:
        var force := dir
        # препятствия
        for o in obstacles:
                var d: float = u.global_position.distance_to(o["pos"])
                var rr: float = o["r"] + u.def["radius"] + 24.0
                if d < rr and d > 1.0:
                        var away: Vector2 = (u.global_position - o["pos"]).normalized()
                        force += away * (1.0 - d / rr) * 1.8
        # расталкивание своих
        for other in units:
                if other == u or not is_instance_valid(other) or not other.alive or other.air != u.air:
                        continue
                var d2: float = u.global_position.distance_to(other.global_position)
                var want: float = u.def["radius"] + other.def["radius"] + 8.0
                if d2 < want and d2 > 0.5:
                        force += (u.global_position - other.global_position).normalized() * (1.0 - d2 / want) * 1.2
        # впереди вода → объезд
        var ahead: Vector2 = u.global_position + dir * 70.0
        if tile_blocked(ahead):
                var left := dir.rotated(1.2)
                var right := dir.rotated(-1.2)
                if not tile_blocked(u.global_position + left * 80.0):
                        force = left
                elif not tile_blocked(u.global_position + right * 80.0):
                        force = right
                else:
                        force = -dir
        return force.normalized() if force.length() > 0.01 else dir

# ================= ВИДИМОСТЬ =================
func _init_fog() -> void:
        explored = []
        visible_cells = []
        for y in range(fog_h):
                var er := []
                var vr := []
                for x in range(fog_w):
                        er.append(false)
                        vr.append(false)
                explored.append(er)
                visible_cells.append(vr)
        fog_img = Image.create_empty(fog_w, fog_h, false, Image.FORMAT_RGBA8)
        fog_tex = ImageTexture.create_from_image(fog_img)
        fog_sprite = Sprite2D.new()
        fog_sprite.texture = fog_tex
        fog_sprite.centered = false
        fog_sprite.scale = Vector2(FOG_CELL, FOG_CELL)
        fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        fog_sprite.z_index = 0
        fog_layer.add_child(fog_sprite)
        _update_fog_image()

func conceal_mult(target) -> float:
        var m := 1.0
        match tile_at(target.global_position):
                T_FOREST: m = 0.42
                T_TRENCH: m = 0.34
                T_URBAN, T_RUBBLE: m = 0.6
                T_MUD: m = 0.75
        m /= maxf(0.5, target.def.get("stealth", 1.0))
        return m

func smoke_blocks(a: Vector2, b: Vector2) -> bool:
        for sc in fx.smoke_cols:
                var sc_pos: Vector2 = sc["pos"]
                var rr: float = sc["r"] * 0.8
                # расстояние от центра дыма до отрезка
                var ab := b - a
                var t := clampf((sc_pos - a).dot(ab) / maxf(1.0, ab.length_squared()), 0.0, 1.0)
                var closest := a + ab * t
                if closest.distance_to(sc_pos) < rr:
                        return true
        return false

func _update_visibility() -> void:
        vis_player.clear()
        vis_enemy.clear()
        # сброс ячеек видимости
        for y in range(fog_h):
                var row: Array = visible_cells[y]
                for x in range(fog_w):
                        row[x] = false
        for u in units:
                if not is_instance_valid(u) or not u.alive:
                        continue
                var vision: float = u.def["vision"]
                # КШМ-аура: +12% обзора
                if cmd_aura_for(u.global_position, u.team):
                        vision *= 1.12
                # открываем клетки тумана (только игрок рисует туман)
                if u.team == G.TEAM_PLAYER:
                        _reveal_cells(u.global_position, vision)
                # кого видит этот юнит
                for e in units:
                        if e == u or not is_instance_valid(e) or not e.alive or e.team == u.team:
                                continue
                        var d: float = u.global_position.distance_to(e.global_position)
                        var rng: float = vision * conceal_mult(e)
                        if e.loud_t > 0.0:
                                rng = maxf(rng, 900.0)
                        if d <= rng and not smoke_blocks(u.global_position, e.global_position):
                                if u.team == G.TEAM_PLAYER:
                                        vis_player[e] = true
                                else:
                                        vis_enemy[e] = true
        # прячем врагов, невидимых игроку (туман войны — честный)
        for e in units:
                if not is_instance_valid(e) or not e.alive:
                        continue
                if e.team == G.TEAM_ENEMY:
                        e.visible = vis_player.has(e) and not unit_hidden_for_player(e)
                else:
                        e.visible = true
        _update_fog_image()

func _reveal_cells(pos: Vector2, vision: float) -> void:
        var cx := int(pos.x / FOG_CELL)
        var cy := int(pos.y / FOG_CELL)
        var r := int(vision / FOG_CELL) + 1
        for y in range(maxi(0, cy - r), mini(fog_h, cy + r + 1)):
                for x in range(maxi(0, cx - r), mini(fog_w, cx + r + 1)):
                        var dist := Vector2((x + 0.5) * FOG_CELL - pos.x, (y + 0.5) * FOG_CELL - pos.y).length()
                        if dist <= vision:
                                visible_cells[y][x] = true
                                explored[y][x] = true

func _update_fog_image() -> void:
        if fog_img == null:
                return
        for y in range(fog_h):
                for x in range(fog_w):
                        if visible_cells[y][x]:
                                fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
                        elif explored[y][x]:
                                fog_img.set_pixel(x, y, Color(0.05, 0.05, 0.04, 0.55))
                        else:
                                fog_img.set_pixel(x, y, Color(0.03, 0.03, 0.03, 0.92))
        fog_tex.update(fog_img)

func is_visible_to_player(u) -> bool:
        return u.team == G.TEAM_PLAYER or vis_player.has(u)

func unit_hidden_for_player(u) -> bool:
        # гарнизон/окоп: враг невидим, если не подпущен вплотную
        if u.team == G.TEAM_PLAYER:
                return false
        if u.in_cover or u.garrison_obj != null:
                for p in units:
                        if is_instance_valid(p) and p.alive and p.team == G.TEAM_PLAYER:
                                if p.global_position.distance_to(u.global_position) < 190.0:
                                        return false
                return true
        return false

# ================= ПОИСК ЦЕЛЕЙ =================
func find_target(shooter):
        var best = null
        var best_score := -1e9
        var vis_set: Dictionary = vis_player if shooter.team == G.TEAM_PLAYER else vis_enemy
        for e in units:
                if not is_instance_valid(e) or not e.alive or e.team == shooter.team:
                        continue
                if e.mounted_in != null:
                        continue   # пехота в технике — цель машина, а не пассажиры
                if shooter.team == G.TEAM_PLAYER:
                        if not vis_player.has(e):
                                continue
                else:
                        if not vis_enemy.has(e):
                                continue
                # оружие: чем стрелять?
                var can_hit := false
                var pref := 0.0
                for w in shooter.def["wpns"]:
                        if w["only"] == "air" and not e.air:
                                continue
                        if w["only"] == "ground" and e.air:
                                continue
                        if w["k"] == "kamikaze":
                                continue
                        var d: float = shooter.global_position.distance_to(e.global_position)
                        if d > w["rng"]:
                                continue
                        var min_rng: float = shooter.def.get("min_rng", 0.0)
                        if d < min_rng:
                                continue
                        can_hit = true
                        # приоритет цели
                        match w["ap"]:
                                "apcr", "heat":
                                        pref = maxf(pref, {"heavy": 4.0, "med": 3.0, "light": 1.5, "none": 0.5}[e.def["armor"]])
                                "kinetic":
                                        pref = maxf(pref, {"heavy": 2.0, "med": 2.0, "light": 2.0, "none": 1.5}[e.def["armor"]])
                                "he", "frag":
                                        pref = maxf(pref, {"heavy": 0.5, "med": 1.0, "light": 2.0, "none": 3.0}[e.def["armor"]])
                                "sam":
                                        pref = 5.0
                if not can_hit:
                        continue
                var d2: float = shooter.global_position.distance_to(e.global_position)
                var score := pref * 100.0 - d2 * 0.08
                if score > best_score:
                        best_score = score
                        best = e
        return best

func cmd_aura_for(pos: Vector2, team: int) -> bool:
        for u in units:
                if is_instance_valid(u) and u.alive and u.team == team and u.def.get("cmd_aura", false):
                        if u.global_position.distance_to(pos) < 420.0:
                                return true
        return false

func find_target_in_cone(shooter, ang: float, rng: float):
        # цель в конусе ручного прицела (для twin-stick)
        var best = null
        var bd := 1e9
        for e in units:
                if not is_instance_valid(e) or not e.alive or e.team == shooter.team:
                        continue
                if e.air:
                        continue
                if e.mounted_in != null:
                        continue   # в машине стреляем по машине
                var d: float = shooter.global_position.distance_to(e.global_position)
                if d > rng:
                        continue
                # в тумане видим только близких (сами смотрим) или подсвеченных разведкой
                if d > 460.0 and not vis_player.has(e):
                        continue
                var ea: float = (e.global_position - shooter.global_position).angle()
                if absf(angle_difference(ea, ang)) > 0.55:
                        continue
                if d < bd:
                        bd = d
                        best = e
        return best

# ================= ЛОГИСТИКА: ЯЩИКИ И РАЗГРУЗКА =================
func spawn_crate(pos: Vector2) -> void:
        var s := Sprite2D.new()
        s.texture = G.tex("prop_crate")
        s.position = clamp_to_map(pos + Vector2(randf_range(-18, 18), randf_range(-14, 14)))
        s.z_index = 3
        fx_layer.add_child(s)
        crates.append({"node": s, "t": 120.0})
        add_log("Выпал ящик боеприпасов — подведите пехоту", Color(0.85, 0.8, 0.5))

func _tick_logistics(delta: float) -> void:
        # ящики снабжения: пополняют патроны рядом стоящей пехоте
        for i in range(crates.size() - 1, -1, -1):
                var c: Dictionary = crates[i]
                c["t"] -= delta
                if not is_instance_valid(c["node"]):
                        crates.remove_at(i)
                        continue
                if c["t"] <= 0.0:
                        c["node"].queue_free()
                        crates.remove_at(i)
                        continue
                for u in units:
                        if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and u.def["kind"] == "inf":
                                if u.global_position.distance_to(c["node"].position) < 70.0 and u.mags < u.mags_max * 0.98:
                                        u.resupply()
        # снабжение на разгрузке: Урал стоит — раздаёт патроны, лечит раны, пополняет аптечку
        for v in units:
                if not is_instance_valid(v) or not v.alive or v.team != G.TEAM_PLAYER:
                        continue
                if v.def.get("role", "") != "supply":
                        continue
                if v.vel.length() > 6.0:
                        continue   # на ходу разгрузка невозможна
                for u in units:
                        if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and u.def["kind"] == "inf":
                                if u.global_position.distance_to(v.global_position) < 180.0:
                                        if u.mags < u.mags_max * 0.98:
                                                u.resupply()
                # аптечка командира пополняется у снабжения
                if direct_ctrl and is_instance_valid(direct_unit) and direct_unit.global_position.distance_to(v.global_position) < 180.0:
                        for ik in cmd_items.keys():
                                var mx := 4 if ik == "band" else 3
                                cmd_items[ik] = mini(mx, int(cmd_items[ik]) + 1)

func _tick_booms(delta: float) -> void:
        # детонация боекомплекта: вторичные взрывы горящей техники
        for i in range(pending_booms.size() - 1, -1, -1):
                var b: Dictionary = pending_booms[i]
                b["t"] -= delta
                if b["t"] <= 0.0:
                        explosion_at(b["pos"] + Vector2(randf_range(-26, 26), randf_range(-20, 20)), b["dmg"], b["splash"], "he", b["src"])
                        fx.smoke_column(b["pos"], 9.0)
                        pending_booms.remove_at(i)

# ================= СНАРЯДЫ / ВЗРЫВЫ =================
func spawn_proj(cfg: Dictionary) -> void:
        var p := Node2D.new()
        p.set_script(ProjScript)
        proj_layer.add_child(p)
        p.setup(cfg, self)
        projs.append(p)

func explosion_at(at: Vector2, dmg: float, splash: float, ap: String, src) -> void:
        var size := 1
        if dmg >= 100:
                size = 2
        if splash >= 100:
                size = 3
        if splash <= 0:
                size = 0
        fx.explosion(at, size)
        shake(2.0 + size * 2.0)
        for u in units:
                if not is_instance_valid(u) or not u.alive:
                        continue
                var d: float = u.global_position.distance_to(at)
                var rr: float = maxf(splash, 34.0)
                if d <= rr + u.def["radius"]:
                        var fall := clampf(1.0 - d / (rr + u.def["radius"]), 0.25, 1.0)
                        u.take_damage(dmg * fall, ap, src)
                        u.add_suppression(22.0 * fall)
                elif d < rr * 2.2:
                        u.add_suppression(10.0)
        # мины взрываются цепочкой
        for m in mines.duplicate():
                if is_instance_valid(m["node"]) and m["armed"] and m["node"].global_position.distance_to(at) < splash:
                        m["armed"] = false
                        trigger_mine(m)

func shake(amt: float) -> void:
        shake_amt = minf(14.0, shake_amt + amt)

func spawn_tracks(pos: Vector2, facing: float) -> void:
        fx.add_decal("decal_tracks", pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), facing, 1.0)

func spawn_mine(pos: Vector2, team: int) -> void:
        var s := Sprite2D.new()
        s.texture = G.tex("prop_ied")
        s.position = clamp_to_map(pos) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
        s.z_index = 2
        fx_layer.add_child(s)
        mines.append({"node": s, "team": team, "armed": true})

func trigger_mine(m: Dictionary) -> void:
        explosion_at(m["node"].global_position, 170.0, 95.0, "heat", null)
        m["node"].queue_free()
        mines.erase(m)

# ================= СОБЫТИЯ ЮНИТОВ =================
func on_unit_fired(u) -> void:
        # звуковые маркеры по ТЗ 1.4: стреляющий враг вне прямой видимости
        if u.team == G.TEAM_ENEMY and sound_marker_cd <= 0.0 and not vis_player.has(u):
                sound_marker_cd = 0.8
                fx.sound_marker(u.global_position + Vector2(0, -20))
                if ui != null:
                        ui.add_sound_ping(u.global_position)

func on_unit_died(u, src) -> void:
        if not u.alive:
                return
        u.alive = false
        u.set_process(false)
        # пассажиры гибнущей техники: тяжёлый урон и выброс наружу
        if u.def["kind"] == "veh" and not u.passengers.is_empty():
                for p in u.passengers.duplicate():
                        if is_instance_valid(p):
                                p.dismount(true)
                                p.take_damage(randf_range(80.0, 140.0), "he", src)
                u.passengers.clear()
        # КОМАНДИР павший: ждём заместителя
        if u.def.get("hero", false) and u.team == G.TEAM_PLAYER:
                cmdr_respawn = CMDR_RESPAWN
                add_log("КОМАНДИР ПАВШИЙ! Заместитель прибудет на ФОБ через %d с..." % int(CMDR_RESPAWN), Color(0.95, 0.4, 0.35))
                tickets_player -= 60.0
        if direct_ctrl and u == direct_unit:
                # если командир был в технике — прямое управление вырубаем до респауна
                _exit_direct()
        if u.team == G.TEAM_ENEMY:
                stats["kills"] += 1
                tickets_enemy -= u.def["cost"] / 8.0
                if G.save["upgrades"].get("trophy", false):
                        req += u.def["cost"] * 0.1
        else:
                stats["losses"] += 1
                tickets_player -= u.def["cost"] / 8.0
        selection.erase(u)
        # стресс: гибель товарища потрясает соседние отряды (психология, ТЗ 4.6)
        if u.def["kind"] == "inf":
                for o in units:
                        if is_instance_valid(o) and o.alive and o.team == u.team and "soldiers" in o and not o.soldiers.is_empty():
                                if o.global_position.distance_to(u.global_position) < 420.0:
                                        o.buddy_died()
        # визуал смерти
        if u.def["kind"] in ["veh", "heli", "drone"]:
                if u.air:
                        fx.explosion(u.global_position, 2)
                else:
                        fx.wreck(u.global_position, u.def["hull"], u.facing)
                        # ДЕТОНАЦИЯ БОЕКОМПЛЕКТА: техника с боеукладом рвёт вторично
                        if u.def.get("cargo", false) or u.def["armor"] in ["med", "heavy"]:
                                var n_booms := 2 + randi() % 3
                                for bi in range(n_booms):
                                        pending_booms.append({"pos": u.global_position, "t": 0.35 + bi * randf_range(0.3, 0.7),
                                                "dmg": 60.0, "splash": 80.0, "src": null})
                        # снабжение гибнет — выбрасывает ящики боеприпасов
                        if u.def.get("role", "") == "supply":
                                for ci in range(2):
                                        spawn_crate(u.global_position)
        else:
                # пехота: добиваем выживших бойцов — каждый остаётся тушкой на земле
                if "soldiers" in u and not u.soldiers.is_empty():
                        for s in u.soldiers:
                                if s["alive"]:
                                        u._kill_soldier(s)
                else:
                        fx.puff(u.global_position, 1)
        var killer := "неизвестный"
        if src != null and is_instance_valid(src) and src != u:
                killer = src.def["name"]
        add_log(("УНИЧТОЖЕН: " if u.team == G.TEAM_ENEMY else "ПОТЕРЯ: ") + u.def["name"] + " (" + killer + ")",
                Color(0.5, 0.85, 0.5) if u.team == G.TEAM_ENEMY else Color(0.9, 0.5, 0.45))
        u.queue_free()

# ================= ПРИКАЗЫ ИГРОКА =================
func issue_move(pos: Vector2, attack_move := false) -> void:
        if cutscene:
                return
        var sel := _valid_selection()
        if sel.is_empty():
                return
        # построение веером
        var i := 0
        var n := sel.size()
        for u in sel:
                var row := i / 5
                var col := i % 5 - 2
                var gap: float = 66.0 if u.def["kind"] == "inf" else 84.0
                var offset := Vector2(col * gap, row * gap * 0.95 - row * 16.0)
                var p := pos + offset
                if attack_move:
                        u.set_order_amove(clamp_to_map(p))
                else:
                        u.set_order_move(clamp_to_map(p))
                u.last_player_order_t = stats["time"]
                i += 1
        G.play_sfx("radio", -8.0)
        _order_marker(pos, attack_move)

func issue_attack(tgt) -> void:
        if cutscene:
                return
        for u in _valid_selection():
                u.set_order_attack(tgt)
                u.last_player_order_t = stats["time"]
        G.play_sfx("radio", -8.0)
        _order_marker(tgt.global_position, true)

func issue_stop() -> void:
        if cutscene:
                return
        for u in _valid_selection():
                u.set_order_stop()
                u.last_player_order_t = stats["time"]

func issue_hold() -> void:
        if cutscene:
                return
        for u in _valid_selection():
                u.set_order_hold()
                u.last_player_order_t = stats["time"]

func issue_garrison(pos: Vector2) -> void:
        if cutscene:
                return
        # окоп или здание под курсором
        var sel := _valid_selection()
        if sel.is_empty():
                return
        var t := tile_at(pos)
        if t == T_TRENCH:
                var best = null
                var bd := 1e9
                for u in sel:
                        if u.def["kind"] != "inf":
                                continue
                        var d: float = u.global_position.distance_to(pos)
                        if d < bd:
                                bd = d
                                best = u
                if best != null:
                        # ищем ближайшую точку окопа
                        var snap := pos
                        for u2 in sel:
                                if u2 != best and u2.garrison_obj == null:
                                        snap = pos + Vector2(randf_range(-60, 60), 0)
                                        break
                        best.set_garrison({"pos": clamp_to_map(snap), "kind": "trench"})
                        add_log("Группа заняла окоп", Color(0.6, 0.8, 0.6))
        elif _near_building(pos) != null:
                var b: Dictionary = _near_building(pos)
                var count := 0
                for u in sel:
                        if u.def["kind"] == "inf" and count < 3:
                                u.set_garrison({"pos": b["pos"] + Vector2(randf_range(-30, 30), randf_range(20, 40)), "kind": "building"})
                                count += 1
                add_log("Отряд занял здание", Color(0.6, 0.8, 0.6))
        else:
                add_log("Здесь нет укрытия (окоп/здание)", Color(0.8, 0.8, 0.6))

func _near_building(pos: Vector2):
        for o in obstacles:
                if not o.get("soft", true) and pos.distance_to(o["pos"]) < 90.0:
                        return o
        return null

func _order_marker(pos: Vector2, attack: bool) -> void:
        var s := Sprite2D.new()
        s.texture = G.tex("fx_attack_marker" if attack else "fx_move_marker")
        s.position = clamp_to_map(pos)
        s.z_index = 15
        fx_layer.add_child(s)
        var tw := s.create_tween()
        tw.tween_property(s, "modulate:a", 0.0, 0.8)
        tw.tween_callback(s.queue_free)

func _valid_selection() -> Array:
        var res := []
        for u in selection:
                if is_instance_valid(u) and u.alive:
                        res.append(u)
        selection = res
        return res

# ================= СПОСОБНОСТИ =================
func try_ability(ab_id: String) -> bool:
        if cutscene or not G.DB.has(ab_id) or battle_over != "":
                return false
        var cost: float = G.DB[ab_id]["cost"]
        if req < cost:
                add_log("Недостаточно реквизиции", Color(0.9, 0.6, 0.4))
                return false
        if ability_cd.get(ab_id, 0.0) > 0.0:
                return false
        pending_ability = ab_id
        amove_mode = false
        return true

var pending_ability := ""

func use_ability_at(pos: Vector2) -> void:
        var ab := pending_ability
        pending_ability = ""
        if not G.DB.has(ab):
                return
        req -= G.DB[ab]["cost"]
        ability_cd[ab] = _ability_cooldown(ab)
        match ab:
                "_ab_air":
                        _call_airstrike(pos, G.TEAM_PLAYER)
                "_ab_arty":
                        _call_arty(pos, G.TEAM_PLAYER, 8)
                "_ab_smoke":
                        for i in range(3):
                                fx.smoke_screen(pos + Vector2(randf_range(-90, 90), randf_range(-90, 90)))
                        add_log("Дымовая завеса поставлена", Color(0.7, 0.7, 0.7))
                "_ab_mines":
                        for i in range(5):
                                spawn_mine(pos + Vector2(randf_range(-120, 120), randf_range(-120, 120)), G.TEAM_PLAYER)
                        add_log("Минное поле установлено", Color(0.7, 0.7, 0.5))
                "_ab_drones":
                        for i in range(3):
                                var t = _best_enemy_armor(G.TEAM_PLAYER)
                                if t != null:
                                        var d = _spawn_unit("foa_drone", G.TEAM_PLAYER, clamp_to_map(pos + Vector2(randf_range(-200, 200), 300)))
                                        if d != null:
                                                d.set_order_attack(t)
        add_log(G.DB[ab]["name"] + " — выполнено", Color(0.8, 0.85, 0.6))

func _ability_cooldown(ab: String) -> float:
        match ab:
                "_ab_air": return 45.0
                "_ab_arty": return 35.0
                "_ab_smoke": return 25.0
                "_ab_mines": return 30.0
                _: return 40.0

func _call_airstrike(pos: Vector2, team: int) -> void:
        # Су-25 проходит через точку и сбрасывает серию бомб (ТЗ 4.3)
        var dir := Vector2(1, -0.3).normalized() if randf() < 0.5 else Vector2(-1, 0.3).normalized()
        var start := pos - dir * 2600.0
        var jet := Node2D.new()
        var spr := Sprite2D.new()
        spr.texture = G.tex("veh_jet_sak")
        jet.add_child(spr)
        spr.rotation = dir.angle() if dir.x > 0 else dir.angle() + PI
        jet.position = clamp_to_map(start)
        jet.z_index = 18
        unit_layer.add_child(jet)
        jets.append({"node": jet, "dir": dir, "target": pos, "dropped": 0, "team": team, "spd": 900.0})
        G.play_sfx("jet_flyby", -2.0)
        add_log("АВИАЦИЯ: Су-25 на подходе, цель подсвечена", Color(0.85, 0.8, 0.5))

func _call_arty(pos: Vector2, team: int, shells: int) -> void:
        G.play_sfx("artillery_whistle", -4.0)
        add_log("АРТИЛЛЕРИЯ: залп по квадрату ушёл", Color(0.85, 0.8, 0.5))
        for i in range(shells):
                var delay := 0.6 + i * 0.35
                var dest: Vector2 = pos + Vector2(randf_range(-160, 160), randf_range(-160, 160))
                _arty_shell_later(dest, team, delay)

func _arty_shell_later(dest: Vector2, team: int, delay: float) -> void:
        var timer := get_tree().create_timer(delay)
        timer.timeout.connect(func():
                if not is_instance_valid(self) or not is_inside_tree() or battle_over != "":
                        return
                var dir := Vector2(0.7, 1).normalized()
                spawn_proj({
                        "kind": "arcshell", "from": clamp_to_map(dest + dir * 2300.0), "dest": dest,
                        "team": team, "dmg": 105.0, "ap": "he", "splash": 105.0, "ps": 0, "src": null,
                }))

func _best_enemy_armor(for_team: int):
        var best = null
        var bs := -1.0
        for u in units:
                if not is_instance_valid(u) or not u.alive or u.team == for_team:
                        continue
                var w: float = {"heavy": 4.0, "med": 3.0, "light": 1.5, "none": 0.5}[u.def["armor"]]
                if u.air:
                        w *= 0.3
                if w > bs:
                        bs = w
                        best = u
        return best

# ================= DEPLOY =================
func try_deploy(id: String) -> bool:
        if cutscene or battle_over != "":
                return false
        if deploy_queue.size() >= 6:
                add_log("Очередь развёртывания заполнена", Color(0.9, 0.6, 0.4))
                return false
        var cost: float = G.cost_for(id, G.save["kit"])
        if id == faction_player + "_heli":
                if not heli_unlocked:
                        add_log("Вертолёт заблокирован: захватите аэродром «Сокол»", Color(0.9, 0.6, 0.4))
                        return false
        if G.DB[id].get("hero", false):
                return false   # командир не нанимается — он уже в строю
        if req < cost:
                add_log("Недостаточно реквизиции", Color(0.9, 0.6, 0.4))
                return false
        req -= cost
        stats["spent"] += int(cost)
        var build: float = G.DB[id]["build"]
        deploy_queue.append({"id": id, "t": build, "total": build})
        G.play_sfx("radio", -8.0)
        add_log("Заказ: " + G.DB[id]["name"], Color(0.7, 0.75, 0.65))
        return true

func _tick_deploy(delta: float) -> void:
        if deploy_queue.is_empty():
                return
        var item: Dictionary = deploy_queue[0]
        item["t"] -= delta
        if item["t"] <= 0.0:
                deploy_queue.pop_at(0)
                var id: String = item["id"]
                var team := G.TEAM_PLAYER
                var fob := fob_player
                var u = _spawn_unit(id, team, fob)
                if u != null:
                        if u.air:
                                # вертолёт влетает с южного края
                                u.global_position = Vector2(fob.x + randf_range(-300, 300), map_size.y + 100)
                                u.set_order_move(fob + Vector2(0, 160))
                        else:
                                # развёртывание РАЗОСРЕДОТОЧЕННОЕ: каждый прибывает на своё место
                                var an := deploy_count % 8
                                deploy_count += 1
                                var ang := -PI / 2.0 + an * TAU / 8.0
                                u.global_position = clamp_to_map(fob + Vector2.from_angle(ang) * randf_range(120.0, 220.0))
                                u.facing = (fob - u.global_position).angle()
                                _give_auto_order(u, true)   # сам выдвигается к фронту
                add_log(G.DB[id]["name"] + " — в бой!", Color(0.6, 0.9, 0.6))

var deploy_count := 0

# ================= ЗАХВАТ ТОЧЕК =================
func _tick_points(delta: float) -> void:
        for p in points:
                var pc := 0
                var ec := 0
                for u in units:
                        if not is_instance_valid(u) or not u.alive or u.air:
                                continue
                        if u.global_position.distance_to(p["pos"]) < 260.0:
                                if u.team == G.TEAM_PLAYER:
                                        pc += 1
                                else:
                                        ec += 1
                var prog: float = p["prog"]
                if pc > 0 and ec == 0:
                        prog += delta * minf(1.0 + pc * 0.15, 2.0)
                elif ec > 0 and pc == 0:
                        prog -= delta * minf(1.0 + ec * 0.15, 2.0)
                prog = clampf(prog, -6.0, 6.0)
                p["prog"] = prog
                var old_owner: int = p["owner"]
                if prog >= 6.0:
                        p["owner"] = G.TEAM_PLAYER
                elif prog <= -6.0:
                        p["owner"] = G.TEAM_ENEMY
                elif (old_owner == G.TEAM_PLAYER and prog <= 0.0) or (old_owner == G.TEAM_ENEMY and prog >= 0.0):
                        p["owner"] = 0
                if old_owner != p["owner"]:
                        _on_point_captured(p)
                # цвет кольца
                if p.has("ring"):
                        var col := Color(0.85, 0.85, 0.8, 0.3)
                        if p["owner"] == G.TEAM_PLAYER:
                                col = G.FACTION_COLOR[faction_player]
                        elif p["owner"] == G.TEAM_ENEMY:
                                col = G.FACTION_COLOR[faction_enemy]
                        p["ring"].modulate = Color(col.r, col.g, col.b, 0.4)
                if p.has("flag") and is_instance_valid(p["flag"]):
                        var fc := Color(0.8, 0.8, 0.75)
                        if p["owner"] == G.TEAM_PLAYER:
                                fc = G.FACTION_COLOR[faction_player]
                        elif p["owner"] == G.TEAM_ENEMY:
                                fc = G.FACTION_COLOR[faction_enemy]
                        p["flag"].modulate = fc

func _on_point_captured(p: Dictionary) -> void:
        G.play_sfx("capture", -4.0)
        if p["owner"] == G.TEAM_PLAYER:
                stats["captured"] += 1
                add_log("СЕКТОР " + p["id"] + " «" + p["name"] + "» — ВЗЯТ!", Color(0.5, 0.9, 0.5))
        else:
                add_log("СЕКТОР " + p["id"] + " «" + p["name"] + "» — потерян", Color(0.9, 0.5, 0.45))

func _points_owned(team: int) -> int:
        var n := 0
        for p in points:
                if p["owner"] == team:
                        n += 1
        return n

func _tick_auras() -> void:
        # медики (role support) лечат пехоту (и раны — поэтапно), снабжение (repair) чинит технику
        for u in units:
                if not is_instance_valid(u) or not u.alive or u.air or u.hp >= u.max_hp:
                        continue
                for m in units:
                        if m == u or not is_instance_valid(m) or not m.alive or m.team != u.team or m.air:
                                continue
                        var heals: bool = m.def["role"] == "support" and u.def["kind"] == "inf"
                        var repairs: bool = m.def.get("repair", false) and u.def["kind"] == "veh"
                        if not heals and not repairs:
                                continue
                        if u.global_position.distance_to(m.global_position) < 130.0:
                                u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.02)
                                # медик перевязывает раны по этапам (анатомическая медицина)
                                if heals and "soldiers" in u and not u.soldiers.is_empty():
                                        u._auto_treat(true)
                                break

# ================= ГЛАВНЫЙ ЦИКЛ =================
func _process(delta: float) -> void:
        if battle_over != "":
                return
        if paused:
                return
        if cutscene:
                # катсцена приезда: живёт только камера/эффекты/туман, бой заморожен
                _tick_cutscene(delta)
                if shake_amt > 0.1:
                        shake_amt = lerpf(shake_amt, 0.0, delta * 6.0)
                camera.offset = Vector2.ZERO
                fx.tick(delta)
                fog_timer += delta
                if fog_timer >= 0.13:
                        fog_timer = 0.0
                        _update_visibility()
                for i in range(decay_nodes.size() - 1, -1, -1):
                        var dcn: Dictionary = decay_nodes[i]
                        dcn["t"] -= delta
                        if is_instance_valid(dcn["node"]):
                                if dcn["t"] < 4.0:
                                        dcn["node"].modulate.a = maxf(0.0, dcn["t"] / 4.0)
                                if dcn["t"] <= 0.0:
                                        dcn["node"].queue_free()
                                        decay_nodes.remove_at(i)
                        else:
                                decay_nodes.remove_at(i)
                return
        stats["time"] += delta
        sound_marker_cd -= delta
        chatter_cd = maxf(0.0, chatter_cd - delta)
        # «война вокруг»: дальние разрывы, всполохи и столбы дыма на карте
        ambient_t -= delta
        if ambient_t <= 0.0:
                ambient_t = randf_range(6.0, 13.0)
                _ambient_war()
        # камера
        _camera_controls(delta)
        if shake_amt > 0.1:
                shake_amt = lerpf(shake_amt, 0.0, delta * 6.0)
                camera.offset = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
        else:
                camera.offset = Vector2.ZERO
        # экономика
        var income: float = 8.0 + 6.0 * _points_owned(G.TEAM_PLAYER)
        income *= 1.0 + 0.15 * int(G.save["upgrades"].get("logistics", 0))
        # ЗЕМЛЯ КОРМИТ: чем больше территории — тем больше реквизиции
        if territory != null:
                income += territory.share_p * 7.0
        req += income * delta
        # враг
        var ai_income: float = (8.0 + 6.0 * _points_owned(G.TEAM_ENEMY)) * float(G.DIFFICULTY[G.save["difficulty"]]["ai_income"])
        ai_income *= 0.8 + sector_idx * 0.045
        if territory != null:
                ai_income += territory.share_e * 7.0
        ai.give_income(ai_income * delta)
        # командир: респаун и возврат в строй
        _cmdr_tick(delta)
        # автономная доктрина: отряды сами воюют
        _tick_auto_doctrine(delta)
        # таймеры
        for k in ability_cd.keys():
                ability_cd[k] = maxf(0.0, ability_cd[k] - delta)
        _tick_deploy(delta)
        _tick_points(delta)
        # анимация эффектов
        fx.tick(delta)
        # логистика: ящики снабжения + разгрузка Уралов; детонация боекомплекта
        _tick_logistics(delta)
        _tick_booms(delta)
        # ауры лечения (медики) и ремонта (снабжение) — раз в секунду
        heal_timer += delta
        if heal_timer >= 1.0:
                heal_timer = 0.0
                _tick_auras()
        # видимость
        fog_timer += delta
        if fog_timer >= 0.13:
                fog_timer = 0.0
                _update_visibility()
        # радиоразведка по ТЗ 3.4
        radio_timer += delta
        if radio_timer >= 24.0:
                radio_timer = 0.0
                _radio_recon()
        # тикеты: преимущество по точкам
        _ticket_timer += delta
        if _ticket_timer >= 5.0:
                _ticket_timer = 0.0
                var pp := _points_owned(G.TEAM_PLAYER)
                var ep := _points_owned(G.TEAM_ENEMY)
                tickets_player -= maxf(0.0, ep - pp) * 6.0
                tickets_enemy -= maxf(0.0, pp - ep) * 6.0
                if tickets_player <= 0 or tickets_enemy <= 0:
                        _end_battle(tickets_enemy <= 0)
        # дымовые источники
        for i in range(smoke_sources.size() - 1, -1, -1):
                var s: Dictionary = smoke_sources[i]
                s["t"] += delta
                s["acc"] += delta
                if s["acc"] > 0.4:
                        s["acc"] = 0.0
                        fx.puff(s["pos"] + Vector2(randf_range(-10, 10), -8), 1)
                if s["t"] > s["dur"]:
                        smoke_sources.remove_at(i)
        # дым-завесы
        for i in range(fx.smoke_cols.size() - 1, -1, -1):
                var sc: Dictionary = fx.smoke_cols[i]
                sc["t"] -= delta
                if sc["t"] <= 0.0:
                        fx.smoke_cols.remove_at(i)
        # затухающие узлы
        for i in range(decay_nodes.size() - 1, -1, -1):
                var dn: Dictionary = decay_nodes[i]
                dn["t"] -= delta
                if is_instance_valid(dn["node"]):
                        if dn["t"] < 4.0:
                                dn["node"].modulate.a = maxf(0.0, dn["t"] / 4.0)
                        if dn["t"] <= 0.0:
                                dn["node"].queue_free()
                                decay_nodes.remove_at(i)
                else:
                        decay_nodes.remove_at(i)
        # мины
        for m in mines.duplicate():
                if not is_instance_valid(m["node"]) or not m["armed"]:
                        continue
                for u in units:
                        if not is_instance_valid(u) or not u.alive or u.team == m["team"] or u.air:
                                continue
                        if u.global_position.distance_to(m["node"].global_position) < 48.0:
                                m["armed"] = false
                                trigger_mine(m)
                                break
        # самолёты (авиаудар)
        for i in range(jets.size() - 1, -1, -1):
                var j: Dictionary = jets[i]
                var jn = j["node"]
                if not is_instance_valid(jn):
                        jets.remove_at(i)
                        continue
                jn.position += j["dir"] * j["spd"] * delta
                var to_target: Vector2 = j["target"] - jn.position
                if j["dropped"] < 4 and to_target.dot(j["dir"]) < 200.0 and to_target.dot(j["dir"]) > -400.0:
                        if randf() < 0.25:
                                j["dropped"] += 1
                                spawn_proj({
                                        "kind": "bomb", "from": jn.position, "dest": jn.position + j["dir"] * 250.0,
                                        "team": j["team"], "dmg": 150.0, "ap": "he", "splash": 120.0,
                                        "ps": 700.0, "src": null, "ang": j["dir"].angle(),
                                })
                                G.play_sfx("launch_rocket", -8.0)
                if absf(to_target.dot(j["dir"])) > 3200.0 or jn.position.x < -300 or jn.position.x > map_size.x + 300:
                        jn.queue_free()
                        jets.remove_at(i)
        # проверка полного разгрома + чистка массивов от мёртвых ссылок
        end_timer += delta
        if end_timer >= 3.0:
                end_timer = 0.0
                projs = projs.filter(func(p): return is_instance_valid(p))
                units = units.filter(func(u): return is_instance_valid(u))
                _check_annihilation()

var _ticket_timer := 0.0

func _check_annihilation() -> void:
        var p_alive := 0
        var e_alive := 0
        for u in units:
                if is_instance_valid(u) and u.alive:
                        if u.team == G.TEAM_PLAYER:
                                p_alive += 1
                        else:
                                e_alive += 1
        var e_can_build: bool = ai != null and (ai.req >= 120.0)
        if e_alive == 0 and not e_can_build and deploy_queue.is_empty():
                _end_battle(true)
        elif p_alive == 0 and req < 120.0 and deploy_queue.is_empty():
                _end_battle(false)

func _end_battle(victory: bool) -> void:
        if battle_over != "":
                return
        battle_over = "victory" if victory else "defeat"
        paused = true  # замораживаем симуляцию, UI продолжает работать
        G.play_sfx("victory" if victory else "defeat", 0.0)
        G.save["battles"] += 1
        # ПЕРМАСМЕРТЬ: совокупные потери кампании накапливаются в штабе навсегда
        G.save["total_losses"] = int(G.save.get("total_losses", 0)) + int(stats["losses"])
        G.save["total_kills"] = int(G.save.get("total_kills", 0)) + int(stats["kills"])
        if victory:
                G.save["wins"] += 1
                var salvage: int = 400 + sector_idx * 60 + int(stats["kills"]) * 8
                G.save["bank"] += salvage
                if G.SECTORS[sector_idx]["type"] == "airbase":
                        G.save["heli_unlocked"] = true
                        add_log("Захвачены вертолёты! Ми-24 доступны в следующих боях", Color(0.7, 0.9, 0.6))
                if sector_idx >= G.SECTORS.size() - 1:
                        G.save["campaign_won"] = true  # финал: победа в кампании
                else:
                        G.save["sector"] = mini(sector_idx + 1, G.SECTORS.size() - 1)
        G.write_save()
        if ui != null:
                ui.show_end(victory)

# ================= РАДИОРАЗВЕДКА (ТЗ 3.4) =================
func _radio_recon() -> void:
        var callsigns := ["Сокол", "Буря", "Гранит", "Кобра", "Стрела", "Тень"]
        var cs: String = callsigns[randi() % callsigns.size()]
        # где скопление врага?
        var best_pos := Vector2.ZERO
        var best_n := 0
        for p in points:
                var n := 0
                for u in units:
                        if is_instance_valid(u) and u.alive and u.team == G.TEAM_ENEMY and u.global_position.distance_to(p["pos"]) < 500.0:
                                n += 1
                if n > best_n:
                        best_n = n
                        best_pos = p["pos"]
        if best_n >= 2:
                _reveal_cells(best_pos, 800.0)
                _update_fog_image()
                var phrases := [
                        "Командир, на связи " + cs + ". Вижу скопление техники у сектора, воюем аккуратно!",
                        cs + " доложает: у точки противник, минимум пара машин!",
                        "Разведка " + cs + ": засада противника у сектора, слежу за ними.",
                ]
                add_log(phrases[randi() % phrases.size()], Color(0.75, 0.85, 0.75))
        else:
                var phrases2 := [
                        cs + ": по участку тихо, движений не видно.",
                        cs + " на связи: пока чисто, продолжаем движение.",
                ]
                add_log(phrases2[randi() % phrases2.size()], Color(0.65, 0.7, 0.65))

# ================= ЖУРНАЛ =================
func add_log(text: String, col := Color(0.8, 0.8, 0.75), tag := "") -> void:
        if ui != null and is_instance_valid(ui):
                ui.push_log(text, col, tag)

# ================= АТМОСФЕРА: ВОЙНА ВОКРУГ =================
func _ambient_war() -> void:
        # случайная точка недалеко от камеры (в поле зрения или рядом)
        var half: Vector2 = get_viewport_rect().size * 0.5 / cam_zoom
        var pos := camera.position + Vector2(randf_range(-half.x * 1.3, half.x * 1.3),
                randf_range(-half.y * 1.3, half.y * 1.3))
        pos = clamp_to_map(pos)
        var r := randf()
        if r < 0.45:
                # далёкий разрыв
                fx.explosion(pos, randi() % 2)
                G.play_sfx("cannon_far", -8.0, randf_range(0.85, 1.1))
        elif r < 0.75:
                # smoke over burning ground
                fx.explosion(pos, 1)
                fx.smoke_column(pos, 12.0)
                G.play_sfx("cannon_far", -6.0, 0.9)
        else:
                # пара бомб где-то далеко
                fx.explosion(pos, 2)
                G.play_sfx("expl_l", -10.0, 0.8)
                shake(1.5)

# ================= КАМЕРА И ВВОД =================
func _camera_controls(delta: float) -> void:
        # прямое управление: камера следует за командиром, twin-stick
        if direct_ctrl:
                if is_instance_valid(direct_unit) and direct_unit.alive:
                        if not joy_active:
                                var mv := Vector2.ZERO
                                if Input.is_key_pressed(KEY_W):
                                        mv.y -= 1
                                if Input.is_key_pressed(KEY_S):
                                        mv.y += 1
                                if Input.is_key_pressed(KEY_A):
                                        mv.x -= 1
                                if Input.is_key_pressed(KEY_D):
                                        mv.x += 1
                                direct_vec = mv.limit_length(1.0)
                        camera.position = camera.position.lerp(direct_unit.global_position, minf(1.0, delta * 5.0))
                        camera.position = clamp_to_map(camera.position)
                        # ПК: мышь — прицел (правый стик), ЛМБ — огонь (устанавливается во вводе)
                        if not touch_mode:
                                manual_aim = true
                                manual_ang = (get_global_mouse_position() - direct_unit.global_position).angle()
                        _tick_rear_fov(delta)
                        _mmb_last = get_global_mouse_position()
                        return
                else:
                        _exit_direct()
        var v := Vector2.ZERO
        if Input.is_key_pressed(KEY_UP):
                v.y -= 1
        if Input.is_key_pressed(KEY_DOWN):
                v.y += 1
        if Input.is_key_pressed(KEY_LEFT):
                v.x -= 1
        if Input.is_key_pressed(KEY_RIGHT):
                v.x += 1
        camera.position += v * 900.0 * delta / cam_zoom
        # перетаскивание средней кнопкой мыши
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
                var pan := get_global_mouse_position() - _mmb_last
                camera.position -= pan
        camera.position = clamp_to_map(camera.position)
        _mmb_last = get_global_mouse_position()

var _mmb_last := Vector2.ZERO

# ---------- ДИНАМИЧЕСКАЯ ВИДИМОСТЬ (ТЗ 4.5): конус 110°, замыленный тыл ----------
const FOV_HALF := 0.96      # половина конуса 110° в радианах

func _tick_rear_fov(delta: float) -> void:
        # в прямом управлении враги позади командира (вне конуса) тают —
        # живые юниты исчезают в замыленном тылу
        var fang: float = direct_unit.facing
        for e in units:
                if not is_instance_valid(e) or not e.alive:
                        continue
                if e.team != G.TEAM_ENEMY:
                        continue
                var d: float = direct_unit.global_position.distance_to(e.global_position)
                var rear := false
                if d > 300.0:
                        var ea: float = (e.global_position - direct_unit.global_position).angle()
                        if absf(angle_difference(ea, fang)) > FOV_HALF + 0.5:
                                rear = not vis_player.has(e)
                var target_a := 0.12 if rear else 1.0
                e.modulate.a = lerpf(e.modulate.a, target_a, minf(1.0, delta * 5.0))
        # звуковые маркеры: выстрелы/взрывы за спиной — указатели на экране (ui)
        if ui != null:
                ui.update_fov_hud(direct_unit.global_position, fang)

func zoom_by(factor: float) -> void:
        cam_zoom = clampf(cam_zoom * factor, 0.5, 1.7)
        camera.zoom = Vector2(cam_zoom, cam_zoom)

# ================= РАЦИЯ ОТРЯДОВ: ЖИВЫЕ РЕПЛИКИ =================
var chatter_cd := 0.0

func chatter(u, text: String, col := Color(0.66, 0.78, 0.62)) -> void:
        # бойцы сами докладывают по рации — не спамим, глобальный троттлинг
        if chatter_cd > 0.0 or u == null or not is_instance_valid(u):
                return
        if u.team != G.TEAM_PLAYER:
                return
        chatter_cd = 2.4
        # метка ГОВОРЯЩЕГО: видно сразу, кто именно докладывает — боец или штаб
        add_log(text, col, "БОЕЦ · " + u.callsign)

# ================= КОНТЕКСТНАЯ ТЕХНИКА КОМАНДИРА =================
# 0 — машины нет рядом; 1 — можно сесть; 2 — сидим в машине
func cmdr_veh_state() -> int:
        if not is_instance_valid(cmdr) or not cmdr.alive:
                return 0
        if cmdr.mounted_in != null and is_instance_valid(cmdr.mounted_in):
                return 2
        if nearest_boardable(cmdr.global_position, 165.0) != null:
                return 1
        return 0

func cmdr_near_veh():
        if not is_instance_valid(cmdr) or not cmdr.alive or cmdr.mounted_in != null:
                return null
        return nearest_boardable(cmdr.global_position, 165.0)

func center_on(pos: Vector2) -> void:
        camera.position = clamp_to_map(pos)

func _unhandled_input(event: InputEvent) -> void:
        if battle_over != "":
                return
        if cutscene:
                return
        # НА ТЕЛЕФОНЕ в режиме командира мышь (эмуляция от касаний) игнорируется —
        # иначе эмулированные клики смешивались со стиками: хотел идти — а он стреляет.
        if touch_mode and direct_ctrl:
                if event is InputEventScreenTouch:
                        _touch_stick(event as InputEventScreenTouch)
                elif event is InputEventScreenDrag:
                        _drag_stick(event as InputEventScreenDrag)
                return
        if event is InputEventMouseButton:
                var mb := event as InputEventMouseButton
                var wpos := get_global_mouse_position()
                if mb.button_index == MOUSE_BUTTON_LEFT:
                        if mb.pressed:
                                if pending_ability != "":
                                        use_ability_at(wpos)
                                        return
                                if amove_mode:
                                        issue_move(wpos, true)
                                        amove_mode = false
                                        return
                                if garrison_mode:
                                        issue_garrison(wpos)
                                        garrison_mode = false
                                        return
                                # эвакуация: тап по раненому отряду отправляет к нему санитаров
                                if evac_mode:
                                        var ev_tgt = _unit_at(wpos)
                                        if ev_tgt != null and ev_tgt.team == G.TEAM_PLAYER and ev_tgt.has_wounded():
                                                for u2 in _valid_selection():
                                                        if u2.def["kind"] == "inf" and u2 != ev_tgt:
                                                                u2.set_order_evac(ev_tgt)
                                                add_log("ЭВАКУАЦИЯ: идём к раненым — вытащим их в укрытие!", Color(0.9, 0.7, 0.5))
                                                G.play_sfx("radio", -8.0)
                                        else:
                                                add_log("Эвакуация отменена: цель не ранена", Color(0.7, 0.72, 0.6))
                                        evac_mode = false
                                        return
                                # сенсорный приказ: тап по карте отдаёт приказ вместо выделения
                                if touch_order:
                                        var ord_tgt = _unit_at(wpos)
                                        if ord_tgt != null and ord_tgt.team == G.TEAM_ENEMY and is_visible_to_player(ord_tgt):
                                                issue_attack(ord_tgt)
                                        elif ord_tgt != null and ord_tgt.team == G.TEAM_PLAYER and ord_tgt.def["kind"] == "veh":
                                                issue_board(ord_tgt)   # тап по своей технике — посадка
                                        else:
                                                issue_move(wpos, false)
                                        touch_order = false
                                        return
                                # ПРЯМОЕ УПРАВЛЕНИЕ: на ПК мышь — прицел, ЛМБ — огонь
                                if direct_ctrl:
                                        if not touch_mode:
                                                manual_fire = true
                                        return
                                drag_start = wpos
                                drag_start_screen = get_viewport().get_mouse_position()
                                dragging = true
                        else:
                                if direct_ctrl and not touch_mode:
                                        manual_fire = false
                                        return
                                if dragging:
                                        dragging = false
                                        _finish_selection(wpos)
                elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
                        if pending_ability != "":
                                pending_ability = ""
                                return
                        var tgt = _unit_at(wpos)
                        if tgt != null and tgt.team == G.TEAM_ENEMY and is_visible_to_player(tgt):
                                issue_attack(tgt)
                        elif tgt != null and tgt.team == G.TEAM_PLAYER and tgt.def["kind"] == "veh":
                                # ПОСАДКА: выделенная пехота садится в свою технику
                                var has_inf := false
                                for su in _valid_selection():
                                        if su.def["kind"] == "inf":
                                                has_inf = true
                                                break
                                if has_inf:
                                        issue_board(tgt)
                                elif is_instance_valid(cmdr) and cmdr.alive and cmdr.mounted_in == null and cmdr.global_position.distance_to(tgt.global_position) < 170.0:
                                        cmdr.set_order_board(tgt)
                                        add_log("КОМАНДИР: садится в «%s»" % tgt.def["name"], Color(0.7, 0.85, 0.7))
                        elif tgt != null and tgt.team == G.TEAM_PLAYER and tgt.has_wounded():
                                # ЭВАКУАЦИЯ ВОЛОКОМ: приказ здоровому отряду вытащить раненых
                                for u in _valid_selection():
                                        if u.def["kind"] == "inf" and u != tgt:
                                                u.set_order_evac(tgt)
                                add_log("ЭВАКУАЦИЯ: идём к раненым — вытащим их в укрытие!", Color(0.9, 0.7, 0.5))
                                G.play_sfx("radio", -8.0)
                        else:
                                issue_move(wpos, false)
                elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
                        zoom_by(1.12)
                elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
                        zoom_by(0.89)
        elif event is InputEventMouseMotion:
                if dragging and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
                        pass  # рамка рисуется в ui через battle.drag_start
        elif event is InputEventScreenTouch:
                # реальные касания (на телефоне приходят вместе с эмуляцией мыши)
                touch_mode = true
                var st := event as InputEventScreenTouch
                var vp2 := get_viewport_rect().size
                if direct_ctrl:
                        _touch_stick(st)
                        return
                if st.pressed:
                        _touch_pts[st.index] = st.position
                        if _touch_pts.size() == 2:
                                if dragging:
                                        dragging = false   # второй палец — жест камеры, отменяем рамку
                                var vals: Array = _touch_pts.values()
                                _pan_mid = (vals[0] + vals[1]) * 0.5
                                _pinch_dist = vals[0].distance_to(vals[1])
                                _panning = not direct_ctrl
                else:
                        _touch_pts.erase(st.index)
                        if _touch_pts.size() < 2:
                                _panning = false
        elif event is InputEventScreenDrag:
                var sd := event as InputEventScreenDrag
                if direct_ctrl:
                        _drag_stick(sd)
                        return
                if _touch_pts.has(sd.index):
                        _touch_pts[sd.index] = sd.position
                if _touch_pts.size() >= 2:
                        var vals2: Array = _touch_pts.values()
                        var mid: Vector2 = (vals2[0] + vals2[1]) * 0.5
                        var dist: float = vals2[0].distance_to(vals2[1])
                        if _panning:
                                var pan_px: Vector2 = mid - _pan_mid
                                camera.position -= pan_px / cam_zoom
                                camera.position = clamp_to_map(camera.position)
                        if _pinch_dist > 1.0:
                                zoom_by(dist / _pinch_dist)
                        _pan_mid = mid
                        _pinch_dist = dist
        var kb := event as InputEventKey
        if kb != null and kb.pressed and not kb.echo:
                var k := kb.keycode
                # отряды 1–9 (Ctrl+N — назначить, N — вызвать)
                if k >= KEY_1 and k <= KEY_9:
                        var num: int = (k - KEY_1) + 1
                        if kb.ctrl_pressed:
                                set_control_group(num)
                                add_log("Отряд %d назначен" % num, Color(0.7, 0.8, 0.7))
                        else:
                                recall_control_group(num)
                        return
                # горячие клавиши способностей
                var hot := {KEY_Q: "_ab_air", KEY_E: "_ab_arty", KEY_R: "_ab_smoke", KEY_T: "_ab_mines", KEY_Y: "_ab_drones"}
                if hot.has(k) and G.ability_list(faction_player).has(hot[k]) and not direct_ctrl:
                        try_ability(hot[k])
                        return
                match k:
                        KEY_A:
                                if not direct_ctrl:
                                        amove_mode = true
                                        add_log("Атакующее движение: укажите точку", Color(0.7, 0.8, 0.7))
                        KEY_S:
                                if not direct_ctrl:
                                        issue_stop()
                        KEY_H:
                                if not direct_ctrl:
                                        issue_hold()
                        KEY_G:
                                if direct_ctrl:
                                        cmdr_board_exit()   # сесть/выйти из техники
                                else:
                                        garrison_mode = true
                                        add_log("Занять укрытие: укажите окоп или здание", Color(0.7, 0.8, 0.7))
                        KEY_F:
                                toggle_direct()
                        KEY_Z:
                                if direct_ctrl:
                                        use_cmd_item("band")
                        KEY_X:
                                if direct_ctrl:
                                        use_cmd_item("tq")
                        KEY_C:
                                if direct_ctrl:
                                        use_cmd_item("splint")
                        KEY_V:
                                if direct_ctrl:
                                        use_cmd_item("morph")
                        KEY_B:
                                if direct_ctrl:
                                        use_cmd_item("mag")
                        KEY_N:
                                if direct_ctrl:
                                        check_mag_blind()
                        KEY_ESCAPE:
                                if direct_ctrl:
                                        _exit_direct()
                                elif ui != null:
                                        ui.toggle_pause()
                        KEY_F1:
                                if ui != null:
                                        ui.toggle_help()
                        KEY_SPACE:
                                center_on(fob_player)
                                for i in range(1, 10):
                                        if control_groups.has(i):
                                                var grp: Array = control_groups[i]
                                                var valid := []
                                                for u in grp:
                                                        if is_instance_valid(u) and u.alive:
                                                                valid.append(u)
                                                if not valid.is_empty():
                                                        var c := Vector2.ZERO
                                                        for u in valid:
                                                                c += u.global_position
                                                        center_on(c / valid.size())
                                                        break

# ================= ЗАКРЕПЛЁННЫЕ СТИКИ (телефон) =================
# Левый стик — ТОЛЬКО движение, правый — прицел; огонь начинается
# только когда ручку толкнули до упора (гистерезис). Касание у базы —
# иначе не захватывается: стики больше не смешиваются с экраном.
func _touch_stick(st: InputEventScreenTouch) -> void:
        var bl := stick_base("l")
        var br := stick_base("r")
        if st.pressed:
                var dl: float = st.position.distance_to(bl)
                var dr: float = st.position.distance_to(br)
                if dl <= STICK_ACT_R and _stick_move_idx < 0 and _stick_aim_idx != st.index:
                        _stick_move_idx = st.index
                        joy_active = true
                        joy_origin = bl
                        _move_stick_vec(st.position)
                elif dr <= STICK_ACT_R and _stick_aim_idx < 0 and _stick_move_idx != st.index:
                        _stick_aim_idx = st.index
                        r_joy_active = true
                        r_joy_origin = br
                        _aim_stick_vec(st.position)
        else:
                if st.index == _stick_move_idx:
                        _stick_move_idx = -1
                        joy_active = false
                        direct_vec = Vector2.ZERO
                elif st.index == _stick_aim_idx:
                        _stick_aim_idx = -1
                        r_joy_active = false
                        _r_fire_latch = false
                        _r_was_center = false
                        manual_fire = false
                        manual_aim = false

func _drag_stick(sd: InputEventScreenDrag) -> void:
        if sd.index == _stick_move_idx:
                _move_stick_vec(sd.position)
        elif sd.index == _stick_aim_idx:
                _aim_stick_vec(sd.position)

func _move_stick_vec(at: Vector2) -> void:
        var v: Vector2 = (at - joy_origin) / STICK_KNOB
        direct_vec = v.limit_length(1.0)

func _aim_stick_vec(at: Vector2) -> void:
        var av: Vector2 = at - r_joy_origin
        var mag := av.length()
        var k: float = mag / STICK_KNOB
        if mag > 14.0:
                manual_aim = true
                manual_ang = av.angle()
        # Ручка побывала у центра — только теперь доводка к краю даёт ОГОНЬ.
        # (нельзя выстрелить, просто коснувшись края базы)
        if k < STICK_FIRE_OFF:
                _r_was_center = true
                if _r_fire_latch:
                        _r_fire_latch = false
                        manual_fire = false
        elif _r_was_center and k >= STICK_FIRE_K:
                _r_fire_latch = true
                manual_fire = true

func _finish_selection(end_pos: Vector2) -> void:
        var additive := Input.is_key_pressed(KEY_SHIFT)
        var sel: Array = []
        var area := Rect2(drag_start, end_pos - drag_start).abs()
        if area.size.length() < 18.0:
                # одиночный клик
                var u = _unit_at(end_pos)
                if u != null and u.team == G.TEAM_PLAYER:
                        sel.append(u)
        else:
                for unit in units:
                        if not is_instance_valid(unit) or not unit.alive or unit.team != G.TEAM_PLAYER:
                                continue
                        if unit.mounted_in != null:
                                continue   # севшую пехоту рамкой не берём — берём машину
                        if area.has_point(unit.global_position):
                                sel.append(unit)
        if not additive:
                for u in selection:
                        if is_instance_valid(u):
                                u.selected = false
                                u.ring.visible = false
                selection = sel
        else:
                for u in sel:
                        if not selection.has(u):
                                selection.append(u)
        for u in selection:
                if is_instance_valid(u):
                        u.selected = true
                        u.ring.visible = true
        if not selection.is_empty():
                G.play_sfx("ui_click", -10.0)

func _unit_at(pos: Vector2):
        var best = null
        var bd := 1e9
        for u in units:
                if not is_instance_valid(u) or not u.alive:
                        continue
                if u.mounted_in != null:
                        continue   # погруженную пехоту нельзя выбрать — выбирается машина
                if u.team == G.TEAM_ENEMY and (not is_visible_to_player(u) or unit_hidden_for_player(u)):
                        continue
                var d: float = pos.distance_to(u.global_position)
                var pick_r: float = u.def["radius"] + 38.0 if u.def["kind"] == "inf" else u.def["radius"] + 26.0
                if d < pick_r and d < bd:
                        bd = d
                        best = u
        return best

func set_control_group(idx: int) -> void:
        control_groups[idx] = _valid_selection().duplicate()

func recall_control_group(idx: int) -> void:
        if control_groups.has(idx):
                var grp: Array = control_groups[idx]
                var valid := []
                for u in grp:
                        if is_instance_valid(u) and u.alive:
                                valid.append(u)
                selection = valid
                for u in valid:
                        u.selected = true
                        u.ring.visible = true
