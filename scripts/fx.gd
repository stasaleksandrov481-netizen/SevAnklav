# ============================================================
# МЕНЕДЖЕР ВИЗУАЛЬНЫХ ЭФФЕКТОВ v2
# Многослойные взрывы (вспышка+огненный шар+кольцо+искры+дым),
# пожары, дымовые шлейфы, воронки, кровь, гильзы, остовы техники.
# ============================================================
extends Node2D

var battle = null

var anims: Array = []
var decals: Array = []
var smoke_cols: Array = []

const EXP_FRAMES := 8
const PUFF_FRAMES := 5
const FIRE_FRAMES := 4
const MAX_DECALS := 420

func setup(btl) -> void:
        battle = btl
        z_index = 12

func _tex(name: String) -> Texture2D:
        return G.tex(name)

func _mk_sprite(tex_name: String, pos: Vector2, z := 0) -> Sprite2D:
        var s := Sprite2D.new()
        s.texture = _tex(tex_name)
        s.position = pos
        s.z_index = z
        add_child(s)
        return s

func _additive(s: Sprite2D) -> void:
        var m := CanvasItemMaterial.new()
        m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        s.material = m

# ================= ВЗРЫВЫ (многослойные) =================
func explosion(pos: Vector2, size: int) -> void:
        # size: 0 малый, 1 средний, 2 большой, 3 огромный (авиабомба)
        var scl: float = [0.62, 1.0, 1.55, 2.25][clampi(size, 0, 3)]
        # 1) аддитивная вспышка
        var fl := _mk_sprite("fx_flash", pos, 14)
        _additive(fl)
        fl.scale = Vector2(scl, scl) * (0.7 + 0.25 * size)
        fl.rotation = randf() * TAU
        anims.append({"node": fl, "frames": [_tex("fx_flash")], "fps": 1.0, "t": 0.0,
                "loop": false, "dur": 0.14, "fade": true})
        # 2) огненный шар (8 кадров)
        var spr := _mk_sprite("fx_expl2_0", pos, 14)
        spr.scale = Vector2(scl, scl)
        spr.rotation = randf() * TAU
        var frames := []
        for i in range(EXP_FRAMES):
                frames.append(_tex("fx_expl2_" + str(i)))
        anims.append({"node": spr, "frames": frames, "fps": 15.0, "t": 0.0, "loop": false,
                "dur": EXP_FRAMES / 15.0})
        # 3) ударное кольцо
        if size >= 1:
                var rg := _mk_sprite("fx_ring", pos, 13)
                rg.scale = Vector2(0.3, 0.3)
                rg.modulate.a = 0.85
                anims.append({"node": rg, "frames": [_tex("fx_ring")], "fps": 1.0, "t": 0.0,
                        "loop": false, "dur": 0.4, "grow": 2.6 * scl, "fade": true})
        # 4) искры во все стороны
        var sparks: int = [4, 8, 13, 18][clampi(size, 0, 3)]
        for i in range(sparks):
                var sp := _mk_sprite("fx_spark", pos, 15)
                _additive(sp)
                var a := randf() * TAU
                var dist: float = randf_range(40, 130) * scl
                anims.append({"node": sp, "frames": [_tex("fx_spark")], "fps": 1.0, "t": 0.0,
                        "loop": false, "dur": randf_range(0.25, 0.55),
                        "move": Vector2.from_angle(a) * dist, "fade": true})
        # 5) подпалина + воронка
        if size >= 1:
                add_decal("decal_scorch", pos, randf() * TAU, scl)
        if size >= 2:
                add_decal("decal_crater", pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), randf() * TAU, scl * 0.95)
        # 6) дым
        for i in range(size + 2):
                puff(pos + Vector2(randf_range(-18, 18), randf_range(-18, 18)), 1, scl)
        match size:
                0: G.play_sfx("expl_s", -6.0)
                1: G.play_sfx("expl_m", -3.0)
                2: G.play_sfx("expl_l", 0.0)
                3:
                        G.play_sfx("expl_l", 2.0, 0.8)
                        G.play_sfx("cannon_far", -2.0)

func muzzle(pos: Vector2, ang: float, size: float) -> void:
        var tex_name := "fx_mz_s"
        if size >= 40:
                tex_name = "fx_mz_l"
        elif size >= 30:
                tex_name = "fx_mz_m"
        var spr := _mk_sprite(tex_name, pos, 13)
        _additive(spr)
        spr.rotation = ang
        spr.scale = Vector2(1.0, 1.0)
        anims.append({"node": spr, "frames": [_tex(tex_name)], "fps": 1.0, "t": 0.0,
                "loop": false, "dur": 0.09, "fade": true})

func puff(pos: Vector2, n := 1, scl := 1.0) -> void:
        for i in range(n):
                var spr := _mk_sprite("fx_puff2_0", pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 11)
                spr.scale = Vector2(randf_range(0.75, 1.3), randf_range(0.75, 1.3)) * scl
                spr.modulate.a = randf_range(0.45, 0.8)
                var frames := []
                for f in range(PUFF_FRAMES):
                        frames.append(_tex("fx_puff2_" + str(f)))
                anims.append({"node": spr, "frames": frames, "fps": 8.0, "t": 0.0, "loop": false, "dur": 0.8})

func fire(pos: Vector2, dur := 8.0, scl := 1.0) -> void:
        var spr := _mk_sprite("fx_fire2_0", pos, 9)
        spr.scale = Vector2(scl, scl)
        var frames := []
        for f in range(FIRE_FRAMES):
                frames.append(_tex("fx_fire2_" + str(f)))
        anims.append({"node": spr, "frames": frames, "fps": 9.0, "t": 0.0, "loop": true, "dur": dur})

func blood(pos: Vector2) -> void:
        # 6 органичных вариантов пятен (см. gen: decal_blood0..5)
        var spr := _mk_sprite("decal_blood" + str(randi() % 6), pos, 8)
        spr.rotation = randf() * TAU
        spr.scale = Vector2(0.8 + randf() * 0.5, 0.8 + randf() * 0.5)
        decals.append(spr)
        if decals.size() > MAX_DECALS:
                var old: Sprite2D = decals.pop_front()
                if is_instance_valid(old):
                        old.queue_free()

func smoke_column(pos: Vector2, dur := 14.0) -> void:
        battle.smoke_sources.append({"pos": pos, "t": 0.0, "dur": dur, "acc": 0.0})

func wreck(pos: Vector2, hull_tex_name: String, rot: float) -> void:
        var s := Sprite2D.new()
        var t = _tex(hull_tex_name)
        if t:
                s.texture = t
                s.scale = Vector2(1.24, 1.24)
        s.position = pos
        s.rotation = rot
        s.modulate = Color(0.22, 0.2, 0.18, 0.96)
        s.z_index = -7
        add_child(s)
        battle.decay_nodes.append({"node": s, "t": 45.0})
        fire(pos + Vector2(0, -6), 9.0, 1.15)
        smoke_column(pos, 16.0)
        add_decal("decal_scorch", pos, rot, 1.3)

func add_decal(tex_name: String, pos: Vector2, rot: float, scl := 1.0) -> void:
        var s := Sprite2D.new()
        var t = _tex(tex_name)
        if t == null:
                return
        s.texture = t
        s.position = pos
        s.rotation = rot
        s.scale = Vector2(scl, scl)
        s.z_index = -11
        add_child(s)
        decals.append(s)
        if decals.size() > MAX_DECALS:
                var old: Sprite2D = decals.pop_front()
                if is_instance_valid(old):
                        old.queue_free()

func sound_marker(pos: Vector2) -> void:
        var spr := _mk_sprite("fx_sound_marker", pos, 15)
        spr.modulate = Color(1, 0.4, 0.3, 0.95)
        anims.append({"node": spr, "frames": [_tex("fx_sound_marker")], "fps": 1.0, "t": 0.0,
                "loop": false, "dur": 1.4, "pulse": true})

func smoke_screen(pos: Vector2) -> void:
        var spr := _mk_sprite("fx_smokecloud", pos, 16)
        spr.modulate.a = 0.0
        var tw := create_tween()
        tw.tween_property(spr, "modulate:a", 0.92, 1.2)
        smoke_cols.append({"pos": pos, "r": 130.0, "t": 20.0})
        battle.decay_nodes.append({"node": spr, "t": 21.0})

func tick(delta: float) -> void:
        for i in range(anims.size() - 1, -1, -1):
                var a: Dictionary = anims[i]
                var node = a["node"]
                if not is_instance_valid(node):
                        anims.remove_at(i)
                        continue
                a["t"] += delta
                var t: float = a["t"]
                # движение (искры)
                if a.has("move"):
                        node.position += (a["move"] as Vector2) * delta
                # рост (кольцо)
                if a.has("grow"):
                        var k: float = clampf(t / float(a["dur"]), 0.0, 1.0)
                        var gs: float = 0.3 + k * float(a["grow"])
                        node.scale = Vector2(gs, gs)
                # растворение
                if a.get("fade", false) and t > float(a["dur"]) * 0.4:
                        node.modulate.a = maxf(0.0, 1.0 - (t - float(a["dur"]) * 0.4) / (float(a["dur"]) * 0.6))
                if a.get("pulse", false):
                        node.modulate.a = 1.0 - t / float(a["dur"])
                        node.scale = Vector2.ONE * (1.0 + t * 0.6)
                if a.has("frames") and (a["frames"] as Array).size() > 1:
                        var fi := int(t * float(a["fps"]))
                        if a["loop"]:
                                fi = fi % (a["frames"] as Array).size()
                        else:
                                fi = mini(fi, (a["frames"] as Array).size() - 1)
                        node.texture = (a["frames"] as Array)[fi]
                if t >= float(a["dur"]):
                        anims.remove_at(i)
                        if is_instance_valid(node):
                                node.queue_free()
