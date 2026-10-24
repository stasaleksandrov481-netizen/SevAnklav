# ============================================================
# КОМАНДУЮЩИЙ ПРОТИВНИКА (ИИ)
# Состав армии по сектору, волны атак, захват точек,
# артиллерия по скоплениям, ПВО против авиации,
# мины ФОА на дорогах, дроны-камикадзе, отступление побитых.
# ============================================================
extends Node

var battle = null
var req := 400.0          # реквизиция ИИ
var think_timer := 0.0
var wave_timer := 0.0
var ability_timer := 0.0
var attack_group: Array = []
var compositions := {}    # целевые доли ролей

func setup(btl) -> void:
        battle = btl
        # состав армии зависит от номера сектора и фракции
        var fac: String = battle.faction_enemy
        var idx: int = battle.sector_idx
        compositions = {
                "infantry": 0.35,
                "at": 0.15,
                "tank": 0.12 + idx * 0.008,
                "arty": 0.1,
                "aa": 0.08,
                "recon": 0.06,
                "support": 0.08,
                "air": 0.06 if idx >= 8 else 0.0,
        }

func give_income(amount: float) -> void:
        req += amount

func _process(delta: float) -> void:
        if battle == null or battle.battle_over != "" or battle.paused or battle.cutscene:
                return
        think_timer -= delta
        wave_timer -= delta
        ability_timer -= delta
        if think_timer <= 0.0:
                think_timer = 2.0
                _think()
        if wave_timer <= 0.0:
                wave_timer = randf_range(35.0, 55.0)
                _launch_wave()
        if ability_timer <= 0.0:
                ability_timer = randf_range(20.0, 35.0)
                _use_abilities()
        _defense_react(delta)

# ================= ЛОГИКА =================
func _my_units() -> Array:
        var res := []
        for u in battle.units:
                if is_instance_valid(u) and u.alive and u.team == G.TEAM_ENEMY:
                        res.append(u)
        return res

func _count_role(role: String) -> int:
        var n := 0
        for u in _my_units():
                if u.def["role"] == role:
                        n += 1
        return n

func _pick_build() -> String:
        var fac: String = battle.faction_enemy
        # приоритет: ПВО если у игрока авиация, иначе по недобору ролей
        var player_air := 0
        for u in battle.units:
                if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and u.air:
                        player_air += 1
        if player_air >= 1 and _count_role("aa") < 2:
                var aa_id := _cheapest_of_role(fac, "aa")
                if aa_id != "":
                        return aa_id
        var needs := {
                "infantry": 0.4, "at": 0.15, "tank": 0.15, "arty": 0.1, "aa": 0.08, "recon": 0.06, "support": 0.06,
        }
        for role in ["infantry", "at", "tank", "arty", "aa", "recon", "support"]:
                var have := _count_role(role)
                if have < 1 or (have < 6 and randf() < 0.5):
                        var id := _cheapest_of_role(fac, role)
                        if id != "":
                                return id
        return _cheapest_of_role(fac, "infantry")

func _cheapest_of_role(fac: String, role: String) -> String:
        var best := ""
        var bc := 1e9
        for id in G.DB:
                if id.begins_with("_"):
                        continue
                var d: Dictionary = G.DB[id]
                if d["fac"] != fac or d["role"] != role:
                        continue
                if d["kind"] == "heli" or d["kind"] == "drone":
                        continue
                if d["cost"] < bc:
                        bc = d["cost"]
                        best = id
        return best

func _deploy_at(pos: Vector2, id: String) -> void:
        var u = battle._spawn_unit(id, G.TEAM_ENEMY, pos + Vector2(randf_range(-100, 100), randf_range(-100, 100)))
        if u != null:
                if u.air:
                        u.global_position = Vector2(pos.x + randf_range(-300, 300), -100.0)
                        u.set_order_move(pos)
                else:
                        u.set_order_amove(pos + Vector2(randf_range(-120, 120), randf_range(-140, 40)))
                battle.add_log("РАЗВЕДКА: противник ввёл в бой " + G.DB[id]["name"], Color(0.85, 0.7, 0.5))

func _think() -> void:
        # развёртывание
        if req >= 150.0:
                var id := _pick_build()
                if id != "":
                        var cost: float = G.DB[id]["cost"]
                        if req >= cost:
                                req -= cost
                                _deploy_at(battle.fob_enemy, id)
        # ИИ отступляет побитую технику (ветеран+)
        if G.save["difficulty"] >= 1:
                for u in _my_units():
                        if not u.air and u.def["kind"] == "veh" and u.hp < u.max_hp * 0.22 and not u.retreat_mode:
                                u.retreat_mode = true
                                u.set_order_move(battle.fob_enemy)
        # артиллерия бьёт по скоплениям игрока
        _arty_strike()
        # мины ФОА на дорогах
        if battle.faction_enemy == "foa" and randf() < 0.25:
                for u in _my_units():
                        if u.def.get("mines", 0) > 0:
                                # посылаем сапёра в сторону центра карты
                                u.set_order_amove(Vector2(30.5 * battle.TS, 22.0 * battle.TS))
                                break

func _arty_strike() -> void:
        # ищем скопление игрока, видим ИИ (упрощение: ИИ «в курсе» видимых ему целей)
        var clusters := {}
        for u in battle.units:
                if not is_instance_valid(u) or not u.alive or u.team != G.TEAM_PLAYER:
                        continue
                var key := Vector2i(int(u.global_position.x / 400.0), int(u.global_position.y / 400.0))
                clusters[key] = clusters.get(key, 0) + 1
        var best_key := Vector2i.ZERO
        var best_n := 1
        for k in clusters:
                if clusters[k] > best_n:
                        best_n = clusters[k]
                        best_key = k
        if best_n >= 3:
                var center := Vector2((best_key.x + 0.5) * 400.0, (best_key.y + 0.5) * 400.0)
                for u in _my_units():
                        if u.def["role"] == "arty" and is_instance_valid(u) and u.alive:
                                var d: float = u.global_position.distance_to(center)
                                var rng: float = u.def["wpns"][0]["rng"]
                                var min_rng: float = u.def.get("min_rng", 0.0)
                                if d < rng and d > min_rng:
                                        # залп
                                        var w: Dictionary = u.def["wpns"][0]
                                        var shots: int = mini(6, w.get("burst", 1) * 3)
                                        for i in range(shots):
                                                var dest := center + Vector2(randf_range(-180, 180), randf_range(-180, 180))
                                                battle.spawn_proj({
                                                        "kind": "arcshell", "from": u.global_position + Vector2(0, -300), "dest": dest,
                                                        "team": G.TEAM_ENEMY, "dmg": w["d"], "ap": w["ap"], "splash": w["splash"],
                                                        "ps": 0, "src": u,
                                                })
                                        G.play_sfx("cannon_far", -6.0)
                                        return

func _launch_wave() -> void:
        # собираем ударную группу: свободные боевые юниты (часть оставляем в резерве)
        var fighters := []
        for u in _my_units():
                if u.def["role"] in ["infantry", "at", "tank", "recon", "air"] and u.order["type"] == "idle":
                        fighters.append(u)
        var reserve := 1 + int(G.save["difficulty"])
        while fighters.size() - reserve < 4 and fighters.size() > 0 and reserve > 0:
                fighters.pop_back()
                reserve -= 1
        if fighters.size() < 4:
                return
        # цель: самая слабозащищённая точка игрока
        var target_pt: Dictionary = {}
        var best_score := 1e9
        for p in battle.points:
                var defenders := 0
                for u in battle.units:
                        if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and not u.air:
                                if u.global_position.distance_to(p["pos"]) < 420.0:
                                        defenders += 1
                var score: float = defenders + (0.0 if p["owner"] == G.TEAM_PLAYER else -1.5)
                if score < best_score:
                        best_score = score
                        target_pt = p
        if target_pt.is_empty():
                return
        # дымовая завеса перед атакой (по фракции ФОА/Шакал — излюбленный приём)
        if randf() < 0.5 and battle.faction_enemy != "sak":
                for i in range(2):
                        battle.fx.smoke_screen(target_pt["pos"] + Vector2(randf_range(-160, 160), randf_range(-160, 160)))
        # ФЛАНГИ: группа делится пополам, каждая заходит со своей стороны
        var mid := fighters.size() / 2
        var dir_to: Vector2 = (target_pt["pos"] - battle.fob_enemy).normalized()
        var side: Vector2 = dir_to.rotated(PI / 2.0)
        for i in range(fighters.size()):
                var u = fighters[i]
                var flank_off: Vector2 = side * (240.0 if i % 2 == 0 else -240.0)
                var wp: Vector2 = target_pt["pos"] + flank_off + Vector2(randf_range(-140, 140), randf_range(-140, 140))
                if i == mid - 1 or i == fighters.size() - 1:
                        u.set_order_amove(target_pt["pos"] + Vector2(randf_range(-160, 160), randf_range(-160, 160)))
                else:
                        u.set_order_amove(wp)
        battle.add_log("РАДИОПЕРЕХВАТ: противник пошёл в атаку на сектор " + target_pt["id"], Color(0.9, 0.6, 0.4))
        G.play_sfx("alarm", -10.0)

func _use_abilities() -> void:
        # ИИ использует способности по своей фракции
        var fac: String = battle.faction_enemy
        var cluster = _player_cluster()
        if cluster == null:
                return
        var pos: Vector2 = cluster.global_position
        if fac == "foa":
                # дроны на бронетехнику
                var tanks := 0
                for u in _my_units():
                        if u.def["kind"] == "drone":
                                tanks += 1
                if tanks < 3 and req >= 400.0:
                        for i in range(2):
                                var t = battle._best_enemy_armor(G.TEAM_ENEMY)
                                if t != null:
                                        var d = battle._spawn_unit("foa_drone", G.TEAM_ENEMY, Vector2(pos.x + randf_range(-200, 200), -100))
                                        if d != null:
                                                d.set_order_attack(t)
                        req -= 400.0
        elif fac == "jack" and req >= 600.0:
                battle._call_airstrike(pos, G.TEAM_ENEMY)
                req -= 600.0
        # артиллерийский налёт как способность (на поздних секторах)
        if battle.sector_idx >= 6 and req >= 450.0 and randf() < 0.4:
                battle._call_arty(pos, G.TEAM_ENEMY, 6)
                req -= 450.0

func _player_cluster():
        var best = null
        var bs := -1
        for u in battle.units:
                if not is_instance_valid(u) or not u.alive or u.team != G.TEAM_PLAYER:
                        continue
                var n := 0
                for v in battle.units:
                        if is_instance_valid(v) and v.alive and v.team == G.TEAM_PLAYER and v.global_position.distance_to(u.global_position) < 320.0:
                                n += 1
                if n > bs:
                        bs = n
                        best = u
        return best if bs >= 2 else null

func _defense_react(delta: float) -> void:
        # держим свои точки: бездельники занимают окопы рядом с захваченными секторами
        for p in battle.points:
                if p["owner"] != G.TEAM_ENEMY:
                        continue
                var guards := 0
                for u in battle.units:
                        if is_instance_valid(u) and u.alive and u.team == G.TEAM_ENEMY and not u.air:
                                if u.global_position.distance_to(p["pos"]) < 330.0:
                                        guards += 1
                if guards >= 2:
                        continue
                for u in _my_units():
                        if u.order["type"] == "idle" and u.def["role"] in ["infantry", "at"]:
                                u.set_order_amove(p["pos"] + Vector2(randf_range(-150, 150), randf_range(-150, 150)))
                                break
        # реакция на прорыв игрока к штабу ИИ
        var threat_near_hq := false
        for u in battle.units:
                if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER:
                        if u.global_position.distance_to(battle.fob_enemy) < 900.0:
                                threat_near_hq = true
                                break
        if threat_near_hq:
                for u in _my_units():
                        if u.order["type"] == "idle" and u.def["role"] in ["infantry", "at", "tank"]:
                                u.set_order_amove(battle.fob_enemy + Vector2(randf_range(-250, 250), randf_range(80, 220)))
