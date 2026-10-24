# ============================================================
# ZMEDUI — МЕДИЦИНСКОЕ ОКНО И ИНВЕНТАРЬ (Barotrauma-стиль)
# Отдельный модуль (по ТЗ №1). Слева — анатомическая кукла тела
# (голова, торс, руки, ноги) с SVG-индикаторами травм:
#   SVG-КАПЛЯ  — активное кровотечение
#   SVG-КОСТЬ  — перелом
#   SVG-ШПРИЦ  — заражение (биореакция)
# Справа — сетка инвентаря с drag-and-drop: предмет тащится
# на зону тела (подсветка слотов и зон), либо выбирается тапом.
# Лут-окно: строки лута перетаскиваются в рюкзак или берутся кнопкой.
# Логика лечения — med.gd, применение — battle_z.gd (med_apply_zone).
# ============================================================
class_name ZMedUI

const ZONES := ["head", "torso", "la", "ra", "ll", "rl"]

# прямоугольники зон на кукле (холст 250x340)
const ZR := {
        "head": Rect2(96, 8, 58, 58),
        "torso": Rect2(82, 74, 86, 118),
        "la": Rect2(34, 78, 40, 110),
        "ra": Rect2(176, 78, 40, 110),
        "ll": Rect2(82, 202, 40, 120),
        "rl": Rect2(128, 202, 40, 120),
}

# ---------- иконки предметов (спрайты игры, фолбэк — SVG) ----------
static func item_icon(item: String) -> Texture2D:
        var spr := G.tex("z_i_" + item)
        if spr != null:
                return spr
        match item:
                "band": return ZUI.icon("bandage")
                "tq": return ZUI.icon("bandage")
                "morph": return ZUI.icon("syringe")
                "abx": return ZUI.icon("medkit")
                "keycard": return ZUI.icon("keycard")
                "food": return ZUI.icon("food")
        return ZUI.icon("bag")

static func item_name(item: String) -> String:
        if G.ZITEMS.has(item):
                return str(G.ZITEMS[item]["name"])
        if item == "keycard":
                return "КЛЮЧ-КАРТА"
        return item.to_upper()

# ---------- открытие окна ----------
static func open(btl) -> void:
        if btl.med_win != null and is_instance_valid(btl.med_win):
                return
        btl.paused = true
        var w := ZUI.open_window(btl.ui_layer, "ВОЛКОВ / СОСТОЯНИЕ ОРГАНИЗМА", Vector2(1000, 0))
        btl.med_win = w["overlay"]
        var vb: VBoxContainer = w["vb"]
        btl.med_win.tree_exiting.connect(func(): _med_closed(btl))
        # строка статус-чипов (SVG)
        vb.add_child(_status_row(btl))
        vb.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
        # основная строка: кукла + осмотр | инвентарь
        var main_row := HBoxContainer.new()
        main_row.add_theme_constant_override("separation", 18)
        vb.add_child(main_row)
        # --- левая колонка: тело ---
        var left := VBoxContainer.new()
        left.add_theme_constant_override("separation", 6)
        main_row.add_child(left)
        var doll := BodyDoll.new()
        doll.btl = btl
        doll.custom_minimum_size = Vector2(250, 340)
        left.add_child(doll)
        var inspect := PanelContainer.new()
        inspect.custom_minimum_size = Vector2(250, 118)
        inspect.add_theme_stylebox_override("panel", ZUI.panel_style(Color(0.05, 0.06, 0.055, 0.92), ZUI.BORDER_SOFT, 8))
        left.add_child(inspect)
        var ivb := VBoxContainer.new()
        ivb.add_theme_constant_override("separation", 3)
        inspect.add_child(ivb)
        var info_lbl := ZUI.wrap_label(_default_info(btl), 12, ZUI.TEXT, 210.0)
        info_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
        ivb.add_child(info_lbl)
        # --- правая колонка: инвентарь ---
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
        var tl := ZUI.label("РЮКЗАК — ячейки: на тело, между собой или в быстрые слоты", 14, ZUI.NEON_BRIGHT)
        tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(tl)
        right.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
        # FIX7v2: сетка-ячейки как в Майнкрафте + строка быстрых слотов внутри окна
        var grid_wrap := InvGrid.new()
        grid_wrap.btl = btl
        grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        right.add_child(grid_wrap)
        grid_wrap.add_child(build_inv_grid(btl))
        # подсказка
        var hint_l := ZUI.wrap_label("Перетащите предмет: на другую ячейку — поменять местами; на куклу тела — лечение; в БЫСТРЫЕ СЛОТЫ — закрепить внизу экрана. Лут из окна обыска бросайте в сетку. Магазины: тап — патроны в запас.", 12, ZUI.FAINT, 560.0)
        right.add_child(hint_l)
        # кнопка закрыть
        var brow := HBoxContainer.new()
        brow.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(brow)
        var close := ZUI.ZButton.new("ВЕРНУТЬСЯ В БОЙ", Vector2(300, 48), false, 14)
        close.pressed.connect(func():
                G.play_sfx("ui_click", -8.0)
                ZUI.close_window(btl.med_win))
        brow.add_child(close)
        # регистрируем ссылки для обновлений
        btl._med_doll = doll
        btl._med_info_lbl = info_lbl
        _refresh_delayed(btl)

static func _refresh_delayed(btl) -> void:
        # кукла перерисуется сама в _draw каждый кадр (queue_redraw в _process)
        pass

static func _default_info(btl) -> String:
        if str(btl._med_sel_item) != "":
                return "%s выбран. Нажмите на повреждённую зону тела или перетащите предмет на неё." % item_name(str(btl._med_sel_item))
        return "Нажмите на часть тела для осмотра. SVG-метки: капля — кровотечение, кость — перелом, шприц — заражение."

static func _med_closed(btl) -> void:
        btl.med_win = null
        btl.paused = false

static func refresh(btl) -> void:
        # пересоздание окна (после применения предмета) — только если было открыто
        if btl.med_win != null and is_instance_valid(btl.med_win):
                ZUI.close_window(btl.med_win)
                btl.med_win = null
                btl.paused = false
                open(btl)

# ---------- строка SVG-чипов статуса ----------
static func _status_row(btl) -> Control:
        var st: Dictionary = btl.player["st"]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 16)
        # средняя целость
        var avg := 0.0
        for z in ZONES:
                avg += float(st["body"][z])
        avg /= ZONES.size()
        row.add_child(ZUI.chip("heart", "ЦЕЛОСТЬ %d%%" % roundi(avg * 100.0), ZUI.NEON if avg > 0.6 else ZUI.WARN if avg > 0.3 else ZUI.ALERT, 22, 14))
        # кровотечения
        var bleeds := 0
        for w in st["wounds"]:
                if int(w["bleed"]) > 0 and not w["tq"] and not w["clamp"]:
                        bleeds += int(w["bleed"])
        if bleeds > 0:
                row.add_child(ZUI.chip("drop", "КРОВЬ x%d" % bleeds, ZUI.ALERT, 22, 14))
        else:
                row.add_child(ZUI.chip("drop", "кровь остановлена", ZUI.FAINT, 22, 12))
        # переломы
        if not st["frac"].is_empty():
                row.add_child(ZUI.chip("bone", "ПЕРЕЛОМ: %s" % str(st["frac"][0]).to_upper(), ZUI.WARN, 22, 14))
        else:
                row.add_child(ZUI.chip("bone", "костей целы", ZUI.FAINT, 22, 12))
        # заражение + температура
        var infect: float = float(btl.player["infect"])
        if infect > 0.5:
                row.add_child(ZUI.chip("syringe", "ЗАРАЖЕНИЕ %d%%" % int(infect), ZUI.NEON_DIM if infect < 40 else ZUI.WARN, 22, 14))
        if infect > 28.0:
                var temp := 36.6 + (infect / 100.0) * 2.4
                row.add_child(ZUI.chip("thermo", "ТЕМП. %.1f°" % temp, ZUI.WARN, 22, 14))
        return row

# ============================================================
# ANATOMY DOLL — визуальное окно анатомии тела
# ============================================================
class BodyDoll extends Control:
        var btl = null
        var pulse_t := 0.0

        func _ready() -> void:
                mouse_filter = Control.MOUSE_FILTER_STOP
                set_process(true)

        func _process(delta: float) -> void:
                pulse_t += delta
                queue_redraw()

        func _zone_at(p: Vector2) -> String:
                for z in ZR:
                        if (ZR[z] as Rect2).has_point(p):
                                return z
                return ""

        func _gui_input(ev: InputEvent) -> void:
                if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
                        var zone := _zone_at((ev as InputEventMouseButton).position)
                        if zone != "" and btl != null:
                                if str(btl._med_sel_item) == "":
                                        btl._inspect_zone(zone)
                                else:
                                        btl.med_apply_zone(zone)

        # ---------- DRAG & DROP: предмет на зону ----------
        func _can_drop_data(at: Vector2, data) -> bool:
                if not (data is Dictionary) or not data.has("item"):
                        return false
                if str(data.get("kind", "")) != "med_item":
                        return false
                return _zone_at(at) != ""

        func _drop_data(at: Vector2, data) -> void:
                var zone := _zone_at(at)
                if zone == "":
                        return
                btl._med_sel_item = str(data["item"])
                if btl._med_info_lbl != null and is_instance_valid(btl._med_info_lbl):
                        (btl._med_info_lbl as Label).text = ZMedUI._default_info(btl)
                btl.med_apply_zone(zone)

        func _draw() -> void:
                if btl == null:
                        return
                var st: Dictionary = btl.player["st"]
                var dragging: bool = get_viewport().gui_is_dragging()
                var drag_data = get_viewport().gui_get_drag_data() if dragging else null
                var drag_item := ""
                if drag_data is Dictionary and str(drag_data.get("kind", "")) == "med_item":
                        drag_item = str(drag_data["item"])
                # фон
                draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.062, 0.058, 0.92), true)
                draw_rect(Rect2(Vector2.ZERO, size), ZUI.BORDER_SOFT, false, 1.5)
                # силуэт-подложка
                draw_rect(Rect2(110, 66, 30, 10), Color(0.14, 0.15, 0.145, 0.9), true)   # шея
                # зоны
                for z in ZR:
                        var r: Rect2 = ZR[z]
                        var integrity: float = float(st["body"][z])
                        var base := Color(0.15 + integrity * 0.15, 0.30 + integrity * 0.28, 0.36 + integrity * 0.30)
                        if integrity < 0.5:
                                base = Color(0.60, 0.24 + integrity * 0.2, 0.20)
                        var fill := Color(base.r, base.g, base.b, 0.62 + integrity * 0.25)
                        # подсветка при перетаскивании: раненые зоны пульсируют
                        if dragging and drag_item != "":
                                var wounded := _zone_needs(z, st, drag_item)
                                if wounded:
                                        var pk := 0.5 + 0.5 * sin(pulse_t * 6.0)
                                        fill = Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.35 + 0.3 * pk)
                        _draw_anatomy(z,r,fill)
                        draw_string(ThemeDB.fallback_font,r.position+Vector2(5,r.size.y-7),"%d%%" % int(integrity*100),HORIZONTAL_ALIGNMENT_LEFT,-1,10,ZUI.ICE)
                        # зона под курсором при drag — неоновая рамка
                        if dragging and drag_item != "" and r.has_point(get_local_mouse_position()):
                                draw_rect(r.grow(3), ZUI.NEON_BRIGHT, false, 2.5)
                        # имя зоны
                        draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 13), btl.Med.ZONE_RU[z], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.88, 0.9, 0.85, 0.7))
                        # SVG-индикаторы травм (правый верх зоны)
                        var icon_pos := Vector2(r.end.x - 20.0, r.position.y + 2.0)
                        var bleeding := false
                        var tq_on := false
                        for w in st["wounds"]:
                                if w["zone"] == z and int(w["bleed"]) > 0:
                                        if w["tq"] or w["clamp"]:
                                                tq_on = true
                                        else:
                                                bleeding = true
                        if bleeding:
                                var ik := ZUI.icon("drop")
                                if ik != null:
                                        var pk2 := 0.75 + 0.25 * sin(pulse_t * 5.0)
                                        draw_texture_rect(ik, Rect2(icon_pos, Vector2(19, 19)), false, Color(1.0, 0.35, 0.3, pk2))
                        elif tq_on:
                                var ik2 := ZUI.icon("bandage")
                                if ik2 != null:
                                        draw_texture_rect(ik2, Rect2(icon_pos, Vector2(19, 19)), false, ZUI.NEON_BRIGHT)
                        if st["frac"].has(z):
                                var ik3 := ZUI.icon("bone")
                                if ik3 != null:
                                        draw_texture_rect(ik3, Rect2(icon_pos + Vector2(-21, 0), Vector2(19, 19)), false, ZUI.WARN)
                # глобальный значок заражения (шприц) слева внизу
                var infect: float = float(btl.player["infect"])
                if infect > 0.5:
                        var ik4 := ZUI.icon("syringe")
                        if ik4 != null:
                                var pk3 := 0.6 + 0.4 * sin(pulse_t * 3.0)
                                draw_texture_rect(ik4, Rect2(Vector2(10, size.y - 30), Vector2(22, 22)), false, Color(ZUI.WARN.r, ZUI.WARN.g, ZUI.WARN.b, pk3))
                                draw_string(ThemeDB.fallback_font, Vector2(36, size.y - 14), "биореакция %d%%" % int(infect), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ZUI.WARN)
                # пульс-виньетка при высоком заражении
                if infect > 30.0:
                        var pulse: float = 0.5 + 0.5 * sin(pulse_t * 3.5)
                        draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.75, 0.35, 0.04 + 0.05 * pulse), true)

        func _draw_anatomy(zone: String, r: Rect2, fill: Color) -> void:
                var pts := PackedVector2Array()
                if zone == "head":
                        for i in range(32):
                                var a := float(i)/32.0*TAU
                                pts.append(r.get_center()+Vector2(cos(a)*r.size.x*0.43,sin(a)*r.size.y*0.48))
                elif zone == "torso":
                        for v in [Vector2(0.18,0),Vector2(0.82,0),Vector2(1,0.18),Vector2(0.82,0.6),Vector2(0.76,1),Vector2(0.24,1),Vector2(0.18,0.6),Vector2(0,0.18)]:
                                pts.append(r.position+v*r.size)
                else:
                        for v in [Vector2(0.3,0),Vector2(0.7,0),Vector2(0.88,0.15),Vector2(0.7,0.95),Vector2(0.3,1),Vector2(0.16,0.9),Vector2(0.12,0.18)]:
                                pts.append(r.position+v*r.size)
                draw_colored_polygon(pts,Color(fill.r,fill.g,fill.b,0.72))
                pts.append(pts[0])
                draw_polyline(pts,ZUI.ICE,1.0,true)
                # Skeletal centreline keeps each anatomical treatment zone readable.
                var centre := r.get_center()
                draw_line(Vector2(centre.x,r.position.y+18),Vector2(centre.x,r.end.y-20),Color(0.6,0.85,0.92,0.3),2)
                if zone != "head":
                        draw_circle(centre,3.5,Color(0.65,0.86,0.91,0.5))

        func _zone_needs(z: String, st: Dictionary, item: String) -> bool:
                match item:
                        "tq":
                                for w in st["wounds"]:
                                        if w["zone"] == z and int(w["bleed"]) > 0 and not w["tq"] and not w["clamp"]:
                                                return true
                                return false
                        "clamp":
                                for w in st["wounds"]:
                                        if w["zone"] == z and int(w["bleed"]) > 0 and not w["tq"] and not w["clamp"]:
                                                return true
                                return false
                        "band":
                                if float(st["body"][z]) < 0.9:
                                        return true
                                for w in st["wounds"]:
                                        if w["zone"] == z and int(w["bleed"]) == 1 and not w["tq"]:
                                                return true
                                return false
                        "splint":
                                return st["frac"].has(z)
                        "morph":
                                return float(st["stress"]) > 40.0
                        "abx":
                                return float(btl.player["infect"]) > 0.5
                        "food":
                                return true
                return false

# ============================================================
# INVGRID — сетка рюкзака (drop-цель: лут из окна обыска)
# ============================================================
class InvGrid extends PanelContainer:
        var btl = null
        var flash_t := 0.0

        func _ready() -> void:
                var sb := ZUI.panel_style(Color(0.06, 0.068, 0.062, 0.9), ZUI.BORDER_SOFT, 10)
                add_theme_stylebox_override("panel", sb)

        func _can_drop_data(_at: Vector2, data) -> bool:
                return data is Dictionary and str(data.get("kind", "")) == "loot_item"

        func _drop_data(_at: Vector2, data) -> void:
                if btl != null and data.has("item"):
                        flash_t = 0.5
                        btl._take_loot_item(str(data["item"]))

        func _process(delta: float) -> void:
                if flash_t > 0.0:
                        flash_t -= delta
                        queue_redraw()

        func _draw() -> void:
                if flash_t > 0.0:
                        var a := flash_t / 0.5
                        draw_rect(Rect2(Vector2.ZERO, size), Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.14 * a), true)
                        draw_rect(Rect2(Vector2.ZERO, size), Color(ZUI.NEON.r, ZUI.NEON.g, ZUI.NEON.b, 0.7 * a), false, 2.0)

# ============================================================
# INVCELL — ячейка рюкзака (как в Майнкрафте): фиксированная сетка,
# drag предмета между ячейками, на тело или в быстрые слоты.
# ============================================================
class InvCell extends Button:
        var btl = null
        var item := ""
        var n := 0
        var grid_index := -1      # индекс в inv_slots (обычные ячейки)
        var is_quick := false     # ячейка строки быстрых слотов
        var q_index := -1

        func _init() -> void:
                custom_minimum_size = Vector2(96, 92)
                focus_mode = Control.FOCUS_NONE

        func _ready() -> void:
                if item != "" and G.ZITEMS.has(item):
                        tooltip_text = "%s\n%s" % [G.ZITEMS[item]["name"], G.ZITEMS[item]["desc"]]
                var normal := StyleBoxFlat.new()
                if item != "":
                        normal.bg_color = Color(0.105, 0.118, 0.108, 0.96)
                        normal.border_color = Color(0.38, 0.44, 0.37, 0.95)
                else:
                        normal.bg_color = Color(0.05, 0.058, 0.052, 0.72)
                        normal.border_color = Color(0.25, 0.29, 0.25, 0.65)
                normal.set_border_width_all(1)
                normal.set_corner_radius_all(9)
                normal.shadow_color = Color(0, 0, 0, 0.35)
                normal.shadow_size = 3
                var hover := normal.duplicate()
                hover.bg_color = Color(0.15, 0.17, 0.155, 0.98)
                hover.border_color = ZUI.NEON
                var pressed := normal.duplicate()
                pressed.bg_color = Color(0.05, 0.10, 0.06, 0.98)
                pressed.border_color = ZUI.NEON_BRIGHT
                add_theme_stylebox_override("normal", normal)
                add_theme_stylebox_override("hover", hover)
                add_theme_stylebox_override("pressed", pressed)
                # содержимое: иконка + имя + количество
                if item != "":
                        var vb := VBoxContainer.new()
                        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
                        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        vb.alignment = BoxContainer.ALIGNMENT_CENTER
                        vb.add_theme_constant_override("separation", 1)
                        add_child(vb)
                        var tex := ZMedUI.item_icon(item)
                        if tex != null:
                                var ic := TextureRect.new()
                                ic.texture = tex
                                ic.custom_minimum_size = Vector2(42, 42)
                                ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                                ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                                ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                vb.add_child(ic)
                        var nm := ZUI.label(ZMedUI.item_name(item), 9, ZUI.TEXT)
                        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                        nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                        nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        vb.add_child(nm)
                        if n > 1:
                                var cnt := ZUI.label("× %d" % n, 12, ZUI.NEON_BRIGHT)
                                cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                                cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                vb.add_child(cnt)
                        if str(btl._med_sel_item) == item:
                                modulate = Color(1.0, 0.92, 0.62)

        func _notification(what: int) -> void:
                if what == Control.NOTIFICATION_RESIZED:
                        queue_redraw()

        func _draw() -> void:
                if is_quick:
                        draw_string(ThemeDB.fallback_font, Vector2(7, 16), str((q_index + 5) % 10), HORIZONTAL_ALIGNMENT_LEFT, 18, 12, ZUI.FAINT)
                if item != "":
                        return
                # пустая ячейка: мягкий крестик-подсказка
                var cc := Vector2(size.x * 0.5, size.y * 0.5 - 4.0)
                draw_line(cc - Vector2(8, 0), cc + Vector2(8, 0), Color(0.42, 0.47, 0.42, 0.40), 2.0)
                draw_line(cc - Vector2(0, 8), cc + Vector2(0, 8), Color(0.42, 0.47, 0.42, 0.40), 2.0)

        # ---------- DRAG источник (ячейка рюкзака или быстрого слота) ----------
        func _get_drag_data(_at: Vector2) -> Variant:
                if item == "":
                        return null
                G.play_sfx("ui_click", -18.0, 1.4)
                var tex := ZMedUI.item_icon(item)
                if tex != null:
                        var prev := TextureRect.new()
                        prev.texture = tex
                        prev.custom_minimum_size = Vector2(46, 46)
                        prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                        prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                        prev.modulate = Color(1, 1, 1, 0.9)
                        set_drag_preview(prev)
                return {"kind": "med_item", "item": item, "from": "quick" if is_quick else "grid", "idx": q_index if is_quick else grid_index}

        # ---------- DROP цель (перестановка / быстрые слоты) ----------
        func _can_drop_data(_at: Vector2, data) -> bool:
                return data is Dictionary and str(data.get("kind", "")) == "med_item" and str(data.get("item", "")) != ""

        func _drop_data(_at: Vector2, data) -> void:
                var d: Dictionary = data
                var from_kind := str(d.get("from", "grid"))
                var from_item := str(d.get("item", ""))
                if from_item == "":
                        return
                if is_quick:
                        if from_kind == "quick":
                                btl._swap_quick(int(d.get("idx", -1)), q_index)
                        else:
                                btl._assign_quick(q_index, from_item)
                else:
                        if from_kind == "quick":
                                btl._quick_to_grid(int(d.get("idx", -1)), grid_index)
                        else:
                                btl._move_inv_slot(int(d.get("idx", -1)), grid_index)

# ============================================================
# BUILD_INV_GRID — фиксированная сетка 6x4 + быстрые слоты (хотбар),
# одна и та же для окна РЮКЗАК и страницы СНАРЯЖЕНИЕ в КПК.
# ============================================================
static func build_inv_grid(btl) -> VBoxContainer:
        G.z_sync_inv_slots()
        if not (G.zsave.get("quick") is Array) or (G.zsave["quick"] as Array).size() != 6:
                G.zsave["quick"] = ["", "", "", "", "", ""]
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 8)
        var grid := GridContainer.new()
        grid.columns = 6
        grid.add_theme_constant_override("h_separation", 8)
        grid.add_theme_constant_override("v_separation", 8)
        box.add_child(grid)
        var slots: Array = G.zsave["inv_slots"]
        for i in range(G.INV_SLOTS):
                var cell := InvCell.new()
                cell.btl = btl
                cell.grid_index = i
                if i < slots.size() and str(slots[i]) != "":
                        cell.item = str(slots[i])
                        cell.n = int(G.zsave["inv"].get(cell.item, 0))
                if cell.item != "":
                        var it: String = cell.item
                        cell.pressed.connect(func():
                                G.play_sfx("ui_click", -12.0)
                                btl._med_tap(it, btl._med_doll))
                grid.add_child(cell)
        # строка быстрых слотов (как хотбар в Майнкрафте)
        box.add_child(ZUI.hdivider(1, ZUI.BORDER_SOFT))
        var qhead := HBoxContainer.new()
        qhead.add_theme_constant_override("separation", 8)
        var qic := ZUI.icon_rect("footstep", 16, ZUI.WARN)
        qic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        qhead.add_child(qic)
        var qlbl := ZUI.label("БЫСТРЫЕ СЛОТЫ — перетащите сюда то, чем пользуетесь чаще всего (появится внизу экрана)", 12, ZUI.WARN)
        qlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        qhead.add_child(qlbl)
        box.add_child(qhead)
        var qrow := HBoxContainer.new()
        qrow.add_theme_constant_override("separation", 8)
        box.add_child(qrow)
        var quick: Array = G.zsave["quick"]
        for qi in range(quick.size()):
                var qc := InvCell.new()
                qc.btl = btl
                qc.is_quick = true
                qc.q_index = qi
                qc.item = str(quick[qi])
                qc.n = int(G.zsave["inv"].get(qc.item, 0)) if qc.item != "" else 0
                if qc.item != "":
                        var qitem: String = qc.item
                        qc.pressed.connect(func():
                                G.play_sfx("ui_click", -12.0)
                                btl._quick_use_item(qitem))
                qrow.add_child(qc)
        return box

# ============================================================
# LOOTROW — строка лута (drag в рюкзак + кнопка ВЗЯТЬ)
# ============================================================
class LootRow extends PanelContainer:
        var item := ""
        var n := 1
        var btl = null

        func _init(item_id: String, count: int) -> void:
                item = item_id
                n = count
                custom_minimum_size = Vector2(320, 62)

        func _ready() -> void:
                var sb := ZUI.panel_style(Color(0.09, 0.10, 0.095, 0.95), ZUI.BORDER_SOFT, 8)
                add_theme_stylebox_override("panel", sb)
                var h := HBoxContainer.new()
                h.add_theme_constant_override("separation", 10)
                add_child(h)
                var ic := TextureRect.new()
                ic.texture = ZMedUI.item_icon(item)
                ic.custom_minimum_size = Vector2(34, 34)
                ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                h.add_child(ic)
                var vb := VBoxContainer.new()
                vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                vb.add_theme_constant_override("separation", 0)
                h.add_child(vb)
                var nm := ZUI.label(ZMedUI.item_name(item), 13, ZUI.TEXT)
                vb.add_child(nm)
                var dsc := ZUI.label("x%d" % n, 11, ZUI.NEON_BRIGHT)
                vb.add_child(dsc)
                var take := ZUI.ZButton.new("ВЗЯТЬ", Vector2(96, 40), false, 12)
                take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                take.pressed.connect(func():
                        if btl != null:
                                btl._take_loot_item(item))
                h.add_child(take)

        func _get_drag_data(_at: Vector2) -> Variant:
                G.play_sfx("ui_click", -18.0, 1.4)
                var tex := ZMedUI.item_icon(item)
                if tex != null:
                        var prev := TextureRect.new()
                        prev.texture = tex
                        prev.custom_minimum_size = Vector2(44, 44)
                        prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                        prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                        prev.modulate = Color(1, 1, 1, 0.9)
                        set_drag_preview(prev)
                return {"kind": "loot_item", "item": item}
