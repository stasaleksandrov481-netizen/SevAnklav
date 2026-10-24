# ============================================================
# СНАРЯДЫ И РАКЕТЫ
# Виды: tracer (пули), shell (снаряды), atgm (ПТУР с наведением),
# sam (ЗУР), flak (зенитки), rocket (НАРС), bomb (авиабомба),
# arcshell (артиллерия по дуге)
# ============================================================
extends Node2D

var kind := "tracer"
var from := Vector2.ZERO
var dest := Vector2.ZERO
var target = null        # цель наведения (atgm/sam)
var team := 1
var dmg := 10.0
var ap := "kinetic"
var splash := 0.0
var ps := 1000.0
var src = null
var ang := 0.0
var battle = null

var vel := Vector2.ZERO
var traveled := 0.0
var max_range := 3000.0
var arc_h := 0.0
var arc_t := 0.0
var arc_dur := 1.0
var trail_t := 0.0
var life := 0.0
var sprite: Sprite2D
var dead := false

func setup(cfg: Dictionary, btl) -> void:
        battle = btl
        kind = cfg["kind"]
        from = cfg["from"]
        global_position = from
        dest = cfg["dest"]
        target = cfg.get("target", null)
        team = cfg["team"]
        dmg = cfg["dmg"]
        ap = cfg["ap"]
        splash = cfg["splash"]
        ps = cfg["ps"]
        src = cfg.get("src", null)
        ang = cfg.get("ang", 0.0)
        z_index = 10
        ang = cfg.get("ang", (dest - from).angle())
        match kind:
                "tracer":
                        vel = Vector2.from_angle(ang) * ps
                        max_range = 1600.0
                        _make_sprite("fx_tracer2", 1.3)
                "shell":
                        vel = Vector2.from_angle(ang) * ps
                        max_range = 2200.0
                        _make_sprite("fx_shell", 1.6)
                "flak":
                        vel = Vector2.from_angle(ang) * ps
                        max_range = 1300.0
                        _make_sprite("fx_flak", 1.2)
                "rocket":
                        vel = Vector2.from_angle(ang) * 700.0
                        max_range = 1400.0
                        _make_sprite("fx_atgm", 1.0)
                "bomb":
                        vel = Vector2.from_angle(ang) * 620.0
                        max_range = 2000.0
                        _make_sprite("fx_bomb", 1.0)
                "atgm":
                        vel = Vector2.from_angle(ang) * maxf(200.0, ps)
                        max_range = 2200.0
                        _make_sprite("fx_atgm", 1.0)
                "sam":
                        vel = Vector2.from_angle(ang) * ps
                        max_range = 1800.0
                        _make_sprite("fx_sam", 1.0)
                "arcshell":
                        arc_h = from.distance_to(dest) * 0.18 + 60.0
                        arc_dur = clampf(from.distance_to(dest) / 520.0, 0.7, 3.2)
                        arc_t = 0.0
                        rotation = 0
                        _make_sprite("fx_shell", 2.2)

func _make_sprite(tex: String, scl: float) -> void:
        sprite = Sprite2D.new()
        var t = G.tex(tex)
        if t:
                sprite.texture = t
        sprite.rotation = ang
        sprite.scale = Vector2(scl, scl)
        add_child(sprite)

func _physics_process(delta: float) -> void:
        if dead or battle == null:
                return
        if battle.paused:
                return
        life += delta
        if life > 6.0:
                queue_free()
                return
        match kind:
                "arcshell":
                        _arc_move(delta)
                "atgm", "sam":
                        _homing_move(delta)
                _:
                        _direct_move(delta)

func _direct_move(delta: float) -> void:
        var step := vel * delta
        global_position += step
        traveled += step.length()
        # попадание по площади
        var hit := _check_hits()
        if traveled > max_range:
                if splash > 0.0:
                        _boom(global_position)
                else:
                        queue_free()

func _check_hits() -> bool:
        var hit_any := false
        # ядро попадания: точка впереди
        for u in battle.units:
                if not is_instance_valid(u) or not u.alive or u.team == team:
                        continue
                var should_hit := true
                if u.air and kind in ["tracer", "shell", "flak", "rocket"]:
                        should_hit = true
                if not should_hit:
                        continue
                var d := global_position.distance_to(u.global_position)
                var rad: float = u.def["radius"] + 6.0
                if kind == "tracer":
                        rad *= 0.8
                if d <= rad:
                        if splash > 0.0:
                                _boom(global_position)
                        else:
                                u.take_damage(dmg, ap, src)
                                _die()
                        return true
        return false

func _homing_move(delta: float) -> void:
        # наведение (ПТУР, ЗУР)
        if target != null and is_instance_valid(target) and target.alive:
                dest = target.global_position
        var want := (dest - global_position).angle()
        var turn := 4.5 if kind == "sam" else 2.8
        var cur := vel.angle()
        var diff := angle_difference(cur, want)
        cur += clampf(diff, -turn * delta, turn * delta)
        vel = Vector2.from_angle(cur) * vel.length()
        global_position += vel * delta
        rotation = 0
        if sprite:
                sprite.rotation = cur
        trail_t += delta
        if trail_t > 0.04:
                trail_t = 0.0
                battle.fx.puff(global_position - vel.normalized() * 8.0, 1)
        traveled += vel.length() * delta
        # попадание
        for u in battle.units:
                if not is_instance_valid(u) or not u.alive or u.team == team:
                        continue
                if kind == "sam" and not u.air:
                        continue
                var d := global_position.distance_to(u.global_position)
                if d <= u.def["radius"] + 10.0:
                        _boom(global_position)
                        return
        if traveled > max_range or global_position.distance_to(dest) < 12.0:
                _boom(global_position)

func _arc_move(delta: float) -> void:
        arc_t += delta / arc_dur
        var t: float = minf(arc_t, 1.0)
        var p := from.lerp(dest, t)
        # высота дуги — смещаем спрайт вверх и уменьшаем тень
        var h := sin(t * PI) * arc_h
        global_position = p
        if sprite:
                sprite.position = Vector2(0, -h * 0.55)
                sprite.scale = Vector2(2.2, 2.2) * (1.0 - h / (arc_h * 3.0))
        if arc_t >= 1.0:
                _boom(dest)

func _boom(at: Vector2) -> void:
        if dead:
                return
        dead = true
        battle.explosion_at(at, dmg, splash, ap, src)
        queue_free()

func _die() -> void:
        dead = true
        queue_free()
