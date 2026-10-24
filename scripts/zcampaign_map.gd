# ============================================================
# КАМПАНИЯ «ЗЕМЛЯ МЕРТВЫХ» — ЭКРАН ГЛОБАЛЬНОЙ КАРТЫ КАМПАНИИ
# (по ТЗ №1, раздел 4)
# Открывается после выхода из бункера: цепь из 20 секторов
# на фоне заснеженного Севера с метелью.
# СЛЕВА  — интерактивная карта: доступная точка пульсирует,
#          узлы кликабельны (разведданные по выбранному сектору).
# СПРАВА — окно дневника/КПК с последней записью (первая —
#          «СЕКТОР 1: ВЫХОД ИЗ БУНКЕРА "ЗАРЯ"»).
# ПОД ЗАПИСЬЮ — большая кнопка [ НАЧАТЬ ПУТЬ НА СЕВЕР ].
# Лагеря между секторами: перевязка, патроны, торговля, наём.
# ============================================================
extends Control

const Med = preload("res://scripts/med.gd")

var main_ref = null
var time_t := 0.0
var draw_off := Vector2.ZERO
var sel_idx := -1                # выбранный на карте узел (-1 = текущий)
var board: Control = null        # кликабельная зона карты
var node_positions: Array = []   # позиции узлов в ЛОКАЛЬНЫХ координатах board
const BOARD_POS := Vector2(36, 150)  # позиция доски в дизайн-координатах

func _fit_design() -> void:
        var vs := get_viewport_rect().size
        var k := maxf(0.5, minf(vs.x / 1600.0, vs.y / 900.0))
        scale = Vector2(k, k)
        var design := vs / k
        draw_off = Vector2(maxf(0.0, (design.x - 1600.0) * 0.5), maxf(0.0, (design.y - 900.0) * 0.5))

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _fit_design()
        G.set_music_track("z")
        _build_snow_backdrop()
        # заголовок
        var title_block := VBoxContainer.new()
        title_block.position = Vector2(30, 14) + draw_off
        title_block.add_theme_constant_override("separation", 4)
        add_child(title_block)
        var over := ZUI.label("— ПОЛЕВОЙ ШТАБ ВЫЖИВШИХ · СЕВЕРНЫЕ ТЕРРИТОРИИ —", 13, ZUI.FAINT)
        title_block.add_child(over)
        var title := ZUI.label("«ЗЕМЛЯ МЕРТВЫХ»", 34, ZUI.NEON_BRIGHT)
        title_block.add_child(title)
        var tdiv := ZUI.hdivider()
        tdiv.custom_minimum_size = Vector2(260, 2)
        title_block.add_child(tdiv)
        var sub := ZUI.label("20 зараженных секторов на север. Источник штамма — Северный бункер.", 14, ZUI.MUTED)
        title_block.add_child(sub)
        ZUI.entrance(title_block, 0.05, 16)
        _build_map_board()
        _build_diary_panel()
        _build_profile_chips()
        _build_buttons()
        # если кампания пройдена
        if bool(G.zsave.get("campaign_won", false)):
                var won := ZUI.label("ШТАММ ОСТАНОВЛЕН. КАМПАНИЯ ПРОЙДЕНА.", 16, ZUI.NEON_BRIGHT)
                won.position = Vector2(30, 128) + draw_off
                add_child(won)

# ---------- зимний фон: небо, топографика, метель ----------
func _build_snow_backdrop() -> void:
        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.043, 0.050, 0.062)
        add_child(bg)
        var grad := ColorRect.new()
        grad.set_anchors_preset(Control.PRESET_FULL_RECT)
        grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var gsh := Shader.new()
        gsh.code = """
shader_type canvas_item;
void fragment() {
        vec3 top = vec3(0.020, 0.026, 0.038);
        vec3 bot = vec3(0.075, 0.088, 0.105);
        vec3 c = mix(bot, top, UV.y);
        // холодное свечение севера сверху
        c += vec3(0.05, 0.07, 0.10) * smoothstep(0.7, 0.0, UV.y) * 0.5;
        COLOR = vec4(c, 1.0);
}
"""
        var gm := ShaderMaterial.new()
        gm.shader = gsh
        grad.material = gm
        add_child(grad)
        var topo := ColorRect.new()
        topo.set_anchors_preset(Control.PRESET_FULL_RECT)
        topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        topo.material = UiKit.make_topo_material()
        topo.modulate = Color(0.55, 0.65, 0.9, 0.5)
        add_child(topo)
        add_child(ZUI.vignette(0.45))
        add_child(ZUI.grain(0.05))
        # метель: три слоя снега
        for layer_i in range(3):
                var snow := CPUParticles2D.new()
                snow.amount = [60, 90, 130][layer_i]
                snow.lifetime = [7.0, 5.0, 3.4][layer_i]
                snow.preprocess = 6.0
                snow.texture = _snow_tex()
                snow.scale_amount_min = [0.5, 0.8, 1.3][layer_i]
                snow.scale_amount_max = [1.0, 1.4, 2.2][layer_i]
                snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
                snow.emission_rect_extents = Vector2(1100, 12)
                snow.position = Vector2(800 + draw_off.x, -30 + draw_off.y)
                snow.direction = Vector2(-0.35, 1.0)
                snow.spread = 8.0
                snow.gravity = Vector2(4, 26)
                snow.initial_velocity_min = 60.0 + layer_i * 55.0
                snow.initial_velocity_max = 120.0 + layer_i * 80.0
                var a: float = [0.20, 0.34, 0.55][layer_i]
                snow.color = Color(0.92, 0.95, 1.0, a)
                add_child(snow)

func _snow_tex() -> Texture2D:
        var gt := GradientTexture2D.new()
        gt.width = 16
        gt.height = 16
        gt.fill = GradientTexture2D.FILL_RADIAL
        gt.fill_from = Vector2(0.5, 0.5)
        gt.fill_to = Vector2(0.5, 0.0)
        var gr := Gradient.new()
        gr.set_color(0, Color(1, 1, 1, 1))
        gr.set_color(1, Color(1, 1, 1, 0))
        gt.gradient = gr
        return gt

# ---------- ЛЕВАЯ ЧАСТЬ: интерактивная карта ----------
func _build_map_board() -> void:
        board = Control.new()
        board.position = BOARD_POS + draw_off
        board.custom_minimum_size = Vector2(620, 640)
        board.size = board.custom_minimum_size
        board.mouse_filter = Control.MOUSE_FILTER_STOP
        board.gui_input.connect(_on_board_input)
        add_child(board)

func _on_board_input(ev: InputEvent) -> void:
        if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
                var mp: Vector2 = board.get_local_mouse_position()
                var best := -1
                var bd := 34.0
                for i in range(node_positions.size()):
                        var d: float = (node_positions[i] as Vector2).distance_to(mp)
                        if d < bd:
                                bd = d
                                best = i
                if best >= 0:
                        G.play_sfx("ui_click", -12.0, 1.3)
                        sel_idx = best
                        _refresh_info()
                        queue_redraw()

# ---------- ПРАВАЯ ЧАСТЬ: дневник/КПК + кнопка пути ----------
var info_panel: PanelContainer = null
var info_title_lbl: Label = null
var info_kind_lbl: Label = null
var info_desc_lbl: Label = null
var diary_lbl: Label = null
var start_btn: ZUI.ZButton = null

func _build_diary_panel() -> void:
        info_panel = PanelContainer.new()
        # корпус планшета: тёмный металл, неоновая кромка
        var pst := ZUI.panel_style(Color(0.028, 0.036, 0.032, 0.97), Color(0.16, 0.34, 0.22), 16)
        pst.border_width_top = 3
        info_panel.add_theme_stylebox_override("panel", pst)
        info_panel.position = Vector2(700, 92) + draw_off
        info_panel.custom_minimum_size = Vector2(560, 560)
        add_child(info_panel)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        info_panel.add_child(vb)
        # шапка устройства
        var top := HBoxContainer.new()
        top.add_theme_constant_override("separation", 10)
        vb.add_child(top)
        var led := ColorRect.new()
        led.color = ZUI.NEON
        led.custom_minimum_size = Vector2(8, 8)
        top.add_child(led)
        var dev := ZUI.label("КПК «ЗАРЯ» · ПОЛЕВОЙ ДНЕВНИК КОМАНДИРА", 11, Color(0.55, 0.78, 0.58))
        dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        top.add_child(dev)
        top.add_child(ZUI.label("АКБ ▰▰▰▰▱", 11, ZUI.NEON_DIM))
        vb.add_child(ZUI.hdivider(1, Color(0.16, 0.30, 0.20)))
        # разведданные выбранного узла
        info_kind_lbl = ZUI.label("", 11, ZUI.NEON)
        vb.add_child(info_kind_lbl)
        info_title_lbl = ZUI.label("", 22, ZUI.WARN)
        vb.add_child(info_title_lbl)
        info_desc_lbl = ZUI.wrap_label("", 14, Color(0.78, 0.8, 0.7), 520.0)
        vb.add_child(info_desc_lbl)
        vb.add_child(ZUI.hdivider(1, Color(0.16, 0.30, 0.20)))
        # запись дневника
        var dhead := HBoxContainer.new()
        dhead.add_theme_constant_override("separation", 8)
        var dic := ZUI.icon_rect("pda", 18, ZUI.NEON)
        dic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        dhead.add_child(dic)
        var dtl := ZUI.label("ЗАПИСЬ ДНЕВНИКА", 14, ZUI.NEON_BRIGHT)
        dtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        dhead.add_child(dtl)
        vb.add_child(dhead)
        diary_lbl = ZUI.wrap_label("", 14, Color(0.82, 0.86, 0.74), 520.0)
        diary_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vb.add_child(diary_lbl)
        # большая кнопка пути (по ТЗ — с SVG-иконкой)
        var brow := HBoxContainer.new()
        brow.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(brow)
        start_btn = ZUI.ZButton.new("", Vector2(520, 64), true, 18, "arrow")
        start_btn.pressed.connect(func():
                G.play_sfx("ui_click", -6.0)
                var cur := mini(int(G.zsave["sector"]), G.ZSECTORS.size() - 1)
                var sec: Dictionary = G.ZSECTORS[cur]
                if sec["type"] in ["camp", "camp_big"]:
                        _open_camp(sec["type"] == "camp_big")
                elif main_ref != null:
                        main_ref.start_zbattle())
        brow.add_child(start_btn)
        _refresh_info()

func _refresh_info() -> void:
        var cur := mini(int(G.zsave["sector"]), G.ZSECTORS.size() - 1)
        var idx := cur if sel_idx < 0 else sel_idx
        var sec: Dictionary = G.ZSECTORS[idx]
        var kind_ru := {
                "bunker": "СЮЖЕТНЫЙ БУНКЕР", "clear": "ЗАЧИСТКА", "warehouse": "СКЛАД",
                "tablets": "ПОИСК ДАННЫХ", "defense": "ОБОРОНА", "rescue": "СПАСЕНИЕ",
                "camp": "ЛАГЕРЬ", "camp_big": "КРУПНЫЙ ЛАГЕРЬ", "final": "ФИНАЛ",
        }
        var passed: bool = idx < cur
        var is_cur: bool = idx == cur
        info_kind_lbl.text = "УЗЕЛ %02d / 20  /  %s%s" % [idx + 1, kind_ru.get(sec["type"], "РАЙОН"), "  ·  ПРОЙДЕН" if passed else ("  ·  ВЫ ЗДЕСЬ" if is_cur else "")]
        info_title_lbl.text = sec["name"].to_upper()
        info_desc_lbl.text = sec["desc"]
        # дневник: последняя запись
        var d: int = int(G.zsave.get("diary", 0))
        if d <= 0:
                diary_lbl.text = "Записей нет. Выхода из бункера ещё не было."
        else:
                var last: int = d
                var txt: String = G.ZDIARY[last] if G.ZDIARY.has(last) else ""
                diary_lbl.text = txt + "\n\n— всего записей: %d (архив — в бою, в КПК)" % d
        # кнопка пути
        if sec["type"] in ["camp", "camp_big"]:
                start_btn.text = "ВОЙТИ В ЛАГЕРЬ «%s» →" % sec["name"].replace("ЛАГЕРЬ ", "").replace("«", "").replace("»", "")
        elif bool(G.zsave.get("campaign_won", false)):
                start_btn.text = "КАМПАНИЯ ПРОЙДЕНА"
                start_btn.disabled = true
        else:
                start_btn.text = "НАЧАТЬ ПУТЬ НА СЕВЕР (СЕКТОР %d)" % (cur + 1)

func _build_profile_chips() -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 18)
        row.position = Vector2(700, 40) + draw_off
        add_child(row)
        var alive := 0
        for s in G.zsave["squad"]:
                if s.get("alive", true):
                        alive += 1
        row.add_child(ZUI.chip("food", "ХАБАР %d" % int(G.zsave["bank"]), ZUI.WARN, 20, 14))
        row.add_child(ZUI.chip("skull", "БОИ %d" % int(G.zsave["battles"]), ZUI.MUTED, 20, 14))
        row.add_child(ZUI.chip("shield", "ПОБЕДЫ %d" % int(G.zsave["wins"]), ZUI.NEON, 20, 14))
        row.add_child(ZUI.chip("camp", "ОТРЯД %d" % alive, ZUI.TEXT, 20, 14))

func _build_buttons() -> void:
        var menu_btn := ZUI.ZButton.new("В ГЛАВНОЕ МЕНЮ", Vector2(240, 46), false, 13, "menu")
        menu_btn.position = Vector2(700, 686) + draw_off
        menu_btn.pressed.connect(func():
                if main_ref != null:
                        main_ref.to_main_menu())
        add_child(menu_btn)
        ZUI.entrance(menu_btn, 0.30, 12)
        var set_btn := ZUI.ZButton.new("НАСТРОЙКИ", Vector2(190, 46), false, 13, "gear")
        set_btn.position = Vector2(960, 686) + draw_off
        set_btn.pressed.connect(func(): _open_settings_here())
        add_child(set_btn)
        ZUI.entrance(set_btn, 0.36, 12)
        var diary_btn := ZUI.ZButton.new("АРХИВ ДНЕВНИКА", Vector2(230, 46), false, 13, "pda")
        diary_btn.position = Vector2(1170, 686) + draw_off
        diary_btn.pressed.connect(func(): _open_diary_archive())
        add_child(diary_btn)
        ZUI.entrance(diary_btn, 0.42, 12)
        var hint := ZUI.label("Кликните узел на карте — разведданные по сектору", 12, ZUI.FAINT)
        hint.position = Vector2(700, 742) + draw_off
        add_child(hint)

# ---------- архив дневника ----------
func _open_diary_archive() -> void:
        var w := ZUI.open_window(self, "ДНЕВНИК КОМАНДИРА · АРХИВ", Vector2(660, 0))
        var vb: VBoxContainer = w["vb"]
        var d: int = int(G.zsave.get("diary", 0))
        if d <= 0:
                vb.add_child(ZUI.label("Записей нет.", 14, ZUI.FAINT))
        for i in range(d, 0, -1):
                if not G.ZDIARY.has(i):
                        continue
                var ep := PanelContainer.new()
                ep.add_theme_stylebox_override("panel", ZUI.panel_style(Color(0.05, 0.062, 0.056), Color(0.16, 0.30, 0.20), 10))
                vb.add_child(ep)
                var evb := VBoxContainer.new()
                evb.add_theme_constant_override("separation", 2)
                ep.add_child(evb)
                evb.add_child(ZUI.label("ЗАПИСЬ %d" % i, 11, ZUI.NEON_DIM))
                evb.add_child(ZUI.wrap_label(G.ZDIARY[i], 13, Color(0.8, 0.84, 0.72), 560.0))
        var ok := ZUI.ZButton.new("ЗАКРЫТЬ", Vector2(220, 46), false, 14)
        ok.pressed.connect(func(): ZUI.close_window(w["overlay"]))
        var brow := HBoxContainer.new()
        brow.alignment = BoxContainer.ALIGNMENT_CENTER
        brow.add_child(ok)
        vb.add_child(brow)

# ---------- ЛАГЕРЬ (хаб между секторами) ----------
func _open_camp(big: bool) -> void:
        var w := ZUI.open_window(self, "ЛАГЕРЬ ВЫЖИВШИХ" + (" · ТОРГОВЛЯ И НАЁМ" if big else " · ПЕРЕДЫШКА"), Vector2(860, 0))
        var vb: VBoxContainer = w["vb"]
        # перевязка: полное восстановление
        var heal := ZUI.ZButton.new("ПЕРЕВЯЗАТЬ РАНЕНЫХ И ОТДЫХАТЬ (бесплатно)", Vector2(780, 54), false, 15, "medkit")
        heal.pressed.connect(func():
                G.zsave["pstate"] = Med.mk_state()
                G.zsave["infect"] = 0
                for s in G.zsave["squad"]:
                        s["alive"] = true
                G.write_save()
                G.play_sfx("capture", -10.0)
                heal.disabled = true
                heal.text = "Все перевязаны и отдохнули.")
        vb.add_child(heal)
        # бесплатные патроны (маленький лагерь — базовые)
        if not big:
                var ammo_b := ZUI.ZButton.new("ПОПОЛНИТЬ БАЗОВЫЕ ПАТРОНЫ (бесплатно)", Vector2(780, 50), false, 14, "ammo")
                ammo_b.pressed.connect(func():
                        for w2 in G.zsave["weapons"]:
                                G.zsave["ammo"][w2] = int(G.zsave["ammo"].get(w2, 0)) + 24
                        G.write_save()
                        G.play_sfx("z_pickup", -8.0)
                        ammo_b.disabled = true
                        ammo_b.text = "Патроны розданы.")
                vb.add_child(ammo_b)
        if big:
                vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                vb.add_child(ZUI.label("— ТОРГОВЕЦ: ПРОДАТЬ ХАБАР —", 14, ZUI.WARN))
                var junk := HBoxContainer.new()
                junk.add_theme_constant_override("separation", 8)
                vb.add_child(junk)
                var total := 0
                for it in G.ZLOOT:
                        var n: int = int(G.zsave["inv"].get(it, 0))
                        if n > 0:
                                total += n * int(G.ZLOOT[it]["value"])
                var sell_btn := ZUI.ZButton.new("ПРОДАТЬ ВЕСЬ ХАБАР (+%d)" % total, Vector2(380, 50), false, 14) if total > 0 else ZUI.ZButton.new("ХАБАРА НЕТ", Vector2(380, 50), false, 14)
                if total <= 0:
                        sell_btn.disabled = true
                sell_btn.pressed.connect(func():
                        var got := 0
                        for it in G.ZLOOT:
                                var n: int = int(G.zsave["inv"].get(it, 0))
                                if n > 0:
                                        got += n * int(G.ZLOOT[it]["value"])
                                        G.zsave["inv"][it] = 0
                        G.z_bank_add(got)
                        G.write_save()
                        G.play_sfx("z_pickup", -6.0)
                        ZUI.close_window(w["overlay"])
                        _open_camp(true))
                junk.add_child(sell_btn)
                vb.add_child(ZUI.label("Часы, электроника, документы — всё в дело. Тут умеют молчать.", 12, ZUI.FAINT))
                vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                vb.add_child(ZUI.label("— ТОРГОВЕЦ: ПОКУПКА —", 14, ZUI.WARN))
                var shop := GridContainer.new()
                shop.columns = 4
                shop.add_theme_constant_override("h_separation", 8)
                shop.add_theme_constant_override("v_separation", 8)
                vb.add_child(shop)
                for it in ["band", "tq", "splint", "morph", "abx", "mag_pistol", "mag_smg", "mag_rifle", "food"]:
                        var price: int = int(G.ZITEMS[it]["price"])
                        var btn := ZUI.ZButton.new("%s — %d" % [G.ZITEMS[it]["name"], price], Vector2(190, 46), false, 11)
                        btn.disabled = int(G.zsave["bank"]) < price
                        btn.pressed.connect(func():
                                if int(G.zsave["bank"]) >= price:
                                        G.zsave["bank"] = int(G.zsave["bank"]) - price
                                        G.z_give_item(it, 1)
                                        G.write_save()
                                        G.play_sfx("z_pickup", -8.0)
                                        ZUI.close_window(w["overlay"])
                                        _open_camp(true))
                        shop.add_child(btn)
                var wpn_row := HBoxContainer.new()
                wpn_row.add_theme_constant_override("separation", 8)
                vb.add_child(wpn_row)
                for wname in ["smg", "shotgun", "rifle"]:
                        var wp: int = int(G.ZWEAPONS[wname]["price"])
                        var owned: bool = wname in G.zsave["weapons"]
                        var wbtn := ZUI.ZButton.new("%s — %d" % [G.Z_WEAPON_NAMES[wname], wp], Vector2(250, 50), false, 12, "pistol")
                        if owned:
                                wbtn.disabled = true
                                wbtn.text = G.Z_WEAPON_NAMES[wname] + " — есть"
                        else:
                                wbtn.disabled = int(G.zsave["bank"]) < wp
                        wbtn.pressed.connect(func():
                                if not (wname in G.zsave["weapons"]) and int(G.zsave["bank"]) >= wp:
                                        G.zsave["bank"] = int(G.zsave["bank"]) - wp
                                        G.zsave["weapons"].append(wname)
                                        G.zsave["ammo"][wname] = int(G.zsave["ammo"].get(wname, 0)) + int(G.ZWEAPONS[wname]["mag"]) * 2
                                        G.write_save()
                                        G.play_sfx("capture", -8.0)
                                        ZUI.close_window(w["overlay"])
                                        _open_camp(true))
                        wpn_row.add_child(wbtn)
                vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
                # наём
                var hire := ZUI.ZButton.new("НАНЯТЬ БОЙЦА — 120 ХАБАРА", Vector2(780, 52), true, 15, "shield")
                if int(G.zsave["bank"]) < 120 or _squad_alive() >= 4:
                        hire.disabled = true
                        if _squad_alive() >= 4:
                                hire.text = "ОТРЯД ПОЛОН (4/4)"
                hire.pressed.connect(func():
                        if int(G.zsave["bank"]) >= 120:
                                G.zsave["bank"] = int(G.zsave["bank"]) - 120
                                G.zsave["squad"].append({"name": _new_callsign(), "alive": true})
                                G.write_save()
                                G.play_sfx("capture", -8.0)
                                ZUI.close_window(w["overlay"])
                                _open_camp(true))
                vb.add_child(hire)
        vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
        var back := ZUI.ZButton.new("ПРОДОЛЖИТЬ ПОХОД →", Vector2(340, 48), true, 14, "arrow")
        back.pressed.connect(func():
                G.play_sfx("ui_click", -6.0)
                G.zsave["sector"] = mini(int(G.zsave["sector"]) + 1, G.ZSECTORS.size())
                G.write_save()
                if main_ref != null:
                        main_ref.to_zcampaign_map()
                else:
                        ZUI.close_window(w["overlay"]))
        var brow := HBoxContainer.new()
        brow.alignment = BoxContainer.ALIGNMENT_CENTER
        brow.add_child(back)
        vb.add_child(brow)

func _new_callsign() -> String:
        var pool := ["Волк", "Аякс", "Скиф", "Бекас", "Марс", "Клык", "Тайга", "Гроза", "Норд", "Вьюн"]
        return pool[randi() % pool.size()] + "-" + str(randi() % 9 + 2)

func _squad_alive() -> int:
        var n := 0
        for s in G.zsave["squad"]:
                if s.get("alive", true):
                        n += 1
        return n

# ---------- настройки ----------
func _open_settings_here() -> void:
        var layer := CanvasLayer.new()
        layer.layer = 30
        add_child(layer)
        if main_ref == null:
                layer.queue_free()
                return
        main_ref._open_settings(layer)
        var watcher := Timer.new()
        watcher.wait_time = 0.5
        watcher.autostart = true
        watcher.timeout.connect(func():
                if is_instance_valid(layer) and layer.get_child_count() == 0:
                        layer.queue_free()
                        watcher.queue_free())
        add_child(watcher)

# ================= ОТРИСОВКА КАРТЫ СЕВЕРА =================
const BOARD := Rect2(0, 0, 620, 640)   # локальные координаты board

func _map_origin() -> Vector2:
        return Vector2(60, 560)

func _map_step() -> Vector2:
        return Vector2(25, -25)

func _draw() -> void:
        draw_set_transform(draw_off)
        var cur: int = int(G.zsave["sector"])
        # доска карты (дизайн-координаты без draw_off — его добавляет transform)
        var board_rect := Rect2(BOARD_POS, BOARD.size)
        # поле карты: заснеженная тьма
        draw_rect(board_rect.grow(8.0), Color(0.010, 0.014, 0.020, 0.85), true)
        draw_rect(board_rect, Color(0.070, 0.082, 0.098, 0.97), true)
        draw_rect(board_rect, Color(0.30, 0.40, 0.52, 0.8), false, 2.0)
        draw_rect(board_rect.grow(-7.0), Color(0.24, 0.32, 0.44, 0.5), false, 1.0)
        for c in [board_rect.position, Vector2(board_rect.end.x, board_rect.position.y), Vector2(board_rect.position.x, board_rect.end.y), board_rect.end]:
                draw_circle(c, 4.0, Color(0.45, 0.56, 0.70, 0.85))
        # сетка координат
        for gx in range(1, 8):
                var x: float = board_rect.position.x + board_rect.size.x * gx / 8.0
                draw_line(Vector2(x, board_rect.position.y), Vector2(x, board_rect.end.y), Color(0.36, 0.46, 0.60, 0.15), 1.0)
                draw_string(ThemeDB.fallback_font, Vector2(x - 5.0, board_rect.position.y + 18.0), str(char(64 + gx)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.48, 0.58, 0.72, 0.8))
        for gy in range(1, 8):
                var y: float = board_rect.position.y + board_rect.size.y * gy / 8.0
                draw_line(Vector2(board_rect.position.x, y), Vector2(board_rect.end.x, y), Color(0.36, 0.46, 0.60, 0.15), 1.0)
                draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x + 8.0, y - 3.0), "%02d" % gy, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.48, 0.58, 0.72, 0.8))
        # рельеф: заснеженные гряды
        for contour in range(15):
                var center := Vector2(board_rect.position.x + 115.0 + float(contour % 4) * 135.0, board_rect.position.y + 190.0 + float(floori(float(contour) / 4.0)) * 155.0)
                var radius := 27.0 + float(contour % 3) * 12.0
                var pts := PackedVector2Array()
                for pi in range(33):
                        var ang := TAU * float(pi) / 32.0
                        var mr := radius + 4.0 * sin(ang * 3.0 + float(contour)) + 2.5 * cos(ang * 5.0)
                        pts.append(center + Vector2.from_angle(ang) * mr)
                draw_polyline(pts, Color(0.52, 0.62, 0.78, 0.30), 1.0, true)
        # компас
        var compass := Vector2(board_rect.end.x - 34.0, board_rect.position.y + 42.0)
        draw_arc(compass, 18.0, 0.0, TAU, 24, Color(0.62, 0.72, 0.86, 0.7), 1.0)
        draw_line(compass + Vector2(0, 12), compass + Vector2(0, -15), ZUI.ALERT, 2.0)
        draw_colored_polygon(PackedVector2Array([compass + Vector2(0, -16), compass + Vector2(-4, -7), compass + Vector2(4, -7)]), ZUI.ALERT)
        draw_string(ThemeDB.fallback_font, compass + Vector2(-4, -22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.86, 0.95))
        # позиции узлов (локальные координаты board → дизайн-координаты)
        node_positions.clear()
        for i in range(G.ZSECTORS.size()):
                node_positions.append(_map_origin() + _map_step() * i + Vector2(sin(i * 1.1) * 20.0, 0))
        # маршрут
        if cur > 0:
                var done := PackedVector2Array()
                for i in range(mini(cur + 1, node_positions.size())):
                        done.append(BOARD_POS + (node_positions[i] as Vector2))
                draw_polyline(done, Color(0.45, 0.85, 0.55, 0.8), 3.0)
        var ahead := PackedVector2Array()
        for i in range(mini(cur, node_positions.size()), node_positions.size()):
                ahead.append(BOARD_POS + (node_positions[i] as Vector2))
        if ahead.size() >= 2:
                _draw_dashed(ahead, Color(0.55, 0.65, 0.85, 0.55), 2.0, 12.0)
        # узлы
        for i in range(G.ZSECTORS.size()):
                var pos: Vector2 = BOARD_POS + (node_positions[i] as Vector2)
                var sec: Dictionary = G.ZSECTORS[i]
                var passed: bool = i < cur
                var is_cur: bool = i == cur
                var sel: bool = (sel_idx == i) or (sel_idx < 0 and is_cur)
                var base_col := Color(0.32, 0.38, 0.46)
                if passed:
                        base_col = Color(0.42, 0.68, 0.45)
                elif sec["type"] in ["camp", "camp_big"]:
                        base_col = Color(0.72, 0.62, 0.32)
                elif sec["type"] == "final":
                        base_col = Color(0.72, 0.36, 0.32)
                var r := 10.0
                if sec["type"] in ["camp", "camp_big"]:
                        draw_rect(Rect2(pos.x - r, pos.y - r, r * 2, r * 2), Color(base_col.r, base_col.g, base_col.b, 0.92), true)
                        draw_rect(Rect2(pos.x - r, pos.y - r, r * 2, r * 2), Color(0.10, 0.12, 0.14), false, 1.5)
                else:
                        var diamond := PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)])
                        draw_colored_polygon(diamond, Color(base_col.r, base_col.g, base_col.b, 0.92))
                        draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0.10, 0.12, 0.14), 1.5)
                if sel:
                        draw_arc(pos, r + 4.0, 0, TAU, 20, ZUI.TEXT, 2.0)
                if is_cur and not bool(G.zsave.get("campaign_won", false)):
                        var pulse: float = 0.6 + 0.4 * sin(time_t * 4.5)
                        draw_arc(pos, r + 6.0 + pulse * 3.0, 0, TAU, 24, Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.9), 2.5)
                        # «ДОСТУПНАЯ ТОЧКА»
                        draw_string(ThemeDB.fallback_font, pos + Vector2(-40, r + 26), "ДОСТУПНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.85))
                draw_string(ThemeDB.fallback_font, pos + Vector2(-4, -r - 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.88, 0.95) if not passed else Color(0.5, 0.75, 0.5))
                var label: String = sec["name"].substr(0, 20)
                if pos.x - BOARD_POS.x > 260.0:
                        draw_string(ThemeDB.fallback_font, pos + Vector2(-152.0, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.56, 0.64, 0.78))
                else:
                        draw_string(ThemeDB.fallback_font, pos + Vector2(16, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.56, 0.64, 0.78))
        # метки севера/юга
        var north: Vector2 = BOARD_POS + (node_positions[node_positions.size() - 1] as Vector2) + Vector2(-80, -30)
        draw_string(ThemeDB.fallback_font, north, "СЕВЕРНЫЙ БУНКЕР", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.55, 0.45))
        var south: Vector2 = BOARD_POS + (node_positions[0] as Vector2) + Vector2(16, 26)
        draw_string(ThemeDB.fallback_font, south, "БУНКЕР «ЗАРЯ» — ОТСЮДА ВСЁ НАЧАЛОСЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.6, 0.72))
        draw_string(ThemeDB.fallback_font, BOARD_POS + Vector2(12, 22), "РАЗВЕДКАРТА СЕВЕРА  /  КООРДИНАТЫ НЕТОЧНЫ  /  УЗЕЛ %02d ИЗ 20" % (cur + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.72, 0.86))

func _draw_dashed(pts: PackedVector2Array, col: Color, width: float, dash: float) -> void:
        for i in range(pts.size() - 1):
                var a := pts[i]
                var b := pts[i + 1]
                var seg := a.distance_to(b)
                var n: int = int(seg / dash)
                for j in range(0, n, 2):
                        var t0: float = j * dash / maxf(1.0, seg)
                        var t1: float = minf(1.0, (j + 1) * dash / maxf(1.0, seg))
                        draw_line(a.lerp(b, t0), a.lerp(b, t1), col, width)

func _process(delta: float) -> void:
        time_t += delta
        queue_redraw()
