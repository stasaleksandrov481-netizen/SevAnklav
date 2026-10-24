# ============================================================
# ДИНАМИЧЕСКАЯ ТЕРРИТОРИЯ (WorldBox-стиль)
# Влияние фракций на сетке карты: где стоят наши бойцы — там наша земля.
# Территория расширяется с продвижением пехоты и сжимается при отходе/гибели.
# Отрисовка: цветное поле владения + светящаяся ЛИНИЯ ФРОНТА.
# Считается на сетке 64px (128x88 ячеек), текстура 2x для гладкости.
# ============================================================
extends Node2D

var battle = null

const TEAM_P := 1            # == G.TEAM_PLAYER
const TEAM_E := 2            # == G.TEAM_ENEMY
const TCELL := 64
var tw := 128
var th := 88

var inf_p: PackedFloat32Array = PackedFloat32Array()
var inf_e: PackedFloat32Array = PackedFloat32Array()

var img: Image = null
var tex: ImageTexture = null
var spr: Sprite2D = null

var share_p := 0.0
var share_e := 0.0

var _acc := 0.0
const TICK := 0.33
const DECAY := 0.945          # затухание влияния за тик (фронт движется живо)
const FILL_A := 0.30          # плотность заливки владения

func setup(btl) -> void:
        battle = btl
        tw = int(ceil(battle.map_size.x / TCELL))
        th = int(ceil(battle.map_size.y / TCELL))
        inf_p.resize(tw * th)
        inf_e.resize(tw * th)
        inf_p.fill(0.0)
        inf_e.fill(0.0)
        img = Image.create_empty(tw * 2, th * 2, false, Image.FORMAT_RGBA8)
        tex = ImageTexture.create_from_image(img)
        spr = Sprite2D.new()
        spr.texture = tex
        spr.centered = false
        spr.position = Vector2.ZERO
        spr.scale = Vector2(battle.map_size.x / float(tw * 2), battle.map_size.y / float(th * 2))
        spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        spr.z_index = 1
        spr.z_as_relative = false
        add_child(spr)
        z_index = 2
        z_as_relative = false

func cell_of(pos: Vector2) -> Vector2i:
        return Vector2i(int(clampf(pos.x, 0.0, battle.map_size.x - 1) / TCELL),
                        int(clampf(pos.y, 0.0, battle.map_size.y - 1) / TCELL))

# радиус зоны влияния юнита (пехота — главная сила захвата, WorldBox-логика)
func _unit_radius(u) -> float:
        if u.def.get("hero", false):
                return 240.0
        match u.def["kind"]:
                "inf":
                        return 205.0
                "veh":
                        return 255.0
                "heli":
                        return 270.0
                _:
                        return 0.0

func _process(delta: float) -> void:
        if battle == null or battle.battle_over != "":
                return
        if battle.paused or battle.cutscene:
                return
        _acc += delta
        if _acc < TICK:
                return
        var k: float = _acc
        _acc = 0.0
        # --- затухание старого влияния ---
        var df := pow(DECAY, k / TICK)
        for i in range(inf_p.size()):
                inf_p[i] *= df
                inf_e[i] *= df
        # --- влияние юнитов ---
        for u in battle.units:
                if not is_instance_valid(u) or not u.alive:
                        continue
                if u.mounted_in != null:
                        continue   # пехота в технике — землю «красит» машина
                var r := _unit_radius(u)
                if r <= 0.0:
                        continue
                _paint(cell_of(u.global_position), r, u.team, 0.55)
        # --- опорные точки держат зону вокруг себя ---
        for p in battle.points:
                var own: int = p["owner"]
                if own != TEAM_P and own != TEAM_E:
                        continue
                _paint(p["pos"], 300.0, own, 0.42)
        _rebuild_texture()

# добавка влияния команде в круге (письмо напрямую в массивы — без алиасинга)
func _paint(center: Vector2, r: float, team: int, wgt: float) -> void:
        var c := cell_of(center)
        var cr := int(ceil(r / TCELL))
        for dy in range(-cr, cr + 1):
                var yy := c.y + dy
                if yy < 0 or yy >= th:
                        continue
                for dx in range(-cr, cr + 1):
                        var xx := c.x + dx
                        if xx < 0 or xx >= tw:
                                continue
                        var d := Vector2((xx - c.x) * TCELL, (yy - c.y) * TCELL).length()
                        if d > r:
                                continue
                        var w: float = (1.0 - d / r) * wgt
                        var idx := yy * tw + xx
                        if team == TEAM_P:
                                inf_p[idx] = minf(1.0, inf_p[idx] + w)
                        else:
                                inf_e[idx] = minf(1.0, inf_e[idx] + w)

func _rebuild_texture() -> void:
        var cp: Color = battle.FAC_COL_P
        var ce: Color = battle.FAC_COL_E
        var cnt_p := 0
        var cnt_e := 0
        var total := 0
        for y in range(th):
                for x in range(tw):
                        var i := y * tw + x
                        var p := inf_p[i]
                        var e := inf_e[i]
                        var strength: float = maxf(p, e)
                        var col := Color(0, 0, 0, 0)
                        if strength > 0.05:
                                total += 1
                                if p > e + 0.04:
                                        cnt_p += 1
                                        col = Color(cp.r, cp.g, cp.b, minf(1.0, p) * FILL_A)
                                elif e > p + 0.04:
                                        cnt_e += 1
                                        col = Color(ce.r, ce.g, ce.b, minf(1.0, e) * FILL_A)
                                else:
                                        # ЛИНИЯ ФРОНТА: владения схлестнулись
                                        col = Color(1.0, 0.92, 0.6, 0.14 + strength * 0.5)
                        # блок 2x2 для гладкости
                        for by in range(2):
                                for bx in range(2):
                                        img.set_pixel(x * 2 + bx, y * 2 + by, col)
        tex.update(img)
        share_p = float(cnt_p) / float(maxi(1, total))
        share_e = float(cnt_e) / float(maxi(1, total))

# бонус скорости на своей земле / штраф на вражеской
func speed_for(pos: Vector2, team: int) -> float:
        var c := cell_of(pos)
        var i := c.y * tw + c.x
        var own := inf_p[i] if team == TEAM_P else inf_e[i]
        var foe := inf_e[i] if team == TEAM_P else inf_p[i]
        if own >= 0.22 and own > foe:
                return 1.07
        if foe >= 0.22 and foe > own:
                return 0.94
        return 1.0
