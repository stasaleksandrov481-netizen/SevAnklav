# ============================================================
# КАРТА КАМПАНИИ (глобальная, в стиле Barotrauma по ТЗ 4.1)
# 20 секторов с юга на север к Объекту «Заря», база между боями:
# трофеи, улучшения армии, разведданные о следующем секторе.
# ============================================================
extends Control

var main_ref = null
var sel_upgrade := ""
var time_t := 0.0
var draw_off := Vector2.ZERO   # центрирование макета 1600x900 на широких экранах

func _fit_design() -> void:
        # экран рисован под холст 1600x900: на других соотношениях сжимаем
        # всю сцену пропорционально и центрируем — ничего не обрезается
        var vs := get_viewport_rect().size
        var k := maxf(0.5, minf(vs.x / 1600.0, vs.y / 900.0))
        scale = Vector2(k, k)
        var design := vs / k
        draw_off = Vector2(maxf(0.0, (design.x - 1600.0) * 0.5), maxf(0.0, (design.y - 900.0) * 0.5))

# ---------- улучшения ----------
const UPGRADES := [
        {"id": "logistics", "name": "ЛОГИСТИКА", "desc": "+15% к доходу реквизиции за уровень (до III)", "costs": [600, 900, 1300]},
        {"id": "scouts", "name": "РАЗВЕДРОТА", "desc": "Бесплатная разведмашина в начале каждого боя", "costs": [500]},
        {"id": "repair", "name": "РЕМРОТА", "desc": "Техника прибывает с полным ремонтом, аура ремонта сильнее", "costs": [700]},
        {"id": "prep", "name": "АРТПОДГОТОВКА", "desc": "Бесплатный артналёт в начале каждого боя", "costs": [800]},
        {"id": "trophy", "name": "ТРОФЕЙЩИКИ", "desc": "+10% реквизиции с уничтоженной техники врага", "costs": [500]},
]

const TYPE_DESC := {
        "outpost": "Блокпост: укреплённая застава на дороге.",
        "town": "ПГТ: городская застройка, бои в узких улицах.",
        "industrial": "Промзона: заводы и цистерны, много укрытий.",
        "forest": "Лесной массив: засады, ограниченная видимость.",
        "river": "Река: переправа возможна только по мостам.",
        "field": "Открытое поле: танковые дуэли на больших дистанциях.",
        "airbase": "Военный аэродром: захвати его — получишь вертолёты.",
        "final": "ОБЪЕКТ «ЗАРЯ»: последний рубеж. Всё или ничего.",
}

func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _fit_design()
        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = UiKit.BG
        add_child(bg)
        # живой топографический фон
        var topo := ColorRect.new()
        topo.set_anchors_preset(Control.PRESET_FULL_RECT)
        topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        topo.material = UiKit.make_topo_material()
        add_child(topo)
        root_vignette = UiKit.make_vignette(0.45)
        add_child(root_vignette)
        # заголовок
        var title_block := VBoxContainer.new()
        title_block.position = Vector2(30, 14) + draw_off
        title_block.add_theme_constant_override("separation", 4)
        add_child(title_block)
        var over := UiKit.label("— ШТАБ ГРУППИРОВКИ —", 13, UiKit.FAINT)
        title_block.add_child(over)
        var title := UiKit.label("КАРТА КАМПАНИИ", 34, UiKit.AMBER_BRIGHT)
        title_block.add_child(title)
        var tdiv := UiKit.hdivider()
        tdiv.custom_minimum_size = Vector2(260, 2)
        title_block.add_child(tdiv)
        UiKit.entrance(title_block, 0.05, 16)
        # профиль командира
        _build_commander_panel()
        # штурм
        var start_btn := UiKit.MilButton.new("НАЧАТЬ ШТУРМ СЕКТОРА %d →" % (G.save["sector"] + 1), Vector2(400, 58), true, 18)
        start_btn.position = Vector2(680, 776) + draw_off
        start_btn.pressed.connect(func():
                G.play_sfx("ui_click", -6.0)
                if main_ref != null:
                        main_ref.start_battle())
        add_child(start_btn)
        UiKit.entrance(start_btn, 0.25, 14)
        var menu_btn := UiKit.MilButton.new("В ГЛАВНОЕ МЕНЮ", Vector2(230, 46), false, 13)
        menu_btn.position = Vector2(1100, 782) + draw_off
        menu_btn.pressed.connect(func():
                if main_ref != null:
                        main_ref.to_main_menu())
        add_child(menu_btn)
        UiKit.entrance(menu_btn, 0.32, 14)
        var set_btn := UiKit.MilButton.new("НАСТРОЙКИ", Vector2(180, 46), false, 13)
        set_btn.position = Vector2(1346, 782) + draw_off
        set_btn.pressed.connect(func(): _open_settings_here())
        add_child(set_btn)
        UiKit.entrance(set_btn, 0.39, 14)
        # кампания пройдена?
        if G.save.get("campaign_won", false):
                var won := UiKit.label("ОБЪЕКТ «ЗАРЯ» ВЗЯТ — КАМПАНИЯ ПРОЙДЕНА. МОЖНО ПРОЙТИ ЗАНОВО С ЛЮБОЙ ФРАКЦИЕЙ.", 16, UiKit.AMBER_BRIGHT)
                won.position = Vector2(30, 88) + draw_off
                add_child(won)

var root_vignette: Control = null

# настройки прямо из штаба (окно по центру)
func _open_settings_here() -> void:
        var layer := CanvasLayer.new()
        layer.layer = 30
        add_child(layer)
        var main_node = main_ref
        if main_node == null:
                layer.queue_free()
                return
        main_node._open_settings(layer)
        # когда окно закроют — убираем слой (проверяем каждый кадр)
        var watcher := Timer.new()
        watcher.wait_time = 0.5
        watcher.autostart = true
        watcher.timeout.connect(func():
                if is_instance_valid(layer) and layer.get_child_count() == 0:
                        layer.queue_free()
                        watcher.queue_free())
        add_child(watcher)

func _build_commander_panel() -> void:
        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_DIM, UiKit.BORDER, 18))
        panel.position = Vector2(680, 92) + draw_off
        panel.custom_minimum_size = Vector2(560, 660)
        add_child(panel)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        panel.add_child(vb)
        # профиль
        var prof := UiKit.label("КОМАНДИР: %s\nГРУППИРОВКА: %s\nДОПУСК: %s   ·   СЕКТОР: %d из 20\nТРОФЕЙНАЯ РЕКВИЗИЦИЯ: %d\nПОТЕРИ КАМПАНИИ (ПЕРМАСМЕРТЬ): %d   ·   УНИЧТОЖЕНО ПРОТИВНИКА: %d" % [
                G.save["commander"], G.FACTION_NAMES[G.save["faction"]],
                G.DIFFICULTY[G.save["difficulty"]]["name"], G.save["sector"] + 1, G.save["bank"],
                int(G.save.get("total_losses", 0)), int(G.save.get("total_kills", 0))], 15, UiKit.TEXT)
        vb.add_child(prof)
        # разведданные о секторе
        var sec: Dictionary = G.SECTORS[G.save["sector"]]
        var intel := UiKit.label("— РАЗВЕДДАННЫЕ —\nСЛЕДУЮЩИЙ СЕКТОР: %s\n%s\nОЖИДАЕМЫЙ ПРОТИВНИК: %s" % [
                sec["name"], TYPE_DESC.get(sec["type"], ""), G.FACTION_NAMES[sec["enemy"]]], 14, Color(0.78, 0.8, 0.68))
        if sec["type"] == "airbase" and not G.save["heli_unlocked"]:
                intel.text += "\n\n★ ЗАХВАТИТЕ АЭРОДРОМ — ВЫ ПОЛУЧИТЕ УДАРНЫЕ ВЕРТОЛЁТЫ!"
        intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        intel.custom_minimum_size = Vector2(520, 0)
        vb.add_child(intel)
        # улучшения
        vb.add_child(UiKit.label("— БАЗА: УЛУЧШЕНИЯ ГРУППИРОВКИ —", 15, UiKit.AMBER_BRIGHT))
        for up in UPGRADES:
                vb.add_child(_upgrade_row(up))
        vb.add_child(UiKit.label("Совет: берите ПВО против вертолётов противника,\nартиллерии нужен корректировщик-разведчик.", 12, UiKit.MUTED))

func _mk_label(text: String, size: int, col: Color) -> Label:
        var l := UiKit.label(text, size, col)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(520, 0)
        return l

func _upgrade_row(up: Dictionary) -> Control:
        var hb := HBoxContainer.new()
        hb.add_theme_constant_override("separation", 10)
        var lvl := 0
        var maxed := false
        if up["id"] == "logistics":
                lvl = int(G.save["upgrades"].get("logistics", 0))
                maxed = lvl >= 3
        else:
                maxed = bool(G.save["upgrades"].get(up["id"], false))
        var lvl_txt := " (%d/3)" % lvl if up["id"] == "logistics" else (" [ЕСТЬ]" if maxed else "")
        var name_l := UiKit.label(up["name"] + lvl_txt, 14, UiKit.TEXT)
        name_l.custom_minimum_size = Vector2(170, 0)
        hb.add_child(name_l)
        var cost := 0
        if not maxed:
                var arr: Array = up["costs"]
                cost = arr[mini(lvl, arr.size() - 1)]
        var desc_l := UiKit.label(up["desc"] if not maxed else "Куплено", 11, UiKit.MUTED)
        desc_l.custom_minimum_size = Vector2(240, 0)
        desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hb.add_child(desc_l)
        var btn := UiKit.MilButton.new("—" if maxed else "%d ркз" % cost, Vector2(110, 34), false, 12)
        if maxed:
                btn.disabled = true
        else:
                btn.disabled = int(G.save["bank"]) < cost
        btn.pressed.connect(func(): _buy_upgrade(up, cost))
        hb.add_child(btn)
        return hb

func _buy_upgrade(up: Dictionary, cost: int) -> void:
        if int(G.save["bank"]) < cost:
                return
        G.save["bank"] -= cost
        if up["id"] == "logistics":
                G.save["upgrades"]["logistics"] = int(G.save["upgrades"].get("logistics", 0)) + 1
        else:
                G.save["upgrades"][up["id"]] = true
        G.write_save()
        G.play_sfx("capture", -8.0)
        # перерисовать панель
        for c in get_children():
                if c is PanelContainer:
                        c.queue_free()
        _build_commander_panel()

# ================= ОТРИСОВКА КАРТЫ СЕКТОРОВ (штабная доска) =================
func _map_origin() -> Vector2:
        return Vector2(70, 830)

func _map_step() -> Vector2:
        return Vector2(27, -36)

func _draw() -> void:
        draw_set_transform(draw_off)   # весь штабной планшет — с центрирующим сдвигом
        var origin := _map_origin()
        var step := _map_step()
        var board := Rect2(40, 130, 620, 730)
        # рамка планшета с уголками
        draw_rect(board, Color(0.07, 0.075, 0.06, 0.85), true)
        draw_rect(board, UiKit.BORDER, false, 2.0)
        for c in [board.position, Vector2(board.end.x, board.position.y),
                        Vector2(board.position.x, board.end.y), board.end]:
                draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), UiKit.AMBER, false, 2.0)
        # сетка координат
        for gx in range(1, 8):
                var x: float = board.position.x + board.size.x * gx / 8.0
                draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), Color(0.35, 0.38, 0.3, 0.22), 1.0)
        for gy in range(1, 8):
                var y: float = board.position.y + board.size.y * gy / 8.0
                draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), Color(0.35, 0.38, 0.3, 0.22), 1.0)
        # условные горизонтали рельефа
        var tseed := 3.1
        for band in range(7):
                var yy: float = board.position.y + 80 + band * 92
                var col := Color(0.3, 0.36, 0.27, 0.16)
                draw_arc(Vector2(board.position.x + 100 + sin(band * 1.7 + tseed) * 40, yy + 260),
                        190 + band * 26, PI + 0.4, TAU - 0.2, 40, col, 1.2)
        # река (синяя излучена)
        var river := PackedVector2Array()
        for i in range(9):
                var k: float = i / 8.0
                river.append(Vector2(board.position.x + 430 + sin(k * 4.0) * 34,
                        board.position.y + 40 + k * (board.size.y - 80)))
        draw_polyline(river, Color(0.25, 0.33, 0.4, 0.5), 7.0)
        draw_polyline(river, Color(0.35, 0.45, 0.52, 0.35), 3.0)
        # маршрут: линия фронта с юга на север
        var pts := PackedVector2Array()
        var positions: Array = []
        for i in range(G.SECTORS.size()):
                var pos: Vector2 = origin + step * i + Vector2(sin(i * 1.1) * 26.0, 0)
                positions.append(pos)
                pts.append(pos)
        # пройденный путь — зелёный, впереди — пунктир
        var cur: int = int(G.save["sector"])
        if cur > 0:
                var done := PackedVector2Array()
                for i in range(cur + 1):
                        done.append(positions[i])
                draw_polyline(done, Color(0.4, 0.6, 0.4, 0.75), 3.0)
        var ahead := PackedVector2Array()
        for i in range(cur, G.SECTORS.size()):
                ahead.append(positions[i])
        draw_dashed_polyline(ahead, Color(0.55, 0.58, 0.45, 0.6), 2.0, 12.0)
        # стрелка «СЕВЕР»
        var arrow_base := Vector2(board.end.x - 46, board.position.y + 78)
        draw_line(arrow_base, arrow_base + Vector2(0, 44), Color(0.7, 0.74, 0.6, 0.8), 2.0)
        draw_polyline(PackedVector2Array([arrow_base + Vector2(-7, 10), arrow_base, arrow_base + Vector2(7, 10)]),
                Color(0.7, 0.74, 0.6, 0.8), 2.0)
        draw_string(ThemeDB.fallback_font, arrow_base + Vector2(-16, 62), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.75, 0.6))
        # узлы секторов
        for i in range(G.SECTORS.size()):
                var pos: Vector2 = positions[i]
                var sec: Dictionary = G.SECTORS[i]
                var passed: bool = i < cur
                var is_cur: bool = i == cur
                var base_col := Color(0.36, 0.4, 0.32)
                if passed:
                        base_col = Color(0.42, 0.62, 0.42)
                elif sec["enemy"] == "jack":
                        base_col = Color(0.72, 0.6, 0.25)
                # ромб
                var r := 11.0
                var diamond := PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)])
                draw_colored_polygon(diamond, Color(base_col.r, base_col.g, base_col.b, 0.92))
                draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
                        Color(0.16, 0.18, 0.14), 1.5)
                if is_cur:
                        var pulse: float = 0.6 + 0.4 * sin(time_t * 4.5)
                        draw_arc(pos, r + 6.0 + pulse * 3.0, 0, TAU, 24, Color(0.95, 0.8, 0.35, 0.9), 2.5)
                        draw_arc(pos, r + 12.0, 0, TAU, 24, Color(0.95, 0.8, 0.35, 0.3 * pulse), 1.5)
                # номер
                draw_string(ThemeDB.fallback_font, pos + Vector2(-4, -r - 5), str(i + 1),
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.86, 0.75) if not passed else Color(0.55, 0.75, 0.55))
                # подпись
                var label: String = sec["name"].substr(0, 21)
                if pos.x > 470.0:
                        draw_string(ThemeDB.fallback_font, pos + Vector2(-150.0, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.65, 0.55))
                else:
                        draw_string(ThemeDB.fallback_font, pos + Vector2(17, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.65, 0.55))
        # штаб врага
        var north: Vector2 = positions[positions.size() - 1] + Vector2(-92, -34)
        draw_string(ThemeDB.fallback_font, north, "ОБЪЕКТ «ЗАРЯ»", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.55, 0.4))
        # старт
        var south: Vector2 = positions[0] + Vector2(16, 28)
        draw_string(ThemeDB.fallback_font, south, "ТОЧКА ВТОРЖЕНИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.62, 0.5))
        # прогноз погоды/время (атмосферный штрих)
        draw_string(ThemeDB.fallback_font, Vector2(52, 152), "ОПЕРКАРТА · СЕКТОР %d/20 · ЯСНО, ВЕТЕР СЗ 6 М/С" % (cur + 1),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.55, 0.45))

func draw_dashed_polyline(pts: PackedVector2Array, col: Color, width: float, dash: float) -> void:
        for i in range(pts.size() - 1):
                var a := pts[i]
                var b := pts[i + 1]
                var seg := a.distance_to(b)
                var n: int = int(seg / dash)
                for j in range(0, n, 2):
                        var t0: float = j * dash / maxf(1.0, seg)
                        var t1: float = minf(1.0, (j + 1) * dash / maxf(1.0, seg))
                        draw_line(a.lerp(b, t0), a.lerp(b, t1), col, width)
