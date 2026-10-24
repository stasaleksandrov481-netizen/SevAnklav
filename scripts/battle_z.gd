# ============================================================
# КАМПАНИЯ «ЗЕМЛЯ МЕРТВЫХ» — БОЕВОЙ РЕЖИМ (зомби-апокалипсис)
# Сектор 1: подземный бункер лаборатории «Заря» (рукописная карта:
# полумрак, мигающий красный аварийный свет, пар, искры, белый кафель).
# Сектора 2-20: зимняя поверхность (снег, метель, руины, толпы).
# Игрок — выживший командир: twin-stick (левый стик — ход, правый —
# прицел/огонь), анатомическая медицина (6 зон, кровотечения, переломы,
# заражение), инвентарь с перетаскиванием, обыск тел, хабар.
# Военная кампания не тронута: battle.gd / campaign_map.gd живут рядом.
# ============================================================
extends Node2D

const Med = preload("res://scripts/med.gd")
const ZMed = preload("res://scripts/zmed_ui.gd")
const ZTut = preload("res://scripts/z_tutorial.gd")

const TS := 96                 # клетка бункера
const TS_S := 128              # клетка поверхности
const MAPW := 30               # бункер: 30x22 клеток
const MAPH := 22
const MAPW_S := 48             # поверхность: 48x34
const MAPH_S := 34

# ---------- типы зомби ----------
const ZDEF := {
                                                                "sci": {"tex": "z_zombie_sci", "hp": 58.0, "spd": 30.0, "dmg": 9.0, "radius": 13.0, "notice": 240.0, "loot": [["watch", 0.4], ["docs", 0.35], ["band", 0.3]]},
                                                                "walk": {"tex": "z_zombie_walk", "hp": 78.0, "spd": 34.0, "dmg": 11.0, "radius": 13.0, "notice": 260.0, "loot": [["watch", 0.3], ["chip", 0.22], ["ammo", 0.25], ["food", 0.18]]},
                                                                "run": {"tex": "z_zombie_run", "hp": 52.0, "spd": 92.0, "dmg": 8.0, "radius": 12.0, "notice": 420.0, "loot": [["chip", 0.3], ["meds", 0.3]]},
                                                                "cop": {"tex": "z_zombie_cop", "hp": 108.0, "spd": 38.0, "dmg": 14.0, "radius": 13.0, "notice": 300.0, "loot": [["ammo", 0.45], ["meds", 0.25], ["docs", 0.2]]},
                                                                "brute": {"tex": "z_zombie_brute", "hp": 260.0, "spd": 30.0, "dmg": 24.0, "radius": 19.0, "notice": 320.0, "loot": [["chip", 0.6], ["meds", 0.5]]},
                                                                "alpha": {"tex": "z_zombie_brute", "hp": 950.0, "spd": 42.0, "dmg": 34.0, "radius": 24.0, "notice": 999.0, "loot": [["chip", 1.0], ["meds", 1.0]]},
}

const CALLSIGN_POOL := ["Волк", "Аякс", "Скиф", "Бекас", "Марс", "Клык", "Тайга", "Гроза", "Норд", "Вьюн"]

# ---------- слои ----------
var floor_node: Node2D = null
var decal_node: Node2D = null
var prop_layer: Node2D = null
var unit_layer: Node2D = null
var fx_layer: Node2D = null
var ui_layer: CanvasLayer = null
var camera: Camera2D = null
var canvas_mod: CanvasModulate = null

# ---------- конфиг ----------
var main_ref = null
var sector_idx := 0            # индекс узла ZSECTORS
var mission := "clear"         # bunker/clear/warehouse/tablets/defense/rescue/final
var sector_name := ""
var diff_mult := 1.0
var paused := false
var battle_over := ""
var end_timer := 0.0
var time_alive := 0.0
var is_bunker := true

# ---------- геометрия ----------
var walls: Array = []          # Rect2 (мировые координаты)
var floor_zones: Array = []    # {rect, kind}  kind: tile/conc/metal/snow/road
var decals: Array = []         # {pos, idx, rot, scale}
var props: Array = []          # {spr, pos, radius, kind, solid}
var map_size := Vector2(2880, 2112)
var lamp_lights: Array = []    # PointLight2D аварийных ламп (мигают)
var light_pools: Array = []    # пятна света, запечённые в пол {pos, r, col, a}
var wall_lamp_pos: Array = []  # позиции настенных светильников (для табличок)
var lab_lights: Array = []     # фальш-свет LED-светильников (аддитивные спрайты — дёшево для GPU)
var halos: Array = []          # мягкие пятна на полу под светильниками
var wall_occluders: Dictionary = {}   # Rect2 стены → LightOccluder2D (снимаются при открытии двери)
var doors: Dictionary = {}     # id → {pr, wall: Rect2, vertical, opened}
var door_zones: Array = []   # FIX7v2: Rect2 проёмов дверей — мебель их не перекрывает
var spark_points: Array = []   # позиции искрящих проводов
var spark_t := 0.0
var extraction := Vector2.ZERO # точка эвакуации (после выполнения задачи)
var extraction_open := false
var extract_t := 0.0

# ---------- сущности ----------
var player := {}               # {spr, st, infect, weapon, mag, reload_t, fire_cd, aim, facing, alive, light, flash, bscale}
var zombies: Array = []        # словари-зомби
var _scene_spawn := Vector2.ZERO   # FIX9: точка входа игрока из сцены локации
var allies: Array = []         # наёмные бойцы
var corpses: Array = []        # {spr, kind, searched, pos}
var pickups: Array = []        # {spr, item, n, pos}
var tracer_fx: Array = []      # {a, b, t}
var flash_fx: Array = []       # вспышки выстрелов {pos, t}
var blood_burst: Array = []    # живые всплески крови {pos, t, ang}
var blood_sprays: Array[CPUParticles2D] = []
var shells: Array = []             # v2.8: летящие гильзы {pos, vel, rot, vr, t, k}
var shells_static: Array = []      # v2.8: упавшие гильзы {pos, rot, k} (макс 70)
var dying_lamps: Array = []        # v2.8: умирающие лампы {spr, wall, pool, cd, tw}
var muzzle_light: PointLight2D = null   # v2.8: импульс света от выстрела
var muzzle_tw: Tween = null

# ---------- миссии ----------
var objectives: Array = []     # {id, text, done}
var zone_target := Rect2()     # зона зачистки (warehouse)
var zone_count := 0
var zone_total := 0
var tablets_left := 0
var defense_t := 0.0
var defense_wave := 0
var rescue_npc = null          # гражданский на спасении
var rescue_follow := false
var kills := 0
var looted_bodies := 0
var interact_hold_t := 0.0
var cur_interact := {}         # текущий доступный интерактив

# ---------- территория WorldBox (влияние вокруг отряда) ----------
const TERR_CELL := 128.0
var terr := {}                 # Vector2i → float (0..1)
var terr_t := 0.0

# ---------- HUD ----------
const STICK_KNOB := 116.0
const STICK_ACT_R := 236.0
const STICK_FIRE_K := 0.66
const STICK_FIRE_OFF := 0.46
var _stick_move_idx := -1
var _stick_aim_idx := -1
var _r_was_center := false
var _r_fire_latch := false
var hud_ctrl: Control = null   # рисует стики/прицел/виньетки
var log_lines: Array = []      # {text, col, tag, t}
var toasts: Array = []         # {text, t}
var vignette_dmg := 0.0        # вспышка урона (текущее сглаженное значение 0..1)
var vignette_dmg_tgt := 0.0    # цель вспышки: сначала быстрый подъём, затем плавный спад
var heart_t := 0.0
var med_win: Control = null
var loot_win: Control = null
var loot_source: Dictionary = {}
var loot_inventory_lbl: Label = null
var loot_content_vb: VBoxContainer = null
var kpk_win: Control = null
var pause_win: Control = null
var interact_bubble: Button = null   # FIX6: SVG-кнопка НА ОБЪЕКТЕ (мире)
var obj_hidden := false              # FIX6: задачи свернуты (глаз)
# ---------- FIX7: БЕГ + выносливость ----------
var _run_mode := false            # FIX7v2: двойной тап по стику хода — режим БЕГА
var _last_move_tap := -10.0      # FIX7v2: время последнего тапа по левому стику
var stamina := 100.0                 # выносливость 0..100
var run_exhausted := false           # после нуля — до 25 не бежать
var run_noise_t := 0.0               # шум шагов будит мёртвых
var run_hint_done := false           # обучающая подсказка показана
var _reload_flash := 0.0             # FIX7: мигание индикатора перезарядки
var _last_aim_tap := -10.0           # FIX6: двойной тап правого стика — перезарядка
var _ammo_check_t := -1.0            # FIX6: проверка магазина (таймер 1.0..0)
var _ammo_result_t := 0.0            # FIX6: показ результата "± N патронов"
var _ammo_result_txt := ""
var _cull_acc := 0.0                 # FIX6: отсечение невидимого (4 Гц)
var _hand_ind: Node2D = null         # FIX6: "предмет в руках" (рука + иконка)
var _hand_ind_item: Sprite2D = null
# FIX7: панель «ПМ «Макаров» с точным счётом патронов удалена —
# патроны узнаются проверкой магазина (кнопка ПАТРОНЫ, «± N»), оружие — в КПК.
var obj_labels: Array = []
var obj_panel: PanelContainer = null
var in_capsule := false               # игрок ещё в капсуле (UI скрыт)
var _clip_cache: Dictionary = {}      # комнатный Rect2 -> ShaderMaterial
var quick_panel_ref: Control = null
var menu_btns_ref: VBoxContainer = null
var reload_chip_ref: Control = null  # FIX7: подпись перезарядки над слотами
var mm_ref: Control = null
var drag_ghost: Control = null
var _med_sel_item := ""        # выбранный медпремет (тап-тап фолбэк)
var _med_doll = null           # кукла тела в окне медицины (ZMedUI.BodyDoll)
var _med_info_lbl: Label = null
var quick_slots: Array = []
var quick_refresh_t := 0.0
var tut = null                 # ZTutorial — подсказки обучения (бункер)
var scanner_used := false      # карта приложена к считывателю?
var stairs_prop: Dictionary = {}   # лестница за шлюзом
var stairs_fade := 0.0        # затемнение при подъёме по лестнице (0 = неактивно, 2.0 = выход)
var glass_props: Array = []    # осколки стекла у капсулы
const QUICK_ITEMS := ["band", "tq", "splint", "morph", "abx", "food"]
var _touch_pts := {}
var mouse_aim_pos := Vector2.ZERO
var mouse_aim_active := false
var mouse_aim_timer := 0.0
var _heart_rate := 0.0
var voice_gasp_t := 0.0
# ---------- FIX11: тряска камеры, направление удара, анти-спам тостов ----------
var _cam_shake := 0.0              # 0..1 — сила тряски (спадает сама)
var hit_dir_ang := 0.0             # направление последнего удара по игроку
var hit_dir_t := 0.0               # время жизни индикатора направления
var _dry_msg_t := -10.0            # анти-спам подсказок «магазин пуст»
# ---------- FIX5: адаптивное качество (авто-деградация при низком ФПС) ----------
var steam_particles: Array = []   # пар из труб (отключается на низком качестве)
var fps_acc := 0.0
var fps_n := 0
var fps_avg := 60.0
var q_level := 2                  # 2 = полное, 1 = среднее, 0 = минимум
var q_up_timer := 0.0
var q_lock := false               # zshots/zfps: авто-деградация выключена
var _hud_acc := 0.0
var _frame_i := 0

func _bake_light_pool_textures() -> void:
                                                                # FIX7: свет рассеянный — пятно НЕ узкий круг у лампы, а мягкая волна
                                                                # до самых дальних углов комнаты + плоская подсветка пола (ambient).
                                                                var fill_rooms: Array = []   # уникальные комнаты для заливки
                                                                for lp in light_pools:
                                                                                                                                var pos: Vector2 = lp["pos"]
                                                                                                                                var room := _room_rect_at(pos).grow(-10.0)
                                                                                                                                if room.size.x < 12.0 or room.size.y < 12.0:
                                                                                                                                                                                                continue
                                                                                                                                var rr: float = float(lp["r"])
                                                                                                                                # радиус — до самой дальней точки комнаты (свет по всей комнате)
                                                                                                                                for c in [room.position, Vector2(room.end.x, room.position.y), Vector2(room.position.x, room.end.y), room.end]:
                                                                                                                                                                                                rr = maxf(rr, pos.distance_to(c) * 1.04)
                                                                                                                                lp["r"] = rr
                                                                                                                                var bbox := Rect2(pos - Vector2(rr, rr), Vector2(rr * 2.0, rr * 2.0)).intersection(room)
                                                                                                                                if bbox.size.x < 12.0 or bbox.size.y < 12.0:
                                                                                                                                                                                                lp["tex"] = null
                                                                                                                                                                                                continue
                                                                                                                                var step := 4.0
                                                                                                                                var w := int(bbox.size.x / step)
                                                                                                                                var h := int(bbox.size.y / step)
                                                                                                                                var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
                                                                                                                                var col: Color = lp["col"]
                                                                                                                                var a0: float = float(lp["a"])
                                                                                                                                for py in range(h):
                                                                                                                                                                                                var wy := bbox.position.y + (float(py) + 0.5) * step
                                                                                                                                                                                                for px in range(w):
                                                                                                                                                                                                                                                                var wx := bbox.position.x + (float(px) + 0.5) * step
                                                                                                                                                                                                                                                                var d := Vector2(wx, wy).distance_to(pos) / rr
                                                                                                                                                                                                                                                                var k := clampf(1.0 - d, 0.0, 1.0)
                                                                                                                                                                                                                                                                # FIX7: пологая волна (было pow 1.7 — узкий круг) + ambient 0.30
                                                                                                                                                                                                                                                                k = maxf(pow(k, 1.45), 0.13)
                                                                                                                                                                                                                                                                img.set_pixel(px, py, Color(col.r, col.g, col.b, a0 * k * 0.85))
                                                                                                                                lp["tex"] = ImageTexture.create_from_image(img)
                                                                                                                                lp["bbox"] = bbox
                                                                                                                                # уникальная комната → добавим мягкую заливку после цикла
                                                                                                                                var key := "%d,%d" % [int(room.position.x), int(room.position.y)]
                                                                                                                                var found := false
                                                                                                                                for fr in fill_rooms:
                                                                                                                                                                                                if str(fr["key"]) == key:
                                                                                                                                                                                                                                                                found = true
                                                                                                                                                                                                                                                                break
                                                                                                                                if not found:
                                                                                                                                                                                                fill_rooms.append({"key": key, "room": room})
                                                                # FIX7: рассеянная заливка комнат — мягкий аддитивный свет по всему полу,
                                                                # чтобы углы не были чёрными (лампы на стенах больше не «точки»)
                                                                for fr in fill_rooms:
                                                                                                                                var room2: Rect2 = fr["room"]
                                                                                                                                var diag: float = room2.size.length()
                                                                                                                                var s := Sprite2D.new()
                                                                                                                                s.texture = _light_tex()
                                                                                                                                s.position = room2.get_center()
                                                                                                                                s.scale = Vector2(diag / 128.0, diag / 128.0)
                                                                                                                                s.modulate = Color(0.50, 0.60, 0.74, 0.055)
                                                                                                                                s.z_index = 11
                                                                                                                                s.material = _clip_mat_for(room2.get_center())
                                                                                                                                fx_layer.add_child(s)

func _apply_quality() -> void:
                                                                # уровень 0: пар выкл, зум ближе (меньше мира на экране), HUD реже,
                                                                # зомби вдали спят. СВЕТ НЕ ГАСИМ — иначе пол чёрный и играть нельзя.
                                                                var steam_off := q_level <= 0
                                                                for st in steam_particles:
                                                                                                                                if is_instance_valid(st):
                                                                                                                                                                                                st.emitting = not steam_off
                                                                if camera != null:
                                                                                                                                var mob := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
                                                                                                                                var z0 := 1.1 if mob else 1.0
                                                                                                                                if q_level == 1:
                                                                                                                                                                                                z0 *= 1.06
                                                                                                                                elif q_level <= 0:
                                                                                                                                                                                                z0 *= 1.14
                                                                                                                                camera.zoom = Vector2(z0, z0)

# ================= СОЗДАНИЕ =================
func setup(cfg: Dictionary) -> void:
                                                                sector_idx = int(cfg.get("sector_idx", 0))
                                                                mission = cfg.get("mission", "clear")
                                                                sector_name = cfg.get("sector_name", "СЕКТОР")
                                                                diff_mult = G.zdiff_mult()

func map_size_for() -> Vector2:
                                                                if mission == "bunker":
                                                                                                                                return Vector2(MAPW * TS, 3900)
                                                                return Vector2(MAPW_S * TS_S, MAPH_S * TS_S)

var bench := {}

func _bench_hooks() -> void:
                                                                # temporary FPS bisect: ZBENCH_DISABLE="shadow,glow,minimap"
                                                                var e := OS.get_environment("ZBENCH_DISABLE")
                                                                if e != "":
                                                                                                                                for k in e.split(","):
                                                                                                                                                                                                bench[k.strip_edges()] = true

func _ready() -> void:
                                                                _bench_hooks()
                                                                map_size = map_size_for()
                                                                is_bunker = mission == "bunker"
                                                                floor_node = Node2D.new()
                                                                floor_node.set_script(FloorDraw)
                                                                add_child(floor_node)
                                                                decal_node = Node2D.new()
                                                                decal_node.set_script(DecalDraw)
                                                                add_child(decal_node)
                                                                prop_layer = Node2D.new()
                                                                unit_layer = Node2D.new()
                                                                fx_layer = Node2D.new()
                                                                # FIX11: у слоя эффектов теперь есть скрипт — рисует трассеры,
                                                                # вспышки выстрелов и брызги крови (массивы заполнялись, но
                                                                # никогда не отрисовывались — выстрел выглядел «пустым»)
                                                                fx_layer.set_script(FxDraw)
                                                                for l in [prop_layer, unit_layer, fx_layer]:
                                                                                                                                add_child(l)
                                                                fx_layer.z_index = 20
                                                                # общий свет/цвет
                                                                canvas_mod = CanvasModulate.new()
                                                                add_child(canvas_mod)
                                                                if is_bunker:
                                                                                                                                # FIX7: общий тон чуть светлее — тёмные углы ушли, свет рассеянный
                                                                                                                                canvas_mod.color = Color(0.60, 0.645, 0.72)
                                                                else:
                                                                                                                                canvas_mod.color = Color(0.84, 0.87, 0.97)
                                                                # камера
                                                                camera = Camera2D.new()
                                                                camera.position = map_size * 0.5
                                                                # ФПС: зум 1.0 — на экран меньше мира (меньше чанков/пропов),
                                                                # персонажи крупнее; на телефонах ещё плотнее
                                                                var mob := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
                                                                var z0 := 1.1 if mob else 1.0
                                                                camera.zoom = Vector2(z0, z0)
                                                                camera.position_smoothing_enabled = true
                                                                camera.position_smoothing_speed = 9.0
                                                                add_child(camera)
                                                                camera.make_current()
                                                                # карта и сущности
                                                                if is_bunker:
                                                                                                                                _build_bunker()
                                                                else:
                                                                                                                                _build_surface()
                                                                # игрок
                                                                _spawn_player()
                                                                # отряд наёмников из сохранения (в бункере — после вскрытия капсулы)
                                                                if not is_bunker:
                                                                                                                                for s in G.zsave["squad"]:
                                                                                                                                                                                                if s.get("alive", true):
                                                                                                                                                                                                                                                                                                                                _spawn_ally(s)
                                                                camera.position = _player_start()
                                                                camera.reset_smoothing()
                                                                _build_hud()
                                                                # обучающие подсказки (только бункер — Сектор 1)
                                                                if is_bunker:
                                                                                                tut = ZTut.new()
                                                                                                add_child(tut)
                                                                                                tut.bunker_flow(self)
                                                                _bake_light_pool_textures()
                                                                floor_node.redraw_all()
                                                                var _ua := OS.get_cmdline_user_args()
                                                                q_lock = _ua.has("--zshots") or _ua.has("--zfps")
                                                                _apply_quality()
                                                                add_to_group("zbattle")

# ================= ГЕОМЕТРИЯ: СТЕНЫ/ЗОНЫ =================
func _wall(x: float, y: float, w: float, h: float) -> void:
                                                                walls.append(Rect2(x, y, w, h))

func _zone(x: float, y: float, w: float, h: float, kind: String) -> void:
                                                                floor_zones.append({"rect": Rect2(x, y, w, h), "kind": kind})

func _room(x: float, y: float, w: float, h: float, t := 22.0, doors := {}) -> void:
                                                                # комната: 4 полосы стен с проёмами doors = {side: [from, to]} (0..1 вдоль стены)
                                                                # sides: "n","s","w","e"
                                                                var door_n: Array = doors.get("n", [])
                                                                var door_s: Array = doors.get("s", [])
                                                                var door_w: Array = doors.get("w", [])
                                                                var door_e: Array = doors.get("e", [])
                                                                # северная (горизонтальная) стена
                                                                _hwall(x, y, w, t, door_n)
                                                                _hwall(x, y + h - t, w, t, door_s)
                                                                _vwall(x, y, h, t, door_w)
                                                                _vwall(x + w - t, y, h, t, door_e)

func _hwall(x: float, y: float, w: float, t: float, doors: Array) -> void:
                                                                var cuts: Array = []
                                                                for d in doors:
                                                                                                                                cuts.append([x + w * float(d[0]), x + w * float(d[1])])
                                                                cuts.sort_custom(func(a, b): return a[0] < b[0])
                                                                var cx := x
                                                                for c in cuts:
                                                                                                                                if c[0] > cx:
                                                                                                                                                                                                _wall(cx, y, c[0] - cx, t)
                                                                                                                                cx = maxf(cx, c[1])
                                                                if cx < x + w:
                                                                                                                                _wall(cx, y, x + w - cx, t)

func _vwall(x: float, y: float, h: float, t: float, doors: Array) -> void:
                                                                var cuts: Array = []
                                                                for d in doors:
                                                                                                                                cuts.append([y + h * float(d[0]), y + h * float(d[1])])
                                                                cuts.sort_custom(func(a, b): return a[0] < b[0])
                                                                var cy := y
                                                                for c in cuts:
                                                                                                                                if c[0] > cy:
                                                                                                                                                                                                _wall(x, cy, t, c[0] - cy)
                                                                                                                                cy = maxf(cy, c[1])
                                                                if cy < y + h:
                                                                                                                                _wall(x, cy, t, y + h - cy)

# ================= СПРАЙТЫ/ПРОПСЫ =================
func _mk_spr(tex: String, pos: Vector2, scl := 1.42, z := 5, mod := Color(1, 1, 1)) -> Sprite2D:
                                                                var s := Sprite2D.new()
                                                                var t = G.tex(tex)
                                                                if t != null:
                                                                                                                                s.texture = t
                                                                s.position = pos
                                                                s.scale = Vector2(scl, scl)
                                                                s.z_index = z
                                                                s.modulate = mod
                                                                unit_layer.add_child(s)
                                                                return s

# ---------- v2.9: контактные тени (ТЗ «Заря» п.1/3/7/8) ----------
# Мягкая эллиптическая тень — ребёнок спрайта: сама следует за позицией,
# видимостью и альфой родителя (гибель, исчезновение, куллинг), рисуется
# позади него (show_behind_parent) на один уровень ниже (z_index -1).
func _add_shadow(spr: Sprite2D, wf: float, hf: float, a: float, dy := 0.0) -> void:
    if bench.has("shadow") or spr.texture == null:
        return
    var t = G.tex("fx_shadow")
    if t == null:
        return
    var sh := Sprite2D.new()
    sh.texture = t
    sh.show_behind_parent = true
    sh.z_index = -1
    sh.position = Vector2(0.0, dy)
    sh.scale = Vector2(float(spr.texture.get_width()) * wf / 256.0, float(spr.texture.get_height()) * hf / 128.0)
    sh.modulate = Color(0.0, 0.0, 0.0, a)
    spr.add_child(sh)

const CLIP_SHADER := "shader_type canvas_item;\nrender_mode blend_add;\nuniform vec4 clip_rect = vec4(-99999.0, -99999.0, 199999.0, 199999.0);\nvarying vec2 wpos;\nvoid vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }\nvoid fragment() {\n\tvec2 lo = clip_rect.xy;\n\tvec2 hi = clip_rect.xy + clip_rect.zw;\n\tvec2 s = smoothstep(lo - 1.0, lo + 2.0, wpos) * (1.0 - smoothstep(hi - 2.0, hi + 1.0, wpos));\n\tCOLOR.a *= s.x * s.y;\n}"
var _clip_shader: Shader = null

func _clip_mat_for(p: Vector2) -> ShaderMaterial:
                                                                # один материал на комнату: свет обрезается по её полу (не залазит на стены)
                                                                if _clip_shader == null:
                                                                                                                                _clip_shader = Shader.new()
                                                                                                                                _clip_shader.code = CLIP_SHADER
                                                                var r := _room_rect_at(p)
                                                                # свет останавливается ДО стены: комната сжата на 10px с каждой стороны
                                                                r = r.grow(-10.0)
                                                                var key := "%d,%d,%d,%d" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
                                                                if _clip_cache.has(key):
                                                                                                                                return _clip_cache[key]
                                                                var m := ShaderMaterial.new()
                                                                m.shader = _clip_shader
                                                                m.set_shader_parameter("clip_rect", Rect2(r.position, r.size))
                                                                _clip_cache[key] = m
                                                                return m

func _room_rect_at(p: Vector2) -> Rect2:
                                                                var best := Rect2(-99999, -99999, 199999, 199999)
                                                                var bd := 1e12
                                                                for z in floor_zones:
                                                                                                                                var r: Rect2 = z["rect"]
                                                                                                                                if r.has_point(p):
                                                                                                                                                                                                return r
                                                                                                                                var d: float = (r.get_center() as Vector2).distance_squared_to(p)
                                                                                                                                if d < bd:
                                                                                                                                                                                                bd = d
                                                                                                                                                                                                best = r
                                                                return best

func _wall_point(hint: Vector2) -> Dictionary:
                                                                # ближайшая внутренняя кромка комнаты: {pos, rot} для настенного светильника
                                                                var r := _room_rect_at(hint)
                                                                var x: float = clampf(hint.x, r.position.x + 60.0, r.end.x - 60.0)
                                                                var y: float = clampf(hint.y, r.position.y + 60.0, r.end.y - 60.0)
                                                                var dn := hint.y - r.position.y
                                                                var ds := r.end.y - hint.y
                                                                var dw := hint.x - r.position.x
                                                                var de := r.end.x - hint.x
                                                                var m := minf(minf(dn, ds), minf(dw, de))
                                                                if m == dn:
                                                                                                                                return {"pos": Vector2(x, r.position.y - 9.0), "rot": 0.0, "in": Vector2(0, 1)}
                                                                if m == ds:
                                                                                                                                return {"pos": Vector2(x, r.end.y + 9.0), "rot": PI, "in": Vector2(0, -1)}
                                                                if m == dw:
                                                                                                                                return {"pos": Vector2(r.position.x - 9.0, y), "rot": -PI / 2.0, "in": Vector2(1, 0)}
                                                                return {"pos": Vector2(r.end.x + 9.0, y), "rot": PI / 2.0, "in": Vector2(-1, 0)}

func _snap_props_to_walls() -> void:
        # FIX7v2: прижимаем мебель к стенам ТОЛЬКО если она вплотную (зазор < 10px)
        # и только если её габарит НЕ задевает дверной проём (иначе кровать/стол
        # вставали поперёк гермодвери). Капсула не трогается: рядом её стекло и кровь.
        var SNAPPABLE := ["", "cabinet", "gear_table", "loot_crate"]
        for pr in props:
                if not SNAPPABLE.has(str(pr.get("kind", ""))):
                        continue
                var spr: Sprite2D = pr["spr"]
                var half: Vector2 = pr.get("half", Vector2(48, 48))
                var rot: float = spr.rotation
                var p0: Vector2 = pr["pos"]
                if absf(fposmod(rot + PI / 2.0, PI)) < 0.1 or absf(fposmod(rot - PI / 2.0, PI)) < 0.1:
                        half = Vector2(half.y, half.x)
                var aabb := Rect2(p0 - half, half * 2.0)
                var hits_door := false
                for dz in door_zones:
                        if (dz as Rect2).intersects(aabb):
                                hits_door = true
                                break
                if hits_door:
                        continue
                var r := _room_rect_at(p0)
                var p: Vector2 = p0
                var EPS := 1.0
                var TH := half.x + 10.0
                var TV := half.y + 10.0
                if p.y - half.y - r.position.y < TV:
                        p.y = r.position.y + half.y - EPS
                elif r.end.y - (p.y + half.y) < TV:
                        p.y = r.end.y - half.y + EPS
                if p.x - half.x - r.position.x < TH:
                        p.x = r.position.x + half.x - EPS
                elif r.end.x - (p.x + half.x) < TH:
                        p.x = r.end.x - half.x + EPS
                spr.position = p
                pr["pos"] = p
                pr["half"] = half

func _snap_signs_to_walls() -> void:
                                                                # таблички вешаем на стену (центр полосы стены рядом с текущей позицией);
                                                                # FIX5: сдвигаем от настенных светильников, чтобы стена не превращалась в кашу
                                                                for ch in unit_layer.get_children():
                                                                                                                                if ch is Sprite2D and ch.texture != null and ch.texture.resource_path.ends_with("z_sign.png"):
                                                                                                                                                                                                var r := _room_rect_at(ch.position)
                                                                                                                                                                                                var wp := _wall_point(ch.position)
                                                                                                                                                                                                var q: Vector2 = wp["pos"]
                                                                                                                                                                                                var rot: float = wp["rot"]
                                                                                                                                                                                                # FIX6: центр полосы стены (t=22) — табличка ПРИБИТА к стене, не поверх
                                                                                                                                                                                                if absf(rot) < 0.1:
                                                                                                                                                                                                                                                                q.y = r.position.y - 11.0
                                                                                                                                                                                                elif absf(rot - PI) < 0.1:
                                                                                                                                                                                                                                                                q.y = r.end.y + 11.0
                                                                                                                                                                                                elif rot < 0.0:
                                                                                                                                                                                                                                                                q.x = r.position.x - 11.0
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                q.x = r.end.x + 11.0
                                                                                                                                                                                                # не вешаем табличку поверх светильника: разносим минимум на 150px
                                                                                                                                                                                                for lp in wall_lamp_pos:
                                                                                                                                                                                                                                                                var dv: Vector2 = q - (lp as Vector2)
                                                                                                                                                                                                                                                                var same_wall := absf(dv.y) < 40.0 or absf(dv.x) < 40.0
                                                                                                                                                                                                                                                                if not same_wall:
                                                                                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                                                                                if absf(dv.x) < 150.0 and absf(dv.y) < 150.0:
                                                                                                                                                                                                                                                                                                                                var push := 150.0 - (absf(dv.x) if absf(dv.y) < 40.0 else absf(dv.y))
                                                                                                                                                                                                                                                                                                                                if absf(dv.y) < 40.0:
                                                                                                                                                                                                                                                                                                                                                                                                q.x += signf(dv.x if absf(dv.x) > 0.5 else 1.0) * push
                                                                                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                                                                                q.y += signf(dv.y if absf(dv.y) > 0.5 else 1.0) * push
                                                                                                                                                                                                # FIX7v2: табличка не висит на дверном проёме — сдвигаем вдоль стены
                                                                                                                                                                                                for dz in door_zones:
                                                                                                                                                                                                                                                                var dr := dz as Rect2
                                                                                                                                                                                                                                                                if not dr.has_point(q):
                                                                                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                                                                                if dr.size.x >= dr.size.y:
                                                                                                                                                                                                                                                                                                                                var left_d: float = q.x - dr.position.x
                                                                                                                                                                                                                                                                                                                                var right_d: float = dr.end.x - q.x
                                                                                                                                                                                                                                                                                                                                q.x = dr.position.x - 12.0 if left_d <= right_d else dr.end.x + 12.0
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                var up_d: float = q.y - dr.position.y
                                                                                                                                                                                                                                                                                                                                var dn_d: float = dr.end.y - q.y
                                                                                                                                                                                                                                                                                                                                q.y = dr.position.y - 12.0 if up_d <= dn_d else dr.end.y + 12.0
                                                                                                                                                                                                ch.position = q

func _prop(tex: String, pos: Vector2, radius: float, kind := "", scl := 1.42, solid := true, z := 3) -> Dictionary:
                                                                var s := Sprite2D.new()
                                                                var t = G.tex(tex)
                                                                if t != null:
                                                                                                                                s.texture = t
                                                                s.position = pos
                                                                var furniture := tex in ["z_medtable", "z_shelf", "z_cabinet", "z_gurney", "z_crate_z"]
                                                                var visual_scale := scl * (0.72 if is_bunker and furniture else 1.0)
                                                                s.scale = Vector2(visual_scale, visual_scale)
                                                                # v2.9: контактные тени под мебелью/оборудованием/стоящими телами
                                                                if tex in ["z_medtable", "z_gurney", "z_scanner", "z_terminal"]:
                                                                    _add_shadow(s, 0.92, 0.62, 0.26)
                                                                elif tex in ["z_cabinet", "z_shelf", "z_crate_z", "z_capsule", "z_reactor", "z_barrel"]:
                                                                    _add_shadow(s, 0.96, 0.68, 0.30)
                                                                elif tex.begins_with("z_player") or tex.begins_with("z_zombie") or tex.begins_with("z_ally"):
                                                                    _add_shadow(s, 0.62, 0.34, 0.20)
                                                                s.z_index = z
                                                                prop_layer.add_child(s)
                                                                var half := Vector2(56, 56)
                                                                if t != null:
                                                                                                                                half = Vector2(t.get_width(), t.get_height()) * s.scale * 0.5
                                                                var p := {"spr": s, "pos": pos, "radius": radius, "kind": kind, "solid": solid, "half": half}
                                                                props.append(p)
                                                                return p

func _decal(idx: int, pos: Vector2, scl := 1.0) -> void:
                                                                decals.append({"pos": pos, "idx": idx, "rot": randf() * TAU, "scale": scl})
                                                                while decals.size() > 64:
                                                                                                decals.pop_front()
                                                                if decal_node != null:
                                                                                                decal_node.queue_redraw()

func _blood_pool(pos: Vector2, big := true) -> void:
                                                                # 6 текстур: лужи, брызги, потёки; форма зависит от «размера» события (ТЗ п.5)
                                                                var kind: int = [0, 1, 4][randi() % 3] if big else [2, 3, 5][randi() % 3]
                                                                _decal(kind, pos, (1.15 + randf() * 0.5) if big else (0.6 + randf() * 0.45))

func _red_lamp(pos: Vector2) -> void:
                                                                # аварийная лампа НА СТЕНЕ (настенный корпус), свет обрезан по комнате
                                                                var wp := _wall_point(pos)
                                                                var s := _mk_spr("z_wallamp_red", wp["pos"], 1.25, 7)
                                                                s.rotation = wp["rot"]
                                                                var gpos: Vector2 = wp["pos"] + (wp["in"] as Vector2) * 135.0
                                                                var g := _glow(gpos, 3.1, Color(1.0, 0.24, 0.16), 0.34)
                                                                lamp_lights.append({"spr": g, "base": 0.62})
                                                                wall_lamp_pos.append(wp["pos"])
                                                                light_pools.append({"pos": gpos, "r": 300.0, "col": Color(1.0, 0.45, 0.30), "a": 0.16})

func _lab_light(pos: Vector2, wide := false) -> void:
                                                                # настенный светильник вместо потолочной плиты; один аддитивный глоу (было два)
                                                                var wp := _wall_point(pos)
                                                                var s := _mk_spr("z_wallamp", wp["pos"], 1.2, 7, Color(0.94, 1.0, 1.0))
                                                                s.rotation = wp["rot"]
                                                                var gpos: Vector2 = wp["pos"] + (wp["in"] as Vector2) * (175.0 if wide else 135.0)
                                                                # FIX7: рассеянный свет — широкий мягкий ореол вместо яркого пятна
                                                                var g := _glow(gpos, 3.2 if wide else 2.5, Color(0.85, 0.96, 1.0), 0.26)
                                                                lab_lights.append({"spr": g, "base": 0.52})
                                                                wall_lamp_pos.append(wp["pos"])
                                                                light_pools.append({"pos": gpos, "r": 390.0 if wide else 310.0, "col": Color(0.80, 0.92, 1.0), "a": 0.16})

func _glow(pos: Vector2, scl: float, col: Color, a: float) -> Sprite2D:
                                                                if bench.has("glow"):
                                                                                                                                var dummy := Sprite2D.new()
                                                                                                                                dummy.position = pos
                                                                                                                                return dummy
                                                                # ФПС: квант света обрезается по комнате (шейдер) — на стены не залазит,
                                                                # радиус уменьшен, текстура 128px. Аддитивный квад вместо прохода освещения.
                                                                # FIX7v2: свет мягче — меньший радиус и заметно ниже яркость ядра
                                                                scl *= 0.55
                                                                a = minf(1.0, a * 0.70)
                                                                var s := Sprite2D.new()
                                                                s.texture = _light_tex()
                                                                s.position = pos
                                                                s.scale = Vector2(scl, scl)
                                                                s.modulate = Color(col.r, col.g, col.b, a)
                                                                s.z_index = 12
                                                                s.material = _clip_mat_for(pos)
                                                                fx_layer.add_child(s)
                                                                return s

func _load_frames(base: String) -> Array:
                                                                var arr: Array = []
                                                                for i in range(4):
                                                                                                                                var t = G.tex(base + "_w%d" % i)
                                                                                                                                if t != null:
                                                                                                                                                                                                arr.append(t)
                                                                return arr
var _light_tex_cache: Texture2D = null

func _light_tex() -> Texture2D:
                                                                if _light_tex_cache != null:
                                                                                                                                return _light_tex_cache
                                                                var g := Gradient.new()
                                                                # FIX7v2: мягкий колокол света вместо яркого «блина» — белые пятна меньше и тише
                                                                g.set_color(0, Color(1, 1, 1, 0.80))
                                                                g.add_point(0.16, Color(1, 1, 1, 0.58))
                                                                g.add_point(0.42, Color(1, 1, 1, 0.22))
                                                                g.add_point(0.72, Color(1, 1, 1, 0.07))
                                                                g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
                                                                var gt := GradientTexture2D.new()
                                                                gt.gradient = g
                                                                # FIX7v2: 256px — спад плавнее, без ступенек
                                                                gt.width = 256
                                                                gt.height = 256
                                                                gt.fill = GradientTexture2D.FILL_RADIAL
                                                                gt.fill_from = Vector2(0.5, 0.5)
                                                                gt.fill_to = Vector2(0.5, 0.0)
                                                                _light_tex_cache = gt
                                                                return gt

func _flashlight(tex_scale: float, energy: float, col: Color) -> PointLight2D:
                                                                # ФПС: настоящий PointLight2D отключён (проход света + тени были самым
                                                                # дорогим местом на телефоне). Свет имитирует halo-спрайт игрока,
                                                                # обрезанный по комнатам тем же шейдером.
                                                                var l := PointLight2D.new()
                                                                l.enabled = false
                                                                l.texture = _light_tex()
                                                                l.texture_scale = tex_scale
                                                                l.energy = energy
                                                                l.color = col
                                                                l.shadow_enabled = false
                                                                return l

func _occluder_for_walls() -> void:
                                                                # ФПС: окклюдеры не нужны — реального источника света больше нет
                                                                pass

func _door(id: String, pos: Vector2, vertical: bool, gap_w: float) -> Dictionary:
                                                                # дверь-проп в проёме стены: перекрывает весь проём Rect2, открывается интерактивом
                                                                var scl: float = clampf(gap_w / 205.0, 0.7, 1.15)
                                                                var spr := _mk_spr("z_door", pos, scl, 4)
                                                                spr.rotation = PI / 2.0 if vertical else 0.0
                                                                var th := 26.0
                                                                var wrect: Rect2
                                                                if vertical:
                                                                                                                                wrect = Rect2(pos.x - th * 0.5, pos.y - gap_w * 0.5, th, gap_w)
                                                                else:
                                                                                                                                wrect = Rect2(pos.x - gap_w * 0.5, pos.y - th * 0.5, gap_w, th)
                                                                walls.append(wrect)
                                                                var pr := {"spr": spr, "pos": pos, "radius": 6.0, "kind": "door", "solid": false, "door_id": id}
                                                                props.append(pr)
                                                                var door := {"pr": pr, "wall": wrect, "vertical": vertical, "opened": false, "id": id}
                                                                doors[id] = door
                                                                door_zones.append(wrect.grow(34.0))   # FIX7v2
                                                                return door

func _open_door(id: String) -> void:
                                                                var door: Dictionary = doors.get(id, {})
                                                                if door.is_empty() or bool(door["opened"]):
                                                                                                                                return
                                                                door["opened"] = true
                                                                walls.erase(door["wall"])
                                                                if wall_occluders.has(door["wall"]):
                                                                                                                                var occ = wall_occluders[door["wall"]]
                                                                                                                                if is_instance_valid(occ):
                                                                                                                                                                                                occ.queue_free()
                                                                                                                                wall_occluders.erase(door["wall"])
                                                                var spr: Sprite2D = door["pr"]["spr"]
                                                                var slide := Vector2(-30, 0) if bool(door["vertical"]) else Vector2(0, -30)
                                                                var tw := spr.create_tween()
                                                                tw.set_parallel(true)
                                                                tw.tween_property(spr, "modulate:a", 0.0, 0.6)
                                                                tw.tween_property(spr, "position", spr.position + slide, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                                                                tw.chain().tween_callback(func(): spr.visible = false)
                                                                # пыль из-под двери
                                                                var dust := CPUParticles2D.new()
                                                                dust.one_shot = true
                                                                dust.emitting = true
                                                                dust.amount = 18
                                                                dust.lifetime = 1.1
                                                                dust.texture = _light_tex()
                                                                dust.scale_amount_min = 0.3
                                                                dust.scale_amount_max = 0.9
                                                                dust.spread = 180.0
                                                                dust.initial_velocity_min = 20.0
                                                                dust.initial_velocity_max = 70.0
                                                                dust.gravity = Vector2(0, -8)
                                                                dust.color = Color(0.65, 0.72, 0.74, 0.30)
                                                                dust.position = door["pr"]["pos"]
                                                                fx_layer.add_child(dust)
                                                                G.play_sfx("z_door", -5.0)
                                                                G.play_sfx("z_hiss", -14.0)
                                                                shake_camera(0.10)
                                                                floor_node.redraw_all()
                                                                if tut != null:
                                                                                                                                tut.hint("door", "door", "ГЕРМОДВЕРЬ", "Двери бункера открываются кнопкой действия. Открытая дверь остаётся открытой — но и мёртвые теперь могут пройти.", 55)

# ================= БУНКЕР (СЕКТОР 1) =================
# Новая планировка — компактный сеточный бункер лаборатории «Заря»:
#   РЯД 1: ПОСТ ОХРАНЫ · АРХИВ · ШЛЮЗОВАЯ (сканер, гермодверь, лестница)
#   РЯД 2: ЛАБОРАТОРНЫЙ ЗАЛ (двойной) · КРИО-ХРАНИЛИЩЕ
#   РЯД 3: МЕДОТСЕК (старт) · КАРАНТИННЫЙ БЛОК · ГЕНЕРАТОРНАЯ
# Все помещения сомкнуты (без чёрных пустот), между ними — открываемые двери.
func _build_bunker() -> void:
        # FIX9: ВСЯ планировка бункера живёт в сцене scenes/locations/Bunker_Zarya.tscn.
        # Открой её в редакторе: стены (Wall*), комнаты (Room*), гермодвери (Door_*),
        # мебель (Prop*), свет, трупы и мёртвые — обычные узлы, двигай мышью.
        # Этот код лишь читает дефиниции и строит бункер средствами движка боя.
        #
        # FIX11: перед загрузкой сцена проверяется как текст (SceneCheck).
        # Если планировку правили вручную и файл сломался (потеряна скобка,
        # опечатка в Vector2/Rect2, ссылка на переименованную ноду) — в консоль
        # и журнал пишется ПОНЯТНЫЙ список проблем с номерами строк, а бункер
        # собирается из резервной планировки FALLBACK_BUNKER. Игра остаётся
        # проходимой, и сразу ясно, что чинить в сцене.
        var scene_path := "res://scenes/locations/Bunker_Zarya.tscn"
        var errs: PackedStringArray = SceneCheck.validate_tscn(scene_path, true)
        if not errs.is_empty():
                for e in errs:
                        push_error("СЦЕНА БУНКЕРА: " + e)
                print(SceneCheck.report(scene_path, errs))
                _log("Сцена бункера повреждена (%d проблем) — работает резервная планировка. Список проблем — в консоли Godot (вкладка «Вывод»)." % errs.size(), Color(0.95, 0.62, 0.40), "СИСТЕМА")
                _toast("Сцена бункера повреждена — включён резервный план")
        var ps: PackedScene = null
        if errs.is_empty():
                ps = load(scene_path)
                if ps == null:
                        push_error("СЦЕНА БУНКЕРА: load() вернул null: " + scene_path)
        if ps != null:
                var lay := ps.instantiate()
                _read_level_defs(lay)
                lay.free()
        else:
                _build_bunker_fallback()
        # FIX11: спавн и мебель не должны оказаться в стенах/дверных проёмах
        _bunker_sanity()
        # случайная атмосфера остаётся кодом: стекло у капсулы, кровь, пар
        _bunker_ambient_fx()
        # тени/окклюдеры стен (после всех стен и дверей) + привязка мебели к стенам
        _occluder_for_walls()
        _snap_props_to_walls()
        _snap_signs_to_walls()
        # задачи миссии и весь сценарий пролога «ЗАРЯ» — см. _zpro_init()
        _zpro_init()

# ---------- FIX11: страховка после ручной правки сцены ----------
func _bunker_sanity() -> void:
        # точка появления игрока: выталкиваем из стен и твёрдой мебели
        var sp := _scene_spawn if _scene_spawn != Vector2.ZERO else Vector2(350, 1750)
        _scene_spawn = _collide_circle(sp, 16.0)
        # мебель не должна перекрывать дверные проёмы: выталкиваем вдоль проёма
        for pr in props:
                if not bool(pr.get("solid", true)):
                        continue
                var k := str(pr.get("kind", ""))
                if not (k == "" or k == "cabinet" or k == "gear_table" or k == "loot_crate" or k == "capsule"):
                        continue
                var half: Vector2 = pr.get("half", Vector2(48, 48))
                var rot: float = (pr["spr"] as Sprite2D).rotation
                if absf(fposmod(rot + PI / 2.0, PI)) < 0.1 or absf(fposmod(rot - PI / 2.0, PI)) < 0.1:
                        half = Vector2(half.y, half.x)
                var p: Vector2 = pr["pos"]
                var aabb := Rect2(p - half, half * 2.0)
                for dz in door_zones:
                        var dr := dz as Rect2
                        if not dr.intersects(aabb):
                                continue
                        if dr.size.x >= dr.size.y:
                                var ld := aabb.position.x - dr.position.x
                                var rd := dr.end.x - aabb.end.x
                                p.x = dr.position.x - half.x - 2.0 if ld <= rd else dr.end.x + half.x + 2.0
                        else:
                                var ud := aabb.position.y - dr.position.y
                                var dn := dr.end.y - aabb.end.y
                                p.y = dr.position.y - half.y - 2.0 if ud <= dn else dr.end.y + half.y + 2.0
                if p != (pr["pos"] as Vector2):
                        p = _collide_circle(p, maxf(half.x, half.y) * 0.5)
                        (pr["spr"] as Sprite2D).position = p
                        pr["pos"] = p

# ---------- FIX11: резервная планировка (если сцена не загрузилась) ----------
func _build_bunker_fallback() -> void:
        var fb: Dictionary = FALLBACK_BUNKER
        for z in fb["zones"]:
                _zone(float(z[0]), float(z[1]), float(z[2]), float(z[3]), str(z[4]))
        for w in fb["walls"]:
                _wall(float(w[0]), float(w[1]), float(w[2]), float(w[3]))
        for r in fb["rooms"]:
                var doors_d: Dictionary = r[4]
                if r.size() >= 6:
                        _room(float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[5]), doors_d)
                else:
                        _room(float(r[0]), float(r[1]), float(r[2]), float(r[3]), 22.0, doors_d)
        for d in fb["doors"]:
                _door(str(d[0]), Vector2(float(d[1]), float(d[2])), bool(d[3]), float(d[4]))
        for p in fb["props"]:
                var pr := _prop(str(p[0]), Vector2(float(p[1]), float(p[2])), float(p[4]), str(p[3]), float(p[5]), bool(p[7]), int(p[6]))
                if absf(float(p[8])) > 0.001:
                        (pr["spr"] as Sprite2D).rotation = deg_to_rad(float(p[8]))
                if p.size() >= 10:
                        (pr["spr"] as Sprite2D).modulate = p[9]
                if str(p[3]) == "stairs":
                        stairs_prop = pr
                        (stairs_prop["spr"] as Sprite2D).visible = false
        for s in fb["sprs"]:
                var scol: Color = s[5] if s.size() >= 6 else Color(1, 1, 1)
                var spr := _mk_spr(str(s[0]), Vector2(float(s[1]), float(s[2])), float(s[3]), int(s[4]), scol)
                if str(s[0]).begins_with("z_i_"):
                    _add_shadow(spr, 0.85, 0.5, 0.25)
        for l in fb["lights_lab"]:
                _lab_light(Vector2(float(l[0]), float(l[1])), bool(l[2]))
        for l in fb["lights_red"]:
                _red_lamp(Vector2(float(l[0]), float(l[1])))
        for b in fb["bloods"]:
                _blood_pool(Vector2(float(b[0]), float(b[1])), bool(b[2]))
        for c in fb["corpses"]:
                _spawn_corpse(str(c[0]), Vector2(float(c[1]), float(c[2])))
        for z in fb["zombies"]:
                _spawn_zombie(str(z[0]), Vector2(float(z[1]), float(z[2])))
        _scene_spawn = Vector2(float(fb["spawn"][0]), float(fb["spawn"][1]))
        push_warning("Бункер собран из резервной планировки FALLBACK_BUNKER")

# ============================================================
# FALLBACK_BUNKER — резервная планировка бункера «ЗАРЯ»
# Данные сняты с scenes/locations/Bunker_Zarya.tscn (v2.5).
# Если сцена повреждена (например, при правке мебели вручную),
# валидатор SceneCheck это обнаружит, и бункер соберётся отсюда —
# игра остаётся проходимой, а в журнал пишется, что именно не так.
# ============================================================
const FALLBACK_BUNKER := {
	"zones": [
		[118.0, 142.0, 828.0, 536.0, "metal"],
		[1012.0, 142.0, 828.0, 536.0, "metal"],
		[1906.0, 142.0, 828.0, 536.0, "metal"],
		[118.0, 744.0, 1722.0, 536.0, "tile_lab"],
		[1906.0, 744.0, 828.0, 536.0, "tile_lab"],
		[118.0, 1346.0, 828.0, 536.0, "tile_med"],
		[1012.0, 1346.0, 828.0, 536.0, "tile_lab"],
		[1906.0, 1346.0, 828.0, 536.0, "conc"],
		[96.0, 1926.0, 872.0, 580.0, "conc"],
		[990.0, 1926.0, 872.0, 580.0, "tile_lab"],
		[1884.0, 1926.0, 872.0, 580.0, "tile_med"],
		[96.0, 2528.0, 872.0, 580.0, "metal"],
		[990.0, 2528.0, 872.0, 580.0, "tile_lab"],
		[1884.0, 2528.0, 872.0, 580.0, "tile_med"],
		[990.0, 3130.0, 872.0, 580.0, "metal"],
	],
	"walls": [
		[0.0, 0.0, 2880.0, 24.0],
		[0.0, 2088.0, 2880.0, 24.0],
		[0.0, 0.0, 24.0, 2112.0],
		[2856.0, 0.0, 24.0, 2112.0],
		[24.0, 24.0, 2832.0, 96.0],
		[24.0, 1926.0, 2832.0, 162.0],
		[24.0, 24.0, 72.0, 2064.0],
		[2778.0, 24.0, 78.0, 2064.0],
	],
	"rooms": [
		[96.0, 120.0, 872.0, 580.0, {"s": [[0.38, 0.62]]}, 22],
		[990.0, 120.0, 872.0, 580.0, {"s": [[0.38, 0.62]]}, 22],
		[1884.0, 120.0, 872.0, 580.0, {"s": [[0.38, 0.62]]}, 22],
		[96.0, 722.0, 1766.0, 580.0, {"n": [[0.187, 0.306], [0.694, 0.812]], "s": [[0.1325, 0.2288], [0.5685, 0.6648]], "e": [[0.307, 0.566]]}, 22],
		[1884.0, 722.0, 872.0, 580.0, {"w": [[0.307, 0.566]], "n": [[0.38, 0.62]], "s": [[0.38, 0.62]]}, 22],
		[96.0, 1324.0, 872.0, 580.0, {"n": [[0.268, 0.463]], "e": [[0.355, 0.631]], "s": [[0.268, 0.463]]}, 22],
		[990.0, 1324.0, 872.0, 580.0, {"n": [[0.126, 0.321]], "w": [[0.355, 0.631]], "e": [[0.355, 0.631]]}, 22],
		[1884.0, 1324.0, 872.0, 580.0, {"n": [[0.38, 0.62]], "w": [[0.355, 0.631]], "s": [[0.38, 0.62]]}, 22],
		[96.0, 1926.0, 872.0, 580.0, {"n": [[0.268, 0.463]], "e": [[0.355, 0.631]], "s": [[0.132, 0.321]]}],
		[990.0, 1926.0, 872.0, 580.0, {"n": [[0.126, 0.321]], "w": [[0.355, 0.631]], "e": [[0.355, 0.631]]}],
		[1884.0, 1926.0, 872.0, 580.0, {"n": [[0.38, 0.62]], "w": [[0.355, 0.631]], "s": [[0.355, 0.631]]}],
		[96.0, 2528.0, 872.0, 580.0, {"n": [[0.132, 0.321]], "e": [[0.355, 0.631]]}],
		[990.0, 2528.0, 872.0, 580.0, {"n": [[0.126, 0.321]], "w": [[0.355, 0.631]], "e": [[0.355, 0.631]], "s": [[0.126, 0.321]]}],
		[1884.0, 2528.0, 872.0, 580.0, {"n": [[0.355, 0.631]], "w": [[0.355, 0.631]]}],
		[990.0, 3130.0, 872.0, 580.0, {"n": [[0.126, 0.321]]}],
	],
	"doors": [
		["gp", 532.0, 733.0, false, 210.0],
		["ar", 1426.0, 733.0, false, 210.0],
		["air", 2320.0, 733.0, false, 210.0],
		["lab_e", 1873.0, 975.0, true, 150.0],
		["med_n", 415.0, 1313.0, false, 170.0],
		["qr_n", 1185.0, 1313.0, false, 170.0],
		["med_e", 979.0, 1610.0, true, 160.0],
		["qr_e", 1873.0, 1610.0, true, 160.0],
		["cryo_s", 2320.0, 1313.0, false, 210.0],
		["tech_n", 415.0, 1937.0, false, 210.0],
		["cryo_s2", 2320.0, 1937.0, false, 210.0],
		["tech_e", 979.0, 2212.0, true, 210.0],
		["wrk_e", 1873.0, 2212.0, true, 210.0],
		["gen_s", 415.0, 2539.0, false, 210.0],
		["qr2_n", 1185.0, 2539.0, false, 210.0],
		["obs_n", 2320.0, 2539.0, false, 210.0],
		["arm_e", 979.0, 2814.0, true, 210.0],
		["qr2_e", 1873.0, 2814.0, true, 210.0],
		["sas_n", 1185.0, 3141.0, false, 210.0],
	],
	"props": [
		["z_capsule", 350.0, 1720.0, "capsule", 44.0, 1.15, 3, true, 0.0],
		["z_medtable", 650.0, 1440.0, "gear_table", 34.0, 1.25, 3, true, 0.0],
		["z_cabinet", 238.0, 1420.0, "cabinet", 26.0, 1.25, 3, true, 0.0],
		["z_cabinet", 872.0, 1440.0, "cabinet", 26.0, 1.2, 3, true, 90.0],
		["z_cabinet", 1768.0, 1434.0, "cabinet", 26.0, 1.2, 3, true, 90.0],
		["z_shelf", 1650.0, 1811.0, "cabinet", 30.0, 1.25, 3, true, 0.0],
		["z_capsule", 304.0, 924.0, "", 40.0, 1.05, 3, true, -90.0],
		["z_capsule", 800.0, 1171.0, "", 40.0, 1.05, 3, true, 180.0],
		["z_cabinet", 1767.0, 1190.0, "cabinet", 26.0, 1.2, 3, true, 90.0],
		["z_shelf", 1660.0, 842.0, "cabinet", 30.0, 1.25, 3, true, 0.0],
		["z_crate_z", 200.0, 1243.0, "loot_crate", 24.0, 1.3, 3, true, 0.0],
		["z_vent", 210.0, 1291.0, "vent", 0.0, 1.1, 6, false, 0.0],
		["z_cabinet", 873.0, 240.0, "cabinet", 26.0, 1.2, 3, true, 90.0],
		["z_crate_z", 300.0, 641.0, "loot_crate", 24.0, 1.35, 3, true, 0.0],
		["z_shelf", 875.0, 545.0, "cabinet", 30.0, 1.25, 3, true, 90.0],
		["z_shelf", 1150.0, 214.0, "cabinet", 30.0, 1.25, 3, true, 0.0],
		["z_shelf", 1420.0, 214.0, "cabinet", 30.0, 1.25, 3, true, 0.0],
		["z_shelf", 1690.0, 214.0, "cabinet", 30.0, 1.25, 3, true, 0.0],
		["z_crate_z", 1180.0, 641.0, "loot_crate", 24.0, 1.3, 3, true, 0.0],
		["z_cabinet", 1767.0, 480.0, "cabinet", 26.0, 1.2, 3, true, 90.0],
		["z_capsule", 2092.0, 926.0, "", 40.0, 1.05, 3, true, -90.0],
		["z_capsule", 2400.0, 844.0, "", 40.0, 1.05, 3, true, 0.0],
		["z_capsule", 2548.0, 1098.0, "", 40.0, 1.05, 3, true, 90.0],
		["z_shelf", 2300.0, 1210.0, "cabinet", 30.0, 1.25, 3, true, 0.0],
		["z_crate_z", 1955.0, 1243.0, "loot_crate", 24.0, 1.3, 3, true, 0.0],
		["z_reactor", 2520.0, 1430.0, "", 30.0, 1.5, 3, true, 0.0],
		["z_reactor", 2612.0, 1430.0, "", 30.0, 1.5, 3, true, 0.0],
		["z_crate_z", 2687.0, 1520.0, "loot_crate", 24.0, 1.3, 3, true, 0.0],
		["z_scanner", 2000.0, 420.0, "scanner", 16.0, 1.0, 7, false, 0.0],
		["z_airlock", 2320.0, 320.0, "airlock", 0.0, 1.1, 7, false, 0.0],
		["z_cabinet", 2661.0, 260.0, "cabinet", 26.0, 1.2, 3, true, 90.0],
		["z_stairs", 2320.0, 180.0, "stairs", 0.0, 1.7, 8, false, 0.0],
		["z_reactor", 300.0, 2100.0, "generator", 0.0, 1.42, 5, true, 0.0],
		["z_cabinet", 700.0, 2000.0, "gen_panel", 0.0, 1.42, 5, true, 0.0],
		["z_vent", 170.0, 2320.0, "coolant", 0.0, 1.42, 5, true, 0.0],
		["z_crate_z", 850.0, 2420.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 760.0, 2320.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
		["z_player", 1300.0, 2100.0, "serov", 18.0, 1.42, 5, true, 0.0, Color(0.72, 0.8, 0.9, 1)],
		["z_medtable", 1180.0, 2210.0, "serov_table", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 1700.0, 2000.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
		["z_crate_z", 1080.0, 2360.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_reactor", 1520.0, 2420.0, "tape_deck", 0.0, 1.42, 5, true, 0.0],
		["z_capsule", 2300.0, 2120.0, "exp12_capsule", 0.0, 1.42, 5, true, 0.0],
		["z_scanner", 2620.0, 2050.0, "exp12_video", 0.0, 1.42, 5, true, 0.0],
		["z_crate_z", 2380.0, 2420.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_cabinet", 300.0, 2720.0, "weapon_locker", 0.0, 1.42, 5, true, 0.0],
		["z_crate_z", 700.0, 2600.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_crate_z", 820.0, 2950.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 560.0, 2960.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
		["z_capsule", 1150.0, 2620.0, "cell", 0.0, 1.42, 5, true, 0.0],
		["z_capsule", 1450.0, 2620.0, "cell", 0.0, 1.42, 5, true, 0.0],
		["z_capsule", 1750.0, 2620.0, "cell", 0.0, 1.42, 5, true, 0.0],
		["z_vent", 1400.0, 2560.0, "vent_bypass", 0.0, 1.42, 5, false, 0.0],
		["z_scanner", 1080.0, 2920.0, "iso_panel", 0.0, 1.42, 5, true, 0.0],
		["z_airlock", 1300.0, 3060.0, "sas_gate", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 1600.0, 2900.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
		["z_zombie_walk", 1180.0, 2660.0, "", 0.0, 0.8, 2, false, 0.0, Color(0.45, 0.5, 0.5, 0.55)],
		["z_zombie_sci", 1480.0, 2660.0, "", 0.0, 0.8, 2, false, 0.0, Color(0.45, 0.5, 0.5, 0.55)],
		["z_zombie_walk", 1720.0, 2660.0, "", 0.0, 0.8, 2, false, 0.0, Color(0.4, 0.46, 0.46, 0.5)],
		["z_scanner", 2320.0, 2620.0, "obs_terminal", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 2500.0, 2620.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 2100.0, 2620.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
		["z_zombie_sci", 2620.0, 2860.0, "", 0.0, 0.8, 2, false, 0.0, Color(0.45, 0.5, 0.5, 0.5)],
		["z_reactor", 1300.0, 3420.0, "hydro", 0.0, 1.42, 5, true, 0.0],
		["z_vent", 1620.0, 3340.0, "hydro_lever", 0.0, 1.42, 5, true, 0.0],
		["z_scanner", 1080.0, 3340.0, "power_hold", 0.0, 1.42, 5, true, 0.0],
		["z_sign", 1426.0, 3240.0, "speaker", 0.0, 1.42, 5, false, 0.0],
		["z_crate_z", 1000.0, 3600.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_crate_z", 1800.0, 3560.0, "loot_crate", 0.0, 1.42, 5, true, 0.0],
		["z_shelf", 700.0, 3300.0, "cabinet", 0.0, 1.42, 5, true, 0.0],
	],
	"sprs": [
		["z_sign", 640.0, 1372.0, 0.92, 9],
		["z_i_meds", 580.0, 1428.0, 0.6, 6],
		["z_i_band", 612.0, 1432.0, 0.6, 6],
		["z_i_tq", 596.0, 1452.0, 0.6, 6],
		["z_sign", 1560.0, 1372.0, 0.92, 9],
		["z_sign", 1230.0, 772.0, 0.95, 9],
		["z_sign", 560.0, 166.0, 0.92, 9],
		["z_sign", 1426.0, 656.0, 0.95, 9],
		["z_sign", 1920.0, 1180.0, 0.95, 9],
		["z_sign", 2520.0, 640.0, 0.95, 9],
		["z_sign", 1100.0, 1980.0, 1.0, 5],
		["z_sign", 2200.0, 1980.0, 1.0, 5],
		["z_sign", 415.0, 2580.0, 1.0, 5],
		["z_sign", 2320.0, 2580.0, 1.0, 5],
	],
	"lights_lab": [
		[350.0, 1560.0, true],
		[640.0, 1660.0, false],
		[1600.0, 1560.0, false],
		[700.0, 900.0, true],
		[1400.0, 900.0, true],
		[700.0, 1180.0, false],
		[1400.0, 1180.0, false],
		[532.0, 400.0, true],
		[1426.0, 400.0, true],
		[2320.0, 1000.0, true],
		[2300.0, 1600.0, false],
		[2320.0, 500.0, false],
		[350.0, 2100.0, true],
		[700.0, 2350.0, false],
		[1300.0, 2150.0, true],
		[1550.0, 2400.0, false],
		[2300.0, 2180.0, false],
		[450.0, 2700.0, true],
		[1250.0, 2700.0, true],
		[1600.0, 2950.0, false],
		[2320.0, 2750.0, true],
	],
	"lights_red": [
		[1046.0, 1420.0],
		[1550.0, 1012.0],
		[2400.0, 1700.0],
		[530.0, 1980.0],
		[2500.0, 2320.0],
		[1426.0, 2580.0],
		[1185.0, 3040.0],
		[2500.0, 2900.0],
		[1185.0, 3220.0],
		[1650.0, 3560.0],
	],
	"bloods": [
		[310.0, 1665.0, false],
		[430.0, 1560.0, true],
		[2260.0, 2200.0, false],
		[1420.0, 2800.0, true],
		[1150.0, 3000.0, false],
		[2260.0, 2860.0, false],
		[1350.0, 3480.0, true],
	],
	"corpses": [
		["guard", 2250.0, 560.0],
		["sci", 1400.0, 1240.0],
		["sci", 800.0, 800.0],
		["sci", 2400.0, 1100.0],
		["sci", 600.0, 2300.0],
		["guard", 1300.0, 2980.0],
	],
	"zombies": [
		["sci", 1150.0, 1500.0],
		["sci", 1300.0, 1680.0],
		["sci", 1450.0, 1520.0],
		["walk", 700.0, 1000.0],
		["run", 2400.0, 1650.0],
		["walk", 500.0, 2180.0],
		["run", 1750.0, 2380.0],
		["sci", 1250.0, 2760.0],
		["sci", 1550.0, 2960.0],
		["run", 1050.0, 3260.0],
	],
	"spawn": [350.0, 1750.0],
}

# ---------- FIX9: чтение дефиниций рукописной локации ----------
func _read_level_defs(root) -> void:
        for ch in root.get_children():
                if ch is Node2D and ch.get("def_type") != null:
                        _apply_level_def(ch)
                _read_level_defs(ch)

func _apply_level_def(d) -> void:
        var dt: String = d.def_type
        var p: Vector2 = d.position
        match dt:
                "zone":
                        var r: Rect2 = d.rect
                        _zone(p.x, p.y, r.size.x, r.size.y, d.def_kind)
                "wall":
                        var r: Rect2 = d.rect
                        _wall(p.x, p.y, r.size.x, r.size.y)
                "room":
                        var r: Rect2 = d.rect
                        _room(p.x, p.y, r.size.x, r.size.y, d.room_thickness, d.doors)
                "door":
                        _door(d.def_id, p, d.vertical, d.gap_w)
                "prop":
                        var pr := _prop(d.tex, p, d.def_radius, d.def_kind, d.def_scale, d.solid, d.def_z)
                        if absf(d.rot_deg) > 0.001:
                                (pr["spr"] as Sprite2D).rotation = deg_to_rad(d.rot_deg)
                        # FIX11: def_color раньше игнорировался — силуэты были яркими
                        if d.def_color != Color(1, 1, 1):
                                (pr["spr"] as Sprite2D).modulate = d.def_color
                        if d.def_kind == "stairs":
                                stairs_prop = pr
                                (stairs_prop["spr"] as Sprite2D).visible = false
                "spr":
                        var s := _mk_spr(d.tex, p, d.def_scale, d.def_z, d.def_color)
                        if d.tex.begins_with("z_i_"):
                            _add_shadow(s, 0.85, 0.5, 0.25)
                        if absf(d.rot_deg) > 0.001:
                                s.rotation = deg_to_rad(d.rot_deg)
                "light_lab":
                        _lab_light(p, d.wide)
                "light_red":
                        _red_lamp(p)
                "blood":
                        _blood_pool(p, d.big)
                "corpse":
                        _spawn_corpse(d.def_kind, p)
                "zombie":
                        _spawn_zombie(d.def_kind, p)
                "spawn":
                        _scene_spawn = p

# ---------- атмосфера бункера (случайные элементы — код) ----------
func _bunker_ambient_fx() -> void:
        # стекло и кровь у капсулы (по ТЗ — разбита)
        for gp in [Vector2(268, 1662), Vector2(352, 1656), Vector2(305, 1632)]:
                var shard := _mk_spr("fx_spark", gp + Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.5, 6, Color(0.75, 0.82, 0.85, 0.85))
                shard.rotation = randf() * TAU
                glass_props.append(shard)
        _blood_pool(Vector2(310, 1665), false)
        _blood_pool(Vector2(430, 1560), true)
        # карантинный блок: случайные пятна крови
        for i in range(5):
                _blood_pool(Vector2(1120 + randf() * 620, 1560 + randf() * 300), randf() < 0.5)
        # пар из вентиляции
        for vp in [Vector2(210, 1252), Vector2(2100, 1500)]:
                var st := CPUParticles2D.new()
                steam_particles.append(st)
                st.amount = 12 if OS.has_feature("mobile") or OS.has_feature("android") else 22
                st.lifetime = 2.6
                st.texture = _light_tex()
                st.scale_amount_min = 0.35
                st.scale_amount_max = 0.8
                st.direction = Vector2(0, -1)
                st.spread = 24.0
                st.initial_velocity_min = 18.0
                st.initial_velocity_max = 42.0
                st.gravity = Vector2(0, -12)
                st.color = Color(0.75, 0.78, 0.82, 0.16)
                st.position = vp
                fx_layer.add_child(st)
        spark_points = [Vector2(2140, 1480), Vector2(1080, 1560)]
        # v2.8: умирающие лампы (карантинный блок и техтоннель)
        _dying_lamp(Vector2(1400, 1700))
        _dying_lamp(Vector2(700, 2420))

func _build_surface() -> void:
                                                                _zone(0, 0, MAPW_S * TS_S, MAPH_S * TS_S, "snow")
                                                                var rng := RandomNumberGenerator.new()
                                                                rng.seed = 7717 + sector_idx * 131
                                                                # дорога через карту
                                                                var road_y := rng.randf_range(0.3, 0.7) * MAPH_S * TS_S
                                                                _zone(0, road_y - 90, MAPW_S * TS_S, 180, "road")
                                                                # внешние стены — непроходимый лес/скалы
                                                                _wall(0, 0, MAPW_S * TS_S, 40)
                                                                _wall(0, MAPH_S * TS_S - 40, MAPW_S * TS_S, 40)
                                                                _wall(0, 0, 40, MAPH_S * TS_S)
                                                                _wall(MAPW_S * TS_S - 40, 0, 40, MAPH_S * TS_S)
                                                                var center := map_size * 0.5
                                                                # постройки/руины
                                                                var buildings: Array = []
                                                                var nb := 7 + sector_idx % 3
                                                                for i in range(nb):
                                                                                                                                var bw := rng.randf_range(300, 640)
                                                                                                                                var bh := rng.randf_range(240, 420)
                                                                                                                                var bx := rng.randf_range(400, map_size.x - 400 - bw)
                                                                                                                                var by := rng.randf_range(400, map_size.y - 400 - bh)
                                                                                                                                if Rect2(bx, by, bw, bh).grow(180).has_point(center):
                                                                                                                                                                                                continue
                                                                                                                                var doors := {"n": [[rng.randf_range(0.2, 0.5), rng.randf_range(0.55, 0.8)]]}
                                                                                                                                if i % 2 == 0:
                                                                                                                                                                                                doors["s"] = [[rng.randf_range(0.2, 0.4), rng.randf_range(0.6, 0.8)]]
                                                                                                                                _room(bx, by, bw, bh, 26, doors)
                                                                                                                                buildings.append(Rect2(bx, by, bw, bh))
                                                                                                                                _decal(2, Vector2(bx + bw * 0.5, by + bh * 0.5), 1.2)
                                                                # объекты миссии
                                                                if mission == "warehouse" or mission == "clear":
                                                                                                                                # склад: постройка в центре с припасами
                                                                                                                                var wx := center.x - 320
                                                                                                                                var wy := center.y - 220
                                                                                                                                _room(wx, wy, 640, 440, 26, {"s": [[0.4, 0.6]], "n": [[0.35, 0.55]]})
                                                                                                                                _zone(wx, wy, 640, 440, "conc")
                                                                                                                                _prop("z_shelf", Vector2(wx + 120, wy + 120), 34.0, "cabinet", 1.5)
                                                                                                                                _prop("z_shelf", Vector2(wx + 520, wy + 120), 34.0, "cabinet", 1.5)
                                                                                                                                _prop("z_crate_z", Vector2(wx + 320, wy + 150), 24.0, "loot_crate", 1.5)
                                                                                                                                _prop("z_crate_z", Vector2(wx + 250, wy + 320), 24.0, "loot_crate", 1.5)
                                                                                                                                zone_target = Rect2(wx - 60, wy - 60, 760, 560)
                                                                elif mission == "tablets":
                                                                                                                                for i in range(3):
                                                                                                                                                                                                var a := rng.randf() * TAU
                                                                                                                                                                                                var rr := rng.randf_range(500, 1400)
                                                                                                                                                                                                var tp := center + Vector2.from_angle(a) * rr
                                                                                                                                                                                                tp = tp.clamp(Vector2(300, 300), map_size - Vector2(300, 300))
                                                                                                                                                                                                _decal(2, tp + Vector2(30, 20), 0.8)
                                                                                                                                tablets_left = 3
                                                                elif mission == "defense":
                                                                                                                                # мачта в центре, мешки по кругу
                                                                                                                                _prop("prop_watertower", center, 30.0, "tower", 1.6, true, 4).get("spr").modulate = Color(0.8, 0.84, 0.92)
                                                                                                                                for i in range(6):
                                                                                                                                                                                                var a2 := TAU * i / 6.0
                                                                                                                                                                                                _prop("prop_sandbags", center + Vector2.from_angle(a2) * 200.0, 30.0, "", 1.5, true, 4)
                                                                                                                                zone_target = Rect2(center.x - 460, center.y - 460, 920, 920)
                                                                elif mission == "rescue":
                                                                                                                                _prop("prop_house_1", center, 0.0, "", 1.5, false, 3).get("spr").modulate = Color(0.78, 0.82, 0.9)
                                                                                                                                _prop("prop_sandbags", center + Vector2(90, 60), 30.0, "", 1.5, true, 4)
                                                                                                                                # гражданский спрятался
                                                                                                                                var spr := _mk_spr("z_civ", center + Vector2(-10, 0), 1.42, 5)
                                                                                                                                rescue_npc = {"spr": spr, "pos": spr.position, "alive": true, "follow": false}
                                                                elif mission == "final":
                                                                                                                                # реакторный блок
                                                                                                                                _prop("z_reactor", center, 46.0, "reactor", 1.8, true, 4)
                                                                                                                                _red_lamp(center + Vector2(-260, -180))
                                                                                                                                _red_lamp(center + Vector2(260, 180))
                                                                                                                                zone_target = Rect2(center.x - 700, center.y - 700, 1400, 1400)
                                                                # ящики/бочки разбросом
                                                                for i in range(6 + sector_idx % 4):
                                                                                                                                var lx := rng.randf_range(300, map_size.x - 300)
                                                                                                                                var ly := rng.randf_range(300, map_size.y - 300)
                                                                                                                                _prop("z_crate_z" if rng.randf() < 0.5 else "z_barrel", Vector2(lx, ly), 20.0, "loot_crate" if rng.randf() < 0.6 else "", 1.4)
                                                                # зомби по группам
                                                                var total := _zombie_budget()
                                                                var groups := 4 + mini(4, int(float(sector_idx) / 4.0))
                                                                for gi in range(groups):
                                                                                                                                var ga := rng.randf() * TAU
                                                                                                                                var gr := rng.randf_range(400, 1700)
                                                                                                                                var gp := center + Vector2.from_angle(ga) * gr
                                                                                                                                gp = gp.clamp(Vector2(400, 400), map_size - Vector2(400, 400))
                                                                                                                                var gn := 3 + rng.randi() % 4
                                                                                                                                for zi in range(gn):
                                                                                                                                                                                                if total <= 0:
                                                                                                                                                                                                                                                                break
                                                                                                                                                                                                total -= 1
                                                                                                                                                                                                var off := Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
                                                                                                                                                                                                _spawn_zombie(_pick_kind(rng), gp + off)
                                                                while total > 0:
                                                                                                                                total -= 1
                                                                                                                                var rp := Vector2(rng.randf_range(300, map_size.x - 300), rng.randf_range(300, map_size.y - 300))
                                                                                                                                _spawn_zombie(_pick_kind(rng), rp)
                                                                if mission == "warehouse":
                                                                                                                                # гарантированная охрана внутри склада (иначе зачистку не собрать)
                                                                                                                                for i in range(5):
                                                                                                                                                                                                var ip: Vector2 = zone_target.position + Vector2(rng.randf_range(90.0, zone_target.size.x - 90.0), rng.randf_range(90.0, zone_target.size.y - 90.0))
                                                                                                                                                                                                _spawn_zombie(_pick_kind(rng), ip)
                                                                # трупы для обыска
                                                                for i in range(3 + rng.randi() % 3):
                                                                                                                                var dx := rng.randf_range(400, map_size.x - 400)
                                                                                                                                var dy := rng.randf_range(400, map_size.y - 400)
                                                                                                                                _spawn_corpse(["sci", "civ", "guard"][rng.randi() % 3], Vector2(dx, dy))
                                                                # снег (метель)
                                                                var snow := CPUParticles2D.new()
                                                                snow.amount = 220
                                                                snow.lifetime = 5.0
                                                                snow.preprocess = 4.0
                                                                snow.texture = _light_tex()
                                                                snow.scale_amount_min = 0.045
                                                                snow.scale_amount_max = 0.11
                                                                snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
                                                                snow.emission_rect_extents = Vector2(1300, 10)
                                                                snow.direction = Vector2(-0.25, 1)
                                                                snow.spread = 12.0
                                                                snow.initial_velocity_min = 190.0
                                                                snow.initial_velocity_max = 330.0
                                                                snow.gravity = Vector2(6, 26)
                                                                snow.color = Color(1, 1, 1, 0.55)
                                                                snow.position = Vector2(0, -620)
                                                                camera.add_child(snow)
                                                                # задачи миссии
                                                                match mission:
                                                                                                                                "clear":
                                                                                                                                                                                                zone_total = zombies.size()
                                                                                                                                                                                                zone_count = 0
                                                                                                                                                                                                _add_objective("main", "Зачистить сектор от мёртвых (0/%d)" % zone_total)
                                                                                                                                                                                                _add_objective("evac", "Дойти до точки эвакуации")
                                                                                                                                "warehouse":
                                                                                                                                                                                                zone_total = 0
                                                                                                                                                                                                for z in zombies:
                                                                                                                                                                                                                                                                if zone_target.has_point(z["spr"].position):
                                                                                                                                                                                                                                                                                                                                z["zcount"] = true
                                                                                                                                                                                                                                                                                                                                zone_total += 1
                                                                                                                                                                                                zone_count = 0
                                                                                                                                                                                                _add_objective("main", "Зачистить склад (0/%d)" % zone_total)
                                                                                                                                                                                                _add_objective("evac", "Вернуться к точке эвакуации")
                                                                                                                                "tablets":
                                                                                                                                                                                                _add_objective("main", "Найти 3 планшета с данными")
                                                                                                                                                                                                _add_objective("evac", "Дойти до точки эвакуации")
                                                                                                                                "defense":
                                                                                                                                                                                                defense_t = 0.0
                                                                                                                                                                                                defense_wave = 0
                                                                                                                                                                                                _add_objective("main", "Продержаться 90 секунд (волны мёртвых)")
                                                                                                                                                                                                _add_objective("evac", "Отойти к точке эвакуации")
                                                                                                                                "rescue":
                                                                                                                                                                                                _add_objective("main", "Найти и спасти союзника")
                                                                                                                                                                                                _add_objective("evac", "Вывести союзника к эвакуации")
                                                                                                                                "final":
                                                                                                                                                                                                _add_objective("main", "Уничтожить АЛЬФУ (матку штамма)")
                                                                                                                                                                                                _add_objective("evac", "Покинуть сектор через эвакуацию")
                                                                # точка эвакуации пока закрыта (откроется после main)
                                                                extraction = Vector2(map_size.x * 0.5, map_size.y - 460)

func _zombie_budget() -> int:
                                                                var base := 12 + int(float(sector_idx) * 1.6)
                                                                if mission == "final":
                                                                                                                                base += 10
                                                                return mini(base, 34)

func _pick_kind(rng: RandomNumberGenerator) -> String:
                                                                var roll := rng.randf()
                                                                if sector_idx >= 19:
                                                                                                                                return "walk" if roll < 0.45 else ("run" if roll < 0.75 else ("cop" if roll < 0.9 else "brute"))
                                                                if sector_idx >= 14:
                                                                                                                                return "walk" if roll < 0.42 else ("run" if roll < 0.68 else ("cop" if roll < 0.88 else "brute"))
                                                                if sector_idx >= 8:
                                                                                                                                return "walk" if roll < 0.5 else ("run" if roll < 0.74 else ("cop" if roll < 0.94 else "brute"))
                                                                if sector_idx >= 5:
                                                                                                                                return "walk" if roll < 0.62 else ("run" if roll < 0.85 else "cop")
                                                                return "walk" if roll < 0.8 else "run"

# ================= ИГРОК =================
func _spawn_player() -> void:
                                                                var spr := _mk_spr("z_player", _player_start(), 1.05, 8)
                                                                _add_shadow(spr, 0.60, 0.32, 0.22)
                                                                var st := Med.mk_state()
                                                                var saved_st = G.zsave.get("pstate", null)
                                                                if saved_st is Dictionary and (saved_st as Dictionary).has("body"):
                                                                                                                                st = saved_st
                                                                                                                                # FIX-3: после поражения тело не переносится в новый бой полуразрушенным
                                                                                                                                for zn in ["head", "torso", "la", "ra", "ll", "rl"]:
                                                                                                                                                                                                st["body"][zn] = clampf(float(st["body"][zn]), 0.45, 1.0)
                                                                                                                                # FIX-4: РАНЫ НЕ ПЕРЕНОСЯТСЯ кровоточащими — иначе сразу после
                                                                                                                                # выхода из капсулы голова продолжает течь и игрок умирает.
                                                                                                                                # Считаем что между боями всё перевязано в лагере.
                                                                                                                                if st.has("wounds"):
                                                                                                                                                                                                for w in st["wounds"]:
                                                                                                                                                                                                                                                                w["bleed"] = 0
                                                                                                                                                                                                                                                                w["band"] = true
                                                                                                                                                                                                st["stress"] = minf(float(st.get("stress", 0.0)), 25.0)
                                                                var light := _flashlight(1.9, 0.95, Color(1.0, 0.94, 0.8))
                                                                var halo := _glow(spr.position, 2.5, Color(0.9, 0.92, 1.0), 0.32)
                                                                player = {
                                                                                                                                "spr": spr, "st": st, "infect": minf(55.0, float(G.zsave.get("infect", 0.0))), "alive": true,
                                                                                                                                "weapon": G.zsave.get("cur_weapon", "pistol"),
                                                                                                                                "mag": 0, "reload_t": 0.0, "fire_cd": 0.0,
                                                                                                                                "aim": 0.0, "facing": -PI / 2.0, "light": light, "halo": halo,
                                                                                                                                "hurt_cd": 0.0, "down_msg_t": 0.0, "bscale": 1.05,
                                                                                                                                "frames": _load_frames("z_player"), "idle_tex": G.tex("z_player"), "frame_i": -2,
                                                                }
                                                                # стартовый магазин
                                                                var wd: Dictionary = G.ZWEAPONS[player["weapon"]]
                                                                player["mag"] = int(wd["mag"])
                                                                if is_bunker:
                                                                                                                                # ФПС: PointLight2D отключён — светит halo-спрайт, обрезанный по комнатам
                                                                                                                                # FIX11: точка появления — из сцены (PlayerSpawn), выталкиваем из стен/мебели
                                                                                                                                spr.position = _collide_circle(_player_start(), 16.0)
                                                                                                                                spr.visible = false   # в капсуле
                                                                                                                                light.energy = 0.0
                                                                                                                                halo.scale = Vector2(3.0, 3.0)
                                                                                                                                halo.modulate.a = 0.42
                                                                                                                                in_capsule = true
                                                                                                                                _apply_capsule_ui()
                                                                else:
                                                                                                                                spr.position = _collide_circle(extraction + Vector2(0, 90), 15.0)   # ТЗ п.12: не появляться внутри стен/мебели
                                                                                                                                light.energy = 0.0
                                                                                                                                halo.scale = Vector2(2.6, 2.6)
                                                                                                                                halo.modulate.a = 0.3
                                                                                                                                in_capsule = false
                                                                player["halo"].position = spr.position
                                                                light.position = spr.position
                                                                # тревога: зомби рядом со стартом не бьют первые секунды бункера
                                                                time_alive = 0.0

func _player_start() -> Vector2:
                                                                if is_bunker:
                                                                                                                                return _scene_spawn if _scene_spawn != Vector2.ZERO else Vector2(350, 1750)
                                                                return extraction + Vector2(0, 90)

func _player_speed(want_run := false) -> float:
                                                                var base := 152.0
                                                                var st: Dictionary = player["st"]
                                                                var lm: float = Med.leg_mult({"st": st})
                                                                var infect_k := 1.0
                                                                if player["infect"] > 75.0:
                                                                                                                                infect_k = 0.9
                                                                elif player["infect"] > 45.0:
                                                                                                                                infect_k = 0.96
                                                                var stress_k := 1.0
                                                                if st["state"] == "panic":
                                                                                                                                stress_k = 1.12
                                                                elif st["state"] == "stupor":
                                                                                                                                stress_k = 0.6
                                                                var spd := base * lm * infect_k * stress_k
                                                                # FIX7: бег (кнопка БЕГ / Shift на ПК) — +55% скорости
                                                                if want_run:
                                                                                                                                spd *= 1.55
                                                                return spd

func _run_wanted() -> bool:
                                                                # FIX7v2: тач — двойной тап по стику хода включает БЕГ до отпускания; ПК — Shift
                                                                return (_run_mode and _stick_move_idx >= 0) or (_desktop_input() and Input.is_key_pressed(KEY_SHIFT))

func _player_dead_check() -> bool:
                                                                if in_capsule:
                                                                                                                                return false
                                                                var st: Dictionary = player["st"]
                                                                return st["body"]["torso"] < 0.12 or st["body"]["head"] < 0.12

# ================= ЗОМБИ =================
func _spawn_zombie(kind: String, pos: Vector2) -> void:
                                                                var d: Dictionary = ZDEF[kind]
                                                                var hp: float = float(d["hp"]) * (1.0 + (diff_mult - 1.0) * 0.5)
                                                                var scl := 0.75 if kind != "alpha" else 0.95
                                                                var spr := _mk_spr(d["tex"], pos, scl, 7)
                                                                spr.modulate = Color(1.0, 0.97, 0.95) if kind != "alpha" else Color(1.05, 0.9, 0.9)
                                                                _add_shadow(spr, 0.60, 0.32, 0.22)
                                                                zombies.append({
                                                                                                                                "spr": spr, "kind": kind, "hp": hp, "max_hp": hp,
                                                                                                                                "spd": float(d["spd"]) * diff_mult if kind != "alpha" else float(d["spd"]),
                                                                                                                                "dmg": float(d["dmg"]) * diff_mult,
                                                                                                                                "radius": float(d["radius"]), "notice": float(d["notice"]) * float(G.zdiff_param("notice_k")),
                                                                                                                                "state": "idle", "atk_t": 0.0, "growl_t": randf_range(2.0, 9.0),
                                                                                                                                "wander_t": randf_range(0.0, 3.0), "wander_dir": Vector2.ZERO,
                                                                                                                                "los_t": 0.0, "los_pl": false, "los_al": null,
                                                                                                                                "alive": true, "vel": Vector2.ZERO, "hit_t": 0.0,
                                                                                                                                "walk_t": randf() * TAU, "base_scale": spr.scale,
                                                                                                                                "loot": d["loot"], "alert": false, "aggro": null,
                                                                                                                                "frames": _load_frames(d["tex"]), "idle_tex": G.tex(d["tex"]), "frame_i": -2,
                                                                })

func _zombie_sees(p: Vector2, range_mult := 1.0) -> bool:
                                                                # «зрение» мёртвых: близость или шум; стены блокируют взгляд
                                                                for z in zombies:
                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                continue
                                                                                                                                var d: float = z["spr"].position.distance_to(p)
                                                                                                                                var nm: float = z["notice"] * range_mult * (0.55 if (is_bunker and bool(zp.get("flash_off", false))) else 1.0)
                                                                                                                                if d < nm and _los_clear(z["spr"].position, p):
                                                                                                                                                                                                return true
                                                                return false

func _alert_zombies(pos: Vector2, radius: float) -> void:
                                                                # шум выстрела будит всех в радиусе
                                                                for z in zombies:
                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                continue
                                                                                                                                if z["spr"].position.distance_to(pos) < radius:
                                                                                                                                                                                                z["alert"] = true
                                                                                                                                                                                                z["state"] = "chase"

# ================= СОЮЗНИКИ (НАЁМНЫЕ БОЙЦЫ) =================
func _spawn_ally(squad_member: Dictionary = {}) -> void:
                                                                var idx := allies.size()
                                                                var spr := _mk_spr("z_ally", _player_start() + Vector2(-40 - idx * 34, 30 + idx * 26), 1.05, 8)
                                                                _add_shadow(spr, 0.60, 0.32, 0.22)
                                                                var saved_member := squad_member
                                                                var cs: String = str(saved_member.get("name", ""))
                                                                if cs.is_empty():
                                                                                                                                cs = CALLSIGN_POOL[randi() % CALLSIGN_POOL.size()] + "-" + str(randi() % 9 + 2)
                                                                                                                                saved_member = {"name": cs, "alive": true}
                                                                                                                                G.zsave["squad"].append(saved_member)
                                                                allies.append({
                                                                                                                                "spr": spr, "st": Med.mk_state(), "callsign": cs, "alive": true, "down": false,
                                                                                                                                "squad_member": saved_member,
                                                                                                                                "hp": 130.0, "max_hp": 130.0,
                                                                                                                                "weapon": "smg" if randf() < 0.6 else "rifle",
                                                                                                                                "mag": 30, "mag_max": 30, "reload_t": 0.0, "fire_t": 0.0,
                                                                                                                                "hold": false, "revive_t": 0.0, "self_med_t": randf_range(5.0, 9.0),
                                                                                                                                "slot": idx, "vel": Vector2.ZERO, "stuck_t": 0.0,
                                                                                                                                "walk_t": 0.0, "frames": _load_frames("z_ally"), "idle_tex": G.tex("z_ally"), "frame_i": -2,
                                                                })

func _ally_speed(a: Dictionary) -> float:
                                                                return 138.0 * Med.leg_mult(a)

# ================= ФИЗИКА: КОЛЛИЗИИ И ВИДИМОСТЬ =================
func _collide_circle(pos: Vector2, r: float) -> Vector2:
                                                                # выталкивание из стен и твёрдых пропсов
                                                                var p := pos
                                                                for wr in walls:
                                                                                                                                if p.x > wr.position.x - r and p.x < wr.end.x + r and p.y > wr.position.y - r and p.y < wr.end.y + r:
                                                                                                                                                                                                var cl := Vector2(clampf(p.x, wr.position.x, wr.end.x), clampf(p.y, wr.position.y, wr.end.y))
                                                                                                                                                                                                var d := p - cl
                                                                                                                                                                                                var dl := d.length()
                                                                                                                                                                                                if dl < 0.001:
                                                                                                                                                                                                                                                                var left: float = p.x - wr.position.x
                                                                                                                                                                                                                                                                var right: float = wr.end.x - p.x
                                                                                                                                                                                                                                                                var top: float = p.y - wr.position.y
                                                                                                                                                                                                                                                                var bot: float = wr.end.y - p.y
                                                                                                                                                                                                                                                                var m := minf(minf(left, right), minf(top, bot))
                                                                                                                                                                                                                                                                if m == left:
                                                                                                                                                                                                                                                                                                                                p.x = wr.position.x - r
                                                                                                                                                                                                                                                                elif m == right:
                                                                                                                                                                                                                                                                                                                                p.x = wr.end.x + r
                                                                                                                                                                                                                                                                elif m == top:
                                                                                                                                                                                                                                                                                                                                p.y = wr.position.y - r
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                p.y = wr.end.y + r
                                                                                                                                                                                                elif dl < r:
                                                                                                                                                                                                                                                                p = cl + d.normalized() * r
                                                                for pr in props:
                                                                                                                                if not pr["solid"]:
                                                                                                                                                                                                continue
                                                                                                                                var dd := p - (pr["pos"] as Vector2)
                                                                                                                                var rr: float = pr["radius"] + r
                                                                                                                                if dd.length() < rr and dd.length() > 0.01:
                                                                                                                                                                                                p = (pr["pos"] as Vector2) + dd.normalized() * rr
                                                                p = p.clamp(Vector2(60, 60), map_size - Vector2(60, 60))
                                                                return p

func _los_clear(a: Vector2, b: Vector2) -> bool:
                                                                # сегмент против прямоугольников стен
                                                                for wr in walls:
                                                                                                                                if _seg_rect_hit(a, b, wr):
                                                                                                                                                                                                return false
                                                                # твёрдые высокие пропсы блокируют обзор (дома, деревья)
                                                                for pr in props:
                                                                                                                                if not pr["solid"] or pr["radius"] < 18.0:
                                                                                                                                                                                                continue
                                                                                                                                if _seg_circle_hit(a, b, pr["pos"], pr["radius"]):
                                                                                                                                                                                                return false
                                                                return true

func _seg_rect_hit(a: Vector2, b: Vector2, r: Rect2) -> bool:
                                                                if r.has_point(a) or r.has_point(b):
                                                                                                                                return true
                                                                var hits: Array = [
                                                                                                                                _seg_seg(a, b, r.position, Vector2(r.end.x, r.position.y)),
                                                                                                                                _seg_seg(a, b, Vector2(r.end.x, r.position.y), r.end),
                                                                                                                                _seg_seg(a, b, r.end, Vector2(r.position.x, r.end.y)),
                                                                                                                                _seg_seg(a, b, Vector2(r.position.x, r.end.y), r.position),
                                                                ]
                                                                for h in hits:
                                                                                                                                if h:
                                                                                                                                                                                                return true
                                                                return false

func _seg_seg(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
                                                                var ab := b - a
                                                                var cd := d - c
                                                                var denom := ab.x * cd.y - ab.y * cd.x
                                                                if absf(denom) < 0.0001:
                                                                                                                                return false
                                                                var t := ((c.x - a.x) * cd.y - (c.y - a.y) * cd.x) / denom
                                                                var u := ((c.x - a.x) * ab.y - (c.y - a.y) * ab.x) / denom
                                                                return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func _seg_circle_hit(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
                                                                var ab := b - a
                                                                var l := ab.length()
                                                                if l < 0.001:
                                                                                                                                return a.distance_to(c) < r
                                                                var t := clampf((c - a).dot(ab) / (l * l), 0.0, 1.0)
                                                                var cp := a + ab * t
                                                                return cp.distance_to(c) <= r

func _ray_wall_dist(a: Vector2, dir: Vector2, max_d: float) -> float:
                                                                var b := a + dir * max_d
                                                                var best := max_d
                                                                for wr in walls:
                                                                                                                                if _seg_rect_hit(a, b, wr):
                                                                                                                                                                                                # бинарный поиск точки входа
                                                                                                                                                                                                var lo := 0.0
                                                                                                                                                                                                var hi := max_d
                                                                                                                                                                                                for i in range(9):
                                                                                                                                                                                                                                                                var mid := (lo + hi) * 0.5
                                                                                                                                                                                                                                                                if _seg_rect_hit(a, a + dir * mid, wr):
                                                                                                                                                                                                                                                                                                                                hi = mid
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                lo = mid
                                                                                                                                                                                                best = minf(best, hi)
                                                                return best

# ================= СТРЕЛЬБА ИГРОКА =================
func _fire_player() -> void:
                                                                var wname: String = player["weapon"]
                                                                var wd: Dictionary = G.ZWEAPONS[wname]
                                                                if player["reload_t"] > 0.0:
                                                                                                                                return
                                                                if player["fire_cd"] > 0.0:
                                                                                                                                return
                                                                if int(player["mag"]) <= 0:
                                                                                                                                G.play_sfx("z_dry", -12.0)
                                                                                                                                player["fire_cd"] = 0.3
                                                                                                                                if time_alive - _dry_msg_t > 1.5:
                                                                                                                                        _dry_msg_t = time_alive
                                                                                                                                        _toast("Магазин пуст — ПЕРЕЗАРЯДКА (R / кнопка)")
                                                                                                                                return
                                                                if not bool(wd.get("melee", false)):
                                                                        player["mag"] = int(player["mag"]) - 1
                                                                player["fire_cd"] = float(wd["rof"])
                                                                var aim: float = player["aim"]
                                                                var st: Dictionary = player["st"]
                                                                var sway := (Med.arm_mult({"st": st}) - 1.0) * 0.6
                                                                var right_arm: float = float(st["body"].get("ra", 1.0))
                                                                sway += (1.0 - right_arm) * 0.38
                                                                if st["frac"].has("ra"):
                                                                                                                                sway += 0.28
                                                                if player_velocity.length() > 12.0:
                                                                                                                                sway += 0.06 * clampf(player_velocity.length() / _player_speed(), 0.0, 1.0)
                                                                if player["infect"] > 60.0:
                                                                                                                                sway += 0.05
                                                                var muz: Vector2 = player["spr"].position + Vector2.from_angle(aim) * 16.0
                                                                G.play_sfx(wd["sfx"], -8.0, randf_range(0.94, 1.08))
                                                                flash_fx.append({"pos": muz, "t": 0.06})
                                                                # v2.8: импульс света у дула + гильза (не для ножа)
                                                                if not bool(wd.get("melee", false)):
                                                                        _muzzle_pulse(muz, 1.35 if int(wd["pellets"]) > 1 else 1.0)
                                                                        if q_level > 0:
                                                                                _eject_shell(muz, aim, int(wd["pellets"]) > 1)
                                                                var pellets: int = int(wd["pellets"])
                                                                for pi in range(pellets):
                                                                                                                                var ang := aim + randf_range(-1.0, 1.0) * (float(wd["spr"]) + sway) + (randf_range(-0.04, 0.04) if pellets > 1 else 0.0)
                                                                                                                                var dir := Vector2.from_angle(ang)
                                                                                                                                var rng_w: float = float(wd["rng"])
                                                                                                                                var wall_d := _ray_wall_dist(muz, dir, rng_w)
                                                                                                                                # ближайший зомби на луче
                                                                                                                                var best_z = null
                                                                                                                                var best_d := wall_d
                                                                                                                                for z in zombies:
                                                                                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var to_z: Vector2 = z["spr"].position - muz
                                                                                                                                                                                                var proj := to_z.dot(dir)
                                                                                                                                                                                                if proj <= 0.0 or proj > best_d:
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var perp := absf(to_z.cross(dir))
                                                                                                                                                                                                if perp < float(z["radius"]) + 7.0:
                                                                                                                                                                                                                                                                best_d = proj
                                                                                                                                                                                                                                                                best_z = z
                                                                                                                                var hitp := muz + dir * best_d
                                                                                                                                tracer_fx.append({"a": muz, "b": hitp, "t": 0.07})
                                                                                                                                if best_z != null:
                                                                                                                                                                                                _damage_zombie(best_z, float(wd["dmg"]) * randf_range(0.9, 1.15), dir)
                                                                                                                                                                                                blood_burst.append({"pos": hitp, "t": 0.3, "ang": ang})
                                                                                                                                else:
                                                                                                                                                                                                # искра о стену
                                                                                                                                                                                                _decal(2, hitp, 0.35)
                                                                shake_camera(0.20 if pellets > 1 else 0.11)
                                                                # шум привлекает мёртвых (нож — бесшумный ближний бой)
                                                                if not bool(wd.get("melee", false)):
                                                                                                _alert_zombies(player["spr"].position, 560.0)
                                                                if int(player["mag"]) == 0 and not bool(wd.get("melee", false)):
                                                                                                                                _reload_player()

# ================= v2.8: СОЧНОСТЬ (гильзы / свет выстрела / пыль / лампа / текст) =================
func _muzzle_pulse(pos: Vector2, k: float) -> void:
                                                                if q_level <= 0:
                                                                        return
                                                                if muzzle_light == null:
                                                                        muzzle_light = _flashlight(1.5, 0.0, Color(1.0, 0.85, 0.55))
                                                                        add_child(muzzle_light)
                                                                muzzle_light.position = pos
                                                                muzzle_light.energy = 1.05 * k
                                                                if muzzle_tw != null and muzzle_tw.is_valid():
                                                                        muzzle_tw.kill()
                                                                muzzle_tw = muzzle_light.create_tween()
                                                                muzzle_tw.tween_property(muzzle_light, "energy", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _eject_shell(pos: Vector2, aim: float, big: bool) -> void:
                                                                var perp := aim + PI / 2.0 + randf_range(-0.5, 0.5)
                                                                var spd := randf_range(90.0, 150.0) * (1.25 if big else 1.0)
                                                                shells.append({
                                                                        "pos": pos + Vector2.from_angle(aim) * 4.0,
                                                                        "vel": Vector2.from_angle(perp) * spd,
                                                                        "rot": randf() * TAU, "vr": randf_range(-9.0, 9.0),
                                                                        "t": 0.0, "k": 1.5 if big else 1.0,
                                                                })

func _step_puff() -> void:
                                                                if not is_bunker or q_level <= 0 or not bool(player["spr"].visible):
                                                                        return
                                                                var p := (player["spr"].position as Vector2) + Vector2(randf_range(-5, 5), randf_range(2, 7))
                                                                var puff := CPUParticles2D.new()
                                                                puff.one_shot = true
                                                                puff.emitting = true
                                                                puff.amount = 3
                                                                puff.lifetime = 0.5
                                                                puff.texture = _light_tex()
                                                                puff.spread = 180.0
                                                                puff.initial_velocity_min = 8.0
                                                                puff.initial_velocity_max = 22.0
                                                                puff.gravity = Vector2(0, -6)
                                                                puff.scale_amount_min = 0.12
                                                                puff.scale_amount_max = 0.34
                                                                puff.color = Color(0.62, 0.64, 0.66, 0.14)
                                                                puff.position = p
                                                                puff.z_index = 14
                                                                puff.finished.connect(puff.queue_free)
                                                                fx_layer.add_child(puff)
                                                                if _run_mode and randf() < 0.10:
                                                                        flash_fx.append({"pos": p, "t": 0.08})

func _float_text(wpos: Vector2, txt: String, col: Color) -> void:
                                                                if q_level <= 0:
                                                                        return
                                                                var holder := Node2D.new()
                                                                holder.position = wpos + Vector2(0, -26)
                                                                holder.z_index = 30
                                                                var lb := Label.new()
                                                                lb.text = txt
                                                                lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                                                                lb.custom_minimum_size = Vector2(180, 22)
                                                                lb.position = Vector2(-90, 0)
                                                                lb.add_theme_font_size_override("font_size", 13)
                                                                lb.add_theme_color_override("font_color", col)
                                                                lb.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.03, 0.85))
                                                                lb.add_theme_constant_override("outline_size", 5)
                                                                holder.add_child(lb)
                                                                fx_layer.add_child(holder)
                                                                var tw := holder.create_tween()
                                                                tw.set_parallel(true)
                                                                tw.tween_property(holder, "position:y", holder.position.y - 30.0, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                                                                tw.tween_property(holder, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                                                                tw.chain().tween_callback(holder.queue_free)

func _dying_lamp(hint: Vector2) -> void:
                                                                if bench.has("glow"):
                                                                        return
                                                                var wp := _wall_point(hint)
                                                                var s := _mk_spr("z_wallamp", wp["pos"], 1.2, 7, Color(0.94, 1.0, 1.0))
                                                                s.rotation = wp["rot"]
                                                                var gpos: Vector2 = wp["pos"] + (wp["in"] as Vector2) * 140.0
                                                                var g := _glow(gpos, 2.6, Color(0.85, 0.96, 1.0), 0.26)
                                                                # световое пятно на полу — спрайт под пропами и телами (в floor_node)
                                                                var pool := Sprite2D.new()
                                                                pool.texture = _light_tex()
                                                                pool.position = gpos
                                                                pool.scale = Vector2(4.4, 4.4)
                                                                pool.modulate = Color(0.72, 0.86, 1.0, 0.26)
                                                                pool.z_index = 1
                                                                floor_node.add_child(pool)
                                                                dying_lamps.append({"spr": g, "wall": s, "pool": pool, "cd": randf_range(7.0, 15.0)})


func _reload_player() -> void:
                                                                var wname: String = player["weapon"]
                                                                var wd: Dictionary = G.ZWEAPONS[wname]
                                                                if bool(wd.get("melee", false)):
                                                                                                return
                                                                if player["reload_t"] > 0.0 or int(player["mag"]) >= int(wd["mag"]):
                                                                                                                                return
                                                                var reserve: int = int(G.zsave["ammo"].get(wname, 0))
                                                                if reserve <= 0:
                                                                                                                                if time_alive - _dry_msg_t > 1.5:
                                                                                                                                        _dry_msg_t = time_alive
                                                                                                                                        _toast("Нет патронов к «%s»" % G.Z_WEAPON_NAMES.get(wname, wname))
                                                                                                                                return
                                                                var right_arm: float = float(player["st"]["body"].get("ra", 1.0))
                                                                var reload_penalty := (1.0 - right_arm) * 0.45
                                                                if player["st"]["frac"].has("ra"):
                                                                                                reload_penalty += 0.35
                                                                player["reload_t"] = float(wd["reload"]) * (1.0 + reload_penalty)
                                                                G.play_sfx("z_reload", -10.0)
                                                                G.play_sfx("z_voice_effort", -14.0, randf_range(0.96, 1.04))

func _finish_reload() -> void:
                                                                var wname: String = player["weapon"]
                                                                var wd: Dictionary = G.ZWEAPONS[wname]
                                                                var need: int = int(wd["mag"]) - int(player["mag"])
                                                                var take: int = mini(need, int(G.zsave["ammo"].get(wname, 0)))
                                                                G.zsave["ammo"][wname] = int(G.zsave["ammo"].get(wname, 0)) - take
                                                                player["mag"] = int(player["mag"]) + take
                                                                G.play_sfx("z_dry", -14.0, 1.3)

func _damage_zombie(z: Dictionary, dmg: float, dir: Vector2) -> void:
                                                                z["hp"] = float(z["hp"]) - dmg
                                                                z["hit_t"] = 0.12
                                                                z["spr"].modulate = Color(1.6, 0.8, 0.8)
                                                                _blood_spray(z["spr"].position, dir)
                                                                if z["state"] == "idle":
                                                                                                                                z["state"] = "chase"
                                                                                                                                z["alert"] = true
                                                                # отброс
                                                                z["spr"].position += dir * (6.0 if z["kind"] != "brute" and z["kind"] != "alpha" else 2.0)
                                                                if float(z["hp"]) <= 0.0:
                                                                                                                                _kill_zombie(z)

func _blood_spray(pos: Vector2, direction: Vector2) -> void:
                                                                for i in range(blood_sprays.size() - 1, -1, -1):
                                                                                                                                if not is_instance_valid(blood_sprays[i]):
                                                                                                                                                                                                blood_sprays.remove_at(i)
                                                                if blood_sprays.size() >= 12:
                                                                                                                                return
                                                                var spray := CPUParticles2D.new()
                                                                spray.amount = 7
                                                                spray.lifetime = 0.34
                                                                spray.one_shot = true
                                                                spray.explosiveness = 0.92
                                                                spray.texture = _light_tex()
                                                                spray.direction = direction.normalized() if direction.length() > 0.01 else Vector2.UP
                                                                spray.spread = 68.0
                                                                spray.initial_velocity_min = 38.0
                                                                spray.initial_velocity_max = 112.0
                                                                spray.gravity = Vector2(0.0, 90.0)
                                                                spray.scale_amount_min = 0.06
                                                                spray.scale_amount_max = 0.14
                                                                spray.color = Color(0.62, 0.08, 0.055, 0.82)
                                                                spray.position = pos
                                                                spray.z_index = 24
                                                                fx_layer.add_child(spray)
                                                                blood_sprays.append(spray)
                                                                spray.finished.connect(spray.queue_free)
                                                                spray.emitting = true

func _kill_zombie(z: Dictionary) -> void:
                                                                z["alive"] = false
                                                                kills += 1
                                                                _blood_pool(z["spr"].position, z["kind"] == "brute" or z["kind"] == "alpha")
                                                                # FIX11: лёгкий толчок камеры, если погиб рядом
                                                                if (z["spr"].position as Vector2).distance_to(player["spr"].position) < 320.0:
                                                                                                                                shake_camera(0.16)
                                                                var spr: Sprite2D = z["spr"]
                                                                corpses.append({
                                                                                                                                "spr": spr, "kind": "zmb", "searched": false,
                                                                                                                                "pos": spr.position, "loot": z["loot"],
                                                                })
                                                                spr.z_index = 2
                                                                spr.rotation = randf() * TAU
                                                                spr.modulate = Color(0.72, 0.66, 0.66)
                                                                G.play_sfx("z_hit", -6.0, randf_range(0.8, 1.1))
                                                                # FIX11: короткий «поп» тела при гибели — смерть читается телом
                                                                if z.has("base_scale"):
                                                                                var pop := spr.create_tween()
                                                                                spr.scale = (z["base_scale"] as Vector2) * 1.22
                                                                                pop.tween_property(spr, "scale", z["base_scale"], 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
                                                                # счётчики задач
                                                                if mission == "clear":
                                                                                                                                zone_count += 1
                                                                                                                                _upd_obj_text("main", "Зачистить сектор от мёртвых (%d/%d)" % [zone_count, zone_total])
                                                                                                                                if zone_count >= zone_total:
                                                                                                                                                                                                _complete_objective("main")
                                                                                                                                                                                                _open_extraction()
                                                                elif mission == "warehouse" and z.get("zcount", false):
                                                                                                                                zone_count += 1
                                                                                                                                _upd_obj_text("main", "Зачистить склад (%d/%d)" % [zone_count, zone_total])
                                                                                                                                if zone_count >= zone_total:
                                                                                                                                                                                                _complete_objective("main")
                                                                                                                                                                                                _open_extraction()
                                                                elif mission == "final" and z["kind"] == "alpha":
                                                                                                                                _complete_objective("main")
                                                                                                                                _open_extraction()
                                                                                                                                _toast("АЛЬФА ПОВЕРЖЕНА! Уходите через эвакуацию!")
                                                                if is_bunker and z["kind"] == "sci":
                                                                                                                                _check_bunker_corridor()

# ================= УРОН ИГРОКУ/СОЮЗНИКАМ =================
                                                                # ---------- ПЛАВНАЯ ВИНЬЕТКА УРОНА (ТЗ п.11) ----------
                                                                # Эффект быстро (но мягко) поднимается до силы, пропорциональной повреждению,
                                                                # затем плавно гаснет. Повторные уроны не накапливаются бесконечно (макс 1.0).
func _hit_vignette(severity: float) -> void:
                                                                vignette_dmg_tgt = clampf(maxf(vignette_dmg_tgt, severity), 0.0, 1.0)
                                                                if vignette_dmg < vignette_dmg_tgt:
                                                                                                                                vignette_dmg = maxf(vignette_dmg, severity * 0.30)   # мягкий старт без резкой вспышки

# FIX11: мягкая тряска камеры — сила 0..1, гаснет сама (в _process)
func shake_camera(power: float) -> void:
                                                                _cam_shake = clampf(maxf(_cam_shake, power), 0.0, 1.0)

func _bite_target(target: Dictionary, _dmg: float, is_player: bool, from_pos := Vector2.ZERO) -> void:
                                                                # укус: урон по зоне + шанс кровотечения (через Med) + заражение игроку
                                                                Med.hit_soldier(target, false)
                                                                G.play_sfx("z_bite", -4.0, randf_range(0.9, 1.1))
                                                                if is_player:
                                                                                                                                G.play_sfx("z_voice_hurt", -10.0, randf_range(0.94, 1.06))
                                                                                                                                _hit_vignette(1.0)
                                                                                                                                # FIX11: индикатор направления удара + толчок камеры
                                                                                                                                if from_pos != Vector2.ZERO:
                                                                                                                                        hit_dir_ang = (from_pos - (player["spr"].position as Vector2)).angle()
                                                                                                                                        hit_dir_t = 1.0
                                                                                                                                shake_camera(0.42)
                                                                                                                                if randf() < 0.42:
                                                                                                                                                                                                player["infect"] = minf(100.0, float(player["infect"]) + randf_range(13.0, 22.0))
                                                                                                                                                                                                G.play_sfx("z_infect", -8.0)
                                                                                                                                                                                                _log("Заражение усиливается: штамм «Заря» %d%%" % int(player["infect"]), Color(0.75, 0.9, 0.55), "ШТАММ")
                                                                                                                                add_log_body("Укус! " + Med.status_str({"st": player["st"]}), Color(0.95, 0.6, 0.5))
                                                                else:
                                                                                                                                add_log_body("%s: укучен! %s" % [target.get("callsign", "?"), Med.status_str(target)], Color(0.95, 0.6, 0.5))

func _player_tick_med(delta: float) -> void:
                                                                var st: Dictionary = player["st"]
                                                                # кровопотеря по ранам
                                                                for w in st["wounds"]:
                                                                                                                                if w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                                                                                                                                                                                                st["body"][w["zone"]] = maxf(0.05, float(st["body"][w["zone"]]) - float(w["bleed"]) * delta * 0.010)
                                                                                                                                                                                                if randf() < delta * 1.4:
                                                                                                                                                                                                                                                                _decal([3, 5][randi() % 2], player["spr"].position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.35 + randf() * 0.25)
                                                                # заражение
                                                                if player["infect"] > 0.0:
                                                                                                                                var g := delta * 0.55 * diff_mult
                                                                                                                                if player["infect"] >= 100.0:
                                                                                                                                                                                                # штамм побеждает: периодические судороги
                                                                                                                                                                                                player["down_msg_t"] -= delta
                                                                                                                                                                                                if player["down_msg_t"] <= 0.0:
                                                                                                                                                                                                                                                                player["down_msg_t"] = 7.0
                                                                                                                                                                                                                                                                var z: String = Med.worst_zone({"st": st})
                                                                                                                                                                                                                                                                st["body"][z] = maxf(0.05, float(st["body"][z]) - 0.16)
                                                                                                                                                                                                                                                                G.play_sfx("z_infect", -6.0)
                                                                                                                                                                                                                                                                _hit_vignette(0.55)
                                                                                                                                                                                                                                                                _toast("ШТАММ РАЗРУШАЕТ ТЕЛО — нужен АНТИБИОТИК!")
                                                                                                                                else:
                                                                                                                                                                                                player["infect"] = maxf(0.0, float(player["infect"]) - g * 0.25)   # организм борется
                                                                                                                                                                                                player["infect"] = minf(100.0, float(player["infect"]) + g)
                                                                Med.tick({"st": st}, delta, _near_danger(player["spr"].position))
                                                                if _player_dead_check():
                                                                                                                                _lose()

func _near_danger(p: Vector2) -> bool:
                                                                for z in zombies:
                                                                                                                                if z["alive"] and z["spr"].position.distance_to(p) < 260.0:
                                                                                                                                                                                                return true
                                                                return false

# ================= ОБЫСК И ЛУТ =================
func _roll_loot(table: Array) -> Array:
                                                                var res: Array = []
                                                                for entry in table:
                                                                                                                                var item: String = entry[0]
                                                                                                                                var chance: float = float(entry[1])
                                                                                                                                if randf() < chance:
                                                                                                                                                                                                res.append(item)
                                                                return res

func _spawn_corpse(kind: String, pos: Vector2) -> void:
                                                                var texn := "z_player" if kind == "v18" else "z_corpse_" + kind
                                                                var spr := _mk_spr(texn, pos, 1.15, 2)
                                                                _add_shadow(spr, 0.82, 0.46, 0.28)
                                                                spr.rotation = randf() * TAU
                                                                # FIX11: у V-18 фиксированный разворот, случайный перебивал его
                                                                if kind == "v18":
                                                                                                spr.modulate = Color(0.82, 0.86, 0.9)
                                                                                                spr.rotation = PI * 0.5
                                                                var loot_table: Array = [["watch", 0.5], ["chip", 0.3], ["ammo", 0.35], ["meds", 0.3], ["docs", 0.25]]
                                                                if kind == "guard":
                                                                                                                                loot_table = [["ammo", 0.6], ["meds", 0.4], ["docs", 0.3], ["band", 0.5]]
                                                                corpses.append({"spr": spr, "kind": kind, "searched": false, "pos": pos, "loot": loot_table, "bonus": []})

func _search_corpse(corpse: Dictionary) -> void:
                                                                if not corpse.has("loot_items"):
                                                                                                                                var items := _roll_loot(corpse["loot"])
                                                                                                                                if corpse["kind"] == "guard" and is_bunker:
                                                                                                                                                                                                items.append("keycard")
                                                                                                                                for bi in corpse.get("bonus", []):
                                                                                                                                        if str(bi) == "doctor_note":
                                                                                                                                                zp["med_pass"] = true
                                                                                                                                                _toast("Записка врача: пароль терминала — строка из диктофона.")
                                                                                                                                        else:
                                                                                                                                                items.append(str(bi))
                                                                                                                                corpse["loot_items"] = items
                                                                                                                                corpse["searched"] = true
                                                                                                                                looted_bodies += 1
                                                                _open_loot_window("ОБЫСК: " + str(corpse["kind"]).to_upper(), corpse)

func _receive_item(item: String, n: int) -> void:
                                                                match item:
                                                                                                                                "band", "tq", "splint", "morph", "abx", "food":
                                                                                                                                                                                                G.z_give_item(item, n)
                                                                                                                                "mag_pistol", "mag_smg", "mag_shotgun", "mag_rifle":
                                                                                                                                                                                                var wmap := {"mag_pistol": "pistol", "mag_smg": "smg", "mag_shotgun": "shotgun", "mag_rifle": "rifle"}
                                                                                                                                                                                                var w: String = wmap[item]
                                                                                                                                                                                                var per: int = int(G.ZWEAPONS[w]["mag"])
                                                                                                                                                                                                G.zsave["ammo"][w] = int(G.zsave["ammo"].get(w, 0)) + per * n
                                                                                                                                "keycard":
                                                                                                                                                                                                G.z_give_item("keycard", n)
                                                                                                                                _:
                                                                                                                                                                                                # хабар
                                                                                                                                                                                                G.z_give_item(item, n)

func _take_tablet(prop: Dictionary) -> void:
                                                                tablets_left -= 1
                                                                G.play_sfx("z_pickup", -6.0)
                                                                _log("Планшет с данными найден! Осталось: %d" % maxi(0, tablets_left), Color(0.85, 0.88, 0.6), "СИСТЕМА")
                                                                _upd_obj_text("main", "Найти планшеты с данными (осталось %d)" % maxi(0, tablets_left))
                                                                if tablets_left <= 0:
                                                                                                                                _complete_objective("main")
                                                                                                                                _open_extraction()
                                                                if prop.has("spr") and is_instance_valid(prop["spr"]):
                                                                                                                                (prop["spr"] as Sprite2D).queue_free()
                                                                                                                                props.erase(prop)

func _open_loot_crate(prop: Dictionary) -> void:
                                                                if not prop.has("loot_items"):
                                                                                                                                prop["loot_items"] = _roll_loot([["ammo", 0.6], ["meds", 0.5], ["band", 0.5], ["food", 0.4], ["chip", 0.3]])
                                                                                                                                if prop["loot_items"].is_empty():
                                                                                                                                                                                                prop["loot_items"] = ["band"]
                                                                                                                                for bi in prop.get("bonus", []):
                                                                                                                                        if not prop["loot_items"].has(str(bi)):
                                                                                                                                                prop["loot_items"].append(str(bi))
                                                                                                                                prop["kind"] = "crate_used"
                                                                                                                                if prop.has("spr") and is_instance_valid(prop["spr"]):
                                                                                                                                                                                                (prop["spr"] as Sprite2D).modulate = Color(0.7, 0.65, 0.6)
                                                                _open_loot_window("ОБЫСК: ЯЩИК", prop)

func _open_loot_window(title: String, source: Dictionary) -> void:
                                                                if loot_win != null and is_instance_valid(loot_win):
                                                                                                                                return
                                                                paused = true
                                                                loot_source = source
                                                                var w := ZUI.open_window(ui_layer, title, Vector2(620, 0))
                                                                loot_win = w["overlay"]
                                                                loot_win.tree_exiting.connect(_loot_closed)
                                                                var vb: VBoxContainer = w["vb"]
                                                                loot_content_vb = vb
                                                                var head := HBoxContainer.new()
                                                                head.add_theme_constant_override("separation", 8)
                                                                var bag_ic := ZUI.icon_rect("bag", 18, ZUI.NEON)
                                                                bag_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                                                                head.add_child(bag_ic)
                                                                var status := ZUI.label("ПЕРЕТАЩИТЕ ПРЕДМЕТЫ В РЮКЗАК (или нажмите ВЗЯТЬ)", 12, ZUI.MUTED)
                                                                head.add_child(status)
                                                                vb.add_child(head)
                                                                vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                _render_loot_rows(vb)
                                                                vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                vb.add_child(ZUI.label("ВАШ РЮКЗАК", 12, ZUI.NEON_BRIGHT))
                                                                loot_inventory_lbl = ZUI.wrap_label(_inventory_summary(), 12, ZUI.TEXT, 520.0)
                                                                vb.add_child(loot_inventory_lbl)

func _inventory_summary() -> String:
                                                                var entries: Array[String] = []
                                                                for item in G.zsave["inv"]:
                                                                                                                                var count := int(G.zsave["inv"][item])
                                                                                                                                if count <= 0:
                                                                                                                                                                                                continue
                                                                                                                                entries.append("%s ×%d" % [_inventory_item_name(item), count])
                                                                return ", ".join(entries) if not entries.is_empty() else "Пока пусто"

func _inventory_item_name(item: String) -> String:
                                                                if G.ZITEMS.has(item):
                                                                                                                                return str(G.ZITEMS[item]["name"])
                                                                if G.ZLOOT.has(item):
                                                                                                                                return str(G.ZLOOT[item]["name"])
                                                                if item == "keycard":
                                                                                                                                return "КЛЮЧ-КАРТА ШЛЮЗА"
                                                                return item.to_upper()

func _render_loot_rows(parent: VBoxContainer) -> void:
                                                                for child in parent.get_children():
                                                                                                                                if child.has_meta("loot_rows"):
                                                                                                                                                                                                child.queue_free()
                                                                var rows := VBoxContainer.new()
                                                                rows.set_meta("loot_rows", true)
                                                                rows.add_theme_constant_override("separation", 6)
                                                                parent.add_child(rows)
                                                                var counts := {}
                                                                for item in loot_source.get("loot_items", []):
                                                                                                                                counts[item] = int(counts.get(item, 0)) + 1
                                                                if counts.is_empty():
                                                                                                                                rows.add_child(ZUI.label("Контейнер пуст.", 14, ZUI.FAINT))
                                                                                                                                return
                                                                for item in counts:
                                                                                                                                var row := ZMed.LootRow.new(str(item), int(counts[item]))
                                                                                                                                row.btl = self
                                                                                                                                rows.add_child(row)

func _take_loot_item(item: String) -> void:
                                                                var items: Array = loot_source.get("loot_items", [])
                                                                var index := items.find(item)
                                                                if index < 0:
                                                                                                                                return
                                                                items.remove_at(index)
                                                                loot_source["loot_items"] = items
                                                                _receive_item(item, 1)
                                                                if item == "keycard":
                                                                                                                                _complete_objective("guard")
                                                                                                                                _log("Ключ-карта технического шлюза — в рюкзаке.", Color(0.95, 0.85, 0.5), "СИСТЕМА")
                                                                                                                                if tut != null:
                                                                                                                                                                                                tut.hint("scanner_go", "keycard", "КАРТА ПОЛУЧЕНА", "Теперь подойдите к сканеру-считывателю у шлюза и приложите карту — терминал подтвердит личность и снимет блокировку.", 78)
                                                                G.write_save()
                                                                G.play_sfx("z_pickup", -8.0)
                                                                # v2.8: название предмета всплывает в мире над источником
                                                                var iname := ""
                                                                if G.ZITEMS.has(item):
                                                                        iname = str(G.ZITEMS[item]["name"])
                                                                elif G.ZLOOT.has(item):
                                                                        iname = str(G.ZLOOT[item]["name"])
                                                                else:
                                                                        iname = item.to_upper()
                                                                _float_text(loot_source.get("pos", player["spr"].position), "+ " + iname, Color(0.75, 0.9, 0.8))
                                                                if loot_win != null and is_instance_valid(loot_win) and loot_content_vb != null and is_instance_valid(loot_content_vb):
                                                                                                                                _render_loot_rows(loot_content_vb)
                                                                                                                                if loot_inventory_lbl != null and is_instance_valid(loot_inventory_lbl):
                                                                                                                                                                                                loot_inventory_lbl.text = _inventory_summary()
                                                                                                                                                                                                # v2.8: подсветка строки инвентаря — видно, что предмет ушёл в рюкзак
                                                                                                                                                                                                var fl_tw := loot_inventory_lbl.create_tween()
                                                                                                                                                                                                fl_tw.tween_property(loot_inventory_lbl, "self_modulate", Color(0.65, 1.0, 0.8), 0.08)
                                                                                                                                                                                                fl_tw.tween_property(loot_inventory_lbl, "self_modulate", Color(1, 1, 1), 0.55)

func _loot_closed() -> void:
                                                                loot_win = null
                                                                loot_source = {}
                                                                loot_inventory_lbl = null
                                                                loot_content_vb = null
                                                                paused = false

# ================= ТИКИ СУЩНОСТЕЙ =================
func _tick_zombies(delta: float) -> void:
                                                                var pp: Vector2 = player["spr"].position
                                                                var player_valid: bool = player["alive"] and (not is_bunker or player["spr"].visible)
                                                                for z in zombies:
                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                continue
                                                                                                                                var zp: Vector2 = z["spr"].position
                                                                                                                                # FIX5: LOD на минималках — далёкие неагрессивные зомби не тикают
                                                                                                                                if q_level <= 0 and not bool(z["alert"]) and zp.distance_to(pp) > 1100.0:
                                                                                                                                                                                                continue
                                                                                                                                # рычание
                                                                                                                                z["growl_t"] = float(z["growl_t"]) - delta
                                                                                                                                if float(z["growl_t"]) <= 0.0:
                                                                                                                                                                                                z["growl_t"] = randf_range(3.5, 10.0)
                                                                                                                                                                                                var dist_p: float = zp.distance_to(pp)
                                                                                                                                                                                                if dist_p < 900.0:
                                                                                                                                                                                                                                                                var gn: String = ["z_growl", "z_growl2", "z_growl3"][randi() % 3]
                                                                                                                                                                                                                                                                G.play_sfx(gn, clampf(-30.0 + (900.0 - dist_p) * 0.028, -30.0, -8.0), randf_range(0.85, 1.15))
                                                                                                                                # v2.8: таймер «пробуждения» + дрожь тела
                                                                                                                                if float(z.get("wake_t", 0.0)) > 0.0:
                                                                                                                                        z["wake_t"] = float(z["wake_t"]) - delta
                                                                                                                                        (z["spr"] as Sprite2D).offset = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
                                                                                                                                elif (z["spr"] as Sprite2D).offset != Vector2.ZERO:
                                                                                                                                        (z["spr"] as Sprite2D).offset = Vector2.ZERO
                                                                                                                                if z["hit_t"] > 0.0:
                                                                                                                                                                                                z["hit_t"] = float(z["hit_t"]) - delta
                                                                                                                                                                                                if float(z["hit_t"]) <= 0.0:
                                                                                                                                                                                                                                                                z["spr"].modulate = Color(1.0, 0.97, 0.95)
                                                                                                                                # выбор цели: игрок или союзник; LOS кэшируется ~7 раз/сек (ФПС)
                                                                                                                                var tgt_pos := Vector2.ZERO
                                                                                                                                var tgt_is_player := true
                                                                                                                                var found := false
                                                                                                                                z["los_t"] = float(z["los_t"]) - delta
                                                                                                                                if float(z["los_t"]) <= 0.0:
                                                                                                                                                                                                z["los_t"] = 0.13 + randf() * 0.07
                                                                                                                                                                                                z["los_pl"] = player_valid and zp.distance_to(pp) < float(z["notice"]) and _los_clear(zp, pp)
                                                                                                                                                                                                z["los_al"] = null
                                                                                                                                                                                                if not z["los_pl"]:
                                                                                                                                                                                                                                                                for a in allies:
                                                                                                                                                                                                                                                                                                                                if not a["alive"] or a["down"]:
                                                                                                                                                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                                                                                                                                                if zp.distance_to(a["spr"].position) < float(z["notice"]) and _los_clear(zp, a["spr"].position):
                                                                                                                                                                                                                                                                                                                                                                                                z["los_al"] = a
                                                                                                                                                                                                                                                                                                                                                                                                break
                                                                                                                                if player_valid and z["los_pl"]:
                                                                                                                                                                                                tgt_pos = pp
                                                                                                                                                                                                found = true
                                                                                                                                elif z["los_al"] != null:
                                                                                                                                                                                                tgt_pos = z["los_al"]["spr"].position
                                                                                                                                                                                                tgt_is_player = false
                                                                                                                                                                                                found = true
                                                                                                                                if found:
                                                                                                                                                                                                z["state"] = "chase"
                                                                                                                                                                                                # v2.8: «пробуждение» — зомби замирает с шипением, прежде чем ринуться
                                                                                                                                                                                                if str(z.get("state", "")) == "idle" and float(z.get("wake_t", 0.0)) <= 0.0 and not bool(z.get("wake_done", false)):
                                                                                                                                                                                                        z["wake_t"] = randf_range(0.26, 0.4)
                                                                                                                                                                                                        z["wake_done"] = true
                                                                                                                                                                                                        G.play_sfx("z_hiss", clampf(-22.0 + (760.0 - zp.distance_to(pp)) * 0.02, -22.0, -6.0), randf_range(0.9, 1.1))
                                                                                                                                                                                                z["alert"] = true
                                                                                                                                elif z["alert"] and z["state"] == "chase":
                                                                                                                                                                                                # потеряли цель — идём к последней позиции игрока
                                                                                                                                                                                                tgt_pos = pp
                                                                                                                                                                                                tgt_is_player = true
                                                                                                                                                                                                found = true
                                                                                                                                var move := Vector2.ZERO
                                                                                                                                if found:
                                                                                                                                                                                                var dd := zp.distance_to(tgt_pos)
                                                                                                                                                                                                if dd > 30.0:
                                                                                                                                                                                                                                                                move = (tgt_pos - zp).normalized()
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                # атака: замах и укус
                                                                                                                                                                                                                                                                if float(z["atk_t"]) <= 0.0:
                                                                                                                                                                                                                                                                                                                                z["atk_t"] = 0.55
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                z["atk_t"] = float(z["atk_t"]) - delta
                                                                                                                                                                                                                                                                                                                                if float(z["atk_t"]) <= 0.0:
                                                                                                                                                                                                                                                                                                                                                                                                if zp.distance_to(tgt_pos) < 46.0:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                if tgt_is_player and player_valid:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                _bite_target(player, float(z["dmg"]), true, zp)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                elif not tgt_is_player:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                for a in allies:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                if a["alive"] and not a["down"] and (a["spr"].position as Vector2).distance_to(zp) < 46.0:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                _bite_target(a, float(z["dmg"]), false)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                break
                                                                                                                                else:
                                                                                                                                                                                                # блуждание
                                                                                                                                                                                                z["wander_t"] = float(z["wander_t"]) - delta
                                                                                                                                                                                                if float(z["wander_t"]) <= 0.0:
                                                                                                                                                                                                                                                                z["wander_t"] = randf_range(2.0, 5.5)
                                                                                                                                                                                                                                                                z["wander_dir"] = Vector2.from_angle(randf() * TAU) * (0.4 if randf() < 0.6 else 0.0)
                                                                                                                                                                                                move = z["wander_dir"]
                                                                                                                                # расталкивание зомби (FIX5: через кадр — экономия CPU, O(n^2)/2)
                                                                                                                                if _frame_i % 2 == 0:
                                                                                                                                                                                                for z2 in zombies:
                                                                                                                                                                                                                                                                if z2 == z or not z2["alive"]:
                                                                                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                                                                                var dv: Vector2 = zp - (z2["spr"].position as Vector2)
                                                                                                                                                                                                                                                                var dl := dv.length()
                                                                                                                                                                                                                                                                var min_d: float = float(z["radius"]) + float(z2["radius"])
                                                                                                                                                                                                                                                                if dl < min_d and dl > 0.01:
                                                                                                                                                                                                                                                                                                                                move += dv.normalized() * (1.0 - dl / min_d) * 1.4
                                                                                                                                # v2.8: во время «пробуждения» зомби не двигается
                                                                                                                                if float(z.get("wake_t", 0.0)) > 0.0:
                                                                                                                                        move = Vector2.ZERO
                                                                                                                                if move.length() > 0.01:
                                                                                                                                                                                                # FIX5: шаткая походка — темп дышит (рывки), как у мертвеца
                                                                                                                                                                                                var lurch := 1.0 + 0.20 * sin(float(z["walk_t"]) * 0.55)
                                                                                                                                                                                                var spd: float = float(z["spd"]) * lurch
                                                                                                                                                                                                var np := zp + move.normalized() * spd * delta
                                                                                                                                                                                                np = _collide_circle(np, float(z["radius"]))
                                                                                                                                                                                                z["spr"].position = np
                                                                                                                                                                                                z["walk_t"] = float(z["walk_t"]) + delta * (7.5 if spd > 60.0 else 4.5)
                                                                                                                                                                                                # анимация ходьбы: 4 кадра шаткой походки
                                                                                                                                                                                                var zfi := int(float(z["walk_t"]) / (PI * 0.5)) % 4
                                                                                                                                                                                                if int(z["frame_i"]) != zfi and not z["frames"].is_empty():
                                                                                                                                                                                                                                                                z["frame_i"] = zfi
                                                                                                                                                                                                                                                                z["spr"].texture = z["frames"][zfi]
                                                                                                                                                                                                var stride := sin(float(z["walk_t"])) * 0.035
                                                                                                                                                                                                var base_scale: Vector2 = z["base_scale"]
                                                                                                                                                                                                z["spr"].scale = Vector2(base_scale.x * (1.0 + stride), base_scale.y * (1.0 - stride))
                                                                                                                                                                                                # FIX5: корпус заваливается из стороны в сторону (брут — сильнее)
                                                                                                                                                                                                var zk: float = 1.45 if z["kind"] == "brute" or z["kind"] == "alpha" else 1.0
                                                                                                                                                                                                z["spr"].offset = Vector2(sin(float(z["walk_t"]) * 2.0) * 1.6 * zk, sin(float(z["walk_t"])) * 2.9 * zk)
                                                                                                                                                                                                # FIX-3/FIX5: смотрим туда, куда идём (плавный доворот + шатание)
                                                                                                                                                                                                if move.length() > 0.05:
                                                                                                                                                                                                                                                                z["spr"].rotation = lerp_angle(z["spr"].rotation, move.angle(), minf(1.0, 10.0 * delta)) + sin(float(z["walk_t"]) * 0.5) * 0.055
                                                                                                                                else:
                                                                                                                                                                                                # стоит — кадр покоя, корпус ровно
                                                                                                                                                                                                z["spr"].offset = Vector2.ZERO
                                                                                                                                                                                                if int(z["frame_i"]) != -1:
                                                                                                                                                                                                                                                                z["frame_i"] = -1
                                                                                                                                                                                                                                                                if z["idle_tex"] != null:
                                                                                                                                                                                                                                                                                                                                z["spr"].texture = z["idle_tex"]
func _tick_allies(delta: float) -> void:
                                                                var pp: Vector2 = player["spr"].position
                                                                for a in allies:
                                                                                                                                if not a["alive"]:
                                                                                                                                                                                                continue
                                                                                                                                var st: Dictionary = a["st"]
                                                                                                                                if a["down"]:
                                                                                                                                                                                                # ждём оживления
                                                                                                                                                                                                a["spr"].rotation = PI / 2.0
                                                                                                                                                                                                continue
                                                                                                                                # само-перевязка вне боя
                                                                                                                                var danger := _near_danger(a["spr"].position)
                                                                                                                                if not danger:
                                                                                                                                                                                                a["self_med_t"] = float(a["self_med_t"]) - delta
                                                                                                                                                                                                if float(a["self_med_t"]) <= 0.0:
                                                                                                                                                                                                                                                                a["self_med_t"] = randf_range(5.0, 9.0)
                                                                                                                                                                                                                                                                var wi: String = Med.worst_item(a)
                                                                                                                                                                                                                                                                if wi != "":
                                                                                                                                                                                                                                                                                                                                var res: String = Med.treat(a, wi)
                                                                                                                                                                                                                                                                                                                                if res == "":
                                                                                                                                                                                                                                                                                                                                                                                                add_log_body("%s перевязался: %s" % [a["callsign"], Med.status_str(a)], Color(0.65, 0.8, 0.6))
                                                                                                                                Med.tick(a, delta, danger)
                                                                                                                                # тяжёлое состояние
                                                                                                                                if st["body"]["torso"] < 0.30 or st["body"]["head"] < 0.30:
                                                                                                                                                                                                a["down"] = true
                                                                                                                                                                                                add_log_body("%s тяжело ранен — подойдите и ОЖИВИТЕ!" % a["callsign"], Color(0.95, 0.6, 0.4))
                                                                                                                                                                                                continue
                                                                                                                                # огонь по зомби
                                                                                                                                a["fire_t"] = float(a["fire_t"]) - delta
                                                                                                                                if a["reload_t"] > 0.0:
                                                                                                                                                                                                a["reload_t"] = float(a["reload_t"]) - delta
                                                                                                                                                                                                if float(a["reload_t"]) <= 0.0:
                                                                                                                                                                                                                                                                a["mag"] = int(a["mag_max"])
                                                                                                                                else:
                                                                                                                                                                                                var best_z = null
                                                                                                                                                                                                var best_d := 420.0
                                                                                                                                                                                                for z in zombies:
                                                                                                                                                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                                                                                var zp: Vector2 = z["spr"].position
                                                                                                                                                                                                                                                                var dd := (a["spr"].position as Vector2).distance_to(zp)
                                                                                                                                                                                                                                                                if dd < best_d and _los_clear(a["spr"].position, zp):
                                                                                                                                                                                                                                                                                                                                best_d = dd
                                                                                                                                                                                                                                                                                                                                best_z = z
                                                                                                                                                                                                if best_z != null:
                                                                                                                                                                                                                                                                var ang: float = ((best_z["spr"].position as Vector2) - (a["spr"].position as Vector2)).angle()
                                                                                                                                                                                                                                                                a["spr"].rotation = ang
                                                                                                                                                                                                                                                                if float(a["fire_t"]) <= 0.0:
                                                                                                                                                                                                                                                                                                                                a["fire_t"] = 0.14
                                                                                                                                                                                                                                                                                                                                a["mag"] = int(a["mag"]) - 1
                                                                                                                                                                                                                                                                                                                                G.play_sfx("z_shot_rifle" if str(a.get("weapon", "smg")) == "rifle" else "z_shot_smg", clampf(-26.0 + (420.0 - best_d) * 0.03, -26.0, -10.0), randf_range(0.9, 1.1))
                                                                                                                                                                                                                                                                                                                                var muz: Vector2 = (a["spr"].position as Vector2) + Vector2.from_angle(ang) * 14.0
                                                                                                                                                                                                                                                                                                                                var dir := Vector2.from_angle(ang + randf_range(-0.08, 0.08))
                                                                                                                                                                                                                                                                                                                                var wd2 := _ray_wall_dist(muz, dir, 420.0)
                                                                                                                                                                                                                                                                                                                                var hitp := muz + dir * wd2
                                                                                                                                                                                                                                                                                                                                tracer_fx.append({"a": muz, "b": hitp, "t": 0.06})
                                                                                                                                                                                                                                                                                                                                # попадание по зомби на линии
                                                                                                                                                                                                                                                                                                                                for z in zombies:
                                                                                                                                                                                                                                                                                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                                                                                                                                                                                                                var to_z: Vector2 = (z["spr"].position as Vector2) - muz
                                                                                                                                                                                                                                                                                                                                                                                                var proj := to_z.dot(dir)
                                                                                                                                                                                                                                                                                                                                                                                                if proj > 0.0 and proj <= wd2 and absf(to_z.cross(dir)) < float(z["radius"]) + 7.0:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                _damage_zombie(z, 15.0 * randf_range(0.85, 1.15), dir)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                blood_burst.append({"pos": hitp, "t": 0.25, "ang": ang})
                                                                                                                                                                                                                                                                                                                                                                                                                                                                break
                                                                                                                                                                                                                                                                                                                                if int(a["mag"]) <= 0:
                                                                                                                                                                                                                                                                                                                                                                                                a["reload_t"] = 2.2
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                a["spr"].rotation = a["vel"].angle() if a["vel"].length() > 10.0 else a["spr"].rotation
                                                                                                                                # движение: следовать за игроком цепью или держать позицию
                                                                                                                                var tgt: Vector2
                                                                                                                                if a["hold"]:
                                                                                                                                                                                                tgt = a["spr"].position
                                                                                                                                else:
                                                                                                                                                                                                var off := Vector2(-46.0 - float(a["slot"]) * 40.0, ((int(a["slot"]) % 2) * 2.0 - 1.0) * (34.0 + float(a["slot"]) * 18.0))
                                                                                                                                                                                                tgt = pp + off
                                                                                                                                var dv2 := tgt - (a["spr"].position as Vector2)
                                                                                                                                if dv2.length() > 26.0 and not a["hold"]:
                                                                                                                                                                                                var sp := _ally_speed(a)
                                                                                                                                                                                                var np := (a["spr"].position as Vector2) + dv2.normalized() * sp * delta
                                                                                                                                                                                                np = _collide_circle(np, 12.0)
                                                                                                                                                                                                a["vel"] = dv2.normalized() * sp
                                                                                                                                                                                                a["spr"].position = np
                                                                                                                                                                                                a["spr"].rotation = lerp_angle(a["spr"].rotation, dv2.angle(), minf(1.0, 10.0 * delta))
                                                                                                                                                                                                a["stuck_t"] = 0.0
                                                                                                                                                                                                # анимация ходьбы союзника
                                                                                                                                                                                                a["walk_t"] = float(a["walk_t"]) + delta * 8.0
                                                                                                                                                                                                var afi := int(float(a["walk_t"]) / (PI * 0.5)) % 4
                                                                                                                                                                                                if int(a["frame_i"]) != afi and not a["frames"].is_empty():
                                                                                                                                                                                                                                                                a["frame_i"] = afi
                                                                                                                                                                                                                                                                a["spr"].texture = a["frames"][afi]
                                                                                                                                else:
                                                                                                                                                                                                a["vel"] = Vector2.ZERO
                                                                                                                                                                                                if int(a["frame_i"]) != -1:
                                                                                                                                                                                                                                                                a["frame_i"] = -1
                                                                                                                                                                                                                                                                if a["idle_tex"] != null:
                                                                                                                                                                                                                                                                                                                                a["spr"].texture = a["idle_tex"]
                                                                                                                                # кровопотеря союзника
                                                                                                                                for w in st["wounds"]:
                                                                                                                                                                                                if w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                                                                                                                                                                                                                                                                st["body"][w["zone"]] = maxf(0.06, float(st["body"][w["zone"]]) - float(w["bleed"]) * delta * 0.008)

func _revive_ally(a: Dictionary) -> void:
                                                                a["down"] = false
                                                                var st: Dictionary = a["st"]
                                                                st["body"]["torso"] = maxf(float(st["body"]["torso"]), 0.55)
                                                                st["body"]["head"] = maxf(float(st["body"]["head"]), 0.6)
                                                                for w in st["wounds"]:
                                                                                                                                w["bleed"] = 0
                                                                                                                                w["tq"] = true
                                                                add_log_body("%s поднят и перевязан." % a["callsign"], Color(0.6, 0.9, 0.6))
                                                                G.play_sfx("z_pickup", -8.0)

# ================= ДВИЖЕНИЕ ИГРОКА =================
var direct_vec := Vector2.ZERO   # левый стик (ход)
var player_velocity := Vector2.ZERO
var player_walk_t := 0.0
var player_step_t := 0.0
var manual_aim := false          # правый стик / мышь — прицел
var manual_fire := false
var manual_ang := 0.0

func _tick_player(delta: float) -> void:
                                                                var spr: Sprite2D = player["spr"]
                                                                if not player["alive"]:
                                                                                                                                return
                                                                voice_gasp_t = maxf(0.0, voice_gasp_t - delta)
                                                                # перезарядка
                                                                if player["reload_t"] > 0.0:
                                                                                                                                player["reload_t"] = float(player["reload_t"]) - delta
                                                                                                                                if float(player["reload_t"]) <= 0.0:
                                                                                                                                                                                                _finish_reload()
                                                                player["fire_cd"] = maxf(0.0, float(player["fire_cd"]) - delta)
                                                                # капсула: пока не выбил стекло — стоим
                                                                if is_bunker and not spr.visible:
                                                                                                                                return
                                                                # движение с инерцией, плавным стартом и торможением
                                                                # FIX7: бег — кнопка БЕГ зажата (или Shift на ПК), есть выносливость
                                                                var want_run := _run_wanted() and direct_vec.length() > 0.3 and stamina > 0.0 and not run_exhausted
                                                                var spd := _player_speed(want_run)
                                                                var desired_velocity := direct_vec * spd
                                                                var accel := 680.0 if desired_velocity.length() > 1.0 else 920.0
                                                                player_velocity = player_velocity.move_toward(desired_velocity, accel * delta)
                                                                var v := player_velocity
                                                                var moving: bool = v.length() > 4.0
                                                                if v.length() > 1.0:
                                                                                                                                var np := spr.position + v * delta
                                                                                                                                np = _collide_circle(np, 15.0)
                                                                                                                                spr.position = np
                                                                                                                                player_walk_t += delta * TAU * 2.1 * clampf(v.length() / maxf(1.0, spd), 0.35, 1.15)
                                                                                                                                # анимация ходьбы: 4 кадра шага
                                                                                                                                var pfi := int(player_walk_t / (PI * 0.5)) % 4
                                                                                                                                if int(player["frame_i"]) != pfi and not player["frames"].is_empty():
                                                                                                                                                                                                player["frame_i"] = pfi
                                                                                                                                                                                                spr.texture = player["frames"][pfi]
                                                                                                                                var step_bob := sin(player_walk_t) * 0.018
                                                                                                                                var bs: float = float(player["bscale"])
                                                                                                                                spr.scale = Vector2(bs * (1.0 + step_bob), bs * (1.0 - step_bob))
                                                                                                                                # FIX5: корпус качается — боковой свинг + вертикальный подпрыг
                                                                                                                                spr.offset = Vector2(sin(player_walk_t * 2.0) * 1.7, sin(player_walk_t) * 2.6)
                                                                                                                                var running := want_run and moving
                                                                                                                                # FIX7: выносливость — тратится на бегу, восстанавливается в покое
                                                                                                                                if running:
                                                                                                                                                                                                stamina = maxf(0.0, stamina - 20.0 * delta)
                                                                                                                                                                                                if stamina <= 0.0 and not run_exhausted:
                                                                                                                                                                                                                                                                run_exhausted = true
                                                                                                                                                                                                                                                                _toast("Выносливость на исходе — идём шагом")
                                                                                                                                else:
                                                                                                                                                                                                stamina = minf(100.0, stamina + (11.0 if moving else 17.0) * delta)
                                                                                                                                                                                                if run_exhausted and stamina >= 30.0:
                                                                                                                                                                                                                                                                run_exhausted = false
                                                                                                                                # FIX7: шумный бег привлекает мёртвых издалека
                                                                                                                                if running:
                                                                                                                                                                                                run_noise_t -= delta
                                                                                                                                                                                                if run_noise_t <= 0.0:
                                                                                                                                                                                                                                                                run_noise_t = 0.7
                                                                                                                                                                                                                                                                _alert_zombies(spr.position, 430.0)
                                                                                                                                                                                                if tut != null and not run_hint_done:
                                                                                                                                                                                                                                                                run_hint_done = true
                                                                                                                                                                                                                                                                tut.hint("run", "run", "БЕГ", "Двойной тап по стику хода — бег (в 1.5 раза быстрее). Отпустите стик — снова шаг. Выносливость ограничена, шумный бег слышат мёртвые. На ПК — Shift.", 45)
                                                                                                                                player_step_t -= delta
                                                                                                                                if player_step_t <= 0.0:
                                                                                                                                                                                                # FIX7: на бегу шаги чаще и громче
                                                                                                                                                                                                player_step_t = 0.30 if running else (0.42 if is_bunker else 0.54)
                                                                                                                                                                                                # FIX11: в бункере металлический пол — свой звук шагов
                                                                                                                                                                                                G.play_sfx("z_foot_metal" if is_bunker else "z_footstep", -19.0 if running else -24.0, randf_range(0.92, 1.08))
                                                                                                                                                                                                # v2.8: пыль от шагов по бетону
                                                                                                                                                                                                _step_puff()
                                                                else:
                                                                                                                                player_walk_t = 0.0
                                                                                                                                # FIX5: дыхание в покое (лёгкая пульсация), сброс покачивания
                                                                                                                                var br := sin(Time.get_ticks_msec() * 0.0026) * 0.006
                                                                                                                                spr.scale = Vector2(float(player["bscale"]) * (1.0 + br), float(player["bscale"]) * (1.0 - br))
                                                                                                                                spr.offset = Vector2.ZERO
                                                                                                                                if int(player["frame_i"]) != -1:
                                                                                                                                                                                                player["frame_i"] = -1
                                                                                                                                                                                                if player["idle_tex"] != null:
                                                                                                                                                                                                                                                                spr.texture = player["idle_tex"]
                                                                # прицел
                                                                var st: Dictionary = player["st"]
                                                                if manual_aim:
                                                                                                                                player["aim"] = manual_ang
                                                                elif v.length() > 4.0:
                                                                                                                                player["aim"] = v.angle()
                                                                # лёгкое покачивание корпуса на ходу
                                                                spr.rotation = player["aim"] + (sin(player_walk_t) * 0.028 if moving else 0.0)
                                                                # фонарь следует за прицелом
                                                                var light: PointLight2D = player["light"]
                                                                light.position = spr.position + Vector2.from_angle(player["aim"]) * 30.0
                                                                light.rotation = 0.0
                                                                player["halo"].position = spr.position
                                                                # FIX6: предмет в руках следует за игроком (мини-рука)
                                                                if _hand_ind != null and is_instance_valid(_hand_ind):
                                                                                                                                var hold_item := str(_med_sel_item)
                                                                                                                                var show_hand: bool = hold_item != "" and player["spr"].visible and player["alive"]
                                                                                                                                _hand_ind.visible = show_hand
                                                                                                                                if show_hand:
                                                                                                                                                                                                _hand_ind.position = spr.position + Vector2(-24, -36 + sin(time_alive * 3.2) * 2.5)
                                                                                                                                                                                                var itex = G.tex("z_i_" + hold_item)
                                                                                                                                                                                                if itex == null:
                                                                                                                                                                                                                                                                itex = ZUI.icon("bag")
                                                                                                                                                                                                if _hand_ind_item.texture != itex:
                                                                                                                                                                                                                                                                _hand_ind_item.texture = itex
                                                                # огонь
                                                                if _desktop_input() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
                                                                                                                                manual_fire = false
                                                                if manual_fire and not paused and (_desktop_input() or _stick_aim_idx >= 0):
                                                                                                                                _fire_player()
                                                                # медицина/заражение
                                                                _player_tick_med(delta)
                                                                # сердцебиение при низком здоровье/заражении
                                                                var worst := minf(float(st["body"]["torso"]), float(st["body"]["head"]))
                                                                if worst < 0.32 and voice_gasp_t <= 0.0:
                                                                                                                                voice_gasp_t = 6.0
                                                                                                                                G.play_sfx("z_voice_gasp", -12.0, randf_range(0.96, 1.04))
                                                                if worst < 0.5 or player["infect"] > 55.0:
                                                                                                                                _heart_rate = 1.25 - worst * 0.7
                                                                                                                                heart_t -= delta
                                                                                                                                if heart_t <= 0.0:
                                                                                                                                                                                                heart_t = maxf(0.42, _heart_rate)
                                                                                                                                                                                                G.play_sfx("z_heart", -14.0, 1.0 + (0.5 - worst))
# ================= ИНТЕРАКТИВ =================
func _find_interact() -> Dictionary:
                                                                var pp: Vector2 = player["spr"].position
                                                                # капсула (начало бункера)
                                                                if is_bunker and not player["spr"].visible:
                                                                                                                                return {"kind": "capsule", "text": "ВЫБИТЬ СТЕКЛО КАПСУЛЫ (держать)", "hold": 1.1, "pos": pp}
                                                                # сценарные интерактивы пролога «ЗАРЯ» — приоритет над общими
                                                                var zi := _zpro_find_interact(pp)
                                                                if not zi.is_empty():
                                                                        return zi
                                                                # трупы
                                                                var best := {}
                                                                var bd := 92.0
                                                                for c in corpses:
                                                                                                                                if c["searched"] and c.get("loot_items", []).is_empty():
                                                                                                                                                                                                continue
                                                                                                                                var d: float = pp.distance_to(c["pos"])
                                                                                                                                if d < bd:
                                                                                                                                                                                                bd = d
                                                                                                                                                                                                best = {"kind": "corpse", "ref": c, "text": "ОБЫСКАТЬ ТЕЛО", "hold": 0.0, "pos": c["pos"]}
                                                                # пропсы-интерактив
                                                                for pr in props:
                                                                                                                                var kind: String = pr["kind"]
                                                                                                                                if pp.distance_to(pr["pos"]) > 110.0:
                                                                                                                                                                                                continue
                                                                                                                                if kind == "gear_table" and not _obj_done("gear"):
                                                                                                                                                                                                best = {"kind": "gear", "ref": pr, "text": "ВЗЯТЬ СНАРЯЖЕНИЕ", "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                elif kind == "cabinet" and (not pr.has("used") or not pr.get("loot_items", []).is_empty()):
                                                                                                                                                                                                var cabinet_action := "ПРОДОЛЖИТЬ ОБЫСК" if pr.has("loot_items") else "ОБЫСКАТЬ ШКАФ"
                                                                                                                                                                                                best = {"kind": "cabinet", "ref": pr, "text": cabinet_action, "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                elif kind == "loot_crate" or kind == "crate" or (kind == "crate_used" and not pr.get("loot_items", []).is_empty()):
                                                                                                                                                                                                var crate_action := "ПРОДОЛЖИТЬ ОБЫСК" if kind == "crate_used" else "ОБЫСКАТЬ ЯЩИК"
                                                                                                                                                                                                best = {"kind": "crate", "ref": pr, "text": crate_action, "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                elif kind == "tablet_crate":
                                                                                                                                                                                                best = {"kind": "tablet", "ref": pr, "text": "ЗАБРАТЬ ПЛАНШЕТ", "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                elif kind == "scanner" and is_bunker and not scanner_used:
                                                                                                                                                                                                if G.zsave["inv"].get("keycard", 0) > 0:
                                                                                                                                                                                                                                                                best = {"kind": "scanner", "ref": pr, "text": "ПРИЛОЖИТЬ КЛЮЧ-КАРТУ К СКАНЕРУ", "hold": 0.8, "pos": pr["pos"]}
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                best = {"kind": "scanner_no", "ref": pr, "text": "СКАНЕР: ТРЕБУЕТСЯ КЛЮЧ-КАРТА", "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                elif kind == "airlock" and is_bunker:
                                                                                                                                                                                                if extraction_open:
                                                                                                                                                                                                                                                                best = {}
                                                                                                                                                                                                elif scanner_used and G.zsave["inv"].get("keycard", 0) > 0:
                                                                                                                                                                                                                                                                best = {"kind": "airlock", "ref": pr, "text": "ОТКРЫТЬ ГЕРМОДВЕРЬ ШЛЮЗА", "hold": 0.6, "pos": pr["pos"]}
                                                                                                                                                                                                elif not scanner_used:
                                                                                                                                                                                                                                                                best = {"kind": "airlock_locked", "ref": pr, "text": "ШЛЮЗ ЗАПЕРТ — АКТИВИРУЙТЕ СКАНЕР", "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                best = {"kind": "airlock_locked", "ref": pr, "text": "ШЛЮЗ ЗАПЕРТ — НУЖНА КАРТА", "hold": 0.0, "pos": pr["pos"]}
                                                                                                                                elif kind == "door" and is_bunker:
                                                                                                                                                                                                var dr: Dictionary = doors.get(str(pr.get("door_id", "")), {})
                                                                                                                                                                                                if not dr.is_empty() and not bool(dr.get("opened", false)):
                                                                                                                                                                                                                                                                best = {"kind": "door", "ref": pr, "text": "ОТКРЫТЬ ГЕРМОДВЕРЬ", "hold": 0.6, "pos": pr["pos"]}
                                                                                                                                elif kind == "stairs" and is_bunker and extraction_open:
                                                                                                                                                                                                best = {"kind": "stairs", "ref": pr, "text": "ПОДНЯТЬСЯ ПО ЛЕСТНИЦЕ НА ПОВЕРХНОСТЬ", "hold": 2.2, "pos": pr["pos"]}
                                                                # тяжёлый союзник — оживить
                                                                for a in allies:
                                                                                                                                if a["alive"] and a["down"]:
                                                                                                                                                                                                if pp.distance_to(a["spr"].position) < 80.0:
                                                                                                                                                                                                                                                                best = {"kind": "revive", "ref": a, "text": "ОЖИВИТЬ %s (держать)" % a["callsign"], "hold": 2.4, "pos": a["spr"].position}
                                                                # спасение: гражданский
                                                                if mission == "rescue" and rescue_npc != null and rescue_npc["alive"] and not rescue_follow:
                                                                                                                                if pp.distance_to(rescue_npc["spr"].position) < 90.0:
                                                                                                                                                                                                best = {"kind": "rescue", "ref": rescue_npc, "text": "ПОДНЯТЬ СОЮЗНИКА", "hold": 1.0, "pos": rescue_npc["spr"].position}
                                                                return best

func _do_interact(info: Dictionary) -> void:
                                                                var kind: String = info["kind"]
                                                                if ZPRO_KINDS.has(kind):
                                                                        _zpro_do_interact(kind, info)
                                                                        return
                                                                match kind:
                                                                                                                                "capsule":
                                                                                                                                                                                                player["spr"].visible = true
                                                                                                                                                                                                in_capsule = false
                                                                                                                                                                                                _apply_capsule_ui()
                                                                                                                                                                                                for sq in G.zsave["squad"]:
                                                                                                                                                                                                                                                                if sq.get("alive", true):
                                                                                                                                                                                                                                                                                                                                _spawn_ally(sq)
                                                                                                                                                                                                player["light"].energy = 0.95
                                                                                                                                                                                                (player["halo"] as Sprite2D).modulate.a = 0.32
                                                                                                                                                                                                G.play_sfx("z_glass", -6.0)
                                                                                                                                                                                                G.play_sfx("z_metal", -8.0)
                                                                                                                                                                                                _complete_objective("capsule")
                                                                                                                                                                                                # стекло порезало руку — учебная задача медицины
                                                                                                                                                                                                var st: Dictionary = player["st"]
                                                                                                                                                                                                st["wounds"].append({"zone": "ra", "bleed": 1, "tq": false, "clamp": false, "band": false})
                                                                                                                                                                                                st["body"]["ra"] = maxf(0.55, float(st["body"]["ra"]) - 0.3)
                                                                                                                                                                                                st["stress"] = 30.0
                                                                                                                                                                                                _hit_vignette(0.7)
                                                                                                                                                                                                G.play_sfx("z_tinnitus", -8.0)
                                                                                                                                                                                                _blood_pool(player["spr"].position, false)
                                                                                                                                                                                                _log("Стекло разбито. П.РУКА рассечена — кровь!", Color(0.95, 0.6, 0.5), "СИСТЕМА")
                                                                                                                                                                                                _log("«Внимание. Пациент покинул капсулу. Дальнейшие инструкции недоступны.»", Color(0.6, 0.8, 0.7), "РАДИО")
                                                                                                                                                                                                if tut != null:
                                                                                                                                                                                                                                                                tut.hint("bleeding", "drop", "ВЫ КРОВОТЕЧИТЕ", "Откройте РЮКЗАК — кровь нужно остановить.", 95)
                                                                                                                                "corpse":
                                                                                                                                                                                                _search_corpse(info["ref"])
                                                                                                                                "gear":
                                                                                                                                                                                                _complete_objective("gear")
                                                                                                                                                                                                var pr: Dictionary = info["ref"]
                                                                                                                                                                                                pr["used"] = true
                                                                                                                                                                                                # КПК, пистолет Макарова, 2 магазина, фонарик (по ТЗ) + медицина
                                                                                                                                                                                                G.z_give_item("band", 2)
                                                                                                                                                                                                G.z_give_item("tq", 1)
                                                                                                                                                                                                G.z_give_item("morph", 1)
                                                                                                                                                                                                G.z_give_item("mag_pistol", 2)
                                                                                                                                                                                                G.z_give_item("food", 1)
                                                                                                                                                                                                G.zsave["ammo"]["pistol"] = int(G.zsave["ammo"].get("pistol", 0)) + 8
                                                                                                                                                                                                G.play_sfx("z_pickup", -6.0)
                                                                                                                                                                                                _log("Снаряжение получено: КПК, ПМ, 2 магазина, фонарик, аптечка.", Color(0.85, 0.88, 0.6), "ХАБАР")
                                                                                                                                                                                                # маячок-идентичность: имя из детали мира, без биографии (ТЗ п.13)
                                                                                                                                                                                                _log("Бирка на комбинезоне: «А. ВОЛКОВ · СЛУЖБА БЕЗОПАСНОСТИ». Своё имя читаю как чужое.", Color(0.72, 0.80, 0.92), "ВОЛКОВ")
                                                                                                                                                                                                _toast("Фонарик включён. Патроны в магазине ПМ: 8")
                                                                                                                                                                                                if tut != null:
                                                                                                                                                                                                                                                                tut.hint("corridor", "skull", "КОРИДОР ЗАХВАЧЕН", "За дверью медотсека ходят мёртвые лаборанты. Стреляйте по ним: ЛКМ (ПК) или правый стик до упора. [R] — перезарядка. Берегите патроны.", 85)
                                                                                                                                                                                                if pr.has("spr"):
                                                                                                                                                                                                                                                                (pr["spr"] as Sprite2D).modulate = Color(0.75, 0.75, 0.72)
                                                                                                                                "cabinet":
                                                                                                                                                                                                var pr2: Dictionary = info["ref"]
                                                                                                                                                                                                if not pr2.has("loot_items"):
                                                                                                                                                                                                                                                                pr2["loot_items"] = _roll_loot([["band", 0.5], ["meds", 0.4], ["abx", 0.25], ["food", 0.3]])
                                                                                                                                                                                                                                                                pr2["used"] = true
                                                                                                                                                                                                                                                                if pr2["loot_items"].is_empty():
                                                                                                                                                                                                                                                                                                                                _log("Шкаф пуст. Ещё до вспышки вылизан.", Color(0.7, 0.72, 0.6), "СИСТЕМА")
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                G.play_sfx("z_door", -12.0)
                                                                                                                                                                                                                                                                                                                                _open_loot_window("ОБЫСК: ШКАФ", pr2)
                                                                                                                                                                                                                                                                if pr2.has("spr"):
                                                                                                                                                                                                                                                                                                (pr2["spr"] as Sprite2D).modulate = Color(0.7, 0.7, 0.66)
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                _open_loot_window("ОБЫСК: ШКАФ", pr2)
                                                                                                                                "crate":
                                                                                                                                                                                                _open_loot_crate(info["ref"])
                                                                                                                                "tablet":
                                                                                                                                                                                                _take_tablet(info["ref"])
                                                                                                                                "scanner":
                                                                                                                                                                                                # ДОСТУП РАЗРЕШЕН: сюжетный намёк (по ТЗ)
                                                                                                                                                                                                scanner_used = true
                                                                                                                                                                                                _complete_objective("scanner")
                                                                                                                                                                                                G.play_sfx("radio", -8.0)
                                                                                                                                                                                                G.play_sfx("z_spark", -16.0)
                                                                                                                                                                                                _open_scanner_window()
                                                                                                                                "scanner_no":
                                                                                                                                                                                                _toast("Терминал требует ключ-карту. Обыщите тело охранника.")
                                                                                                                                                                                                G.play_sfx("z_dry", -8.0, 0.7)
                                                                                                                                "stairs":
                                                                                                                                                                                                # ЛИФТ: одноразовый спуск в технический сектор (сценарий п.8)
                                                                                                                                                                                                if not bool(zp.get("elevator_done", false)):
                                                                                                                                                                                                                                                                zp["elevator_done"] = true
                                                                                                                                                                                                                                                                _zpro_elevator_scene()
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                _toast("Лифт обесточен. Спуск — только через техсектор, пешком.")
                                                                                                                                                                                                                                                                G.play_sfx("z_dry", -10.0, 0.7)
                                                                                                                                                                                                                                                                G.play_sfx("z_door", -6.0)
                                                                                                                                                                                                                                                                G.play_sfx("z_footstep", -8.0)
                                                                                                                                "airlock":
                                                                                                                                                                                                G.play_sfx("z_door", -4.0)
                                                                                                                                                                                                _toast("Гермодверь открыта. Лестница — за шлюзом!")
                                                                                                                                                                                                _complete_objective("exit")
                                                                                                                                                                                                extraction = Vector2(2320, 170)
                                                                                                                                                                                                _open_extraction()
                                                                                                                                                                                                # показать лестницу
                                                                                                                                                                                                if not stairs_prop.is_empty() and stairs_prop.has("spr"):
                                                                                                                                                                                                                                                                var spr_s: Sprite2D = stairs_prop["spr"]
                                                                                                                                                                                                                                                                spr_s.visible = true
                                                                                                                                                                                                                                                                ZUI.entrance(spr_s, 0.2, 6)
                                                                                                                                                                                                # дверь уезжает вверх
                                                                                                                                                                                                var pr3: Dictionary = info["ref"]
                                                                                                                                                                                                if pr3.has("spr"):
                                                                                                                                                                                                                                                                var tw := (pr3["spr"] as Sprite2D).create_tween()
                                                                                                                                                                                                                                                                tw.tween_property(pr3["spr"], "position", (pr3["spr"] as Sprite2D).position + Vector2(0, -150), 1.6)
                                                                                                                                                                                                if tut != null:
                                                                                                                                                                                                                                                                tut.hint("stairs_go", "stairs", "НАВЕРХ", "Шлюз открыт. Встаньте на лестницу и удерживайте кнопку действия — выйдете на поверхность, в Сектор 2.", 70)
                                                                                                                                "door":
                                                                                                                                                                                                _open_door(str(info["ref"].get("door_id", "")))
                                                                                                                                "airlock_locked":
                                                                                                                                                                                                _toast("Дверь заперта. Нужна ключ-карта охраны.")
                                                                                                                                                                                                G.play_sfx("z_dry", -8.0, 0.7)
                                                                                                                                "revive":
                                                                                                                                                                                                _revive_ally(info["ref"])
                                                                                                                                "rescue":
                                                                                                                                                                                                rescue_follow = true
                                                                                                                                                                                                _complete_objective("main")
                                                                                                                                                                                                _open_extraction()
                                                                                                                                                                                                G.play_sfx("z_static", -10.0)
                                                                                                                                                                                                _log("Союзник на ногах. Ведите его к эвакуации!", Color(0.6, 0.9, 0.6), "РАДИО")

# ================= ЗАДАЧИ =================
func _add_objective(id: String, text: String, grp := 0) -> void:
                                                                # FIX10: задачи показываются порциями (группами) — обычно 1, где надо 2.
                                                                # Следующая группа появляется, когда выполнены все задачи текущей:
                                                                # список больше не занимает пол-экрана. Группа 0 = видна сразу.
                                                                objectives.append({"id": id, "text": text, "done": false, "grp": grp})
                                                                _refresh_obj_labels()

var _obj_frontier_prev := -1

func _obj_frontier() -> int:
                                                                # номер первой группы, где есть невыполненная задача (9999 — всё сделано)
                                                                var best := 9999
                                                                for o in objectives:
                                                                            if not bool(o["done"]):
                                                                                        best = mini(best, int(o.get("grp", 0)))
                                                                return best

func _obj_done(id: String) -> bool:
                                                                for o in objectives:
                                                                                                                                if o["id"] == id:
                                                                                                                                                                                                return o["done"]
                                                                return false

func _complete_objective(id: String) -> void:
                                                                for o in objectives:
                                                                                                                                if o["id"] == id and not o["done"]:
                                                                                                                                                                                                o["done"] = true
                                                                                                                                                                                                G.play_sfx("capture", -12.0)
                                                                                                                                                                                                _refresh_obj_labels()
                                                                                                                                                                                                _log("Задача выполнена: " + o["text"], Color(0.6, 0.9, 0.6), "СИСТЕМА")

func _upd_obj_text(id: String, text: String) -> void:
                                                                for o in objectives:
                                                                                                                                if o["id"] == id and not o["done"]:
                                                                                                                                                                                                o["text"] = text
                                                                _refresh_obj_labels()

func _refresh_obj_labels() -> void:
                                                                if obj_panel == null:
                                                                                                                                return
                                                                for l in obj_labels:
                                                                                                                                if is_instance_valid(l):
                                                                                                                                                                                                l.queue_free()
                                                                obj_labels.clear()
                                                                var vb: VBoxContainer = obj_panel.get_child(0) if obj_panel.get_child_count() > 0 else null
                                                                if vb == null:
                                                                                                                                return
                                                                # заголовок с SVG-иконкой карты
                                                                var head := HBoxContainer.new()
                                                                head.add_theme_constant_override("separation", 7)
                                                                var hic := ZUI.icon_rect("map", 22, ZUI.NEON)
                                                                hic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                                                                head.add_child(hic)
                                                                var hl := ZUI.label("ЗАДАЧИ СЕКТОРА", 16, ZUI.NEON_BRIGHT)
                                                                hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                                                head.add_child(hl)
                                                                # FIX6: глаз — спрятать/показать задачи
                                                                var eye_btn := Button.new()
                                                                eye_btn.icon = ZUI.icon("eye_off" if obj_hidden else "eye")
                                                                eye_btn.focus_mode = Control.FOCUS_NONE
                                                                eye_btn.custom_minimum_size = Vector2(34, 28)
                                                                eye_btn.modulate = ZUI.MUTED
                                                                eye_btn.tooltip_text = "Свернуть/развернуть задачи"
                                                                eye_btn.pressed.connect(func():
                                                                                                                                G.play_sfx("ui_click", -12.0)
                                                                                                                                obj_hidden = not obj_hidden
                                                                                                                                _refresh_obj_labels())
                                                                head.add_child(eye_btn)
                                                                obj_labels.append(head)
                                                                vb.add_child(head)
                                                                if obj_hidden:
                                                                                                                                return
                                                                # FIX10: видна только ТЕКУЩАЯ группа задач (обычно 1 строка, где надо — 2)
                                                                var fr := _obj_frontier()
                                                                if _obj_frontier_prev >= 0 and fr > _obj_frontier_prev and fr < 9999:
                                                                    # следующая порция задач открылась — тихий сигнал в журнал
                                                                    for o in objectives:
                                                                        if int(o.get("grp", 0)) == fr and not bool(o["done"]):
                                                                            _log("Новая задача: " + str(o["text"]), Color(0.62, 0.85, 0.72), "СИСТЕМА")
                                                                            G.play_sfx("z_radio_beep", -18.0)
                                                                            break
                                                                _obj_frontier_prev = fr
                                                                if fr >= 9999:
                                                                    var fin := HBoxContainer.new()
                                                                    fin.add_theme_constant_override("separation", 6)
                                                                    fin.add_child(ZUI.icon_rect("check", 20, ZUI.NEON))
                                                                    fin.add_child(ZUI.label("Все задачи выполнены — к эвакуации", 16, ZUI.NEON_DIM))
                                                                    obj_labels.append(fin)
                                                                    vb.add_child(fin)
                                                                    return
                                                                for o in objectives:
                                                                                                                                if int(o.get("grp", 0)) != fr:
                                                                                                                                    continue
                                                                                                                                var done: bool = bool(o["done"])
                                                                                                                                var row := HBoxContainer.new()
                                                                                                                                row.add_theme_constant_override("separation", 6)
                                                                                                                                # SVG-галочка (зелёная) или точка
                                                                                                                                var mk := ZUI.icon_rect("check", 20, ZUI.NEON if done else ZUI.FAINT)
                                                                                                                                mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                                                                                                                                row.add_child(mk)
                                                                                                                                var txt: String = String(o["text"])
                                                                                                                                var l := ZUI.wrap_label(txt, 15, ZUI.NEON_DIM if done else ZUI.TEXT, 320.0)
                                                                                                                                l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                                                                                                                row.add_child(l)
                                                                                                                                obj_labels.append(row)
                                                                                                                                vb.add_child(row)

# ================= БУНКЕР: СКРИПТ МИССИИ =================
func _check_bunker_corridor() -> void:
                                                                # все 3 зомби-лаборанта мертвы?
                                                                var sci_left := 0
                                                                for z in zombies:
                                                                                                                                if z["alive"] and z["kind"] == "sci":
                                                                                                                                                                                                sci_left += 1
                                                                if sci_left == 0 and not _obj_done("corridor"):
                                                                                                                                _complete_objective("corridor")
                                                                                                                                G.play_sfx("z_static", -10.0)
                                                                                                                                _log("«Карантинный блок чист. Приём, Командир. Тело охранника — у шлюза.»", Color(0.6, 0.8, 0.7), "РАДИО")
                                                                                                                                if tut != null:
                                                                                                                                                                tut.hint("guard_body", "keycard", "ТЕЛО ОХРАННИКА", "У шлюза лежит охранник. Обыщите тело и перетащите КЛЮЧ-КАРТУ из окна обыска в рюкзак (drag-and-drop). Затем приложите её к сканеру терминала.", 80)

# ---------- СКАНЕР: ТЕРМИНАЛ ДОСТУПА (ZDialog) ----------
func _open_scanner_window() -> void:
                                                                paused = true
                                                                var layer := CanvasLayer.new()
                                                                layer.layer = 35
                                                                add_child(layer)
                                                                var dim := ColorRect.new()
                                                                dim.set_anchors_preset(Control.PRESET_FULL_RECT)
                                                                dim.color = Color(0, 0, 0, 0.6)
                                                                layer.add_child(dim)
                                                                var dlg := ZDialog.new()
                                                                dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
                                                                layer.add_child(dlg)
                                                                dlg.set_stages([
                                                                                                {
                                                                                                                                "speaker": "СКАНЕР КАРТ · ТЕРМИНАЛ СЛУЖБЫ БЕЗОПАСНОСТИ",
                                                                                                                                "col": ZUI.NEON,
                                                                                                                                "text": "[ДОСТУП РАЗРЕШЕН: НАЧАЛЬНИК СЛУЖБЫ БЕЗОПАСНОСТИ О. «ЗАРЯ»]\n\nЛичное дело зашифровано. Уровень допуска — АЛЬФА. Технический шлюз разблокирован.",
                                                                                                                                "sfx": "radio", "sfx_db": -6.0,
                                                                                                                                "btn": {"text": "ОТСТУПИТЬ ОТ ТЕРМИНАЛА", "icon": "door"},
                                                                                                                                "next": -1,
                                                                                                },
                                                                ])
                                                                dlg.on_finished = func():
                                                                                                layer.queue_free()
                                                                                                paused = false
                                                                                                _log("Сканер назвал вас Начальником Службы Безопасности объекта. Вы этого не помните.", Color(0.8, 0.7, 0.5), "СТРАННОЕ")
                                                                                                _log("«Начальник СБ»... Вот и первая зацепка. Шлюз открыт — проверим, что там ещё числится за мной.", Color(0.72, 0.80, 0.92), "ВОЛКОВ")
                                                                                                if tut != null:
                                                                                                                                tut.hint("airlock_go", "door", "ШЛЮЗ РАЗБЛОКИРОВАН", "Терминал снял блокировку. Откройте гермодверь шлюза и поднимитесь по лестнице на поверхность.", 72)
                                                                dlg.start(0)

# ================= ЭВАКУАЦИЯ =================
func _open_extraction() -> void:
                                                                if extraction_open:
                                                                                                                                return
                                                                extraction_open = true
                                                                _upd_obj_text("evac", "Эвакуация открыта — удерживайте точку")
                                                                _refresh_extraction_prop()

func _refresh_extraction_prop() -> void:
                                                                # зелёный дым + маркер
                                                                var smoke := CPUParticles2D.new()
                                                                smoke.amount = 30
                                                                smoke.lifetime = 2.2
                                                                smoke.texture = _light_tex()
                                                                smoke.scale_amount_min = 0.5
                                                                smoke.scale_amount_max = 1.1
                                                                smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
                                                                smoke.emission_sphere_radius = 60.0
                                                                smoke.direction = Vector2(0, -1)
                                                                smoke.initial_velocity_min = 10.0
                                                                smoke.initial_velocity_max = 40.0
                                                                smoke.gravity = Vector2.ZERO
                                                                smoke.color = Color(0.35, 0.85, 0.45, 0.30)
                                                                smoke.position = extraction
                                                                fx_layer.add_child(smoke)

func _tick_extraction(delta: float) -> void:
                                                                if not extraction_open or battle_over != "":
                                                                                                                                return
                                                                if is_bunker:
                                                                                                                                return   # в бункере выход — интерактив «ПОДНЯТЬСЯ ПО ЛЕСТНИЦЕ» (stairs_fade)
                                                                var ok := false
                                                                if player["spr"].visible and player["spr"].position.distance_to(extraction) < 110.0:
                                                                                                                                ok = true
                                                                if mission == "rescue" and rescue_follow and rescue_npc != null and rescue_npc["alive"]:
                                                                                                                                # гражданский должен быть рядом
                                                                                                                                if (rescue_npc["spr"].position as Vector2).distance_to(extraction) > 160.0:
                                                                                                                                                                                                ok = false
                                                                if ok:
                                                                                                                                extract_t += delta
                                                                                                                                if extract_t >= 2.2:
                                                                                                                                                                                                _win()
                                                                else:
                                                                                                                                extract_t = maxf(0.0, extract_t - delta * 2.0)

# ================= ОБОРОНА (волны) =================
var defense_total := 90.0
var wave_rng := RandomNumberGenerator.new()

func _tick_defense(delta: float) -> void:
                                                                if mission != "defense" or _obj_done("main"):
                                                                                                                                return
                                                                defense_t += delta
                                                                var left: float = maxf(0.0, defense_total - defense_t)
                                                                _upd_obj_text("main", "Продержаться %d секунд (волна %d)" % [int(ceil(left)), defense_wave + 1])
                                                                # волны каждые 30 с
                                                                var want_wave := int(defense_t / 30.0)
                                                                if want_wave > defense_wave:
                                                                                                                                defense_wave = want_wave
                                                                                                                                var center := zone_target.get_center()
                                                                                                                                for i in range(5 + defense_wave * 2):
                                                                                                                                                                                                var a := randf() * TAU
                                                                                                                                                                                                var p := center + Vector2.from_angle(a) * randf_range(700, 1000)
                                                                                                                                                                                                p = p.clamp(Vector2(200, 200), map_size - Vector2(200, 200))
                                                                                                                                                                                                _spawn_zombie(_pick_kind(wave_rng), p)
                                                                                                                                                                                                zombies[zombies.size() - 1]["alert"] = true
                                                                                                                                                                                                zombies[zombies.size() - 1]["state"] = "chase"
                                                                                                                                G.play_sfx("z_shriek", -8.0)
                                                                                                                                _log("Волна %d! Они идут со всех сторон!" % (defense_wave + 1), Color(0.95, 0.6, 0.5), "СИСТЕМА")
                                                                if defense_t >= defense_total:
                                                                                                                                _complete_objective("main")
                                                                                                                                _open_extraction()
                                                                                                                                _toast("Сигнал ушёл! К эвакуации!")

# ================= ТЕРРИТОРИЯ WORLDBOX (миникарта) =================
func _tick_territory(delta: float) -> void:
                                                                terr_t += delta
                                                                if terr_t < 0.3:
                                                                                                                                return
                                                                var step := terr_t
                                                                terr_t = 0.0
                                                                # добавляем влияние вокруг отряда
                                                                var sources: Array = []
                                                                if player["spr"].visible:
                                                                                                                                sources.append(player["spr"].position)
                                                                for a in allies:
                                                                                                                                if a["alive"] and not a["down"]:
                                                                                                                                                                                                sources.append(a["spr"].position)
                                                                for pos in sources:
                                                                                                                                var cell := Vector2i(int(pos.x / TERR_CELL), int(pos.y / TERR_CELL))
                                                                                                                                for dy in range(-2, 3):
                                                                                                                                                                                                for dx in range(-2, 3):
                                                                                                                                                                                                                                                                var c := cell + Vector2i(dx, dy)
                                                                                                                                                                                                                                                                var dist := sqrt(float(dx * dx + dy * dy))
                                                                                                                                                                                                                                                                if dist <= 2.4:
                                                                                                                                                                                                                                                                                                                                terr[c] = minf(1.0, float(terr.get(c, 0.0)) + step * 1.6 * (1.0 - dist / 2.6))
                                                                # затухание
                                                                var dead: Array = []
                                                                for c in terr:
                                                                                                                                var v: float = float(terr[c]) * 0.965
                                                                                                                                if v < 0.02:
                                                                                                                                                                                                dead.append(c)
                                                                                                                                else:
                                                                                                                                                                                                terr[c] = v
                                                                for c in dead:
                                                                                                                                terr.erase(c)

# ================= HUD (ZUI: графит + SVG-иконки) =================
func _apply_capsule_ui() -> void:
                                                                # в капсуле видна ТОЛЬКО кнопка действия (выбить стекло/выбраться)
                                                                # (reload_chip не в списке — его видимостью управляет сам ReloadChip)
                                                                var hide := in_capsule
                                                                for n in [obj_panel, mm_ref, quick_panel_ref, menu_btns_ref]:
                                                                                                                                if n != null and is_instance_valid(n):
                                                                                                                                                                                                (n as CanvasItem).visible = not hide

func _build_hud() -> void:
                                                                ui_layer = CanvasLayer.new()
                                                                ui_layer.layer = 15
                                                                add_child(ui_layer)
                                                                # корневой контроль: стики/прицел/виньетки/журнал
                                                                hud_ctrl = Control.new()
                                                                hud_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
                                                                hud_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                                                ui_layer.add_child(hud_ctrl)
                                                                if bench.has("ui"): ui_layer.visible = false
                                                                hud_ctrl.set_script(HudDraw)
                                                                hud_ctrl.set("btl", self)
                                                                # панель задач (левый верх)
                                                                obj_panel = PanelContainer.new()
                                                                obj_panel.add_theme_stylebox_override("panel", ZUI.panel_style(Color(0.045, 0.052, 0.05, 0.85), ZUI.BORDER_SOFT, 10))
                                                                obj_panel.position = Vector2(12, 12)
                                                                obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                                                var vb := VBoxContainer.new()
                                                                vb.add_theme_constant_override("separation", 2)
                                                                obj_panel.add_child(vb)
                                                                ui_layer.add_child(obj_panel)
                                                                _refresh_obj_labels()
                                                                # миникарта (правый верх)
                                                                var mm := Control.new()
                                                                mm_ref = mm
                                                                mm.set_script(MiniMap)
                                                                mm.set("btl", self)
                                                                mm.custom_minimum_size = Vector2(268, 190)
                                                                mm.set_anchors_preset(Control.PRESET_TOP_RIGHT)
                                                                mm.offset_left = -282
                                                                mm.offset_right = -14
                                                                mm.offset_top = 12
                                                                mm.offset_bottom = 202
                                                                mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                                                ui_layer.add_child(mm)
                                                                # FIX7: панель «ПМ «Макаров» удалена — точный счёт патронов
                                                                # больше не показываем (проверка магазина — кнопкой ПАТРОНЫ).
                                                                # Вместо неё — лёгкая плашка перезарядки над слотами.
                                                                var reload_chip := Control.new()
                                                                reload_chip_ref = reload_chip
                                                                reload_chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
                                                                reload_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
                                                                reload_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
                                                                reload_chip.offset_left = -130
                                                                reload_chip.offset_right = 130
                                                                reload_chip.offset_top = -152
                                                                reload_chip.offset_bottom = -116
                                                                reload_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                                                reload_chip.visible = false
                                                                reload_chip.set_script(ReloadChip)
                                                                reload_chip.set("btl", self)
                                                                ui_layer.add_child(reload_chip)
                                                                # FIX7: быстрые слоты опущены ниже — ближе к нижней кромке,
                                                                # не перекрывают обзор и стики (они по краям)
                                                                var quick_row := HBoxContainer.new()
                                                                quick_panel_ref = quick_row
                                                                quick_row.add_theme_constant_override("separation", 10)
                                                                quick_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
                                                                quick_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
                                                                quick_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
                                                                quick_row.offset_top = -136
                                                                quick_row.offset_bottom = -44
                                                                quick_row.mouse_filter = Control.MOUSE_FILTER_PASS
                                                                ui_layer.add_child(quick_row)
                                                                _ensure_quick_list()
                                                                var b_ammo := ZIconButton.new("ammo", "ПАТРОНЫ", Vector2(84, 88), ZUI.WARN)
                                                                b_ammo.tooltip_text = "Проверить магазин на глаз (± пара патронов)"
                                                                b_ammo.pressed.connect(func():
                                                                                                                                G.play_sfx("ui_click", -10.0)
                                                                                                                                _start_ammo_check())
                                                                quick_row.add_child(b_ammo)
                                                                quick_slots.clear()
                                                                for qi in range(G.zsave["quick"].size()):
                                                                                                                                var slot := QuickSlot.new()
                                                                                                                                slot.btl = self
                                                                                                                                slot.index = qi
                                                                                                                                slot.item = str(G.zsave["quick"][qi])
                                                                                                                                slot.custom_minimum_size = Vector2(92, 88)
                                                                                                                                slot.pressed.connect(func():
                                                                                                                                                                                                G.play_sfx("ui_click", -12.0)
                                                                                                                                                                                                _quick_use_item(slot.item))
                                                                                                                                quick_row.add_child(slot)
                                                                                                                                quick_slots.append(slot)
                                                                _refresh_quick_slots()
                                                                # FIX6: кнопки «по полочкам» — два ряда компактных иконок под миникартой
                                                                var btns := VBoxContainer.new()
                                                                menu_btns_ref = btns
                                                                btns.add_theme_constant_override("separation", 10)
                                                                btns.set_anchors_preset(Control.PRESET_TOP_RIGHT)
                                                                btns.grow_horizontal = Control.GROW_DIRECTION_BEGIN
                                                                btns.grow_vertical = Control.GROW_DIRECTION_END
                                                                btns.offset_left = -186
                                                                btns.offset_right = -14
                                                                btns.offset_top = 214
                                                                btns.offset_bottom = 402
                                                                btns.alignment = BoxContainer.ALIGNMENT_END
                                                                ui_layer.add_child(btns)
                                                                var shelf1 := HBoxContainer.new()
                                                                shelf1.add_theme_constant_override("separation", 10)
                                                                shelf1.alignment = BoxContainer.ALIGNMENT_END
                                                                btns.add_child(shelf1)
                                                                var b_med := ZIconButton.new("bag", "РЮКЗАК", Vector2(80, 80), Color(0.82, 0.86, 0.80))
                                                                b_med.pressed.connect(func():
                                                                                                                                G.play_sfx("ui_click", -8.0)
                                                                                                                                _open_med())
                                                                shelf1.add_child(b_med)
                                                                var b_kpk := ZIconButton.new("pda", "КПК", Vector2(80, 80), Color(0.82, 0.86, 0.80))
                                                                b_kpk.pressed.connect(func():
                                                                                                                                G.play_sfx("ui_click", -8.0)
                                                                                                                                _open_kpk())
                                                                shelf1.add_child(b_kpk)
                                                                var shelf2 := HBoxContainer.new()
                                                                shelf2.add_theme_constant_override("separation", 10)
                                                                shelf2.alignment = BoxContainer.ALIGNMENT_END
                                                                btns.add_child(shelf2)
                                                                var b_pause := ZIconButton.new("pause", "ПАУЗА", Vector2(80, 80), ZUI.TEXT)
                                                                b_pause.pressed.connect(func():
                                                                                                                                G.play_sfx("ui_click", -8.0)
                                                                                                                                _open_pause())
                                                                shelf2.add_child(b_pause)
                                                                # FIX6: интерактив — круглая SVG-кнопка ПРЯМО НА ОБЪЕКТЕ (в мире)
                                                                interact_bubble = InteractBubble.new()
                                                                interact_bubble.btl = self
                                                                interact_bubble.visible = false
                                                                interact_bubble.pressed.connect(func():
                                                                                                                                if not cur_interact.is_empty():
                                                                                                                                                                                                _do_interact(cur_interact))
                                                                ui_layer.add_child(interact_bubble)
                                                                # FIX6: индикатор «предмет в руках» — мини-рука + иконка предмета
                                                                _hand_ind = Node2D.new()
                                                                _hand_ind.z_index = 14
                                                                var hand_spr := Sprite2D.new()
                                                                hand_spr.texture = ZUI.icon("hand")
                                                                hand_spr.scale = Vector2(0.62, 0.62)
                                                                hand_spr.modulate = Color(0.95, 0.98, 0.9, 0.85)
                                                                _hand_ind.add_child(hand_spr)
                                                                _hand_ind_item = Sprite2D.new()
                                                                _hand_ind_item.scale = Vector2(0.55, 0.55)
                                                                _hand_ind_item.position = Vector2(13, -15)
                                                                _hand_ind.add_child(_hand_ind_item)
                                                                _hand_ind.visible = false
                                                                unit_layer.add_child(_hand_ind)
                                                                # виньетка
                                                                ui_layer.add_child(ZUI.vignette(0.42))

                                                                _apply_capsule_ui()
func _cycle_weapon() -> void:
                                                                var owned: Array = G.zsave["weapons"]
                                                                if owned.size() < 2:
                                                                                                                                _toast("Другого оружия нет — ищите в секторах / покупайте в лагере")
                                                                                                                                return
                                                                var idx := owned.find(player["weapon"])
                                                                if idx < 0:
                                                                                                                                idx = 0
                                                                player["weapon"] = owned[(idx + 1) % owned.size()]
                                                                G.zsave["cur_weapon"] = player["weapon"]
                                                                var wd: Dictionary = G.ZWEAPONS[player["weapon"]]
                                                                player["mag"] = mini(int(player["mag"]), int(wd["mag"]))
                                                                player["reload_t"] = 0.0
                                                                G.play_sfx("z_dry", -12.0, 1.2)
                                                                _toast("Оружие: %s" % G.Z_WEAPON_NAMES.get(player["weapon"], player["weapon"]))

# ---------- журнал и подсказки ----------
func _log(text: String, col := Color(0.8, 0.8, 0.75), tag := "") -> void:
                                                                log_lines.append({"text": text, "col": col, "tag": tag, "t": 9.0})
                                                                while log_lines.size() > 6:
                                                                                                                                log_lines.pop_front()

func add_log_body(text: String, col := Color(0.85, 0.85, 0.8)) -> void:
                                                                _log(text, col, "ОТРЯД")

func _toast(text: String) -> void:
                                                                toasts.append({"text": text, "t": 3.4})

# ---------- окно ЗДОРОВЬЯ (ZMedUI: анатомия + инвентарь, drag&drop) ----------
func _open_med() -> void:
                                                                if tut != null:
                                                                                                                                # FIX7: свободные слоты — объясняем один раз
                                                                                                                                tut.hint("quickbar", "bag", "РЮКЗАК: ЯЧЕЙКИ", "Справа ячейки рюкзака: перетащите предмет в БЫСТРЫЕ СЛОТЫ внизу окна — он закрепится на нижней панели. Тап по слоту — использовать (или взять в руки).", 60)
                                                                ZMed.open(self)
                                                                # контекстный шаг 2: подсказка появляется уже внутри рюкзака, один раз (ТЗ п.14)
                                                                var _hb := false
                                                                for w in player["st"]["wounds"]:
                                                                    if int(w["bleed"]) > 0 and not bool(w["tq"]) and not bool(w["clamp"]):
                                                                        _hb = true
                                                                if tut != null and _hb:
                                                                    tut.hint("bleeding2", "drop", "ПЕРЕВЯЗКА", "Выберите БИНТ или ЖГУТ и перетащите на мерцающую зону тела. Или тап по предмету, затем тап по зоне.", 90)

func _refresh_med_window() -> void:
                                                                ZMed.refresh(self)

func _refresh_after_item_use() -> void:
                                                                # FIX7v2: после применения предмета обновляем активное окно (РЮКЗАК или КПК)
                                                                _refresh_med_window()
                                                                if kpk_win != null and is_instance_valid(kpk_win):
                                                                                                                                _refresh_kpk()

func _med_tap(item: String, _body_ctrl = null) -> void:
                                                                # тап-тап: выбираем предмет, затем зона; магазин — сразу в запас
                                                                if item == "keycard":
                                                                                                                                _toast("КЛЮЧ-КАРТА открывает технический шлюз — приложите её к сканеру")
                                                                                                                                return
                                                                if item.begins_with("mag_"):
                                                                                                                                var wmap := {"mag_pistol": "pistol", "mag_smg": "smg", "mag_shotgun": "shotgun", "mag_rifle": "rifle"}
                                                                                                                                var w: String = wmap.get(item, "pistol")
                                                                                                                                if G.z_take_item(item, 1):
                                                                                                                                                                                                var per: int = int(G.ZWEAPONS[w]["mag"])
                                                                                                                                                                                                G.zsave["ammo"][w] = int(G.zsave["ammo"].get(w, 0)) + per
                                                                                                                                                                                                _toast("Патроны «%s» в запас (+%d)" % [G.Z_WEAPON_NAMES[w], per])
                                                                                                                                                                                                _refresh_after_item_use()
                                                                                                                                return
                                                                if not G.ZITEMS.has(item) and item != "keycard":
                                                                                                                                _med_sel_item = ""
                                                                                                                                _toast("%s не требует лечения" % ZMed.item_name(item))
                                                                                                                                return
                                                                _med_sel_item = item
                                                                if _med_info_lbl != null and is_instance_valid(_med_info_lbl):
                                                                                                                                _med_info_lbl.text = "%s выбрано. Нажмите на часть тела или перетащите предмет на неё." % ZMed.item_name(item)
                                                                _refresh_quick_slots()
                                                                _toast("Выбрано: %s — нажмите на зону тела" % ZMed.item_name(item))

func _quick_use_item(item: String) -> void:
                                                                if item == "":
                                                                                                                                return
                                                                # FIX7: магазин из слота — сразу патроны в запас
                                                                if item.begins_with("mag_"):
                                                                                                                                var wmap := {"mag_pistol": "pistol", "mag_smg": "smg", "mag_shotgun": "shotgun", "mag_rifle": "rifle"}
                                                                                                                                var w: String = wmap.get(item, "pistol")
                                                                                                                                if G.z_take_item(item, 1):
                                                                                                                                                                                                var per: int = int(G.ZWEAPONS[w]["mag"])
                                                                                                                                                                                                G.zsave["ammo"][w] = int(G.zsave["ammo"].get(w, 0)) + per
                                                                                                                                                                                                _toast("Патроны «%s» в запас (+%d)" % [G.Z_WEAPON_NAMES[w], per])
                                                                                                                                                                                                _refresh_quick_slots()
                                                                                                                                return
                                                                if item == "keycard":
                                                                                                                                _toast("КЛЮЧ-КАРТА открывает шлюз — приложите к сканеру")
                                                                                                                                return
                                                                if int(G.zsave["inv"].get(item, 0)) <= 0:
                                                                                                                                _toast("Предмета нет в запасе — перетащите из КПК")
                                                                                                                                return
                                                                G.play_sfx("ui_click", -10.0)
                                                                _med_sel_item = item
                                                                if item in ["abx", "food"]:
                                                                                                                                med_apply_zone("torso")
                                                                                                                                return
                                                                if med_win != null and is_instance_valid(med_win):
                                                                                                                                _refresh_med_window()
                                                                else:
                                                                                                                                _open_med()

func _refresh_quick_slots() -> void:
                                                                for slot in quick_slots:
                                                                                                                                if is_instance_valid(slot):
                                                                                                                                                                                                var qs := slot as QuickSlot
                                                                                                                                                                                                qs.count = int(G.zsave["inv"].get(qs.item, 0)) if qs.item != "" else 0
                                                                                                                                                                                                qs.selected = qs.item != "" and _med_sel_item == qs.item
                                                                                                                                                                                                # FIX7: слот никогда не блокируется — пустой принимает drag,
                                                                                                                                                                                                # тап по пустому/пустому предмету мягко подсказывает
                                                                                                                                                                                                qs.disabled = false
                                                                                                                                                                                                qs.queue_redraw()

func _ensure_quick_list() -> void:
                                                                # FIX7: быстрые слоты СВОБОДНЫЕ — по умолчанию пустые, игрок сам
                                                                # перетаскивает из КПК что нужно (бинты, еду, магазины, карту).
                                                                var ok: bool = G.zsave.has("quick") and (G.zsave["quick"] is Array) and (G.zsave["quick"] as Array).size() == QUICK_ITEMS.size()
                                                                if not ok:
                                                                                                                                G.zsave["quick"] = ["", "", "", "", "", ""]
                                                                                                                                return
                                                                # разовая миграция: старый жёсткий пресет (еда в правой ячейке) → пустые слоты
                                                                var old_preset := true
                                                                for i in range(QUICK_ITEMS.size()):
                                                                                                                                if str(G.zsave["quick"][i]) != str(QUICK_ITEMS[i]):
                                                                                                                                                                                                old_preset = false
                                                                                                                                                                                                break
                                                                if old_preset:
                                                                                                                                G.zsave["quick"] = ["", "", "", "", "", ""]

func _assign_quick(i: int, item: String) -> void:
                                                                _ensure_quick_list()
                                                                if i < 0 or i >= (G.zsave["quick"] as Array).size() or item == "":
                                                                                                                                return
                                                                if str(G.zsave["quick"][i]) == item:
                                                                                                                                return
                                                                G.zsave["quick"][i] = item
                                                                if i < quick_slots.size() and is_instance_valid(quick_slots[i]):
                                                                                                                                (quick_slots[i] as QuickSlot).item = item
                                                                G.write_save()
                                                                _refresh_quick_slots()
                                                                _toast("%s — в слот %d" % [_inventory_item_name(item), i + 1])

func _quick_item_at(i: int) -> String:
                                                                var arr: Array = G.zsave.get("quick", QUICK_ITEMS)
                                                                if i >= 0 and i < arr.size():
                                                                                                                                return str(arr[i])
                                                                return ""

# ---------- FIX6: проверка магазина «на глаз» ----------
func _move_inv_slot(a: int, b: int) -> void:
        # FIX7v2: переложить предмет между ячейками рюкзака (поменять местами)
        G.z_sync_inv_slots()
        var slots: Array = G.zsave["inv_slots"]
        if a < 0 or b < 0 or a >= slots.size() or b >= slots.size() or a == b:
                return
        var tmp = slots[a]
        slots[a] = slots[b]
        slots[b] = tmp
        G.write_save()
        G.play_sfx("ui_click", -14.0, 1.25)
        _refresh_after_item_use()

func _swap_quick(a: int, b: int) -> void:
        # FIX7v2: поменять местами два быстрых слота
        _ensure_quick_list()
        var q: Array = G.zsave["quick"]
        if a < 0 or b < 0 or a >= q.size() or b >= q.size() or a == b:
                return
        var tmp = q[a]
        q[a] = q[b]
        q[b] = tmp
        G.write_save()
        G.play_sfx("ui_click", -14.0, 1.25)
        _refresh_quick_slots()
        _refresh_after_item_use()

func _quick_to_grid(qi: int, _gi: int) -> void:
        # FIX7v2: снять предмет с быстрого слота обратно в рюкзак
        _ensure_quick_list()
        var q: Array = G.zsave["quick"]
        if qi < 0 or qi >= q.size() or str(q[qi]) == "":
                return
        q[qi] = ""
        G.write_save()
        G.play_sfx("ui_click", -14.0, 0.9)
        _refresh_quick_slots()
        _refresh_after_item_use()

func _start_ammo_check() -> void:
                                                                if _ammo_check_t > 0.0:
                                                                                                                                return
                                                                _ammo_check_t = 1.0
                                                                _ammo_result_t = 0.0
                                                                G.play_sfx("z_dry", -16.0, 1.25)

func _tick_ammo_check(delta: float) -> void:
                                                                if _ammo_check_t > 0.0:
                                                                                                                                _ammo_check_t -= delta
                                                                                                                                if _ammo_check_t <= 0.0:
                                                                                                                                                                                                _ammo_check_t = -1.0
                                                                                                                                                                                                var mag := int(player["mag"])
                                                                                                                                                                                                if float(player["reload_t"]) > 0.0:
                                                                                                                                                                                                                                                                _ammo_result_txt = "перезарядка..."
                                                                                                                                                                                                                                                                _ammo_result_t = 1.6
                                                                                                                                                                                                elif mag <= 0:
                                                                                                                                                                                                                                                                _ammo_result_txt = "магазин пуст"
                                                                                                                                                                                                                                                                _ammo_result_t = 2.2
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                var errs: Array = [0, 1, -1, 2, -2]
                                                                                                                                                                                                                                                                var shown: int = maxi(1, mag + int(errs[randi() % errs.size()]))
                                                                                                                                                                                                                                                                _ammo_result_txt = "± %d %s" % [shown, _patr_plural(shown)]
                                                                                                                                                                                                                                                                _ammo_result_t = 2.6
                                                                                                                                                                                                G.play_sfx("z_reload", -20.0, 1.4)
                                                                if _ammo_result_t > 0.0:
                                                                                                                                _ammo_result_t -= delta

func _patr_plural(n: int) -> String:
                                                                if n % 100 >= 11 and n % 100 <= 14:
                                                                                                                                return "патронов"
                                                                var m := n % 10
                                                                if m == 1:
                                                                                                                                return "патрон"
                                                                if m >= 2 and m <= 4:
                                                                                                                                return "патрона"
                                                                return "патронов"

# ---------- FIX6: иконка/подпись кнопки-пузыря ----------
func _bubble_icon(kind: String) -> String:
                                                                match kind:
                                                                                                                                "capsule": return "hand"
                                                                                                                                "corpse", "cabinet", "crate": return "search"
                                                                                                                                "gear": return "bag"
                                                                                                                                "tablet": return "pda"
                                                                                                                                "scanner", "scanner_no": return "keycard"
                                                                                                                                "airlock", "airlock_locked", "door": return "door"
                                                                                                                                "stairs": return "stairs"
                                                                                                                                "revive", "rescue": return "heart"
                                                                return "hand"

func _bubble_caption(kind: String, holding: bool) -> String:
                                                                if holding:
                                                                                                                                match kind:
                                                                                                                                                                                                "door": return "дверь открывается..."
                                                                                                                                                                                                "airlock": return "шлюз открывается..."
                                                                                                                                                                                                "capsule": return "выбираемся..."
                                                                                                                                                                                                "stairs": return "поднимаемся..."
                                                                                                                                                                                                "scanner": return "сканирование..."
                                                                                                                                                                                                "revive": return "оживляем..."
                                                                                                                                                                                                "rescue": return "помогаем..."
                                                                                                                                return "..."
                                                                match kind:
                                                                                                                                "corpse": return "обыскать тело"
                                                                                                                                "cabinet": return "обыскать шкаф"
                                                                                                                                "crate": return "обыскать ящик"
                                                                                                                                "gear": return "снаряжение"
                                                                                                                                "tablet": return "планшет"
                                                                                                                                "scanner": return "приложить карту"
                                                                                                                                "scanner_no": return "нужна карта"
                                                                                                                                "airlock_locked": return "заперто"
                                                                return "держите"

# ---------- FIX6: отсечение невидимых спрайтов (ФПС на слабых устройствах) ----------
func _cull_offscreen() -> void:
                                                                if camera == null:
                                                                                                                                return
                                                                var vp := get_viewport_rect().size
                                                                var half_v: Vector2 = vp * 0.5 / maxf(0.01, camera.zoom.x) + Vector2(150, 150)
                                                                var crect := Rect2(camera.get_screen_center_position() - half_v, half_v * 2.0)
                                                                for z in zombies:
                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                continue
                                                                                                                                (z["spr"] as Sprite2D).visible = crect.has_point((z["spr"].position as Vector2))
                                                                for a in allies:
                                                                                                                                if not a["alive"]:
                                                                                                                                                                                                continue
                                                                                                                                (a["spr"] as Sprite2D).visible = crect.has_point((a["spr"].position as Vector2))
                                                                for pr in props:
                                                                                                                                if pr.has("spr") and is_instance_valid(pr["spr"]):
                                                                                                                                                                                                (pr["spr"] as Sprite2D).visible = crect.has_point((pr["spr"].position as Vector2))
                                                                for c in corpses:
                                                                                                                                if c.has("spr") and is_instance_valid(c["spr"]):
                                                                                                                                                                                                (c["spr"] as Sprite2D).visible = crect.has_point((c["spr"].position as Vector2))

class QuickSlot extends Button:
                                                                var btl = null
                                                                var item := ""
                                                                var index := 0
                                                                var count := 0
                                                                var selected := false

                                                                func _ready() -> void:
                                                                                                                                focus_mode = Control.FOCUS_NONE
                                                                                                                                if item != "" and G.ZITEMS.has(item):
                                                                                                                                                                                                tooltip_text = "%s\n%s" % [G.ZITEMS[item]["name"], G.ZITEMS[item]["desc"]]
                                                                                                                                # FIX6: лёгкая полупрозрачная плитка вместо «таблички»
                                                                                                                                add_theme_stylebox_override("normal", _slot_style(Color(0.050, 0.062, 0.056, 0.55), Color(0.24, 0.28, 0.26, 0.42)))
                                                                                                                                add_theme_stylebox_override("hover", _slot_style(Color(0.10, 0.125, 0.115, 0.78), ZUI.NEON_DIM))
                                                                                                                                add_theme_stylebox_override("pressed", _slot_style(Color(0.04, 0.09, 0.06, 0.85), ZUI.NEON_BRIGHT))
                                                                                                                                # короткая анимация нажатия: слот «вжимается» и мягко возвращается (ТЗ п.7)
                                                                                                                                button_down.connect(func():
                                                                                                                                    pivot_offset = size * 0.5
                                                                                                                                    scale = Vector2(0.93, 0.93))
                                                                                                                                button_up.connect(func():
                                                                                                                                    var tw := create_tween()
                                                                                                                                    tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

                                                                func _slot_style(fill: Color, edge: Color) -> StyleBoxFlat:
                                                                                                                                var style := StyleBoxFlat.new()
                                                                                                                                style.bg_color = fill
                                                                                                                                style.border_color = edge
                                                                                                                                style.set_border_width_all(2)
                                                                                                                                style.set_corner_radius_all(14)
                                                                                                                                style.shadow_color = Color(0, 0, 0, 0.30)
                                                                                                                                style.shadow_size = 4
                                                                                                                                return style

                                                                # ---------- FIX6: drag предмета из инвентаря в слот ----------
                                                                func _can_drop_data(_at: Vector2, data) -> bool:
                                                                                                                                return data is Dictionary and str(data.get("kind", "")) == "med_item" and str(data.get("item", "")) != ""

                                                                func _drop_data(_at: Vector2, data) -> void:
                                                                                                                                if btl != null and data.has("item"):
                                                                                                                                                                                                btl._assign_quick(index, str(data["item"]))

                                                                func _draw() -> void:
                                                                                                                                var tint := ZUI.NEON_BRIGHT if selected else Color(0.80, 0.83, 0.76) if count > 0 else Color(0.40, 0.43, 0.40)
                                                                                                                                if selected:
                                                                                                                                                                                                draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.12), true)
                                                                                                                                                                                                draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(ZUI.NEON_BRIGHT.r, ZUI.NEON_BRIGHT.g, ZUI.NEON_BRIGHT.b, 0.85), false, 1.5)
                                                                                                                                if item == "":
                                                                                                                                                                                                # FIX7: свободный слот — мягкий крестик-подсказка
                                                                                                                                                                                                var cc := Vector2(size.x * 0.5, size.y * 0.5 - 4.0)
                                                                                                                                                                                                draw_line(cc - Vector2(9, 0), cc + Vector2(9, 0), Color(0.33, 0.37, 0.35, 0.38), 2.0)
                                                                                                                                                                                                draw_line(cc - Vector2(0, 9), cc + Vector2(0, 9), Color(0.33, 0.37, 0.35, 0.38), 2.0)
                                                                                                                                                                                                pass   # пустой слот — только малоконтрастный крест, без подписи
                                                                                                                                                                                                return
                                                                                                                                # FIX7: слоты свободные — любые предметы (магазины, карта, лут), не только медицина
                                                                                                                                var texture = G.tex("z_i_" + item)
                                                                                                                                if texture == null:
                                                                                                                                                                                                texture = ZMedUI.item_icon(item)
                                                                                                                                if texture != null:
                                                                                                                                                                                                var icon_size := Vector2(52, 52)
                                                                                                                                                                                                var rect := Rect2(Vector2((size.x - icon_size.x) * 0.5, 7), icon_size)
                                                                                                                                                                                                draw_texture_rect(texture, rect, false, tint)
                                                                                                                                else:
                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(8, 42), ZMedUI.item_name(item).left(3), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 19, tint)
                                                                                                                                var short_names := {"band": "БИНТ", "tq": "ЖГУТ", "splint": "ШИНА", "morph": "МОРФ", "abx": "АНТ", "food": "ЕДА", "mag_pistol": "ПМ-МАГ", "mag_smg": "ПП-МАГ", "mag_shotgun": "ДР-МАГ", "mag_rifle": "ВН-МАГ", "keycard": "КАРТА"}
                                                                                                                                # плашка под названием (читаемость)
                                                                                                                                var lbl: String = short_names.get(item, ZMedUI.item_name(item))
                                                                                                                                draw_rect(Rect2(Vector2(4, size.y - 24), Vector2(size.x - 8, 20)), Color(0.02, 0.045, 0.035, 0.55), true)
                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(4, size.y - 9), lbl, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 14, tint)
                                                                                                                                # счётчик — маленькая пилюля в правом верхнем углу
                                                                                                                                var ccol := Color(0.74, 0.93, 0.80) if count > 0 else ZUI.FAINT
                                                                                                                                var ctxt := str(count)
                                                                                                                                var pw := 13.0 + ctxt.length() * 8.5
                                                                                                                                var pill := Rect2(Vector2(size.x - pw - 4, 4), Vector2(pw, 19))
                                                                                                                                if count > 0:
                                                                                                                                                                                                draw_rect(pill, Color(0.055, 0.07, 0.062, 0.92), true)
                                                                                                                                                                                                draw_rect(pill, Color(ZUI.NEON_DIM.r, ZUI.NEON_DIM.g, ZUI.NEON_DIM.b, 0.8), false, 1.0)
                                                                                                                                draw_string(ThemeDB.fallback_font, pill.position + Vector2(6, 14.5), ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ccol)

# ---------- FIX6: компактная иконка-кнопка (полочки вверху справа, слоты патронов) ----------
class ZIconButton extends Button:
                                                                var icon_name := ""
                                                                var caption := ""
                                                                var icon_col := ZUI.TEXT

                                                                func _init(iname := "", cap := "", msize := Vector2(80, 80), icol := ZUI.TEXT) -> void:
                                                                                                                                icon_name = iname
                                                                                                                                caption = cap
                                                                                                                                icon_col = icol
                                                                                                                                custom_minimum_size = msize
                                                                                                                                focus_mode = Control.FOCUS_NONE
                                                                                                                                var sb := StyleBoxFlat.new()
                                                                                                                                sb.bg_color = Color(0.05, 0.065, 0.058, 0.60)
                                                                                                                                sb.border_color = Color(0.32, 0.40, 0.34, 0.55)
                                                                                                                                sb.set_border_width_all(1)
                                                                                                                                sb.set_corner_radius_all(14)
                                                                                                                                sb.shadow_color = Color(0, 0, 0, 0.32)
                                                                                                                                sb.shadow_size = 5
                                                                                                                                var sbh := sb.duplicate()
                                                                                                                                sbh.bg_color = Color(0.10, 0.13, 0.11, 0.80)
                                                                                                                                sbh.border_color = ZUI.NEON
                                                                                                                                var sbp := sb.duplicate()
                                                                                                                                sbp.bg_color = Color(0.03, 0.045, 0.038, 0.88)
                                                                                                                                sbp.border_color = ZUI.NEON_DIM
                                                                                                                                add_theme_stylebox_override("normal", sb)
                                                                                                                                add_theme_stylebox_override("hover", sbh)
                                                                                                                                add_theme_stylebox_override("pressed", sbp)
                                                                                                                                add_theme_stylebox_override("disabled", sb.duplicate())

                                                                func _draw() -> void:
                                                                                                                                var tex := ZUI.icon(icon_name)
                                                                                                                                if tex != null:
                                                                                                                                                                                                var isz := 38.0
                                                                                                                                                                                                draw_texture_rect(tex, Rect2(Vector2((size.x - isz) * 0.5, (size.y - isz) * 0.5 - 7.0), Vector2(isz, isz)), false, icon_col)
                                                                                                                                if caption != "":
                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 8), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(0.62, 0.68, 0.62, 0.95))

# ---------- FIX7: лёгкая плашка «ПЕРЕЗАРЯДКА» над слотами ----------
class ReloadChip extends Control:
                                                                var btl = null
                                                                var _vis_cache := false

                                                                func _ready() -> void:
                                                                                                                                mouse_filter = Control.MOUSE_FILTER_IGNORE
                                                                                                                                set_process(true)

                                                                func _process(_delta: float) -> void:
                                                                        if btl == null:
                                                                                return
                                                                        var rt: float = float(btl.player.get("reload_t", 0.0))
                                                                        var reloading := rt > 0.0
                                                                        var spr = btl.player.get("spr", null)
                                                                        var spr_ok: bool = spr != null and is_instance_valid(spr) and (spr as Sprite2D).visible
                                                                        # FIX11: пустой магазин тоже подсвечиваем (кроме перезарядки и капсулы)
                                                                        var mag_empty: bool = int(btl.player.get("mag", 0)) <= 0 and not reloading and spr_ok and not bool(btl.in_capsule) and btl.battle_over == ""
                                                                        var need: bool = reloading or mag_empty
                                                                        if need != _vis_cache:
                                                                                _vis_cache = need
                                                                                visible = need
                                                                                queue_redraw()
                                                                        if need:
                                                                                queue_redraw()

                                                                func _draw() -> void:
                                                                        if btl == null or not visible:
                                                                                return
                                                                        var wd: Dictionary = G.ZWEAPONS.get(btl.player.get("weapon", "pistol"), {})
                                                                        var rt: float = float(btl.player.get("reload_t", 0.0))
                                                                        var w := size.x
                                                                        draw_rect(Rect2(0, 0, w, size.y), Color(0.04, 0.055, 0.048, 0.72), true)
                                                                        draw_rect(Rect2(0, 0, w, size.y), Color(0.35, 0.48, 0.40, 0.55), false, 1.2)
                                                                        var ic := ZUI.icon("reload")
                                                                        if rt > 0.0:
                                                                                # перезарядка: прогресс-полоса + мигающая подпись
                                                                                var total: float = maxf(0.2, float(wd.get("reload", 1.5)))
                                                                                var frac := clampf(1.0 - rt / total, 0.0, 1.0)
                                                                                draw_rect(Rect2(4, size.y - 7, (w - 8) * frac, 3.5), Color(0.5, 0.9, 0.65, 0.9), true)
                                                                                var bl := sin(Time.get_ticks_msec() * 0.009) * 0.5 + 0.5
                                                                                draw_string(ThemeDB.fallback_font, Vector2(10, 21), "ПЕРЕЗАРЯДКА", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.9, 0.7, 0.6 + 0.4 * bl))
                                                                                if ic != null:
                                                                                        draw_texture_rect(ic, Rect2(w - 26, 4, 18, 18), false, Color(0.6, 0.9, 0.7, 0.85))
                                                                        else:
                                                                                # FIX11: магазин пуст — янтарная (или красная) пульсирующая плашка
                                                                                var reserve: int = int(G.zsave["ammo"].get(str(btl.player.get("weapon", "pistol")), 0))
                                                                                var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
                                                                                var has_res := reserve > 0
                                                                                var col := Color(0.95, 0.72, 0.30, 0.55 + 0.45 * pulse) if has_res else Color(0.95, 0.42, 0.32, 0.55 + 0.45 * pulse)
                                                                                var txt := "МАГАЗИН ПУСТ — ПЕРЕЗАРЯДКА (R)" if has_res else "ПАТРОНОВ НЕТ — ИЩИ ЗАПАСЫ"
                                                                                draw_rect(Rect2(4, size.y - 7, w - 8, 3.5), Color(col.r, col.g, col.b, 0.5), true)
                                                                                draw_string(ThemeDB.fallback_font, Vector2(10, 21), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
                                                                                if ic != null:
                                                                                        draw_texture_rect(ic, Rect2(w - 26, 4, 18, 18), false, col)


# ---------- FIX6: круглая кнопка-«пузырь» ПРЯМО НА ОБЪЕКТЕ (удержание — прогресс-дуга) ----------
class InteractBubble extends Button:
                                                                var btl = null
                                                                var icon_name := ""
                                                                var cap_idle := ""
                                                                var cap_hold := ""
                                                                var hold_time := 0.0
                                                                var _filling := false
                                                                var _fill_t := 0.0
                                                                var _pulse_t := 0.0

                                                                func _init() -> void:
                                                                                                                                custom_minimum_size = Vector2(132, 128)
                                                                                                                                focus_mode = Control.FOCUS_NONE
                                                                                                                                action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
                                                                                                                                var sb := StyleBoxFlat.new()
                                                                                                                                sb.bg_color = Color(0, 0, 0, 0)
                                                                                                                                sb.border_color = Color(0, 0, 0, 0)
                                                                                                                                add_theme_stylebox_override("normal", sb)
                                                                                                                                add_theme_stylebox_override("hover", sb.duplicate())
                                                                                                                                add_theme_stylebox_override("pressed", sb.duplicate())

                                                                func _ready() -> void:
                                                                                                                                set_process(true)
                                                                                                                                button_down.connect(func(): _filling = true)
                                                                                                                                button_up.connect(func(): _filling = false)

                                                                func setup(iname: String, c_idle: String, c_hold: String, hold: float) -> void:
                                                                                                                                if iname != icon_name or c_idle != cap_idle or c_hold != cap_hold or absf(hold - hold_time) > 0.01:
                                                                                                                                                                                                icon_name = iname
                                                                                                                                                                                                cap_idle = c_idle
                                                                                                                                                                                                cap_hold = c_hold
                                                                                                                                                                                                hold_time = hold
                                                                                                                                                                                                _fill_t = 0.0
                                                                                                                                                                                                _filling = false
                                                                                                                                                                                                queue_redraw()

                                                                func _process(delta: float) -> void:
                                                                                                                                _pulse_t += delta
                                                                                                                                if btl == null:
                                                                                                                                                                                                return
                                                                                                                                # держимся на объекте в мире (экранные координаты)
                                                                                                                                if not btl.cur_interact.is_empty():
                                                                                                                                                                                                var pp: Vector2 = btl.cur_interact.get("pos", Vector2.ZERO)
                                                                                                                                                                                                var cam: Camera2D = btl.camera
                                                                                                                                                                                                if cam != null:
                                                                                                                                                                                                                                                                var vp := get_viewport_rect().size
                                                                                                                                                                                                                                                                var sp: Vector2 = (pp - cam.get_screen_center_position()) * cam.zoom.x + vp * 0.5
                                                                                                                                                                                                                                                                position = sp - Vector2(66, 96)
                                                                                                                                # удержание — заполняем дугу
                                                                                                                                if hold_time > 0.0:
                                                                                                                                                                                                if _filling and not btl.cur_interact.is_empty():
                                                                                                                                                                                                                                                                _fill_t += delta
                                                                                                                                                                                                                                                                if int((_fill_t - delta) * 16.0) != int(_fill_t * 16.0):
                                                                                                                                                                                                                                                                                                                                queue_redraw()
                                                                                                                                                                                                                                                                if _fill_t >= hold_time:
                                                                                                                                                                                                                                                                                                                                _fill_t = 0.0
                                                                                                                                                                                                                                                                                                                                _filling = false
                                                                                                                                                                                                                                                                                                                                emit_signal("pressed")
                                                                                                                                                                                                elif _fill_t > 0.0:
                                                                                                                                                                                                                                                                _fill_t = maxf(0.0, _fill_t - delta * 2.5)
                                                                                                                                                                                                                                                                queue_redraw()

                                                                func _draw() -> void:
                                                                                                                                var c := Vector2(size.x * 0.5, 50.0)
                                                                                                                                var r := 40.0
                                                                                                                                var pulse := 0.5 + 0.5 * sin(_pulse_t * 4.0)
                                                                                                                                var frac := clampf(_fill_t / hold_time, 0.0, 1.0) if hold_time > 0.0 else 0.0
                                                                                                                                draw_circle(c + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.38))
                                                                                                                                draw_circle(c, r, Color(0.04, 0.055, 0.048, 0.80))
                                                                                                                                draw_arc(c, r, 0, TAU, 40, Color(0.45, 0.55, 0.47, 0.75), 2.0)
                                                                                                                                if frac > 0.0:
                                                                                                                                                                                                draw_circle(c, r, Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.08 + 0.14 * frac))
                                                                                                                                                                                                draw_arc(c, r - 4.5, -PI / 2.0, -PI / 2.0 + TAU * frac, 34, Color(0.5, 0.95, 0.65, 0.95), 5.0)
                                                                                                                                else:
                                                                                                                                                                                                draw_arc(c, r + 2.5 + pulse * 2.0, 0, TAU, 40, Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.22 + 0.22 * pulse), 1.6)
                                                                                                                                var tex := ZUI.icon(icon_name)
                                                                                                                                if tex != null:
                                                                                                                                                                                                var isz := 38.0
                                                                                                                                                                                                draw_texture_rect(tex, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color(0.92, 0.95, 0.88, 0.96))
                                                                                                                                var cap := cap_hold if (hold_time > 0.0 and _filling and frac > 0.12) else cap_idle
                                                                                                                                if cap != "":
                                                                                                                                                                                                draw_rect(Rect2(size.x * 0.5 - 64, 94, 128, 22), Color(0.02, 0.035, 0.025, 0.74), true)
                                                                                                                                                                                                draw_rect(Rect2(size.x * 0.5 - 64, 94, 128, 22), Color(0.35, 0.45, 0.37, 0.5), false, 1.0)
                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 62, 109), cap, HORIZONTAL_ALIGNMENT_CENTER, 124, 11, Color(0.85, 0.92, 0.82, 0.96))

func _quick_item_refresh(delta: float) -> void:
                                                                quick_refresh_t -= delta
                                                                if quick_refresh_t <= 0.0:
                                                                                                                                quick_refresh_t = 0.25
                                                                                                                                _refresh_quick_slots()

func _inspect_zone(zone: String) -> void:
                                                                if _med_info_lbl == null or not is_instance_valid(_med_info_lbl):
                                                                                                                                return
                                                                var st: Dictionary = player["st"]
                                                                var body_pct := roundi(float(st["body"].get(zone, 1.0)) * 100.0)
                                                                var notes: Array[String] = []
                                                                var bleed := 0
                                                                for wound in st["wounds"]:
                                                                                                                                if wound["zone"] == zone and int(wound["bleed"]) > 0 and not wound["tq"] and not wound["clamp"]:
                                                                                                                                                                                                bleed += int(wound["bleed"])
                                                                if bleed > 0:
                                                                                                                                notes.append("Активное кровотечение")
                                                                if st["frac"].has(zone):
                                                                                                                                notes.append("Перелом")
                                                                if body_pct < 55:
                                                                                                                                notes.append("Сильное повреждение тканей")
                                                                if notes.is_empty():
                                                                                                                                notes.append("Явных повреждений нет")
                                                                var advice := ""
                                                                if st["frac"].has(zone):
                                                                                                                                advice = "Лечение: наложить шину."
                                                                elif bleed > 0 and zone in ["la", "ra", "ll", "rl"]:
                                                                                                                                advice = "Лечение: жгут остановит кровотечение; бинт восстановит ткани."
                                                                elif bleed > 0:
                                                                                                                                advice = "Лечение: бинт на эту зону, затем повторный осмотр."
                                                                elif body_pct < 100:
                                                                                                                                advice = "Лечение: бинт восстановит часть целости."
                                                                _med_info_lbl.text = "%s\nЦелость: %d%%\n%s\n%s" % [Med.ZONE_RU.get(zone, zone), body_pct, ", ".join(notes), advice]

func med_apply_zone(zone: String) -> void:
                                                                if _med_sel_item == "":
                                                                                                                                _toast("Сначала выберите предмет в инвентаре")
                                                                                                                                return
                                                                var item := _med_sel_item
                                                                if item == "abx":
                                                                                                                                if G.z_take_item("abx", 1):
                                                                                                                                                                                                player["infect"] = maxf(0.0, float(player["infect"]) - 62.0)
                                                                                                                                                                                                _toast("Антибиотик принят: заражение подавлено")
                                                                                                                                                                                                G.play_sfx("z_pickup", -8.0)
                                                                                                                                _med_sel_item = ""
                                                                                                                                _refresh_after_item_use()
                                                                                                                                return
                                                                if item == "food":
                                                                                                                                if G.z_take_item("food", 1):
                                                                                                                                                                                                var st: Dictionary = player["st"]
                                                                                                                                                                                                var z: String = Med.worst_zone({"st": st})
                                                                                                                                                                                                st["body"][z] = minf(1.0, float(st["body"][z]) + 0.16)
                                                                                                                                                                                                st["stress"] = maxf(0.0, float(st["stress"]) - 12.0)
                                                                                                                                                                                                _toast("Сухпаёк съеден: силы восполняются")
                                                                                                                                                                                                G.play_sfx("z_pickup", -8.0)
                                                                                                                                _med_sel_item = ""
                                                                                                                                _refresh_after_item_use()
                                                                                                                                return
                                                                var res: String = Med.treat_zone({"st": player["st"]}, item, zone)
                                                                if res == "":
                                                                                                                                G.z_take_item(item, 1)
                                                                                                                                _toast("%s → %s: применено" % [G.ZITEMS[item]["name"], Med.ZONE_RU[zone]])
                                                                                                                                G.play_sfx("z_pickup", -8.0)
                                                                                                                                # учебная задача бункера
                                                                                                                                if is_bunker:
                                                                                                                                                                                                var st2: Dictionary = player["st"]
                                                                                                                                                                                                var ra_bleeds := false
                                                                                                                                                                                                for w in st2["wounds"]:
                                                                                                                                                                                                                                                                if w["zone"] == "ra" and w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                                                                                                                                                                                                                                                                                                                                ra_bleeds = true
                                                                                                                                                                                                if not ra_bleeds and float(st2["body"]["ra"]) >= 0.69 and not _obj_done("heal"):
                                                                                                                                                                                                                                                                _complete_objective("heal")
                                                                                                                                                                                                                                                                if tut != null and not _obj_done("gear"):
                                                                                                                                                                                                                                                                                                                                tut.hint("gear_go", "bag", "СНАРЯЖЕНИЕ НА СТОЛЕ", "Рана перевязана. Теперь заберите со стола КПК, пистолет Макарова, 2 магазина и фонарик — без них в коридор нельзя.", 90)
                                                                else:
                                                                                                                                _toast(res)
                                                                                                                                G.play_sfx("z_dry", -14.0, 0.8)
                                                                _med_sel_item = ""
                                                                _refresh_med_window()

# ---------- КПК (FIX6: субнатика-стиль — вкладки слева, тело игрока и инвентарь) ----------
func _open_kpk() -> void:
                                                                if kpk_win != null and is_instance_valid(kpk_win):
                                                                                                                                return
                                                                if tut != null:
                                                                                                                                # FIX7: свободные слоты — объясняем один раз
                                                                                                                                tut.hint("quickbar", "bag", "РЮКЗАК: ЯЧЕЙКИ", "Перетащите предмет из ячеек в БЫСТРЫЕ СЛОТЫ внизу окна — он закрепится на нижней панели. Тап по слоту — использовать (или взять в руки).", 60)
                                                                paused = true
                                                                var w := ZUI.open_window(ui_layer, "КПК «ЗАРЯ» · ПОЛЕВОЙ ТЕРМИНАЛ", Vector2(980, 0))
                                                                kpk_win = w["overlay"]
                                                                kpk_win.tree_exiting.connect(_kpk_closed)
                                                                var vb: VBoxContainer = w["vb"]
                                                                var body := HBoxContainer.new()
                                                                body.add_theme_constant_override("separation", 14)
                                                                vb.add_child(body)
                                                                # левая колонка: вкладки-«полочки»
                                                                var tabs := VBoxContainer.new()
                                                                tabs.add_theme_constant_override("separation", 8)
                                                                tabs.custom_minimum_size = Vector2(188, 0)
                                                                body.add_child(tabs)
                                                                var sync := ZUI.label("ЗАРЯ / ПОЛЕВОЙ КОМПЬЮТЕР\nЗАЩИЩЁННЫЙ КАНАЛ · АКБ ▰▰▰▰▱", 10, Color(0.55, 0.78, 0.58))
                                                                tabs.add_child(sync)
                                                                # правая область: страницы
                                                                var content := PanelContainer.new()
                                                                content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                                                content.size_flags_vertical = Control.SIZE_EXPAND_FILL
                                                                content.add_theme_stylebox_override("panel", ZUI.panel_style(Color(0.045, 0.06, 0.05, 0.92), Color(0.17, 0.27, 0.18), 14))
                                                                body.add_child(content)
                                                                var pages := {}
                                                                for pkey in ["inv", "tasks", "diary", "squad"]:
                                                                                                                                var pg := VBoxContainer.new()
                                                                                                                                pg.name = str(pkey)
                                                                                                                                pg.add_theme_constant_override("separation", 8)
                                                                                                                                pg.visible = pkey == "inv"
                                                                                                                                content.add_child(pg)
                                                                                                                                pages[pkey] = pg
                                                                _kpk_fill_inv(pages["inv"])
                                                                _kpk_fill_tasks(pages["tasks"])
                                                                _kpk_fill_diary(pages["diary"])
                                                                _kpk_fill_squad(pages["squad"])
                                                                for tdef in [["inv", "СНАРЯЖЕНИЕ", "bag"], ["tasks", "ЗАДАНИЯ", "check"], ["diary", "ЖУРНАЛ", "map"], ["squad", "ОТРЯД", "shield"]]:
                                                                                                                                var tkey: String = tdef[0]
                                                                                                                                var tb := ZUI.ZButton.new(str(tdef[1]), Vector2(184, 54), tkey == "inv", 15, str(tdef[2]))
                                                                                                                                tb.pressed.connect(func():
                                                                                                                                                                                                G.play_sfx("ui_click", -10.0)
                                                                                                                                                                                                for k in pages:
                                                                                                                                                                                                                                                                (pages[k] as Control).visible = k == tkey)
                                                                                                                                tabs.add_child(tb)

func _kpk_fill_inv(pg: VBoxContainer) -> void:
                                                                # статус-чипы (как в рюкзаке)
                                                                pg.add_child(ZMedUI._status_row(self))
                                                                pg.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                var main_row := HBoxContainer.new()
                                                                main_row.add_theme_constant_override("separation", 16)
                                                                pg.add_child(main_row)
                                                                # --- центр: тело игрока + осмотр ---
                                                                var left := VBoxContainer.new()
                                                                left.add_theme_constant_override("separation", 6)
                                                                main_row.add_child(left)
                                                                var doll := ZMedUI.BodyDoll.new()
                                                                doll.btl = self
                                                                doll.custom_minimum_size = Vector2(250, 340)
                                                                left.add_child(doll)
                                                                var inspect := PanelContainer.new()
                                                                inspect.custom_minimum_size = Vector2(250, 110)
                                                                inspect.add_theme_stylebox_override("panel", ZUI.panel_style(Color(0.05, 0.06, 0.055, 0.92), ZUI.BORDER_SOFT, 8))
                                                                left.add_child(inspect)
                                                                var ivb := VBoxContainer.new()
                                                                ivb.add_theme_constant_override("separation", 3)
                                                                inspect.add_child(ivb)
                                                                var info_lbl := ZUI.wrap_label(ZMedUI._default_info(self), 12, ZUI.TEXT, 210.0)
                                                                info_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
                                                                ivb.add_child(info_lbl)
                                                                # --- право: инвентарь (drag на тело и в нижние слоты) ---
                                                                var right := VBoxContainer.new()
                                                                right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                                                right.add_theme_constant_override("separation", 6)
                                                                main_row.add_child(right)
                                                                var head := HBoxContainer.new()
                                                                head.add_theme_constant_override("separation", 8)
                                                                right.add_child(head)
                                                                var bag_ic := ZUI.icon_rect("bag", 20, ZUI.NEON)
                                                                bag_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                                                                head.add_child(bag_ic)
                                                                var tl := ZUI.label("ИНВЕНТАРЬ — ячейки: тащите на тело, между ячейками или в быстрые слоты", 14, ZUI.NEON_BRIGHT)
                                                                tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                                                head.add_child(tl)
                                                                right.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                # FIX7v2: сетка-ячейки как в Майнкрафте + быстрые слоты внутри окна
                                                                var grid_wrap := ZMedUI.InvGrid.new()
                                                                grid_wrap.btl = self
                                                                grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                                                right.add_child(grid_wrap)
                                                                grid_wrap.add_child(ZMedUI.build_inv_grid(self))
                                                                # --- оружие: выбор в инвентаре (кнопки ОРУЖИЕ больше нет) ---
                                                                right.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                var wh := HBoxContainer.new()
                                                                wh.add_theme_constant_override("separation", 8)
                                                                right.add_child(wh)
                                                                var wic := ZUI.icon_rect("pistol", 20, ZUI.WARN)
                                                                wic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                                                                wh.add_child(wic)
                                                                wh.add_child(ZUI.label("ОРУЖИЕ — выберите в инвентаре", 13, ZUI.WARN))
                                                                var owned: Array = G.zsave["weapons"]
                                                                for wi in range(owned.size()):
                                                                                                                                var wname: String = str(owned[wi])
                                                                                                                                var wd: Dictionary = G.ZWEAPONS.get(wname, {})
                                                                                                                                var wrow := HBoxContainer.new()
                                                                                                                                wrow.add_theme_constant_override("separation", 10)
                                                                                                                                right.add_child(wrow)
                                                                                                                                var cur: bool = wname == str(player["weapon"])
                                                                                                                                var wcol := ZUI.NEON_BRIGHT if cur else ZUI.TEXT
                                                                                                                                wrow.add_child(ZUI.label(G.Z_WEAPON_NAMES.get(wname, wname), 14, wcol))
                                                                                                                                var reserve: int = int(G.zsave["ammo"].get(wname, 0))
                                                                                                                                var mag_now := int(player["mag"]) if cur else 0
                                                                                                                                wrow.add_child(ZUI.label("%d/%d · запас %d" % [mag_now, int(wd.get("mag", 0)), reserve], 12, ZUI.MUTED))
                                                                                                                                if not cur:
                                                                                                                                                                                                var take := ZUI.ZButton.new("ВЗЯТЬ", Vector2(96, 40), false, 12)
                                                                                                                                                                                                take.pressed.connect(func():
                                                                                                                                                                                                                                                                                                G.play_sfx("ui_click", -10.0)
                                                                                                                                                                                                                                                                                                _select_weapon(wi)
                                                                                                                                                                                                                                                                                                _refresh_kpk())
                                                                                                                                                                                                wrow.add_child(take)
                                                                                                                                else:
                                                                                                                                                                                                wrow.add_child(ZUI.label("· В РУКАХ", 12, ZUI.NEON_DIM))
                                                                var hint_l := ZUI.wrap_label("Лечение: перетащите бинт/жгут на зону тела. Магазины: тап — патроны в запас.", 12, ZUI.FAINT, 520.0)
                                                                pg.add_child(hint_l)
                                                                _med_doll = doll
                                                                _med_info_lbl = info_lbl

func _kpk_fill_tasks(pg: VBoxContainer) -> void:
                                                                pg.add_child(ZUI.label("ОПЕРАЦИОННЫЕ ЗАДАЧИ · %s" % sector_name.to_upper(), 14, ZUI.NEON_BRIGHT))
                                                                pg.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                for objective in objectives:
                                                                                                                                var task_row := HBoxContainer.new()
                                                                                                                                task_row.add_theme_constant_override("separation", 8)
                                                                                                                                pg.add_child(task_row)
                                                                                                                                var done: bool = bool(objective["done"])
                                                                                                                                var mk := ZUI.icon_rect("check", 18, ZUI.NEON if done else ZUI.WARN)
                                                                                                                                mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                                                                                                                                task_row.add_child(mk)
                                                                                                                                task_row.add_child(ZUI.wrap_label(objective["text"], 13, ZUI.NEON_DIM if done else ZUI.TEXT, 640.0))
                                                                pg.add_child(ZUI.label("ХАБАР %d   ·   БОИ %d   ·   ПОБЕДЫ %d   ·   УБИТО %d" % [int(G.zsave["bank"]), int(G.zsave["battles"]), int(G.zsave["wins"]), kills], 11, Color(0.65, 0.76, 0.62)))

func _kpk_fill_diary(pg: VBoxContainer) -> void:
                                                                pg.add_child(ZUI.label("АРХИВ ЗАПИСЕЙ · КОМАНДИР", 14, ZUI.NEON_BRIGHT))
                                                                pg.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                var diary_n: int = int(G.zsave.get("diary", 0))
                                                                if diary_n <= 0:
                                                                                                                                pg.add_child(ZUI.label("Журнал пока пуст.", 13, ZUI.FAINT))
                                                                else:
                                                                                                                                for i in range(1, diary_n + 1):
                                                                                                                                                                                                if G.ZDIARY.has(i):
                                                                                                                                                                                                                                                                var entry_panel := PanelContainer.new()
                                                                                                                                                                                                                                                                entry_panel.add_theme_stylebox_override("panel", ZUI.panel_style(Color(0.065, 0.085, 0.065), Color(0.18, 0.27, 0.18), 10))
                                                                                                                                                                                                                                                                pg.add_child(entry_panel)
                                                                                                                                                                                                                                                                entry_panel.add_child(ZUI.wrap_label(G.ZDIARY[i], 12, Color(0.78, 0.84, 0.74), 660.0))

func _kpk_fill_squad(pg: VBoxContainer) -> void:
                                                                pg.add_child(ZUI.label("ЛИЧНЫЙ СОСТАВ", 14, ZUI.NEON_BRIGHT))
                                                                pg.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                                                                if allies.is_empty():
                                                                                                                                pg.add_child(ZUI.label("Бойцов нет. Наём доступен в лагерях.", 13, ZUI.FAINT))
                                                                for ally in allies:
                                                                                                                                var ally_status := "В СТРОЮ" if ally["alive"] and not ally["down"] else ("РАНЕН" if ally["alive"] else "ПОГИБ")
                                                                                                                                pg.add_child(ZUI.label("%s   /   %s" % [ally["callsign"], ally_status], 14, ZUI.TEXT if ally["alive"] else ZUI.ALERT))
                                                                pg.add_child(ZUI.label("СИНХРОНИЗАЦИЯ: ЛОКАЛЬНЫЙ РЕЖИМ · ДАННЫЕ СОХРАНЕНЫ", 10, ZUI.FAINT))

func _refresh_kpk() -> void:
                                                                # пересборка КПК (после смены оружия) — окно перезарождается
                                                                if kpk_win != null and is_instance_valid(kpk_win):
                                                                                                                                ZUI.close_window(kpk_win)
                                                                                                                                kpk_win = null
                                                                                                                                paused = false
                                                                                                                                _open_kpk()

# ---------- пауза ----------
# FIX11: окно потеряло фокус — безопасная авто-пауза
func _notification(what: int) -> void:
        if what == NOTIFICATION_APPLICATION_FOCUS_OUT and battle_over == "" and not paused and ui_layer != null and is_instance_valid(ui_layer) and _desktop_input():
                _open_pause()

func _open_pause() -> void:
        if pause_win != null and is_instance_valid(pause_win):
                return
        if ui_layer == null or not is_instance_valid(ui_layer):
                return
        paused = true
        var w := ZUI.open_window(ui_layer, "ПАУЗА", Vector2(520, 0))
        pause_win = w["overlay"]
        pause_win.tree_exiting.connect(_pause_closed)
        var vb: VBoxContainer = w["vb"]
        var cont := ZUI.ZButton.new("ПРОДОЛЖИТЬ", Vector2(460, 54), true, 16)
        cont.pressed.connect(func():
                G.play_sfx("ui_click", -8.0)
                ZUI.close_window(pause_win))
        vb.add_child(cont)
        # ---------- FIX11: настройки звука и экрана прямо в паузе ----------
        var set_row := HBoxContainer.new()
        set_row.add_theme_constant_override("separation", 16)
        vb.add_child(set_row)
        var col1 := VBoxContainer.new()
        col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col1.add_theme_constant_override("separation", 4)
        set_row.add_child(col1)
        var col2 := VBoxContainer.new()
        col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col2.add_theme_constant_override("separation", 4)
        set_row.add_child(col2)
        col1.add_child(ZUI.label("МУЗЫКА · %d%%" % roundi(G.music_vol * 100.0), 12, ZUI.MUTED))
        var msl := HSlider.new()
        msl.min_value = 0.0
        msl.max_value = 1.0
        msl.step = 0.05
        msl.value = G.music_vol
        msl.custom_minimum_size = Vector2(0, 22)
        msl.focus_mode = Control.FOCUS_NONE
        msl.value_changed.connect(func(v: float):
                G.set_music_vol(v))
        col1.add_child(msl)
        col2.add_child(ZUI.label("ЗВУКИ · %d%%" % roundi(G.sfx_vol * 100.0), 12, ZUI.MUTED))
        var ssl := HSlider.new()
        ssl.min_value = 0.0
        ssl.max_value = 1.0
        ssl.step = 0.05
        ssl.value = G.sfx_vol
        ssl.custom_minimum_size = Vector2(0, 22)
        ssl.focus_mode = Control.FOCUS_NONE
        ssl.value_changed.connect(func(v: float):
                G.set_sfx_vol(v))
        ssl.drag_ended.connect(func(_c: bool):
                G.play_sfx("ui_click", -8.0))
        col2.add_child(ssl)
        var fs := CheckButton.new()
        fs.text = "Полный экран"
        fs.button_pressed = G.fullscreen
        fs.focus_mode = Control.FOCUS_NONE
        fs.toggled.connect(func(on: bool):
                G.play_sfx("ui_click", -8.0)
                G.set_fullscreen(on))
        vb.add_child(fs)
        var hint := ZUI.wrap_label("УПРАВЛЕНИЕ: левый стик — движение, правый — прицел; доводите правый стик до упора — огонь, ДВОЙНОЙ ТАП по правому стику — перезарядка, ДВОЙНОЙ ТАП по левому стику — бег (отпустили стик — снова шаг; на ПК — Shift). ПК: WASD + мышь, ЛКМ — огонь, R — перезарядка, E — действие (или кнопка на объекте), F — фонарик, G — дым, ESC — пауза.\nРЮКЗАК/КПК — справа ячейки рюкзака: перетаскивайте предметы между ячейками, на зону тела или в строку БЫСТРЫХ СЛОТОВ внутри окна; выбрав предмет в слоте, вы держите его в руках. Кнопка с патроном у слотов — проверить магазин на глаз («± N»).", 13, ZUI.MUTED, 460.0)
        vb.add_child(hint)
        var quit := ZUI.ZButton.new("СДАТЬСЯ И ВЫЙТИ В ШТАБ", Vector2(460, 50), false, 14)
        quit.pressed.connect(func():
                G.play_sfx("ui_click", -8.0)
                _lose())
        vb.add_child(quit)

class FxDraw extends Node2D:
        # FIX11: трассеры, вспышки выстрелов и брызги крови. Раньше эти массивы
        # только заполнялись и тикали — но нигде не рисовались (выстрел «без ствола»).
        var btl = null

        func _ready() -> void:
                if btl == null:
                        btl = get_parent()

        func _draw() -> void:
                if btl == null:
                        return
                # трассеры: тонкая линия + яркая головка
                for tr in btl.tracer_fx:
                        var k: float = clampf(float(tr["t"]) / 0.07, 0.0, 1.0)
                        draw_line(tr["a"], tr["b"], Color(1.0, 0.9, 0.62, 0.55 * k), 1.6)
                        draw_circle(tr["b"], 2.2, Color(1.0, 0.95, 0.8, 0.7 * k))
                # вспышки выстрелов и искр: тёплое ядро + мягкий ореол
                for fl in btl.flash_fx:
                        var k2: float = clampf(float(fl["t"]) / 0.1, 0.0, 1.0)
                        var fp: Vector2 = fl["pos"]
                        var r1 := 5.0 + 7.0 * (1.0 - k2)
                        draw_circle(fp, r1 * 1.8, Color(1.0, 0.75, 0.35, 0.16 * k2))
                        draw_circle(fp, r1, Color(1.0, 0.88, 0.55, 0.75 * k2))
                        draw_circle(fp, r1 * 0.45, Color(1.0, 1.0, 0.9, 0.9 * k2))
                # брызги крови при попадании: короткие «снопы» вдоль направления
                for bb in btl.blood_burst:
                        var k3: float = clampf(float(bb["t"]) / 0.3, 0.0, 1.0)
                        var bp: Vector2 = bb["pos"]
                        var ba: float = float(bb["ang"])
                        for jj in range(5):
                                var sa := ba + (float(jj) - 2.0) * 0.28
                                var ln := (9.0 + 7.0 * float(jj % 3)) * (0.4 + 0.6 * k3)
                                var s0 := bp + Vector2.from_angle(sa) * 2.0
                                draw_line(s0, s0 + Vector2.from_angle(sa) * ln, Color(0.55, 0.07, 0.05, 0.75 * k3), 2.0)
                # v2.8: гильзы — упавшие лежат на полу, летящие катятся
                for sh in btl.shells_static:
                        var cr: float = float(sh["rot"])
                        var cp: Vector2 = sh["pos"]
                        var half: Vector2 = Vector2.from_angle(cr) * (2.3 * float(sh["k"]))
                        draw_line(cp - half, cp + half, Color(0.72, 0.56, 0.24, 0.85), 1.8 * float(sh["k"]))
                        draw_circle(cp + half, 0.9 * float(sh["k"]), Color(0.5, 0.38, 0.16, 0.85))
                for sh2 in btl.shells:
                        var cr2: float = float(sh2["rot"])
                        var cp2: Vector2 = sh2["pos"]
                        draw_line(cp2 - Vector2.from_angle(cr2) * 2.6, cp2 + Vector2.from_angle(cr2) * 2.6, Color(0.88, 0.7, 0.33, 0.95), 2.0)
        
        func _process(delta: float) -> void:
                if btl == null:
                        return
                if btl.shells.is_empty():
                        return
                var done: Array = []
                for sh in btl.shells:
                        sh["t"] = float(sh["t"]) + delta
                        sh["pos"] = (sh["pos"] as Vector2) + (sh["vel"] as Vector2) * delta
                        sh["vel"] = (sh["vel"] as Vector2) * exp(-delta * 5.2)
                        sh["rot"] = float(sh["rot"]) + float(sh["vr"]) * delta
                        sh["vr"] = float(sh["vr"]) * exp(-delta * 5.2)
                        if (sh["vel"] as Vector2).length() < 10.0 or float(sh["t"]) > 1.4:
                                done.append(sh)
                for sh3 in done:
                        btl.shells.erase(sh3)
                        btl.shells_static.append({"pos": sh3["pos"], "rot": sh3["rot"], "k": sh3["k"]})
                while btl.shells_static.size() > 70:
                        btl.shells_static.pop_front()
                queue_redraw()
# ================= ОТРИСОВКА ПОЛА/СТЕН (внутренний класс) =================
class FloorDraw extends Node2D:
                                                                # ОПТИМИЗАЦИЯ FPS: плитки пола нарезаны на чанки 512x512.
                                                                # Каждый чанк — отдельный canvas item, GPU отсекает невидимые чанки.
                                                                # Стены/декор — один лёгкий элемент (несколько сотен квадов).
                                                                const CHUNK := 1024.0
                                                                var btl = null

                                                                func _ready() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                btl = get_parent()
                                                                                                                                _build_chunks()

                                                                func _build_chunks() -> void:
                                                                                                                                for c in get_children():
                                                                                                                                                                                                c.queue_free()
                                                                                                                                var ms: Vector2 = btl.map_size
                                                                                                                                var nx := int(ceil(ms.x / CHUNK))
                                                                                                                                var ny := int(ceil(ms.y / CHUNK))
                                                                                                                                for iy in ny:
                                                                                                                                                                                                for ix in nx:
                                                                                                                                                                                                                                                                var ch := FloorChunk.new()
                                                                                                                                                                                                                                                                ch.btl = btl
                                                                                                                                                                                                                                                                ch.rect = Rect2(float(ix) * CHUNK, float(iy) * CHUNK, CHUNK, CHUNK)
                                                                                                                                                                                                                                                                add_child(ch)
                                                                                                                                var decor := FloorDecor.new()
                                                                                                                                decor.btl = btl
                                                                                                                                add_child(decor)

                                                                func redraw_all() -> void:
                                                                                                                                for c in get_children():
                                                                                                                                                                                                (c as Node2D).queue_redraw()

                                                                func _hash2(cx: int, cy: int, salt: int = 0) -> float:
                                                                                                                                var h: int = int(cx * 73856093 + salt * 83492791) ^ int(cy * 19349663 + salt * 29712150)
                                                                                                                                return float(absi(h) % 2147483647) / 2147483647.0

class FloorChunk extends Node2D:
                                                                # один чанк пола: рисует только свои клетки (1 раз, без per-frame redraw)
                                                                var btl = null
                                                                var rect := Rect2()

                                                                func _ready() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                btl = get_parent().get_parent()
                                                                                                                                queue_redraw()

                                                                func _hash2(cx: int, cy: int, salt: int = 0) -> float:
                                                                                                                                var h: int = int(cx * 73856093 + salt * 83492791) ^ int(cy * 19349663 + salt * 29712150)
                                                                                                                                return float(absi(h) % 2147483647) / 2147483647.0

                                                                func _cell_range(r: Rect2, ts: float) -> Array:
                                                                                                                                var x0 := int(floorf(maxf(r.position.x, rect.position.x - ts) / ts))
                                                                                                                                var y0 := int(floorf(maxf(r.position.y, rect.position.y - ts) / ts))
                                                                                                                                var x1 := int(ceilf(minf(r.end.x, rect.end.x + ts) / ts))
                                                                                                                                var y1 := int(ceilf(minf(r.end.y, rect.end.y + ts) / ts))
                                                                                                                                return [x0, y0, x1, y1]

                                                                func _draw() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                return
                                                                                                                                var ms: Vector2 = btl.map_size
                                                                                                                                var ts: float = btl.TS if btl.is_bunker else btl.TS_S
                                                                                                                                var base := rect.grow(2.0).intersection(Rect2(Vector2.ZERO, ms))
                                                                                                                                if btl.is_bunker:
                                                                                                                                                                                                # FIX5: база СТРОГО внутри чанка — раньше grow-заливка соседнего
                                                                                                                                                                                                # чанка затирала уже нарисованные плитки (пол «исчезал»)
                                                                                                                                                                                                draw_rect(base, Color(0.008, 0.011, 0.014), true)
                                                                                                                                                                                                _draw_bunker_cells(ts)
                                                                                                                                                                                                _draw_light_pools()
                                                                                                                                else:
                                                                                                                                                                                                draw_rect(base, Color(0.72, 0.76, 0.84), true)
                                                                                                                                                                                                _draw_surface_cells(ts)

                                                                func _draw_surface_cells(ts: float) -> void:
                                                                                                                                var cols := {
                                                                                                                                                                                                "snow": Color(0.83, 0.87, 0.93),
                                                                                                                                                                                                "road": Color(0.38, 0.40, 0.44),
                                                                                                                                                                                                "conc": Color(0.23, 0.26, 0.29),
                                                                                                                                                                                                "metal": Color(0.29, 0.34, 0.39),
                                                                                                                                                                                                "tile": Color(0.49, 0.55, 0.54),
                                                                                                                                }
                                                                                                                                for zone in btl.floor_zones:
                                                                                                                                                                                                var r: Rect2 = zone["rect"]
                                                                                                                                                                                                if not r.grow(ts).intersects(rect):
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var col: Color = cols.get(zone["kind"], Color(0.72, 0.76, 0.84))
                                                                                                                                                                                                var rng := _cell_range(r, ts)
                                                                                                                                                                                                for cy in range(rng[1], rng[3]):
                                                                                                                                                                                                                                                                for cx in range(rng[0], rng[2]):
                                                                                                                                                                                                                                                                                                                                var cell := Rect2(cx * ts, cy * ts, ts, ts)
                                                                                                                                                                                                                                                                                                                                var h := _hash2(cx, cy)
                                                                                                                                                                                                                                                                                                                                var k := 0.92 + 0.16 * h
                                                                                                                                                                                                                                                                                                                                var cc := Color(col.r * k, col.g * k, col.b * k)
                                                                                                                                                                                                                                                                                                                                draw_rect(cell, cc, true)
                                                                                                                                                                                                                                                                                                                                if zone["kind"] == "snow" and _hash2(cx, cy, 3) > 0.72:
                                                                                                                                                                                                                                                                                                                                                                                                var dc := cell.position + Vector2(ts * 0.5, ts * 0.68)
                                                                                                                                                                                                                                                                                                                                                                                                draw_circle(dc + Vector2(-ts * 0.16, 0), ts * 0.17, Color(1, 1, 1, 0.20))
                                                                                                                                                                                                                                                                                                                                                                                                draw_circle(dc + Vector2(ts * 0.13, -ts * 0.03), ts * 0.13, Color(1, 1, 1, 0.16))
                                                                                                                                                                                                                                                                                                                                                                                                draw_circle(dc + Vector2(ts * 0.02, ts * 0.06), ts * 0.10, Color(1, 1, 1, 0.14))
                                                                                                                                                                                                                                                                                                                                elif zone["kind"] == "road":
                                                                                                                                                                                                                                                                                                                                                                                                draw_rect(cell, Color(0.3, 0.32, 0.36, 0.4), false, 1.0)

                                                                func _draw_bunker_cells(ts: float) -> void:
                                                                 # ПОЛ БУНКЕРА v3: архитектура вместо «тестовой сетки» (ТЗ п.2/5).
                                                                 # У каждого покрытия свой ритм панелей; швы приглушены; редкие плиты ломают
                                                                 # ритм: сдвоенные, рифлёные, решётки, трещины; добавлены следы эксплуатации.
                                                                 var kind_col := {
                                                                         "tile_med": Color(0.34, 0.37, 0.37),
                                                                         "tile_lab": Color(0.135, 0.175, 0.19),
                                                                         "metal": Color(0.20, 0.23, 0.27),
                                                                         "conc": Color(0.195, 0.205, 0.23),
                                                                         "tile": Color(0.32, 0.36, 0.36),
                                                                 }
                                                                 var grout := {
                                                                         "tile_med": Color(0.24, 0.27, 0.27, 0.55),
                                                                         "tile_lab": Color(0.075, 0.11, 0.125, 0.5),
                                                                         "metal": Color(0.135, 0.16, 0.19, 0.45),
                                                                         "conc": Color(0.15, 0.16, 0.18, 0.4),
                                                                         "tile": Color(0.24, 0.27, 0.27, 0.4),
                                                                 }
                                                                 var half := ts * 0.5
                                                                 for zone in btl.floor_zones:
                                                                  var r: Rect2 = zone["rect"]
                                                                  if not r.grow(ts).intersects(rect):
                                                                   continue
                                                                  var kind: String = zone["kind"]
                                                                  var col: Color = kind_col.get(kind, Color(0.2, 0.22, 0.24))
                                                                  var gr: Color = grout.get(kind, Color(0.1, 0.1, 0.12))
                                                                  var rng := _cell_range(r, ts)
                                                                  for cy in range(rng[1], rng[3]):
                                                                   for cx in range(rng[0], rng[2]):
                                                                    var cell := Rect2(cx * ts, cy * ts, ts, ts)
                                                                    var k := 0.94 + 0.12 * _hash2(cx, cy)
                                                                    var cc := Color(col.r * k, col.g * k, col.b * k)
                                                                    if kind == "metal":
                                                                     _metal_plate(cell, cx, cy, cc, gr)
                                                                    elif kind == "conc":
                                                                     draw_rect(cell, cc, true)
                                                                     _conc_details(cell, cx, cy)
                                                                     draw_rect(cell, gr, false, 1.0)
                                                                    else:
                                                                     # кафель: 2х2 суб-плитки, ритм ломают сдвоенные плиты и трещины
                                                                     var slab_mode := int(_hash2(cx, cy, 11) * 3.0)
                                                                     for sy in range(2):
                                                                      for sx in range(2):
                                                                       var hk := 0.93 + 0.14 * _hash2(cx * 2 + sx, cy * 2 + sy, 3)
                                                                       var sub := Rect2(cx * ts + sx * half, cy * ts + sy * half, half, half)
                                                                       draw_rect(sub, Color(col.r * hk, col.g * hk, col.b * hk), true)
                                                                     if kind == "tile_lab" and _hash2(cx, cy, 5) > 0.82:
                                                                      var grime := Rect2(cell.position + cell.size * Vector2(0.22, 0.26), cell.size * Vector2(0.46, 0.4))
                                                                      draw_rect(grime, Color(0.05, 0.08, 0.07, 0.22), true)
                                                                     if kind == "tile_med" and _hash2(cx, cy, 5) > 0.84:
                                                                      var worn := Rect2(cell.position + cell.size * Vector2(0.14, 0.3), cell.size * Vector2(0.62, 0.42))
                                                                      draw_rect(worn, Color(0.22, 0.24, 0.23, 0.4), true)
                                                                     draw_rect(cell, gr, false, 1.0)
                                                                     # внутренние швы: у «сдвоенных» плит крест отсутствует
                                                                     if slab_mode == 0:
                                                                      draw_line(Vector2(cell.position.x, cell.position.y + half), Vector2(cell.end.x, cell.position.y + half), gr, 1.0)
                                                                      draw_line(Vector2(cell.position.x + half, cell.position.y), Vector2(cell.position.x + half, cell.end.y), gr, 1.0)
                                                                     elif slab_mode == 1:
                                                                      draw_line(Vector2(cell.position.x, cell.position.y + half), Vector2(cell.end.x, cell.position.y + half), gr, 1.0)
                                                                     else:
                                                                      draw_line(Vector2(cell.position.x + half, cell.position.y), Vector2(cell.position.x + half, cell.end.y), gr, 1.0)
                                                                     if _hash2(cx, cy, 13) > 0.94:
                                                                      # треснувшая плитка
                                                                      var t0 := cell.position + cell.size * Vector2(0.2 + 0.4 * _hash2(cx, cy, 14), 0.16)
                                                                      draw_line(t0, t0 + cell.size * Vector2(0.16, 0.3), Color(0.06, 0.07, 0.075, 0.75), 1.3)
                                                                      draw_line(t0 + cell.size * Vector2(0.16, 0.3), t0 + cell.size * Vector2(0.06, 0.55), Color(0.06, 0.07, 0.075, 0.6), 1.2)

                                                                func _metal_plate(cell: Rect2, cx: int, cy: int, cc: Color, gr: Color) -> void:
                                                                 # крупная стальная плита: варианты ритма — рифлёная, решётка, повреждённая
                                                                 draw_rect(cell, cc, true)
                                                                 var h := _hash2(cx, cy, 21)
                                                                 if h > 0.93:
                                                                  draw_rect(cell, Color(0.09, 0.105, 0.125, 0.6), true)
                                                                  var p0 := cell.position + cell.size * Vector2(0.18, 0.24)
                                                                  draw_line(p0, p0 + cell.size * Vector2(0.3, 0.2), Color(0.05, 0.06, 0.07, 0.8), 1.4)
                                                                  draw_line(p0 + cell.size * Vector2(0.3, 0.2), p0 + cell.size * Vector2(0.24, 0.5), Color(0.05, 0.06, 0.07, 0.65), 1.3)
                                                                 elif h > 0.72:
                                                                  # рифлёная сталь: диагональная насечка
                                                                  var step := 26.0
                                                                  var off := -fmod(cell.position.y, step)
                                                                  var xx := cell.position.x - cell.size.y
                                                                  while xx < cell.end.x:
                                                                   draw_line(Vector2(xx + off, cell.end.y), Vector2(xx + off + cell.size.y, cell.position.y), Color(0.30, 0.36, 0.41, 0.28), 2.0)
                                                                   xx += step
                                                                 elif h > 0.60:
                                                                  # сервисная решётка в полу
                                                                  draw_rect(cell.grow(-6.0), Color(0.10, 0.12, 0.14, 0.85), true)
                                                                  var sy2 := cell.position.y + 10.0
                                                                  while sy2 < cell.end.y - 8.0:
                                                                   draw_line(Vector2(cell.position.x + 10.0, sy2), Vector2(cell.end.x - 10.0, sy2), Color(0.23, 0.27, 0.31, 0.9), 2.4)
                                                                   sy2 += 9.0
                                                                 for rv in [Vector2(7, 7), Vector2(cell.size.x - 7, 7), Vector2(7, cell.size.y - 7), Vector2(cell.size.x - 7, cell.size.y - 7)]:
                                                                  draw_circle(cell.position + rv, 1.5, Color(0.4, 0.46, 0.5, 0.75))
                                                                 draw_rect(cell, gr, false, 1.0)

                                                                func _conc_details(cell: Rect2, cx: int, cy: int) -> void:
                                                                 # бетон: трещины и выкрашивания
                                                                 if _hash2(cx, cy, 7) > 0.78:
                                                                  var x0 := cell.position.x + cell.size.x * (0.15 + 0.5 * _hash2(cx, cy, 8))
                                                                  var y0 := cell.position.y + cell.size.y * 0.2
                                                                  draw_line(Vector2(x0, y0), Vector2(x0 + cell.size.x * 0.2, y0 + cell.size.y * 0.3), Color(0.14, 0.15, 0.16, 0.7), 1.2)
                                                                  draw_line(Vector2(x0 + cell.size.x * 0.2, y0 + cell.size.y * 0.3), Vector2(x0 + cell.size.x * 0.1, y0 + cell.size.y * 0.55), Color(0.14, 0.15, 0.16, 0.6), 1.2)

                                                                func _draw_light_pools() -> void:
                                                                                                                                # мягкие пятна света: предзапечённые текстуры (гладко, клип по комнате)
                                                                                                                                # FIX10: пятно рисуется СТРОГО в пределах чанка (draw_texture_rect_region).
                                                                                                                                # Раньше каждый чанк, чей bbox пересекался, рисовал пятно ЦЕЛИКОМ —
                                                                                                                                # свет накладывался сам на себя 4–8 раз (альфа-накопление) и пол
                                                                                                                                # выгорал в белое («зимний» зал лаборатории).
                                                                                                                                for lp in btl.light_pools:
                                                                                                                                                                                                var bb: Rect2 = lp.get("bbox", Rect2())
                                                                                                                                                                                                if bb.size.x < 1.0 or not rect.intersects(bb):
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var tx: Texture2D = lp.get("tex", null)
                                                                                                                                                                                                if tx == null:
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var vis := bb.intersection(rect)
                                                                                                                                                                                                if vis.size.x < 1.0 or vis.size.y < 1.0:
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var tw := tx.get_width()
                                                                                                                                                                                                var th := tx.get_height()
                                                                                                                                                                                                var sx := (vis.position.x - bb.position.x) / bb.size.x * tw
                                                                                                                                                                                                var sy := (vis.position.y - bb.position.y) / bb.size.y * th
                                                                                                                                                                                                var sw := vis.size.x / bb.size.x * tw
                                                                                                                                                                                                var sh := vis.size.y / bb.size.y * th
                                                                                                                                                                                                draw_texture_rect_region(tx, vis, Rect2(sx, sy, sw, sh))

class FloorDecor extends Node2D:
                                                                # стены, разметка, трубы, точка выхода — один лёгкий canvas item
                                                                var btl = null

                                                                func _ready() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                btl = get_parent().get_parent()
                                                                                                                                queue_redraw()

                                                                func _draw() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                return
                                                                                                                                if btl.is_bunker:
                                                                                                                                                                                                _draw_bunker_walls()
                                                                                                                                                                                                _draw_deco()
                                                                                                                                else:
                                                                                                                                                                                                for wr in btl.walls:
                                                                                                                                                                                                                                                                draw_rect(wr, Color(0.30, 0.34, 0.30), true)
                                                                                                                                                                                                                                                                draw_rect(wr.grow(2.0), Color(0.55, 0.62, 0.55), false, 2.0)
                                                                                                                                # точка выхода
                                                                                                                                if btl.extraction_open:
                                                                                                                                                                                                var e: Vector2 = btl.extraction
                                                                                                                                                                                                var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
                                                                                                                                                                                                draw_arc(e, 90.0 + pulse * 14.0, 0, TAU, 30, Color(0.4, 0.9, 0.5, 0.6), 3.0)
                                                                                                                                                                                                draw_arc(e, 46.0, 0, TAU, 20, Color(0.4, 0.9, 0.5, 0.4), 2.0)
                                                                                                                                                                                                var ex_label := "ЛЕСТНИЦА НАВЕРХ" if btl.is_bunker else "ЭВАКУАЦИЯ"
                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, e + Vector2(-46, -100), ex_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.95, 0.6))

                                                                func _draw_deco() -> void:
                                                                                                                                # аварийная разметка у шлюзовой (вход в шлюз)
                                                                                                                                _draw_hazard(Rect2(1920, 682, 800, 14))
                                                                                                                                _draw_hazard(Rect2(1920, 1318, 800, 14))
                                                                                                                                # технологические трубы вдоль стены лабзала
                                                                                                                                _draw_pipe(Vector2(140, 1252), Vector2(1810, 1252))
                                                                                                                                _draw_pipe(Vector2(1908, 180), Vector2(1908, 660))

                                                                func _draw_bunker_walls() -> void:
                                                                 # СТЕНЫ v3: секции переменной ширины, сервисные люки, кабель-каналы,
                                                                 # мягкое затенение пола у основания (ТЗ п.2). Отрисовка кэшируется.
                                                                 for wr in btl.walls:
                                                                  var hseed: float = fposmod(wr.position.x * 0.013 + wr.position.y * 0.017, 1.0)
                                                                  # мягкое AO на полу вокруг стены (рисуется до корпуса — видно только по краям)
                                                                  draw_rect(wr.grow(24.0), Color(0.0, 0.0, 0.0, 0.09), true)
                                                                  draw_rect(wr.grow(11.0), Color(0.0, 0.0, 0.0, 0.13), true)
                                                                  # тень на пол + корпус стены
                                                                  draw_rect(Rect2(wr.position + Vector2(4, 7), wr.size), Color(0.0, 0.0, 0.0, 0.42), true)
                                                                  draw_rect(wr, Color(0.055, 0.066, 0.085), true)
                                                                  var face: Rect2 = wr.grow(-3.0)
                                                                  if face.size.x > 1.0 and face.size.y > 1.0:
                                                                   var fk: float = 0.93 + 0.14 * hseed
                                                                   draw_rect(face, Color(0.135 * fk, 0.16 * fk, 0.195 * fk), true)
                                                                  # фаска: свет сверху-слева, тень снизу-справа
                                                                  if wr.size.x >= wr.size.y:
                                                                   draw_line(Vector2(wr.position.x + 3.0, wr.position.y + 3.0), Vector2(wr.end.x - 3.0, wr.position.y + 3.0), Color(0.52, 0.585, 0.645, 0.75), 1.6)
                                                                   draw_line(Vector2(wr.position.x + 3.0, wr.end.y - 3.0), Vector2(wr.end.x - 3.0, wr.end.y - 3.0), Color(0.03, 0.04, 0.05, 0.8), 1.6)
                                                                  else:
                                                                   draw_line(Vector2(wr.position.x + 3.0, wr.position.y + 3.0), Vector2(wr.position.x + 3.0, wr.end.y - 3.0), Color(0.52, 0.585, 0.645, 0.75), 1.6)
                                                                   draw_line(Vector2(wr.end.x - 3.0, wr.position.y + 3.0), Vector2(wr.end.x - 3.0, wr.end.y - 3.0), Color(0.03, 0.04, 0.05, 0.8), 1.6)
                                                                  var vertical: bool = wr.size.y > wr.size.x
                                                                  var length: float = wr.size.y if vertical else wr.size.x
                                                                  if length >= 30.0:
                                                                   # панели ПЕРЕМЕННОЙ ширины + фурнитура — ритм перестаёт быть равномерным
                                                                   var travelled := 8.0
                                                                   var wi := 0
                                                                   while travelled < length - 14.0:
                                                                    var seg: float = 66.0 + 74.0 * _wall_hash(int(wr.position.x) + wi * 131, int(wr.position.y) + wi * 17)
                                                                    var end_t := minf(travelled + seg, length - 6.0)
                                                                    if wi > 0:
                                                                     _wall_mark(wr, vertical, travelled)
                                                                    var wh: float = _wall_hash(int(wr.position.x) * 3 + wi * 57, int(wr.position.y) * 5 - wi * 91)
                                                                    var seg_len := end_t - travelled
                                                                    if seg_len > 86.0 and wh > 0.74:
                                                                     _wall_service(wr, vertical, (travelled + end_t) * 0.5)
                                                                    elif seg_len > 70.0 and wh < 0.16:
                                                                     _wall_cables(wr, vertical, travelled + 6.0, end_t - 6.0, hseed)
                                                                    wi += 1
                                                                    travelled = end_t + 4.0
                                                                  draw_rect(wr.grow(2.0), Color(0.38, 0.44, 0.50, 0.55), false, 1.0)

                                                                func _wall_hash(i1: int, i2: int) -> float:
                                                                 var h: int = int(i1 * 73856093) ^ int(i2 * 19349663)
                                                                 return float(absi(h) % 2147483647) / 2147483647.0

                                                                func _wall_mark(wr: Rect2, vertical: bool, t: float) -> void:
                                                                 # стык панелей: тёмная линия + заклёпка по центру
                                                                 var c := Color(0.05, 0.06, 0.075, 0.85)
                                                                 if vertical:
                                                                  draw_line(Vector2(wr.position.x + 3.0, wr.position.y + t), Vector2(wr.end.x - 3.0, wr.position.y + t), c, 1.0)
                                                                  draw_circle(Vector2(wr.position.x + wr.size.x * 0.5, wr.position.y + t), 1.3, Color(0.44, 0.50, 0.55, 0.7))
                                                                 else:
                                                                  draw_line(Vector2(wr.position.x + t, wr.position.y + 3.0), Vector2(wr.position.x + t, wr.end.y - 3.0), c, 1.0)
                                                                  draw_circle(Vector2(wr.position.x + t, wr.position.y + wr.size.y * 0.5), 1.3, Color(0.44, 0.50, 0.55, 0.7))

                                                                func _wall_service(wr: Rect2, vertical: bool, mid: float) -> void:
                                                                 # врезанный сервисный люк: рамка, диагональ страховочная, винты
                                                                 var sw: float = minf(26.0, (wr.size.x - 12.0) if vertical else (wr.size.y - 12.0))
                                                                 if sw < 14.0:
                                                                  return
                                                                 var rp: Rect2
                                                                 if vertical:
                                                                  rp = Rect2(wr.position.x + wr.size.x * 0.5 - sw * 0.5, wr.position.y + mid - sw * 0.5, sw, sw)
                                                                 else:
                                                                  rp = Rect2(wr.position.x + mid - sw * 0.5, wr.position.y + wr.size.y * 0.5 - sw * 0.5, sw, sw)
                                                                 draw_rect(rp, Color(0.10, 0.125, 0.15), true)
                                                                 draw_rect(rp, Color(0.30, 0.36, 0.42, 0.8), false, 1.0)
                                                                 draw_line(rp.position + Vector2(4, 4), rp.end - Vector2(4, 4), Color(0.22, 0.27, 0.31, 0.7), 1.0)
                                                                 draw_line(Vector2(rp.end.x - 4, rp.position.y + 4), Vector2(rp.position.x + 4, rp.end.y - 4), Color(0.22, 0.27, 0.31, 0.7), 1.0)

                                                                func _wall_cables(wr: Rect2, vertical: bool, a: float, b: float, hseed: float) -> void:
                                                                 # кабель-канал: один-два кабеля вдоль панели со скобами
                                                                 var off := 5.0 + 3.0 * hseed
                                                                 var cc := Color(0.09, 0.10, 0.115, 0.9)
                                                                 var bracket := Color(0.3, 0.35, 0.4, 0.7)
                                                                 if vertical:
                                                                  var cxx := wr.end.x - off
                                                                  draw_line(Vector2(cxx, wr.position.y + a), Vector2(cxx, wr.position.y + b), cc, 2.6)
                                                                  var t := a + 14.0
                                                                  while t < b - 6.0:
                                                                   draw_line(Vector2(cxx - 3.5, wr.position.y + t), Vector2(cxx + 3.5, wr.position.y + t), bracket, 1.2)
                                                                   t += 34.0
                                                                 else:
                                                                  var cyy := wr.end.y - off
                                                                  draw_line(Vector2(wr.position.x + a, cyy), Vector2(wr.position.x + b, cyy), cc, 2.6)
                                                                  var t2 := a + 14.0
                                                                  while t2 < b - 6.0:
                                                                   draw_line(Vector2(wr.position.x + t2, cyy - 3.5), Vector2(wr.position.x + t2, cyy + 3.5), bracket, 1.2)
                                                                   t2 += 34.0

                                                                func _draw_hazard(r: Rect2) -> void:
                                                                                                                                draw_rect(r, Color(0.16, 0.13, 0.03, 0.9), true)
                                                                                                                                var x := r.position.x - r.size.y
                                                                                                                                while x < r.end.x:
                                                                                                                                                                                                var quad := PackedVector2Array([
                                                                                                                                                                                                                                                                Vector2(maxf(x, r.position.x), r.end.y),
                                                                                                                                                                                                                                                                Vector2(maxf(x + r.size.y * 0.5, r.position.x), r.end.y),
                                                                                                                                                                                                                                                                Vector2(maxf(x + r.size.y, r.position.x), r.position.y),
                                                                                                                                                                                                                                                                Vector2(maxf(x + r.size.y * 0.5, r.position.x), r.position.y),
                                                                                                                                                                                                ])
                                                                                                                                                                                                draw_polygon(quad, PackedColorArray([Color(0.78, 0.62, 0.16, 0.95)]))
                                                                                                                                                                                                x += r.size.y * 2.0

                                                                func _draw_pipe(a: Vector2, b: Vector2) -> void:
                                                                                                                                var horizontal: bool = absf(b.y - a.y) < 0.01
                                                                                                                                var dir := (b - a).normalized()
                                                                                                                                var nrm := Vector2(-dir.y, dir.x)
                                                                                                                                for off in [-4.0, 4.0]:
                                                                                                                                                                                                draw_line(a + nrm * off, b + nrm * off, Color(0.16, 0.20, 0.24, 0.95), 4.5)
                                                                                                                                                                                                draw_line(a + nrm * (off - 1.2), b + nrm * (off - 1.2), Color(0.42, 0.50, 0.56, 0.55), 1.2)
                                                                                                                                # фланцы каждые 192px
                                                                                                                                var length := a.distance_to(b)
                                                                                                                                var d := 48.0
                                                                                                                                while d < length:
                                                                                                                                                                                                var p := a + dir * d
                                                                                                                                                                                                draw_line(p + nrm * -6.5, p + nrm * 6.5, Color(0.36, 0.44, 0.50, 0.9), 3.0)
                                                                                                                                                                                                d += 192.0

class DecalDraw extends Node2D:
                                                                var btl = null

                                                                func _ready() -> void:
                                                                                                if btl == null:
                                                                                                                                btl = get_parent()

                                                                func _draw() -> void:
                                                                                                if btl == null:
                                                                                                                                return
                                                                                                for decal in btl.decals:
                                                                                                                                var idx_n: int = clampi(int(decal.get("idx", 0)), 0, 5)
                                                                                                                                var texture = G.tex("decal_blood%d" % idx_n)
                                                                                                                                if texture == null:
                                                                                                                                    texture = G.tex("decal_blood0")
                                                                                                                                if texture == null:
                                                                                                                                                                continue
                                                                                                                                var extent: float = 64.0 * float(decal["scale"])
                                                                                                                                draw_set_transform(decal["pos"], float(decal["rot"]))
                                                                                                                                draw_texture_rect(texture, Rect2(Vector2(-extent * 0.5, -extent * 0.5), Vector2(extent, extent)), false)
                                                                                                draw_set_transform(Vector2.ZERO, 0.0)

# ================= HUD-ОТРИСОВКА (стики, прицел, виньетки) =================
class HudDraw extends Control:
                                                                var btl = null

                                                                func _ready() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                btl = get_parent()

                                                                func stick_base(side: String) -> Vector2:
                                                                                                                                var vp := get_viewport_rect().size
                                                                                                                                var x := maxf(236.0, vp.x * 0.095)
                                                                                                                                if side == "l":
                                                                                                                                                                                                return Vector2(x, vp.y - 244.0)
                                                                                                                                return Vector2(vp.x - x, vp.y - 244.0)

                                                                func _draw() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                return
                                                                                                                                var vp := get_viewport_rect().size
                                                                                                                                # ---------- в капсуле интерфейса НЕТ (только кнопка «выбраться») ----------
                                                                                                                                if bool(btl.in_capsule):
                                                                                                                                                                                                return
                                                                                                                                # v2.8: компас активной задачи (стрелка к цели за экраном)
                                                                                                                                if btl.is_bunker:
                                                                                                                                        _draw_compass_arrow(vp)
                                                                                                                                # ---------- виньетка урона ----------
                                                                                                                                var vdmg: float = float(btl.vignette_dmg)
                                                                                                                                if vdmg > 0.0:
                                                                                                                                                                                                # мягкая красная виньетка по краям экрана (радиальный градиент)
                                                                                                                                                                                                var vtex := _vig_tex()
                                                                                                                                                                                                var vw := vp.x * 1.45
                                                                                                                                                                                                var vh := vp.y * 1.45
                                                                                                                                                                                                draw_texture_rect(vtex, Rect2((vp.x - vw) * 0.5, (vp.y - vh) * 0.5, vw, vh), false, Color(0.74, 0.09, 0.05, 0.60 * vdmg))
                                                                                                                                                                                                # лёгкая общая заливка: удар читается даже в центре экрана
                                                                                                                                                                                                draw_rect(Rect2(Vector2.ZERO, vp), Color(0.55, 0.06, 0.04, 0.09 * vdmg), true)
                                                                                                                                # заражение: зеленоватая пульсация краёв
                                                                                                                                var infect: float = float(btl.player["infect"])
                                                                                                                                if infect > 30.0:
                                                                                                                                                                                                var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0035)
                                                                                                                                                                                                var a: float = (infect / 100.0) * 0.14 * (0.6 + 0.4 * pulse)
                                                                                                                                                                                                draw_rect(Rect2(Vector2.ZERO, vp), Color(0.45, 0.65, 0.25, a), true)
                                                                                                                                # ---------- FIX11: направление последнего удара ----------
                                                                                                                                if float(btl.hit_dir_t) > 0.0:
                                                                                                                                        var ppos2: Vector2 = btl.player["spr"].position
                                                                                                                                        var scr2 := _world_to_screen(ppos2)
                                                                                                                                        var ha: float = float(btl.hit_dir_ang)
                                                                                                                                        var rr := minf(vp.x, vp.y) * 0.30
                                                                                                                                        var a3: float = clampf(float(btl.hit_dir_t), 0.0, 1.0)
                                                                                                                                        draw_arc(scr2, rr, ha - 0.45, ha + 0.45, 18, Color(0.95, 0.25, 0.18, 0.75 * a3), 5.0)
                                                                                                                                        draw_arc(scr2, rr + 8.0, ha - 0.30, ha + 0.30, 14, Color(0.95, 0.4, 0.3, 0.35 * a3), 2.0)
                                                                                                                                # ---------- стики ----------
                                                                                                                                var bl := stick_base("l")
                                                                                                                                var br := stick_base("r")
                                                                                                                                _draw_stick(bl, btl.direct_vec * btl.STICK_KNOB, "ХОД")
                                                                                                                                _draw_run_state(bl)
                                                                                                                                var aim_v := Vector2.ZERO
                                                                                                                                if btl.manual_aim:
                                                                                                                                                                                                aim_v = Vector2.from_angle(btl.manual_ang) * btl.STICK_KNOB * (1.0 if btl.manual_fire else 0.7)
                                                                                                                                _draw_stick(br, aim_v, "ВЗГЛЯД" if btl.get_meta("bunker_v5",false) and not btl._obj_done("gear") else "ОГОНЬ")
                                                                                                                                # ---------- прицел ----------
                                                                                                                                if btl.player["spr"].visible and btl.player["alive"] and btl.manual_aim and not btl.get_meta("bunker_v5",false):
                                                                                                                                                                                                var ppos: Vector2 = btl.player["spr"].position
                                                                                                                                                                                                var _cam: Camera2D = btl.camera
                                                                                                                                                                                                var ang: float = btl.player["aim"]
                                                                                                                                                                                                var scr := _world_to_screen(ppos)
                                                                                                                                                                                                var tip := scr + Vector2.from_angle(ang) * 120.0
                                                                                                                                                                                                draw_line(scr + Vector2.from_angle(ang) * 34.0, tip, Color(1, 0.95, 0.7, 0.5), 2.0)
                                                                                                                                                                                                var fire_col := Color(1.0, 0.45, 0.35) if btl.manual_fire else Color(1, 0.95, 0.7, 0.85)
                                                                                                                                                                                                draw_arc(tip, 16.0, 0, TAU, 20, fire_col, 2.0)
                                                                                                                                                                                                for i in range(4):
                                                                                                                                                                                                                                                                var ta := ang + i * PI / 2.0
                                                                                                                                                                                                                                                                draw_line(tip + Vector2.from_angle(ta) * 20.0, tip + Vector2.from_angle(ta) * 26.0, fire_col, 2.0)
                                                                                                                                                                                                # индикатор перезарядки — дуга
                                                                                                                                                                                                var rt: float = float(btl.player["reload_t"])
                                                                                                                                                                                                if rt > 0.0:
                                                                                                                                                                                                                                                                var wd: Dictionary = G.ZWEAPONS[btl.player["weapon"]]
                                                                                                                                                                                                                                                                var frac: float = 1.0 - clampf(rt / float(wd["reload"]), 0.0, 1.0)
                                                                                                                                                                                                                                                                draw_arc(tip, 26.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 24, Color(0.5, 0.9, 1.0, 0.9), 3.0)
                                                                                                                                # ---------- журнал (FIX7: ниже панели задач, чтобы не налезал) ----------
                                                                                                                                var ly := 296.0
                                                                                                                                for entry in ([] if btl.get_meta("bunker_v6",false) else btl.log_lines):
                                                                                                                                                                                                var col: Color = entry["col"]
                                                                                                                                                                                                col.a = clampf(float(entry["t"]) / 2.0, 0.0, 1.0)
                                                                                                                                                                                                var tag: String = entry["tag"]
                                                                                                                                                                                                var txt: String = entry["text"]
                                                                                                                                                                                                if tag != "":
                                                                                                                                                                                                                                                                var tag_col := Color(0.55, 0.75, 0.5)
                                                                                                                                                                                                                                                                if tag == "ШТАММ":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.75, 0.9, 0.55)
                                                                                                                                                                                                                                                                elif tag == "РАДИО":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.6, 0.8, 0.7)
                                                                                                                                                                                                                                                                elif tag == "СИСТЕМА":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.6, 0.7, 0.85)
                                                                                                                                                                                                                                                                elif tag == "ХАБАР":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.9, 0.85, 0.5)
                                                                                                                                                                                                                                                                elif tag == "ОТРЯД":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.8, 0.7, 0.5)
                                                                                                                                                                                                                                                                elif tag == "ВОЛКОВ":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.64, 0.76, 0.92)
                                                                                                                                                                                                                                                                elif tag == "СТРАННОЕ":
                                                                                                                                                                                                                                                                                                                                tag_col = Color(0.78, 0.66, 0.88)
                                                                                                                                                                                                                                                                draw_rect(Rect2(12, ly - 3, 12, 20), Color(tag_col.r, tag_col.g, tag_col.b, col.a), true)
                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(32, ly + 13), "[%s] %s" % [tag, txt], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(16, ly + 13), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
                                                                                                                                                                                                ly += 24.0
                                                                                                                                # ---------- подсказки-тосты ----------
                                                                                                                                var ty := 156.0
                                                                                                                                for t in ([] if btl.get_meta("bunker_v6",false) else btl.toasts):
                                                                                                                                                                                                var a2: float = clampf(float(t["t"]) / 0.8, 0.0, 1.0)
                                                                                                                                                                                                var col2 := Color(1.0, 0.9, 0.6, a2)
                                                                                                                                                                                                var w := 780.0
                                                                                                                                                                                                draw_rect(Rect2((vp.x - w) * 0.5, ty - 5, w, 32), Color(0.05, 0.05, 0.04, 0.65 * a2), true)
                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2((vp.x - w) * 0.5 + 10, ty + 19), t["text"], HORIZONTAL_ALIGNMENT_CENTER, w, 19, col2)
                                                                                                                                                                                                ty += 38.0
                                                                                                                                # ---------- FIX6: проверка магазина — панель над полосой слотов ----------
                                                                                                                                if not btl.get_meta("bunker_v9",false) and (float(btl._ammo_check_t) > 0.0 or float(btl._ammo_result_t) > 0.0):
                                                                                                                                                                                                var pw := 320.0
                                                                                                                                                                                                var px := vp.x * 0.5 - pw * 0.5
                                                                                                                                                                                                var py := vp.y - 272.0
                                                                                                                                                                                                draw_rect(Rect2(px, py, pw, 46), Color(0.04, 0.055, 0.048, 0.88), true)
                                                                                                                                                                                                draw_rect(Rect2(px, py, pw, 46), Color(0.4, 0.5, 0.42, 0.65), false, 1.5)
                                                                                                                                                                                                var atex := ZUI.icon("ammo")
                                                                                                                                                                                                if float(btl._ammo_check_t) > 0.0:
                                                                                                                                                                                                                                                                # «персонаж достаёт магазин и проверяет» — пульсация + прогресс
                                                                                                                                                                                                                                                                var t01 := clampf(1.0 - float(btl._ammo_check_t), 0.0, 1.0)
                                                                                                                                                                                                                                                                if atex != null:
                                                                                                                                                                                                                                                                                                                                var bob := sin(t01 * PI * 5.0) * 4.0
                                                                                                                                                                                                                                                                                                                                var ik := Rect2(px + 12, py + 9 + bob, 28, 28)
                                                                                                                                                                                                                                                                                                                                draw_texture_rect(atex, ik, false, ZUI.WARN)
                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(px + 54, py + 21), "ПРОВЕРКА МАГАЗИНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.92, 0.87, 0.62))
                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(px + 54, py + 38), ".".repeat(1 + int(t01 * 3.0) % 4), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ZUI.MUTED)
                                                                                                                                                                                                                                                                draw_rect(Rect2(px + 6, py + 42, (pw - 12) * t01, 2.0), Color(0.5, 0.9, 0.6, 0.85), true)
                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                var res: String = str(btl._ammo_result_txt)
                                                                                                                                                                                                                                                                var bad: bool = res.contains("пуст") or res.contains("перезарядк")
                                                                                                                                                                                                                                                                if atex != null:
                                                                                                                                                                                                                                                                                                                                draw_texture_rect(atex, Rect2(px + 12, py + 9, 28, 28), false, ZUI.ALERT if bad else ZUI.NEON_BRIGHT)
                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(px + 54, py + 30), res, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ZUI.ALERT if bad else ZUI.NEON_BRIGHT)
                                                                                                                                                                                                                                                                if res.begins_with("±"):
                                                                                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(px + pw - 16, py + 28), "на глаз", HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, ZUI.FAINT)
                                                                                                                                # ---------- прогресс эвакуации (FIX7: поднят над слотами) ----------
                                                                                                                                if btl.extract_t > 0.05:
                                                                                                                                                                                                var frac2: float = clampf(float(btl.extract_t) / 2.2, 0.0, 1.0)
                                                                                                                                                                                                draw_rect(Rect2(vp.x * 0.5 - 160, vp.y - 200, 320, 18), Color(0.05, 0.06, 0.05, 0.7), true)
                                                                                                                                                                                                draw_rect(Rect2(vp.x * 0.5 - 156, vp.y - 196, 312 * frac2, 10), Color(0.4, 0.9, 0.5, 0.9), true)
                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 60, vp.y - 206), "ЭВАКУАЦИЯ...", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1.0, 0.75))
                                                                                                                                # ---------- подъём по лестнице бункера: темнота ----------
                                                                                                                                if float(btl.stairs_fade) > 0.0 and btl.battle_over == "":
                                                                                                                                                                                                var fk: float = clampf(float(btl.stairs_fade) / 1.7, 0.0, 1.0)
                                                                                                                                                                                                draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, fk), true)
                                                                                                                                                                                                if fk > 0.3:
                                                                                                                                                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 130, vp.y * 0.5), "ВЫХОД НА ПОВЕРХНОСТЬ...", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.95, 0.75, minf(1.0, (fk - 0.3) * 1.4)))
                                                                                                                                # ---------- затемнение конца боя ----------
                                                                                                                                if btl.battle_over != "":
                                                                                                                                                                                                var k: float = clampf(float(btl.end_timer) / 1.2, 0.0, 1.0)
                                                                                                                                                                                                var fc := Color(0.95, 0.95, 0.92, k) if btl.battle_over == "win" else Color(0.35, 0.02, 0.02, k)
                                                                                                                                                                                                if btl.is_bunker:
                                                                                                                                                                                                                                                                fc = Color(0.0, 0.0, 0.0, k)   # из бункера — в темноту севера
                                                                                                                                                                                                draw_rect(Rect2(Vector2.ZERO, vp), fc, true)

                                                                func _draw_stick(base: Vector2, knob_off: Vector2, caption: String) -> void:
                                                                                                                                if btl.get_meta("bunker_v6",false): return
                                                                                                                                var t := Time.get_ticks_msec() * 0.001
                                                                                                                                # внешнее кольцо: тёмная база + стальная окантовка + тонкая неоновая кромка
                                                                                                                                # FIX6: стики прозрачнее — не закрывают обзор
                                                                                                                                draw_circle(base, 116.0, Color(0.05, 0.06, 0.055, 0.22))
                                                                                                                                draw_arc(base, 116.0, 0, TAU, 48, Color(0.42, 0.46, 0.40, 0.30), 6.0)
                                                                                                                                draw_arc(base, 116.0, 0, TAU, 48, Color(0.72, 0.78, 0.62, 0.40), 2.0)
                                                                                                                                draw_arc(base, 105.0, 0, TAU, 48, Color(0.30, 0.36, 0.30, 0.16), 1.4)
                                                                                                                                # риск-метки по кругу
                                                                                                                                for i in range(4):
                                                                                                                                                                                                var a := t * 0.35 + i * PI / 2.0
                                                                                                                                                                                                var p1 := base + Vector2.from_angle(a) * 91.0
                                                                                                                                                                                                var p2 := base + Vector2.from_angle(a) * 102.0
                                                                                                                                                                                                draw_line(p1, p2, Color(0.55, 0.60, 0.48, 0.24), 2.4)
                                                                                                                                draw_circle(base, 56.0, Color(0.07, 0.08, 0.07, 0.28))
                                                                                                                                var kpos := base + knob_off.limit_length(116.0)
                                                                                                                                # ручка: тёмная с бликом и мягкой неоновой подсветкой
                                                                                                                                draw_circle(kpos + Vector2(0, 4), 52.0, Color(0.0, 0.0, 0.0, 0.18))
                                                                                                                                draw_circle(kpos, 52.0, Color(0.135, 0.155, 0.125, 0.55))
                                                                                                                                draw_arc(kpos, 52.0, 0, TAU, 32, Color(0.78, 0.82, 0.62, 0.50), 2.6)
                                                                                                                                draw_arc(kpos, 42.0, PI * 0.9, PI * 1.9, 20, Color(0.85, 0.9, 0.75, 0.16), 3.6)
                                                                                                                                draw_circle(kpos + Vector2(-12, -12), 10.0, Color(0.9, 0.94, 0.82, 0.09))
                                                                                                                                draw_string(ThemeDB.fallback_font, base + Vector2(-30, 150), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.62, 0.66, 0.52, 0.55))

                                                                func _draw_run_state(base: Vector2) -> void:
                                                                        if btl.get_meta("bunker_v6",false): return
                                                                        # FIX7v2: кнопки БЕГ больше нет — выносливость кольцом у стика, режим бега — значок
                                                                        var t := Time.get_ticks_msec() * 0.001
                                                                        var stf: float = clampf(float(btl.stamina) / 100.0, 0.0, 1.0)
                                                                        var rcol := Color(0.85, 0.30, 0.22) if stf < 0.28 else (Color(0.90, 0.72, 0.28) if stf < 0.55 else Color(0.35, 0.85, 0.5))
                                                                        draw_arc(base, 126.0, -PI / 2.0, -PI / 2.0 + TAU * stf, 44, Color(rcol.r, rcol.g, rcol.b, 0.55), 3.0)
                                                                        if bool(btl._run_mode):
                                                                                var pk := 0.72 + 0.28 * sin(t * 6.0)
                                                                                var rtex := ZUI.icon("run")
                                                                                if rtex != null:
                                                                                        draw_texture_rect(rtex, Rect2(base + Vector2(-150.0, -16.0), Vector2(30, 30)), false, Color(0.55, 0.95, 0.65, pk))
                                                                                draw_string(ThemeDB.fallback_font, base + Vector2(-152.0, 34.0), "БЕГ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.55, 0.95, 0.65, pk))

                                                                var _vig_tex_cache: Texture2D = null

                                                                func _vig_tex() -> Texture2D:
                                                                                                                                # радиальный градиент «наоборот»: прозрачный центр, плотные края — виньетка урона
                                                                                                                                if _vig_tex_cache != null:
                                                                                                                                                                                                return _vig_tex_cache
                                                                                                                                var g := Gradient.new()
                                                                                                                                g.set_color(0, Color(1, 1, 1, 0.0))
                                                                                                                                g.add_point(0.50, Color(1, 1, 1, 0.06))
                                                                                                                                g.add_point(0.74, Color(1, 1, 1, 0.34))
                                                                                                                                g.add_point(0.90, Color(1, 1, 1, 0.78))
                                                                                                                                g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 1.0))
                                                                                                                                var gt := GradientTexture2D.new()
                                                                                                                                gt.gradient = g
                                                                                                                                gt.width = 256
                                                                                                                                gt.height = 256
                                                                                                                                gt.fill = GradientTexture2D.FILL_RADIAL
                                                                                                                                gt.fill_from = Vector2(0.5, 0.5)
                                                                                                                                gt.fill_to = Vector2(0.5, 0.0)
                                                                                                                                _vig_tex_cache = gt
                                                                                                                                return gt

                                                                func _world_to_screen(w: Vector2) -> Vector2:
                                                                                                                                var cam: Camera2D = btl.camera
                                                                                                                                var zoom: float = cam.zoom.x
                                                                                                                                return (w - cam.get_screen_center_position()) * zoom + get_viewport_rect().size * 0.5
                                                                
                                                                func _draw_compass_arrow(vp: Vector2) -> void:
                                                                                                                                # v2.8: стрелка-компас к цели текущей задачи, только если цель за экраном
                                                                                                                                var tgt: Vector2 = btl._zpro_obj_pos()
                                                                                                                                if tgt == Vector2.INF:
                                                                                                                                        return
                                                                                                                                var sp := _world_to_screen(tgt)
                                                                                                                                var mg := 76.0
                                                                                                                                var inner := Rect2(Vector2(mg, mg), vp - Vector2(mg * 2.0, mg * 2.0))
                                                                                                                                if inner.has_point(sp):
                                                                                                                                        return
                                                                                                                                var c := vp * 0.5
                                                                                                                                var dir := sp - c
                                                                                                                                if dir.length() < 1.0:
                                                                                                                                        return
                                                                                                                                var k := 1000000000.0
                                                                                                                                if dir.x > 0.0:
                                                                                                                                        k = minf(k, (inner.end.x - c.x) / dir.x)
                                                                                                                                if dir.x < 0.0:
                                                                                                                                        k = minf(k, (inner.position.x - c.x) / dir.x)
                                                                                                                                if dir.y > 0.0:
                                                                                                                                        k = minf(k, (inner.end.y - c.y) / dir.y)
                                                                                                                                if dir.y < 0.0:
                                                                                                                                        k = minf(k, (inner.position.y - c.y) / dir.y)
                                                                                                                                if k > 100000000.0:
                                                                                                                                        return
                                                                                                                                var edge := c + dir * k
                                                                                                                                var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.0045)
                                                                                                                                var col := Color(0.60,0.76,0.82,0.75) if btl.get_meta("bunker_v9",false) else Color(0.52, 0.9, 0.7, 0.9 * pulse)
                                                                                                                                var pts := PackedVector2Array([Vector2(15, 0), Vector2(-9, 9), Vector2(-4, 0), Vector2(-9, -9)])
                                                                                                                                var xf := Transform2D(dir.angle(), edge)
                                                                                                                                var tri := PackedVector2Array()
                                                                                                                                for p in pts:
                                                                                                                                        tri.append(xf * p)
                                                                                                                                draw_colored_polygon(tri, col)
                                                                                                                                if btl.get_meta("bunker_v9",false): return
                                                                                                                                draw_arc(edge, 21.0, 0.0, TAU, 26, Color(col.r, col.g, col.b, 0.30), 1.4)
                                                                                                                                draw_arc(edge, 26.0, dir.angle() - 0.5, dir.angle() + 0.5, 12, Color(col.r, col.g, col.b, 0.55), 2.0)

# ================= МИНИКАРТА (территория WorldBox-стиля) =================
class MiniMap extends Control:
                                                                var btl = null
                                                                var pulse_t := 0.0
                                                                var _bench_mm := OS.get_environment("ZBENCH_DISABLE").contains("minimap")
                                                                var _mm_acc := 0.0

                                                                func _ready() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                btl = get_parent()
                                                                                                                                set_process(true)

                                                                func _process(delta: float) -> void:
                                                                                                                                pulse_t += delta
                                                                                                                                _mm_acc += delta
                                                                                                                                if not _bench_mm and _mm_acc >= 0.15:
                                                                                                                                                                                                _mm_acc = 0.0
                                                                                                                                                                                                queue_redraw()

                                                                func _draw() -> void:
                                                                                                                                if btl == null:
                                                                                                                                                                                                return
                                                                                                                                var r := Rect2(Vector2.ZERO, size)
                                                                                                                                draw_rect(r, Color(0.05, 0.06, 0.05, 0.88), true)
                                                                                                                                draw_rect(r, ZUI.BORDER, false, 2.0)
                                                                                                                                var ms: Vector2 = btl.map_size
                                                                                                                                var k: float = minf(size.x / ms.x, size.y / ms.y)
                                                                                                                                var off := (size - ms * k) * 0.5
                                                                                                                                # территория: зелёное влияние отряда
                                                                                                                                for c in btl.terr:
                                                                                                                                                                                                var v: float = float(btl.terr[c])
                                                                                                                                                                                                var cell_rect := Rect2(off + Vector2(c.x * btl.TERR_CELL, c.y * btl.TERR_CELL) * k, Vector2(btl.TERR_CELL, btl.TERR_CELL) * k)
                                                                                                                                                                                                draw_rect(cell_rect, Color(0.35, 0.75, 0.4, 0.30 * v), true)
                                                                                                                                # стены
                                                                                                                                for wr in btl.walls:
                                                                                                                                                                                                var wr2 := Rect2(off + (wr.position as Vector2) * k, (wr.size as Vector2) * k)
                                                                                                                                                                                                draw_rect(wr2, Color(0.45, 0.5, 0.55, 0.8), true)
                                                                                                                                # зона миссии
                                                                                                                                if (btl.mission == "warehouse" or btl.mission == "defense") and btl.zone_target.size != Vector2.ZERO:
                                                                                                                                                                                                var zr := Rect2(off + (btl.zone_target.position as Vector2) * k, (btl.zone_target.size as Vector2) * k)
                                                                                                                                                                                                draw_rect(zr, Color(0.9, 0.8, 0.3, 0.25), true)
                                                                                                                                                                                                draw_rect(zr, Color(0.9, 0.8, 0.3, 0.9), false, 2.0)
                                                                                                                                # планшеты
                                                                                                                                for pr in btl.props:
                                                                                                                                                                                                if pr["kind"] == "tablet_crate":
                                                                                                                                                                                                                                                                var pp: Vector2 = off + (pr["pos"] as Vector2) * k
                                                                                                                                                                                                                                                                var pl: float = 0.6 + 0.4 * sin(pulse_t * 5.0 + pp.x)
                                                                                                                                                                                                                                                                draw_circle(pp, 5.0, Color(1.0, 0.85, 0.3, pl))
                                                                                                                                # эвакуация
                                                                                                                                if btl.extraction_open:
                                                                                                                                                                                                var ep: Vector2 = off + (btl.extraction as Vector2) * k
                                                                                                                                                                                                var pl2: float = 0.6 + 0.4 * sin(pulse_t * 4.0)
                                                                                                                                                                                                draw_circle(ep, 6.0, Color(0.4, 0.95, 0.5, pl2))
                                                                                                                                                                                                draw_line(ep + Vector2(-8, 0), ep + Vector2(8, 0), Color(0.4, 0.95, 0.5, 0.9), 2.0)
                                                                                                                                                                                                draw_line(ep + Vector2(0, -8), ep + Vector2(0, 8), Color(0.4, 0.95, 0.5, 0.9), 2.0)
                                                                                                                                # зомби (тревожные и близкие)
                                                                                                                                var ppos: Vector2 = btl.player["spr"].position
                                                                                                                                for z in btl.zombies:
                                                                                                                                                                                                if not z["alive"]:
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var zp: Vector2 = z["spr"].position
                                                                                                                                                                                                var close := zp.distance_to(ppos) < 1000.0
                                                                                                                                                                                                if z["alert"] or close:
                                                                                                                                                                                                                                                                var col := Color(0.95, 0.35, 0.3, 0.9) if z["alert"] else Color(0.85, 0.45, 0.4, 0.55)
                                                                                                                                                                                                                                                                draw_circle(off + zp * k, 3.0 if z["kind"] != "brute" and z["kind"] != "alpha" else 5.0, col)
                                                                                                                                # союзники
                                                                                                                                for a in btl.allies:
                                                                                                                                                                                                if not a["alive"]:
                                                                                                                                                                                                                                                                continue
                                                                                                                                                                                                var ap: Vector2 = off + (a["spr"].position as Vector2) * k
                                                                                                                                                                                                draw_circle(ap, 4.0, Color(0.4, 0.9, 0.45, 0.9))
                                                                                                                                # гражданский (спасение)
                                                                                                                                if btl.rescue_npc != null and btl.rescue_npc["alive"]:
                                                                                                                                                                                                var cp: Vector2 = off + (btl.rescue_npc["spr"].position as Vector2) * k
                                                                                                                                                                                                draw_circle(cp, 4.0, Color(0.45, 0.85, 0.95, 0.9))
                                                                                                                                # игрок: белая точка + направление прицела
                                                                                                                                if btl.player["spr"].visible:
                                                                                                                                                                                                var me: Vector2 = off + ppos * k
                                                                                                                                                                                                draw_circle(me, 5.0, Color(0.95, 0.95, 0.9, 1.0))
                                                                                                                                                                                                var aim := Vector2.from_angle(btl.player["aim"]) * 12.0
                                                                                                                                                                                                draw_line(me, me + aim, Color(1, 0.9, 0.5, 0.9), 2.0)
                                                                                                                                # заголовок
                                                                                                                                # лестница за шлюзом: путь наверх (спокойный маркер, горит после открытия)
                                                                                                                                if btl.is_bunker and not btl.stairs_prop.is_empty() and btl.stairs_prop.has("pos"):
                                                                                                                                    var stp: Vector2 = (btl.stairs_prop["pos"] as Vector2)
                                                                                                                                    var stc := Color(0.5, 0.95, 0.6, 0.9) if btl.extraction_open else Color(0.55, 0.75, 0.62, 0.4)
                                                                                                                                    draw_circle(off + stp * k, 4.0, stc)
                                                                                                                                    draw_arc(off + stp * k, 7.0, 0, TAU, 16, stc, 1.2)
                                                                                                                                draw_string(ThemeDB.fallback_font, Vector2(6, 14), btl.sector_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.86, 0.75, 0.9))

# ================= ВВОД =================
func _unhandled_input(event: InputEvent) -> void:
                                                                if event is InputEventKey and event.pressed and not event.echo and is_bunker and battle_over == "":
                                                                        match event.physical_keycode:
                                                                                KEY_F:
                                                                                        _zpro_toggle_flash()
                                                                                        return
                                                                                KEY_G:
                                                                                        _zpro_use_smoke()
                                                                                        return
                                                                if battle_over != "":
                                                                                                                                return
                                                                # ---------- тач: стики ----------
                                                                if event is InputEventScreenTouch:
                                                                                                                                if _desktop_input():
                                                                                                                                                                                                return
                                                                                                                                var st := event as InputEventScreenTouch
                                                                                                                                if st.pressed:
                                                                                                                                                                                                _touch_pts[st.index] = st.position
                                                                                                                                                                                                var bl := _stick_base("l")
                                                                                                                                                                                                var br := _stick_base("r")
                                                                                                                                                                                                if st.position.distance_to(bl) <= STICK_ACT_R and _stick_move_idx < 0 and _stick_aim_idx != st.index:
                                                                                                                                                                                                                                                                _stick_move_idx = st.index
                                                                                                                                                                                                                                                                # FIX7v2: двойной тап по стику хода — БЕГ, пока стик не отпущен
                                                                                                                                                                                                                                                                var now_mt := Time.get_ticks_msec() * 0.001
                                                                                                                                                                                                                                                                if now_mt - _last_move_tap < 0.34:
                                                                                                                                                                                                                                                                        _run_mode = true
                                                                                                                                                                                                                                                                        _last_move_tap = -10.0
                                                                                                                                                                                                                                                                        if tut != null and not run_hint_done:
                                                                                                                                                                                                                                                                                run_hint_done = true
                                                                                                                                                                                                                                                                                tut.hint("run", "run", "БЕГ", "Двойной тап по стику хода — бег. Отпустите стик и потяните снова — снова шаг. Бег шумный: мёртвые слышат издалека.", 45)
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                        _last_move_tap = now_mt
                                                                                                                                                                                                elif st.position.distance_to(br) <= STICK_ACT_R and _stick_aim_idx < 0 and _stick_move_idx != st.index:
                                                                                                                                                                                                                                                                _stick_aim_idx = st.index
                                                                                                                                                                                                                                                                _aim_stick_vec(st.position)
                                                                                                                                                                                                                                                                # FIX6: двойной тап правого стика — перезарядка
                                                                                                                                                                                                                                                                var now_t := Time.get_ticks_msec() * 0.001
                                                                                                                                                                                                                                                                if now_t - _last_aim_tap < 0.35:
                                                                                                                                                                                                                                                                                                                                _last_aim_tap = -10.0
                                                                                                                                                                                                                                                                                                                                _reload_player()
                                                                                                                                                                                                                                                                else:
                                                                                                                                                                                                                                                                                                                                _last_aim_tap = now_t
                                                                                                                                else:
                                                                                                                                                                                                _touch_pts.erase(st.index)
                                                                                                                                                                                                if st.index == _stick_move_idx:
                                                                                                                                                                                                                                                                _stick_move_idx = -1
                                                                                                                                                                                                                                                                direct_vec = Vector2.ZERO
                                                                                                                                                                                                                                                                # FIX7v2: стик отпущен — бег выключается, следующая потяжка = шаг
                                                                                                                                                                                                                                                                _run_mode = false
                                                                                                                                                                                                                                                                _last_move_tap = -10.0
                                                                                                                                                                                                elif st.index == _stick_aim_idx:
                                                                                                                                                                                                                                                                _stick_aim_idx = -1
                                                                                                                                                                                                                                                                _r_fire_latch = false
                                                                                                                                                                                                                                                                _r_was_center = false
                                                                                                                                                                                                                                                                manual_fire = false
                                                                                                                                                                                                                                                                manual_aim = false
                                                                elif event is InputEventScreenDrag:
                                                                                                                                if _desktop_input():
                                                                                                                                                                                                return
                                                                                                                                var sd := event as InputEventScreenDrag
                                                                                                                                if sd.index == _stick_move_idx:
                                                                                                                                                                                                _move_stick_vec(sd.position)
                                                                                                                                elif sd.index == _stick_aim_idx:
                                                                                                                                                                                                _aim_stick_vec(sd.position)
                                                                                                                                return
                                                                # ---------- клавиатура ----------
                                                                if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
                                                                                                                                var key := (event as InputEventKey).keycode
                                                                                                                                if key == KEY_R:
                                                                                                                                                                                                _reload_player()
                                                                                                                                elif key == KEY_E:
                                                                                                                                                                                                if not cur_interact.is_empty():
                                                                                                                                                                                                                                                                _do_interact(cur_interact)
                                                                                                                                elif key == KEY_ESCAPE:
                                                                                                                                        # FIX11: ESC — переключатель: закрывает открытое окно (пауза/рюкзак/КПК/лут)
                                                                                                                                        var esc_closed := false
                                                                                                                                        for w in [pause_win, med_win, kpk_win, loot_win]:
                                                                                                                                                if w != null and is_instance_valid(w):
                                                                                                                                                        ZUI.close_window(w)
                                                                                                                                                        esc_closed = true
                                                                                                                                                        break
                                                                                                                                        if not esc_closed:
                                                                                                                                                _open_pause()
                                                                                                                                elif key == KEY_1:
                                                                                                                                                                                                _select_weapon(0)
                                                                                                                                elif key == KEY_2:
                                                                                                                                                                                                _select_weapon(1)
                                                                                                                                elif key == KEY_3:
                                                                                                                                                                                                _select_weapon(2)
                                                                                                                                elif key == KEY_4:
                                                                                                                                                                                                _select_weapon(3)
                                                                                                                                elif key == KEY_5:
                                                                                                                                                                _quick_use_item(_quick_item_at(0))
                                                                                                                                elif key == KEY_6:
                                                                                                                                                                _quick_use_item(_quick_item_at(1))
                                                                                                                                elif key == KEY_7:
                                                                                                                                                                _quick_use_item(_quick_item_at(2))
                                                                                                                                elif key == KEY_8:
                                                                                                                                                                _quick_use_item(_quick_item_at(3))
                                                                                                                                elif key == KEY_9:
                                                                                                                                                                _quick_use_item(_quick_item_at(4))
                                                                                                                                elif key == KEY_0:
                                                                                                                                                                _quick_use_item(_quick_item_at(5))

func _input(event: InputEvent) -> void:
                                                                if battle_over != "" or not _desktop_input():
                                                                                                                                return
                                                                if event is InputEventMouseButton:
                                                                                                                                var mb := event as InputEventMouseButton
                                                                                                                                if mb.button_index != MOUSE_BUTTON_LEFT:
                                                                                                                                                                                                return
                                                                                                                                if mb.pressed:
                                                                                                                                                                                                if get_viewport().gui_get_hovered_control() != null:
                                                                                                                                                                                                                                return
                                                                                                                                                                                                mouse_aim_active = true
                                                                                                                                                                                                mouse_aim_timer = 0.8
                                                                                                                                                                                                manual_aim = true
                                                                                                                                                                                                manual_fire = true
                                                                                                                                else:
                                                                                                                                                                                                manual_fire = false
                                                                                                                                                                                                mouse_aim_timer = 0.8
                                                                elif event is InputEventMouseMotion:
                                                                                                                                if get_viewport().gui_get_hovered_control() == null:
                                                                                                                                                                                                mouse_aim_pos = (event as InputEventMouseMotion).position
                                                                                                                                                                                                mouse_aim_active = true
                                                                                                                                                                                                mouse_aim_timer = 0.8
                                                                                                                                                                                                manual_aim = true

func _select_weapon(i: int) -> void:
                                                                var owned: Array = G.zsave["weapons"]
                                                                if i >= 0 and i < owned.size():
                                                                                                                                player["weapon"] = owned[i]
                                                                                                                                G.zsave["cur_weapon"] = player["weapon"]
                                                                                                                                var wd: Dictionary = G.ZWEAPONS[player["weapon"]]
                                                                                                                                player["mag"] = mini(int(player["mag"]), int(wd["mag"]))
                                                                                                                                player["reload_t"] = 0.0
                                                                                                                                _toast("Оружие: %s" % G.Z_WEAPON_NAMES.get(player["weapon"], player["weapon"]))

func _stick_base(side: String) -> Vector2:
                                                                var vp := get_viewport_rect().size
                                                                var x := maxf(236.0, vp.x * 0.095)
                                                                if side == "l":
                                                                                                                                return Vector2(x, vp.y - 244.0)
                                                                return Vector2(vp.x - x, vp.y - 244.0)

func _move_stick_vec(at: Vector2) -> void:
                                                                var v: Vector2 = (at - _stick_base("l")) / STICK_KNOB
                                                                direct_vec = v.limit_length(1.0)

func _aim_stick_vec(at: Vector2) -> void:
                                                                var av: Vector2 = at - _stick_base("r")
                                                                var mag := av.length()
                                                                var k: float = mag / STICK_KNOB
                                                                if mag > 14.0:
                                                                                                                                manual_aim = true
                                                                                                                                manual_ang = av.angle()
                                                                # гистерезис: огонь только после доводки от центра к краю
                                                                if k < STICK_FIRE_OFF:
                                                                                                                                _r_was_center = true
                                                                                                                                if _r_fire_latch:
                                                                                                                                                                                                _r_fire_latch = false
                                                                                                                                                                                                manual_fire = false
                                                                elif _r_was_center and k >= STICK_FIRE_K:
                                                                                                                                _r_fire_latch = true
                                                                                                                                manual_fire = true

# ================= ГЛАВНЫЙ ЦИКЛ =================
func _process(delta: float) -> void:
                                                                if bench.has("logic"):
                                                                                                                                return
                                                                _frame_i += 1
                                                                # FIX6: отсечение невидимых спрайтов — 4 Гц (ФПС на слабых устройствах)
                                                                _cull_acc += delta
                                                                if _cull_acc >= 0.25:
                                                                                                                                _cull_acc = 0.0
                                                                                                                                _cull_offscreen()
                                                                # FIX5: измерение ФПС раз в 1.6с, автомат качества
                                                                fps_acc += delta
                                                                fps_n += 1
                                                                if fps_acc >= 1.6:
                                                                                                                                fps_avg = float(fps_n) / fps_acc
                                                                                                                                fps_acc = 0.0
                                                                                                                                fps_n = 0
                                                                                                                                if q_lock:
                                                                                                                                                                                                fps_avg = 60.0
                                                                                                                                elif fps_avg < 27.0 and q_level > 0:
                                                                                                                                                                                                q_level -= 1
                                                                                                                                                                                                q_up_timer = 0.0
                                                                                                                                                                                                _apply_quality()
                                                                                                                                                                                                _log("ГРАФИКА: режим производительности %s" % ("МИНИМУМ" if q_level <= 0 else "СРЕДНИЙ"), Color(0.7, 0.75, 0.6), "СИСТЕМА")
                                                                                                                                elif fps_avg > 54.0 and q_level < 2:
                                                                                                                                                                                                q_up_timer += 1.6
                                                                                                                                                                                                if q_up_timer >= 9.6:
                                                                                                                                                                                                                                                                q_level += 1
                                                                                                                                                                                                                                                                q_up_timer = 0.0
                                                                                                                                                                                                                                                                _apply_quality()
                                                                                                                                else:
                                                                                                                                                                                                q_up_timer = 0.0
                                                                # эффекты всегда идут (даже в паузе — но без геймплея)
                                                                if battle_over != "":
                                                                                                                                end_timer += delta
                                                                                                                                if end_timer > 1.5 and battle_over == "win":
                                                                                                                                                                                                battle_over = "done"
                                                                                                                                                                                                if main_ref != null:
                                                                                                                                                                                                                                                                main_ref.after_zbattle(true)
                                                                                                                                elif end_timer > 1.5 and battle_over == "lose":
                                                                                                                                                                                                battle_over = "done"
                                                                                                                                                                                                if main_ref != null:
                                                                                                                                                                                                                                                                main_ref.after_zbattle(false)
                                                                                                                                queue_redraw_all()
                                                                                                                                return
                                                                _quick_item_refresh(delta)
                                                                _tick_ammo_check(delta)
                                                                if _desktop_input() and mouse_aim_timer > 0.0:
                                                                                                                                mouse_aim_timer = maxf(0.0, mouse_aim_timer - delta)
                                                                                                                                if mouse_aim_timer <= 0.0 and not manual_fire:
                                                                                                                                                                mouse_aim_active = false
                                                                                                                                                                manual_aim = false
                                                                time_alive += delta
                                                                # подъём по лестнице: плавное затемнение → победа (выход из бункера)
                                                                if stairs_fade > 0.0 and battle_over == "":
                                                                                                stairs_fade += delta
                                                                                                if stairs_fade >= 2.0:
                                                                                                                                stairs_fade = 0.0
                                                                                                                                _win()
                                                                if not paused:
                                                                                                                                _tick_player(delta)
                                                                                                                                _tick_zombies(delta)
                                                                                                                                _tick_allies(delta)
                                                                                                                                _tick_defense(delta)
                                                                                                                                _tick_extraction(delta)
                                                                                                                                _tick_territory(delta)
                                                                                                                                _zpro_tick(delta)
                                                                                                                                # спасение: гражданский следует
                                                                                                                                if mission == "rescue" and rescue_npc != null and rescue_npc["alive"] and rescue_follow:
                                                                                                                                                                                                var tp: Vector2 = player["spr"].position + Vector2(30, 30)
                                                                                                                                                                                                var np := (rescue_npc["spr"].position as Vector2).move_toward(tp, 120.0 * delta)
                                                                                                                                                                                                np = _collide_circle(np, 11.0)
                                                                                                                                                                                                rescue_npc["spr"].position = np
                                                                                                                                # камера
                                                                                                                                var cpos: Vector2 = player["spr"].position
                                                                                                                                camera.position = camera.position.lerp(cpos, minf(1.0, 10.0 * delta))
                                                                                                                                # FIX11: тряска камеры — затухает со временем, смещение через offset
                                                                                                                                if _cam_shake > 0.001:
                                                                                                                                        _cam_shake = maxf(0.0, _cam_shake - delta * 2.4)
                                                                                                                                        var sk := _cam_shake * _cam_shake
                                                                                                                                        camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 9.0 * sk
                                                                                                                                elif camera.offset != Vector2.ZERO:
                                                                                                                                        camera.offset = Vector2.ZERO
                                                                                                                                # halo игрока: клиппинг света по текущей комнате
                                                                                                                                if is_bunker:
                                                                                                                                                                                                var hs: Sprite2D = player["halo"]
                                                                                                                                                                                                var hm := hs.material as ShaderMaterial
                                                                                                                                                                                                if hm != null:
                                                                                                                                                                                                                                                                var hz := _room_rect_at(hs.position)
                                                                                                                                                                                                                                                                hm.set_shader_parameter("clip_rect", Rect2(hz.position, hz.size))
                                                                                                                                # мышь/клавиатура на ПК
                                                                                                                                if _desktop_input():
                                                                                                                                                                                                var mv := Vector2.ZERO
                                                                                                                                                                                                if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
                                                                                                                                                                                                                                                                mv.y -= 1.0
                                                                                                                                                                                                if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
                                                                                                                                                                                                                                                                mv.y += 1.0
                                                                                                                                                                                                if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
                                                                                                                                                                                                                                                                mv.x -= 1.0
                                                                                                                                                                                                if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
                                                                                                                                                                                                                                                                mv.x += 1.0
                                                                                                                                                                                                if mv.length() > 0.1:
                                                                                                                                                                                                                                                                direct_vec = mv.normalized()
                                                                                                                                                                                                elif _stick_move_idx < 0:
                                                                                                                                                                                                                                                                direct_vec = Vector2.ZERO
                                                                                                                                                                                                # мышь — прицел
                                                                                                                                                                                                if player["spr"].visible and mouse_aim_active:
                                                                                                                                                                                                                                                                manual_ang = (get_global_mouse_position() - player["spr"].position).angle()
                                                                                                                                # атмосфера бункера: искры и лампы
                                                                                                                                _ambient_tick(delta)
                                                                # HUD
                                                                _update_interact(delta)
                                                                # затухания
                                                                # плавная виньетка урона: мягкий подъём к цели и плавный спад
                                                                var vtg := float(vignette_dmg_tgt)
                                                                if vtg > vignette_dmg:
                                                                                                                                vignette_dmg = lerpf(vignette_dmg, vtg, 1.0 - exp(-delta * 16.0))
                                                                                                                                if vtg - vignette_dmg < 0.02:
                                                                                                                                                                                                vignette_dmg = vtg
                                                                else:
                                                                                                                                vignette_dmg = maxf(vtg, vignette_dmg - delta * 0.55)
                                                                vignette_dmg_tgt = maxf(0.0, vignette_dmg_tgt - delta * 0.55)
                                                                var dl: Array = []
                                                                for e in log_lines:
                                                                                                                                e["t"] = float(e["t"]) - delta
                                                                                                                                if float(e["t"]) <= 0.0:
                                                                                                                                                                                                dl.append(e)
                                                                for e in dl:
                                                                                                                                log_lines.erase(e)
                                                                var dt2: Array = []
                                                                for t in toasts:
                                                                                                                                t["t"] = float(t["t"]) - delta
                                                                                                                                if float(t["t"]) <= 0.0:
                                                                                                                                                                                                dt2.append(t)
                                                                for t in dt2:
                                                                                                                                toasts.erase(t)
                                                                # трассеры/вспышки/кровь
                                                                # FIX11: индикатор направления удара гаснет ~1.2 с
                                                                if hit_dir_t > 0.0:
                                                                                                                                hit_dir_t = maxf(0.0, hit_dir_t - delta * 0.85)
                                                                var dead_tr: Array = []
                                                                for tracer in tracer_fx:
                                                                                                                                tracer["t"] = float(tracer["t"]) - delta
                                                                                                                                if float(tracer["t"]) <= 0.0:
                                                                                                                                                                                                dead_tr.append(tracer)
                                                                for tracer in dead_tr:
                                                                                                                                tracer_fx.erase(tracer)
                                                                var dead_fl: Array = []
                                                                for flash in flash_fx:
                                                                                                                                flash["t"] = float(flash["t"]) - delta
                                                                                                                                if float(flash["t"]) <= 0.0:
                                                                                                                                                                                                dead_fl.append(flash)
                                                                for flash in dead_fl:
                                                                                                                                flash_fx.erase(flash)
                                                                # FIX11: пока есть живые трассеры/вспышки/брызги — рисуем слой эффектов
                                                                if fx_layer != null and is_instance_valid(fx_layer) and (not tracer_fx.is_empty() or not flash_fx.is_empty() or not blood_burst.is_empty()):
                                                                                                                                fx_layer.queue_redraw()
                                                                # FIX5: HUD перерисовывается каждый кадр только при живых стиках/вспышках,
                                                                # иначе — 30/20/15 Гц по уровню качества (экономия CPU на телефоне)
                                                                _hud_acc += delta
                                                                var stick_active: bool = _stick_move_idx >= 0 or _stick_aim_idx >= 0 or vignette_dmg > 0.0 or not toasts.is_empty() or battle_over != "" or _ammo_check_t > 0.0 or _ammo_result_t > 0.0
                                                                var hud_period := 0.033 if q_level >= 2 else (0.05 if q_level == 1 else 0.07)
                                                                if stick_active or _hud_acc >= hud_period:
                                                                                                                                _hud_acc = 0.0
                                                                                                                                queue_redraw_all()

func _desktop_input() -> bool:
                                                                return DisplayServer.get_name() in ["x11", "windows", "macos", "wayland"]

func queue_redraw_all() -> void:
                                                                if hud_ctrl != null and is_instance_valid(hud_ctrl):
                                                                                                                                hud_ctrl.queue_redraw()

func _ambient_tick(delta: float) -> void:
                                                                # искры проводки
                                                                spark_t -= delta
                                                                if spark_t <= 0.0:
                                                                                                                                spark_t = randf_range(2.5, 6.0)
                                                                                                                                if not spark_points.is_empty() and is_bunker:
                                                                                                                                                                                                var sp: Vector2 = spark_points[randi() % spark_points.size()]
                                                                                                                                                                                                G.play_sfx("z_spark", -12.0)
                                                                                                                                                                                                flash_fx.append({"pos": sp, "t": 0.1})
                                                                # мигание аварийных ламп (аддитивные спрайты — дёшево)
                                                                var t := Time.get_ticks_msec() * 0.001
                                                                for i in range(lamp_lights.size()):
                                                                                                                                var e: Dictionary = lamp_lights[i]
                                                                                                                                var flick := 0.75 + 0.25 * sin(t * 7.0 + i * 2.1) + 0.08 * sin(t * 23.0 + i)
                                                                                                                                if randf() < 0.004:
                                                                                                                                                                                                flick *= 0.15
                                                                                                                                (e["spr"] as Sprite2D).self_modulate.a = clampf(flick, 0.05, 1.3)
                                                                # потолочные LED: ровный свет с редким подмигиванием (на q0 — статика)
                                                                if q_level > 0:
                                                                                                                                for j in range(lab_lights.size()):
                                                                                                                                                                                                var le: Dictionary = lab_lights[j]
                                                                                                                                                                                                var steady := 1.0 + 0.045 * sin(t * 2.2 + j * 1.7)
                                                                                                                                                                                                if randf() < 0.0035:
                                                                                                                                                                                                                                                                steady *= 0.55
                                                                                                                                                                                                (le["spr"] as Sprite2D).self_modulate.a = clampf(steady, 0.4, 1.15)
                                                                # v2.8: умирающие лампы — свет отказывает рывками и оживает
                                                                for dl in dying_lamps:
                                                                        var cd: float = float(dl["cd"]) - delta
                                                                        if cd > 0.0:
                                                                                dl["cd"] = cd
                                                                                continue
                                                                        if dl.has("tw") and (dl["tw"] as Tween).is_valid():
                                                                                dl["cd"] = randf_range(9.0, 18.0)
                                                                                continue
                                                                        dl["cd"] = randf_range(9.0, 18.0)
                                                                        var wall_spr: Sprite2D = dl["wall"]
                                                                        var glow_spr: Sprite2D = dl["spr"]
                                                                        var pool_spr: Sprite2D = dl["pool"]
                                                                        G.play_sfx("z_relay", -16.0, randf_range(0.9, 1.1))
                                                                        flash_fx.append({"pos": wall_spr.position, "t": 0.09})
                                                                        var tw := glow_spr.create_tween()
                                                                        tw.set_parallel(true)
                                                                        tw.tween_property(glow_spr, "self_modulate:a", 0.04, 0.16)
                                                                        tw.tween_property(pool_spr, "modulate:a", 0.02, 0.16)
                                                                        tw.tween_property(wall_spr, "self_modulate", Color(0.4, 0.45, 0.5), 0.16)
                                                                        tw.chain().tween_interval(randf_range(1.1, 2.4))
                                                                        tw.chain().tween_property(glow_spr, "self_modulate:a", 0.9, 0.05)
                                                                        tw.parallel().tween_property(pool_spr, "modulate:a", 0.24, 0.05)
                                                                        tw.parallel().tween_property(wall_spr, "self_modulate", Color(1, 1, 1), 0.05)
                                                                        tw.chain().tween_property(glow_spr, "self_modulate:a", 0.05, 0.09)
                                                                        tw.parallel().tween_property(pool_spr, "modulate:a", 0.03, 0.09)
                                                                        tw.chain().tween_property(glow_spr, "self_modulate:a", 1.0, 0.22)
                                                                        tw.parallel().tween_property(pool_spr, "modulate:a", 0.30, 0.22)
                                                                        dl["tw"] = tw
var _interact_acc := 0.0
func _update_interact(delta: float = 0.0) -> void:
                                                                if interact_bubble == null or not is_instance_valid(interact_bubble):
                                                                                                                                return
                                                                # ФПС: поиск интерактива — 10 раз/сек, не каждый кадр
                                                                _interact_acc += delta
                                                                if _interact_acc < 0.1:
                                                                                                                                return
                                                                _interact_acc = 0.0
                                                                var info := _find_interact()
                                                                if info.is_empty():
                                                                                                                                cur_interact = {}
                                                                elif cur_interact.is_empty() or info["kind"] != cur_interact.get("kind", "") or info.get("ref") != cur_interact.get("ref"):
                                                                                                                                cur_interact = info
                                                                else:
                                                                                                                                cur_interact = info
                                                                if cur_interact.is_empty():
                                                                                                                                interact_bubble.visible = false
                                                                                                                                return
                                                                # FIX6: SVG-кнопка появляется ПРЯМО НА ОБЪЕКТЕ
                                                                var kind: String = str(cur_interact.get("kind", ""))
                                                                var hold: float = float(cur_interact.get("hold", 0.0))
                                                                interact_bubble.visible = true
                                                                interact_bubble.setup(_bubble_icon(kind), _bubble_caption(kind, false), _bubble_caption(kind, true), hold)

func _med_closed() -> void:
                                                                med_win = null
                                                                paused = false

func _kpk_closed() -> void:
                                                                kpk_win = null
                                                                paused = false

func _pause_closed() -> void:
                                                                pause_win = null
                                                                paused = false

# ================= КОНЕЦ БОЯ =================
func _win() -> void:
                                                                if battle_over != "":
                                                                                                                                return
                                                                battle_over = "win"
                                                                _complete_objective("evac")
                                                                _complete_objective("exit")
                                                                end_timer = 0.0
                                                                G.play_sfx("victory", -6.0)
                                                                G.zsave["wins"] = int(G.zsave["wins"]) + 1
                                                                G.zsave["battles"] = int(G.zsave["battles"]) + 1
                                                                G.zsave["sector"] = maxi(int(G.zsave["sector"]), sector_idx + 1)
                                                                G.z_bank_add(20 + sector_idx * 4)
                                                                # судьба отряда
                                                                for a in allies:
                                                                                                                                var survived: bool = a["alive"]
                                                                                                                                _sync_squad_member(a, survived)
                                                                # дневник
                                                                if int(G.zsave.get("diary", 0)) < sector_idx + 1:
                                                                                                                                G.zsave["diary"] = sector_idx + 1
                                                                if sector_idx >= 19:
                                                                                                                                G.zsave["campaign_won"] = true
                                                                G.zsave["pstate"] = player["st"]
                                                                G.zsave["infect"] = float(player["infect"])
                                                                if is_bunker:
                                                                        # переменная кампании: не потрачен редкий меднабор (ТЗ п.17)
                                                                        G.zset_flag("saved_medkit", int(G.zsave["inv"].get("medkit", 0)) > 0)
                                                                G.write_save()
                                                                _log("Сектор пройден.", Color(0.6, 0.95, 0.6), "СИСТЕМА")

func _lose() -> void:
                                                                if battle_over != "":
                                                                                                                                return
                                                                battle_over = "lose"
                                                                end_timer = 0.0
                                                                G.play_sfx("defeat", -6.0)
                                                                G.zsave["battles"] = int(G.zsave["battles"]) + 1
                                                                for a in allies:
                                                                                                                                _sync_squad_member(a, bool(a["alive"]))
                                                                # FIX-3: поражение не сохраняет разрушенное тело — реванш начинается свежим
                                                                G.zsave["pstate"] = Med.mk_state()
                                                                G.zsave["infect"] = 0.0
                                                                G.write_save()
                                                                _log("Сигнал потерян...", Color(0.95, 0.5, 0.4), "СИСТЕМА")

func _sync_squad_member(ally: Dictionary, alive: bool) -> void:
                                                                var saved_member: Dictionary = ally.get("squad_member", {})
                                                                if not saved_member.is_empty():
                                                                                                                                saved_member["alive"] = alive
                                                                                                                                return
                                                                var callsign: String = str(ally.get("callsign", ""))
                                                                for s in G.zsave["squad"]:
                                                                                                                                if s.get("name", "") == callsign:
                                                                                                                                                                                                s["alive"] = alive
                                                                                                                                                                                                return
                                                                G.zsave["squad"].append({"name": callsign, "alive": alive})

# ============================================================
# ПРОЛОГ «ЗАРЯ» — СЦЕНАРИЙНЫЙ СЛОЙ БОЯ (по документу сценария)
# Многоэтапный пролог: камера пробуждения → медсектор (Пациент-06,
# щитовая, питание) → палата № 12 (Э-12) → мастерская Серова →
# техсектор (генератор 18%, утечка газа) → оружейная → карантинный
# блок (изоляция, отсчёт) → комната наблюдения (Морозова) → побег
# (сталкер, свет/тьма) → грузовой шлюз (гидравлика, V-18) →
# «Снежная линия».
# Аудио: ZAmbience (гул реактора, вентиляция, сирены, шёпот).
# Режиссура: ZCutscene-оверлеи, ZTerminal-экраны, ZDialog-выборы.
# Переменные кампании: G.zset_flag(...) — 9 флагов из ТЗ п.17.
# ============================================================

# ---------- состояние пролога ----------
var zp_amb: ZAmbience = null
var zp_fast := false                      # smoke-режим: кат-сцены ускорены
var zp_overlay_layer: CanvasLayer = null   # активный оверлей (для тестов)
var zp := {}
var zp_frost: ColorRect = null          # иней на экране (холодные зоны)
var zp_smoke_zones: Array = []          # завесы дымовых шашек {rect, t}
var zp_stalker = null                   # заражённый охранник (преследование)
var zp_stalker_rt := 0.0
var zp_countdown := 0.0                 # отсчёт изоляции карантина
var zp_beep_acc := 0.0
var zp_cough_acc := 0.0
var zp_room_cur := ""
var zp_lights_out := false              # свет погас (финальный побег)
var zp_gate_state := 0                  # гидравлика шлюза: 0..4
var zp_gate_t := 0.0
var zp_v18_spawned := false
var zp_v18_timer := -1.0                # перегрев гидравлики при осмотре
var zp_speaker_done := false
var zp_cam_note := false                # просмотрены камеры (прачечная-ветка)
var zp_ai_msg := {}                     # однократные реплики ИИ по зонам
var zp_last_hint := ""

const ZPRO_KILLS := "zp_kills_qr"       # убийства в карантине (used_stealth_route)

# прямоугольники комнат (для триггеров) — по Room*_def сцены
func zp_room_rect(id: String) -> Rect2:
                match id:
                                "r6": return Rect2(96, 1324, 872, 580)      # камера пробуждения
                                "r7": return Rect2(990, 1324, 872, 580)     # медкоридор
                                "r8": return Rect2(1884, 1324, 872, 580)    # крио-хранилище
                                "r9": return Rect2(96, 1926, 872, 580)      # генераторная
                                "r10": return Rect2(990, 1926, 872, 580)    # мастерская Серова
                                "r11": return Rect2(1884, 1926, 872, 580)   # палата № 12
                                "r12": return Rect2(96, 2528, 872, 580)     # оружейная
                                "r13": return Rect2(990, 2528, 872, 580)    # карантинный блок
                                "r14": return Rect2(1884, 2528, 872, 580)   # комната наблюдения
                                "r15": return Rect2(990, 3130, 872, 580)    # грузовой шлюз
                return Rect2()

# зона утечки газа (южная полоса генераторной + тоннель мастерской)
func zp_gas_rect() -> Rect2:
                return Rect2(120, 2380, 820, 110).merge(Rect2(1010, 2380, 830, 110))

# ---------- инициализация сценария ----------
func _zpro_init() -> void:
                zp = {
                                "stage": "awake",
                                "seen": {},                    # посещённые комнаты
                                "pat06_done": false, "female_ward": false, "prints_done": false,
                                "water_closed": false, "gloves": false, "med_power": false,
                                "med_pass": false, "med_term_done": false,
                                "exp12_done": false,
                                "serov_state": 0,              # 0 не встречен, 1 диалог был, 2 решён
                                "fuse_found": false, "gen_fuse": false, "gen_loop": false,
                                "gen_cool": false, "gen_on": false,
                                "gas_fixed": false,
                                "armory_code": false, "armory_open": false,
                                "air_key_found": false, "iso_off": false, "iso_active": false,
                                "lockdown_started": false, "lockdown_missed": false,
                                "morozova_done": false,
                                "escape_on": false, "wipe_done": false,
                                "hydro_powered": false, "hydro_released": false,
                                "hypo": 1.0,                   # переохлаждение (снижается от снаряжения)
                                "kill_qr": 0,
                }
                # сложность пролога: стартовые ресурсы по ТЗ п.18
                var ak: float = G.zdiff_param("ammo_k")
                var mk: float = G.zdiff_param("med_k")
                G.zsave["ammo"]["pistol"] = int(2 * ak)             # два патрона (по ТЗ)
                G.zsave["ammo"]["knife"] = 9999
                G.zsave["inv"]["band"] = int(2 * mk)
                G.zsave["inv"]["tq"] = int(1 * mk)
                G.zsave["inv"]["morph"] = int(1 * mk)
                # аудио-атмосфера бункера
                zp_amb = ZAmbience.new()
                add_child(zp_amb)
                zp_amb.set_mode("bunker")
                # иней на экране (появляется в холодных зонах) — отдельный слой:
                # ui_layer строится позже (в _build_hud), здесь его ещё нет
                zp_frost = ZTerminal.frost_overlay(0.0)
                zp_frost.visible = false   # FIX10: шейдер не работает, пока инея нет
                var fl := CanvasLayer.new()
                fl.layer = 15
                add_child(fl)
                fl.add_child(zp_frost)
                # задачи миссии: базовые (по ТЗ №1) + цепочка техсектор→карантин→шлюз
                # FIX10: цепочка задач порциями — следующая строка появляется,
                # только когда выполнена предыдущая (в связанных местах — по 2)
                _add_objective("capsule", "Выбить стекло капсулы и выбраться", 0)
                _add_objective("gear", "Снаряжение со стола: КПК, ПМ, фонарь, термокофта", 1)
                _add_objective("heal", "Перевязать рану: окно РЮКЗАК → бинт/жгут", 1)
                _add_objective("corridor", "Пройти медицинский сектор (карантинный коридор)", 2)
                _add_objective("guard", "Обыскать тело охранника у шлюза (ключ-карта, нож)", 3)
                _add_objective("scanner", "Приложить ключ-карту к сканеру у шлюза", 4)
                _add_objective("gen18", "Техсектор: восстановить генератор (мощность 18%)", 5)
                _add_objective("gas", "Перекрыть утечку охлаждающего газа", 5)
                _add_objective("armory", "Оружейная: ПММ и боезапас (нужен код или отмычка)", 6)
                _add_objective("iso", "Карантин: пережить блокировку и отключить изоляцию", 7)
                _add_objective("frost", "Комната наблюдения: архив доктора Морозовой", 8)
                _add_objective("hydro", "Грузовой шлюз: гидравлика и ворота (осторожно: V-18)", 9)
                _add_objective("evac", "Выйти на внешнюю площадку", 10)
                # --- код-спавн: квестовые объекты, которых нет в tscn ---
                _spawn_corpse("sci", Vector2(500, 1620))                       # труп исследователя с пропуском (п.3)
                corpses[corpses.size() - 1]["bonus"] = ["propusk", "doctor_note"]
                _spawn_corpse("sci", Vector2(700, 2420))                       # тело техника в тоннеле (п.8)
                corpses[corpses.size() - 1]["bonus"] = ["tool_key"]
                for c in corpses:
                                var cp: Vector2 = c["pos"]
                                if str(c.get("kind", "")) == "guard":
                                                if cp.y > 2500.0:
                                                                c["bonus"] = ["air_key"]                 # аварийный ключ карантина (п.11)
                                                elif cp.y < 2000.0:
                                                                c["bonus"] = ["knife"]                   # складной нож охранника (п.3)
                for pr in props:
                                var pp2: Vector2 = pr["pos"]
                                if str(pr.get("kind", "")) == "loot_crate":
                                                if pp2.x > 2500.0 and pp2.y < 2000.0:
                                                                pr["bonus"] = ["lockpick", "medkit"]     # прачечная-ветка: отмычка
                                                elif pp2.x > 800.0 and pp2.y > 1900.0 and pp2.y < 2500.0:
                                                                pr["bonus"] = ["fuse"]                   # предохранитель генератора
                _prop("z_scanner", Vector2(1792, 330), 26.0, "cams_terminal")   # мониторы камер (п.5)
                _prop("z_vent", Vector2(200, 2420), 24.0, "gas_valve")          # клапан утечки за решёткой
                _prop("z_i_tq", Vector2(165, 2062), 16.0, "gloves_pick", 0.9)   # изоляционные перчатки
                _prop("z_vent", Vector2(148, 1978), 20.0, "water_valve", 0.9)   # перекрыть воду щитовой
                _prop("z_scanner", Vector2(238, 1988), 22.0, "breaker")         # рубильник щитовой
                _prop("z_crate_z", Vector2(880, 1450), 14.0, "distraction", 0.8, false)   # металл для броска
                _prop("z_crate_z", Vector2(1120, 2900), 14.0, "distraction", 0.8, false)
                _prop("z_shelf", Vector2(1660, 2020), 18.0, "journal")          # журнал смены (п.9)
                _prop("z_scanner", Vector2(1150, 1420), 20.0, "recorder")       # диктофон врача (запись № 01)
                _prop("z_sign", Vector2(1426, 3330), 14.0, "light_switch", 0.7, false)  # аварийное освещение
                _prop("z_stairs", Vector2(1426, 3640), 30.0, "exit_gate")       # выход на площадку
                _prop("z_scanner", Vector2(162, 1545), 24.0, "cryo_terminal")   # терминал капсулы: ПАЦИЕНТ V-17 (п.3)
                _prop("z_sign", Vector2(640, 1660), 12.0, "tag", 0.8, false)    # военный жетон: «НЕ ВЕРЬ ГОЛОСУ» (п.3)
                _prop("z_vent", Vector2(150, 1440), 18.0, "vent_whisper", 0.9)  # решётка: «Волков... не открывай...» (п.3)
                _prop("z_scanner", Vector2(1420, 1402), 24.0, "med_terminal")   # медтерминал сектора (п.5)

# ---------- v2.8: цель активной задачи для компаса ----------
func _zpro_obj_pos() -> Vector2:
                for o in objectives:
                        if bool(o["done"]):
                                continue
                        var p := _zpro_anchor_pos(str(o["id"]))
                        if p != Vector2.INF:
                                return p
                return Vector2.INF

func _zpro_anchor_pos(oid: String) -> Vector2:
                var want := ""
                match oid:
                        "capsule":
                                want = "capsule"
                        "gear":
                                want = "gear_table"
                        "corridor":
                                want = "med_terminal"
                        "guard":
                                want = "__corpse_guard"
                        "scanner":
                                want = "scanner"
                        "gen18":
                                want = "generator"
                        "gas":
                                want = "gas_valve"
                        "armory":
                                want = "weapon_locker"
                        "iso":
                                want = "iso_panel"
                        "frost":
                                want = "obs_terminal"
                        "hydro":
                                want = "hydro"
                        "evac":
                                want = "exit_gate"
                        _:
                                return Vector2.INF
                for pr in props:
                        if str(pr.get("kind", "")) == want and pr.get("spr", null) != null and is_instance_valid(pr["spr"]):
                                return pr["pos"]
                if want == "__corpse_guard":
                        for c in corpses:
                                if str(c.get("kind", "")) == "guard" and not bool(c.get("searched", false)):
                                        return c["pos"]
                return Vector2.INF

# ---------- тик сценария ----------
func _zpro_tick(delta: float) -> void:
                if not is_bunker or (zp as Dictionary).is_empty():
                                return
                if player == null or player.get("spr") == null or not is_instance_valid(player["spr"]):
                                return
                var pp: Vector2 = player["spr"].position
                if in_capsule:
                                return
                # --- определение комнаты ---
                var room := zp_room_at(pp)
                if room != zp_room_cur:
                                zp_room_cur = room
                                _zpro_on_room(room)
                # --- отсчёт изоляции ---
                if bool(zp.get("iso_active", false)) and not bool(zp.get("iso_off", false)):
                                zp_countdown -= delta / maxf(0.4, G.zdiff_param("countdown_k"))
                                zp_beep_acc += delta
                                if zp_countdown <= 12.0 and zp_beep_acc >= 1.0:
                                                zp_beep_acc = 0.0
                                                G.play_sfx("z_beep_alarm", -14.0, 1.0 + (12.0 - maxf(0.0, zp_countdown)) * 0.02)
                                if zp_countdown <= 0.0:
                                                _zpro_lockdown_missed()
                # --- утечка газа ---
                if not bool(zp.get("gas_fixed", false)) and zp_gas_rect().has_point(pp):
                                zp_cough_acc -= delta
                                if zp_cough_acc <= 0.0:
                                                zp_cough_acc = randf_range(2.2, 4.0)
                                                G.play_sfx("z_cough", -10.0, randf_range(0.9, 1.1))
                                                _zpro_hypo_hit(0.14)
                                if zp_frost != null and zp_frost.material != null:
                                                zp_frost.material.set_shader_parameter("strength", 0.55)
                                                zp_frost.visible = true
                else:
                                # иней в тонелях с повреждённым охлаждением (вентиляция карантина)
                                var cold := Rect2(1330, 2540, 260, 120).has_point(pp) and not bool(zp.get("gas_fixed", false))
                                if zp_frost != null:
                                                var tgt := 0.55 if zp_gas_rect().has_point(pp) else (0.4 if cold else 0.0)
                                                var cur: float = zp_frost.material.get_shader_parameter("strength")
                                                var ns := lerpf(cur, tgt, delta * 2.0)
                                                zp_frost.material.set_shader_parameter("strength", ns)
                                                zp_frost.visible = ns > 0.02   # FIX10: скрыт — полный экран не считается
                                if cold:
                                                zp_cough_acc -= delta
                                                if zp_cough_acc <= 0.0:
                                                                zp_cough_acc = 3.0
                                                                G.play_sfx("z_ice_crack", -16.0)
                                                                _zpro_hypo_hit(0.1)
                # --- переохлаждение: медленнее восстанавливается выносливость (по ТЗ) ---
                if float(zp.get("hypo", 1.0)) > 0.0:
                                zp["hypo"] = maxf(0.0, float(zp["hypo"]) - delta * 0.01)   # согревается со временем
                # --- переохлаждение: термокофта со стола снаряжения согревает (по ТЗ п.3) ---
                if float(zp.get("hypo", 0.0)) > 0.0 and _obj_done("gear"):
                                zp["hypo"] = 0.0
                                _toast("Термокофта и брюки персонала. Холод отступает.")
                # --- дымовые завесы ---
                for i in range(zp_smoke_zones.size() - 1, -1, -1):
                                zp_smoke_zones[i]["t"] -= delta
                                if float(zp_smoke_zones[i]["t"]) <= 0.0:
                                                zp_smoke_zones.remove_at(i)
                # --- сталкер (заражённый охранник) ---
                _zpro_stalker_tick(delta)
                # --- финал: перегрев гидравлики при осмотре V-18 ---
                if zp_v18_timer > 0.0:
                                zp_v18_timer -= delta
                                if zp_v18_timer <= 0.0 and zp_gate_state >= 3:
                                                _zpro_gate_overheat()
                # --- медленный процесс открытия ворот ---
                if zp_gate_state == 3:
                                zp_gate_t += delta
                                if zp_gate_t >= 6.0:
                                                zp_gate_state = 4
                                                zp_gate_t = 0.0
                                                _zpro_gate_open()
                # --- голос из динамика у шлюза ---
                if zp_gate_state >= 1 and not zp_speaker_done:
                                var spk := zp_room_rect("r15").position + Vector2(436, 110)
                                if pp.distance_to(spk) < 150.0:
                                                zp_speaker_done = true
                                                _zpro_speaker_scene()

func _zpro_hypo_hit(k: float) -> void:
                # холод бьёт по организму: стресс и лёгкий урон в конечности
                var st: Dictionary = player["st"]
                st["stress"] = minf(100.0, float(st.get("stress", 0.0)) + k * 18.0 * float(G.zdiff_param("hypothermia_k")))
                var body: Dictionary = st["body"]
                body["ll"] = maxf(0.3, float(body.get("ll", 1.0)) - k * 0.05 * float(G.zdiff_param("hypothermia_k")))

func _zpro_room_seen(id: String) -> bool:
                return bool(zp.get("seen", {}).get(id, false))

func _zpro_see(id: String) -> void:
                zp["seen"][id] = true

func zp_room_at(p: Vector2) -> String:
                for id in ["r6", "r7", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]:
                                if zp_room_rect(id).has_point(p):
                                                return id
                return zp_room_cur

# ---------- события входа в комнаты ----------
func _zpro_on_room(id: String) -> void:
                if id == "" or _zpro_room_seen(id):
                                return
                _zpro_see(id)
                match id:
                                "r6":
                                                zp_amb.set_mode("bunker")
                                "r7":
                                                # медицинский сектор: детский смех за громкоговорителем, женский голос
                                                zp_amb.set_mode("bunker")
                                                _zpro_female_ward()
                                "r8":
                                                G.play_sfx("z_hiss", -16.0)
                                "r9":
                                                # технический сектор: гул громче
                                                zp_amb.set_mode("bunker")
                                                if not bool(zp.get("gen_on", false)):
                                                                _zpro_ai_line("Обнаружен низкий заряд резервного генератора: 18%. Рекомендуется восстановить питание контура.", ZCutscene.C_AI_WARN, "gen18_note")
                                "r10":
                                                if int(zp.get("serov_state", 0)) == 0:
                                                                _zpro_serov_scene()
                                "r11":
                                                # палата, которой нет на плане
                                                if G.zdiff_hints():
                                                                _toast("Палаты № 12 нет на плане объекта...")
                                                G.play_sfx("z_whisper1", -14.0)
                                "r12":
                                                G.play_sfx("z_seal_lock", -16.0)
                                "r13":
                                                # КАРАНТИННЫЙ БЛОК: блокировка по сценарию п.11
                                                if not bool(zp.get("lockdown_started", false)):
                                                                _zpro_lockdown_start()
                                "r14":
                                                zp_amb.set_mode("alarm_far")
                                                if not bool(zp.get("morozova_done", false)):
                                                                _toast("Комната наблюдения. Терминал архива мигает...")
                                "r15":
                                                # грузовой шлюз: метель за створами
                                                zp_amb.set_mode("gas" if not bool(zp.get("gas_fixed", false)) else "bunker")
                                                G.play_sfx("z_blast_close", -14.0)

# ---------- интерактив пролога ----------
const ZPRO_KINDS := ["cryo_terminal", "tag", "vent_whisper", "med_terminal", "water_valve",
                "breaker", "gloves_pick", "exp12_video", "exp12_capsule", "tape_deck",
                "gen_panel", "generator", "coolant", "fuse_crate", "serov", "serov_table",
                "weapon_locker", "iso_panel", "sas_gate", "vent_bypass", "obs_terminal",
                "hydro", "hydro_lever", "power_hold", "speaker", "v18_body", "exit_gate",
                "light_switch", "cams_terminal", "distraction", "journal",
                "recorder", "gas_valve"]

func _zpro_find_interact(pp: Vector2) -> Dictionary:
                # тело V-18 (появляется в финале)
                if zp_v18_spawned and not bool(G.zflag("found_v18_body")):
                                for c in corpses:
                                                if str(c.get("kind", "")) == "v18" and pp.distance_to(c["pos"]) < 110.0:
                                                                return {"kind": "v18_body", "text": "ОСМОТРЕТЬ ТЕЛО (V-18)", "hold": 2.2, "pos": c["pos"]}
                # разбор завалов не нужен — остальные интерактивы через пропы
                for pr in props:
                                var k: String = str(pr.get("kind", ""))
                                if not ZPRO_KINDS.has(k):
                                                continue
                                var pos: Vector2 = pr["pos"]
                                var d := pp.distance_to(pos)
                                if d > 96.0:
                                                continue
                                match k:
                                                "cryo_terminal":
                                                                return {"kind": k, "text": "ТЕРМИНАЛ КАПСУЛЫ", "hold": 0.5, "pos": pos}
                                                "tag":
                                                                return {"kind": k, "text": "ВОЕННЫЙ ЖЕТОН", "hold": 0.5, "pos": pos}
                                                "vent_whisper":
                                                                return {"kind": k, "text": "ВЕНТИЛЯЦИОННАЯ РЕШЁТКА", "hold": 0.5, "pos": pos}
                                                "med_terminal":
                                                                return {"kind": k, "text": "МЕДИЦИНСКИЙ ТЕРМИНАЛ", "hold": 0.5, "pos": pos}
                                                "water_valve":
                                                                if not bool(zp.get("water_closed", false)):
                                                                                return {"kind": k, "text": "ПЕРЕКРЫТЬ ВОДУ (держать)", "hold": 1.4, "pos": pos}
                                                "breaker":
                                                                if bool(zp.get("water_closed", false)) and not bool(zp.get("med_power", false)):
                                                                                return {"kind": k, "text": "ПОДНЯТЬ АВАРИЙНЫЙ ВЫКЛЮЧАТЕЛЬ (держать)", "hold": 1.6, "pos": pos}
                                                                elif not bool(zp.get("water_closed", false)):
                                                                                return {"kind": k, "text": "РУБИЛЬНИК В ВОДЕ — ОПАСНО", "hold": 0.4, "pos": pos, "danger": true}
                                                "gloves_pick":
                                                                if not bool(zp.get("gloves", false)):
                                                                                return {"kind": k, "text": "ВЗЯТЬ ИЗОЛЯЦИОННЫЕ ПЕРЧАТКИ", "hold": 0.5, "pos": pos}
                                                "exp12_video":
                                                                if not bool(zp.get("exp12_done", false)):
                                                                                return {"kind": k, "text": "ТЕРМИНАЛ: «ЭКСПЕРИМЕНТ № 12»", "hold": 0.5, "pos": pos}
                                                "exp12_capsule":
                                                                return {"kind": k, "text": "КАПСУЛА «ЭКСПЕРИМЕНТ № 12»", "hold": 0.5, "pos": pos}
                                                "tape_deck":
                                                                return {"kind": k, "text": "КАССЕТНАЯ ДЕКА ТЕХСЕКТОРА", "hold": 0.6, "pos": pos}
                                                "gen_panel":
                                                                return {"kind": k, "text": "РАСПРЕДЕЛИТЕЛЬНЫЙ ШКАФ", "hold": 0.7, "pos": pos}
                                                "generator":
                                                                if bool(zp.get("gen_fuse", false)) and bool(zp.get("gen_loop", false)) and bool(zp.get("gen_cool", false)) and not bool(zp.get("gen_on", false)):
                                                                                return {"kind": k, "text": "ПЕРЕЗАПУСТИТЬ ГЕНЕРАТОР (держать)", "hold": 2.4, "pos": pos}
                                                                return {"kind": k, "text": "ГЕНЕРАТОР: 18% МОЩНОСТИ", "hold": 0.4, "pos": pos}
                                                "coolant":
                                                                if bool(zp.get("gen_fuse", false)) and not bool(zp.get("gen_cool", false)):
                                                                                return {"kind": k, "text": "ЗАПУСТИТЬ ОХЛАЖДЕНИЕ (держать)", "hold": 1.2, "pos": pos}
                                                "fuse_crate":
                                                                if not bool(zp.get("fuse_found", false)):
                                                                                return {"kind": k, "text": "ОБЫСКАТЬ ЯЩИК (предохранитель)", "hold": 0.8, "pos": pos}
                                                "serov":
                                                                if int(zp.get("serov_state", 0)) == 1:
                                                                                return {"kind": k, "text": "ГОВОРИТЬ С СЕРОВЫМ", "hold": 0.4, "pos": pos}
                                                "serov_table":
                                                                if not bool(zp.get("serov_looted", false)):
                                                                                return {"kind": k, "text": "МЕДИКАМЕНТЫ СЕРОВА", "hold": 0.6, "pos": pos}
                                                "weapon_locker":
                                                                if not bool(zp.get("armory_open", false)):
                                                                                return {"kind": k, "text": "ОРУЖЕЙНЫЙ ШКАФ (код)", "hold": 0.5, "pos": pos}
                                                "iso_panel":
                                                                if bool(zp.get("iso_active", false)) and not bool(zp.get("iso_off", false)):
                                                                                if int(G.zsave["inv"].get("air_key", 0)) > 0:
                                                                                                return {"kind": k, "text": "АВАРИЙНЫЙ КЛЮЧ: ОТКЛЮЧИТЬ ИЗОЛЯЦИЮ (держать)", "hold": 2.0, "pos": pos}
                                                                                return {"kind": k, "text": "ПАНЕЛЬ ИЗОЛЯЦИИ: НУЖЕН АВАРИЙНЫЙ КЛЮЧ", "hold": 0.4, "pos": pos}
                                                "sas_gate":
                                                                if bool(zp.get("iso_off", false)) or bool(zp.get("lockdown_missed", false)):
                                                                                return {"kind": k, "text": "АВАРИЙНЫЙ ШЛЮЗ — ОТКРЫТЬ", "hold": 0.8, "pos": pos}
                                                                return {"kind": k, "text": "ШЛЮЗ ЗАБЛОКИРОВАН", "hold": 0.4, "pos": pos}
                                                "vent_bypass":
                                                                return {"kind": k, "text": "ВЕНТИЛЯЦИОННЫЙ КАНАЛ (камеры 4–5)", "hold": 1.0, "pos": pos}
                                                "obs_terminal":
                                                                if not bool(zp.get("morozova_done", false)):
                                                                                return {"kind": k, "text": "АРХИВ НАБЛЮДЕНИЯ: ВОСПРОИЗВЕСТИ", "hold": 0.6, "pos": pos}
                                                "hydro":
                                                                if zp_gate_state == 0:
                                                                                return {"kind": k, "text": "ЗАПУСТИТЬ ГИДРАВЛИЧЕСКИЙ МЕХАНИЗМ (держать)", "hold": 2.0, "pos": pos}
                                                "hydro_lever":
                                                                if zp_gate_state == 1:
                                                                                return {"kind": k, "text": "РАЗБЛОКИРОВАТЬ АВАРИЙНЫЙ ПРИВОД (держать)", "hold": 1.8, "pos": pos}
                                                "power_hold":
                                                                if zp_gate_state == 2:
                                                                                return {"kind": k, "text": "УДЕРЖИВАТЬ ПИТАНИЕ", "hold": 3.0, "pos": pos}
                                                "light_switch":
                                                                return {"kind": k, "text": "АВАРИЙНОЕ ОСВЕЩЕНИЕ: ВКЛ/ВЫКЛ", "hold": 0.5, "pos": pos}
                                                "cams_terminal":
                                                                if not zp_cam_note:
                                                                                return {"kind": k, "text": "МОНИТОР КАМЕР МЕДСЕКТОРА", "hold": 0.6, "pos": pos}
                                                "distraction":
                                                                return {"kind": k, "text": "МЕТНУТЬ ДЕТАЛЬ В СТОРОНУ", "hold": 0.4, "pos": pos, "pos_ref": pr}
                                                "recorder":
                                                                return {"kind": k, "text": "ДИКТОФОН ВРАЧА (запись № 01)", "hold": 0.6, "pos": pos}
                                                "gas_valve":
                                                                if not bool(zp.get("gas_fixed", false)):
                                                                                return {"kind": k, "text": "КЛАПАН УТЕЧКИ (держать)", "hold": 1.8, "pos": pos}
                                                "exit_gate":
                                                                if zp_gate_state == 4:
                                                                                return {"kind": k, "text": "ВЫЙТИ НА ВНЕШНЮЮ ПЛОЩАДКУ", "hold": 1.2, "pos": pos}
                                                "journal":
                                                                return {"kind": k, "text": "ЖУРНАЛ СМЕНЫ", "hold": 0.6, "pos": pos}
                return {}

func _zpro_do_interact(kind: String, info: Dictionary) -> void:
                match kind:
                                "cryo_terminal": _zp_win_cryo_terminal()
                                "tag": _zp_win_tag()
                                "vent_whisper": _zp_win_vent()
                                "med_terminal": _zp_win_med_terminal()
                                "water_valve":
                                                zp["water_closed"] = true
                                                G.play_sfx("z_pressure_hiss", -10.0)
                                                _toast("Вода перекрыта. Теперь можно поднять рубильник.")
                                                if G.zdiff_hints(): _toast("Щитовая: поднять аварийный выключатель.")
                                "breaker": _zpro_breaker()
                                "gloves_pick":
                                                zp["gloves"] = true
                                                G.z_give_item("gloves", 1)
                                                G.play_sfx("z_pickup", -8.0)
                                                _toast("Изоляционные перчатки получены.")
                                "exp12_video": _zp_win_exp12()
                                "exp12_capsule":
                                                G.play_sfx("z_hiss", -14.0)
                                                _zp_win_note("КАПСУЛА «ЭКСПЕРИМЕНТ № 12»", "Внутри — анестезия и следы недавнего восстановления. Браслет пациента такой же, как на вашей руке.", ZUI.WARN)
                                "tape_deck": _zp_win_tape()
                                "gen_panel": _zp_win_gen_panel()
                                "generator": _zpro_generator()
                                "coolant":
                                                zp["gen_cool"] = true
                                                G.play_sfx("z_pressure_hiss", -8.0, 0.9)
                                                _toast("Охлаждение запущено. Генератор готов к перезапуску.")
                                "fuse_crate":
                                                zp["fuse_found"] = true
                                                G.z_give_item("fuse", 1)
                                                G.play_sfx("z_pickup", -8.0)
                                                _toast("Промышленный предохранитель найден.")
                                "serov": _zpro_serov_talk()
                                "serov_table":
                                                zp["serov_looted"] = true
                                                G.z_give_item("band", 1)
                                                G.z_give_item("morph", 1)
                                                G.play_sfx("z_pickup", -8.0)
                                                _toast("Бинт и морфин взяты со стола.")
                                "weapon_locker": _zp_win_armory()
                                "iso_panel": _zpro_iso_off()
                                "sas_gate":
                                                if bool(zp.get("iso_off", false)) or bool(zp.get("lockdown_missed", false)):
                                                                _open_door("sas_n")
                                                                _complete_objective("iso")
                                                                G.play_sfx("z_seal_lock", -8.0)
                                                                _toast("Аварийный шлюз открыт. Дальше — грузовой отсек.")
                                "vent_bypass": _zpro_vent_bypass()
                                "obs_terminal": _zpro_morozova()
                                "hydro":
                                                zp_gate_state = 1
                                                G.play_sfx("z_hydro_loop", -10.0)
                                                _toast("Гидравлический механизм запущен. Теперь — аварийный привод.")
                                "hydro_lever":
                                                zp_gate_state = 2
                                                G.play_sfx("z_relay", -8.0)
                                                _toast("Привод разблокирован. Удерживайте питание у щитка.")
                                "power_hold":
                                                zp_gate_state = 3
                                                zp_gate_t = 0.0
                                                G.play_sfx("z_hydro_loop", -8.0)
                                                _toast("Питание удержано. Ворота открываются...")
                                "speaker": _zpro_speaker_scene()
                                "v18_body": _zpro_v18_inspect()
                                "light_switch": _zpro_light_switch()
                                "cams_terminal": _zp_win_cams()
                                "distraction":
                                                G.play_sfx("z_metal", -10.0, 1.2)
                                                var target: Vector2 = info.get("pos", player["spr"].position) + Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 260.0
                                                _log("Деталь ударилась о металл. Шум привлёк внимание в сторону.", Color(0.7, 0.75, 0.7), "СИСТЕМА")
                                                # враги идут НА ШУМ, а не на игрока (отвлечение по ТЗ)
                                                for z in zombies:
                                                                if z["alive"] and z["spr"].position.distance_to(target) < 420.0:
                                                                                z["state"] = "wander"
                                                                                z["wander_dir"] = (target - z["spr"].position).normalized()
                                                                                z["wander_t"] = 4.0
                                                                                z["alert"] = false
                                "recorder": _zp_win_recorder()
                                "gas_valve": _zpro_gas_valve()
                                "exit_gate":
                                                stairs_fade = 0.001
                                                G.play_sfx("z_door", -6.0)
                                                G.play_sfx("z_footstep", -8.0)
                                "journal": _zp_win_journal()
                # однократное закрытие задач
                match kind:
                                "cryo_terminal": _complete_objective("terminal")
                                "exp12_video":
                                                _complete_objective("ward12")
                                "gen_panel", "generator":
                                                if bool(zp.get("gen_on", false)):
                                                                _complete_objective("gen18")
                                "obs_terminal":
                                                if bool(zp.get("morozova_done", false)):
                                                                _complete_objective("frost")

# ---------- ЗКРАНЫ-ТЕРМИНАЛЫ (ZTerminal) ----------
func zp_terminal_screen(title: String, accent: Color, lines: Array, on_done: Callable = Callable(), status := "") -> void:
                paused = true
                var layer := CanvasLayer.new()
                layer.layer = 41
                add_child(layer)
                var dim := ColorRect.new()
                dim.set_anchors_preset(Control.PRESET_FULL_RECT)
                dim.color = Color(0, 0, 0, 0.72)
                layer.add_child(dim)
                var t := ZTerminal.new(title, accent)
                t.set_anchors_preset(Control.PRESET_FULL_RECT)
                layer.add_child(t)
                zp_overlay_layer = layer
                if status != "":
                                t.set_status(status)
                t.print_lines(lines, func():
                                await get_tree().create_timer(1.1).timeout
                                if is_instance_valid(t):
                                                t.close_terminal()
                                await get_tree().create_timer(0.4).timeout
                                if is_instance_valid(layer):
                                                layer.queue_free()
                                if battle_over == "":
                                                paused = false
                                if on_done.is_valid():
                                                on_done.call())

# принудительно закрыть оверлей (смоук-тесты)
func zp_force_close() -> void:
        if zp_overlay_layer != null and is_instance_valid(zp_overlay_layer):
                for c in zp_overlay_layer.get_children():
                        if c is ZDialog:
                                (c as ZDialog)._finish()
                        elif c is ZTerminal:
                                (c as ZTerminal).close_terminal()
                zp_overlay_layer.queue_free()
                zp_overlay_layer = null
        paused = false

# кат-сцена поверх боя (ZCutscene)
func zp_scene(cues: Array, on_done: Callable = Callable(), skippable := true) -> void:
                paused = true
                var layer := CanvasLayer.new()
                layer.layer = 42
                add_child(layer)
                var cs := ZCutscene.new()
                cs.skippable = skippable
                cs.fast = zp_fast
                zp_overlay_layer = layer
                cs.set_anchors_preset(Control.PRESET_FULL_RECT)
                layer.add_child(cs)
                cs.finished.connect(func(_sk: bool):
                                if is_instance_valid(layer):
                                                layer.queue_free()
                                if battle_over == "":
                                                paused = false
                                if on_done.is_valid():
                                                on_done.call())
                cs.play(cues)

# диалог (ZDialog) поверх боя
func zp_dialog(stages: Array, on_done: Callable = Callable()) -> void:
                paused = true
                var layer := CanvasLayer.new()
                layer.layer = 41
                add_child(layer)
                var dim := ColorRect.new()
                dim.set_anchors_preset(Control.PRESET_FULL_RECT)
                dim.color = Color(0, 0, 0, 0.6)
                layer.add_child(dim)
                var dlg := ZDialog.new()
                dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
                layer.add_child(dlg)
                zp_overlay_layer = layer
                dlg.set_stages(stages)
                dlg.on_finished = func():
                                layer.queue_free()
                                paused = false
                                if on_done.is_valid():
                                                on_done.call()
                dlg.start(0)

# короткая реплика ИИ (лог + голосом SFX)
func _zpro_ai_line(text: String, col: Color, once_key := "") -> void:
                if once_key != "":
                                if zp_ai_msg.has(once_key):
                                                return
                                zp_ai_msg[once_key] = true
                _log("«%s»" % text, col, "ИИ «ЗАРЯ»")
                G.play_sfx("z_radio_beep", -16.0)
                G.play_sfx("z_static", -20.0)

# закрыть открытую дверь (изоляция карантина)
func _close_door(id: String) -> void:
                var door: Dictionary = doors.get(id, {})
                if door.is_empty() or not bool(door["opened"]):
                                return
                door["opened"] = false
                walls.append(door["wall"])
                var spr: Sprite2D = door["pr"]["spr"]
                spr.visible = true
                spr.modulate.a = 0.0
                var tw := spr.create_tween()
                tw.set_parallel(true)
                tw.tween_property(spr, "modulate:a", 1.0, 0.4)
                tw.tween_property(spr, "position", door["pr"]["pos"], 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                G.play_sfx("z_blast_close", -6.0)
                floor_node.redraw_all()

# ============================================================
# ПРОЛОГ «ЗАРЯ» — СЮЖЕТНЫЕ СЦЕНЫ (реплики, кат-сцены, выборы)
# Все тексты — из документа сценария (п.3–14). Озвучка — карта
# G.VOICE_MAP (ai_*.wav / radio_*.wav; отсутствующие пропускаются).
# ============================================================

# ---------- ЛОКАЦИЯ 1: КАМЕРА ПРОБУЖДЕНИЯ ----------
func _zp_win_cryo_terminal() -> void:
                # По сценарию п.3: строки терминала, последняя — с задержкой,
                # после чего терминал выключается.
                var lines := [
                                {"text": "ПАЦИЕНТ: V-17", "col": ZTerminal.CRT_GREEN, "delay": 0.5, "sfx": "z_relay"},
                                {"text": "ВОССТАНОВЛЕНИЕ ЗАВЕРШЕНО", "col": ZTerminal.CRT_GREEN, "delay": 0.7},
                                {"text": "ПАМЯТЬ: НЕСТАБИЛЬНА", "col": ZTerminal.CRT_AMBER, "delay": 0.9, "glitch": true},
                                {"text": "ПОВТОРНАЯ СМЕРТЬ: НЕ ДОПУСТИТЬ", "col": ZTerminal.CRT_RED, "delay": 1.6, "blink": true, "sfx": "z_beep_alarm", "sfx_db": -16.0},
                ]
                zp_terminal_screen("О. «ЗАРЯ» · МЕДИЦИНСКИЙ ТЕРМИНАЛ КАПСУЛЫ", ZTerminal.CRT_GREEN, lines, func():
                                zp_amb.radio_off(0.6)
                                _zpro_ai_line("Пациент V-17. Пожалуйста, вернитесь в капсулу. Вы находитесь в зоне медицинского карантина.", ZCutscene.C_AI, "cryo_warn"))

func _zp_win_tag() -> void:
                # Военный жетон: короткое воспоминание (по сценарию — «НЕ ВЕРЬ ГОЛОСУ»)
                zp_dialog([{
                                "speaker": "ВОЕННЫЙ ЖЕТОН · ОБРАТНАЯ СТОРОНА",
                                "col": ZCutscene.C_VOLKOV,
                                "text": "Нацарапано острым предметом, торопливо:\n\n«НЕ ВЕРЬ ГОЛОСУ»\n\nПочерк кажется знакомым. Вашим.",
                                "sfx": "z_relay", "sfx_db": -14.0,
                                "btn": {"text": "СПРЯТАТЬ ЖЕТОН", "icon": "keycard"},
                                "next": -1,
                }])

func _zp_win_vent() -> void:
                # Вентиляция: неизвестный голос (по сценарию — шёпот из решётки)
                zp_amb.play_voice_seq(G.voice_list("whisper_vent"), 1.0)
                G.play_sfx("z_whisper1", -8.0)
                zp_dialog([{
                                "speaker": "ВЕНТИЛЯЦИОННАЯ РЕШЁТКА · НЕИЗВЕСТНЫЙ ГОЛОС",
                                "col": ZCutscene.C_VOICE,
                                "text": "Из вентиляции доносится шёпот — тихий, как будто сквозь толщу льда:\n\n«Волков... не открывай...»",
                                "sfx": "z_whisper2", "sfx_db": -10.0,
                                "btn": {"text": "ОТСТУПИТЬ ОТ РЕШЁТКИ", "icon": "question"},
                                "next": -1,
                }])

func _zp_win_med_terminal() -> void:
                # Медицинский терминал: нужен пропуск + питание + пароль врача
                if not bool(zp.get("med_power", false)):
                                zp_terminal_screen("МЕДСЕКТОР · ТЕРМИНАЛ", ZTerminal.CRT_AMBER, [
                                                {"text": "ОТСУТСТВУЕТ ПИТАНИЕ ЛОКАЛЬНОЙ СЕТИ", "col": ZTerminal.CRT_RED, "delay": 0.5},
                                                {"text": "Аварийная щитовая: перекрыть воду, поднять рубильник", "col": ZTerminal.CRT_AMBER, "delay": 0.6},
                                ], func(): pass)
                                return
                if int(G.zsave["inv"].get("propusk", 0)) <= 0:
                                zp_terminal_screen("МЕДСЕКТОР · ТЕРМИНАЛ", ZTerminal.CRT_AMBER, [
                                                {"text": "ПРИЛОЖИТЕ ПРОПУСК СОТРУДНИКА", "col": ZTerminal.CRT_RED, "delay": 0.5},
                                                {"text": "Доступ уровня: ЛЕЧАЩИЙ ВРАЧ", "col": ZTerminal.CRT_AMBER, "delay": 0.4},
                                ], func(): pass)
                                return
                if not bool(zp.get("med_pass", false)):
                                zp_terminal_screen("МЕДСЕКТОР · ТЕРМИНАЛ", ZTerminal.CRT_AMBER, [
                                                {"text": "ПРОПУСК ПРИНЯТ: К.с.н. НЕСТЕРОВА И.П.", "col": ZTerminal.CRT_GREEN, "delay": 0.5},
                                                {"text": "ВВЕДИТЕ ПАРОЛЬ ВРАЧА", "col": ZTerminal.CRT_GREEN, "delay": 0.6},
                                                {"text": "Подсказка: личные записи врача (диктофон / листок / дневник)", "col": ZTerminal.CRT_AMBER, "delay": 0.8},
                                ], func():
                                                _zp_win_password())
                                return
                # всё выполнено: задачи медсектора закрыты
                zp["med_term_done"] = true
                _complete_objective("medtask")
                zp_terminal_screen("МЕДСЕКТОР · ТЕРМИНАЛ", ZTerminal.CRT_GREEN, [
                                {"text": "ДОСТУП РАЗРЕШЕН", "col": ZTerminal.CRT_GREEN, "delay": 0.4},
                                {"text": "ЖУРНАЛ ПАЦИЕНТОВ МЕДБЛОКА ОТКРЫТ", "col": ZTerminal.CRT_GREEN, "delay": 0.5},
                                {"text": "ПАЦИЕНТ 06 — АКТИВЕН. НЕ НАХОДИТСЯ В ПАЛАТЕ.", "col": ZTerminal.CRT_RED, "delay": 1.0, "blink": true},
                                {"text": "ПАЦИЕНТ V-17 — СМ. ДЕЛО «ЭКСПЕРИМЕНТ № 12»", "col": ZTerminal.CRT_AMBER, "delay": 0.9},
                ], func():
                                if G.zflag("found_v17_record"):
                                                _zpro_ai_line("Рекомендую остерегаться пациента 06. Его состояние нестабильно.", ZCutscene.C_AI_WARN, "pat06_warn"))

func _zp_win_password() -> void:
                # ввод пароля: игрок уже нашёл записи врача — пароль принимается
                # автоматически, если найден листок или диктофон (med_pass ставится там)
                zp_dialog([{
                                "speaker": "МЕДИЦИНСКИЙ ТЕРМИНАЛ · ВВОД ПАРОЛЯ",
                                "col": ZTerminal.CRT_AMBER,
                                "text": "Пароль врача: четыре символа.\n\n(Пароль записан в личных вещах врача — ищите листок, диктофон или дневник в палатах.)",
                                "btn": {"text": "ВВЕСТИ НАЙДЕННЫЙ ПАРОЛЬ", "icon": "keycard"},
                                "next": -1,
                }])

# ---------- МЕДСЕКТОР: ЖЕНСКИЙ ГОЛОС (п.5) ----------
func _zpro_female_ward() -> void:
                if bool(zp.get("female_ward", false)):
                                return
                zp["female_ward"] = true
                # детская запись + женский голос по громкоговорителю
                zp_amb.play_voice_seq(G.voice_list("female_ward"), 1.0)
                G.play_sfx("z_whisper2", -12.0, 0.85)
                zp_scene([
                                {"wait": 0.6, "sfx": "z_radio_bed", "sfx_db": -16.0},
                                {"speaker": "ГРОМКОГОВОРИТЕЛЬ МЕДСЕКТОРА", "col": ZCutscene.C_VOICE,
                                                "text": "Сначала — детский смех. Запись? Нет... слишком близко.",
                                                "speed": 0.032, "hold": 0.9, "wait": 1.2},
                                {"speaker": "ЖЕНСКИЙ ГОЛОС", "col": ZCutscene.C_VOICE,
                                                "text": "«Алексей, ты обещал вернуться».",
                                                "voice": G.voice_list("female_ward"), "voice_db": 2.0, "hold": 1.2, "wait": 1.0},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Кто это сказал?»", "hold": 0.8, "wait": 0.6},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Аудиосигнал не обнаружен».", "hold": 1.0, "wait": 1.4},
                                {"speaker": "ЗА ДВЕРЬЮ ПАЛАТЫ", "col": ZCutscene.C_VOICE,
                                                "text": "«Алексей... мне холодно».", "sfx": "z_whisper1", "sfx_db": -9.0, "hold": 1.4, "wait": 1.6},
                                {"call": Callable(self, "_zpro_palm_prints"), "wait": 0.8},
                                {"speaker": "СТЕКЛО ПАЛАТЫ", "col": ZCutscene.C_SYSTEM,
                                                "text": "За стеклом никого нет. Но на внутренней стороне — свежие отпечатки ладоней.",
                                                "hold": 1.4, "wait": 1.0},
                ])

func _zpro_palm_prints() -> void:
                # декали отпечатков на стекле палаты
                for gp in [Vector2(1520, 1560), Vector2(1560, 1620)]:
                                var p := _mk_spr("decal_blood1", gp, 0.5, 6, Color(0.62, 0.68, 0.72, 0.5))
                                p.rotation = randf() * TAU

# ---------- ПАЦИЕНТ № 06 (п.6) ----------
func _zpro_pat06_encounter() -> void:
                if bool(zp.get("pat06_done", false)):
                                return
                zp["pat06_done"] = true
                # особый враг: быстрый, «сохраняет речь»
                _spawn_zombie("run", Vector2(1220, 1560))
                var z: Dictionary = zombies[zombies.size() - 1]
                z["kind"] = "pat06"
                z["spd"] = 78.0
                z["hp"] = 86.0 * (1.0 + (diff_mult - 1.0) * 0.5)
                z["notice"] = 300.0 * float(G.zdiff_param("notice_k"))
                z["state"] = "idle"
                zp["pat06"] = z
                G.play_sfx("z_growl2", -10.0, 0.8)
                zp_scene([
                                {"wait": 0.5, "red": true},
                                {"speaker": "КОРИДОР МЕДСЕКТОРА", "col": ZCutscene.C_VOICE,
                                                "text": "Человек в разорванной больничной одежде стоит спиной. Он шепчет:",
                                                "hold": 0.9, "wait": 1.0},
                                {"speaker": "ПАЦИЕНТ № 06", "col": ZCutscene.C_VOICE,
                                                "text": "«Мама? Ты пришла?»", "sfx": "z_whisper2", "sfx_db": -12.0, "hold": 1.4, "wait": 1.4},
                                {"speaker": "СЦЕНА", "col": ZCutscene.C_SYSTEM,
                                                "text": "Он медленно поворачивается к вам. Зрачки не отражают свет.",
                                                "shake": 0.5, "shake_k": 6.0, "hold": 1.1, "wait": 0.8},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Стой. Не подходи».", "hold": 0.9, "wait": 1.0},
                                {"speaker": "ПАЦИЕНТ № 06", "col": ZCutscene.C_ALERT,
                                                "text": "«МАМА!!!»", "sfx": "z_shriek", "sfx_db": -6.0, "shake": 0.7, "shake_k": 14.0, "hold": 0.6, "wait": 0.6},
                                {"call": Callable(self, "_cb_pat06_chase"), "wait": 0.2},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Пациент 06 агрессивен. Рекомендация: избегать прямого контакта. Реагирует на свет, шаги и шум».",
                                                "hold": 1.6, "wait": 0.8},
                ], func(): pass)

# ---------- ЩИТОВАЯ: РУБИЛЬНИК (п.5, задача 2) ----------
func _zpro_breaker() -> void:
                if not bool(zp.get("gloves", false)):
                                # удар током: игрок поднял рубильник без перчаток/до перекрытия воды
                                G.play_sfx("z_shock", -4.0)
                                var st: Dictionary = player["st"]
                                st["body"]["ra"] = maxf(0.25, float(st["body"].get("ra", 1.0)) - 0.22)
                                st["stress"] = minf(100.0, float(st.get("stress", 0.0)) + 22.0)
                                zp_scene([
                                                {"flash": 0.05, "flash_col": Color(0.9, 0.95, 1.0, 0.9), "flash_fade": 0.5, "shake": 0.6, "shake_k": 16.0},
                                                {"speaker": "ЭЛЕКТРОЩИТОВАЯ", "col": ZCutscene.C_SYSTEM,
                                                                "text": "Разряд прошёл сквозь воду, перчатки и вас. Правая рука не слушается.",
                                                                "hold": 1.2, "wait": 0.6},
                                ])
                                _toast("Удар током! Нужны изолирующие перчатки и перекрытая вода.")
                                return
                zp["med_power"] = true
                zp_amb.set_mode("bunker")
                G.play_sfx("z_relay", -6.0)
                G.play_sfx("z_seal_lock", -12.0)
                zp_scene([
                                {"wait": 0.4, "sfx": "z_relay", "sfx_db": -8.0},
                                {"speaker": "АВАРИЙНАЯ ЩИТОВАЯ", "col": ZTerminal.CRT_GREEN,
                                                "text": "Релейный щелчок — и по медсектору ползёт тусклый свет. Лампы моргают, но держатся.",
                                                "hold": 1.2, "wait": 1.0},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Питание локальной сети восстановлено. Медицинский терминал доступен».",
                                                "hold": 1.3, "wait": 0.8},
                ], func():
                                _toast("Питание медсектора восстановлено."))

# ---------- ПАЛАТА № 12 (п.7) ----------
func _zp_win_exp12() -> void:
                zp["exp12_done"] = true
                G.zset_flag("found_v17_record", true)
                zp_amb.play_voice_seq(G.voice_list("ai_intro"), 0.0)
                zp_scene([
                                {"wait": 0.5, "veil": 1.2, "veil_to": 0.45},
                                {"speaker": "ЗАПИСЬ · ДАТА 09.02.2041", "col": ZTerminal.CRT_AMBER,
                                                "text": "На терминале — запись с Волковым в военной форме и женщиной в халате.",
                                                "hold": 1.2, "wait": 0.8},
                                {"speaker": "ВОЛКОВ (ЗАПИСЬ)", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Если это сработает, мы сможем вернуть их».", "hold": 1.2, "wait": 0.8},
                                {"speaker": "ЖЕНЩИНА (ЗАПИСЬ)", "col": ZCutscene.C_VOICE,
                                                "text": "«А если они вернутся не такими?»", "hold": 1.2, "wait": 0.8},
                                {"speaker": "ВОЛКОВ (ЗАПИСЬ)", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Тогда мы будем первыми, кто узнает правду».", "hold": 1.2, "wait": 1.2},
                                {"speaker": "ВОЛКОВ (ЗАПИСЬ, ГЛЯДЯ В КАМЕРУ)", "col": ZCutscene.C_ALERT,
                                                "text": "«Если ты это смотришь, значит, они снова запустили процесс. Не доверяй системе. И особенно... не доверяй мне».",
                                                "speed": 0.036, "hold": 1.8, "wait": 1.0},
                                {"call": Callable(self, "_cb_exp12_loot")},
                ], func():
                                _toast("Запись палаты № 12 просмотрена. Память всё ещё молчит."))

# ---------- КАССЕТА (альтернативная версия событий) ----------
func _zp_win_tape() -> void:
                if int(G.zsave["inv"].get("cassette", 0)) <= 0:
                                zp_dialog([{
                                                "speaker": "КАССЕТНАЯ ДЕКА", "col": ZTerminal.CRT_AMBER,
                                                "text": "Дека исправна, но кассеты у вас нет.\n\n(Кассета — в палате № 12, в нижнем ящике.)",
                                                "btn": {"text": "ОТСТУПИТЬ", "icon": "question"}, "next": -1,
                                }])
                                return
                G.z_take_item("cassette", 1)
                zp_amb.play_voice_seq(G.voice_list("radio_survivor"), 1.0)
                zp_scene([
                                {"wait": 0.5, "sfx": "z_radio_beep", "sfx_db": -12.0},
                                {"speaker": "АУДИОКАССЕТА · СЛУШАЕТСЯ ЗАПИСЬ", "col": ZTerminal.CRT_GREEN,
                                                "text": "«...это не оживление. Понимаете? Мы не возвращаем человека. Мы даём чему-то ТОЛЧОК, и оно носит его тело...»",
                                                "speed": 0.034, "hold": 1.4, "wait": 1.0},
                                {"speaker": "АУДИОКАССЕТА", "col": ZTerminal.CRT_GREEN,
                                                "text": "«...эксперимент № 12 — не первый. Первый был раньше. Субъект всё ещё на объекте...»",
                                                "hold": 1.4, "wait": 1.0},
                                {"speaker": "АУДИОКАССЕТА", "col": ZTerminal.CRT_RED,
                                                "text": "«...если Волков выйдет на поверхность — он не должен узнать, чем стал...»",
                                                "hold": 1.6, "wait": 1.2},
                                {"sfx": "z_data_wipe", "sfx_db": -14.0, "wait": 1.2},
                                {"speaker": "СИСТЕМА", "col": ZCutscene.C_SYSTEM,
                                                "text": "Запись обрывается. Дальше — только шипение.",
                                                "hold": 1.0, "wait": 0.6},
                ])

# ---------- МАСТЕРСКАЯ: СЕРОВ (п.9) ----------
func _zpro_serov_scene() -> void:
                zp["serov_state"] = 1
                G.play_sfx("z_growl3", -14.0, 0.9)
                zp_scene([
                                {"wait": 0.5, "shake": 0.4, "shake_k": 6.0},
                                {"speaker": "МАСТЕРСКАЯ", "col": ZCutscene.C_SEROV,
                                                "text": "В углу, за перевёрнутым верстаком — раненый техник. В руке незаряженный пистолет, дрожит.",
                                                "hold": 1.2, "wait": 0.8},
                                {"speaker": "СЕРОВ", "col": ZCutscene.C_SEROV,
                                                "text": "«Не подходи!»", "sfx": "z_metal", "sfx_db": -12.0, "hold": 1.0, "wait": 0.8},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Успокойся. Я не заражён».", "hold": 1.0, "wait": 0.8},
                                {"speaker": "СЕРОВ", "col": ZCutscene.C_ALERT,
                                                "text": "Он замечает браслет на вашей руке. Пистолет опускается.\n\n«Нет... Нет, только не ты».",
                                                "hold": 1.5, "wait": 0.8},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Мы знакомы?»", "hold": 0.9, "wait": 0.7},
                                {"speaker": "СЕРОВ", "col": ZCutscene.C_SEROV,
                                                "text": "«Ты должен был остаться в капсуле».", "hold": 1.3, "wait": 0.8},
                ], func(): _zpro_serov_choices())

func _zpro_serov_choices() -> void:
                zp_dialog([{
                                "speaker": "СЕРОВ · РАНЕН",
                                "col": ZCutscene.C_SEROV,
                                "text": "Он зажимает бок. Помощь ему, требовать ответы или забрать всё и уйти — решать вам.",
                                "choices": [
                                                {"text": "А:  «Держись. Я помогу» (потратить бинт и морфин)", "icon": "medkit", "accent": true},
                                                {"text": "Б:  «Говори. Немедленно» (потребовать информацию)", "icon": "radio", "accent": false},
                                                {"text": "В:  Обыскать и уйти (оставить его)", "icon": "bag", "accent": false, "danger": true},
                                ],
                                                "on_choice": Callable(self, "_cb_serov_choice"),
                }])

func _cb_serov_choice(i: int) -> int:
                _zpro_serov_resolve(i)
                return -1

func _cb_pat06_chase() -> void:
                if zp.has("pat06") and is_instance_valid(zp["pat06"]["spr"]):
                                zp["pat06"]["state"] = "chase"
                                zp["pat06"]["alert"] = true

func _cb_exp12_loot() -> void:
                G.z_give_item("cassette", 1)
                _toast("В нижнем ящике — аудиокассета. Есть дека в техсекторе.")

func _zpro_serov_resolve(i: int) -> void:
                match i:
                                0:
                                                # Вариант 1 — помочь: бинт + обезболивающее → маршрут и код
                                                if int(G.zsave["inv"].get("band", 0)) >= 1 and int(G.zsave["inv"].get("morph", 0)) >= 1:
                                                                G.z_take_item("band", 1)
                                                                G.z_take_item("morph", 1)
                                                                G.zset_flag("helped_serov", true)
                                                                zp["serov_state"] = 2
                                                                zp["armory_code"] = true
                                                                zp["journal_ready"] = true
                                                                zp_dialog([{
                                                                                "speaker": "СЕРОВ · ПЕРЕВЯЗАН", "col": ZCutscene.C_SEROV,
                                                                                "text": "«Ты всё ещё идиот, Волков... Слушай: к грузовому шлюзу — через карантин, аварийный привод у щитка. Оружейная — код 4-1-2-7. И вот ещё... журнал смены на полке. Прочитай. Про капсулу».",
                                                                                "voice": G.voice_list("serov_wounded"), "voice_db": 1.0,
                                                                                "btn": {"text": "«Держись здесь. И не открывай никому»", "icon": "check"}, "next": -1,
                                                                }], func(): _complete_objective("serov"))
                                                else:
                                                                zp_dialog([{
                                                                                "speaker": "РЮКЗАК", "col": ZUI.WARN,
                                                                                "text": "Нужны бинт И морфин — ничего этого нет в достатке. Серов отворачивается.",
                                                                                "btn": {"text": "УЙТИ", "icon": "door"}, "next": -1,
                                                                }])
                                1:
                                                # Вариант 2 — потребовать информацию: код оружейного шкафа
                                                zp["serov_state"] = 2
                                                zp["armory_code"] = true
                                                zp_dialog([{
                                                                "speaker": "СЕРОВ", "col": ZCutscene.C_SEROV,
                                                                "text": "«О проекте я говорить не буду. Даже так. Но... код оружейного шкафа: 4-1-2-7. Возьми всё. И уходи, пока карантин не закрылся».",
                                                                "voice": G.voice_list("serov_wounded"), "voice_db": 1.0,
                                                                "btn": {"text": "ЗАПОМНИТЬ КОД", "icon": "keycard"}, "next": -1,
                                                }], func(): _complete_objective("serov"))
                                2:
                                                # Вариант 3 — обыскать и уйти
                                                zp["serov_state"] = 3
                                                G.z_give_item("mag_pistol", 2)
                                                G.z_give_item("morph", 1)
                                                G.z_give_item("docs", 1)
                                                zp["armory_code"] = false
                                                zp_dialog([{
                                                                "speaker": "ОБЫСК", "col": ZUI.WARN,
                                                                "text": "Патроны, медикаменты, документы. Серов смотрит в пол и молчит.\n\nЕго судьба теперь зависит только от него самого.",
                                                                "btn": {"text": "УЙТИ БЕЗ ОГЛЯДКИ", "icon": "door"}, "next": -1,
                                                }], func(): _complete_objective("serov"))

func _zpro_serov_talk() -> void:
                if int(zp.get("serov_state", 0)) == 1:
                                _zpro_serov_choices()
                                return
                var txt := "«Иди. Пока они не услышали»."
                if G.zflag("helped_serov"):
                                txt = "«Живи, Волков. И если найдёшь Морозову — спроси про антенну»."
                zp_dialog([{
                                "speaker": "СЕРОВ", "col": ZCutscene.C_SEROV, "text": txt,
                                "btn": {"text": "Кивнуть и идти", "icon": "door"}, "next": -1,
                }])

func _zp_win_journal() -> void:
                if not bool(zp.get("journal_ready", false)):
                                zp_dialog([{
                                                "speaker": "ЖУРНАЛ СМЕНЫ", "col": ZTerminal.CRT_AMBER,
                                                "text": "Журнал заперт на полке. Ключ — у мастера. (Показания Серова помогут.)",
                                                "btn": {"text": "ОСТАВИТЬ", "icon": "question"}, "next": -1,
                                }])
                                return
                zp_dialog([{
                                "speaker": "ЖУРНАЛ СМЕНЫ · ЗАПИСЬ ТЕХНИКА", "col": ZTerminal.CRT_GREEN,
                                "text": "«Я обслуживал камеры восстановления. 17 октября видел, как Волков открыл глаза.\n\nВ капсуле были ДВОЕ. Второй пациент не значится ни в одном отчёте. V-18. Куда его дели — не знаю».",
                                "sfx": "z_relay", "sfx_db": -14.0,
                                "btn": {"text": "ЗАКРЫТЬ ЖУРНАЛ", "icon": "docs"}, "next": -1,
                }])

# ---------- ТЕХСЕКТОР: ГЕНЕРАТОР (п.8, задача 1) ----------
func _zp_win_gen_panel() -> void:
                if not int(G.zsave["inv"].get("fuse", 0)) > 0:
                                zp_terminal_screen("РАСПРЕДЕЛИТЕЛЬНЫЙ ШКАФ", ZTerminal.CRT_AMBER, [
                                                {"text": "ПРОМЫШЛЕННЫЙ ПРЕДОХРАНИТЕЛЬ ОТСУТСТВУЕТ", "col": ZTerminal.CRT_RED, "delay": 0.5},
                                                {"text": "Поиск по складу техсектора (ящики)", "col": ZTerminal.CRT_AMBER, "delay": 0.5},
                                ], func(): pass)
                                return
                if not bool(zp.get("gen_fuse", false)):
                                zp["gen_fuse"] = true
                                G.z_take_item("fuse", 1)
                                G.play_sfx("z_relay", -8.0)
                                zp_terminal_screen("РАСПРЕДЕЛИТЕЛЬНЫЙ ШКАФ", ZTerminal.CRT_GREEN, [
                                                {"text": "ПРЕДОХРАНИТЕЛЬ УСТАНОВЛЕН", "col": ZTerminal.CRT_GREEN, "delay": 0.5},
                                                {"text": "ПЕРЕКЛЮЧИТЬ РЕЗЕРВНЫЙ КОНТУР?", "col": ZTerminal.CRT_AMBER, "delay": 0.6},
                                ], func():
                                                zp["gen_loop"] = true
                                                _toast("Резервный контур переключён. Осталось охлаждение."))
                else:
                                zp_terminal_screen("РАСПРЕДЕЛИТЕЛЬНЫЙ ШКАФ", ZTerminal.CRT_GREEN, [
                                                {"text": "КОНТУР: РЕЗЕРВНЫЙ", "col": ZTerminal.CRT_GREEN, "delay": 0.4},
                                                {"text": "ОХЛАЖДЕНИЕ: %s" % ("ЗАПУЩЕНО" if bool(zp.get("gen_cool", false)) else "НЕ ЗАПУЩЕНО"), "col": ZTerminal.CRT_AMBER, "delay": 0.5},
                                ], func(): pass)

func _zpro_generator() -> void:
                if not bool(zp.get("gen_fuse", false)) or not bool(zp.get("gen_loop", false)) or not bool(zp.get("gen_cool", false)):
                                _toast("Сначала: предохранитель, резервный контур, охлаждение.")
                                G.play_sfx("z_dry", -10.0, 0.7)
                                return
                zp["gen_on"] = true
                G.zset_flag("repaired_generator", true)
                zp_amb.set_mode("bunker")
                zp_scene([
                                {"wait": 0.4, "sfx": "z_lift_hit1", "sfx_db": -8.0, "shake": 0.9, "shake_k": 9.0},
                                {"sfx": "z_lift_hit2", "sfx_db": -8.0, "wait": 0.7, "shake": 0.7, "shake_k": 7.0},
                                {"speaker": "ГЕНЕРАТОРНАЯ", "col": ZTerminal.CRT_GREEN,
                                                "text": "Генератор выходит на режим с ленивого рычания. Лампы выравниваются. Гул заполняет комнаты — впервые за долгое время объект «Заря» звучит живым.",
                                                "hold": 1.4, "wait": 1.0},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Мощность: 18%. Резервный контур стабилен. Хорошая работа, пациент V-17».",
                                                "hold": 1.3, "wait": 0.8},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Я не твой пациент».", "hold": 1.0, "wait": 0.6},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Это вопрос формулировок».", "hold": 1.2, "wait": 0.6},
                ], func():
                                _complete_objective("gen18")
                                _toast("Генератор восстановлен. Свет в техсекторе стал ровнее."))

# ---------- УТЕЧКА ГАЗА: КЛАПАН (п.8, задача 2) ----------
func _zpro_gas_valve() -> void:
                # клапан доступен с другой стороны решётки — через тоннель
                zp["gas_fixed"] = true
                G.zset_flag("gas_fixed", true)
                zp_amb.set_mode("bunker")
                G.play_sfx("z_pressure_hiss", -6.0, 1.2)
                zp_scene([
                                {"wait": 0.4},
                                {"speaker": "ТОННЕЛЬ ОХЛАЖДЕНИЯ", "col": ZTerminal.CRT_GREEN,
                                                "text": "Клапан поддаётся с третьего оборота. Шипение газа стихает, иней на стекле КПК тает.",
                                                "hold": 1.2, "wait": 0.8},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Утечка изолирована. Концентрация падает».",
                                                "hold": 1.0, "wait": 0.6},
                ], func():
                                _complete_objective("gas")
                                _toast("Утечка перекрыта. Дышать стало легче — в прямом смысле."))

# ---------- ОРУЖЕЙНАЯ (п.10) ----------
func _zp_win_armory() -> void:
                if bool(zp.get("armory_open", false)):
                                return
                if bool(zp.get("armory_code", false)):
                                zp["armory_open"] = true
                                G.play_sfx("z_relay", -6.0)
                                G.play_sfx("z_seal_lock", -10.0)
                                # ПММ: пистолет + 24 патрона + дымовые шашки + ремкомплект + фонарь + сухпайки
                                G.z_give_item("mag_pistol", 3)
                                G.z_give_item("smoke", 2)
                                G.z_give_item("food", 2)
                                G.zsave["ammo"]["pistol"] = int(G.zsave["ammo"].get("pistol", 0)) + 24
                                zp_dialog([{
                                                "speaker": "ОРУЖЕЙНАЯ · ШКАФ ОТКРЫТ", "col": ZTerminal.CRT_GREEN,
                                                "text": "ПММ, 24 патрона, две дымовые шашки, комплект ремонта оружия, военный фонарь, сухпайки.\n\nКаждый выстрел теперь — осознанное решение.",
                                                "sfx": "z_pickup", "sfx_db": -8.0,
                                                "btn": {"text": "ВЗЯТЬ ВСЁ", "icon": "pistol"}, "next": -1,
                                }], func(): _complete_objective("armory"))
                elif int(G.zsave["inv"].get("lockpick", 0)) > 0:
                                G.z_take_item("lockpick", 1)
                                zp["armory_open"] = true
                                G.play_sfx("z_relay", -6.0)
                                _alert_zombies(player["spr"].position, 420.0)
                                zp_dialog([{
                                                "speaker": "ОРУЖЕЙНАЯ · ВЗЛОМ", "col": ZUI.WARN,
                                                "text": "Отмычка хрустит, замок сдаётся — громко. Всё оружие на месте, но вы потратили время и подняли шум.",
                                                "sfx": "z_metal", "sfx_db": -8.0,
                                                "btn": {"text": "ЗАБРАТЬ БОЕЗАПАС", "icon": "pistol"}, "next": -1,
                                }], func():
                                                G.z_give_item("mag_pistol", 3)
                                                G.z_give_item("smoke", 2)
                                                G.zsave["ammo"]["pistol"] = int(G.zsave["ammo"].get("pistol", 0)) + 24
                                                _complete_objective("armory"))
                else:
                                zp_dialog([{
                                                "speaker": "ОРУЖЕЙНАЯ · КОДОВЫЙ ЗАМОК", "col": ZUI.ALERT,
                                                "text": "Замок с четырёхзначным кодом. Вспомнить его вы не можете.\n\n(Код знает техник из мастерской. Или найдите отмычку в прачечной.)",
                                                "sfx": "z_dry", "sfx_db": -10.0,
                                                "btn": {"text": "ОТСТУПИТЬ", "icon": "door"}, "next": -1,
                                }])

# ---------- КАРАНТИН: БЛОКИРОВКА (п.11) ----------
func _zpro_lockdown_start() -> void:
                zp["lockdown_started"] = true
                zp["iso_active"] = true
                zp_countdown = 46.0 * float(G.zdiff_param("countdown_k"))
                zp_amb.set_mode("alarm")
                zp_scene([
                                {"wait": 0.4, "red": true, "sfx": "z_beep_alarm", "sfx_db": -10.0},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_ALERT,
                                                "text": "«Обнаружено несанкционированное перемещение пациента V-17. Запускаю процедуру изоляции».",
                                                "voice": G.voice_list("ai_isolation"), "voice_db": 1.0,
                                                "speed": 0.034, "hold": 1.4, "wait": 0.8},
                                {"call": func():
                                                _close_door("qr2_n")
                                                _close_door("qr2_e")
                                                _close_door("arm_e"), "shake": 0.8, "shake_k": 12.0,
                                                "sfx": "z_blast_close", "sfx_db": -4.0, "wait": 0.8},
                                {"speaker": "КАРАНТИННЫЙ БЛОК", "col": ZCutscene.C_SYSTEM,
                                                "text": "Двери начинают закрываться одна за другой. За стёклами камер просыпаются силуэты.",
                                                "hold": 1.2, "wait": 0.8},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Аварийный шлюз — в дальнем конце блока. Аварийный ключ — у сотрудника в блоке. Время: ограничено».",
                                                "hold": 1.4, "wait": 0.6},
                ], func():
                                _toast("ИЗОЛЯЦИЯ: %d СЕКУНД" % int(zp_countdown))
                                if G.zdiff_hints():
                                                _toast("Панель изоляции отключит блокировку. Ключ — у мёртвого охранника."))

func _zpro_lockdown_missed() -> void:
                if bool(zp.get("iso_off", false)) or bool(zp.get("lockdown_missed", false)):
                                return
                zp["lockdown_missed"] = true
                zp["iso_active"] = false
                G.zset_flag("alarm_triggered", true)
                zp_amb.set_mode("alarm")
                zp_scene([
                                {"wait": 0.3, "flash": 0.08, "flash_col": Color(1.0, 0.25, 0.2, 0.75), "flash_fade": 0.9, "shake": 1.0, "shake_k": 16.0},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_ALERT,
                                                "text": "«Процедура изоляции не завершена. Открываю камеры карантина. Пациенты — свободны».",
                                                "hold": 1.4, "wait": 0.8},
                                {"call": Callable(self, "_cb_iso_wave"), "wait": 0.6},
                                {"speaker": "СИСТЕМА", "col": ZCutscene.C_SYSTEM,
                                                "text": "Гермодвери расходятся. Из карантина на вас смотрит слишком много глаз.",
                                                "hold": 1.2, "wait": 0.8},
                ], func():
                                _toast("ТРЕВОГА ПОДНЯТА. Камеры открыты."))

func _cb_iso_wave() -> void:
                # массовое открытие камер: волна из блоков
                for i in range(5):
                                var p := Vector2(1120 + (i % 3) * 300, 2640 + (i / 3) * 260)
                                _spawn_zombie("sci" if i % 2 == 0 else "walk", p)
                                zombies[zombies.size() - 1]["alert"] = true
                                zombies[zombies.size() - 1]["state"] = "chase"
                G.play_sfx("z_shriek", -6.0)

func _zpro_iso_off() -> void:
                if int(G.zsave["inv"].get("air_key", 0)) <= 0:
                                _toast("Нужен аварийный ключ.")
                                return
                zp["iso_off"] = true
                zp["iso_active"] = false
                G.z_take_item("air_key", 1)
                G.play_sfx("z_seal_lock", -6.0)
                zp_amb.set_mode("bunker")
                zp_scene([
                                {"wait": 0.4, "red_off": true, "sfx": "z_relay", "sfx_db": -8.0},
                                {"speaker": "ПАНЕЛЬ ИЗОЛЯЦИИ", "col": ZTerminal.CRT_GREEN,
                                                "text": "Автоматическая изоляция отключена. Камеры останутся заперты — пока.",
                                                "hold": 1.1, "wait": 0.8},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Хорошо. Но протокол «Север» всё равно запущен. Вы просто ещё не знаете, что это значит».",
                                                "hold": 1.4, "wait": 0.8},
                ], func():
                                _complete_objective("iso")
                                _open_door("sas_n")
                                _toast("Аварийный шлюз разблокирован."))

func _zpro_vent_bypass() -> void:
                # вентиляционный канал между камерами 4 и 5: обход заражённых,
                # участок с повреждённым охлаждением (риск замёрзнуть — ТЗ п.11)
                if bool(zp.get("vent_used", false)):
                                return
                zp["vent_used"] = true
                var dest := Vector2(1560, 3000)
                zp_scene([
                                {"wait": 0.3, "veil": 0.8, "veil_to": 0.95, "sfx": "z_vent_loop", "sfx_db": -12.0},
                                {"speaker": "ВЕНТИЛЯЦИЯ · КАМЕРЫ 4–5", "col": ZTerminal.CRT_AMBER,
                                                "text": "Тесно. Холодно. Слой инея на металле ломается под пальцами, и каждый хруст кажется выстрелом.",
                                                "sfx": "z_ice_crack", "sfx_db": -10.0, "hold": 1.4, "wait": 1.0},
                                {"call": func():
                                                player["spr"].position = _collide_circle(dest, 15.0)
                                                player["halo"].position = player["spr"].position
                                                camera.position = player["spr"].position
                                                camera.reset_smoothing()
                                                zp["hypo"] = minf(1.0, float(zp["hypo"]) + 0.5)
                                                _zpro_hypo_hit(0.2)},
                                {"wait": 0.8, "veil": 0.6, "veil_to": 0.0},
                ], func():
                                G.zset_flag("used_stealth_route", true)
                                _toast("Вы в обход. Боеприпасы сохранены."))

# ---------- КОМНАТА НАБЛЮДЕНИЯ: МОРОЗОВА (п.12) ----------
func _zpro_morozova() -> void:
                zp["morozova_done"] = true
                zp_amb.play_voice_seq(G.voice_list("morozova_record"), 1.0)
                zp_amb.set_mode("alarm_far")
                zp_scene([
                                {"wait": 0.5, "veil": 1.0, "veil_to": 0.4, "sfx": "z_radio_beep", "sfx_db": -14.0},
                                {"speaker": "ЗАПИСЬ · ДОКТОР ЕЛЕНА МОРОЗОВА", "col": ZCutscene.C_VOICE,
                                                "text": "За её спиной — удары в дверь. Ритмичные. Терпеливые.",
                                                "sfx": "z_metal", "sfx_db": -14.0, "hold": 1.2, "wait": 1.0},
                                {"speaker": "МОРОЗОВА", "col": ZCutscene.C_VOICE,
                                                "text": "«Если кто-нибудь когда-нибудь увидит эту запись, значит, протокол эвакуации провалился. Мы ошиблись в самом начале. Мы считали, что микроорганизм восстанавливает повреждённые связи. Он не восстанавливает их. Он создаёт новые».",
                                                "speed": 0.038, "hold": 1.6, "wait": 1.0},
                                {"speaker": "МОРОЗОВА", "col": ZCutscene.C_VOICE,
                                                "text": "«Волков — не первый, кто вернулся. Но он первый, кто помнит, кем был».",
                                                "hold": 1.5, "wait": 1.0},
                                {"speaker": "МОРОЗОВА", "col": ZCutscene.C_VOICE,
                                                "text": "«Если он доберётся до поверхности, не позволяйте ему приблизиться к антенне. И если он спросит, где я...»",
                                                "sfx": "z_blast_close", "sfx_db": -12.0, "hold": 1.2, "wait": 0.6},
                                {"speaker": "ЗАПИСЬ", "col": ZCutscene.C_SYSTEM,
                                                "text": "Запись обрывается. Дверь за её спиной держится — пока держалась.",
                                                "shake": 0.6, "shake_k": 10.0, "hold": 1.0, "wait": 0.8},
                                {"speaker": "АРХИВ О. «ЗАРЯ»", "col": ZTerminal.CRT_RED,
                                                "text": "АРХИВ ПОВРЕЖДЁН\nСУБЪЕКТ V-17: СТАТУС НЕИЗВЕСТЕН\nПРОТОКОЛ «СЕВЕР»: АКТИВЕН",
                                                "blink": false, "hold": 1.6, "wait": 1.0},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Какая ещё антенна?..»", "hold": 1.0, "wait": 0.7},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Алексей Волков. Мне необходимо, чтобы вы покинули объект».",
                                                "voice": G.voice_list("ai_order_changed"), "voice_db": 1.0,
                                                "hold": 1.2, "wait": 0.7},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Ты же не хотел меня выпускать».", "hold": 1.0, "wait": 0.7},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Ранее я выполнял приказ. Теперь приказ изменился».",
                                                "hold": 1.2, "wait": 0.7},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Чей?»", "hold": 0.8, "wait": 0.7},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Неизвестно».",
                                                "hold": 1.2, "wait": 0.6},
                ], func():
                                _complete_objective("frost")
                                _zpro_escape_start())

# ---------- ПОБЕГ (п.13) ----------
func _zpro_escape_start() -> void:
                if bool(zp.get("escape_on", false)):
                                return
                zp["escape_on"] = true
                zp_amb.play_voice_seq([], 0.0)
                zp_scene([
                                {"wait": 0.4, "sfx": "z_data_wipe", "sfx_db": -8.0, "red": true, "glitch": true},
                                {"speaker": "СИСТЕМА О. «ЗАРЯ»", "col": ZCutscene.C_SYSTEM,
                                                "text": "Система начинает уничтожать данные. Камеры карантина открываются одна за другой.",
                                                "hold": 1.2, "wait": 0.8},
                                {"call": Callable(self, "_cb_escape_spawns")},
                                {"wait": 0.6, "shake": 0.7, "shake_k": 12.0, "sfx": "z_shriek", "sfx_db": -8.0},
                                {"speaker": "ЗАРАЖЁННЫЙ · В ОБЪЕКТИВ КАМЕРЫ", "col": ZCutscene.C_ALERT,
                                                "text": "Один из них останавливается. Смотрит прямо в объектив. Не мигая.\n\n«Мы знаем, что ты проснулся».",
                                                "speed": 0.04, "hold": 1.6, "wait": 1.0},
                                {"call": Callable(self, "_zpro_lights_out")},
                                {"speaker": "СИСТЕМА", "col": ZCutscene.C_SYSTEM,
                                                "text": "И гаснет свет.",
                                                "hold": 1.0, "wait": 0.8},
                ], func():
                                _complete_objective("escape")
                                # сталкер: заражённый охранник с сохранившимися моторными навыками
                                _zpro_spawn_stalker()
                                _toast("СВЕТ ПОГАС. Фонарь — ваш единственный союзник (кнопка ЛАМПА)."))

func _cb_escape_spawns() -> void:
                # часть заражённых идёт к игроку, часть — к техническим помещениям
                for i in range(4):
                                var p := Vector2(1050 + i * 240, 2600 + (i % 2) * 300)
                                _spawn_zombie("sci" if i % 2 == 0 else "run", p)
                                var zz: Dictionary = zombies[zombies.size() - 1]
                                zz["alert"] = true
                                zz["state"] = "chase" if i < 2 else "wander"
                _open_door("qr2_n")
                _open_door("qr2_e")

func _zpro_lights_out() -> void:
                zp_lights_out = true
                # гасим аварийные лампы и подсветку комнат
                for l in lamp_lights:
                                if is_instance_valid(l):
                                                l.energy = 0.0
                for h in halos:
                                if is_instance_valid(h):
                                                h.modulate.a = 0.05
                canvas_mod.color = Color(0.32, 0.35, 0.40)
                if zp_amb != null:
                                zp_amb.set_mode("gas")

func _zpro_light_switch() -> void:
                # выбор: аварийное освещение (видно ловушки/движение, но привлекает) или темнота
                zp_lights_out = not zp_lights_out
                G.play_sfx("z_relay", -8.0)
                if not zp_lights_out:
                                for l in lamp_lights:
                                                if is_instance_valid(l):
                                                                l.energy = 0.9
                                for h in halos:
                                                if is_instance_valid(h):
                                                                h.modulate.a = 0.3
                                canvas_mod.color = Color(0.60, 0.645, 0.72)
                                for z in zombies:
                                                if z["alive"]:
                                                                z["notice"] = float(z["notice"]) * 1.15
                                _toast("Аварийное освещение включено. Мёртвые видят дальше.")
                else:
                                _zpro_lights_out()
                                _toast("Темнота. Вы почти невидимы — и почти слепы.")

func _zpro_spawn_stalker() -> void:
                # заражённый охранник: использует двери, обходит препятствия, преследует
                _spawn_zombie("cop", Vector2(2320, 2700))
                var z: Dictionary = zombies[zombies.size() - 1]
                z["kind"] = "stalker"
                z["hp"] = 150.0 * (1.0 + (diff_mult - 1.0) * 0.5)
                z["spd"] = 66.0
                z["notice"] = 520.0 * float(G.zdiff_param("notice_k"))
                z["alert"] = true
                z["state"] = "chase"
                zp_stalker = z
                G.play_sfx("z_foot_metal", -8.0)
                _log("Тяжёлые шаги за спиной. Он умеет открывать двери.", Color(0.9, 0.5, 0.4), "ОПАСНОСТЬ")

func _zpro_stalker_tick(delta: float) -> void:
                if zp_stalker == null:
                                return
                if not is_instance_valid(zp_stalker["spr"]) or not bool(zp_stalker["alive"]):
                                zp_stalker = null
                                return
                zp_stalker_rt -= delta
                if zp_stalker_rt <= 0.0:
                                zp_stalker_rt = 16.0
                                # «умеет двери»: если давно не видел игрока — перемещается через открытые двери ближе
                                var d: float = (zp_stalker["spr"].position as Vector2).distance_to(player["spr"].position)
                                if d > 900.0 and not _los_clear(zp_stalker["spr"].position, player["spr"].position):
                                                # перемещение к соседней открытой двери рядом с игроком
                                                var best: Vector2 = Vector2.ZERO
                                                var bd := 1e12
                                                for dz in doors.values():
                                                                if not bool(dz["opened"]):
                                                                                continue
                                                                var dp: Vector2 = dz["pr"]["pos"]
                                                                var dd: float = dp.distance_to(player["spr"].position)
                                                                if dd < bd and dd > 260.0:
                                                                                bd = dd
                                                                                best = dp
                                                if best != Vector2.ZERO:
                                                                zp_stalker["spr"].position = best
                                                                G.play_sfx("z_foot_metal", -10.0)
                                                                _log("Шаги... они снова за спиной.", Color(0.9, 0.5, 0.4), "ОПАСНОСТЬ")

# ---------- ГОЛОС У ШЛЮЗА + ВОСПОМИНАНИЕ (п.13, этап 3) ----------
func _zpro_speaker_scene() -> void:
                zp_amb.play_voice_seq(G.voice_list("female_ward"), 1.0)
                zp_dialog([{
                                "speaker": "ДИНАМИК У ШЛЮЗА · ЖЕНСКИЙ ГОЛОС",
                                "col": ZCutscene.C_VOICE,
                                "text": "«Алексей... Ты обещал вернуться».",
                                "voice": G.voice_list("female_ward"), "voice_db": 2.0,
                                "choices": [
                                                {"text": "А:  «Кто ты?..» (ответить)", "icon": "radio", "accent": true},
                                                {"text": "Б:  Выдернуть шнур динамика", "icon": "radio", "accent": false},
                                                {"text": "В:  Проверить источник сигнала", "icon": "question", "accent": false},
                                ],
                                "on_choice": Callable(self, "_cb_speaker_choice"),
                }])

func _cb_speaker_choice(i: int) -> int:
                match i:
                                0:
                                                _zpro_memory_flash(true)
                                1:
                                                G.play_sfx("z_relay", -8.0)
                                                _log("Динамик замолкает. Приступ прошёл быстрее.", Color(0.7, 0.75, 0.7), "СИСТЕМА")
                                2:
                                                G.zset_flag("heard_unknown_voice", true)
                                                _log("Источник сигнала — в закрытом секторе. Точнее терминал не говорит.", Color(0.8, 0.7, 0.5), "СТРАННОЕ")
                return -1

func _zpro_memory_flash(full: bool) -> void:
                G.zset_flag("heard_unknown_voice", true)
                zp_amb.play_voice_seq(G.voice_list("memory_scream"), 1.0)
                zp_scene([
                                {"wait": 0.4, "sfx": "z_memory_flash", "sfx_db": -6.0},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Кто ты?..»", "hold": 0.8, "wait": 0.8},
                                {"speaker": "ГОЛОС", "col": ZCutscene.C_VOICE,
                                                "text": "«Ты ведь помнишь, что случилось на станции?»",
                                                "hold": 1.2, "wait": 0.8},
                                {"wait": 0.6, "flash": 1.2, "flash_col": Color(1, 1, 1, 0.95), "flash_hold": 1.4, "flash_fade": 3.0,
                                                "sfx": "z_tinnitus", "sfx_db": -6.0, "shake": 1.2, "shake_k": 14.0},
                                {"speaker": "ВОСПОМИНАНИЕ", "col": ZCutscene.C_MEMORY,
                                                "text": "Снег. Чёрный лес. Солдаты.",
                                                "hold": 0.9, "wait": 0.6},
                                {"speaker": "ВОСПОМИНАНИЕ", "col": ZCutscene.C_MEMORY,
                                                "text": "Женщина у открытого люка.",
                                                "hold": 0.9, "wait": 0.6},
                                {"speaker": "ГОЛОС В ПАМЯТИ", "col": ZCutscene.C_MEMORY,
                                                "text": "«Капитан, отходите!»",
                                                "sfx": "z_shriek", "sfx_db": -16.0, "shake": 0.6, "shake_k": 10.0, "hold": 0.9, "wait": 0.7},
                                {"speaker": "ВОСПОМИНАНИЕ", "col": ZCutscene.C_MEMORY,
                                                "text": "Выстрел." if not full else "Выстрел. И белый свет.",
                                                "sfx": "expl_s", "sfx_db": -14.0, "hold": 1.0, "wait": 1.0},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Ваш пульс критический. Продолжайте движение к шлюзу».",
                                                "hold": 1.1, "wait": 0.6},
                ])

# ---------- ГРУЗОВОЙ ШЛЮЗ: V-18 (п.14) ----------
func _zpro_gate_open() -> void:
                G.play_sfx("z_hydro_loop", -6.0)
                _toast("Ворота открываются. Медленно. Слишком медленно.")
                # по связи: «V-17. Возвращение к исходной точке»
                G.play_sfx("z_radio_beep", -12.0)
                zp_scene([
                                {"wait": 0.4, "sfx": "z_radio_bed", "sfx_db": -14.0},
                                {"speaker": "РАЦИЯ · ЧУЖОЙ ГОЛОС", "col": ZCutscene.C_RADIO,
                                                "text": "«V-17. Возвращение к исходной точке».",
                                                "hold": 1.2, "wait": 1.0},
                                {"call": func(): _zpro_spawn_v18()},
                                {"wait": 0.8},
                ])

func _zpro_spawn_v18() -> void:
                if zp_v18_spawned:
                                return
                zp_v18_spawned = true
                # тело человека в форме Волкова за медленно открывающимися воротами
                _spawn_corpse("v18", Vector2(1426, 3560))
                zp_v18_timer = 12.0
                zp_scene([
                                {"wait": 0.5, "veil": 0.8, "veil_to": 0.35},
                                {"speaker": "ЗА СТВОРОМ", "col": ZCutscene.C_ALERT,
                                                "text": "За медленно ползущей дверью стоит человек. В вашей форме. С вашим лицом.",
                                                "hold": 1.4, "wait": 0.8},
                                {"speaker": "V-18", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Ты опять опоздал».",
                                                "voice": G.voice_list("v18_voice"), "voice_db": 1.0,
                                                "hold": 1.2, "wait": 0.7},
                                {"call": func(): G.play_sfx("z_metal", -6.0, 0.8)},
                                {"speaker": "СЦЕНА", "col": ZCutscene.C_SYSTEM,
                                                "text": "Он падает. Из груди торчит металлический обломок. На рукаве — номер: V-18.",
                                                "shake": 0.5, "shake_k": 8.0, "hold": 1.4, "wait": 0.8},
                                {"speaker": "ГИДРАВЛИКА", "col": ZTerminal.CRT_RED,
                                                "text": "Датчики перегрева пищат. Осмотр займёт время, которого может не быть.",
                                                "hold": 1.2, "wait": 0.6},
                ], func():
                                _toast("ОСМОТРЕТЬ ТЕЛО или БЕЖАТЬ — гидравлика перегревается."))

func _zpro_v18_inspect() -> void:
                # осмотр тела V-18: первое прямое доказательство другого субъекта
                G.zset_flag("found_v18_body", true)
                zp_v18_timer = -1.0
                _complete_objective("hydro")
                zp_dialog([{
                                "speaker": "ТЕЛО · V-18", "col": ZTerminal.CRT_AMBER,
                                "text": "Форма ваша. Лицо ваше. Обломок в груди — арматура из шлюза.\n\nВ нагрудном кармане: жетон без номера и клочок бумаги:\n\n«НЕ ДАЙ ЕМУ ДОЙТИ ДО АНТЕННЫ».",
                                "sfx": "z_relay", "sfx_db": -14.0,
                                "btn": {"text": "ВСТАТЬ И БЕЖАТЬ", "icon": "door"}, "next": -1,
                }])
                _log("Запись в журнал: субъект V-18 существовал. Он шёл до вас.", Color(0.8, 0.7, 0.5), "ЖУРНАЛ")

func _zpro_gate_overheat() -> void:
                if zp_gate_state >= 4:
                                return
                zp_gate_state = 2
                zp_v18_timer = -1.0
                G.play_sfx("z_hydro_overheat", -6.0)
                zp_scene([
                                {"wait": 0.3, "flash": 0.1, "flash_col": Color(1.0, 0.6, 0.3, 0.7), "flash_fade": 0.8, "shake": 0.8, "shake_k": 14.0},
                                {"speaker": "ГИДРАВЛИКА", "col": ZCutscene.C_ALERT,
                                                "text": "Перегрев. Контур сброшен. Ворота замерли на полпути — придётся держать питание заново.",
                                                "hold": 1.2, "wait": 0.6},
                ])

# ---------- КАМЕРЫ (ветка «проверить камеры» — п.5, задача 3) ----------
func _zp_win_cams() -> void:
                zp_cam_note = true
                zp_scene([
                                {"wait": 0.4, "veil": 0.8, "veil_to": 0.5},
                                {"speaker": "МОНИТОР КАМЕР · МЕДСЕКТОР", "col": ZTerminal.CRT_GREEN,
                                                "text": "На камере человек внутри лифта стоит неподвижно. Потом поднимает голову — прямо в объектив.",
                                                "shake": 0.5, "shake_k": 8.0, "hold": 1.3, "wait": 0.8},
                                {"sfx": "z_static", "sfx_db": -8.0, "wait": 0.6},
                                {"speaker": "МОНИТОР", "col": ZTerminal.CRT_RED,
                                                "text": "СИГНАЛ ПОТЕРЯН",
                                                "blink": true, "hold": 0.8, "wait": 0.8},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Рекомендуется оставаться в медицинском секторе. Эвакуационный лифт доступен. Патрулирование... не обнаружено».",
                                                "hold": 1.4, "wait": 0.8},
                                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                                                "text": "«Ты уверен, что это был не патруль?»", "hold": 1.0, "wait": 0.7},
                                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                                                "text": "«Нет».",
                                                "hold": 1.0, "wait": 0.6},
                ], func():
                                G.zset_flag("trust_ai", true)
                                _toast("Вы последовали подсказке ИИ. Часть данных он всё же скрыл."))

# ---------- прочие окна ----------
func _zp_win_note(title: String, body: String, col: Color) -> void:
                zp_dialog([{
                                "speaker": title, "col": col, "text": body,
                                "btn": {"text": "ЗАКРЫТЬ", "icon": "docs"}, "next": -1,
                }])

# ---------- ДИКТОФОН ВРАЧА: ЗАПИСЬ № 01 «СМЕНА» (п.5) ----------
func _zp_win_recorder() -> void:
        zp["med_pass"] = true
        zp_scene([
                {"wait": 0.5, "sfx": "z_radio_beep", "sfx_db": -14.0},
                {"speaker": "ДИКТОФОН · ЗАПИСЬ № 01 «СМЕНА»", "col": ZTerminal.CRT_GREEN,
                        "text": "«Третья неделя после инцидента. Они говорят, что всё под контролем. Сегодня один из пациентов произнёс имя своей дочери. Девочка умерла шесть лет назад».",
                        "speed": 0.036, "hold": 1.4, "wait": 1.0},
                {"speaker": "ЗАПИСЬ № 01", "col": ZTerminal.CRT_GREEN,
                        "text": "«Мы проверили камеры. Никто не входил в палату. Никаких записей в базе. Он продолжал говорить с ней до отключения питания».",
                        "hold": 1.4, "wait": 1.0},
                {"wait": 0.8, "sfx": "z_whisper1", "sfx_db": -12.0},
                {"speaker": "КОНЕЦ ЗАПИСИ", "col": ZCutscene.C_VOICE,
                        "text": "«Она здесь».",
                        "shake": 0.5, "shake_k": 8.0, "hold": 1.4, "wait": 1.0},
        ], func():
                _toast("Пароль врача найден: строка из диктофона. Медтерминал ждёт."))

# ---------- ЛИФТ МЕЖДУ ЭТАЖАМИ (п.8) ----------
func _zpro_elevator_scene() -> void:
        zp_amb.set_mode("bunker")
        zp_scene([
                {"wait": 0.4, "sfx": "z_door", "sfx_db": -8.0},
                {"wait": 0.8, "sfx": "z_lift_hit1", "sfx_db": -8.0, "shake": 0.4, "shake_k": 6.0},
                {"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
                        "text": "«Обнаружена неисправность системы электропитания. Пожалуйста, сохраняйте спокойствие».",
                        "hold": 1.3, "wait": 0.8},
                {"wait": 0.9, "sfx": "z_lift_hit2", "sfx_db": -6.0, "shake": 0.6, "shake_k": 10.0},
                {"speaker": "ЛИФТ", "col": ZCutscene.C_SYSTEM,
                        "text": "Кабина падает на несколько сантиметров и замирает. Где-то сверху — три тяжёлых удара.",
                        "hold": 1.2, "wait": 0.8},
                {"wait": 0.7, "sfx": "z_lift_hit3", "sfx_db": -4.0, "shake": 0.9, "shake_k": 16.0},
                {"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
                        "text": "«Ну давай. Покажи, кто ты».",
                        "sfx": "z_knife", "sfx_db": -12.0, "hold": 1.1, "wait": 0.9},
                {"speaker": "ДИНАМИК ЛИФТА", "col": ZCutscene.C_VOICE,
                        "text": "Из динамика — его собственный голос. Точно его. Только произнесённый чужим человеком:\n\n«Не открывай дверь».",
                        "speed": 0.038, "sfx": "z_whisper2", "sfx_db": -10.0, "hold": 1.6, "wait": 1.2},
                {"wait": 0.8, "veil": 1.0, "veil_to": 1.0},
                {"call": Callable(self, "_cb_elevator_arrive")},
                {"wait": 0.6, "veil": 0.8, "veil_to": 0.0},
                {"speaker": "ТЕХНИЧЕСКИЙ СЕКТОР", "col": ZTerminal.CRT_AMBER,
                        "text": "Трубы. Кабели. Пар из стыков. Одни трубы раскалены, другие покрыты инеем. Пол вибрирует.",
                        "hold": 1.3, "wait": 0.8},
        ], func():
                _toast("Технический сектор. Генератор — в западном зале."))

func _cb_elevator_arrive() -> void:
        player["spr"].position = _collide_circle(Vector2(500, 2100), 15.0)
        player["halo"].position = player["spr"].position
        camera.position = player["spr"].position
        camera.reset_smoothing()   # камера сразу на месте — без «перелёта» через бункер
        if not G.zsave["weapons"].has("knife"):
                G.zsave["weapons"].append("knife")

# ---------- ФОНАРЬ И ДЫМ (стелс по ТЗ п.6/13) ----------
func _zpro_toggle_flash() -> void:
        zp["flash_off"] = not bool(zp.get("flash_off", false))
        if player.has("light") and is_instance_valid(player["light"]):
                player["light"].energy = 0.0 if bool(zp["flash_off"]) else 0.95
        player["halo"].modulate.a = 0.12 if bool(zp.get("flash_off", false)) else 0.32
        G.play_sfx("z_relay", -18.0, 1.4)
        if bool(zp.get("flash_off", false)):
                _toast("Фонарь выключен. Вы часть темноты.")
        else:
                _toast("Фонарь включён. Мёртвые видят свет.")

func _zpro_use_smoke() -> void:
        if int(G.zsave["inv"].get("smoke", 0)) <= 0:
                _toast("Нет дымовых шашек.")
                return
        G.z_take_item("smoke", 1)
        var p: Vector2 = player["spr"].position
        zp_smoke_zones.append({"rect": Rect2(p - Vector2(240, 240), Vector2(480, 480)), "t": 9.0})
        G.play_sfx("z_pressure_hiss", -6.0)
        # визуал: облако частиц
        var smoke := CPUParticles2D.new()
        smoke.amount = 60
        smoke.lifetime = 3.4
        smoke.texture = _light_tex()
        smoke.scale_amount_min = 1.4
        smoke.scale_amount_max = 3.2
        smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
        smoke.emission_sphere_radius = 60.0
        smoke.spread = 180.0
        smoke.initial_velocity_min = 30.0
        smoke.initial_velocity_max = 90.0
        smoke.gravity = Vector2(0, -14)
        smoke.color = Color(0.62, 0.66, 0.68, 0.4)
        smoke.position = p
        smoke.emitting = true
        fx_layer.add_child(smoke)
        _log("Дымовая завеса. Мёртвые теряют вас из виду.", Color(0.7, 0.8, 0.75), "СИСТЕМА")

# ================= СМОУК-ХУКИ =================
func smoke_info() -> Dictionary:
                                                                return {
                                                                                                                                "player": is_instance_valid(player["spr"]),
                                                                                                                                "zombies": zombies.size(),
                                                                                                                                "allies": allies.size(),
                                                                                                                                "objectives": objectives.size(),
                                                                                                                                "props": props.size(),
                                                                                                                                "corpses": corpses.size(),
                                                                                                                                "walls": walls.size(),
                                                                                                                                "mission": mission,
                                                                                                                                "terr_cells": terr.size(),
                                                                }
