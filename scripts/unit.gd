# ============================================================
# БОЕВАЯ ЕДИНИЦА (юнит) v3
# Вся наземная техника, пехота, вертолёты, дроны.
# корпус/башня/тень поворачиваются по ходу движения,
# каждый боец отряда — независимая модель с рассредоточением,
# боевой интеллект бойца: дистанция, укрытия, реакция на подавление.
# ХАРДКОР: анатомические раны по 6 зонам, кровотечения, переломы,
# этапное лечение, стресс/паника/ярость, магазины и заклинивание.
# ============================================================
extends Node2D

const Med = preload("res://scripts/med.gd")

var id: String = ""
var def: Dictionary = {}
var team: int = 1
var battle = null  # ссылка на battle.gd (утиной типизации, чтобы избежать циклов)

# --- узлы ---
var shadow: Sprite2D
var hull: Sprite2D
var turret: Sprite2D
var rotor: Sprite2D
var ring: Sprite2D

# --- состояние ---
var hp: float = 100.0
var max_hp: float = 100.0
var facing := 0.0
var tur_facing := 0.0
var order := {"type": "idle", "pos": Vector2.ZERO, "target": null}
var weapon_cd: Array = []
var weapon_target = null
var suppression := 0.0
var in_cover := false
var garrison_obj = null   # {"pos": Vector2, "kind": "trench"/"building"}
var alive := true
var air := false
var hover_t := 0.0
var mines_left := 0
var mine_dist := 0.0
var vel := Vector2.ZERO
var loud_t := 0.0
var stuck_t := 0.0
var retreat_mode := false
var selected := false
var spawn_t := 0.0
var heal_cd := 0.0

# --- хардкор: боеприпасы и оружие ---
var mags := 8.0            # запас магазинов (дробный: расход по очередям)
var mags_max := 8.0
var jam_t := 0.0           # >0 — оружие заклинило
var evac_target = null     # отряд, к которому идём эвакуировать раненых
var treat_t := 0.0         # таймер поэтапного лечения медиками
var bleed_tick := 0.0      # накопитель кровопотери
var ammo_warned := false   # предупреждение «патронов нет» один раз

# ---- ТРАНСПОРТ: пехота садится в технику, техника возит пассажиров ----
var mounted_in = null      # техника, в которую мы сели (для пехоты)
var passengers: Array = [] # пассажиры-отряды (для техники)
var driver = null          # командир за рулём (герой в машине)
var last_player_order_t := -100.0   # когда игрок отдавал приказ лично нам
var last_auto_t := 0.0     # когда доктрина давала автономный приказ

# ---- «ЖИВЫЕ БОТЫ»: личность, перебежки, микроповедение, рация ----
var pers_aggro := 1.0      # смелость: как рвётся вперёд (0.7..1.35)
var pers_caution := 1.0    # осторожность: дольше осматривается, чаще в укрытие
var callsign := ""         # позывной для живых реплик
var adv_halt := false      # перебежка: сейчас остановка и осмотр?
var adv_t := 0.0           # таймер фазы перебежки
var scan_t := 0.0          # осмотр по сторонам на месте
var _crouch_k := 1.0       # приседание под огнём (визуал)
var _sidestep := Vector2.ZERO
var _sidestep_t := 0.0
var said_contact := false
var said_cover := false
var said_low_ammo := false
var _no_target_t := 10.0   # давно ли не видели цели (для «Вижу цель!»)
const CS_POOL := ["Сокол", "Буря", "Гранит", "Кобра", "Стрела", "Тень", "Вихрь", "Рубин", "Кремень", "Ястреб"]

const SPD_MULT := 2.2
const VIS_SCL := 1.42          # масштаб техники (крупная, читается на телефоне)
const SINF_SCL := 1.34         # масштаб бойцов пехоты (крупнее — видно лицо/снаряжение)
const SHOT_ALERT := 900.0

# ================= СОЛДАТЫ ОТРЯДА (независимые модели) =================
# Каждый боец — отдельный спрайт со своей позицией/скоростью,
# пружиной к слоту построения и расталкиванием с соседями.
var soldiers: Array = []      # {spr, off:Vector2, vel:Vector2, slot:int, alive:bool, ph:float}
var alive_prev := 0

func setup(unit_id: String, unit_team: int, btl) -> void:
        id = unit_id
        team = unit_team
        battle = btl
        def = G.DB[id]
        hp = float(def["hp"])
        max_hp = hp
        air = def.get("air", false)
        mines_left = def.get("mines", 0)
        # ЛИЧНОСТЬ: каждый боец/экипаж немного свой — один смелее, другой осторожнее
        pers_aggro = randf_range(0.72, 1.35)
        pers_caution = randf_range(0.8, 1.3)
        callsign = CS_POOL[randi() % CS_POOL.size()] + "-" + str(randi() % 9 + 2)
        _unit_seed = randi() % 100000
        z_index = 8 if air else 6
        facing = 0.0 if team == G.TEAM_PLAYER else PI
        # тень техники
        if def["kind"] != "inf":
                var sh_tex = G.tex(def["hull"] + "_sh")
                if sh_tex:
                        shadow = Sprite2D.new()
                        shadow.texture = sh_tex
                        shadow.z_index = -1
                        shadow.scale = Vector2(VIS_SCL, VIS_SCL)
                        if air:
                                shadow.modulate = Color(0, 0, 0, 0.28)
                                shadow.position = Vector2(50, 74)
                                shadow.scale = Vector2(0.85 * VIS_SCL, 0.8 * VIS_SCL)
                        add_child(shadow)
        # корпус
        if def["kind"] != "inf":
                hull = Sprite2D.new()
                var h_tex = G.tex(def["hull"])
                if h_tex:
                        hull.texture = h_tex
                        hull.scale = Vector2(VIS_SCL, VIS_SCL)
                add_child(hull)
        # башня
        if def.get("tur", "") != "":
                turret = Sprite2D.new()
                var t_tex = G.tex(def["tur"])
                if t_tex:
                        turret.texture = t_tex
                        turret.scale = Vector2(VIS_SCL, VIS_SCL)
                turret.position = (def.get("tur_off", Vector2.ZERO) as Vector2) * VIS_SCL
                add_child(turret)
        # винт для вертолёта
        if def["kind"] == "heli":
                rotor = Sprite2D.new()
                rotor.texture = G.tex("fx_rotor")
                rotor.modulate = Color(1, 1, 1, 0.55)
                rotor.scale = Vector2(VIS_SCL, VIS_SCL)
                add_child(rotor)
        # пехота — независимые бойцы
        if def["kind"] == "inf" and def.has("squad"):
                _make_squad()
        # кольцо выделения
        ring = Sprite2D.new()
        ring.texture = G.tex("fx_ring_sel")
        var rs: float = SINF_SCL if def["kind"] == "inf" else VIS_SCL
        ring.scale = Vector2(rs, rs)
        ring.modulate = Color(0.4, 1.0, 0.45, 0.9) if team == G.TEAM_PLAYER else Color(1.0, 0.4, 0.35, 0.9)
        ring.visible = false
        ring.z_index = 3
        add_child(ring)
        weapon_cd = []
        for w in def["wpns"]:
                weapon_cd.append(randf() * 1.5)
        tur_facing = facing
        # боезапас пехоты (магазины), у техники — полный боеуклад
        if def["kind"] == "inf":
                mags_max = float(def.get("mags", 8))
                mags = mags_max
        elif def.get("cargo", false):
                mags_max = 4.0
                mags = mags_max

func _make_squad() -> void:
        soldiers.clear()
        var squad: Array = def["squad"]
        for i in range(squad.size()):
                var stype: String = squad[i]
                var spr := Sprite2D.new()
                var tex = G.tex("soldier_" + stype + "_" + def["fac"])
                if tex == null:
                        tex = G.tex("soldier_" + stype + "_sak")
                if tex == null:
                        tex = G.tex("soldier_rifle_sak")
                if tex:
                        spr.texture = tex
                spr.z_index = 1
                spr.scale = Vector2(SINF_SCL, SINF_SCL)   # крупные бойцы
                add_child(spr)
                var s_off := _slot_pos(i, true)
                spr.position = s_off
                spr.rotation = facing
                soldiers.append({"spr": spr, "off": s_off, "vel": Vector2.ZERO,
                        "slot": i, "alive": true, "ph": randf() * TAU, "st": Med.mk_state()})
        alive_prev = soldiers.size()

func _slot_pos(idx: int, spread: bool) -> Vector2:
        # Построение «цепью»: на марше — разреженная цепь уступами, на позиции —
        # боевое рассредоточение (каждый боец — отдельная огневая позиция).
        var k: float = 2.55 if spread else 2.0
        var row := idx / 3
        var col := idx % 3
        var local := Vector2(16 - row * 26 * k, (col - 1) * 26 * k + (7.0 if row % 2 == 1 else -7.0))
        if idx == 0:
                local = Vector2(20 * k, 0)
        return local.rotated(facing)

# ================= ГЛАВНЫЙ ЦИКЛ =================
func _process(delta: float) -> void:
        if battle == null or not alive:
                return
        if battle.paused:
                return
        spawn_t += delta
        loud_t = maxf(0.0, loud_t - delta)
        suppression = maxf(0.0, suppression - delta * 6.0)
        hover_t += delta
        jam_t = maxf(0.0, jam_t - delta)
        _hardcore_tick(delta)
        # ---- ПАССАЖИР: сидим в технике, следуем за ней ----
        if mounted_in != null:
                if not is_instance_valid(mounted_in) or not mounted_in.alive:
                        dismount(true)
                else:
                        global_position = mounted_in.global_position
                        vel = Vector2.ZERO
                        for s in soldiers:
                                (s["spr"] as Sprite2D).visible = false
                        return
        if air:
                if rotor:
                        rotor.rotation += delta * 22.0
                var bob := sin(hover_t * 3.0) * 2.5
                if hull:
                        hull.position.y = bob
                if rotor:
                        rotor.position.y = bob
                match def["kind"]:
                        "drone":
                                _drone_logic(delta)
                        "heli":
                                _heli_logic(delta)
        else:
                _ground_logic(delta)
                # минирование на марше (сапёр)
                if mines_left > 0 and vel.length() > 8.0:
                        mine_dist += vel.length() * delta
                        if mine_dist > 260.0:
                                mine_dist = 0.0
                                mines_left -= 1
                                battle.spawn_mine(global_position, team)
        _apply_visuals(delta)
        queue_redraw()

# ---------- ПРИМЕНЕНИЕ ВИЗУАЛА: ПОВОРОТ КОРПУСА/БАШНИ/ТЕНЬ ----------
func _apply_visuals(delta: float) -> void:
        # ФИКС «ездит боком»: корпус и тень смотрят по ходу движения
        if hull != null:
                hull.rotation = facing
        if shadow != null:
                shadow.rotation = facing
        if turret != null:
                turret.rotation = tur_facing - facing
        if def["kind"] == "inf":
                _update_soldiers(delta)

# ================= СОЛДАТЫ: ФИЗИКА РАССРЕДоточения =================
func _update_soldiers(delta: float) -> void:
        if soldiers.is_empty():
                return
        var moving := vel.length() > 12.0
        # живых бойцов считаем от доли HP: каждый убитый — отдельная тушка
        var alive_n: int = int(ceil(clampf(hp / max_hp, 0.0, 1.0) * soldiers.size()))
        if alive_n < 1 and hp > 0.0:
                alive_n = 1
        # гибель бойцов: убираем с конца строя
        if alive_n < alive_prev:
                var lost: int = alive_prev - alive_n
                for i in range(soldiers.size() - 1, -1, -1):
                        if lost <= 0:
                                break
                        var sv: Dictionary = soldiers[i]
                        if sv["alive"]:
                                _kill_soldier(sv)
                                lost -= 1
        alive_prev = alive_n
        # прячем всех в гарнизоне
        if garrison_obj != null:
                for s in soldiers:
                        (s["spr"] as Sprite2D).visible = false
                return
        var base_alpha := 0.75 if (in_cover and battle.tile_at(global_position) == battle.T_TRENCH) else 1.0
        var spd: float = def["spd"] * SPD_MULT * 1.05
        var danger := suppression > 18.0 or (weapon_target != null and is_instance_valid(weapon_target))
        # «тяжёлый» — его тащат: пристраиваем к здоровому бойцу
        var down_s = null
        var carrier = null
        for s in soldiers:
                if not s["alive"]:
                        continue
                if (s["st"] as Dictionary)["down"]:
                        down_s = s
                elif carrier == null:
                        carrier = s
        for s in soldiers:
                var spr: Sprite2D = s["spr"]
                if not s["alive"]:
                        continue
                spr.visible = true
                spr.modulate.a = base_alpha
                var st: Dictionary = s["st"]
                # ПРИСЕДАНИЕ ПОД ОГНЁМ: прижимается к земле, когда палят
                var want_crouch := 0.8 if (suppression > 34.0 or (in_cover and weapon_target != null and is_instance_valid(weapon_target))) else 1.0
                _crouch_k = lerpf(_crouch_k, want_crouch, minf(1.0, delta * 6.0))
                spr.scale = Vector2(1.0, _crouch_k)
                # окраска раненого
                var hurt: float = 1.0 - (st["body"][Med.worst_zone(s)] if s["alive"] else 1.0)
                if hurt > 0.25:
                        spr.modulate = Color(1.0, 1.0 - hurt * 0.35, 1.0 - hurt * 0.35, base_alpha)
                else:
                        spr.modulate = Color(1, 1, 1, base_alpha)
                # слот: при движении плотный клин, на позиции — рассредоточение
                var slot := _slot_pos(s["slot"], not moving)
                if not moving and order["type"] == "idle":
                        slot += Vector2(sin(s["ph"] * 3.1) * 5.0, cos(s["ph"] * 2.3) * 5.0)
                var target := slot  # локально == смещение мира (узел не вращается)
                var forced := false
                if st["down"]:
                        # лежит без движения; при переносе — волочится за здоровым
                        spr.rotation = rotate_toward(spr.rotation, facing + PI / 2.0, delta * 8.0)
                        if carrier != null and down_s == s:
                                var cpos: Vector2 = (carrier["off"] as Vector2) + Vector2(9, 7)
                                s["off"] = (s["off"] as Vector2).lerp(cpos, minf(1.0, delta * 3.0))
                        spr.position = s["off"]
                        spr.modulate = Color(0.85, 0.45, 0.4, base_alpha)
                        continue
                # ПОВЕДЕНИЕ СТРЕССА: паника/ступор/ярость
                if st["state"] == "panic":
                        var away := facing + PI
                        if weapon_target != null and is_instance_valid(weapon_target):
                                away = (global_position - weapon_target.global_position).angle()
                        target = (s["off"] as Vector2) + Vector2.from_angle(away) * 70.0
                        forced = true
                elif st["state"] == "stupor":
                        s["vel"] = (s["vel"] as Vector2).lerp(Vector2.ZERO, 0.4)
                        spr.position = s["off"]
                        continue
                elif st["state"] == "rage" and weapon_target != null and is_instance_valid(weapon_target):
                        target = (s["off"] as Vector2) + (weapon_target.global_position - global_position).limit_length(90.0)
                        forced = true
                # медик-носильщик держится у тяжёлого
                if carrier == s and down_s != null:
                        target = (down_s["off"] as Vector2) + Vector2(-11, -8)
                        forced = true
                # пружина к слоту
                var to_t := target - (s["off"] as Vector2)
                var want_v := to_t.limit_length(spd * (1.25 if forced else 1.0))
                var v: Vector2 = (s["vel"] as Vector2).lerp(want_v, minf(1.0, delta * 6.0))
                # расталкивание с соседями (лежачих не толкаем)
                for o in soldiers:
                        if o == s or not o["alive"]:
                                continue
                        if (o["st"] as Dictionary)["down"]:
                                continue
                        var dv: Vector2 = (s["off"] as Vector2) - (o["off"] as Vector2)
                        var dl := dv.length()
                        if dl < 15.0 and dl > 0.01:
                                v += dv.normalized() * (15.0 - dl) * 0.5
                s["vel"] = v
                s["off"] = (s["off"] as Vector2) + v * delta
                spr.position = s["off"]
                # поворот: на марше — по движению, на месте — по facing или к цели
                var spr_rot := facing
                if moving:
                        spr_rot = v.angle() if v.length() > 6.0 else facing
                elif weapon_target != null and is_instance_valid(weapon_target):
                        spr_rot = (weapon_target.global_position - (global_position + (s["off"] as Vector2))).angle()
                var cur: float = spr.rotation
                cur = rotate_toward(cur, spr_rot, delta * 10.0)
                spr.rotation = cur
                # шаг
                if v.length() > 14.0:
                        spr.position.y += sin(hover_t * 11.0 + s["ph"]) * 1.2
        _tick_medics(delta, danger)

func _kill_soldier(s: Dictionary) -> void:
        s["alive"] = false
        var spr: Sprite2D = s["spr"]
        spr.visible = false
        if battle == null:
                return
        # труп в мировых координатах + кровь
        var corpse := Sprite2D.new()
        var tex = spr.texture
        if tex != null:
                corpse.texture = tex
        corpse.scale = spr.scale
        corpse.global_position = global_position + (s["off"] as Vector2)
        corpse.rotation = facing + PI / 2.0 + randf_range(-0.3, 0.3)
        corpse.modulate = Color(0.42, 0.38, 0.35, 0.9)
        corpse.z_index = 2
        battle.fx_layer.add_child(corpse)
        battle.decay_nodes.append({"node": corpse, "t": 26.0})
        battle.fx.blood(corpse.global_position)

# ================= НАЗЕМНАЯ ЛОГИКА + БОЕВОЙ ИНТЕЛЛЕКТ =================
func _ground_logic(delta: float) -> void:
        # прямое управление игроком («играем за военного»)
        if battle != null and battle.direct_ctrl and battle.direct_unit == self:
                # ВАЖНО: авто-огонь здесь НЕ дублируем — им управляет _direct_move_ground
                # (раньше второй вызов стрелял по цели «впереди», пока игрок целился назад)
                _direct_move_ground(delta)
                return
        weapon_target = _pick_weapon_target()
        var want_move := Vector2.ZERO
        match order["type"]:
                "move", "amove":
                        want_move = (order["pos"] as Vector2) - global_position
                        if want_move.length() < 14.0:
                                order["type"] = "idle"
                                want_move = Vector2.ZERO
                        elif def["kind"] == "inf" and weapon_target == null and suppression < 30.0:
                                # ЖИВОЙ МАРШ: перебежками — рывок, короткая остановка,
                                # осмотрелся по сторонам, снова рывок. Как человек, а не поезд.
                                adv_t -= delta
                                if adv_t <= 0.0:
                                        adv_halt = not adv_halt
                                        if adv_halt:
                                                adv_t = randf_range(0.35, 0.95) * pers_caution
                                        else:
                                                adv_t = randf_range(1.3, 2.8) / maxf(0.6, pers_aggro)
                                if adv_halt:
                                        want_move = Vector2.ZERO
                                        # на остановке боец всматривается в сторону цели
                                        scan_t -= delta
                                        if scan_t <= 0.0:
                                                scan_t = randf_range(0.5, 1.1)
                                                facing += randf_range(-0.5, 0.5)
                "board":
                        # идём к технике и садимся в неё
                        if order["target"] != null and is_instance_valid(order["target"]) and order["target"].alive:
                                var bv: Vector2 = (order["target"].global_position as Vector2) - global_position
                                want_move = bv
                                if bv.length() < 54.0:
                                        mount(order["target"])
                                        return
                        else:
                                order["type"] = "idle"
                "attack":
                        if order["target"] != null and is_instance_valid(order["target"]) and order["target"].alive:
                                want_move = _approach_delta()
                        else:
                                order["type"] = "idle"
                "evac":
                        # эвакуация волоком: идём к раненому отряду
                        if evac_target != null and is_instance_valid(evac_target) and evac_target.alive and evac_target.has_wounded():
                                var dv2: Vector2 = (evac_target.global_position as Vector2) - global_position
                                if dv2.length() > 62.0:
                                        want_move = dv2
                                else:
                                        want_move = Vector2.ZERO
                        else:
                                order["type"] = "idle"
                                evac_target = null
                "hold":
                        pass
        # атакующее движение останавливается для стрельбы. БОЙ ПО-НАСТОЯЩЕМУ:
        # увидели врага у цели — встали, огрызаемся из укрытий, и только
        # зачистив рубеж — идём дальше (а не толпой бегом на точку)
        if order["type"] == "amove" and weapon_target != null:
                var d2: float = global_position.distance_to(weapon_target.global_position)
                if d2 < _max_ground_range() * 0.95:
                        want_move = Vector2.ZERO
                        # занять укрытие у остановки (окоп/руина/за домом),
                        # каждый отряд — своё место: фронт наступления широкий
                        if def["kind"] == "inf" and not in_cover and _cover_t <= 0.0 and suppression > 18.0:
                                var side := 1.0 if (_unit_seed % 2) == 0 else -1.0
                                var probe := global_position + Vector2.from_angle((weapon_target.global_position - global_position).angle() + side * PI * 0.5) * randf_range(90.0, 170.0)
                                var cv: Vector2 = battle.find_cover(probe, 220.0)
                                if cv != Vector2.INF:
                                        _cover_goal = cv
                                        _cover_t = 4.5
                                        if not said_cover:
                                                said_cover = true
                                                battle.chatter(self, "Огонь с рубежа! В укрытие!", Color(0.85, 0.75, 0.55))
                        if _cover_t > 0.0 and global_position.distance_to(_cover_goal) > 28.0:
                                want_move = _cover_goal - global_position
        var tile: int = battle.tile_at(global_position)
        in_cover = (tile == battle.T_TRENCH or garrison_obj != null)
        if garrison_obj != null:
                want_move = Vector2.ZERO
        # --- АВТОНОМНОСТЬ: на месте боец сам держит дистанцию и ищет укрытие
        if order["type"] == "idle" or order["type"] == "hold":
                want_move = _combat_brain(delta, want_move)
        var spd: float = def["spd"] * SPD_MULT
        spd *= battle.terrain_speed(global_position, false)
        # ЗЕМЛЯ ПОМОГАЕТ: на своей территории быстрее, на вражеской — медленнее
        if battle.territory != null:
                spd *= battle.territory.speed_for(global_position, team)
        if def["kind"] == "veh" and not passengers.is_empty():
                spd *= 0.88   # машина с пассажирами тяжелеет
        if def["kind"] == "inf":
                spd *= 0.55 if in_cover else 1.0
                if hp < max_hp * 0.4:
                        spd *= 0.55
                spd *= _squad_leg_mult()       # переломы ног и «тяжёлые» на руках
        if suppression > 30.0:
                spd *= 0.6
        if retreat_mode:
                spd *= 1.15
        if want_move.length() > 2.0:
                var dir := want_move.normalized()
                dir = battle.steer(self, dir)
                var target_angle := dir.angle()
                facing = rotate_toward(facing, target_angle, delta * def["rot"])
                var ang_diff := absf(angle_difference(facing, target_angle))
                var move_ok: bool = ang_diff < 1.2 or def["kind"] == "inf"
                if move_ok:
                        vel = Vector2.from_angle(facing) * spd * minf(1.0, 1.4 - ang_diff)
                        global_position += vel * delta
                        stuck_t = 0.0
                else:
                        vel = vel.lerp(Vector2.ZERO, 0.1)
                        stuck_t += delta
                        if stuck_t > 1.6:
                                stuck_t = 0.0
                                facing += randf_range(-1.4, 1.4)
                if def["kind"] == "veh" and randf() < 0.3:
                        battle.spawn_tracks(global_position, facing)
        else:
                vel = vel.lerp(Vector2.ZERO, 0.15)
                if weapon_target != null and is_instance_valid(weapon_target):
                        facing = rotate_toward(facing, (weapon_target.global_position - global_position).angle(), delta * def["rot"])
        rotate_toward_target_fire(delta)

# ---------- тактика одиночного бойца/машины ----------
var _cover_goal := Vector2.ZERO
var _cover_t := 0.0
var _pos_seek_t := 0.0      # таймер «занять огневую позицию» на точке
var _pos_cover_goal := Vector2.ZERO
var _pos_cover_t := 0.0
var _unit_seed := 0         # персональный разброс позиций (каждый — своё место)

func _combat_brain(delta: float, fallback: Vector2) -> Vector2:
        _cover_t = maxf(0.0, _cover_t - delta)
        _sidestep_t = maxf(0.0, _sidestep_t - delta)
        if weapon_target == null or not is_instance_valid(weapon_target):
                # стоим без цели — боец осматривается, как живой
                _no_target_t += delta
                if def["kind"] == "inf" and order["type"] == "idle":
                        scan_t -= delta
                        if scan_t <= 0.0:
                                scan_t = randf_range(1.2, 2.6)
                                facing += randf_range(-0.7, 0.7) * pers_caution
                        # «ОДИН В ОКОПЕ, ДРУГОЙ ЗА ДОМОМ»: вышед на рубеж, каждый
                        # отряд сам ищет себе огневую позицию в укрытии — не толпой
                        if garrison_obj == null and mounted_in == null:
                                _pos_seek_t -= delta
                                if _pos_seek_t <= 0.0:
                                        _pos_seek_t = randf_range(6.0, 11.0) * pers_caution
                                        if not in_cover and suppression < 22.0:
                                                var ang0: float = float(_unit_seed % 628) * 0.01
                                                var probe := global_position + Vector2.from_angle(ang0) * randf_range(110.0, 230.0)
                                                var pc: Vector2 = battle.find_cover(probe, 210.0)
                                                if pc != Vector2.INF and global_position.distance_to(pc) > 55.0:
                                                        _pos_cover_goal = pc
                                                        _pos_cover_t = 7.0
                                                        battle.chatter(self, "Занял позицию, прикрываю.", Color(0.66, 0.78, 0.62))
                                if _pos_cover_t > 0.0:
                                        var dpc := global_position.distance_to(_pos_cover_goal)
                                        if dpc > 30.0:
                                                return _pos_cover_goal - global_position
                                        _pos_cover_t = 0.0
                return fallback
        _no_target_t = 0.0
        var d: float = global_position.distance_to(weapon_target.global_position)
        var band := _effective_band()
        var want := Vector2.ZERO
        # держим дистанцию: подходим или отходим в «пояс эффективности»
        if d > band.y:
                want = (weapon_target.global_position - global_position) * 0.55
        elif d < band.x:
                want = (global_position - weapon_target.global_position) * 0.5
        # пехота без укрытия под огнём — ищет ближайшее укрытие
        if def["kind"] == "inf" and suppression > 30.0 and _cover_t <= 0.0 and not in_cover:
                var c: Vector2 = battle.find_cover(global_position, 300.0)
                if c != Vector2.INF:
                        _cover_goal = c
                        _cover_t = 5.0
                        if not said_cover:
                                said_cover = true
                                battle.chatter(self, "Прижимаюсь к укрытию!", Color(0.85, 0.75, 0.55))
        if _cover_t > 0.0:
                var dc := global_position.distance_to(_cover_goal)
                if dc > 26.0:
                        return (_cover_goal - global_position)
                else:
                        _cover_t = 0.0
        # микрострейф: отстреливаясь из-за укрытия, боец смещается вбок —
        # живое поведение вместо статичной «палки»
        if def["kind"] == "inf" and in_cover and suppression > 20.0 and _sidestep_t <= 0.0:
                _sidestep_t = randf_range(1.1, 2.3)
                _sidestep = Vector2.from_angle(randf() * TAU) * randf_range(24.0, 46.0)
        want += _sidestep * minf(1.0, _sidestep_t * 1.4)
        return want

func _effective_band() -> Vector2:
        var r := _max_ground_range()
        var k := 0.8
        for w in def["wpns"]:
                match w["k"]:
                        "atgm":
                                k = 0.72
                        "rpg":
                                k = 0.45
                        "sniper":
                                k = 0.95
                        "cannon":
                                k = 0.85
        return Vector2(r * k * 0.45, r * k)

func _approach_delta() -> Vector2:
        var rng_max: float = 0.0
        for w in def["wpns"]:
                if w["only"] != "air":
                        rng_max = maxf(rng_max, w["rng"])
        var d: float = global_position.distance_to(order["target"].global_position)
        if d > rng_max * 0.92:
                return order["target"].global_position - global_position
        return Vector2.ZERO

# ---------- движение под прямым управлением ----------
func _direct_move_ground(delta: float) -> void:
        weapon_target = _pick_weapon_target()
        var wm: Vector2 = battle.direct_vec
        var spd: float = def["spd"] * SPD_MULT * 1.1
        spd *= battle.terrain_speed(global_position, false)
        if def["kind"] == "inf":
                spd *= _squad_leg_mult()
                if hp < max_hp * 0.4:
                        spd *= 0.6
        if suppression > 30.0:
                spd *= 0.7
        var prev := global_position
        var moving := wm.length() > 0.12
        if moving:
                var dir := wm.normalized()
                dir = battle.steer(self, dir)
                # TWIN-STICK: пехота двигается НЕЗАВИСИМО от корпуса (страйф),
                # техника разворачивает корпус по ходу, башню ведёт прицел
                if def["kind"] == "inf" and battle.manual_aim:
                        global_position += dir * spd * minf(1.0, wm.length()) * delta
                        vel = dir * spd * minf(1.0, wm.length())
                else:
                        facing = rotate_toward(facing, dir.angle(), delta * def["rot"] * 1.5)
                        vel = Vector2.from_angle(facing) * spd * minf(1.0, wm.length())
                        global_position += vel * delta
                stuck_t = 0.0
                if def["kind"] == "veh" and randf() < 0.3:
                        battle.spawn_tracks(global_position, facing)
        else:
                vel = vel.lerp(Vector2.ZERO, 0.2)
        # TWIN-STICK: ручной прицел правым стиком / мышью.
        # Корпус доворачивается к прицелу БЫСТРО; авто-огонь по чужим целям
        # ПОЛНОСТЬЮ отключен, пока игрок держит прицел — стреляем только куда целимся.
        if battle.manual_aim:
                if def["kind"] == "inf":
                        facing = rotate_toward(facing, battle.manual_ang, delta * def["rot"] * 4.5)
                elif not moving:
                        # стоящая техника разворачивает корпус к прицелу
                        facing = rotate_toward(facing, battle.manual_ang, delta * def["rot"] * 2.0)
                if turret != null:
                        tur_facing = rotate_toward(tur_facing, battle.manual_ang, delta * def["rot"] * 5.0)
        elif moving:
                if turret != null and def["kind"] != "inf":
                        tur_facing = rotate_toward(tur_facing, facing, delta * def["rot"])
        elif weapon_target != null and is_instance_valid(weapon_target):
                facing = rotate_toward(facing, (weapon_target.global_position - global_position).angle(), delta * def["rot"])
        if battle.manual_fire:
                _manual_fire(delta)
        elif not battle.manual_aim:
                rotate_toward_target_fire(delta)
        if battle.tile_blocked(global_position):
                global_position = prev
                vel = Vector2.ZERO
        global_position = battle.clamp_to_map(global_position)
        var tile: int = battle.tile_at(global_position)
        in_cover = (tile == battle.T_TRENCH or garrison_obj != null)

func _manual_fire(delta: float) -> void:
        # twin-stick огонь: ствол по направлению прицела, без автонаводки.
        # Пока стик/мышь удерживаются — НИКАКИХ выстрелов по сторонам.
        for i in range(def["wpns"].size()):
                weapon_cd[i] = maxf(0.0, weapon_cd[i] - delta)
        if jam_t > 0.0:
                return
        if def["kind"] == "inf" and mags <= 0.05:
                return
        var w: Dictionary = def["wpns"][0]
        if w["only"] == "air" and def["wpns"].size() > 1:
                w = def["wpns"][1]
        if w["arc"]:
                return   # навесное — стреляет только по автоцели, руками не ведётся
        if weapon_cd[0] > 0.0:
                return
        var ang: float = battle.manual_ang
        var cur := tur_facing if turret != null else facing
        if absf(angle_difference(cur, ang)) > 0.45:
                return   # ещё доворачиваем ствол (доводка быстрая — 4.5x)
        var tgt = battle.find_target_in_cone(self, ang, w["rng"])
        weapon_target = tgt
        weapon_cd[0] = 1.0 / maxf(0.05, w["rof"])
        _fire_weapon(0, w, tgt, ang)

func _max_ground_range() -> float:
        var r := 0.0
        for w in def["wpns"]:
                if w["only"] != "air":
                        r = maxf(r, w["rng"])
        return r

func rotate_toward_target_fire(delta: float) -> void:
        var primary = null
        if weapon_target != null and is_instance_valid(weapon_target):
                primary = weapon_target
        var rof_mult := 0.78 if _any_rage() else 1.0
        for i in range(def["wpns"].size()):
                weapon_cd[i] = maxf(0.0, weapon_cd[i] - delta)
                var w: Dictionary = def["wpns"][i]
                if w["k"] == "kamikaze":
                        continue
                if jam_t > 0.0:
                        continue
                if def["kind"] == "inf" and mags <= 0.05:
                        continue
                var tgt = _target_for_weapon(w)
                if tgt == null:
                        continue
                var in_rng: bool = global_position.distance_to(tgt.global_position) <= w["rng"]
                if not in_rng:
                        continue
                if global_position.distance_to(tgt.global_position) < def.get("min_rng", 0.0):
                        continue
                var aim: float = (tgt.global_position - global_position).angle()
                var cur := tur_facing if turret != null else facing
                var aim_speed: float = def["rot"] * 2.2 if turret != null else def["rot"]
                if turret != null:
                        tur_facing = rotate_toward(tur_facing, aim, delta * aim_speed)
                if absf(angle_difference(cur, aim)) < 0.18 and weapon_cd[i] <= 0.0:
                        _fire_weapon(i, w, tgt)
                        weapon_cd[i] = (1.0 / maxf(0.05, w["rof"])) * rof_mult
        if primary == null and turret != null:
                tur_facing = rotate_toward(tur_facing, facing, delta * def["rot"])

func _target_for_weapon(w: Dictionary):
        if weapon_target == null or not is_instance_valid(weapon_target):
                return null
        var t = weapon_target
        if w["only"] == "air" and not t.air:
                return null
        if w["only"] == "ground" and t.air:
                return null
        return t

func _pick_weapon_target():
        if weapon_target != null and is_instance_valid(weapon_target) and weapon_target.alive:
                var d: float = global_position.distance_to(weapon_target.global_position)
                if d <= _max_ground_range() * 1.15:
                        return weapon_target
        return battle.find_target(self)

# ---------- вертолёты ----------
func _heli_logic(delta: float) -> void:
        if battle != null and battle.direct_ctrl and battle.direct_unit == self:
                _direct_move_air(delta)
                rotate_toward_target_fire(delta)
                return
        weapon_target = _pick_weapon_target()
        var want := Vector2.ZERO
        match order["type"]:
                "move", "amove":
                        want = (order["pos"] as Vector2) - global_position
                        if want.length() < 20.0:
                                order["type"] = "idle"
                "attack":
                        if order["target"] != null and is_instance_valid(order["target"]) and order["target"].alive:
                                want = order["target"].global_position - global_position
                                if want.length() < 500.0:
                                        want = Vector2.ZERO
                        else:
                                order["type"] = "idle"
        var spd: float = def["spd"] * SPD_MULT
        if weapon_target != null and is_instance_valid(weapon_target) and order["type"] == "idle":
                want = Vector2.ZERO
        if want.length() > 2.0:
                var dir := want.normalized()
                var ta := dir.angle()
                facing = rotate_toward(facing, ta, delta * def["rot"])
                global_position += Vector2.from_angle(facing) * spd * delta
                global_position = battle.clamp_to_map(global_position)
        if weapon_target != null and is_instance_valid(weapon_target):
                if turret == null:
                        facing = rotate_toward(facing, (weapon_target.global_position - global_position).angle(), delta * def["rot"] * 1.5)
        rotate_toward_target_fire(delta)

func _direct_move_air(delta: float) -> void:
        weapon_target = _pick_weapon_target()
        var wm: Vector2 = battle.direct_vec
        var spd: float = def["spd"] * SPD_MULT
        if wm.length() > 0.12:
                var dir := wm.normalized()
                facing = rotate_toward(facing, dir.angle(), delta * def["rot"] * 1.4)
                global_position += Vector2.from_angle(facing) * spd * minf(1.0, wm.length()) * delta
        global_position = battle.clamp_to_map(global_position)

# ---------- дроны-камикадзе ----------
func _drone_logic(delta: float) -> void:
        var tgt = order["target"]
        if tgt == null or not is_instance_valid(tgt) or not tgt.alive:
                tgt = battle.find_target(self)
                order["target"] = tgt
        if tgt != null:
                var dir: Vector2 = (tgt.global_position - global_position)
                var d := dir.length()
                facing = rotate_toward(facing, dir.angle(), delta * def["rot"])
                global_position += Vector2.from_angle(facing) * def["spd"] * SPD_MULT * delta
                if d < 46.0:
                        battle.explosion_at(global_position, def["wpns"][0]["d"], def["wpns"][0]["splash"], def["wpns"][0]["ap"], self)
                        battle.on_unit_died(self, self)
                        return
        else:
                global_position += Vector2.from_angle(facing) * def["spd"] * SPD_MULT * delta
        global_position = battle.clamp_to_map(global_position)

# ================= ХАРДКОР: КРОВЬ, МЕДИКИ, ЭВАКУАЦИЯ =================
func _hardcore_tick(delta: float) -> void:
        if def["kind"] != "inf" or soldiers.is_empty():
                return
        var danger := suppression > 18.0 or (weapon_target != null and is_instance_valid(weapon_target))
        for s in soldiers:
                if not s["alive"]:
                        continue
                Med.tick(s, delta, danger)
                var st: Dictionary = s["st"]
                if st["state"] == "panic" and st["scream_cd"] <= 0.0:
                        st["scream_cd"] = 3.5 + randf() * 3.0
                        if team == G.TEAM_PLAYER:
                                G.play_sfx("alarm", -18.0, 1.6)
        # кровопотеря: истекающий кровью отряд слабеет сам
        var bleeding := 0.0
        for s in soldiers:
                if s["alive"]:
                        bleeding += Med.total_bleed(s)
        if bleeding > 0.0:
                var drain: float = bleeding * 0.5 * delta
                hp -= drain
                bleed_tick += drain
                if bleed_tick > 5.0:
                        bleed_tick = 0.0
                        battle.fx.blood(global_position + Vector2(randf_range(-14, 14), randf_range(-10, 10)))
                if hp <= 0.0:
                        battle.on_unit_died(self, null)
                        return
        treat_t -= delta
        if treat_t <= 0.0:
                treat_t = 2.8
                _auto_treat(false)
        # эвакуация: идём к раненому отряду и вытаскиваем в укрытие
        if evac_target != null:
                if not is_instance_valid(evac_target) or not evac_target.alive:
                        evac_target = null
                        if order["type"] == "evac":
                                order = {"type": "idle", "pos": global_position, "target": null}
                elif evac_target.has_wounded() and global_position.distance_to(evac_target.global_position) < 80.0:
                        evac_target.treat_t = minf(evac_target.treat_t, 0.4)

func _auto_treat(force: bool) -> void:
        # медик отряда (или напарник) проводит этапное лечение худшего раненого
        var worst = null
        var worst_score := -1.0
        for s in soldiers:
                if not s["alive"]:
                        continue
                var item: String = Med.worst_item(s)
                if item == "":
                        continue
                var score := 1.0
                if (s["st"] as Dictionary)["down"]:
                        score = 3.0
                elif Med.total_bleed(s) >= 2.0:
                        score = 2.0
                if score > worst_score:
                        worst_score = score
                        worst = s
        if worst == null:
                return
        var has_medic := false
        for stype in def["squad"]:
                if stype == "med":
                        has_medic = true
                        break
        if not has_medic and not force and randf() < 0.45:
                return   # без медика помощь медленнее
        var item2: String = Med.worst_item(worst)
        if item2 != "":
                Med.treat(worst, item2)
                if team == G.TEAM_PLAYER and (worst["st"] as Dictionary)["down"] == false:
                        pass

func has_wounded() -> bool:
        if def["kind"] != "inf":
                return false
        for s in soldiers:
                if s["alive"] and (Med.worst_item(s) != "" or (s["st"] as Dictionary)["down"]):
                        return true
        return false

func _squad_leg_mult() -> float:
        if soldiers.is_empty():
                return 1.0
        var m := 0.0
        var n := 0
        var down_n := 0
        for s in soldiers:
                if s["alive"]:
                        n += 1
                        m += Med.leg_mult(s)
                        if (s["st"] as Dictionary)["down"]:
                                down_n += 1
        if n == 0:
                return 1.0
        var res: float = m / float(n)
        if down_n > 0:
                res *= 0.78   # несут тяжёлого на руках
        return maxf(0.3, res)

func _squad_arm_mult() -> float:
        if soldiers.is_empty():
                return 1.0
        var m := 0.0
        var n := 0
        for s in soldiers:
                if s["alive"]:
                        n += 1
                        m += Med.arm_mult(s)
        return clampf(m / float(maxi(1, n)), 1.0, 1.9)

func _any_rage() -> bool:
        for s in soldiers:
                if s["alive"] and (s["st"] as Dictionary)["state"] == "rage":
                        return true
        return false

func buddy_died() -> void:
        Med.buddy_died(soldiers)

func squad_stress_avg() -> float:
        if soldiers.is_empty():
                return 0.0
        var t := 0.0
        var n := 0
        for s in soldiers:
                if s["alive"]:
                        n += 1
                        t += (s["st"] as Dictionary)["stress"]
        return t / float(maxi(1, n))

func _tick_medics(delta: float, danger: bool) -> void:
        pass   # лечение ведёт _hardcore_tick (в _auto_treat)

# ================= УРОН И СМЕРТЬ =================
func take_damage(dmg: float, ap_kind: String, src) -> void:
        if not alive:
                return
        if mounted_in != null:
                return   # сидим в броне — урон держит машина
        var mult: float = 1.0
        var armor: String = def["armor"]
        if G.AP_TABLE.has(ap_kind) and G.AP_TABLE[ap_kind].has(armor):
                mult = G.AP_TABLE[ap_kind][armor]
        if in_cover:
                mult *= 0.55
        if team == G.TEAM_PLAYER:
                mult *= float(G.DIFFICULTY[G.save["difficulty"]]["enemy_dmg"])
        var explosive := ap_kind in ["he", "frag"] or splash_like(dmg)
        if def["kind"] == "inf" and not soldiers.is_empty():
                # АНАТОМИЧЕСКАЯ РАНА: случайному живому бойцу в случайную зону
                var living: Array = []
                for s in soldiers:
                        if s["alive"] and not (s["st"] as Dictionary)["down"]:
                                living.append(s)
                if living.is_empty():
                        for s in soldiers:
                                if s["alive"]:
                                        living.append(s)
                if not living.is_empty():
                        var victim: Dictionary = living[randi() % living.size()]
                        mult *= Med.hit_soldier(victim, explosive)
        hp -= dmg * mult
        suppression = minf(100.0, suppression + dmg * 0.12)
        # «КОНТАКТ! Работают по нам!» — первый же обстрел озвучиваем по рации
        if def["kind"] == "inf" and team == G.TEAM_PLAYER and not said_contact and suppression > 15.0:
                said_contact = true
                var dir_txt := ""
                if src != null and is_instance_valid(src):
                        var da: float = (src.global_position - global_position).angle()
                        dir_txt = " с %s" % ["севера", "северо-востока", "востока", "юго-востока", "юга", "юго-запада", "запада", "северо-запада"][wrapi(roundi(da / TAU * 8.0), 0, 8)]
                battle.chatter(self, "Контакт! Работают по нам" + dir_txt + "!", Color(0.9, 0.6, 0.45))
        if def["kind"] == "inf":
                var samt: float = 13.0 if explosive else 7.0
                for s in soldiers:
                        if s["alive"]:
                                Med.add_stress(s, samt * randf_range(0.7, 1.3))
        if hp <= 0:
                battle.on_unit_died(self, src)

func splash_like(dmg: float) -> bool:
        return dmg >= 55.0

func add_suppression(amount: float) -> void:
        suppression = minf(100.0, suppression + amount)

# ================= ПРИКАЗЫ =================
func set_order_move(pos: Vector2) -> void:
        order = {"type": "move", "pos": pos, "target": null}
        garrison_obj = null
        retreat_mode = false

func set_order_amove(pos: Vector2) -> void:
        order = {"type": "amove", "pos": pos, "target": null}
        garrison_obj = null

func set_order_attack(tgt) -> void:
        order = {"type": "attack", "pos": tgt.global_position, "target": tgt}
        garrison_obj = null

func set_order_hold() -> void:
        order = {"type": "hold", "pos": global_position, "target": null}

func set_order_evac(tgt) -> void:
        # эвакуация волоком: подойти к раненым и вытащить их в укрытие
        order = {"type": "evac", "pos": tgt.global_position, "target": tgt}
        garrison_obj = null
        evac_target = tgt

func resupply() -> void:
        # пополнение от снабжения (Урал/БМП на разгрузке, ящики)
        mags = mags_max
        ammo_warned = false
        said_low_ammo = false
        jam_t = 0.0

func set_order_stop() -> void:
        order = {"type": "idle", "pos": global_position, "target": null}

func set_garrison(obj) -> void:
        garrison_obj = obj
        order = {"type": "hold", "pos": obj["pos"], "target": null}
        global_position = obj["pos"]

# ================= ПОСАДКА / ВЫСАДКА =================
func set_order_board(veh) -> void:
        if def["kind"] != "inf" or veh == null:
                return
        order = {"type": "board", "pos": veh.global_position, "target": veh}
        garrison_obj = null

func mount(veh) -> void:
        if def["kind"] != "inf" or veh == null or not is_instance_valid(veh) or not veh.alive:
                return
        if mounted_in != null:
                dismount()
        mounted_in = veh
        veh.passengers.append(self)
        global_position = veh.global_position
        vel = Vector2.ZERO
        order = {"type": "idle", "pos": global_position, "target": null}
        for s in soldiers:
                (s["spr"] as Sprite2D).visible = false
        ring.visible = false
        selected = false
        z_index = 1
        if battle != null:
                battle.on_mount(self, veh)

func dismount(dangerous := false) -> void:
        if mounted_in == null:
                return
        var veh = mounted_in
        mounted_in = null
        if is_instance_valid(veh):
                veh.passengers.erase(self)
                if veh.driver == self:
                        veh.driver = null
                global_position = battle.clamp_to_map(veh.global_position + Vector2(randf_range(-40, 40), randf_range(30, 52)))
        z_index = 6
        facing = PI / 2.0
        order = {"type": "idle", "pos": global_position, "target": null}
        for s in soldiers:
                if s["alive"]:
                        (s["spr"] as Sprite2D).visible = true
        if battle != null:
                battle.on_dismount(self, dangerous)

# ================= ВЫСТРЕЛЫ =================
func _fire_weapon(widx: int, w: Dictionary, tgt, force_ang := -999.0) -> void:
        loud_t = 2.0
        battle.on_unit_fired(self)
        # «Вижу цель!» — после долгой тишины боец докладывает о новом контакте
        if team == G.TEAM_PLAYER and _no_target_t > 4.5 and tgt != null and widx == 0:
                _no_target_t = 0.0
                battle.chatter(self, "Вижу цель — огонь!", Color(0.75, 0.85, 0.6))
        var muzzle_pos := global_position
        var ang: float = force_ang if force_ang > -900.0 else (tgt.global_position - global_position).angle() if tgt != null else facing
        if turret != null:
                var pivot: Vector2 = global_position + ((def.get("tur_off", Vector2.ZERO) as Vector2) * VIS_SCL).rotated(facing)
                muzzle_pos = pivot + ((def.get("muzzle", Vector2(20, 0)) as Vector2) * VIS_SCL).rotated(tur_facing)
                if force_ang <= -900.0:
                        ang = tur_facing
        elif def["kind"] == "inf" and not soldiers.is_empty():
                # ствол первого живого бойца
                for s in soldiers:
                        if s["alive"]:
                                muzzle_pos = global_position + (s["off"] as Vector2) + Vector2.from_angle(facing) * 16.0
                                break
        var mz_size := 24
        if w["k"] in ["cannon", "howitzer", "mlrs"]:
                mz_size = 46
        elif w["k"] in ["ac", "rockets"]:
                mz_size = 34
        battle.fx.muzzle(muzzle_pos, ang, mz_size)
        match w["k"]:
                "cannon":
                        G.play_sfx("shot_cannon", -2.0)
                        battle.shake(3.0)
                "howitzer", "mlrs":
                        G.play_sfx("shot_cannon", -4.0, 0.8)
                        G.play_sfx("launch_rocket", -6.0)
                "ac":
                        G.play_sfx("shot_mg", -4.0, 0.7)
                "sniper":
                        G.play_sfx("shot_mg", -6.0, 1.4)
                "atgm", "sam":
                        G.play_sfx("launch_atgm" if w["k"] == "atgm" else "launch_sam", -4.0)
                "rpg":
                        G.play_sfx("shot_cannon", -8.0, 1.5)
                _:
                        G.play_sfx("shot_mg", -9.0)
        var shots: int = int(maxf(1.0, float(w.get("burst", 1))))
        # ХАРДКОР: расход магазинов и заклинивание (пехота)
        if def["kind"] == "inf":
                mags = maxf(0.0, mags - shots / 26.0)
                if team == G.TEAM_PLAYER and not said_low_ammo and mags < mags_max * 0.3:
                        said_low_ammo = true
                        battle.chatter(self, "Патроны на исходе — перезарядка!", Color(0.9, 0.75, 0.45))
                if randf() < 0.0018 + suppression * 0.00005:
                        jam_t = 2.6
                        if team == G.TEAM_PLAYER:
                                battle.add_log("ОТРЯД: оружие заклинило — перезарядка с чисткой...", Color(0.95, 0.65, 0.4))
                        return
                if mags <= 0.05 and team == G.TEAM_PLAYER and not ammo_warned:
                        ammo_warned = true
                        battle.add_log("ПАТРОНОВ НЕТ! Подведите снабжение (Урал) или ящик боеприпасов", Color(0.95, 0.5, 0.4))
        for s_i in range(shots):
                var spread: float = w["spr"]
                if suppression > 40.0:
                        spread *= 1.8
                if def["kind"] == "inf":
                        spread *= _squad_arm_mult()   # раненые руки хуже стреляют
                if battle.cmd_aura_for(global_position, team):
                        spread *= 0.88
                var a := ang + randf_range(-spread, spread)
                var dest: Vector2 = tgt.global_position if tgt != null else muzzle_pos + Vector2.from_angle(ang) * minf(w["rng"], 720.0)
                if w["arc"]:
                        dest = dest + Vector2(randf_range(-30, 30), randf_range(-30, 30)) * (1.0 if shots == 1 else 0.5)
                battle.spawn_proj({
                        "kind": w["proj"], "from": muzzle_pos, "dest": dest, "target": tgt,
                        "team": team, "dmg": w["d"], "ap": w["ap"], "splash": w["splash"],
                        "ps": w["ps"], "src": self, "ang": a,
                })

# ================= ОТРИСОВКА ПОВЕРХ =================
func _draw() -> void:
        if not alive:
                return
        if def.get("hero", false) and mounted_in == null:
                # ЗОЛОТОЙ ШЕВРОН КОМАНДИРА — сразу видно, за кого играем
                draw_rect(Rect2(-7, -44, 14, 3), Color(0.95, 0.8, 0.3, 0.95))
                draw_polygon(PackedVector2Array([Vector2(-7, -41), Vector2(0, -34), Vector2(7, -41)]),
                        PackedColorArray([Color(0.95, 0.8, 0.3, 0.85)]))
                draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(0.95, 0.8, 0.3, 0.5), 1.5)
        if def["kind"] == "veh" and not passengers.is_empty():
                # значок «возим пехоту» с числом отрядов
                var n := passengers.size()
                draw_rect(Rect2(12, -30, 22, 13), Color(0.08, 0.09, 0.07, 0.85))
                draw_rect(Rect2(12, -30, 22, 13), Color(0.55, 0.75, 0.45, 0.9), false, 1.0)
                draw_string(ThemeDB.fallback_font, Vector2(15, -19.5), "%d отр." % n,
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.95, 0.75))
        if hp < max_hp:
                var frac := clampf(hp / max_hp, 0.0, 1.0)
                var col := Color(0.35, 0.9, 0.35)
                if frac < 0.6:
                        col = Color(0.95, 0.8, 0.25)
                if frac < 0.3:
                        col = Color(0.95, 0.3, 0.25)
                var w := 40.0 if def["kind"] != "inf" else 30.0
                var y := -30.0 if def["kind"] != "inf" else -24.0
                draw_rect(Rect2(-w / 2, y, w, 4), Color(0, 0, 0, 0.6))
                draw_rect(Rect2(-w / 2, y, w * frac, 4), col)
        if def["kind"] == "inf":
                # боезапас: маленькая полоска патронов под HP
                if mags_max > 1.0:
                        var af := clampf(mags / mags_max, 0.0, 1.0)
                        draw_rect(Rect2(-15, -19, 30, 2.5), Color(0, 0, 0, 0.55))
                        draw_rect(Rect2(-15, -19, 30.0 * af, 2.5), Color(0.85, 0.75, 0.3, 0.95))
                # индикатор стресса (глаз страха)
                var stv := squad_stress_avg()
                if stv > 45.0:
                        draw_circle(Vector2(0, -38), 3.2, Color(1.0, 0.35, 0.2, 0.85))
                # «тяжёлый» — красный крест над отрядом (нужна помощь)
                for s in soldiers:
                        if s["alive"] and (s["st"] as Dictionary)["down"]:
                                draw_rect(Rect2(-6, -46, 12, 3), Color(0.95, 0.3, 0.25, 0.9))
                                draw_rect(Rect2(-1.5, -50.5, 3, 12), Color(0.95, 0.3, 0.25, 0.9))
                                break
        if jam_t > 0.0:
                draw_circle(Vector2(14, -34), 3.0, Color(0.95, 0.55, 0.2, 0.9))
        if suppression > 30.0:
                draw_circle(Vector2(0, -38), 3.0, Color(1.0, 0.85, 0.2, 0.9))
        if in_cover:
                draw_rect(Rect2(-3, -40, 6, 6), Color(0.4, 0.9, 0.5, 0.85))
        if garrison_obj != null:
                draw_arc(Vector2.ZERO, 16.0, 0, TAU, 16, Color(0.5, 0.8, 1.0, 0.8), 1.5)
