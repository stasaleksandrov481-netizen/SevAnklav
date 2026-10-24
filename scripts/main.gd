# ============================================================
# ГЛАВНЫЙ ПОТОК ИГРЫ «СЕВЕРНЫЙ АНКЛАВ: ЛИНИЯ ФРОНТА»
# Главное меню (стиль командного пункта), окно НАСТРОЕК по центру
# (масштаб интерфейса, звук, полный экран), окно НОВОЙ КАМПАНИИ
# с карточками фракций/допуска/снаряжения, белое сюжетное интро
# с побуквенным появлением и пропуском зажатием, карта кампании, бой.
# ============================================================
extends Node2D

const BattleScript = preload("res://scripts/battle.gd")
const CampaignScript = preload("res://scripts/campaign_map.gd")
const BunkerStory = preload("res://scripts/bunker_story.gd")
const BattleZScript = preload("res://scripts/battle_z.gd")
const ZCampaignScript = preload("res://scripts/zcampaign_map.gd")
const ZPrologueScript = preload("res://scripts/zprologue.gd")   # старая версия (резерв)
const ZPrologueZarya = preload("res://scripts/zprologue_zarya.gd")  # пролог «ЗАРЯ» (по ТЗ)
const Med = preload("res://scripts/med.gd")

var pending_new_z := false
var boot_loading7_done:=false
var current_screen: Node = null
var battle_node = null
var loading_layer: CanvasLayer = null

const GAME_VER := "СЕВЕРНЫЙ АНКЛАВ · ЗАРЯ 7.0"   # метка сборки — видна в главном меню (правый нижний угол)

func _loading_text(kind: String = "") -> String:
		var lines := [
				"Проверка периметра…",
				"Сборка маршрута…",
				"Проверка сектора…",
				"Сканирование тьмы…",
				"Выносим выживших…",
				"Сверка записей…",
		]
		if kind != "":
				return kind
		return lines[randi() % lines.size()]

func show_loading(message: String = "", min_time: float = 0.5) -> void:
	var boot:=message=="Сверка данных выживших…" and not boot_loading7_done
	var entering:=message.begins_with("СЕКТОР 1 ·")
	if not boot and not entering:
		await get_tree().process_frame
		return
	if boot: boot_loading7_done=true
	if is_instance_valid(loading_layer): loading_layer.queue_free()
	var layer:=CanvasLayer.new();layer.layer=100;add_child(layer);loading_layer=layer
	var screen:=preload("res://scripts/ui/loading_screen.gd").new()
	screen.message=message;screen.entering=entering;layer.add_child(screen)
	await get_tree().create_timer(maxf(3.0,min_time)).timeout
	if not is_instance_valid(screen): return
	await screen.fade_out()
	layer.queue_free()
	if loading_layer==layer: loading_layer=null

func _ready() -> void:
		add_to_group("main_root")   # FIX9: ExitDoor/free_roam ищут контроллер через эту группу
		print("BOOT: ", GAME_VER)   # v2.6: строка в лог — сразу видно, какая сборка запущена
		to_main_menu()
		if OS.get_cmdline_user_args().has("--smoke"):
				_run_smoke_test()
		elif OS.get_cmdline_user_args().has("--smoke2"):
				_run_smoke_test2()
		elif OS.get_cmdline_user_args().has("--smoke3"):
				_run_smoke_test3()
		elif OS.get_cmdline_user_args().has("--shots"):
				_run_shots()
		elif OS.get_cmdline_user_args().has("--zsmoke"):
				_run_zsmoke()
		elif OS.get_cmdline_user_args().has("--zsmoke2"):
				_run_zsmoke2()
		elif OS.get_cmdline_user_args().has("--zshots"):
				_run_zshots()
		elif OS.get_cmdline_user_args().has("--zpro"):
				_run_zpro()
		elif OS.get_cmdline_user_args().has("--zprolog"):
				_run_zprolog_test()
		elif OS.get_cmdline_user_args().has("--zintro"):
				_run_zintro_shots()
		elif OS.get_cmdline_user_args().has("--zjuice"):
				_run_zjuice()
		elif OS.get_cmdline_user_args().has("--zfps"):
				_run_zfps_bench()
		elif OS.get_cmdline_user_args().has("--zdeath"):
				_run_zdeath_repro()
		elif OS.get_cmdline_user_args().has("--dbg"):
				_run_dbg()
		elif OS.get_cmdline_user_args().has("--sim"):
				_run_sim()

func _run_sim() -> void:
		# боевая симуляция: приказы, ИИ, смерти, поворот техники
		await get_tree().create_timer(0.5).timeout
		G.save["commander"] = "ТЕСТ"
		start_battle()
		await get_tree().create_timer(1.0).timeout
		if battle_node.cutscene:
				battle_node._finish_cutscene(true)
		await get_tree().create_timer(1.0).timeout
		# телепортируем группу к центру и посылаем в атаку
		var my := []
		for u in battle_node.units:
				if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER:
						my.append(u)
		var i0 := 0
		for u in my:
				u.global_position = Vector2(30.5 * battle_node.TS + (i0 - 3) * 90.0, 26.0 * battle_node.TS)
				i0 += 1
				u.set_order_amove(battle_node.fob_enemy + Vector2(randf_range(-300, 300), 200))
		var tank = null
		for u in my:
				if u.def["kind"] == "veh":
						tank = u
						break
		var t := 0.0
		var rot_seen := false
		while t < 70.0:
				await get_tree().create_timer(0.5).timeout
				t += 0.5
				if tank != null and is_instance_valid(tank) and tank.alive:
						if absf(tank.hull.rotation) > 0.2:
								rot_seen = true
		var kills: int = battle_node.stats["kills"]
		var losses: int = battle_node.stats["losses"]
		var alive_p := 0
		var alive_e := 0
		var corpses := 0
		for u in battle_node.units:
				if is_instance_valid(u) and u.alive:
						if u.team == G.TEAM_PLAYER:
								alive_p += 1
						else:
								alive_e += 1
		for dn in battle_node.decay_nodes:
				if is_instance_valid(dn["node"]):
						corpses += 1
		print("SIM: kills=", kills, " losses=", losses, " aliveP=", alive_p, " aliveE=", alive_e)
		print("SIM: veh hull rotated = ", rot_seen)
		print("SIM: decay nodes (corpses/wrecks/decals) = ", corpses)
		print("SIM: req=", int(battle_node.req), " ai_req=", int(battle_node.ai.req))
		print("SIM: DONE")
		get_tree().quit(0)

func _run_dbg() -> void:
		await get_tree().create_timer(1.5).timeout
		var ui := current_screen
		for c in ui.get_children():
				if c is Control:
						for cc in (c as Control).get_children():
								if cc is VBoxContainer:
										print("DBG vbox found, children=", (cc as VBoxContainer).get_child_count())
										for b in (cc as VBoxContainer).get_children():
												if b is Control:
														print("  - ", b.get_class(), " txt=", b.get("text"), " size=", (b as Control).size, " min=", (b as Control).custom_minimum_size, " visible=", (b as Control).visible, " a=%.2f" % (b as Control).modulate.a, " pos=", (b as Control).position)
		get_tree().quit(0)

# ================= СКРИНШОТЫ ДЛЯ ПРОВЕРКИ (флаг --shots) =================
func _shot(shot_name: String) -> void:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("/home/z/my-project/shots/" + shot_name + ".png")
		print("SHOT: ", shot_name)

func _run_shots() -> void:
		await get_tree().create_timer(1.4).timeout
		await _shot("01_menu")
		_open_settings(current_screen)
		await get_tree().create_timer(0.7).timeout
		await _shot("02_settings")
		_close_last_window()
		await get_tree().create_timer(0.4).timeout
		_open_contract(current_screen)
		await get_tree().create_timer(0.7).timeout
		await _shot("03_contract")
		_close_last_window()
		await get_tree().create_timer(0.4).timeout
		G.save["commander"] = "ГРОМ"
		_play_intro()
		await get_tree().create_timer(3.5).timeout
		await _shot("04_intro")
		to_campaign_map()
		await get_tree().create_timer(1.0).timeout
		await _shot("05_campaign")
		start_battle()
		await get_tree().create_timer(4.0).timeout
		await _shot("06_cutscene")
		await get_tree().create_timer(6.0).timeout
		await _shot("07_battle_ready")
		# 1.6: режим командира уже включён — стики видны, идём вперёд
		battle_node.direct_vec = Vector2(0.2, -1)
		await get_tree().create_timer(1.5).timeout
		await _shot("08_direct")
		# прицел: держим правый стик в сторону — виден crosshair
		battle_node.direct_vec = Vector2.ZERO
		battle_node.manual_aim = true
		battle_node.manual_ang = -PI / 5.0
		await get_tree().create_timer(0.5).timeout
		await _shot("10_aim")
		battle_node.manual_aim = false
		# окно ЗДОРОВЬЯ: схема тела + инвентарь (перетаскивание)
		battle_node.ui.open_medic()
		await get_tree().create_timer(0.7).timeout
		await _shot("11_health")
		UiKit.close_window(battle_node.ui.med_win)
		battle_node.ui.med_win = null
		battle_node.paused = false
		await get_tree().create_timer(0.4).timeout
		battle_node.toggle_direct()   # штаб: рамка выделения и приказы
		for u in battle_node.units:
				if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER:
						u.selected = true
						u.ring.visible = true
						battle_node.selection.append(u)
		battle_node.zoom_by(0.7)
		await get_tree().create_timer(1.2).timeout
		await _shot("09_staff")
		print("SHOTS DONE")
		get_tree().quit(0)

# ================= СМОК-ТЕСТ (только с флагом --smoke) =================
func _find_button_by_text(txt: String) -> Button:
		if current_screen == null:
				return null
		var stack: Array = [current_screen]
		while not stack.is_empty():
				var n: Node = stack.pop_back()
				for c in n.get_children():
						stack.append(c)
				if n is Button and (n as Button).text == txt:
						return n
		return null

func _run_smoke_test() -> void:
		print("SMOKE: menu ok")
		await get_tree().create_timer(0.6).timeout
		# --- проверка РЕАЛЬНОЙ кнопки «НОВАЯ КАМПАНИЯ» (как жмёт игрок) ---
		var nb := _find_button_by_text("НОВАЯ КАМПАНИЯ")
		if nb != null:
				nb.pressed.emit()
				await get_tree().create_timer(0.5).timeout
				var opened := false
				for c in current_screen.get_children():
						if c is Control and c.has_meta("panel"):
								opened = true
				print("SMOKE: НОВАЯ КАМПАНИЯ button opens contract window = ", opened)
				_close_last_window()
				await get_tree().create_timer(0.4).timeout
		else:
				print("SMOKE: !!! НОВАЯ КАМПАНИЯ BUTTON NOT FOUND")
		# --- проверка кнопки «КАК ИГРАТЬ» ---
		var hb := _find_button_by_text("КАК ИГРАТЬ")
		if hb != null:
				hb.pressed.emit()
				await get_tree().create_timer(0.4).timeout
				var help_ok := false
				for c in current_screen.get_children():
						if c is Control and c.has_meta("panel"):
								help_ok = true
				print("SMOKE: help window opened = ", help_ok)
				_close_last_window()
				await get_tree().create_timer(0.4).timeout
		_open_settings(current_screen)
		await get_tree().create_timer(0.5).timeout
		_close_last_window()
		print("SMOKE: settings ok")
		await get_tree().create_timer(0.4).timeout
		_open_contract(current_screen)
		await get_tree().create_timer(0.5).timeout
		_close_last_window()
		print("SMOKE: contract ok")
		G.save["commander"] = "ТЕСТ"
		_play_intro()
		print("SMOKE: intro ok")
		await get_tree().create_timer(1.6).timeout
		to_campaign_map()
		print("SMOKE: campaign map ok")
		await get_tree().create_timer(0.8).timeout
		start_battle()
		print("SMOKE: battle started, cutscene = ", battle_node.cutscene)
		await get_tree().create_timer(3.0).timeout
		if battle_node != null and battle_node.cutscene:
				battle_node._finish_cutscene(true)
				print("SMOKE: cutscene skipped ok, units = ", battle_node.units.size())
		await get_tree().create_timer(1.0).timeout
		if battle_node != null:
				# 1.6: режим командира включается сам после катсцены
				print("SMOKE: cmdr exists = ", is_instance_valid(battle_node.cmdr))
				print("SMOKE: commander mode auto-on = ", battle_node.direct_ctrl)
				print("SMOKE: territory module = ", battle_node.territory != null and battle_node.territory.tex != null)
				# левый стик двигает командира
				if battle_node.direct_ctrl:
						battle_node.direct_vec = Vector2(0, -1)
				await get_tree().create_timer(1.5).timeout
				if battle_node.direct_unit != null and is_instance_valid(battle_node.direct_unit):
						print("SMOKE: cmdr moved to ", battle_node.direct_unit.global_position)
				# штаб (F) и обратно
				battle_node.toggle_direct()
				print("SMOKE: staff mode = ", not battle_node.direct_ctrl)
				battle_node.toggle_direct()
				print("SMOKE: back to cmdr = ", battle_node.direct_ctrl)
				battle_node._exit_direct()
				# --- ПОСАДКА: пехота садится в технику ---
				battle_node.auto_on = false
				var inf_u = null
				var veh_u = null
				for u in battle_node.units:
						if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER:
								if u.def["kind"] == "inf" and not u.def.get("hero", false) and inf_u == null:
										inf_u = u
								if u.def["kind"] == "veh" and battle_node.veh_capacity(u.def) > 0 and veh_u == null and u.passengers.is_empty():
										veh_u = u
				if inf_u != null and veh_u != null:
						battle_node.selection = [inf_u]
						battle_node.issue_board(veh_u)
						await get_tree().create_timer(8.0).timeout
						print("SMOKE: inf mounted = ", is_instance_valid(inf_u) and inf_u.mounted_in != null)
						if is_instance_valid(inf_u) and inf_u.mounted_in != null:
								inf_u.dismount()
								print("SMOKE: dismount ok = ", inf_u.mounted_in == null)
				else:
						print("SMOKE: !!! no inf/veh for boarding test")
				# территория должна проступить
				if battle_node.territory != null:
						print("SMOKE: territory share_p = %.3f" % battle_node.territory.share_p)
				# --- проверка сенсорного приказа (кнопка ПРИКАЗ) ---
				print("SMOKE: ui order_btn exists = ", battle_node.ui != null and battle_node.ui.btn_order != null)
				battle_node.touch_order = true
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				ev.position = Vector2(800, 450)
				battle_node._unhandled_input(ev)
				print("SMOKE: touch order issued (touch_order now false) = ", not battle_node.touch_order)
				# --- окно ШТАБА и САНАЧАСТЬ открываются и закрываются ---
				if battle_node.ui != null:
						battle_node.ui.open_hq("deploy")
						await get_tree().create_timer(0.5).timeout
						print("SMOKE: hq window = ", battle_node.ui.hq_win != null and is_instance_valid(battle_node.ui.hq_win))
						battle_node.ui.open_medic()
						await get_tree().create_timer(0.5).timeout
						print("SMOKE: medic window = ", battle_node.ui.med_win != null and is_instance_valid(battle_node.ui.med_win))
						if is_instance_valid(battle_node.ui.hq_win):
								UiKit.close_window(battle_node.ui.hq_win)
						if is_instance_valid(battle_node.ui.med_win):
								UiKit.close_window(battle_node.ui.med_win)
						await get_tree().create_timer(0.4).timeout
						print("SMOKE: hq/medic closed, paused = ", battle_node.paused)
		print("SMOKE: ALL OK")
		get_tree().quit(0)

func _run_smoke_test2() -> void:
		# полный прогон катсцены без пропуска
		await get_tree().create_timer(0.5).timeout
		G.save["commander"] = "ТЕСТ"
		start_battle()
		var t0 := 0.0
		while battle_node != null and battle_node.cutscene and t0 < 20.0:
				await get_tree().create_timer(0.5).timeout
				t0 += 0.5
		print("SMOKE2: cutscene ended naturally at ~%.1fs" % t0)
		if battle_node != null:
				var pn := 0
				for u in battle_node.units:
						if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER:
								pn += 1
				print("SMOKE2: player units on field = ", pn)
				print("SMOKE2: convoy left = ", battle_node.convoy.size())
		print("SMOKE2: ALL OK")
		get_tree().quit(0)

func _run_smoke_test3() -> void:
		# ХАРДКОР-СМОК: анатомия, twin-stick, боеприпасы, детонация, эвакуация
		await get_tree().create_timer(0.5).timeout
		G.save["commander"] = "ТЕСТ"
		start_battle()
		await get_tree().create_timer(2.0).timeout
		if battle_node != null and battle_node.cutscene:
				battle_node._finish_cutscene(true)
		await get_tree().create_timer(1.0).timeout
		if battle_node == null:
				print("SMOKE3: FAIL no battle")
				get_tree().quit(1)
				return
		var b = battle_node
		# --- 1. анатомия: раним пехоту, проверяем зоны/кровотечение/лечение ---
		var inf = null
		for u in b.units:
				if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and u.def["kind"] == "inf" and not u.soldiers.is_empty():
						inf = u
						break
		if inf != null:
				var st0: Dictionary = inf.soldiers[0]["st"]
				var zones0: int = st0["body"].size()
				print("SMOKE3: body zones = ", zones0, " (need 6)")
				var had_wound := false
				for i in range(8):
						inf.take_damage(30.0, "kinetic", null)
				for s in inf.soldiers:
						if s["alive"] and ((s["st"] as Dictionary)["wounds"].size() > 0 or (s["st"] as Dictionary)["frac"].size() > 0):
								had_wound = true
				print("SMOKE3: wounds after 8 hits = ", had_wound, " hp=", int(inf.hp), "/", int(inf.max_hp))
				print("SMOKE3: has_wounded() = ", inf.has_wounded())
				# лечение по этапам
				var treated := false
				for s in inf.soldiers:
						if not s["alive"]:
								continue
						var it: String = b.Med.worst_item(s)
						if it != "":
								var res: String = b.Med.treat(s, it)
								if res == "":
										treated = true
										break
				print("SMOKE3: staged treat works = ", treated)
		else:
				print("SMOKE3: !!! no player inf found")
		# --- 2. twin-stick: прямое управление + ручной огонь ---
		var tgt_unit = null
		for u in b.units:
				if is_instance_valid(u) and u.alive and u.team == G.TEAM_PLAYER and u.def["kind"] == "inf":
						tgt_unit = u
						break
		if tgt_unit != null:
				b.selection = [tgt_unit]
				# с 1.6 игра стартует в режиме командира — выходим и встаём
				# за выбранного бойца напрямую (toggle вернул бы командира)
				if b.direct_ctrl:
						b._exit_direct()
				b._switch_direct_to(tgt_unit)
				print("SMOKE3: direct_ctrl = ", b.direct_ctrl, " zoom=", b.cam_zoom)
				# ручной прицел и огонь (в пустоту — тракти тоже тратят боезапас)
				var e_visible = null
				for e in b.units:
						if is_instance_valid(e) and e.alive and e.team == G.TEAM_ENEMY and b.is_visible_to_player(e):
								e_visible = e
								break
				if e_visible != null:
						b.manual_ang = (e_visible.global_position - tgt_unit.global_position).angle()
				else:
						b.manual_ang = 0.0
				b.manual_aim = true
				b.manual_fire = true
				var m0: float = tgt_unit.mags
				await get_tree().create_timer(1.2).timeout
				if is_instance_valid(tgt_unit) and tgt_unit.alive:
						print("SMOKE3: manual fire drained mags: ", tgt_unit.mags, " < ", m0, " = ", tgt_unit.mags < m0)
				else:
						print("SMOKE3: manual fire unit died in contact (ok)")
				b.manual_fire = false
				b.manual_aim = false
				b._exit_direct()
		# --- 3. ящик снабжения + пополнение ---
		if tgt_unit != null and is_instance_valid(tgt_unit) and tgt_unit.alive:
				tgt_unit.mags = 0.5
				b.spawn_crate(tgt_unit.global_position)
				await get_tree().create_timer(0.5).timeout
				print("SMOKE3: crate resupply = ", tgt_unit.mags >= tgt_unit.mags_max * 0.98)
		# --- 4. детонация боекомплекта: убиваем технику с боеукладом ---
		var veh = null
		for u in b.units:
				if is_instance_valid(u) and u.alive and u.team == G.TEAM_ENEMY and u.def["kind"] == "veh":
						if u.def["armor"] in ["med", "heavy"] or u.def.get("cargo", false):
								veh = u
								break
						if veh == null:
								veh = u
		if veh != null:
				if not (veh.def["armor"] in ["med", "heavy"] or veh.def.get("cargo", false)):
						veh.def["cargo"] = true   # тест: считаем боеуклад
				b.on_unit_died(veh, null)
				print("SMOKE3: cook-off pending booms = ", b.pending_booms.size() > 0)
		await get_tree().create_timer(2.0).timeout
		# --- 5. FOV: экранная функция не падает ---
		if b.direct_unit == null and tgt_unit != null and is_instance_valid(tgt_unit):
				b.direct_unit = tgt_unit
				b.ui.update_fov_hud(tgt_unit.global_position, 0.0)
				b.ui.add_sound_ping(tgt_unit.global_position + Vector2(300, 0))
				print("SMOKE3: fov hud + sound ping ok")
				b.direct_unit = null
		print("SMOKE3: ALL OK")
		get_tree().quit(0)

func _close_last_window() -> void:
		if current_screen == null:
				return
		for c in current_screen.get_children():
				if c is Control and c.has_meta("panel"):
						UiKit.close_window(c)
						return

# ================= ОЧИСТКА ЭКРАНОВ =================
func _clear() -> void:
		if battle_node != null and is_instance_valid(battle_node):
				battle_node.queue_free()
				battle_node = null
		if current_screen != null and is_instance_valid(current_screen):
				current_screen.queue_free()
				current_screen = null

# ================= ГЛАВНОЕ МЕНЮ =================
func to_main_menu() -> void:
				_to_main_menu()

func _to_main_menu() -> void:
		# FIX9: меню — это СЦЕНА (scenes/ui/MainMenu.tscn). Открой её в
		# редакторе и двигай кнопки/панели мышью; main.gd только слушает
		# сигналы экрана и выполняет переходы.
		await show_loading("Сверка данных выживших…", 0.4)
		_clear()
		var mm := preload("res://scenes/ui/MainMenu.tscn").instantiate()
		current_screen = mm
		add_child(mm)
		mm.play_pressed.connect(func():
				G.play_sfx("ui_click", -6.0)
				pending_new_z = true
				_open_campaign_select(mm))
		mm.continue_pressed.connect(func():
				pending_new_z = false
				start_z_campaign())
		mm.load_pressed.connect(func():
				pending_new_z = false
				_open_campaign_select(mm))
		mm.mil_pressed.connect(func():
				G.play_sfx("ui_click", -6.0)
				_open_terminal(mm))
		mm.settings_pressed.connect(func():
				G.play_sfx("ui_click", -6.0)
				_open_settings(mm))
		mm.help_pressed.connect(func():
				G.play_sfx("ui_click", -6.0)
				_open_help(mm))
		mm.quit_pressed.connect(func():
				G.write_save()
				get_tree().quit())


# ================= ВЫБОР КАМПАНИИ (FIX7v2: одна кнопка ИГРАТЬ) =================
func _open_campaign_select(parent_ui: CanvasLayer) -> void:
		preload("res://scripts/ui/cinematic_pages.gd").open(self,parent_ui,"campaign")

func _campaign_card(row: HBoxContainer, img: String, title: String, title_col: Color, status: String, status_col: Color, desc: String, meta: String, btn_txt: String, on_press: Callable) -> PanelContainer:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(540, 0)
		var csb := UiKit.panel_style(Color(0.075, 0.082, 0.066, 0.97), UiKit.BORDER_SOFT, 0)
		csb.set_corner_radius_all(12)
		csb.border_width_top = 2
		csb.border_color = Color(UiKit.BORDER.r, UiKit.BORDER.g, UiKit.BORDER.b, 0.9)
		card.add_theme_stylebox_override("panel", csb)
		row.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		card.add_child(v)
		# изображение кампании
		var tex := G.tex(img)
		if tex != null:
				var tr := TextureRect.new()
				tr.texture = tex
				tr.custom_minimum_size = Vector2(540, 226)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				tr.clip_contents = true
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				v.add_child(tr)
				# тонкая линия-разделитель под картинкой
				var dv := UiKit.hdivider(2, UiKit.BORDER_SOFT)
				v.add_child(dv)
		else:
				var ph := ColorRect.new()
				ph.color = Color(0.10, 0.11, 0.09)
				ph.custom_minimum_size = Vector2(540, 120)
				v.add_child(ph)
		var pad := VBoxContainer.new()
		pad.add_theme_constant_override("separation", 8)
		var pm := MarginContainer.new()
		pm.add_theme_constant_override("margin_left", 18)
		pm.add_theme_constant_override("margin_right", 18)
		pm.add_theme_constant_override("margin_top", 12)
		pm.add_theme_constant_override("margin_bottom", 16)
		v.add_child(pm)
		pm.add_child(pad)
		# статус
		var st := UiKit.label(status, 12, status_col)
		pad.add_child(st)
		# заголовок
		var tl := UiKit.label(title, 26, title_col)
		pad.add_child(tl)
		# описание (без спойлеров)
		var dl := UiKit.label(desc, 13, UiKit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(500, 0)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(dl)
		# прогресс/мета
		var ml := UiKit.label(meta, 12, UiKit.FAINT)
		pad.add_child(ml)
		# кнопка
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		pad.add_child(brow)
		var b := UiKit.MilButton.new(btn_txt, Vector2(460, 54), title_col == UiKit.AMBER_BRIGHT, 16)
		b.pressed.connect(on_press)
		brow.add_child(b)
		return card

# ================= НАСТРОЙКИ (окно по центру) =================
func _open_settings(parent_ui: CanvasLayer) -> void:
		preload("res://scripts/ui/cinematic_pages.gd").open(self,parent_ui,"settings")

func _style_slider(sl: HSlider) -> void:
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = Color(0.05, 0.055, 0.045)
		bg_sb.border_color = UiKit.BORDER_SOFT
		bg_sb.set_border_width_all(1)
		bg_sb.set_corner_radius_all(3)
		bg_sb.content_margin_top = 5
		bg_sb.content_margin_bottom = 5
		var fg_sb := StyleBoxFlat.new()
		fg_sb.bg_color = UiKit.AMBER
		fg_sb.set_corner_radius_all(3)
		fg_sb.content_margin_top = 5
		fg_sb.content_margin_bottom = 5
		sl.add_theme_stylebox_override("slider", bg_sb)
		sl.add_theme_stylebox_override("grabber_area", fg_sb)
		sl.add_theme_stylebox_override("grabber_area_highlight", fg_sb)

# ================= КАК ИГРАТЬ (окно по центру) =================
func _open_help(parent_ui: CanvasLayer) -> void:
	preload("res://scripts/ui/cinematic_pages.gd").open(self,parent_ui,"help")

# ================= НОВАЯ КАМПАНИЯ (окно по центру) =================
var _fac_sel := 0
var _diff_sel := 1
var _kit_sel := 0

func _open_contract(parent_ui: CanvasLayer) -> void:
		_fac_sel = ["sak", "foa", "jack"].find(G.save["faction"])
		if _fac_sel < 0:
				_fac_sel = 0
		_diff_sel = int(G.save["difficulty"])
		_kit_sel = int(G.save["kit"])
		var w := UiKit.open_window(parent_ui, "РЕГИСТРАЦИЯ КОНТРАКТА", Vector2(760, 0))
		var vb: VBoxContainer = w["vb"]
		vb.add_child(UiKit.label("Карта допуска командира. Группа будет доставлена конвоем к южному рубежу.", 13, UiKit.MUTED))
		# ----- позывной -----
		var name_l := UiKit.label("ПОЗЫВНОЙ КОМАНДИРА", 13, UiKit.TEXT)
		vb.add_child(name_l)
		var name_edit := LineEdit.new()
		name_edit.text = G.save["commander"]
		name_edit.placeholder_text = "введите позывной"
		name_edit.max_length = 14
		name_edit.custom_minimum_size = Vector2(700, 42)
		name_edit.add_theme_font_size_override("font_size", 16)
		var le_sb := StyleBoxFlat.new()
		le_sb.bg_color = Color(0.05, 0.055, 0.045)
		le_sb.border_color = UiKit.BORDER
		le_sb.set_border_width_all(1)
		le_sb.set_corner_radius_all(3)
		le_sb.content_margin_left = 12
		le_sb.content_margin_right = 12
		var le_f: StyleBoxFlat = le_sb.duplicate()
		le_f.border_color = UiKit.AMBER
		name_edit.add_theme_stylebox_override("normal", le_sb)
		name_edit.add_theme_stylebox_override("focus", le_f)
		name_edit.add_theme_color_override("font_color", UiKit.TEXT)
		name_edit.add_theme_color_override("caret_color", UiKit.AMBER_BRIGHT)
		vb.add_child(name_edit)
		# ----- фракция -----
		vb.add_child(_section_head("ВООРУЖЁННАЯ ГРУППА"))
		var fac_row := HBoxContainer.new()
		fac_row.add_theme_constant_override("separation", 10)
		vb.add_child(fac_row)
		var fac_data := [
				["sak", "САК", "Регулярный корпус. Танки, БТР и артиллерия — прямая линия фронта."],
				["foa", "ФОА", "Ополчение фронта. Дешёвые отряды, мины, засады и технички."],
				["jack", "«ШАКАЛ»", "Наёмный синдикат. Натовская техника, точность, дорого."],
		]
		var fac_btns: Array = []
		for fi in range(3):
				var fd: Array = fac_data[fi]
				var card := _make_card(fd[1], fd[2], 44)
				var cvb: VBoxContainer = card.get_child(0)
				var em := UiKit.FactionEmblem.new(fd[0], 32)
				cvb.add_child(em)
				cvb.move_child(em, 0)
				card.pressed.connect(func():
						G.play_sfx("ui_click", -10.0, 1.2)
						_fac_sel = fi
						_refresh_cards(fac_btns, _fac_sel))
				fac_btns.append(card)
				fac_row.add_child(card)
		# ----- допуск -----
		vb.add_child(_section_head("ДОПУСК ШТАБА — СИЛА ПРОТИВНИКА"))
		var diff_row := HBoxContainer.new()
		diff_row.add_theme_constant_override("separation", 10)
		vb.add_child(diff_row)
		var diff_data := [
				["РЯДОВОЙ", 1, "Учебный допуск: противник осторожен, цены обычные."],
				["ВЕТЕРАН", 2, "Боевой допуск: противник бьёт гораздо больнее, снабжение дороже."],
				["АНКЛАВ", 3, "Штурмовой допуск: противник безжалостен. Одна ошибка стоит боя."],
		]
		var diff_btns: Array = []
		for di in range(3):
				var dd: Array = diff_data[di]
				var bars := ""
				for b in range(3):
						bars += "▮" if b < int(dd[1]) else "▯"
				var card := _make_card(dd[0], dd[2], 44)
				var cvb2: VBoxContainer = card.get_child(0)
				var bars_l := UiKit.label(bars, 20, UiKit.AMBER_BRIGHT)
				cvb2.add_child(bars_l)
				cvb2.move_child(bars_l, 0)
				card.pressed.connect(func():
						G.play_sfx("ui_click", -10.0, 1.2)
						_diff_sel = di
						_refresh_cards(diff_btns, _diff_sel))
				diff_btns.append(card)
				diff_row.add_child(card)
		# ----- снаряжение -----
		vb.add_child(_section_head("СНАРЯЖЕНИЕ ГРУППЫ"))
		var kit_row := HBoxContainer.new()
		kit_row.add_theme_constant_override("separation", 10)
		vb.add_child(kit_row)
		var kit_btns: Array = []
		for ki in range(3):
				var kd: Dictionary = G.START_KITS[ki]
				var card := _make_card(kd["name"], kd["desc"], 44)
				var cvb3: VBoxContainer = card.get_child(0)
				var mark := UiKit.label("✚", 22, UiKit.OK)
				cvb3.add_child(mark)
				cvb3.move_child(mark, 0)
				card.pressed.connect(func():
						G.play_sfx("ui_click", -10.0, 1.2)
						_kit_sel = ki
						_refresh_cards(kit_btns, _kit_sel))
				kit_btns.append(card)
				kit_row.add_child(card)
		# хардкор
		var hc := UiKit.label("Хардкор-механики (медицина, снабжение, окопы) включены всегда.", 11, UiKit.FAINT)
		vb.add_child(hc)
		var err := UiKit.label("", 13, UiKit.RED)
		vb.add_child(err)
		# ----- кнопки -----
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 12)
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(brow)
		var back := UiKit.MilButton.new("НАЗАД", Vector2(200, 54), false, 15)
		back.pressed.connect(func(): UiKit.close_window(w["overlay"]))
		brow.add_child(back)
		var start := UiKit.MilButton.new("ПОДПИСАТЬ КОНТРАКТ", Vector2(400, 54), true, 17)
		start.pressed.connect(func():
				var nm: String = name_edit.text.strip_edges()
				if nm.is_empty():
						err.text = "Введите позывной командира — без него контракт не подпишут."
						return
				G.save["commander"] = nm
				G.save["faction"] = ["sak", "foa", "jack"][_fac_sel]
				G.save["difficulty"] = _diff_sel
				G.save["kit"] = _kit_sel
				G.save["sector"] = 0
				G.save["bank"] = 0
				G.save["wins"] = 0
				G.save["battles"] = 0
				G.save["heli_unlocked"] = false
				G.save["campaign_won"] = false
				G.save["upgrades"] = {"logistics": 0, "scouts": false, "repair": false, "prep": false, "trophy": false}
				G.write_save()
				UiKit.close_window(w["overlay"])
				_play_intro())
		brow.add_child(start)
		# начальные выделения
		_refresh_cards(fac_btns, _fac_sel)
		_refresh_cards(diff_btns, _diff_sel)
		_refresh_cards(kit_btns, _kit_sel)

func _section_head(txt: String) -> Control:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var mark := ColorRect.new()
		mark.color = UiKit.AMBER
		mark.custom_minimum_size = Vector2(5, 18)
		hb.add_child(mark)
		var l := UiKit.label(txt, 15, UiKit.TEXT)
		hb.add_child(l)
		var line := UiKit.hdivider(1, UiKit.BORDER_SOFT)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(line)
		return hb

func _make_card(title: String, desc: String, _min_h := 44) -> Button:
		var card := Button.new()
		card.custom_minimum_size = Vector2(226, 136)
		card.focus_mode = Control.FOCUS_NONE
		card.clip_contents = false
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 10
		vb.offset_right = -10
		vb.offset_top = 8
		vb.offset_bottom = -8
		vb.add_theme_constant_override("separation", 4)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vb)
		var tl := UiKit.label(title, 16, UiKit.TEXT)
		vb.add_child(tl)
		var dl := UiKit.wrap_label(desc, 11, UiKit.MUTED, 206.0)
		dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(dl)
		card.set_meta("title_l", tl)
		card.mouse_entered.connect(func():
				if not card.has_meta("sel"):
						G.play_sfx("ui_click", -22.0, 1.8))
		return card

func _refresh_cards(btns: Array, sel: int) -> void:
		for i in range(btns.size()):
				var b: Button = btns[i]
				var sb := StyleBoxFlat.new()
				if i == sel:
						sb.bg_color = Color(0.16, 0.15, 0.10)
						sb.border_color = UiKit.AMBER
						sb.set_border_width_all(2)
						var tl: Label = b.get_meta("title_l")
						tl.add_theme_color_override("font_color", UiKit.AMBER_BRIGHT)
						b.set_meta("sel", true)
				else:
						sb.bg_color = Color(0.10, 0.11, 0.088)
						sb.border_color = UiKit.BORDER_SOFT
						sb.set_border_width_all(1)
						var tl2: Label = b.get_meta("title_l")
						tl2.add_theme_color_override("font_color", UiKit.TEXT)
						if b.has_meta("sel"):
								b.remove_meta("sel")
				sb.set_corner_radius_all(4)
				sb.content_margin_left = 4
				sb.content_margin_right = 4
				sb.content_margin_top = 4
				sb.content_margin_bottom = 4
				b.add_theme_stylebox_override("normal", sb)
				var sbh: StyleBoxFlat = sb.duplicate()
				sbh.bg_color = sb.bg_color.lightened(0.05)
				sbh.border_color = UiKit.BORDER if i != sel else UiKit.AMBER_BRIGHT
				b.add_theme_stylebox_override("hover", sbh)
				b.add_theme_stylebox_override("pressed", sbh)
		# авто-переключатель подписи к допуску не нужен: карточки сами описывают

# ================= ИНТРО: БЕЛЫЙ ТЕКСТ ПО ЦЕНТРУ =================
func _play_intro() -> void:
		_clear()
		var ui := CanvasLayer.new()
		ui.layer = 10
		current_screen = ui
		add_child(ui)
		var overlay := Control.new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(overlay)
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.012, 0.012, 0.01)
		overlay.add_child(bg)
		# вертикальная композиция по центру экрана
		var mid := VBoxContainer.new()
		mid.set_anchors_preset(Control.PRESET_CENTER)
		mid.offset_left = -560
		mid.offset_right = 560
		mid.offset_top = -240
		mid.offset_bottom = 240
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		mid.add_theme_constant_override("separation", 22)
		overlay.add_child(mid)
		var head := UiKit.label("СЕВЕРНЫЙ АНКЛАВ · 2029", 15, Color(0.55, 0.55, 0.5))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_child(head)
		var tdiv := UiKit.hdivider()
		tdiv.custom_minimum_size = Vector2(180, 2)
		tdiv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mid.add_child(tdiv)
		# белый текст, побуквенно
		var txt := UiKit.label("", 23, Color(0.95, 0.95, 0.92))
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.custom_minimum_size = Vector2(1120, 320)
		mid.add_child(txt)
		var story: String = "Электромагнитный удар оставил Северный анклав без связи и света.\n\nЦентральная власть пала, и арсенал «Заря» стал призом, за который дерутся три силы.\n\nВы — командир ударной группы «%s». Позывной — «%s».\n\nКонвой везёт вашу группу к южному рубежу. Двадцать секторов на север — и вы у цели.\n\nПриказ один: взять сектора боем." % [
				G.FACTION_NAMES[G.save["faction"]].split(" — ")[0], G.save["commander"]]
		# пропустить зажатием
		var skip := UiKit.HoldButton.new("ЗАЖМИТЕ, ЧТОБЫ ПРОПУСТИТЬ", 0.9)
		skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		skip.offset_left = -190
		skip.offset_right = 190
		skip.offset_top = -78
		skip.offset_bottom = -34
		overlay.add_child(skip)
		# появление чёрного экрана, затем печатная машинка
		overlay.modulate.a = 0.0
		var fin := func():
				if not is_instance_valid(overlay) or overlay.has_meta("finished"):
						return
				overlay.set_meta("finished", true)
				var ftw := overlay.create_tween()
				ftw.tween_property(overlay, "modulate:a", 0.0, 0.7)
				ftw.tween_callback(to_campaign_map)
		skip.pressed.connect(func():
				G.play_sfx("ui_click", -10.0)
				fin.call())
		var tw := overlay.create_tween()
		tw.tween_property(overlay, "modulate:a", 1.0, 0.5)
		tw.tween_interval(0.4)
		tw.tween_callback(func():
				var idx: Dictionary = {"i": 0}
				var timer := Timer.new()
				timer.wait_time = 0.028
				timer.autostart = true
				timer.timeout.connect(func():
						idx["i"] += 1
						txt.text = story.substr(0, idx["i"])
						if idx["i"] % 7 == 0:
								G.play_sfx("ui_click", -26.0, 2.3)
						if idx["i"] >= story.length():
								timer.stop()
								var t2 := get_tree().create_timer(3.2)
								t2.timeout.connect(func():
										if is_instance_valid(overlay) and not skip.hold_done:
												fin.call()))
				overlay.add_child(timer))

# ================= ТЕРМИНАЛ: ВОЕННАЯ КАМПАНИЯ ЗАМОРОЖЕНА =================
func _open_terminal(parent_ui: CanvasLayer) -> void:
		var w := UiKit.open_window(parent_ui, "ТЕРМИНАЛ ШТАБА · ЛИНИЯ СВЯЗИ", Vector2(760, 0))
		var vb: VBoxContainer = w["vb"]
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.015, 0.035, 0.02)
		sb.border_color = Color(0.3, 0.65, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		box.add_theme_stylebox_override("panel", sb)
		box.custom_minimum_size = Vector2(700, 0)
		vb.add_child(box)
		var tb := VBoxContainer.new()
		tb.add_theme_constant_override("separation", 10)
		box.add_child(tb)
		var l1 := UiKit.label("[ДОСТУП ЗАБЛОКИРОВАН ГЕНЕРАЛЬНЫМ ШТАБОМ]", 17, Color(0.55, 0.95, 0.6))
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.add_child(l1)
		tb.add_child(UiKit.hdivider(1, Color(0.25, 0.5, 0.32)))
		var l2 := UiKit.label("Сектор временно запечатан из-за высокого уровня радиационного заражения\nи активных боевых действий сил САК и ФОА.\nОжидайте приказа командования после стабилизации северного фронта.", 15, Color(0.75, 0.9, 0.78))
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.add_child(l2)
		var l3 := UiKit.label("// СТАТУС: ПРОТОКОЛ В РАЗРАБОТКЕ", 14, Color(0.45, 0.7, 0.5))
		l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.add_child(l3)
		# печатание статуса
		var tw := l3.create_tween()
		tw.set_loops()
		tw.tween_property(l3, "modulate:a", 0.25, 0.45)
		var back := UiKit.MilButton.new("ЗАКРЫТЬ ТЕРМИНАЛ", Vector2(300, 50), false, 15)
		back.pressed.connect(func(): UiKit.close_window(w["overlay"]))
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		brow.add_child(back)
		vb.add_child(brow)
		G.play_sfx("radio", -10.0)

# ================= КАМПАНИЯ «ЗЕМЛЯ МЕРТВЫХ»: ПОТОК =================
func start_z_campaign() -> void:
				_start_z_campaign()

func _start_z_campaign() -> void:
		if pending_new_z:
				var visual_preferences: Dictionary = G.zsave.get("bunker_visual",{}).duplicate(true)
				G.zsave = G._default_zsave()
				if not visual_preferences.is_empty(): G.zsave["bunker_visual"] = visual_preferences
				pending_new_z = false
				G.write_save()
		if bool(G.zsave.get("campaign_won", false)):
				_zwin_screen()
		elif not bool(G.zsave["seen_prologue"]):
				# НОВАЯ ИГРА: сначала сложность (ТЗ п.18), затем предупреждение о вспышках
				if not G.zsave.has("zdiff_chosen") or not bool(G.zsave.get("zdiff_chosen", false)):
						await show_loading("Запуск пролога…", 0.45)
						_show_zdiff_select()
				else:
						await show_loading("Запуск пролога…", 0.45)
						_show_flash_warning()
		elif int(G.zsave.get("sector", 0)) == 0:
				_prologue_done()
		else:
				_show_bunker_complete()

# ---------- ПРЕДУПРЕЖДЕНИЕ О ВСПЫШКАХ (перед прологом) ----------
func _show_flash_warning() -> void:
	_clear()
	var layer:=CanvasLayer.new();layer.layer=10;add_child(layer);current_screen=layer
	var page:=preload("res://scripts/ui/startup_notice.gd").new();page.main=self;layer.add_child(page)

func _flash_warning_done() -> void:
		# после предупреждения — пролог
		_clear()
		var layer := CanvasLayer.new()
		layer.layer = 10
		current_screen = layer
		add_child(layer)
		var pr = ZPrologueZarya.new()   # пролог «ОБЪЕКТ „ЗАРЯ“» — кинематографическая цепочка
		pr.main_ref = self
		layer.add_child(pr)

func to_zcampaign_map() -> void:
				_to_zcampaign_map()

# ---------- ПРОЛОГ ЗАВЕРШЁН → СЕКТОР 1 (по ТЗ №1) ----------
# Кнопка пролога «ВЫБИТЬ СТЕКЛО И ПОДНЯТЬСЯ» ведёт прямо
# на 2D-локацию «Подземный бункер лаборатории».
func prologue_done() -> void:
				_prologue_done()

func _prologue_done() -> void:
				await show_loading("СЕКТОР 1 · ПОДЗЕМНЫЙ БУНКЕР ЛАБОРАТОРИИ «ЗАРЯ»", 0.8)
				# FIX-4: пробуждение в капсуле — состояние всегда свежее.
				# Старые раны/заражение из прошлых прогонов НЕ переносятся:
				# именно из-за них игрок умирал сразу после выхода из капсулы.
				G.zsave["pstate"] = Med.mk_state()
				G.zsave["infect"] = 0.0
				G.write_save()
				_clear()
				battle_node = null
				var b = BunkerStory.new()
				battle_node = b
				b.setup({
								"sector_idx": 0,
								"mission": "bunker",
								"sector_name": "СЕКТОР 1: БУНКЕР «ЗАРЯ»",
				})
				b.main_ref = self
				current_screen = b
				add_child(b)

func _to_zcampaign_map() -> void:
		await show_loading("Сборка карты секторов…", 0.4)
		_clear()
		battle_node = null
		var layer := CanvasLayer.new()
		layer.layer = 10
		current_screen = layer
		add_child(layer)
		var camp = ZCampaignScript.new()
		camp.main_ref = self
		layer.add_child(camp)

func start_zbattle() -> void:
				_start_zbattle()

func _start_zbattle() -> void:
		await show_loading("Выход на сектор…", 0.45)
		_clear()
		battle_node = null
		var idx: int = clampi(int(G.zsave["sector"]), 0, G.ZSECTORS.size() - 1)
		var b = BunkerStory.new() if idx == 0 else BattleZScript.new()
		battle_node = b
		var sec: Dictionary = G.ZSECTORS[idx]
		b.setup({
				"sector_idx": idx,
				"mission": sec["type"],
				"sector_name": sec["name"],
		})
		b.main_ref = self
		current_screen = b
		add_child(b)

func after_zbattle(victory: bool) -> void:
		if victory and battle_node != null and battle_node.is_bunker:
				_show_bunker_complete()
				return
		if victory and (bool(G.zsave.get("campaign_won", false)) or int(G.zsave["sector"]) >= G.ZSECTORS.size()):
				_after_zbattle_win(victory)
		else:
				_after_zbattle_loss(victory)

func _after_zbattle_win(victory: bool) -> void:
		await show_loading("Подсчёт итога боя…", 0.35)
		if battle_node != null and is_instance_valid(battle_node):
				battle_node.queue_free()
				battle_node = null
		if victory and (bool(G.zsave.get("campaign_won", false)) or int(G.zsave["sector"]) >= G.ZSECTORS.size()):
				G.zsave["campaign_won"] = true
				G.write_save()
				_zwin_screen()
		else:
				# ПОБЕГ ИЗ «ЗАРИ» ЗАВЕРШЁН: переход «СНЕЖНАЯ ЛИНИЯ» (ТЗ п.15)
				if victory and int(G.zsave["sector"]) == 1 and not bool(G.zsave.get("pvars", {}).get("snowline_shown", false)):
						await _snow_line_transition()
				open_location("res://scenes/locations/Surface.tscn", "FromBunker")

func _after_zbattle_loss(victory: bool) -> void:
		await show_loading("Возвращение на карту…", 0.35)
		if battle_node != null and is_instance_valid(battle_node):
				battle_node.queue_free()
				battle_node = null
		if victory and (bool(G.zsave.get("campaign_won", false)) or int(G.zsave["sector"]) >= G.ZSECTORS.size()):
				G.zsave["campaign_won"] = true
				G.write_save()
				_zwin_screen()
		else:
				to_main_menu()

func _zwin_screen() -> void:
		_clear()
		var ui := CanvasLayer.new()
		ui.layer = 10
		current_screen = ui
		add_child(ui)
		var overlay := Control.new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(overlay)
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.02, 0.03, 0.02)
		overlay.add_child(bg)
		var mid := VBoxContainer.new()
		mid.set_anchors_preset(Control.PRESET_CENTER)
		mid.grow_horizontal = Control.GROW_DIRECTION_BOTH
		mid.grow_vertical = Control.GROW_DIRECTION_BOTH
		mid.offset_left = -520
		mid.offset_right = 520
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		mid.add_theme_constant_override("separation", 18)
		overlay.add_child(mid)
		var t1 := UiKit.label("СЕВЕРНЫЙ БУНКЕР ДОСТИГНУТ", 30, Color(0.6, 0.95, 0.55))
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_child(t1)
		var t2 := UiKit.wrap_label("Штамм «Заря-0» остановлен. Антидот из вашей крови спас тех, кто ещё жив.\n\n" + (G.ZDIARY[20] if G.ZDIARY.has(20) else ""), 17, Color(0.85, 0.9, 0.8), 980.0)
		mid.add_child(t2)
		var back := UiKit.MilButton.new("В ГЛАВНОЕ МЕНЮ", Vector2(380, 56), true, 17)
		back.pressed.connect(func():
				G.play_sfx("ui_click", -6.0)
				to_main_menu())
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		brow.add_child(back)
		mid.add_child(brow)

# ================= КАРТА КАМПАНИИ (ВОЕННАЯ, ЗАМОРОЖЕНА) =================
func to_campaign_map() -> void:
		_clear()
		var camp = CampaignScript.new()
		camp.main_ref = self
		current_screen = camp
		add_child(camp)

# ================= ЗАПУСК БОЯ =================
func start_battle() -> void:
		_clear()
		var b = BattleScript.new()
		battle_node = b
		var sec: Dictionary = G.SECTORS[G.save["sector"]]
		var enemy_fac: String = sec["enemy"]
		var cfg := {
				"faction_player": G.save["faction"],
				"faction_enemy": enemy_fac,
				"sector_idx": G.save["sector"],
				"sector_type": sec["type"],
				"heli_unlocked": G.save["heli_unlocked"],
		}
		b.setup(cfg)
		b.main_ref = self
		add_child(b)

# ================= ВОЗВРАТЫ ИЗ БОЯ =================
func after_battle(_victory: bool) -> void:
		if battle_node != null and is_instance_valid(battle_node):
				battle_node.queue_free()
				battle_node = null
		to_campaign_map()

func to_main_menu_from_battle() -> void:
		to_main_menu()

# ================= ЗОМБИ-СМОУКИ =================
func _run_zsmoke() -> void:
		# сектор 1: капсула → снаряжение → бинт → лаборанты → охранник → шлюз → победа
		await get_tree().create_timer(0.5).timeout
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 0
		G.zsave["squad"] = []
		# чистое состояние: прошлые проги могли сохранить заражение/раны
		G.zsave["infect"] = 0.0
		G.zsave.erase("pstate")
		start_zbattle()
		await get_tree().create_timer(1.2).timeout
		var b = battle_node
		if b == null:
				print("ZSMOKE: FAIL no battle")
				get_tree().quit(1)
				return
		var info: Dictionary = b.smoke_info()
		print("ZSMOKE: bunker info = ", info)
		print("ZSMOKE: player in capsule (hidden) = ", not b.player["spr"].visible)
		# 1. выбиваем стекло
		b._do_interact({"kind": "capsule"})
		await get_tree().create_timer(0.3).timeout
		print("ZSMOKE: player out = ", b.player["spr"].visible, ", ra wound = ", (b.player["st"] as Dictionary)["wounds"].size() > 0)
		# 2. снаряжение со стола
		b.player["spr"].position = Vector2(640, 1500)
		await get_tree().create_timer(0.3).timeout
		# v2.9: компас задачи — цель активной задачи должна находиться
		var ctgt: Vector2 = b._zpro_obj_pos()
		print("ZSMOKE: compass target = ", ctgt, " (gear_table ~ (640,1450))")
		print("ZSMOKE: compass ok = ", ctgt != Vector2.INF)
		# v2.9: выстрел → гильза + импульс света
		b.player["mag"] = 8
		b.player["fire_cd"] = 0.0
		b._fire_player()
		print("ZSMOKE: shell ejected = ", b.shells.size() > 0, ", muzzle light = ", b.muzzle_light != null and b.muzzle_light.energy > 0.0)
		var it: Dictionary = b._find_interact()
		print("ZSMOKE: gear interact = ", it.get("kind", "none"))
		if it.get("kind", "") == "gear":
				b._do_interact(it)
				await get_tree().create_timer(0.2).timeout
				print("ZSMOKE: gear objective done = ", b._obj_done("gear"), ", bandages = ", int(G.zsave["inv"].get("band", 0)))
		# 3. перевязка (реальный UI-путь: выбор предмета → зона)
		b._med_sel_item = "band"
		b.med_apply_zone("ra")
		print("ZSMOKE: bandage via UI, band left = ", int(G.zsave["inv"].get("band", 0)))
		await get_tree().create_timer(0.4).timeout
		print("ZSMOKE: heal objective done = ", b._obj_done("heal"))
		# 4. лаборанты: убиваем всех sci
		for z in b.zombies.duplicate():
				if z["kind"] == "sci":
						b._kill_zombie(z)
		await get_tree().create_timer(0.2).timeout
		print("ZSMOKE: corridor objective done = ", b._obj_done("corridor"))
		# 5. обыск охранника (+ карта в рюкзак для проверки шлюза)
		for c in b.corpses:
				if c["kind"] == "guard":
						b._search_corpse(c)
		for c in b.corpses:
				if c["kind"] == "guard" and not (c as Dictionary).get("loot_items", []).is_empty():
						b.loot_source = c
						b._take_loot_item("keycard")
		print("ZSMOKE: guard done + keycard = ", b._obj_done("guard"), int(G.zsave["inv"].get("keycard", 0)) > 0)
		# 6. сканер: карта к считывателю
		b.player["spr"].position = Vector2(2000, 420)
		await get_tree().create_timer(0.3).timeout
		var its: Dictionary = b._find_interact()
		print("ZSMOKE: scanner interact = ", its.get("kind", "none"))
		if its.get("kind", "") == "scanner":
				b._do_interact(its)
				await get_tree().create_timer(0.4).timeout
				print("ZSMOKE: scanner_used = ", b.scanner_used, ", objective = ", b._obj_done("scanner"))
		# 7. шлюз
		b.player["spr"].position = Vector2(2320, 340)
		await get_tree().create_timer(0.3).timeout
		var it2: Dictionary = b._find_interact()
		print("ZSMOKE: airlock interact = ", it2.get("kind", "none"))
		if it2.get("kind", "") == "airlock":
				b._do_interact(it2)
				await get_tree().create_timer(0.3).timeout
				print("ZSMOKE: extraction open = ", b.extraction_open)
		# 8. ЛИФТ: спуск в технический сектор (сценарий п.8) → финал через грузовой шлюз
		b.zp_fast = true
		b.player["spr"].position = Vector2(2320, 180)
		await get_tree().create_timer(0.3).timeout
		var it3: Dictionary = b._find_interact()
		print("ZSMOKE: lift interact = ", it3.get("kind", "none"))
		if it3.get("kind", "") == "stairs":
				b._do_interact(it3)
		await get_tree().create_timer(2.5).timeout
		b.zp_force_close()
		var lifted: bool = (b.player["spr"].position as Vector2).y > 1900
		print("ZSMOKE: ZPRO-ELEV teleport to tech sector = ", lifted, " pos=", b.player["spr"].position)
		# финал: грузовой шлюз — ворота открыты, выход на площадку
		b.player["spr"].position = Vector2(1426, 3300)
		b.zp_gate_state = 4
		await get_tree().create_timer(0.2).timeout
		G.zsave["pvars"]["snowline_shown"] = true   # смоук: без перехода «Снежная линия»
		b._win()
		var won: bool = b.battle_over != ""
		await get_tree().create_timer(2.6).timeout
		print("ZSMOKE: victory flow = ", won and int(G.zsave["sector"]) == 1)
		print("ZSMOKE: diary = ", int(G.zsave["diary"]))
		print("ZSMOKE: ALL OK")
		get_tree().quit(0)

# ================= ZPRO: АВТОПРОГОН ПРОЛОГА «ЗАРЯ» =================
# Проверяет все системы сценария без участия игрока: задачи, интерактивы,
# переменные кампании (9 флагов ТЗ), блокировку карантина, V-18, финал.
func _run_zpro() -> void:
		await get_tree().create_timer(0.5).timeout
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 0
		G.zsave["zdiff"] = 1
		G.zsave["pvars"] = {}
		G.zsave["squad"] = []
		G.zsave["infect"] = 0.0
		G.zsave["inv"] = {}
		G.zsave["weapons"] = []
		G.zsave.erase("pstate")
		G.write_save()
		start_zbattle()
		await get_tree().create_timer(1.2).timeout
		var b = battle_node
		if b == null:
				print("ZPRO: FAIL no battle")
				get_tree().quit(1)
				return
		b.zp_fast = true
		var ok := true
		# 1) сценарный слой инициализирован
		ok = ok and b.zp_amb != null and (b.zp as Dictionary).size() > 0
		print("ZPRO: init = ", ok, ", objectives = ", b.objectives.size())
		# 2) выход из капсулы
		b._do_interact({"kind": "capsule"})
		await get_tree().create_timer(0.2).timeout
		for zn in ["head", "torso", "la", "ra", "ll", "rl"]:
				b.player["st"]["body"][zn] = 1.0
		b.player["st"]["wounds"] = []
		b.player["st"]["frac"] = []
		b.player["st"]["stress"] = 0.0
		b.player["spr"].visible = true
		# 3) крио-терминал камеры пробуждения
		b.player["spr"].position = Vector2(238, 1585)   # терминал теперь у западной стены (162, 1545), радиус 96
		await get_tree().create_timer(0.25).timeout
		var it: Dictionary = b._find_interact()
		print("ZPRO: cryo terminal = ", it.get("kind", "none"))
		if it.get("kind", "") == "cryo_terminal":
				b._do_interact(it)
				await get_tree().create_timer(1.6).timeout
				b.zp_force_close()
		# 4) труп исследователя: пропуск + записка (пароль врача)
		for c in b.corpses:
				if (c as Dictionary).get("bonus", []).has("propusk"):
						b._search_corpse(c)
						b.zp_force_close()
				if (c as Dictionary).get("bonus", []).has("propusk"):
						b.loot_source = c
						b._take_loot_item("propusk")
		print("ZPRO: propusk + med_pass = ", int(G.zsave["inv"].get("propusk", 0)) > 0, bool(b.zp.get("med_pass", false)))
		# 5) щитовая: перчатки → вода → рубильник
		b._do_interact({"kind": "gloves_pick"})
		b._do_interact({"kind": "water_valve"})
		b._do_interact({"kind": "breaker"})
		print("ZPRO: med power = ", bool(b.zp.get("med_power", false)))
		# 6) медтерминал (теперь у северной стены палаты)
		b.player["spr"].position = Vector2(1408, 1452)
		await get_tree().create_timer(0.2).timeout
		var it2: Dictionary = b._find_interact()
		if it2.get("kind", "") == "med_terminal":
				b._do_interact(it2)
				await get_tree().create_timer(1.2).timeout
				b.zp_force_close()
		# 7) Пациент-06: сцена и волна
		b._zpro_pat06_encounter()
		await get_tree().create_timer(0.8).timeout
		b.zp_force_close()
		print("ZPRO: pat06 spawned = ", (b.zp as Dictionary).has("pat06"))
		# 8) палата 12: запись → found_v17_record + кассета
		b._zpro_do_interact("exp12_video", {})
		await get_tree().create_timer(1.0).timeout
		b.zp_force_close()
		print("ZPRO: found_v17_record = ", G.zflag("found_v17_record"), ", cassette = ", int(G.zsave["inv"].get("cassette", 0)))
		# 9) Серов: вариант А (помочь)
		G.z_give_item("band", 2)
		G.z_give_item("morph", 2)
		b._zpro_serov_resolve(0)
		await get_tree().create_timer(0.4).timeout
		b.zp_force_close()
		print("ZPRO: helped_serov = ", G.zflag("helped_serov"), ", armory_code = ", bool(b.zp.get("armory_code", false)))
		# 10) генератор: предохранитель → контур → охлаждение → запуск
		G.z_give_item("fuse", 1)
		b.zp["gen_fuse"] = true
		b.zp["gen_loop"] = true
		b.zp["gen_cool"] = true
		b._zpro_do_interact("generator", {})
		await get_tree().create_timer(1.0).timeout
		b.zp_force_close()
		print("ZPRO: repaired_generator = ", G.zflag("repaired_generator"), ", gen_on = ", bool(b.zp.get("gen_on", false)))
		# 11) утечка газа
		b._zpro_do_interact("gas_valve", {})
		await get_tree().create_timer(1.0).timeout
		b.zp_force_close()
		print("ZPRO: gas_fixed = ", bool(b.zp.get("gas_fixed", false)))
		# 12) оружейная по коду Серова
		b._zpro_do_interact("weapon_locker", {})
		await get_tree().create_timer(0.6).timeout
		b.zp_force_close()
		print("ZPRO: armory_open = ", bool(b.zp.get("armory_open", false)), ", ammo24 = ", int(G.zsave["ammo"].get("pistol", 0)) >= 24)
		# 13) карантин: блокировка → ключ → изоляция выкл.
		b._zpro_do_interact("sas_gate", {})
		for zn in ["head", "torso", "la", "ra", "ll", "rl"]:
				b.player["st"]["body"][zn] = 1.0
		b.player["st"]["wounds"] = []
		b.player["st"]["frac"] = []
		b.player["st"]["stress"] = 0.0
		b.player["spr"].position = Vector2(1200, 2700)
		for wi in range(20):
				await get_tree().create_timer(0.1).timeout
				if bool(b.zp.get("lockdown_started", false)):
						break
		print("ZPRO: lockdown started = ", bool(b.zp.get("lockdown_started", false)), ", countdown = ", int(b.zp_countdown))
		G.z_give_item("air_key", 1)
		b._zpro_do_interact("iso_panel", {})
		await get_tree().create_timer(1.0).timeout
		b.zp_force_close()
		print("ZPRO: iso_off = ", bool(b.zp.get("iso_off", false)))
		# 14) вент-обход (used_stealth_route)
		b._zpro_vent_bypass()
		await get_tree().create_timer(0.8).timeout
		b.zp_force_close()
		print("ZPRO: used_stealth_route = ", G.zflag("used_stealth_route"))
		# 15) Морозова → побег → сталкер (подлатать игрока — тест не про выживание)
		for zn in ["head", "torso", "la", "ra", "ll", "rl"]:
				b.player["st"]["body"][zn] = 1.0
		b.player["st"]["wounds"] = []
		b.player["st"]["frac"] = []
		b.player["st"]["stress"] = 0.0
		b._zpro_morozova()
		await get_tree().create_timer(1.5).timeout
		b.zp_force_close()
		await get_tree().create_timer(1.0).timeout
		print("ZPRO: escape_on = ", bool(b.zp.get("escape_on", false)), ", stalker = ", b.zp_stalker != null)
		# 16) свет/тьма + память
		b._zpro_light_switch()
		b._zpro_memory_flash(true)
		await get_tree().create_timer(1.0).timeout
		b.zp_force_close()
		print("ZPRO: heard_unknown_voice = ", G.zflag("heard_unknown_voice"))
		# 17) гидравлика и V-18 (снова подлатать: тест не про выживание)
		for zn in ["head", "torso", "la", "ra", "ll", "rl"]:
				b.player["st"]["body"][zn] = 1.0
		b.player["st"]["wounds"] = []
		b.player["st"]["stress"] = 0.0
		b.zp_gate_state = 3
		b.zp_gate_t = 10.0
		await get_tree().create_timer(0.6).timeout
		print("ZPRO: v18 spawned = ", b.zp_v18_spawned)
		b._zpro_v18_inspect()
		print("ZPRO: found_v18_body = ", G.zflag("found_v18_body"))
		# 18) финал: победа
		G.zsave["pvars"]["snowline_shown"] = true   # смоук: без перехода
		b._win()
		var won: bool = b.battle_over != ""
		await get_tree().create_timer(2.6).timeout
		print("ZPRO: victory = ", won, ", sector = ", int(G.zsave["sector"]))
		var flags := ["helped_serov", "found_v17_record", "repaired_generator", "saved_medkit",
				"heard_unknown_voice", "found_v18_body", "alarm_triggered", "used_stealth_route", "trust_ai"]
		var got := 0
		for f in flags:
				if G.zflag(str(f)):
						got += 1
		print("ZPRO: pvars set = ", got, "/9 (saved_medkit ожидаем false — аптечка потрачена)")
		print("ZPRO: ALL OK" if ok else "ZPRO: FAILED")
		get_tree().quit(0 if ok else 1)

# ================= ZPROLOG: тест кинематографического пролога =================
func _run_zprolog_test() -> void:
		G.zsave["seen_prologue"] = false
		G.zsave["zdiff_chosen"] = false
		# 1) экран выбора сложности строится
		_show_zdiff_select()
		await get_tree().create_timer(1.2).timeout
		G.zsave["zdiff"] = 1
		G.zsave["zdiff_chosen"] = true
		_clear()
		# 2) пролог: акты 0–1 идут, аудио/субтитры работают
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		var pr = ZPrologueZarya.new()
		pr.main_ref = self
		layer.add_child(pr)
		await get_tree().create_timer(14.0).timeout
		# 3) завершение пролога → передача в бой (бункер строится)
		pr._finish_prologue()
		await get_tree().create_timer(6.0).timeout
		var ok: bool = battle_node != null and is_instance_valid(battle_node) and bool(battle_node.get("is_bunker"))
		print("ZPROLOG: prologue -> bunker handoff = ", ok)
		get_tree().quit(0 if ok else 1)

# ВИЗУАЛЬНАЯ ПРОВЕРКА ВСТУПЛЕНИЯ (ТЗ v2.7): скриншоты карточек пролога.
# Запуск: godot -- --zintro  (нужен реальный рендер: xvfb-run на сервере)
func _run_zintro_shots() -> void:
		G.zsave["seen_prologue"] = false
		var layer := CanvasLayer.new()
		layer.layer = 60   # над меню (layer 10), под экраном загрузки (100)
		add_child(layer)
		var pr = ZPrologueZarya.new()
		pr.main_ref = self
		layer.add_child(pr)
		await get_tree().create_timer(2.2).timeout
		await _shot("zintro_01_head")           # заголовок проявляется из темноты
		await get_tree().create_timer(5.3).timeout
		await _shot("zintro_02_act0_system")    # акт 0: системная карточка
		await get_tree().create_timer(16.5).timeout
		await _shot("zintro_03_act1_system")    # акт 1: зелёные системные карточки
		await get_tree().create_timer(12.5).timeout
		await _shot("zintro_04_act1_story")     # акт 1: литературная карточка
		# останавливаем живой пролог (замораживаем корутину) и доснимаем остальное оверлеями
		pr.cs.stop_now()
		pr.cs.visible = false
		# диалог (акт 2): реплика ИИ + выборы
		pr.dlg.visible = true
		pr.dlg.set_stages(pr._dialog_stages())
		pr.dlg.start(0)
		await get_tree().create_timer(18.0).timeout
		await _shot("zintro_05_dialog")   # выборы А/Б/В уже показаны
		pr.dlg.stop_all()
		pr.dlg.visible = false
		# системная карточка с зелёным тегом (спокойный чёрный фон)
		var cs_sys := ZCutscene.new()
		cs_sys.skippable = false
		layer.add_child(cs_sys)
		cs_sys.play([{"speaker": "ИИ · СИСТЕМА ОБЕСПЕЧЕНИЯ БЕЗОПАСНОСТИ ОБЪЕКТА «ЗАРЯ»", "col": ZUI.NEON, "style": "system",
				"text": "«Пациент V-17. Пожалуйста, вернитесь в капсулу. Вы находитесь в зоне медицинского карантина».",
				"hold": 30.0}])
		await get_tree().create_timer(2.6).timeout
		await _shot("zintro_06_system_card")
		cs_sys.stop_now()
		cs_sys.visible = false
		# сюжетная карточка с аварийным красным свечением (как на скриншоте пользователя)
		var cs_red := ZCutscene.new()
		cs_red.skippable = false
		layer.add_child(cs_red)
		cs_red.play([{"speaker": "СИСТЕМА ОБЪЕКТА", "col": ZCutscene.C_SYSTEM, "style": "story",
				"text": "Красные лампы вспыхивают — раз. Другая. Мигание выхватывает из темноты перевёрнутый стол, треснувшую перегородку, лужу воды на полу.",
				"red": true, "hold": 30.0}])
		await get_tree().create_timer(3.2).timeout
		await _shot("zintro_07_red_story")
		print("ZINTRO: shots done")
		get_tree().quit(0)

func _run_zdeath_repro() -> void:
		# РЕПРОДУКЦИЯ БАГА: выход из капсулы → быстрая смерть?
		# Сценарий А: чистое состояние. Сценарий Б: хвосты прошлого боя в pstate.
		await get_tree().create_timer(0.5).timeout
		var scenario := OS.get_environment("ZDEATH_DIRTY") == "1"
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 0
		G.zsave["squad"] = []
		G.zsave["infect"] = 0.0
		G.zsave.erase("pstate")
		if scenario:
				# имитация: игрок победил прошлый бой с раной головы и заражением
				G.zsave["pstate"] = {"body": {"head": 0.5, "torso": 0.9, "la": 0.8, "ra": 0.55, "ll": 0.9, "rl": 0.9},
						"wounds": [{"zone": "head", "bleed": 1, "tq": false, "clamp": false, "band": false}],
						"frac": [], "stress": 20.0, "state": "ok", "state_t": 0.0, "roll_t": 3.0, "scream_cd": 0.0, "down": false, "dragged": false, "dragging": null}
				G.zsave["infect"] = 55.0
		start_zbattle()
		await get_tree().create_timer(1.2).timeout
		var b = battle_node
		if b == null:
				print("ZDEATH: FAIL no battle")
				get_tree().quit(1)
				return
		b._do_interact({"kind": "capsule"})
		await get_tree().create_timer(0.3).timeout
		Engine.time_scale = 8.0
		var sim_t := 0.0
		while sim_t < 420.0 and b.battle_over == "":
				await get_tree().create_timer(0.5).timeout
				sim_t += 0.5 * Engine.time_scale
				if sim_t >= 60.0:
						var st: Dictionary = b.player["st"]
						var wz: Dictionary = st["body"]
						print("ZDEATH[%s] t=%3.0f head=%.2f torso=%.2f ra=%.2f infect=%.0f wounds=%d state=%s over=%s" % [
								"dirty" if scenario else "clean", sim_t,
								float(wz["head"]), float(wz["torso"]), float(wz["ra"]),
								float(b.player["infect"]), (st["wounds"] as Array).size(),
								str(st.get("state", "?")), str(b.battle_over)])
						if float(wz["head"]) < 0.5 and float(wz["head"]) > 0.44:
								print("ZDEATH: head dropping!")
		Engine.time_scale = 1.0
		print("ZDEATH: final battle_over = ", b.battle_over, " (player alive = ", b.player["alive"], ")")
		print("ZDEATH: DONE")

func _run_zsmoke2() -> void:
		# поверхность: склад, стрельба, зачистка, эвакуация
		await get_tree().create_timer(0.5).timeout
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 2
		G.zsave["squad"] = [{"name": "Волк-4", "alive": true}]
		G.zsave["infect"] = 0.0
		G.zsave.erase("pstate")
		G.zsave["weapons"] = ["pistol", "smg"]
		G.zsave["ammo"] = {"pistol": 24, "smg": 90, "shotgun": 0, "rifle": 0}
		start_zbattle()
		await get_tree().create_timer(1.2).timeout
		var b = battle_node
		if b == null:
				print("ZSMOKE2: FAIL no battle")
				get_tree().quit(1)
				return
		var info: Dictionary = b.smoke_info()
		print("ZSMOKE2: surface info = ", info)
		print("ZSMOKE2: allies = ", b.allies.size(), ", mission = ", b.mission)
		# стреляем по ближайшему зомби
		b.player["spr"].visible = true
		var tz = null
		for z in b.zombies:
				if z["alive"]:
						tz = z
						break
		if tz != null:
				b.player["spr"].position = (tz["spr"] as Sprite2D).position + Vector2(220, 0)
				b.player["weapon"] = "smg"
				if int(b.player["mag"]) <= 0:
						b.player["mag"] = 30   # ПМУ: без магазина выстрела не будет
				b.manual_aim = true
				b.manual_ang = PI
				b.manual_fire = true
				var m0: int = int(b.player["mag"])
				await get_tree().create_timer(1.0).timeout
				b.manual_fire = false
				print("ZSMOKE2: smg fired = ", int(b.player["mag"]) < m0)
		# добиваем всех
		for z in b.zombies.duplicate():
				if z["alive"]:
						b._kill_zombie(z)
		await get_tree().create_timer(0.3).timeout
		print("ZSMOKE2: main objective done = ", b._obj_done("main"), ", extraction open = ", b.extraction_open)
		b.player["spr"].position = b.extraction
		await get_tree().create_timer(3.0).timeout
		print("ZSMOKE2: victory = ", int(G.zsave["sector"]) == 3)
		print("ZSMOKE2: ALL OK")
		get_tree().quit(0)

func _run_zfps_bench() -> void:
		# бенчмарк FPS: бункер-бой, замер средней частоты кадров
		await get_tree().create_timer(0.5).timeout
		# замер 1: главное меню (без боя)
		var acc0 := 0.0
		var fr0 := 0
		var t0 := 0.0
		while t0 < 2.0:
				var dt0: float = get_process_delta_time()
				acc0 += 1.0 / maxf(dt0, 0.0001)
				fr0 += 1
				t0 += dt0
				await get_tree().process_frame
		print("ZFPS: menu_avg=", snappedf(acc0 / maxf(1.0, float(fr0)), 0.1))
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 0
		G.zsave["squad"] = []
		G.zsave["infect"] = 0.0
		G.zsave.erase("pstate")
		start_zbattle()
		await get_tree().create_timer(1.5).timeout
		var b = battle_node
		if b == null:
				print("ZFPS: FAIL no battle")
				get_tree().quit(1)
				return
		# прогрев 2 c
		await get_tree().create_timer(2.0).timeout
		var acc := 0.0
		var frames := 0
		var t := 0.0
		while t < 6.0:
				var dt: float = get_process_delta_time()
				acc += 1.0 / maxf(dt, 0.0001)
				frames += 1
				t += dt
				await get_tree().process_frame
		var avg: float = acc / maxf(1.0, float(frames))
		print("ZFPS: avg=", snappedf(avg, 0.1), " frames=", frames)
		print("ZFPS: proc_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1))
		# диагностика: перечислить ноды с _process/_physics_process
		var procs := []
		var stack: Array = [b]
		var total := 0
		while not stack.is_empty():
				var n: Node = stack.pop_back()
				total += 1
				if n.has_method("_process") and n.is_processing():
						procs.append(str(n.get_class()) + ":" + n.get_script().resource_path.get_file() if n.get_script() != null else str(n.get_class()) + ":<no-script>")
				for c in n.get_children():
						stack.push_back(c)
		print("ZFPS: tree_nodes=", total, " processing_nodes=", procs.size())
		var cnt := {}
		for p in procs:
				cnt[p] = int(cnt.get(p, 0)) + 1
		for k in cnt.keys():
				print("ZFPS: proc_node x", cnt[k], " = ", k)
		print("ZFPS: objects=", int(b.smoke_info()["props"]))
		get_tree().quit(0)

# v2.9: проверка «сочности» — умирающая лампа, гильзы, лут-текст, пыль шагов
func _run_zjuice() -> void:
		await get_tree().create_timer(0.6).timeout
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 0
		G.zsave["squad"] = []
		G.zsave["infect"] = 0.0
		G.zsave.erase("pstate")
		start_zbattle()
		await get_tree().create_timer(1.0).timeout
		var b = battle_node
		b.q_lock = true          # тест: не даём авто-качеству гасить эффекты (llvmpipe медленный)
		b.q_level = 2
		b._do_interact({"kind": "capsule"})
		# шаги: пыль от ботинок (симулируем ходьбу)
		var walked := 0.0
		while walked < 1.6:
				b.direct_vec = Vector2(1, 0)
				await get_tree().create_timer(0.1).timeout
				walked += 0.1
		b.direct_vec = Vector2.ZERO
		# выстрелы: гильзы + импульс света у дула
		b.player["mag"] = 8
		b.player["fire_cd"] = 0.0
		for i in range(3):
				b._fire_player()
				b.player["fire_cd"] = 0.0
				await get_tree().create_timer(0.12).timeout
		await get_tree().create_timer(0.8).timeout
		await _shot("j01_shells")
		# мирные съёмки: убираем мёртвых, чтобы игрок дожил до конца теста
		for zz in b.zombies:
				zz["alive"] = false
				zz["spr"].visible = false
		# всплывающий текст предмета при подборе
		var crate = null
		for pr in b.props:
				if str(pr.get("kind", "")) == "loot_crate":
						crate = pr
						break
		if crate != null:
				b.player["spr"].position = (crate["pos"] as Vector2) + Vector2(40, 0)
				crate["loot_items"] = ["medkit", "ammo"]
				b._open_loot_crate(crate)
				await get_tree().create_timer(0.4).timeout
				b._take_loot_item("medkit")
				await get_tree().create_timer(0.3).timeout
				await _shot("j02_floattext")
				if b.loot_win != null and is_instance_valid(b.loot_win):
						UiKit.close_window(b.loot_win)
						b.loot_win = null
						b.paused = false
		# к умирающей лампе (карантин): ждём отказ → снимок → ждём оживание → снимок
		b.player["spr"].position = Vector2(1250, 1680)
		var elapsed := 0.0
		var dark_ok := false
		var back_ok := false
		while elapsed < 30.0 and is_instance_valid(b) and b.battle_over == "":
				await get_tree().create_timer(0.4).timeout
				elapsed += 0.4
				if not is_instance_valid(b) or b.dying_lamps.is_empty():
						break
				var gs: Sprite2D = b.dying_lamps[0]["spr"]
				if not dark_ok and gs.self_modulate.a < 0.25:
						await get_tree().create_timer(0.5).timeout
						await _shot("j03_lamp_dark")
						dark_ok = true
				elif dark_ok and not back_ok and gs.self_modulate.a > 0.8:
						await _shot("j04_lamp_back")
						back_ok = true
						break
		print("ZJUICE: lamp dark =", dark_ok, ", lamp back =", back_ok)
		print("ZJUICE DONE")
		get_tree().quit(0)


func _run_zshots() -> void:
		await get_tree().create_timer(1.2).timeout
		await _shot("z01_menu")
		_open_terminal(current_screen)
		await get_tree().create_timer(0.7).timeout
		await _shot("z02_terminal")
		_close_last_window()
		await get_tree().create_timer(0.4).timeout
		# пролог (принудительно — для скриншота; теперь сначала предупреждение)
		G.zsave["seen_prologue"] = false
		start_z_campaign()
		await get_tree().create_timer(0.8).timeout
		await _shot("z03_warning")
		_flash_warning_done()
		await get_tree().create_timer(0.8).timeout
		await _shot("z03_prologue")
		# бункер
		G.zsave["seen_prologue"] = true
		G.zsave["sector"] = 0
		start_zbattle()
		await get_tree().create_timer(1.2).timeout
		var b = battle_node
		for zz in b.zombies:
				zz["alive"] = false
				zz["spr"].visible = false
		# FIX-4: скриншот капсулы — весь HUD скрыт, только кнопка выбраться
		await get_tree().create_timer(0.6).timeout
		await _shot("z04_capsule")
		b._do_interact({"kind": "capsule"})
		b.player["spr"].position = Vector2(430, 1740)
		b.manual_aim = true
		b.manual_ang = -PI / 4.0
		await get_tree().create_timer(0.8).timeout
		await _shot("z04_bunker")
		# лабораторный зал
		for d in b.doors.values():
				if not bool(d["opened"]):
						b._open_door(str(d["id"]))
		b.player["spr"].position = Vector2(760, 1000)
		await get_tree().create_timer(0.9).timeout
		await _shot("z04b_lab")
		# крио-хранилище
		b.player["spr"].position = Vector2(2350, 1050)
		await get_tree().create_timer(0.9).timeout
		await _shot("z04c_cryo")
		# FIX6: скрыть обучение — чистые кадры UI
		if b.tut != null:
				b.tut.visible = false
		b._open_med()
		await get_tree().create_timer(0.7).timeout
		await _shot("z05_health")
		UiKit.close_window(b.med_win)
		b.med_win = null
		b.paused = false
		await get_tree().create_timer(0.3).timeout
		b._open_kpk()
		await get_tree().create_timer(0.7).timeout
		await _shot("z06_kpk")
		UiKit.close_window(b.kpk_win)
		b.kpk_win = null
		b.paused = false
		# FIX6: задачи свернуты глазом
		b.obj_hidden = true
		b._refresh_obj_labels()
		await get_tree().create_timer(0.3).timeout
		await _shot("z06b_tasks_hidden")
		b.obj_hidden = false
		b._refresh_obj_labels()
		# FIX6: результат проверки магазина «± N патронов»
		b._ammo_check_t = -1.0
		b._ammo_result_txt = "± 2 патрона"
		b._ammo_result_t = 2.6
		b.queue_redraw_all()
		await get_tree().create_timer(0.3).timeout
		await _shot("z06c_ammochek")
		b._ammo_result_t = 0.0
		# FIX6: кнопка-пузырь прямо на объекте (дверь, удержание)
		b.cur_interact = {"kind": "door", "text": "ОТКРЫТЬ ГЕРМОДВЕРЬ", "hold": 0.6, "pos": b.player["spr"].position + Vector2(150, -20)}
		b.interact_bubble.visible = true
		b.interact_bubble.setup("door", "держите", "дверь открывается...", 0.6)
		await get_tree().create_timer(0.3).timeout
		await _shot("z06d_bubble")
		b.cur_interact = {}
		b.interact_bubble.visible = false
		# FIX6: шкаф у южной стены — фронт должен смотреть в комнату
		b.player["spr"].position = Vector2(560, 1250)
		b.manual_ang = PI / 2.0
		await get_tree().create_timer(0.9).timeout
		await _shot("z06e_cabinet")
		# поверхность
		G.zsave["sector"] = 2
		G.zsave["squad"] = [{"name": "Волк-4", "alive": true}]
		G.zsave["weapons"] = ["pistol", "smg"]
		start_zbattle()
		await get_tree().create_timer(1.5).timeout
		await _shot("z07_surface")
		# карта кампании
		to_zcampaign_map()
		await get_tree().create_timer(1.0).timeout
		await _shot("z08_zmap")
		print("ZSHOTS DONE")
		get_tree().quit(0)


# ================= FIX9: СЦЕНЫ-ЛОКАЦИИ =================
# Любая локация — обычная сцена (scenes/locations/*.tscn). Двери
# ExitDoor.tscn вызывают open_location(): загрузка сцены, постановка
# игрока в точку входа Spawns/<spawn_id>.
func open_location(path: String, spawn_id: String = "Main") -> void:
		await show_loading("Переход в новую локацию…", 0.45)
		_clear()
		# FIX11: сцена-локация проверяется ДО загрузки — понятный отчёт
		# вместо красной строки, если файл правили вручную и сломали
		var sc_errs: PackedStringArray = SceneCheck.validate_tscn(path, false)
		if not sc_errs.is_empty():
				for e in sc_errs:
						push_error("СЦЕНА ЛОКАЦИИ: " + e)
				print(SceneCheck.report(path, sc_errs))
				var eui := CanvasLayer.new()
				eui.layer = 30
				current_screen = eui
				add_child(eui)
				var eroot := Control.new()
				eroot.set_anchors_preset(Control.PRESET_FULL_RECT)
				eui.add_child(eroot)
				var ebg := ColorRect.new()
				ebg.set_anchors_preset(Control.PRESET_FULL_RECT)
				ebg.color = Color(0.02, 0.015, 0.012)
				eroot.add_child(ebg)
				var evb := VBoxContainer.new()
				evb.set_anchors_preset(Control.PRESET_CENTER)
				evb.grow_horizontal = Control.GROW_DIRECTION_BOTH
				evb.grow_vertical = Control.GROW_DIRECTION_BOTH
				evb.offset_left = -560
				evb.offset_right = 560
				evb.add_theme_constant_override("separation", 14)
				eroot.add_child(evb)
				var et := ZUI.label("СЦЕНА ЛОКАЦИИ ПОВРЕЖДЕНА", 30, ZUI.ALERT)
				et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				evb.add_child(et)
				var e2 := ZUI.wrap_label(SceneCheck.report(path, sc_errs) + "\n\nВерните файл из резервной копии или исправьте строки выше (номера строк — по файлу .tscn). Игра возвращена в главное меню.", 15, ZUI.TEXT, 1060.0)
				evb.add_child(e2)
				var eb := ZUI.ZButton.new("В ГЛАВНОЕ МЕНЮ", Vector2(320, 54), true, 15, "door")
				eb.pressed.connect(func():
						G.play_sfx("ui_click", -8.0)
						to_main_menu())
				evb.add_child(eb)
				G.play_sfx("z_beep_alarm", -12.0)
				return
		var ps: PackedScene = load(path)
		if ps == null:
				push_error("Не найдена сцена локации: " + path)
				to_main_menu()
				return
		var loc := ps.instantiate()
		current_screen = loc
		add_child(loc)
		if loc.has_method("enter"):
				loc.enter(spawn_id)

# Финальная дверь главы: экран победы главы.
func end_of_chapter() -> void:
		await show_loading("Глава завершена…", 0.6)
		G.zsave["chapter_done"] = int(G.zsave.get("chapter_done", 0)) + 1
		G.write_save()
		_zwin_screen()

# ---------- ВЫБОР СЛОЖНОСТИ ПРОЛОГА (ТЗ п.18) ----------
func _show_zdiff_select() -> void:
	_clear()
	var layer:=CanvasLayer.new()
	layer.layer=10
	add_child(layer)
	current_screen=layer
	preload("res://scripts/ui/cinematic_pages.gd").open(self,layer,"difficulty")

# ---------- ПЕРЕХОД «СНЕЖНАЯ ЛИНИЯ» (ТЗ п.15–16) ----------
func _snow_line_transition() -> void:
		G.zsave["pvars"]["snowline_shown"] = true
		G.write_save()
		_clear()
		var layer := CanvasLayer.new()
		layer.layer = 10
		current_screen = layer
		add_child(layer)
		var scr := Control.new()
		scr.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(scr)
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.02, 0.024, 0.03)
		scr.add_child(bg)
		scr.add_child(ZUI.scanlines())
		scr.add_child(ZUI.vignette(0.6))
		var cs := ZCutscene.new()
		cs.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(cs)
		await cs.play([
				{"wait": 1.0, "sfx": "z_blizzard_loop", "sfx_db": -8.0},
				{"speaker": "ПОВЕРХНОСТЬ · СНЕЖНАЯ ЛИНИЯ", "col": ZCutscene.C_MEMORY,
						"text": "Внешние ворота открываются. Ледяной ветер. Ночь, снег, разрушенные мачты связи и заброшенные здания. Волков падает на колено, пытаясь вдохнуть.",
						"speed": 0.038, "hold": 1.4, "wait": 1.0},
				{"speaker": "", "col": ZCutscene.C_MEMORY,
						"text": "В небе — низкие облака. И красное свечение на горизонте.",
						"hold": 1.2, "wait": 1.0},
				{"wait": 0.6, "sfx": "z_radio_bed", "sfx_db": -14.0},
				{"speaker": "РАЦИЯ", "col": ZCutscene.C_RADIO,
						"text": "«...Заря... приём...»",
						"hold": 1.0, "wait": 0.8},
				{"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
						"text": "«Я на связи. Кто говорит?»",
						"hold": 1.0, "wait": 0.7},
				{"speaker": "ОПЕРАТОР", "col": ZCutscene.C_RADIO,
						"text": "«Назовите позывной».",
						"hold": 1.0, "wait": 0.7},
				{"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
						"text": "«Волков. Капитан Алексей Волков».",
						"hold": 1.0, "wait": 0.8},
				{"speaker": "ОПЕРАТОР", "col": ZCutscene.C_RADIO,
						"text": "«Невозможно».",
						"hold": 1.0, "wait": 0.8},
				{"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
						"text": "«Повтори».",
						"hold": 0.9, "wait": 0.8},
				{"speaker": "ОПЕРАТОР", "col": ZCutscene.C_ALERT,
						"text": "«Капитан Волков числится погибшим восемь месяцев».",
						"hold": 1.4, "wait": 0.9},
				{"wait": 0.5, "sfx": "z_radio_beep", "sfx_db": -14.0},
				{"speaker": "РАЦИЯ · АВТОМАТИЧЕСКОЕ СООБЩЕНИЕ", "col": ZTerminal.CRT_RED,
						"text": "ПРОТОКОЛ «СЕВЕР» / ОБНАРУЖЕН АКТИВНЫЙ СУБЪЕКТ / НАЧАТЬ ПОИСК",
						"hold": 1.4, "wait": 0.9},
				{"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
						"text": "«Алексей, у вас осталось приблизительно девять минут».",
						"hold": 1.2, "wait": 0.8},
				{"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
						"text": "«До чего?»",
						"hold": 0.9, "wait": 0.8},
				{"speaker": "ИИ «ЗАРЯ»", "col": ZCutscene.C_AI,
						"text": "«До прибытия группы зачистки».",
						"hold": 1.2, "wait": 0.8},
				{"wait": 0.5, "sfx": "z_beep_alarm", "sfx_db": -12.0, "red": true},
				{"speaker": "ПЛОЩАДКА", "col": ZCutscene.C_SYSTEM,
						"text": "На площадке загораются прожекторы. Вооружённые люди. Без опознавательных знаков.",
						"shake": 0.6, "shake_k": 9.0, "hold": 1.2, "wait": 0.8},
				{"speaker": "ВОЛКОВ", "col": ZCutscene.C_VOLKOV,
						"text": "«Здесь капитан Волков! Я военный! Мне нужна эвакуация!»",
						"hold": 1.2, "wait": 0.8},
				{"speaker": "КОМАНДИР ГРУППЫ · ПО РАЦИИ", "col": ZCutscene.C_ALERT,
						"text": "«Цель визуально подтверждена. Субъект V-17 обнаружен. Разрешение на ликвидацию получено».",
						"hold": 1.4, "wait": 0.8},
				{"wait": 0.4, "sfx": "z_shot_rifle", "sfx_db": -4.0, "flash": 0.05, "flash_col": Color(1, 1, 1, 0.8), "flash_fade": 0.6, "shake": 0.7, "shake_k": 14.0, "red_off": true},
				{"speaker": "СЦЕНА", "col": ZCutscene.C_SYSTEM,
						"text": "Первый выстрел разбивает рацию. Волков бросается к укрытию.",
						"hold": 1.2, "wait": 0.8},
				{"wait": 0.8, "veil": 2.2, "veil_to": 1.0},
				{"speaker": "", "col": ZUI.NEON_BRIGHT,
						"text": "ГЛАВА I\nСНЕЖНАЯ ЛИНИЯ",
						"speed": 0.05, "hold": 1.8, "wait": 1.0},
				{"speaker": "", "col": ZUI.FAINT,
						"text": "Конец пролога.",
						"hold": 1.4, "wait": 0.8},
		])
		if is_instance_valid(layer):
				layer.queue_free()

func _show_bunker_complete() -> void:
	_clear()
	var layer := CanvasLayer.new()
	current_screen = layer
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.014,0.022,0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -400
	v.offset_right = 400
	v.offset_top = -130
	v.add_theme_constant_override("separation",24)
	root.add_child(v)
	for text in ["ЛОКАЦИЯ 1 ЗАВЕРШЕНА", "БУНКЕР «ЗАРЯ»", "Вы вернули меня… Зачем?"]:
		var l := ZUI.label(text,28,ZUI.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var b := ZUI.ZButton.new("В ГЛАВНОЕ МЕНЮ",Vector2(400,60),true,18,"door")
	b.pressed.connect(to_main_menu)
	v.add_child(b)
