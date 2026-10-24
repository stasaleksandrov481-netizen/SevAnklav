# ============================================================
# БОЕВОЙ ИНТЕРФЕЙС (HUD) — МОБИЛЬНАЯ ВЕРСИЯ «СЕВЕРНЫЙ АНКЛАВ»
# Всё под палец: никаких ЛКМ/ПКМ и клавиш на экране.
# РАСКЛАДКА:
#   ВЕРХ — узкая строка состояния (реквизиция, силы, сектора) + ШТАБ/ПАУЗА
#   ЛЕВО-ВЕРХ  — РАЦИЯ (сворачиваемая лента донесений)
#   ПРАВО-ВЕРХ — МИНИКАРТА (тап — камера)
#   ЦЕНТР-ВЕРХ — чип КОМАНДИРА (HP/патроны/состояние) в режиме бойца
#   ЦЕНТР-НИЗ  — панель действий: ПРИКАЗ · МЕДИК · АВТО · ТЕХНИКА(контекст)
#   УГЛЫ-НИЗ   — ЗАКРЕПЛЁННЫЕ СТИКИ: левый «ХОД», правый «ОГОНЬ»
#   Модалки: ШТАБ (подкрепления/способности/справка), САНАЧАСТЬ (тело+аптечка),
#   ПАУЗА, ФИНАЛ. Здоровье по зонам тела — только внутри САНАЧАСТИ.
# ============================================================
extends CanvasLayer

var battle = null
const Med = preload("res://scripts/med.gd")
var root: Control

# ---------- верхняя строка ----------
var req_label: Label
var ticket_p_bar: ColorRect
var ticket_e_bar: ColorRect
var ticket_p_label: Label
var ticket_e_label: Label
var sectors_label: Label

# ---------- рация (отдельная панель) ----------
var radio_panel: PanelContainer = null
var radio_box: VBoxContainer = null
var radio_head_btn: Button = null
var radio_open := true
var radio_flash := 0.0

# ---------- миникарта ----------
var minimap: Control = null
var map_img_tex: ImageTexture = null
var fog_img: Image = null
var fog_tex: ImageTexture = null
const MINI_W := 268
const MINI_H := 167

# ---------- чип командира (компактная полоска сверху) ----------
var chip: PanelContainer = null
var chip_name: Label = null
var chip_hp: ColorRect = null
var chip_ammo: ColorRect = null
var chip_state: Label = null

# ---------- панель действий (низ-центр) ----------
var btn_order: Button = null
var btn_medic: Button = null
var btn_auto: Button = null
var btn_veh: Button = null

# ---------- модалки ----------
var hq_win: Control = null          # окно ШТАБа
var hq_tab := "deploy"
var hq_pages := {}                  # tab → VBoxContainer
var hq_tab_btns := {}
var deploy_box: HFlowContainer = null
var queue_label: Label = null
var card_buttons := {}
var ab_buttons := {}
var med_win: Control = null         # окно САНАЧАСТИ
var med_body: Control = null
var med_status: Label = null
var med_items_lbl := {}
var pause_win: Control = null
var help_opened_from_pause := false
var end_panel: Control = null

# ---------- прочее ----------
var toast_label: Label
var cut_skip_btn: Button = null
var drag_overlay: Control
var pings: Array = []
var ui_t := 0.0
var fov_rect: ColorRect = null
var fov_mat: ShaderMaterial = null

# ================= СБОРКА =================
func setup(btl) -> void:
        battle = btl
        layer = 50
        root = Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(root)
        _build_top_bar()
        _build_radio()
        _build_minimap()
        _build_chip()
        _build_action_bar()
        _build_drag_overlay()
        _build_toast()
        _build_cutscene_skip()
        _build_fov_overlay()
        _build_grain()

# ================= СТИЛИ =================
func _panel_style(bg := Color(0.065, 0.072, 0.058, 0.9), border := UiKit.BORDER) -> StyleBoxFlat:
        var sb := UiKit.panel_style(bg, border, 8.0)
        sb.set_corner_radius_all(3)
        return sb

func _mk_label(text: String, size: int, col := Color(0.86, 0.88, 0.8)) -> Label:
        return UiKit.label(text, size, col)

func _flat_btn(txt: String, msize: Vector2, accent := false, fsize := 13) -> Button:
        var b := UiKit.MilButton.new(txt, msize, accent, fsize)
        return b

# ================= ВЕРХНЯЯ СТРОКА (узкая, не мешает обзору) =================
func _build_top_bar() -> void:
        var bar := PanelContainer.new()
        bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
        bar.offset_left = 6
        bar.offset_right = -6
        bar.offset_top = 4
        bar.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.055, 0.045, 0.86)))
        var hb := HBoxContainer.new()
        hb.add_theme_constant_override("separation", 12)
        bar.add_child(hb)
        req_label = _mk_label("РКЗ 0", 17, Color(0.93, 0.88, 0.6))
        req_label.custom_minimum_size.x = 220
        hb.add_child(req_label)
        # силы сторон: две компактные полосы с цифрами
        ticket_p_label = _mk_label("1000", 15, G.FACTION_COLOR[battle.faction_player].lightened(0.35))
        hb.add_child(ticket_p_label)
        ticket_p_bar = ColorRect.new()
        ticket_p_bar.custom_minimum_size = Vector2(130, 15)
        ticket_p_bar.color = G.FACTION_COLOR[battle.faction_player]
        ticket_p_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hb.add_child(ticket_p_bar)
        ticket_e_bar = ColorRect.new()
        ticket_e_bar.custom_minimum_size = Vector2(130, 15)
        ticket_e_bar.color = G.FACTION_COLOR[battle.faction_enemy]
        ticket_e_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hb.add_child(ticket_e_bar)
        ticket_e_label = _mk_label("1000", 15, G.FACTION_COLOR[battle.faction_enemy].lightened(0.35))
        hb.add_child(ticket_e_label)
        sectors_label = _mk_label("A·B·C·D·E·F", 16, Color(0.8, 0.85, 0.72))
        sectors_label.custom_minimum_size.x = 200
        hb.add_child(sectors_label)
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hb.add_child(spacer)
        var hq_btn := _flat_btn("ШТАБ", Vector2(112, 44), true, 16)
        hq_btn.pressed.connect(func(): open_hq("deploy"))
        hb.add_child(hq_btn)
        var pause_btn := _flat_btn("II", Vector2(64, 44), false, 17)
        pause_btn.pressed.connect(toggle_pause)
        hb.add_child(pause_btn)
        root.add_child(bar)

# ================= РАЦИЯ (отдельная сворачиваемая панель слева) =================
# КАЖДОЕ донесение имеет метку ГОВОРЯЩЕГО: ШТАБ / КОМАНДИР / БОЕЦ · позывной /
# МЕДИК / РАЗВЕДКА — сразу видно, кто именно докладывает.
const TAG_COL := {
        "ШТАБ": Color(0.95, 0.8, 0.35), "КОМАНДИР": Color(1.0, 0.87, 0.45),
        "БОЕЦ": Color(0.62, 0.9, 0.55), "МЕДИК": Color(0.95, 0.55, 0.5),
        "СНАРЯЖЕНИЕ": Color(0.9, 0.75, 0.45), "РАЗВЕДКА": Color(0.85, 0.62, 0.4),
        "РАДИОПЕРЕХВАТ": Color(0.9, 0.5, 0.4), "АВИАЦИЯ": Color(0.65, 0.8, 0.95),
        "АРТИЛЛЕРИЯ": Color(0.9, 0.7, 0.5), "ЭВАКУАЦИЯ": Color(0.95, 0.7, 0.5),
        "ПОСАДКА": Color(0.6, 0.85, 0.6), "СЕКТОР": Color(0.75, 0.85, 0.95),
        "БОЙ": Color(0.95, 0.6, 0.45),
}
const TAG_PREFIX := ["ШТАБ:", "КОМАНДИР:", "ПОСАДКА:", "ЭВАКУАЦИЯ:", "АВИАЦИЯ:",
        "АРТИЛЛЕРИЯ:", "РАЗВЕДКА:", "РАДИОПЕРЕХВАТ:", "НА ГЛАЗ:", "МЕДИК:"]

func _build_radio() -> void:
        radio_panel = PanelContainer.new()
        radio_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
        radio_panel.offset_left = 8
        radio_panel.offset_top = 56
        radio_panel.offset_right = 8 + 490
        radio_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.068, 0.055, 0.8)))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 3)
        radio_panel.add_child(vb)
        radio_head_btn = Button.new()
        radio_head_btn.text = "РАЦИЯ  ·  СВЕРНУТЬ"
        radio_head_btn.focus_mode = Control.FOCUS_NONE
        radio_head_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        radio_head_btn.custom_minimum_size = Vector2(474, 36)
        radio_head_btn.add_theme_font_size_override("font_size", 17)
        radio_head_btn.add_theme_color_override("font_color", UiKit.AMBER)
        radio_head_btn.add_theme_color_override("font_hover_color", UiKit.AMBER_BRIGHT)
        var hsb := StyleBoxFlat.new()
        hsb.bg_color = Color(0, 0, 0, 0)
        radio_head_btn.add_theme_stylebox_override("normal", hsb)
        radio_head_btn.add_theme_stylebox_override("hover", hsb.duplicate())
        radio_head_btn.add_theme_stylebox_override("pressed", hsb.duplicate())
        radio_head_btn.pressed.connect(_toggle_radio)
        vb.add_child(radio_head_btn)
        radio_box = VBoxContainer.new()
        radio_box.add_theme_constant_override("separation", 2)
        vb.add_child(radio_box)
        root.add_child(radio_panel)

func _toggle_radio() -> void:
        radio_open = not radio_open
        radio_head_btn.text = "РАЦИЯ  ·  РАЗВЕРНУТЬ" if not radio_open else "РАЦИЯ  ·  СВЕРНУТЬ"
        for c in radio_box.get_children():
                c.visible = radio_open
        G.play_sfx("ui_click", -14.0, 1.1)

func push_log(text: String, col: Color, tag: String = "") -> void:
        if radio_box == null:
                return
        # автоопределение говорящего по префиксу текста («ШТАБ: …» и т.п.)
        if tag == "":
                for p in TAG_PREFIX:
                        if text.begins_with(p):
                                tag = p.trim_suffix(":")
                                text = text.trim_prefix(p).strip_edges()
                                break
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 7)
        row.visible = radio_open
        if tag != "":
                var tag_chip := _mk_label(tag, 14, Color(0.08, 0.08, 0.06))
                var tcol: Color = TAG_COL.get(tag.split(" ")[0], UiKit.AMBER)
                tag_chip.add_theme_color_override("font_color", Color(0.07, 0.075, 0.05))
                var chip_bg := PanelContainer.new()
                var csb := StyleBoxFlat.new()
                csb.bg_color = tcol
                csb.set_corner_radius_all(3)
                csb.content_margin_left = 7.0
                csb.content_margin_right = 7.0
                csb.content_margin_top = 1.0
                csb.content_margin_bottom = 1.0
                chip_bg.add_theme_stylebox_override("panel", csb)
                chip_bg.add_child(tag_chip)
                chip_bg.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
                row.add_child(chip_bg)
        var l := _mk_label(text, 15, col)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(l)
        radio_box.add_child(row)
        if radio_box.get_child_count() > 7:
                var old := radio_box.get_child(0)
                radio_box.remove_child(old)
                old.queue_free()
        radio_flash = 0.5

# ================= МИНИКАРТА (правый верхний угол) =================
func _build_minimap() -> void:
        var panel := PanelContainer.new()
        panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
        panel.offset_left = -MINI_W - 22
        panel.offset_right = -8
        panel.offset_top = 52
        panel.add_theme_stylebox_override("panel", _panel_style())
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 3)
        panel.add_child(vb)
        minimap = MinimapView.new()
        minimap.custom_minimum_size = Vector2(MINI_W, MINI_H)
        minimap.battle = battle
        minimap.ui_ref = self
        vb.add_child(minimap)
        var hb := HBoxContainer.new()
        hb.alignment = BoxContainer.ALIGNMENT_CENTER
        hb.add_theme_constant_override("separation", 8)
        vb.add_child(hb)
        var zin := _flat_btn("+", Vector2(56, 36), false, 18)
        zin.pressed.connect(func(): battle.zoom_by(1.16))
        hb.add_child(zin)
        var zout := _flat_btn("–", Vector2(56, 36), false, 18)
        zout.pressed.connect(func(): battle.zoom_by(0.86))
        hb.add_child(zout)
        hb.add_child(_mk_label("тап — камера", 14, Color(0.6, 0.62, 0.52)))
        root.add_child(panel)
        _bake_map_image()

func _bake_map_image() -> void:
        var img := Image.create_empty(MiniConst.MW, MiniConst.MH, false, Image.FORMAT_RGBA8)
        var cols := {
                battle.T_GRASS: Color(0.34, 0.35, 0.24), battle.T_GRASS2: Color(0.31, 0.33, 0.22),
                battle.T_DRY: Color(0.45, 0.41, 0.27), battle.T_DIRT: Color(0.41, 0.36, 0.26),
                battle.T_FIELD: Color(0.5, 0.44, 0.27), battle.T_FIELD2: Color(0.47, 0.42, 0.25),
                battle.T_FOREST: Color(0.16, 0.24, 0.13), battle.T_ROAD: Color(0.28, 0.28, 0.27),
                battle.T_DROAD: Color(0.4, 0.35, 0.26), battle.T_WATER: Color(0.15, 0.24, 0.27),
                battle.T_BRIDGE: Color(0.42, 0.4, 0.37), battle.T_URBAN: Color(0.47, 0.45, 0.42),
                battle.T_TRENCH: Color(0.28, 0.23, 0.18), battle.T_CONCRETE: Color(0.45, 0.44, 0.42),
                battle.T_RUBBLE: Color(0.38, 0.35, 0.31), battle.T_MUD: Color(0.33, 0.3, 0.23),
        }
        for y in range(MiniConst.MH):
                var ty := int(y * battle.MAP_H / float(MiniConst.MH))
                for x in range(MiniConst.MW):
                        var tx := int(x * battle.MAP_W / float(MiniConst.MW))
                        img.set_pixel(x, y, cols.get(battle.tiles[ty][tx], Color(0.3, 0.3, 0.2)))
        map_img_tex = ImageTexture.create_from_image(img)
        fog_img = Image.create_empty(MiniConst.MW, MiniConst.MH, false, Image.FORMAT_RGBA8)
        fog_tex = ImageTexture.create_from_image(fog_img)

class MiniConst:
        const MW := 128
        const MH := 88

class MinimapView extends Control:
        var battle = null
        var ui_ref = null
        func _ready() -> void:
                texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                mouse_filter = Control.MOUSE_FILTER_STOP
        func _gui_input(event: InputEvent) -> void:
                if battle == null:
                        return
                var mb := event as InputEventMouseButton
                if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
                        var mp := mb.position
                        var world := Vector2(
                                mp.x / size.x * battle.MAP_W * battle.TS,
                                mp.y / size.y * battle.MAP_H * battle.TS)
                        battle.center_on(world)
                        G.play_sfx("ui_click", -18.0, 1.2)
        func _draw() -> void:
                if battle == null or ui_ref == null or ui_ref.map_img_tex == null:
                        return
                draw_texture_rect(ui_ref.map_img_tex, Rect2(Vector2.ZERO, size), false)
                # ДИНАМИЧЕСКАЯ ТЕРРИТОРИЯ: границы как в WorldBox
                if battle.territory != null and battle.territory.tex != null:
                        draw_texture_rect(battle.territory.tex, Rect2(Vector2.ZERO, size), false)
                if battle.fog_tex:
                        draw_texture_rect(battle.fog_tex, Rect2(Vector2.ZERO, size), false)
                # точки захвата
                for p in battle.points:
                        var pos := Vector2(
                                p["pos"].x / (battle.MAP_W * battle.TS) * size.x,
                                p["pos"].y / (battle.MAP_H * battle.TS) * size.y)
                        var col := Color(0.85, 0.85, 0.8)
                        if p["owner"] == G.TEAM_PLAYER:
                                col = G.FACTION_COLOR[battle.faction_player]
                        elif p["owner"] == G.TEAM_ENEMY:
                                col = G.FACTION_COLOR[battle.faction_enemy]
                        draw_rect(Rect2(pos - Vector2(4.5, 4.5), Vector2(9, 9)), col)
                        draw_string(ThemeDB.fallback_font, pos + Vector2(6, 5), p["id"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.85))
                # юниты
                for u in battle.units:
                        if not is_instance_valid(u) or not u.alive:
                                continue
                        if u.mounted_in != null:
                                continue
                        if u.team == G.TEAM_ENEMY and not battle.is_visible_to_player(u):
                                continue
                        var pos := Vector2(
                                u.global_position.x / (battle.MAP_W * battle.TS) * size.x,
                                u.global_position.y / (battle.MAP_H * battle.TS) * size.y)
                        var col: Color = G.FACTION_COLOR[battle.faction_player] if u.team == G.TEAM_PLAYER else Color(0.95, 0.35, 0.3)
                        draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), col)
                # КОМАНДИР — золотая метка
                if is_instance_valid(battle.cmdr) and battle.cmdr.alive and battle.cmdr.mounted_in == null:
                        var cpos := Vector2(
                                battle.cmdr.global_position.x / (battle.MAP_W * battle.TS) * size.x,
                                battle.cmdr.global_position.y / (battle.MAP_H * battle.TS) * size.y)
                        draw_circle(cpos, 3.4, Color(0.98, 0.84, 0.3))
                        draw_arc(cpos, 5.4, 0, TAU, 16, Color(0.98, 0.84, 0.3, 0.7), 1.0)
                # рамка камеры
                var cam = battle.camera
                var vs := get_viewport_rect().size
                var half: Vector2 = vs * 0.5 / cam.zoom.x
                var tl: Vector2 = cam.position - half
                var br: Vector2 = cam.position + half
                var r1 := Vector2(tl.x / (battle.MAP_W * battle.TS) * size.x, tl.y / (battle.MAP_H * battle.TS) * size.y)
                var r2 := Vector2(br.x / (battle.MAP_W * battle.TS) * size.x, br.y / (battle.MAP_H * battle.TS) * size.y)
                draw_rect(Rect2(r1, r2 - r1), Color(1, 1, 1, 0.5), false, 1.0)

# ================= ЧИП КОМАНДИРА (верх-центр, только в режиме бойца) =================
func _build_chip() -> void:
        chip = PanelContainer.new()
        chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
        chip.offset_top = 56
        chip.offset_bottom = 102
        chip.offset_left = -360
        chip.offset_right = 360
        chip.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.04, 0.72), UiKit.BORDER_SOFT))
        chip.visible = false
        var hb := HBoxContainer.new()
        hb.add_theme_constant_override("separation", 10)
        chip.add_child(hb)
        chip_name = _mk_label("КОМАНДИР «Заря-1»", 17, UiKit.AMBER_BRIGHT)
        chip_name.custom_minimum_size.x = 220
        hb.add_child(chip_name)
        chip_hp = ColorRect.new()
        chip_hp.custom_minimum_size = Vector2(170, 15)
        chip_hp.color = Color(0.35, 0.85, 0.4)
        chip_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hb.add_child(chip_hp)
        chip_ammo = ColorRect.new()
        chip_ammo.custom_minimum_size = Vector2(100, 15)
        chip_ammo.color = Color(0.85, 0.75, 0.3)
        chip_ammo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hb.add_child(chip_ammo)
        chip_state = _mk_label("", 14, Color(0.9, 0.6, 0.45))
        hb.add_child(chip_state)
        root.add_child(chip)

func show_direct(on: bool, _unit) -> void:
        if chip != null and is_instance_valid(chip):
                chip.visible = on
        if fov_rect != null and not on:
                fov_rect.visible = false
        pings.clear()

# ================= ПАНЕЛЬ ДЕЙСТВИЙ (низ-центр: приказ/здоровье/авто/техника) =================
func _build_action_bar() -> void:
        var bar := HBoxContainer.new()
        bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        bar.offset_top = -92
        bar.offset_bottom = -20
        bar.offset_left = -400
        bar.offset_right = 400
        bar.alignment = BoxContainer.ALIGNMENT_CENTER
        bar.add_theme_constant_override("separation", 14)
        # ПРИКАЗ: следующий тап по карте — движение/атака отрядом
        btn_order = _flat_btn("ПРИКАЗ", Vector2(184, 68), false, 17)
        btn_order.pressed.connect(func():
                battle.touch_order = not battle.touch_order
                if battle.touch_order:
                        battle.amove_mode = false
                        battle.garrison_mode = false
                        battle.pending_ability = ""
                        push_log("ПРИКАЗ: коснитесь точки — движение (по врагу — атака)", Color(0.9, 0.85, 0.55), "ПРИКАЗ")
                        G.play_sfx("ui_click", -8.0, 1.3)
                else:
                        G.play_sfx("ui_click", -14.0, 0.9))
        bar.add_child(btn_order)
        # ЗДОРОВЬЕ: вкладка с телом и инвентарём (перетаскивание предметов на раны)
        btn_medic = _flat_btn("ЗДОРОВЬЕ", Vector2(184, 68), false, 17)
        btn_medic.pressed.connect(func(): open_medic())
        bar.add_child(btn_medic)
        # АВТО: автономное наступление
        btn_auto = _flat_btn("АВТО ВКЛ", Vector2(184, 68), true, 17)
        btn_auto.pressed.connect(func():
                battle.auto_on = not battle.auto_on
                btn_auto.text = "АВТО ВКЛ" if battle.auto_on else "АВТО ВЫКЛ"
                push_log("Автономное наступление: " + ("ВКЛ — отряды сами идут вперёд" if battle.auto_on else "ВЫКЛ — только ваши приказы"), Color(0.85, 0.9, 0.6), "ШТАБ")
                G.play_sfx("ui_click", -8.0))
        bar.add_child(btn_auto)
        # ТЕХНИКА: появляется ТОЛЬКО когда рядом машина (или мы в ней)
        btn_veh = _flat_btn("СЕСТЬ", Vector2(184, 68), true, 17)
        btn_veh.visible = false
        btn_veh.pressed.connect(func(): battle.cmdr_board_exit())
        bar.add_child(btn_veh)
        root.add_child(bar)

# ================= ОВЕРЛЕЙ: СТИКИ, ПИНГИ, РАМКА =================
func _build_drag_overlay() -> void:
        drag_overlay = Control.new()
        drag_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        drag_overlay.draw.connect(_draw_overlay)
        root.add_child(drag_overlay)

func _draw_overlay() -> void:
        if battle == null:
                return
        var vp := drag_overlay.get_viewport_rect().size
        if battle.dragging:
                var mp := drag_overlay.get_local_mouse_position()
                var col := Color(0.5, 0.95, 0.5, 0.9)
                drag_overlay.draw_rect(Rect2(battle.drag_start_screen, mp - battle.drag_start_screen), col, false, 1.5)
                drag_overlay.draw_rect(Rect2(battle.drag_start_screen, mp - battle.drag_start_screen), Color(0.5, 0.95, 0.5, 0.08), true)
        # ----- ЗАКРЕПЛЁННЫЕ СТИКИ В УГЛАХ + ПРИЦЕЛ -----
        if battle.direct_ctrl:
                var bl: Vector2 = battle.stick_base("l")
                var br: Vector2 = battle.stick_base("r")
                var KR: float = battle.STICK_KNOB
                var lcol := Color(0.55, 0.9, 0.55)
                var rcol := Color(0.95, 0.6, 0.35)
                # левый: ход
                var lv: Vector2 = battle.direct_vec.limit_length(1.0)
                _draw_stick(bl, lv * KR, lcol, bool(battle.joy_active), "ХОД")
                # правый: прицел/огонь
                var av := Vector2.ZERO
                var pushed := 0.0
                if battle.manual_aim:
                        av = Vector2.from_angle(battle.manual_ang)
                        pushed = KR * 0.66
                if battle.r_joy_active and pushed > 0.0:
                        av *= pushed
                _draw_fire_stick(br, av, rcol, bool(battle.r_joy_active), bool(battle.manual_fire), "ОГОНЬ")
                _draw_crosshair(vp)
                # слуховые маркеры «?» на краю экрана
                for p in pings:
                        var wpos: Vector2 = p["pos"]
                        var scr: Vector2 = (wpos - battle.camera.position) * battle.cam_zoom + vp * 0.5
                        var to_s := scr - vp * 0.5
                        if to_s.length() < mini(int(vp.x), int(vp.y)) * 0.38:
                                continue
                        var edge := vp * 0.5 + to_s.normalized() * (mini(int(vp.x), int(vp.y)) * 0.36)
                        var alpha: float = clampf(p["t"] / 2.4, 0.0, 1.0)
                        drag_overlay.draw_circle(edge, 16.0, Color(0.9, 0.35, 0.25, 0.35 * alpha))
                        drag_overlay.draw_string(ThemeDB.fallback_font, edge + Vector2(-6, 7), "?",
                                HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.55, 0.4, alpha))
        # ----- ПРИЗРАК ПРЕДМЕТА при перетаскивании в ЗДОРОВЬЕ -----
        if med_drag_item != "":
                var ghost: Color = ITEM_COLORS.get(med_drag_item, Color(0.8, 0.8, 0.7))
                drag_overlay.draw_circle(med_drag_pos, 26.0, Color(ghost.r, ghost.g, ghost.b, 0.35))
                drag_overlay.draw_arc(med_drag_pos, 26.0, 0, TAU, 24, Color(ghost.r, ghost.g, ghost.b, 0.9), 2.0)
                drag_overlay.draw_string(ThemeDB.fallback_font, med_drag_pos + Vector2(-30, 6), Med.ITEM_RU.get(med_drag_item, med_drag_item),
                        HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(1, 1, 1, 0.95))
        if battle.evac_mode:
                drag_overlay.draw_string(ThemeDB.fallback_font, Vector2(24, vp.y * 0.4), "ЭВАКУАЦИЯ: коснитесь раненого отряда",
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.7, 0.4))
        if battle.touch_order:
                drag_overlay.draw_string(ThemeDB.fallback_font, Vector2(24, vp.y * 0.4), "ПРИКАЗ: коснитесь точки карты",
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.85, 0.5))
        if battle.pending_ability != "":
                drag_overlay.draw_string(ThemeDB.fallback_font, Vector2(24, vp.y * 0.4), "ЦЕЛЬ: коснитесь точки удара",
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.75, 0.4))

# ----- ПРИЦЕЛ: куда смотрит ствол командира (мировая точка → экран) -----
func _draw_crosshair(vp: Vector2) -> void:
        if not is_instance_valid(battle.direct_unit) or battle.direct_unit == null:
                return
        var u = battle.direct_unit
        var ang: float = battle.manual_ang if battle.manual_aim else u.facing
        var rng: float = u._max_ground_range()
        var dist: float = clampf(rng * 0.85, 260.0, 900.0)
        var w_from: Vector2 = u.global_position + Vector2.from_angle(ang) * 40.0
        var w_to: Vector2 = u.global_position + Vector2.from_angle(ang) * dist
        var s_from: Vector2 = (w_from - battle.camera.position) * battle.cam_zoom + vp * 0.5
        var s_to: Vector2 = (w_to - battle.camera.position) * battle.cam_zoom + vp * 0.5
        var firing: bool = battle.manual_fire
        var cc := Color(0.95, 0.35, 0.3, 0.9) if firing else Color(1.0, 0.95, 0.8, 0.55)
        # линия прицеливания от ствола
        drag_overlay.draw_line(s_from, s_to, Color(cc.r, cc.g, cc.b, 0.28), 1.5)
        # круг с рисками
        drag_overlay.draw_arc(s_to, 15.0, 0, TAU, 24, cc, 1.8)
        for i in range(4):
                var a := ang + i * PI * 0.5
                var dir := Vector2.from_angle(a)
                drag_overlay.draw_line(s_to + dir * 8.0, s_to + dir * 24.0, cc, 2.0)
        drag_overlay.draw_circle(s_to, 2.4, cc)

func _draw_stick(origin: Vector2, knob_off: Vector2, col: Color, active: bool, cap: String) -> void:
        var a := 0.75 if active else 0.4
        # зона захвата — едва заметный круг (палец ищет базу)
        drag_overlay.draw_arc(origin, battle.STICK_ACT_R * 0.72, 0, TAU, 40, Color(col.r, col.g, col.b, 0.10), 1.0)
        drag_overlay.draw_circle(origin, battle.STICK_KNOB, Color(0.04, 0.045, 0.035, 0.42))
        drag_overlay.draw_arc(origin, battle.STICK_KNOB, 0, TAU, 36, Color(col.r, col.g, col.b, a * 0.55), 2.5)
        drag_overlay.draw_arc(origin, battle.STICK_KNOB * 0.45, 0, TAU, 24, Color(col.r, col.g, col.b, a * 0.2), 1.0)
        var knob := origin + knob_off
        drag_overlay.draw_circle(knob, 37.0, Color(col.r, col.g, col.b, 0.22 if active else 0.12))
        drag_overlay.draw_arc(knob, 37.0, 0, TAU, 24, Color(col.r, col.g, col.b, a), 2.5)
        drag_overlay.draw_string(ThemeDB.fallback_font, origin + Vector2(-16, battle.STICK_KNOB + 30), cap,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(col.r, col.g, col.b, a))

func _draw_fire_stick(origin: Vector2, knob_off: Vector2, col: Color, active: bool, firing: bool, cap: String) -> void:
        var fc := Color(0.95, 0.3, 0.22) if firing else col
        var a := 0.85 if firing else (0.75 if active else 0.4)
        drag_overlay.draw_arc(origin, battle.STICK_ACT_R * 0.72, 0, TAU, 40, Color(fc.r, fc.g, fc.b, 0.10), 1.0)
        drag_overlay.draw_circle(origin, battle.STICK_KNOB, Color(0.05, 0.035, 0.03, 0.42))
        drag_overlay.draw_arc(origin, battle.STICK_KNOB, 0, TAU, 36, Color(fc.r, fc.g, fc.b, a * 0.55), 2.5)
        # метки «до упора — огонь»: два сегмента у края базы
        for sg in [-0.5, 0.5]:
                drag_overlay.draw_arc(origin, battle.STICK_KNOB * battle.STICK_FIRE_K, -0.18 + sg, 0.18 + sg, 8, Color(0.95, 0.35, 0.25, a * 0.8), 4.0)
        var knob := origin + knob_off
        drag_overlay.draw_circle(knob, 37.0, Color(fc.r, fc.g, fc.b, 0.3 if (active or firing) else 0.12))
        drag_overlay.draw_arc(knob, 37.0, 0, TAU, 24, Color(fc.r, fc.g, fc.b, a), 2.5)
        if firing:
                var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.06
                drag_overlay.draw_arc(origin, battle.STICK_KNOB * 1.25 * pulse, 0, TAU, 40, Color(0.95, 0.3, 0.22, 0.5), 2.5)
        drag_overlay.draw_string(ThemeDB.fallback_font, origin + Vector2(-20, battle.STICK_KNOB + 30), cap,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(fc.r, fc.g, fc.b, a))

# ================= КОНУС ЗРЕНИЯ (замыленный тыл) =================
func _build_fov_overlay() -> void:
        fov_rect = ColorRect.new()
        fov_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        fov_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sh := Shader.new()
        sh.code = """
shader_type canvas_item;
uniform vec2 center = vec2(0.5, 0.5);
uniform float facing = 0.0;
uniform float active = 0.0;
uniform vec2 vsize = vec2(1600.0, 900.0);
void fragment() {
        vec2 d = (UV - center) * vsize;
        float a = atan(d.y, d.x);
        float diff = abs(atan(sin(a - facing), cos(a - facing)));
        float rear = smoothstep(1.0, 1.75, diff);
        float col = mix(1.0, 0.42, rear * active);
        COLOR = vec4(vec3(col), rear * active * 0.5);
}
"""
        fov_mat = ShaderMaterial.new()
        fov_mat.shader = sh
        fov_rect.material = fov_mat
        fov_rect.visible = false
        var fov_layer := CanvasLayer.new()
        fov_layer.layer = 80
        fov_layer.add_child(fov_rect)
        add_child(fov_layer)

func update_fov_hud(world_pos: Vector2, facing: float) -> void:
        if fov_rect == null or fov_mat == null:
                return
        var vp := root.get_viewport_rect().size
        var scr: Vector2 = (world_pos - battle.camera.position) * battle.cam_zoom + vp * 0.5
        fov_mat.set_shader_parameter("center", Vector2(scr.x / maxf(1.0, vp.x), scr.y / maxf(1.0, vp.y)))
        fov_mat.set_shader_parameter("facing", facing)
        fov_mat.set_shader_parameter("active", 1.0)
        fov_mat.set_shader_parameter("vsize", vp)
        fov_rect.visible = true

func add_sound_ping(world_pos: Vector2) -> void:
        pings.append({"pos": world_pos, "t": 2.4})
        if pings.size() > 6:
                pings.pop_front()

# ================= ЗЕРНО ПЛЁНКИ =================
func _build_grain() -> void:
        var grain_layer := CanvasLayer.new()
        grain_layer.layer = 90
        add_child(grain_layer)
        grain_layer.add_child(UiKit.make_grain(0.055))
        grain_layer.add_child(UiKit.make_vignette(0.38))

# ================= ТОСТ МИССИИ =================
func _build_toast() -> void:
        toast_label = _mk_label("", 24, Color(0.92, 0.9, 0.8))
        toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
        toast_label.offset_top = 108
        toast_label.offset_left = -460
        toast_label.offset_right = 460
        toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        root.add_child(toast_label)

func _show_toast() -> void:
        var sec: Dictionary = G.SECTORS[battle.sector_idx]
        toast_label.text = "СЕКТОР %d/20: %s\nУдержите большинство точек — обескровьте противника" % [battle.sector_idx + 1, sec["name"]]
        toast_label.modulate.a = 0.0
        var tw := create_tween()
        tw.tween_property(toast_label, "modulate:a", 1.0, 0.8)
        tw.tween_interval(4.0)
        tw.tween_property(toast_label, "modulate:a", 0.0, 1.2)

# ================= КАТСЦЕНА: ПРОПУСК + ПОДСКАЗКА ПОСЛЕ НЕЁ =================
func _build_cutscene_skip() -> void:
        cut_skip_btn = UiKit.HoldButton.new("ЗАЖМИТЕ — ПРОПУСТИТЬ ПРИБЫТИЕ", 0.9)
        cut_skip_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        cut_skip_btn.offset_left = -230
        cut_skip_btn.offset_right = 230
        cut_skip_btn.offset_top = -240
        cut_skip_btn.offset_bottom = -196
        cut_skip_btn.visible = false
        root.add_child(cut_skip_btn)
        cut_skip_btn.pressed.connect(func():
                if battle != null and battle.cutscene:
                        battle._finish_cutscene(true))
        var t := get_tree().create_timer(0.8)
        t.timeout.connect(func():
                if is_instance_valid(cut_skip_btn) and battle != null and battle.cutscene:
                        cut_skip_btn.visible = true
                        var tw := cut_skip_btn.create_tween()
                        cut_skip_btn.modulate.a = 0.0
                        tw.tween_property(cut_skip_btn, "modulate:a", 1.0, 0.4))

func on_cutscene_end() -> void:
        if cut_skip_btn != null and is_instance_valid(cut_skip_btn):
                cut_skip_btn.visible = false
        _show_toast()
        # подсказка ТОЛЬКО сенсорная — никаких ЛКМ/ПКМ (ниже тоста, чтобы не перекрывать)
        var hint := UiKit.label("Левый стик — идти   ·   Правый — прицел, толкни до упора — ОГОНЬ", 20, UiKit.AMBER_BRIGHT)
        hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
        hint.offset_top = 190
        hint.offset_left = -470
        hint.offset_right = 470
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        root.add_child(hint)
        hint.modulate.a = 0.0
        var tw := hint.create_tween()
        tw.tween_interval(0.4)
        tw.tween_property(hint, "modulate:a", 1.0, 0.5)
        tw.tween_interval(5.0)
        tw.tween_property(hint, "modulate:a", 0.0, 1.0)
        tw.tween_callback(hint.queue_free)

# ================= ОКНО ШТАБА: ПОДКРЕПЛЕНИЯ / СПОСОБНОСТИ / СПРАВКА =================
func open_hq(tab: String) -> void:
        if end_panel != null:
                return
        if hq_win != null and is_instance_valid(hq_win):
                _switch_hq_tab(tab)
                return
        battle.paused = true
        hq_tab = tab
        var w := UiKit.open_window(self, "ШТАБ — УПРАВЛЕНИЕ БОЕМ", Vector2(1020, 0), true)
        hq_win = w["overlay"]
        var vb: VBoxContainer = w["vb"]
        # вкладки
        var tabs := HBoxContainer.new()
        tabs.add_theme_constant_override("separation", 8)
        vb.add_child(tabs)
        var defs := [["deploy", "ПОДКРЕПЛЕНИЯ"], ["abil", "СПОСОБНОСТИ"], ["help", "СПРАВКА"]]
        for td in defs:
                var tb: Button = _flat_btn(td[1], Vector2(210, 46), td[0] == hq_tab, 15)
                var f: String = td[0]
                tb.pressed.connect(func(): _switch_hq_tab(f))
                tabs.add_child(tb)
                hq_tab_btns[f] = tb
        # страницы
        var pages := VBoxContainer.new()
        vb.add_child(pages)
        hq_pages = {
                "deploy": _build_deploy_page(pages),
                "abil": _build_abilities_page(pages),
                "help": _build_help_page(pages),
        }
        _switch_hq_tab(hq_tab)

func _switch_hq_tab(tab: String) -> void:
        hq_tab = tab
        for k in hq_pages:
                var pg: Control = hq_pages[k]
                if is_instance_valid(pg):
                        pg.visible = (k == tab)
        for k2 in hq_tab_btns:
                var b: Button = hq_tab_btns[k2]
                if is_instance_valid(b):
                        b.modulate = Color(1.4, 1.28, 0.9) if k2 == tab else Color(1, 1, 1)
        G.play_sfx("ui_click", -14.0, 1.2)

func _build_deploy_page(parent: Control) -> Control:
        var pg := VBoxContainer.new()
        pg.add_theme_constant_override("separation", 6)
        parent.add_child(pg)
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 12)
        pg.add_child(head)
        head.add_child(_mk_label("Вызывайте подкрепления — они прибудут на ФОБ и сами пойдут в бой", 14, Color(0.8, 0.85, 0.7)))
        var sp := Control.new()
        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(sp)
        queue_label = _mk_label("Очередь: пусто", 13, Color(0.85, 0.8, 0.55))
        head.add_child(queue_label)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(960, 380)
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        pg.add_child(scroll)
        deploy_box = HFlowContainer.new()
        deploy_box.add_theme_constant_override("h_separation", 8)
        deploy_box.add_theme_constant_override("v_separation", 8)
        deploy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(deploy_box)
        var ids: Array = G.units_of(battle.faction_player)
        ids = ids.filter(func(id): return not G.DB[id].get("hero", false))
        ids.sort_custom(func(a, b):
                var ka: int = 0 if G.DB[a]["kind"] == "inf" else (1 if G.DB[a]["kind"] == "veh" else 2)
                var kb: int = 0 if G.DB[b]["kind"] == "inf" else (1 if G.DB[b]["kind"] == "veh" else 2)
                if ka != kb:
                        return ka < kb
                return G.DB[a]["cost"] < G.DB[b]["cost"])
        for id in ids:
                deploy_box.add_child(_make_card(id))
        return pg

func _make_card(id: String) -> Button:
        var d: Dictionary = G.DB[id]
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(148, 128)
        btn.tooltip_text = d["name"] + "\n" + d.get("desc", "") + "\nБроня: %s | Обзор: %d" % [d["armor"], int(d["vision"])]
        var vb := VBoxContainer.new()
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_theme_constant_override("separation", 0)
        btn.add_child(vb)
        var icon := TextureRect.new()
        icon.texture = G.tex("icon_" + id)
        icon.custom_minimum_size = Vector2(132, 58)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_child(icon)
        var nm := _mk_label(d["name"], 12, Color(0.88, 0.9, 0.8))
        nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        nm.custom_minimum_size = Vector2(140, 30)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(nm)
        var cost_l := _mk_label("%d ркз · %dс" % [G.cost_for(id, G.save["kit"]), int(d["build"])], 13, Color(0.93, 0.87, 0.5))
        cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(cost_l)
        btn.pressed.connect(func(): battle.try_deploy(id))
        card_buttons[id] = btn
        if d["kind"] == "heli":
                btn.disabled = not battle.heli_unlocked
        return btn

func _build_abilities_page(parent: Control) -> Control:
        var pg := VBoxContainer.new()
        pg.add_theme_constant_override("separation", 8)
        parent.add_child(pg)
        pg.add_child(_mk_label("Поддержка командования: тап по способности, затем тап по карте — точка удара", 14, Color(0.8, 0.85, 0.7)))
        var row := HFlowContainer.new()
        row.add_theme_constant_override("h_separation", 10)
        row.add_theme_constant_override("v_separation", 10)
        pg.add_child(row)
        for ab in G.ability_list(battle.faction_player):
                var d: Dictionary = G.DB[ab]
                var btn := Button.new()
                btn.custom_minimum_size = Vector2(180, 110)
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.12, 0.13, 0.10, 0.95)
                sb.border_color = UiKit.BORDER
                sb.set_border_width_all(1)
                sb.set_corner_radius_all(3)
                btn.add_theme_stylebox_override("normal", sb)
                var sbh: StyleBoxFlat = sb.duplicate()
                sbh.border_color = UiKit.AMBER
                sbh.bg_color = Color(0.16, 0.17, 0.12, 0.95)
                btn.add_theme_stylebox_override("hover", sbh)
                btn.add_theme_stylebox_override("pressed", sbh)
                btn.focus_mode = Control.FOCUS_NONE
                var vb := VBoxContainer.new()
                vb.set_anchors_preset(Control.PRESET_FULL_RECT)
                vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
                btn.add_child(vb)
                var icon := TextureRect.new()
                icon.texture = G.tex(d.get("icon", "icon_ab_arty"))
                icon.custom_minimum_size = Vector2(160, 52)
                icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
                vb.add_child(icon)
                var nm := _mk_label(d["name"], 13, Color(0.88, 0.9, 0.8))
                nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                nm.custom_minimum_size = Vector2(172, 0)
                vb.add_child(nm)
                var cd := _mk_label("%d ркз" % d["cost"], 13, Color(0.93, 0.87, 0.5))
                cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                vb.add_child(cd)
                btn.pressed.connect(func(): battle.try_ability(ab))
                row.add_child(btn)
                ab_buttons[ab] = {"btn": btn, "cd": cd}
        return pg

func _build_help_page(parent: Control) -> Control:
        var pg := VBoxContainer.new()
        pg.add_theme_constant_override("separation", 8)
        parent.add_child(pg)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(960, 360)
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        pg.add_child(scroll)
        var txt := UiKit.wrap_label(
                "МЫ ИГРАЕМ ЗА КОМАНДИРА «ЗАРЯ-1», всё управление — пальцами:\n\n" +
                "СТИКИ (внизу по углам, крупные и симметричные):\n" +
                "  • ЛЕВЫЙ СТИК «ХОД» — движение. Можно идти в одну сторону и целиться в другую.\n" +
                "  • ПРАВЫЙ СТИК «ОГОНЬ» — прицел; толкните от центра до красных меток — огонь, верните к центру — прекратится. Пока стик удерживается — стреляем ТОЛЬКО туда, куда целимся.\n" +
                "  • Белый ПРИЦЕЛ показывает, куда смотрит ствол; при огне он красный.\n\n" +
                "ПАНЕЛЬ ДЕЙСТВИЙ (низ, центр):\n" +
                "  • ПРИКАЗ — затем тап по карте: отряды идут туда (тап по врагу — атака, по своей машине — посадка).\n" +
                "  • ЗДОРОВЬЕ — вкладка тела и инвентаря: перетащите ЖГУТ на раненую ногу, ШИНУ — на перелом, БИНТ — на разбитую зону (или тап по предмету → тап по зоне).\n" +
                "  • АВТО — автономное наступление: отряды сами идут вперёд и ищут бой.\n" +
                "  • ТЕХНИКА — появляется ТОЛЬКО когда командир стоит у свободной машины; в машине — «ВЫЙТИ».\n\n" +
                "РАЦИЯ (левый верх): живые донесения; у каждого — метка говорящего: ШТАБ, БОЕЦ · позывной, МЕДИК, РАЗВЕДКА.\n" +
                "МИНИКАРТА (правый верх): тап — перенести камеру; «+»/«–» — зум; щипок двумя пальцами тоже зум.\n" +
                "ТЕРРИТОРИЯ: земля вокруг наших бойцов красится в наш цвет (как в WorldBox) — линия фронта движется сама; своя земля даёт реквизицию.\n\n" +
                "ЖИВЫЕ ОТРЯДЫ: солдаты идут цепью перебежками, увидев врага у точки — залегают и бьют из укрытий (кто-то в окопе, кто-то за домом), зачистив рубеж — двигаются дальше; докладывают по рации.\n\n" +
                "ХАРДКОР: у бойцов 6 зон тела — кровотечения и переломы смертельны, лечение по этапам. Боезапас ограничен — держите Урал поближе. Боеуклад техники детонирует.\n" +
                "Замыленный тыл: за спиной врагов не видно — следите за маркерами «?» (звук выстрелов).\n" +
                "Командир павший — через 20 секунд заместитель принимает командование.",
                15, Color(0.85, 0.87, 0.78), 940)
        scroll.add_child(txt)
        return pg

# ================= ЗДОРОВЬЕ: ТЕЛО + ИНВЕНТАРЬ (перетаскивание предметов) =================
# Уникальный интерфейс: тащишь ЖГУТ из инвентаря на раненую НОГУ — жгут
# накладывается именно туда. Несовместимое — не применяется (с подсказкой).
# Работает и «в два тапа»: тап по предмету → тап по зоне тела.
var med_drag_item := ""          # предмет «в руке» при перетаскивании
var med_drag_pos := Vector2.ZERO
var med_armed := ""              # выбранный тапом предмет (режим «тап → тап»)
var med_hover_zone := ""         # зона под курсором/пальцем (подсветка)
const ITEM_COLORS := {
        "band": Color(0.93, 0.93, 0.88), "tq": Color(0.85, 0.25, 0.2),
        "splint": Color(0.75, 0.6, 0.35), "morph": Color(0.6, 0.4, 0.8),
        "mag": Color(0.5, 0.6, 0.4),
}

func open_medic() -> void:
        if end_panel != null:
                return
        if med_win != null and is_instance_valid(med_win):
                return
        battle.paused = true
        med_drag_item = ""
        med_armed = ""
        med_hover_zone = ""
        var w := UiKit.open_window(self, "ЗДОРОВЬЕ ОТРЯДА «ЗАРЯ-1»", Vector2(940, 0), true)
        med_win = w["overlay"]
        var vb: VBoxContainer = w["vb"]
        var hb := HBoxContainer.new()
        hb.add_theme_constant_override("separation", 26)
        vb.add_child(hb)
        # схема тела (зоны: голова, торс, руки, ноги) — НА НЕЁ перетаскиваем предметы
        med_body = MedBody.new()
        med_body.ui_ref = self
        med_body.custom_minimum_size = Vector2(230, 320)
        hb.add_child(med_body)
        med_status = UiKit.wrap_label("", 16, UiKit.TEXT, 560)
        med_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hb.add_child(med_status)
        # ИНВЕНТАРЬ: предметы в РЯД (не столбцом), каждый — крупный слот
        var inv_head := _mk_label("ИНВЕНТАРЬ — перетащите предмет на раненую зону тела (или тап по предмету, затем тап по зоне)", 15, Color(0.8, 0.85, 0.7))
        inv_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        inv_head.custom_minimum_size = Vector2(880, 0)
        vb.add_child(inv_head)
        var row := HFlowContainer.new()
        row.add_theme_constant_override("h_separation", 10)
        row.add_theme_constant_override("v_separation", 10)
        vb.add_child(row)
        for it in ["tq", "band", "splint", "morph", "mag"]:
                row.add_child(_make_med_slot(it))
        # «НА ГЛАЗ» — проверка магазина на ощупь
        var chk := _flat_btn("НА ГЛАЗ", Vector2(140, 96), false, 15)
        chk.pressed.connect(func():
                battle.check_mag_blind()
                _refresh_medic())
        row.add_child(chk)
        med_items_lbl = {}
        for it in ["tq", "band", "splint", "morph", "mag"]:
                med_items_lbl[it] = null   # слот сам обновится через группу
        # запоминаем слоты для обновления счётчиков
        for c in row.get_children():
                if c is MedSlot:
                        med_items_lbl[(c as MedSlot).item] = c
        var note := _mk_label("ЖГУТ — на кровоточащую конечность · БИНТ — перевязка зоны · ШИНА — на перелом · МОРФИН — боль и стресс · МАГАЗИН — боезапас. Пополнение: Урал на разгрузке и ящики снабжения.", 13, Color(0.65, 0.68, 0.58))
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        note.custom_minimum_size = Vector2(880, 0)
        vb.add_child(note)
        _refresh_medic()

func _make_med_slot(item: String) -> Control:
        var slot := MedSlot.new()
        slot.ui_ref = self
        slot.item = item
        slot.custom_minimum_size = Vector2(146, 96)
        return slot

# ----- вызовы из слотов/схемы тела (MedSlot / MedBody) -----
func med_press_slot(item: String, gpos: Vector2) -> void:
        if int(battle.cmd_items.get(item, 0)) <= 0:
                return
        med_drag_item = item
        med_drag_pos = gpos
        med_armed = ""
        drag_overlay.queue_redraw()

func med_drag_update(gpos: Vector2) -> void:
        if med_drag_item == "":
                return
        med_drag_pos = gpos
        # подсветка зоны под пальцем
        med_hover_zone = ""
        if med_body != null and is_instance_valid(med_body):
                med_hover_zone = (med_body as MedBody).zone_at(gpos)
        drag_overlay.queue_redraw()

func med_release_slot(item: String, gpos: Vector2) -> void:
        if med_drag_item == "":
                return
        var z := ""
        if med_body != null and is_instance_valid(med_body):
                z = (med_body as MedBody).zone_at(gpos)
        med_drag_item = ""
        med_hover_zone = ""
        drag_overlay.queue_redraw()
        if z != "":
                battle.use_cmd_item_zone(item, z)
                _refresh_medic()
        else:
                # не дотащили — предмет «взят в руку»: ждём тап по зоне
                med_armed = item
                push_log("Предмет в руке: коснитесь зоны тела, чтобы применить", Color(0.85, 0.8, 0.55), "МЕДИК")

func med_tap_zone(zone: String) -> void:
        # режим «тап по предмету → тап по зоне» (удобно одной рукой)
        if med_armed == "":
                return
        var it := med_armed
        med_armed = ""
        battle.use_cmd_item_zone(it, zone)
        _refresh_medic()

func _refresh_medic() -> void:
        if med_win == null or not is_instance_valid(med_win) or battle == null:
                return
        if med_body != null and is_instance_valid(med_body):
                (med_body as MedBody).queue_redraw()
        if med_status == null:
                return
        if not battle.direct_ctrl or not is_instance_valid(battle.direct_unit):
                med_status.text = "Командир не в строю."
                return
        var u = battle.direct_unit
        if u.def["kind"] == "veh":
                med_status.text = "Командир за рулём «%s». Пассажиров: %d. Броня держит урон, но горящая техника опасна для всех." % [u.def["name"], u.passengers.size()]
        else:
                var parts: Array = []
                var n_w := 0
                for s in u.soldiers:
                        if s["alive"]:
                                var ss: String = Med.status_str(s)
                                if ss != "":
                                        n_w += 1
                                        parts.append(ss)
                if n_w > 0:
                        med_status.text = "Раненых: %d\n%s" % [n_w, "\n".join(PackedStringArray(parts.slice(0, 3)))]
                        med_status.add_theme_color_override("font_color", Color(0.95, 0.6, 0.45))
                else:
                        med_status.text = "Отряд в полном порядке. Боезапас: %d/%d маг." % [int(round(u.mags)), int(u.mags_max)]
                        med_status.add_theme_color_override("font_color", UiKit.TEXT)
        # счётчики предметов на слотах
        for it in med_items_lbl:
                var sl = med_items_lbl[it]
                if sl != null and is_instance_valid(sl):
                        (sl as MedSlot).count = int(battle.cmd_items.get(it, 0))
                        (sl as MedSlot).queue_redraw()

# ================= ВНУТРЕННИЕ КЛАССЫ: СЛОТ ПРЕДМЕТА И СХЕМА ТЕЛА =================
class MedSlot extends Button:
        var ui_ref = null
        var item := ""
        var count := 0
        var press_pos := Vector2.ZERO
        var moved := false
        func _init() -> void:
                focus_mode = Control.FOCUS_NONE
        func _ready() -> void:
                custom_minimum_size = Vector2(146, 96)
        func _gui_input(ev: InputEvent) -> void:
                if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
                        if ev.pressed:
                                press_pos = ev.global_position
                                moved = false
                                if ui_ref != null and count > 0:
                                        (ui_ref as Object).med_press_slot(item, ev.global_position)
                        else:
                                if ui_ref != null and count > 0:
                                        # короткий тап без переноса = «взять в руку»
                                        if not moved and press_pos.distance_to(ev.global_position) < 14.0:
                                                (ui_ref as Object).med_release_slot(item, Vector2(-10000, -10000))
                                        else:
                                                (ui_ref as Object).med_release_slot(item, ev.global_position)
                elif ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
                        if press_pos.distance_to(ev.global_position) > 12.0:
                                moved = true
                        if ui_ref != null:
                                (ui_ref as Object).med_drag_update(ev.global_position)
        func _draw() -> void:
                var ui = ui_ref
                if ui == null:
                        return
                var col: Color = ui.ITEM_COLORS.get(item, Color(0.7, 0.7, 0.6))
                var armed: bool = ui.med_armed == item
                var dragging: bool = ui.med_drag_item == item
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(col.r, col.g, col.b, 0.16 if count > 0 else 0.05)
                sb.border_color = col if (armed or dragging) else Color(col.r, col.g, col.b, 0.55)
                sb.set_border_width_all(3 if (armed or dragging) else 2)
                sb.set_corner_radius_all(6)
                draw_style_box(sb, Rect2(Vector2.ZERO, size))
                # иконка предмета: полоска-бинт / крест-жгут / шина / шприц / магазин
                var c := Vector2(size.x * 0.5, size.y * 0.34)
                match item:
                        "tq":
                                draw_line(c + Vector2(-16, -10), c + Vector2(16, 10), Color(0.85, 0.25, 0.2), 5.0)
                                draw_line(c + Vector2(-16, 10), c + Vector2(16, -10), Color(0.85, 0.25, 0.2), 5.0)
                        "band":
                                draw_rect(Rect2(c + Vector2(-18, -6), Vector2(36, 12)), Color(0.93, 0.93, 0.88))
                                draw_rect(Rect2(c + Vector2(-4, -6), Vector2(8, 12)), Color(0.7, 0.35, 0.3))
                        "splint":
                                draw_line(c + Vector2(-14, 10), c + Vector2(14, -10), Color(0.75, 0.6, 0.35), 6.0)
                                draw_line(c + Vector2(-2, 12), c + Vector2(-14, 2), Color(0.75, 0.6, 0.35), 6.0)
                        "morph":
                                draw_rect(Rect2(c + Vector2(-4, -14), Vector2(8, 24)), Color(0.6, 0.4, 0.8))
                                draw_polygon(PackedVector2Array([c + Vector2(-8, 10), c + Vector2(8, 10), c + Vector2(0, 18)]), PackedColorArray([Color(0.6, 0.4, 0.8)]))
                        "mag":
                                draw_rect(Rect2(c + Vector2(-9, -14), Vector2(18, 28)), Color(0.5, 0.6, 0.4))
                                for i in range(3):
                                        draw_rect(Rect2(c + Vector2(-6, -10 + i * 8), Vector2(12, 4)), Color(0.85, 0.8, 0.5))
                var f := ThemeDB.fallback_font
                draw_string(f, Vector2(size.x * 0.5 - 46, size.y * 0.68), ui_ref.Med.ITEM_RU.get(item, item), HORIZONTAL_ALIGNMENT_CENTER, 92, 14, Color(0.88, 0.9, 0.82))
                var cs: String = ("×%d" % count) if count > 0 else "нет"
                draw_string(f, Vector2(size.x * 0.5 - 30, size.y * 0.92), cs, HORIZONTAL_ALIGNMENT_CENTER, 60, 14,
                        Color(0.95, 0.85, 0.5) if count > 0 else Color(0.6, 0.55, 0.5))
                if armed:
                        draw_string(f, Vector2(4, 14), "ВЫБРАН", HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color(1, 0.9, 0.5))

class MedBody extends Control:
        var ui_ref = null
        var zone_rects := {}      # zone → Rect2 (локальные координаты)
        func _init() -> void:
                custom_minimum_size = Vector2(230, 320)
                mouse_filter = Control.MOUSE_FILTER_STOP
        func _gui_input(ev: InputEvent) -> void:
                if ui_ref == null:
                        return
                var ui = ui_ref as Object
                if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
                        var z := _zone_at_local(ev.position)
                        if z != "":
                                accept_event()
                                ui.med_tap_zone(z)
                elif ev is InputEventMouseMotion and ui.med_drag_item != "":
                        var z2 := _zone_at_local(ev.position)
                        ui.med_hover_zone = z2
                        (ui as Node).drag_overlay.queue_redraw()
        func _zone_at_local(p: Vector2) -> String:
                for z in zone_rects:
                        var r: Rect2 = zone_rects[z]
                        if r.has_point(p):
                                return z
                return ""
        func zone_at(global_p: Vector2) -> String:
                return _zone_at_local(global_p - global_position)
        func _draw() -> void:
                if ui_ref == null or ui_ref.battle == null:
                        return
                var ui = ui_ref
                var battle = ui.battle
                var MedC = ui.Med
                # худший раненый боец отряда командира
                var worst: Dictionary = {}
                var wsc := -1.0
                if battle.direct_ctrl and is_instance_valid(battle.direct_unit) and not battle.direct_unit.soldiers.is_empty():
                        for s in battle.direct_unit.soldiers:
                                if not s["alive"]:
                                        continue
                                var sc: float = 2.0 if (s["st"] as Dictionary)["down"] else 0.5
                                if MedC.worst_item(s) != "":
                                        sc += 1.0
                                if sc > wsc:
                                        wsc = sc
                                        worst = s
                var f := ThemeDB.fallback_font
                var head_l := "СОСТОЯНИЕ БОЙЦА"
                draw_string(f, Vector2(size.x * 0.5 - 70, 16), head_l, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(0.7, 0.75, 0.62))
                var st: Dictionary = worst.get("st", {})
                var body: Dictionary = st.get("body", {})
                var frac: Array = st.get("frac", [])
                var wounds: Array = st.get("wounds", [])
                var hover: String = ui.med_hover_zone
                var s := 2.6      # масштаб схемы (крупная, под палец)
                var ox := size.x * 0.5
                var oy := 26.0
                zone_rects.clear()
                # зоны (в порядке отрисовки): голова, торс, руки, ноги
                var head_r := Rect2(ox - 11 * s, oy + 8 * s - 11 * s, 22 * s, 22 * s)
                var torso_r := Rect2(ox - 10 * s, oy + 20 * s, 20 * s, 34 * s)
                var la_r := Rect2(ox - 21 * s, oy + 21 * s, 10 * s, 30 * s)
                var ra_r := Rect2(ox + 11 * s, oy + 21 * s, 10 * s, 30 * s)
                var ll_r := Rect2(ox - 9 * s, oy + 57 * s, 9 * s, 33 * s)
                var rl_r := Rect2(ox + 1 * s, oy + 57 * s, 9 * s, 33 * s)
                zone_rects = {"head": head_r, "torso": torso_r, "la": la_r, "ra": ra_r, "ll": ll_r, "rl": rl_r}
                var col_of := func(z: String) -> Color:
                        var v: float = body.get(z, 1.0)
                        if v > 0.85:
                                return Color(0.4, 0.75, 0.45)
                        if v > 0.5:
                                return Color(0.9, 0.75, 0.3)
                        return Color(0.85, 0.3, 0.25)
                var draw_zone := func(z: String, r: Rect2, is_circle: bool) -> void:
                        var base: Color = col_of.call(z)
                        if z == hover:
                                base = base.lightened(0.45)
                        if is_circle:
                                draw_circle(r.get_center(), r.size.x * 0.5, base)
                        else:
                                draw_rect(r, base)
                        if z == hover:
                                draw_rect(r.grow(3.0), Color(1, 1, 1, 0.85), false, 2.0)
                draw_zone.call("head", head_r, true)
                draw_zone.call("torso", torso_r, false)
                draw_zone.call("la", la_r, false)
                draw_zone.call("ra", ra_r, false)
                draw_zone.call("ll", ll_r, false)
                draw_zone.call("rl", rl_r, false)
                # маркеры: кровотечение (капля), жгут (Т), перелом (крест)
                for w in wounds:
                        var z: String = w["zone"]
                        if not zone_rects.has(z):
                                continue
                        var r: Rect2 = zone_rects[z]
                        var mid := r.get_center()
                        if w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                                draw_circle(mid + Vector2(0, -r.size.y * 0.28), 5.5, Color(0.95, 0.2, 0.15))
                        if w["tq"]:
                                draw_string(f, mid + Vector2(-6, r.size.y * 0.3), "Ж", HORIZONTAL_ALIGNMENT_LEFT, 20, 15, Color(1, 0.95, 0.6))
                for z2 in frac:
                        if not zone_rects.has(z2):
                                continue
                        var r2: Rect2 = zone_rects[z2]
                        var p2 := r2.get_center() + Vector2(0, r2.size.y * 0.18)
                        draw_line(p2 + Vector2(-7, -7), p2 + Vector2(7, 7), Color(0.95, 0.95, 0.9), 3.0)
                        draw_line(p2 + Vector2(7, -7), p2 + Vector2(-7, 7), Color(0.95, 0.95, 0.9), 3.0)
                # подписи зон по бокам (крупно)
                var lab: Dictionary = MedC.ZONE_RU
                draw_string(f, Vector2(4, oy + 30 * s * 0.55), lab["la"], HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.75, 0.8, 0.68))
                draw_string(f, Vector2(size.x - 84, oy + 30 * s * 0.55), lab["ra"], HORIZONTAL_ALIGNMENT_RIGHT, 80, 12, Color(0.75, 0.8, 0.68))
                draw_string(f, Vector2(4, oy + 70 * s * 0.55 + 12), lab["ll"], HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.75, 0.8, 0.68))
                draw_string(f, Vector2(size.x - 84, oy + 70 * s * 0.55 + 12), lab["rl"], HORIZONTAL_ALIGNMENT_RIGHT, 80, 12, Color(0.75, 0.8, 0.68))
                if worst.is_empty():
                        draw_string(f, Vector2(10, oy + 78 * s), "Отряд цел — раненых нет", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, Color(0.55, 0.85, 0.55))

# ================= ПАУЗА =================
func toggle_pause() -> void:
        if end_panel != null:
                return
        if pause_win != null and is_instance_valid(pause_win):
                UiKit.close_window(pause_win)
                pause_win = null
                if hq_win == null and med_win == null:
                        battle.paused = false
                return
        battle.paused = true
        var w := UiKit.open_window(self, "ПАУЗА", Vector2(460, 0), true)
        pause_win = w["overlay"]
        var vb: VBoxContainer = w["vb"]
        var resume := _flat_btn("ПРОДОЛЖИТЬ БОЙ", Vector2(380, 52), true, 16)
        resume.pressed.connect(toggle_pause)
        vb.add_child(resume)
        var hq_b := _flat_btn("ШТАБ И СПРАВКА", Vector2(380, 46), false, 15)
        hq_b.pressed.connect(func():
                UiKit.close_window(pause_win)
                pause_win = null
                open_hq("help"))
        vb.add_child(hq_b)
        vb.add_child(_mk_label("Музыка:", 13))
        var mus := HSlider.new()
        mus.min_value = 0.0
        mus.max_value = 1.0
        mus.step = 0.05
        mus.value = G.music_vol
        mus.custom_minimum_size = Vector2(360, 24)
        mus.value_changed.connect(func(v: float): G.set_music_vol(v))
        vb.add_child(mus)
        vb.add_child(_mk_label("Эффекты:", 13))
        var sfx_s := HSlider.new()
        sfx_s.min_value = 0.0
        sfx_s.max_value = 1.0
        sfx_s.step = 0.05
        sfx_s.value = G.sfx_vol
        sfx_s.custom_minimum_size = Vector2(360, 24)
        sfx_s.value_changed.connect(func(v: float): G.set_sfx_vol(v))
        vb.add_child(sfx_s)
        var quit := _flat_btn("ОТСТУПИТЬ В ШТАБ (выход)", Vector2(380, 46), false, 14)
        quit.pressed.connect(func():
                G.write_save()
                UiKit.close_window(pause_win)
                pause_win = null
                battle.paused = false
                if battle.main_ref != null:
                        battle.main_ref.to_campaign_map()
                else:
                        get_tree().paused = false)
        vb.add_child(quit)

func toggle_help() -> void:
        open_hq("help")

# ================= ФИНАЛ =================
func show_end(victory: bool) -> void:
        if pause_win != null and is_instance_valid(pause_win):
                UiKit.close_window(pause_win)
                pause_win = null
        if hq_win != null and is_instance_valid(hq_win):
                UiKit.close_window(hq_win)
                hq_win = null
        if med_win != null and is_instance_valid(med_win):
                UiKit.close_window(med_win)
                med_win = null
        var overlay := Control.new()
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.mouse_filter = Control.MOUSE_FILTER_STOP
        var dim := ColorRect.new()
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.color = Color(0, 0, 0, 0.62)
        overlay.add_child(dim)
        var panel := PanelContainer.new()
        panel.set_anchors_preset(Control.PRESET_CENTER)
        panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
        panel.grow_vertical = Control.GROW_DIRECTION_BOTH
        panel.custom_minimum_size = Vector2(560, 0)
        panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.07, 0.98), UiKit.AMBER if victory else UiKit.RED))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 12)
        panel.add_child(vb)
        vb.add_child(_mk_label("ПОБЕДА" if victory else "ПОРАЖЕНИЕ", 30, Color(0.7, 0.95, 0.6) if victory else Color(0.95, 0.5, 0.4)))
        var s: Dictionary = battle.stats
        vb.add_child(_mk_label("Уничтожено противника: %d\nПотерь: %d\nЗахвачено секторов: %d\nВремя боя: %d мин %d с" % [
                        s["kills"], s["losses"], s["captured"], floori(float(s["time"]) / 60.0), int(s["time"]) % 60], 16))
        if victory:
                if battle.sector_idx >= G.SECTORS.size() - 1:
                        vb.add_child(_mk_label("ОБЪЕКТ «ЗАРЯ» ВЗЯТ. КАМПАНИЯ ЗАВЕРШЕНА, КОМАНДИР.", 16, Color(0.9, 0.85, 0.5)))
                else:
                        vb.add_child(_mk_label("Трофеи перечислены на базу. Двигаемся на север!", 14, Color(0.8, 0.9, 0.6)))
        if victory:
                var next_b := _flat_btn("СЛЕДУЮЩИЙ СЕКТОР →", Vector2(420, 54), true, 16)
                next_b.pressed.connect(func():
                        if battle.main_ref != null:
                                battle.main_ref.after_battle(true))
                vb.add_child(next_b)
        else:
                var retry := _flat_btn("ПОВТОРИТЬ ШТУРМ", Vector2(420, 54), true, 16)
                retry.pressed.connect(func():
                        if battle.main_ref != null:
                                battle.main_ref.after_battle(false))
                vb.add_child(retry)
        var menu := _flat_btn("В ГЛАВНОЕ МЕНЮ", Vector2(420, 46), false, 15)
        menu.pressed.connect(func():
                if battle.main_ref != null:
                        battle.main_ref.to_main_menu())
        vb.add_child(menu)
        overlay.add_child(panel)
        root.add_child(overlay)
        end_panel = overlay

# ================= ЦИКЛ UI =================
func _process(delta: float) -> void:
        if battle == null:
                return
        # модалки закрыли крестиком/тапом мимо → снимаем паузу
        if hq_win != null and not is_instance_valid(hq_win):
                hq_win = null
        if med_win != null and not is_instance_valid(med_win):
                med_win = null
        if pause_win != null and not is_instance_valid(pause_win):
                pause_win = null
        if (hq_win == null and med_win == null and pause_win == null and end_panel == null
                and battle.paused and not battle.cutscene and battle.battle_over == ""):
                battle.paused = false
        # подсветка заголовка рации при новом донесении
        if radio_head_btn != null and radio_flash > 0.0:
                radio_flash -= delta
                radio_head_btn.modulate = Color(1.5, 1.3, 0.8) if radio_flash > 0.0 else Color(1, 1, 1)
        # живое состояние кнопок панели действий
        if btn_order != null:
                var armed: bool = battle.touch_order
                btn_order.text = "ТОЧКА?" if armed else "ПРИКАЗ"
                btn_order.modulate = Color(1.45, 1.3, 0.85) if armed else Color(1, 1, 1)
        if btn_auto != null:
                btn_auto.text = "АВТО ВКЛ" if battle.auto_on else "АВТО ВЫКЛ"
                btn_auto.modulate = Color(1.3, 1.4, 1.2) if battle.auto_on else Color(1, 1, 1, 0.75)
        # контекстная ТЕХНИКА: видна только у машины / в машине
        if btn_veh != null:
                var vs: int = battle.cmdr_veh_state()
                btn_veh.visible = vs != 0
                if vs == 2:
                        btn_veh.text = "ВЫЙТИ"
                elif vs == 1:
                        btn_veh.text = "СЕСТЬ"
        ui_t += delta
        if ui_t < 0.12:
                return
        ui_t = 0.0
        # верхняя строка
        var income: float = 8.0 + 6.0 * battle._points_owned(G.TEAM_PLAYER)
        income *= 1.0 + 0.15 * int(G.save["upgrades"].get("logistics", 0))
        req_label.text = "РКЗ %d  (+%.0f/с)" % [int(battle.req), income]
        ticket_p_label.text = str(maxi(0, int(battle.tickets_player)))
        ticket_e_label.text = str(maxi(0, int(battle.tickets_enemy)))
        ticket_p_bar.custom_minimum_size.x = 120.0 * clampf(battle.tickets_player / 1000.0, 0.0, 1.0)
        ticket_e_bar.custom_minimum_size.x = 120.0 * clampf(battle.tickets_enemy / 1000.0, 0.0, 1.0)
        var s_txt := ""
        for p in battle.points:
                s_txt += p["id"] + ("✓" if p["owner"] == G.TEAM_PLAYER else ("✗" if p["owner"] == G.TEAM_ENEMY else "·")) + " "
        sectors_label.text = s_txt
        # чип командира
        if chip != null and chip.visible and battle.direct_ctrl and is_instance_valid(battle.direct_unit):
                var u = battle.direct_unit
                chip_name.text = ("МАШИНА: " + u.def["name"]) if u.def["kind"] == "veh" else u.def["name"]
                chip_hp.custom_minimum_size.x = 150.0 * clampf(u.hp / u.max_hp, 0.02, 1.0)
                chip_hp.color = Color(0.35, 0.85, 0.4) if u.hp > u.max_hp * 0.5 else Color(0.9, 0.55, 0.25)
                if u.def["kind"] == "veh":
                        chip_ammo.custom_minimum_size.x = 90.0
                        chip_ammo.color = Color(0.6, 0.7, 0.5)
                        chip_state.text = "за рулём"
                else:
                        chip_ammo.custom_minimum_size.x = 90.0 * clampf(u.mags / maxf(1.0, u.mags_max), 0.0, 1.0)
                        chip_ammo.color = Color(0.85, 0.75, 0.3) if u.mags > 1.0 else Color(0.9, 0.3, 0.25)
                        var parts: Array = []
                        if u.jam_t > 0.0:
                                parts.append("ЗАКЛИНИЛО")
                        if u.mags <= 0.05:
                                parts.append("НЕТ ПАТРОНОВ")
                        if u.has_wounded():
                                parts.append("РАНЕНЫЕ")
                        if u.suppression > 40.0:
                                parts.append("ПРИЖАТ")
                        chip_state.text = "  ".join(PackedStringArray(parts))
        # очередь развёртывания в ШТАБе
        if queue_label != null and is_instance_valid(queue_label):
                if battle.deploy_queue.is_empty():
                        queue_label.text = "Очередь: пусто"
                else:
                        var qtxt := "Очередь: "
                        for it in battle.deploy_queue:
                                qtxt += G.DB[it["id"]]["name"] + " %.0fс  " % maxf(0.0, it["t"])
                        queue_label.text = qtxt
        # доступность карточек и кулдауны способностей
        for id in card_buttons:
                var bv = card_buttons[id]
                if bv == null or not is_instance_valid(bv):
                        continue
                var btn: Button = bv
                if id == battle.faction_player + "_heli":
                        btn.disabled = not battle.heli_unlocked
                else:
                        btn.modulate = Color(1, 1, 1, 1) if battle.req >= G.cost_for(id, G.save["kit"]) else Color(1, 1, 1, 0.45)
        for ab in ab_buttons:
                var cd: float = battle.ability_cd.get(ab, 0.0)
                var entry: Dictionary = ab_buttons[ab]
                if not is_instance_valid(entry["btn"]):
                        continue
                if cd > 0.0:
                        entry["cd"].text = "%.0f с" % cd
                        entry["btn"].modulate = Color(1, 1, 1, 0.5)
                else:
                        entry["cd"].text = "%d ркз" % int(G.DB[ab]["cost"])
                        entry["btn"].modulate = Color(1, 1, 1, 1) if battle.req >= G.DB[ab]["cost"] else Color(1, 1, 1, 0.5)
        # санчасть живьём
        if med_win != null:
                _refresh_medic()
        # затухание слуховых маркеров
        for i in range(pings.size() - 1, -1, -1):
                pings[i]["t"] -= 0.12
                if pings[i]["t"] <= 0.0:
                        pings.remove_at(i)
        if minimap:
                minimap.queue_redraw()
        drag_overlay.queue_redraw()

