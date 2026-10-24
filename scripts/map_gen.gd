# ============================================================
# ГЕНЕРАТОР ПОЛЯ БОЯ v3 (архитектура префабов)
# Код рисует ТОЛЬКО ЗЕМЛЮ: тайлы, дороги, река, мосты, поля, лес-грунт,
# город-грунт, бетонные площадки и наземные декали (воронки).
# ОБЪЕКТОВ В КОДЕ БОЛЬШЕ НЕТ: деревья, кусты, камни, дома, окопы,
# заборы, мешки, машины — это сцены-префабы в scenes/props/,
# геймдизайнер расставляет их руками в редакторе Godot.
# Инструкция: README_PREFABY.txt
# ============================================================
extends Object

const TS := 128
const W := 64
const H := 44

static func generate(battle, seed_val: int, sector_type: String) -> Dictionary:
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_val
        # ---------- база ----------
        battle.tiles = []
        battle.tvar = []
        for y in range(H):
                var row := []
                var vrow := []
                for x in range(W):
                        var t: int = battle.T_GRASS
                        var r := rng.randf()
                        if r < 0.28:
                                t = battle.T_GRASS2
                        elif r < 0.36:
                                t = battle.T_DRY
                        row.append(t)
                        vrow.append("")
                battle.tiles.append(row)
                battle.tvar.append(vrow)
        # пятна грязи
        for i in range(30):
                _blob(battle, rng, rng.randi_range(2, 6), rng.randi_range(1, W - 2), rng.randi_range(1, H - 2),
                        [battle.T_MUD, battle.T_DIRT][rng.randi() % 2])
        # поля
        for i in range(7):
                var fx := rng.randi_range(2, W - 14)
                var fy := rng.randi_range(2, H - 8)
                for y in range(fy, fy + rng.randi_range(4, 7)):
                        for x in range(fx, fx + rng.randi_range(8, 13)):
                                if _in(x, y):
                                        battle.tiles[y][x] = battle.T_FIELD if rng.randf() < 0.5 else battle.T_FIELD2
        # ---------- река ----------
        var river_x := 39
        for y in range(H):
                for x in range(river_x, river_x + 3):
                        battle.tiles[y][x] = battle.T_WATER
                battle.tiles[y][river_x - 1] = battle.T_MUD
                battle.tiles[y][river_x + 3] = battle.T_MUD
        # ---------- ШИРОКИЕ ДОРОГИ (2 тайла) ----------
        # горизонтальные: ряды 12-13 и 30-31; вертикальные: колонки 20-21 и 46-47
        var hroads := [12, 30]
        var vroads := [20, 46]
        for ry in hroads:
                for x in range(W):
                        battle.tiles[ry][x] = battle.T_ROAD
                        battle.tiles[ry + 1][x] = battle.T_ROAD
        for vx in vroads:
                for y in range(H):
                        battle.tiles[y][vx] = battle.T_ROAD
                        battle.tiles[y][vx + 1] = battle.T_ROAD
        # варианты половин
        for ry in hroads:
                for x in range(W):
                        battle.tvar[ry][x] = "hn"
                        battle.tvar[ry + 1][x] = "hs"
        for vx in vroads:
                for y in range(H):
                        battle.tvar[y][vx] = "vw"
                        battle.tvar[y][vx + 1] = "ve"
        # перекрёстки: квадранты 2x2
        for ry in hroads:
                for vx in vroads:
                        battle.tvar[ry][vx] = "x_nw"
                        battle.tvar[ry][vx + 1] = "x_ne"
                        battle.tvar[ry + 1][vx] = "x_sw"
                        battle.tvar[ry + 1][vx + 1] = "x_se"
        # ---------- грунтовки к центру и ФОБ ----------
        for x in range(21, 39):
                battle.tiles[22][x] = battle.T_DROAD
        for x in range(43, 46):
                battle.tiles[22][x] = battle.T_DROAD
        for y in range(23, 41):
                battle.tiles[y][30] = battle.T_DROAD
        for y in range(4, 12):
                battle.tiles[y][30] = battle.T_DROAD
        for x in range(31, 39):
                battle.tiles[7][x] = battle.T_DROAD
        # ---------- МОСТЫ (широкие, по главной дороге) ----------
        for by in hroads:
                for y in range(by, by + 2):
                        for x in range(river_x, river_x + 3):
                                battle.tiles[y][x] = battle.T_BRIDGE
                                battle.tvar[y][x] = "bhn" if y == by else "bhs"
        # ---------- города ----------
        _urban_patch(battle, 10, 14, 17, 19, rng)   # B (южнее дороги)
        _urban_patch(battle, 45, 27, 52, 33, rng)   # D
        _urban_patch(battle, 27, 20, 33, 24, rng)   # ферма у центра
        if sector_type == "town" or sector_type == "final":
                _urban_patch(battle, 24, 6, 36, 10, rng)
                _urban_patch(battle, 6, 24, 14, 29, rng)
        # бетонные площадки
        _patch(battle, 28, 40, 33, 42, battle.T_CONCRETE)  # ФОБ игрока
        _patch(battle, 28, 2, 33, 4, battle.T_CONCRETE)    # штаб врага
        _patch(battle, 38, 10, 44, 15, battle.T_CONCRETE)  # плацдарм у моста A
        if sector_type == "airbase":
                _patch(battle, 46, 18, 58, 20, battle.T_CONCRETE)
        if sector_type == "industrial":
                _patch(battle, 47, 34, 56, 38, battle.T_CONCRETE)
        # руины у городов
        for i in range(14):
                var x := rng.randi_range(9, 53)
                var y := rng.randi_range(12, 33)
                if battle.tiles[y][x] in [battle.T_URBAN, battle.T_GRASS, battle.T_GRASS2]:
                        battle.tiles[y][x] = battle.T_RUBBLE
        # ---------- леса ----------
        var forests := 14
        if sector_type == "forest":
                forests = 24
        for i in range(forests):
                _blob(battle, rng, rng.randi_range(3, 6), rng.randi_range(1, W - 2), rng.randi_range(1, H - 2), battle.T_FOREST)
        # лесополосы вдоль реки
        for y in range(2, H - 2):
                for dx in [-3, -2, 5, 6]:
                        var x2: int = river_x + dx
                        if _in(x2, y) and rng.randf() < 0.35 and battle.tiles[y][x2] in [battle.T_GRASS, battle.T_GRASS2, battle.T_DRY]:
                                battle.tiles[y][x2] = battle.T_FOREST
        # ОКОПЫ УБРАНЫ ИЗ КОДА: теперь это префаб Trench.tscn (scenes/props/),
        # геймдизайнер расставляет их на сцене вручную.
        # ---------- очистка обочин от леса ----------
        for y in range(H):
                for x in range(W):
                        var t2: int = battle.tiles[y][x]
                        if t2 == battle.T_FOREST and _near_road(battle, x, y) and rng.randf() < 0.85:
                                battle.tiles[y][x] = battle.T_GRASS2
        # ---------- отрисовка ----------
        _draw_tiles(battle)
        _scatter_decor(battle, rng)
        _battle_decals(battle, rng)  # только наземные декали (воронки); ОБЪЕКТЫ теперь — префабы
        # ---------- точки захвата ----------
        var pts := [
                {"id": "A", "name": "МОСТ «СЕВЕРНЫЙ»", "pos": Vector2(40.5 * TS, 13.0 * TS), "owner": 0},
                {"id": "B", "name": "ЗАПАДНЫЙ ПГОСТ", "pos": Vector2(13.5 * TS, 16.0 * TS), "owner": 0},
                {"id": "C", "name": "ВОСТОЧНЫЕ ПОЛЯ", "pos": Vector2(52.0 * TS, 20.5 * TS), "owner": 0},
                {"id": "D", "name": "ВОСТОЧНЫЙ КЛАСТЕР", "pos": Vector2(48.5 * TS, 30.5 * TS), "owner": 0},
                {"id": "E", "name": "ЗАПАДНАЯ РАЗВИЛКА", "pos": Vector2(20.5 * TS, 30.5 * TS), "owner": 0},
                {"id": "F", "name": "СТАРАЯ ФЕРМА", "pos": Vector2(30.5 * TS, 22.0 * TS), "owner": 0},
        ]
        for p in pts:
                p["prog"] = 0.0
                p["capper"] = 0
        var result := {
                "points": pts,
                "fob_player": Vector2(30.5 * TS, 41.0 * TS),
                "fob_enemy": Vector2(30.5 * TS, 3.0 * TS),
        }
        return result

# ================= ОТРИСОВКА ТАЙЛОВ =================
static func _draw_tiles(battle) -> void:
        var layer: Node2D = battle.tile_layer
        for y in range(H):
                for x in range(W):
                        var s := Sprite2D.new()
                        var tex = battle.tile_tex_for(x, y)
                        if tex:
                                s.texture = tex
                        s.position = Vector2(x * TS + TS / 2.0, y * TS + TS / 2.0)
                        s.z_index = 0
                        layer.add_child(s)
        # макрорельеф: большие мягкие пятна света/тени поверх всей карты
        var macro_tex = G.tex("overlay_macro")
        if macro_tex != null:
                var mo := Sprite2D.new()
                mo.texture = macro_tex
                mo.centered = false
                mo.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
                mo.region_enabled = true
                mo.region_rect = Rect2(0, 0, W * TS / 256.0, H * TS / 256.0)
                mo.scale = Vector2(256, 256)
                mo.z_index = 1
                mo.modulate = Color(1, 1, 1, 0.85)
                layer.add_child(mo)

# ================= РОССЫПЬ МЕЛКОГО ДЕКОРА =================
static func _scatter_decor(battle, rng: RandomNumberGenerator) -> void:
        var layer: Node2D = battle.prop_layer
        var n := 1500
        for i in range(n):
                var x := rng.randi_range(0, W - 1)
                var y := rng.randi_range(0, H - 1)
                var t: int = battle.tiles[y][x]
                var nm := ""
                var zz := 1
                if t in [battle.T_GRASS, battle.T_GRASS2]:
                        var r: float = rng.randf()
                        if r < 0.62:
                                nm = "deco_grass" + str(rng.randi() % 3)
                        elif r < 0.82:
                                nm = "deco_flower" + str(rng.randi() % 3)
                        else:
                                nm = "deco_pebbles"
                elif t in [battle.T_DRY, battle.T_DIRT, battle.T_DROAD]:
                        if rng.randf() < 0.5:
                                nm = "deco_pebbles"
                        else:
                                nm = "deco_grass" + str(rng.randi() % 3)
                elif t in [battle.T_FOREST]:
                        nm = "deco_grass" + str(rng.randi() % 3)
                elif t in [battle.T_FIELD, battle.T_FIELD2]:
                        if rng.randf() < 0.4:
                                nm = "deco_grass" + str(rng.randi() % 3)
                elif t in [battle.T_URBAN, battle.T_RUBBLE, battle.T_CONCRETE]:
                        if rng.randf() < 0.5:
                                nm = "deco_pebbles"
                        zz = 1
                if nm == "":
                        continue
                var s := Sprite2D.new()
                var tex = G.tex(nm)
                if tex == null:
                        continue
                s.texture = tex
                s.position = Vector2(x * TS + rng.randf() * TS, y * TS + rng.randf() * TS)
                s.rotation = rng.randf() * TAU
                var sc := rng.randf_range(0.8, 1.5)
                s.scale = Vector2(sc, sc)
                s.z_index = zz
                layer.add_child(s)

# ================= ВОРОНКИ (только наземные декали) =================
# Всё остальное (деревья, кусты, дома, окопы, заборы, машины) убрано
# из кода: теперь это сцены-префабы scenes/props/*.tscn, которые
# расставляются вручную в редакторе Godot (см. README_PREFABY.txt).
static func _battle_decals(battle, rng: RandomNumberGenerator) -> void:
        for i in range(28):
                var x4 := rng.randi_range(4, W - 5)
                var y4 := rng.randi_range(4, H - 5)
                if battle.tiles[y4][x4] != battle.T_WATER:
                        battle.fx.add_decal("decal_crater", Vector2(x4 * TS + rng.randf() * TS, y4 * TS + rng.randf() * TS), rng.randf() * TAU, rng.randf_range(0.8, 1.4))
# ---------- вспомогательные ----------
static func _in(x: int, y: int) -> bool:
        return x >= 0 and x < W and y >= 0 and y < H

static func _patch(battle, x0: int, y0: int, x1: int, y1: int, t: int) -> void:
        for y in range(maxi(0, y0), mini(H, y1 + 1)):
                for x in range(maxi(0, x0), mini(W, x1 + 1)):
                        battle.tiles[y][x] = t

static func _blob(battle, rng: RandomNumberGenerator, r: int, cx: int, cy: int, t: int) -> void:
        for y in range(cy - r, cy + r + 1):
                for x in range(cx - r, cx + r + 1):
                        if _in(x, y):
                                var d := Vector2(x - cx, y - cy).length()
                                if d <= r * rng.randf_range(0.6, 1.0):
                                        var cur: int = battle.tiles[y][x]
                                        if cur in [battle.T_WATER, battle.T_BRIDGE, battle.T_ROAD, battle.T_DROAD,
                                                        battle.T_URBAN, battle.T_TRENCH, battle.T_CONCRETE]:
                                                continue
                                        battle.tiles[y][x] = t

static func _urban_patch(battle, x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator) -> void:
        for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                        if _in(x, y) and battle.tiles[y][x] in [battle.T_GRASS, battle.T_GRASS2, battle.T_DRY,
                                        battle.T_DIRT, battle.T_FIELD, battle.T_FIELD2, battle.T_FOREST, battle.T_MUD, battle.T_RUBBLE]:
                                battle.tiles[y][x] = battle.T_URBAN if rng.randf() < 0.85 else battle.T_RUBBLE

static func _near_road(battle, x: int, y: int) -> bool:
        for dy in range(-2, 3):
                for dx in range(-2, 3):
                        var nx := x + dx
                        var ny := y + dy
                        if _in(nx, ny) and battle.tiles[ny][nx] in [battle.T_ROAD, battle.T_URBAN]:
                                return true
        return false

