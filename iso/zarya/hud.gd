extends CanvasLayer
const Polar=preload("res://scripts/ui/bunker_skin.gd")
const BunkerIcons=preload("res://scripts/ui/bunker_icons.gd")
const State=preload("res://iso/zarya/state.gd")
const Journal=preload("res://iso/zarya/journal.gd")
const Back=preload("res://scripts/ui/native_back.gd")
const Icons=preload("res://scripts/ui/equipment_icons.gd")
var world
var inventory_view
var terminal_view
var root: Control
var objective: Label
var notice: Label
var notice_panel: PanelContainer
var bars := {}
var slots: Array = []
var modal: Control
var selected := ""
var moving_from := ""
var selected_zone := "Торс"
var minimap
var weapon_status: Label
var health_readout: Label
var dead_shown := false
var timer := 0.0
var refresh_clock := 0.0
var interaction_hint: Label
var interaction_icons := {}
var interaction_marker: PanelContainer
var interaction_marker_icon: TextureRect
var repair_panel: PanelContainer
var repair_bar: ProgressBar
var modal_feedback: Label
var message_in_modal := false
var medical_heading: Label
var medical_readings: Label
var medical_body: Control
var medical_zones := {}
var medical_actions := {}
var _back_tree: SceneTree
func show_repair(title: String) -> void:
	hide_repair()
	repair_panel=panel(root,Vector2(canvas_size.x/2-240,canvas_size.y-295),Vector2(480,140))
	var column:=VBoxContainer.new();repair_panel.add_child(column)
	label(column,title,16)
	repair_bar=ProgressBar.new();repair_bar.max_value=1.0;repair_bar.show_percentage=false;repair_bar.custom_minimum_size.y=14;column.add_child(repair_bar)
	button(column,"ОТМЕНА",world.cancel_repair,200)
func update_repair(progress: float) -> void:
	if is_instance_valid(repair_bar): repair_bar.value=progress
func hide_repair() -> void:
	if is_instance_valid(repair_panel): repair_panel.queue_free()
	repair_panel=null;repair_bar=null
func style() -> StyleBoxFlat:
	return Polar.surface(14)
func surface_style() -> StyleBoxFlat:
	return Polar.surface(14)
func label(parent: Node, text: String, size := 18) -> Label:
	var result:=Label.new(); result.text=text
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("#bdcbd0"))
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result
func icon_button(parent: Node, id: String, hint: String, callback: Callable) -> Button:
	var b:=button(parent,"",callback,60)
	b.custom_minimum_size=Vector2(60,60); b.tooltip_text=hint; b.accessibility_name=hint
	b.icon=load("res://assets/ui/controls/"+id+".svg"); b.expand_icon=true
	b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER; b.add_theme_constant_override("icon_max_width",32)
	var disabled:=style(); disabled.bg_color=Color("#10171c"); b.add_theme_stylebox_override("disabled",disabled)
	b.add_theme_color_override("icon_disabled_color",Color(0.4,0.5,0.55,0.4))
	return b
func button(parent: Node, text: String, callback: Callable, width := 110) -> Button:
	var b:=Button.new(); b.text=text; b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size=Vector2(width,52)
	b.add_theme_stylebox_override("normal",surface_style())
	var hover:=style(); hover.bg_color=Color("#1c373c"); hover.border_color=Color("#83c6c3")
	b.add_theme_stylebox_override("hover",hover)
	var pressed:=style(); pressed.bg_color=Color("#304b4c"); pressed.border_color=Color("#dfbc82")
	b.add_theme_stylebox_override("pressed",pressed)
	var focus:=style(); focus.bg_color=Color.TRANSPARENT; focus.border_color=Color("#dfbc82"); focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",focus)
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",Color("#b8d1dc"))
	Polar.button(b)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
func panel(parent: Node, at: Vector2, dimensions: Vector2) -> PanelContainer:
	var p:=PanelContainer.new(); p.position=at; p.custom_minimum_size=dimensions
	p.add_theme_stylebox_override("panel",surface_style()); parent.add_child(p)
	return p
var icon_cache := {}
var detail_title: Label
var detail_description: Label
var detail_image: TextureRect
var item_actions := {}
var shade: ColorRect
var hud_body
var last_map_position := Vector3.INF
var last_map_count := -1
var canvas_size := Vector2(1600,900)
func place(node: Control, rect: Rect2) -> void:
	node.position=rect.position; node.size=rect.size
func _fit_canvas() -> void:
	var viewport_size:=get_viewport().get_visible_rect().size
	var safe:=Rect2(Vector2.ZERO,viewport_size)
	if OS.has_feature("mobile"):
		var pixels:=DisplayServer.get_display_safe_area()
		var window_pixels:=Vector2(DisplayServer.window_get_size())
		if pixels.has_area() and window_pixels.x>0 and window_pixels.y>0:
			var ratio:=viewport_size/window_pixels
			safe=Rect2(Vector2(pixels.position)*ratio,Vector2(pixels.size)*ratio).intersection(safe)
	var factor:=minf(1.0,minf(safe.size.x/1600.0,safe.size.y/900.0))
	# Enlarge the playing controls without crowding the inventory/reader layouts.
	if not is_instance_valid(modal):factor*=1.10
	root.scale=Vector2.ONE*factor; root.position=safe.position; root.size=safe.size/factor
	canvas_size=root.size
	_layout_hud()
func _layout_hud() -> void:
	if not root.has_node("Tasks"): return
	var w:=canvas_size.x; var h:=canvas_size.y
	var rects: Dictionary={
		"Tasks":Rect2(24,24,300,118),"Vitals":Rect2((348+w-624-340)/2,24,340,76),
		"Tools":Rect2(18,h-80,198,60),"Condition":Rect2(24,158,112,142),
		"Map":Rect2(w-244,24,220,178),"Belt":Rect2(w/2-321,h-142,642,124),
		"Check":Rect2(w/2-450,h-126,90,96),"MoveStick":Rect2(22,h-395,245,245),
		"AimStick":Rect2(w-267,h-395,245,245),"Interact":Rect2(w-350,h-310,72,72),
		"Weapon":Rect2(w-600,24,330,76),"Utilities":Rect2(w-226,h-80,208,60),
		"InteractionHint":Rect2(w-730,h-306,360,80),
		"CapsuleWake":Rect2(w/2-190,h-235,380,64),
		"Notice":Rect2(w/2-350,114,700,64)}
	for key in rects:
		var n=root.get_node_or_null(NodePath(key))
		if n: n.position=rects[key].position; n.size=rects[key].size
	if is_instance_valid(shade): shade.size=canvas_size
	if is_instance_valid(repair_panel): repair_panel.position=Vector2(canvas_size.x/2-240,canvas_size.y-295)
	if is_instance_valid(modal):
		if modal.get_meta("paper",false):
			modal.size=Vector2(990,800);modal.position=(canvas_size-modal.size)/2
		elif modal.get_meta("compact",false):
			modal.size=modal.get_meta("preferred_size",Vector2(640,610)); modal.position=(canvas_size-modal.size)/2
		else: modal.position=Vector2(24,36); modal.size=canvas_size-Vector2(48,72)
func _ready() -> void:
	world=get_parent(); world.hud=self
	Back.install(self,handle_back)
	root=Control.new(); root.theme=Polar.make_theme(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	_fit_canvas(); get_viewport().size_changed.connect(_fit_canvas)
	var task:=panel(root,Vector2(20,24),Vector2(300,130)); task.name="Tasks"
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",14); task.add_child(column)
	var task_heading:=label(column,"ЗАДАЧА",13)
	task_heading.add_theme_color_override("font_color",Color("#80bbb9"))
	column.add_child(HSeparator.new())
	objective=label(column,"",18)
	objective.add_theme_color_override("font_color",Color("#e0e4e3"))
	var journal_hit:=Button.new();journal_hit.name="OpenJournal";journal_hit.flat=true;journal_hit.tooltip_text="Журнал бункера / текущий шаг и найденные следы";journal_hit.accessibility_name="Открыть журнал бункера";task.add_child(journal_hit);journal_hit.pressed.connect(func():
		if not bool(world.state.data.awake):world.player.request_wake()
		else:open_journal())
	var status:=panel(root,Vector2(566,18),Vector2(320,72)); status.name="Vitals"
	var stack:=VBoxContainer.new(); stack.add_theme_constant_override("separation",10); status.add_child(stack)
	for entry in [["health","ЗДОРОВЬЕ",Color("#d66660")],["water","ВОДА",Color("#74b4cf")]]:
		var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",16); stack.add_child(row)
		var title:=label(row,entry[1],13); title.custom_minimum_size.x=78
		var bar:=preload("res://iso/zarya/meter.gd").new(); bar.tint=entry[2]; bar.custom_minimum_size=Vector2(180,19)
		row.add_child(bar); bars[entry[0]]=bar
	var tools:=HBoxContainer.new(); tools.position=Vector2(980,22); tools.add_theme_constant_override("separation",8); root.add_child(tools); tools.name="Tools"
	icon_button(tools,"bag","Рюкзак",open_inventory)
	icon_button(tools,"pda","КПК",open_pda)
	icon_button(tools,"pause","Пауза",pause_menu)
	var condition:=panel(root,Vector2(392,18),Vector2(112,142)); condition.name="Condition"
	var condition_stack:=VBoxContainer.new(); condition.add_child(condition_stack)
	health_readout=label(condition_stack,"V-17 / 100%",12)
	var body_area:=Control.new(); body_area.custom_minimum_size=Vector2(120,100); condition_stack.add_child(body_area)
	hud_body=preload("res://iso/zarya/body.gd").new(); hud_body.ui=self
	hud_body.scale=Vector2(0.25,0.25); hud_body.position=Vector2(1,0); hud_body.size=Vector2(340,410)
	hud_body.mouse_filter=Control.MOUSE_FILTER_IGNORE; body_area.add_child(hud_body)
	var body_hit:=Button.new(); body_hit.flat=true; body_hit.tooltip_text="Состояние организма / лечение"
	body_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body_hit.pressed.connect(open_medical); body_area.add_child(body_hit)
	var map_frame:=panel(root,Vector2(1325,18),Vector2(214,168)); map_frame.name="Map"
	var map_stack:=VBoxContainer.new(); map_frame.add_child(map_stack)
	label(map_stack,"ЗАРЯ  /  ПОДЗЕМНЫЙ УРОВЕНЬ −2",14)
	minimap=preload("res://iso/zarya/minimap.gd").new(); minimap.world=world; minimap.custom_minimum_size=Vector2(184,98); map_stack.add_child(minimap)
	var bottom:=HBoxContainer.new(); bottom.position=Vector2(418,752); bottom.add_theme_constant_override("separation",7); root.add_child(bottom); bottom.name="Belt"
	for entry in [["left","ЛЕВАЯ РУКА"],["right","ПРАВАЯ РУКА"],["quick0","ЛЕЧЕНИЕ"],["quick1","БЫСТРЫЙ ДОСТУП"],["quick2","БЫСТРЫЙ ДОСТУП"],["quick3","УТИЛИТЫ"]]:
		var col:=VBoxContainer.new(); col.custom_minimum_size.x=102; col.add_theme_constant_override("separation",3); bottom.add_child(col)
		var heading:=label(col,entry[1],10); heading.custom_minimum_size=Vector2(102,26); heading.autowrap_mode=TextServer.AUTOWRAP_OFF; heading.clip_text=true; heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var cell:=make_slot(col,entry[0],true); cell.custom_minimum_size=Vector2(102,80)
	var check:=icon_button(root,"ammo","Проверить магазин",world.player.check_ammo); check.name="Check"
	for side in [0,1]:
		var stick:=preload("res://iso/zarya/stick.gd").new(); stick.set_meta("side",side); root.add_child(stick)
		place(stick,Rect2(55 if side==0 else 1285,510,245,245))
		stick.name="MoveStick" if side==0 else "AimStick"
		if side==1:stick.double_tapped.connect(world.player.reload)
	var interact:=icon_button(root,"hand","Взаимодействовать",func():
		if not bool(world.state.data.awake):world.player.request_wake()
		else:world.interact()); interact.name="Interact"
	var wake_button:=button(root,"ОТКРЫТЬ КАПСУЛУ",world.player.request_wake,380);wake_button.name="CapsuleWake";wake_button.hide()
	interaction_hint=label(root,"",18); interaction_hint.name="InteractionHint"
	interaction_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	interaction_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.add_theme_color_override("font_color",Color("#e2c18b"))
	for key in ["hand","door","terminal","search"]: interaction_icons[key]=load("res://assets/ui/controls/"+key+".svg")
	interaction_marker=PanelContainer.new(); interaction_marker.name="InteractionMarker"
	interaction_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	interaction_marker.custom_minimum_size=Vector2(46,46)
	var marker_style:=style(); marker_style.bg_color=Color(0.025,0.045,0.05,0.94)
	marker_style.border_color=Color("#e2c18b"); marker_style.set_border_width_all(2); marker_style.set_content_margin_all(8)
	interaction_marker.add_theme_stylebox_override("panel",marker_style)
	root.add_child(interaction_marker)
	interaction_marker_icon=TextureRect.new(); interaction_marker_icon.custom_minimum_size=Vector2(28,28)
	interaction_marker_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	interaction_marker_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	interaction_marker_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	interaction_marker.add_child(interaction_marker_icon); interaction_marker.hide()
	var gun_panel:=panel(root,Vector2(1000,24),Vector2(330,76)); gun_panel.name="Weapon"
	var gun_row:=HBoxContainer.new(); gun_panel.add_child(gun_row)
	weapon_status=label(gun_row,"",14); weapon_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	icon_button(gun_row,"reload","Перезарядить",world.player.reload)
	var utility:=HBoxContainer.new(); utility.position=Vector2(26,820); utility.add_theme_constant_override("separation",7); root.add_child(utility); utility.name="Utilities"
	icon_button(utility,"flashlight","Фонарь",world.player.toggle_flashlight)
	icon_button(utility,"minus","Отдалить камеру",func(): world.get_node("Camera").desired_size=minf(24,world.get_node("Camera").desired_size+1))
	icon_button(utility,"plus","Приблизить камеру",func(): world.get_node("Camera").desired_size=maxf(10,world.get_node("Camera").desired_size-1))
	notice_panel=panel(root,Vector2(560,116),Vector2(700,64));notice_panel.name="Notice";notice_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var subtitle_style:=style();subtitle_style.bg_color=Color(0.015,0.027,0.035,0.94);subtitle_style.border_color=Color("#627b81");subtitle_style.set_content_margin_all(12);notice_panel.add_theme_stylebox_override("panel",subtitle_style)
	notice=label(notice_panel,"",18);notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;notice.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;notice.mouse_filter=Control.MOUSE_FILTER_IGNORE;notice_panel.hide()
	world.state.changed.connect(func(): hud_body.queue_redraw())
	world.state.changed.connect(refresh_slots)
	refresh_slots()
	call_deferred("_fit_canvas")
func icon_for(id: String) -> Texture2D:
	var modern:Texture2D=BunkerIcons.get_icon(id)
	if modern!=null:return modern
	if icon_cache.has(id): return icon_cache[id]
	var custom_path: String="res://assets/ui/zarya/"+id+".svg"
	if ResourceLoader.exists(custom_path):
		icon_cache[id]=load(custom_path)
		return icon_cache[id]
	var texture: Texture2D
	if id=="pistol":
		var atlas:=AtlasTexture.new(); atlas.atlas=Icons.ATLAS; atlas.region=Rect2(81,165,470,359); texture=atlas
	else: texture=Icons.get_icon(id)
	if texture!=null:
		icon_cache[id]=texture
		return texture
	var path: String="res://assets/icons/"+str(State.ITEMS.get(id,{}).get("icon","gear"))+".svg"
	var result:=load(path) as Texture2D if ResourceLoader.exists(path) else null
	icon_cache[id]=result
	return result
func make_slot(parent: Node, key: String, shortcut := false) -> Button:
	var cell:=preload("res://iso/zarya/slot.gd").new()
	cell.ui=self; cell.key=key; cell.custom_minimum_size=Vector2(90,78)
	Polar.button(cell); cell.add_theme_stylebox_override("normal",surface_style()); cell.expand_icon=true
	cell.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cell.vertical_icon_alignment=VERTICAL_ALIGNMENT_CENTER
	cell.add_theme_constant_override("icon_max_width",76)
	cell.set_meta("hud_shortcut",shortcut)
	cell.pressed.connect(func():
		if shortcut:activate_shortcut(key)
		else:select_slot(key))
	parent.add_child(cell); slots.append(cell)
	return cell
func refresh_slots() -> void:
	if inventory_view!=null:inventory_view.refresh_summary()
	var kept: Array=[]
	for cell in slots:
		if not is_instance_valid(cell): continue
		kept.append(cell)
		var item: Dictionary=world.state.data.slots.get(cell.key,{})
		cell.icon=icon_for(item.get("id","")) if not item.is_empty() else null
		cell.text=""
		cell.queue_redraw()
		cell.tooltip_text=State.ITEMS.get(item.get("id",""),{}).get("name","Пусто")
		if cell.get_meta("hud_shortcut",false):cell.tooltip_text+=" / коснитесь для действия" if not item.is_empty() else " / настроить в инвентаре"
	slots=kept
func select_slot(key: String) -> void:
	if inventory_view!=null:inventory_view.show_right("item")
	if not moving_from.is_empty():
		if key==moving_from:cancel_move();notify("ПЕРЕНОС ОТМЕНЁН");return
		move_item(moving_from,key);return
	selected=key;refresh_slots();update_details()
func cancel_move() -> void:
	moving_from="";refresh_slots();update_details()
func begin_move() -> void:
	if not moving_from.is_empty():cancel_move();return
	if not world.state.data.slots.has(selected):return
	moving_from=selected;refresh_slots();update_details()
	notify("КОСНИТЕСЬ ПОДСВЕЧЕННОЙ ЯЧЕЙКИ / ПОВТОРНОЕ КАСАНИЕ ПРЕДМЕТА ОТМЕНЯЕТ ПЕРЕНОС")
func move_item(source: String, target: String) -> bool:
	if not world.state.move_slot(source,target):
		notify("ЭТА ЯЧЕЙКА НЕ ПОДХОДИТ / ПРОВЕРЬТЕ ТИП ПРЕДМЕТА И СВОБОДНЫЕ РУКИ");return false
	moving_from="";selected=target;refresh_slots();update_details();world.save_state()
	notify("ПРЕДМЕТ ПЕРЕНЕСЁН / "+str(State.ITEMS[world.state.data.slots[target].id].name))
	return true
func activate_shortcut(key: String) -> void:
	if not world.player.can_act():return
	selected=key
	var entry: Dictionary=world.state.data.slots.get(key,{})
	var id: String=entry.get("id","")
	if id in ["food","water"]:consume();return
	if id in ["band","medkit","morph"]:
		var field: String={"band":"bleeding","medkit":"damage","morph":"pain"}[id]
		var worst:=0.0
		for zone in State.ZONES:
			var severity: float=world.state.data.wounds[zone][field]
			if severity>worst:worst=severity;selected_zone=zone
		open_medical();return
	if id=="flashlight":
		if key in ["left","right"]:world.player.toggle_flashlight()
		else:
			var hand: String=""
			for candidate in ["left","right"]:
				if not world.state.data.slots.has(candidate) and world.state.can_move_slot(key,candidate):hand=candidate;break
			if hand.is_empty():open_inventory();notify("ОСВОБОДИТЕ РУКУ ДЛЯ ФОНАРЯ");return
			world.state.move_slot(key,hand);world.state.data["flash_on"]=true
		world.save_state();return
	open_inventory()
	if entry.is_empty():notify("ПЕРЕТАЩИТЕ ПРЕДМЕТ В ЭТУ ЯЧЕЙКУ БЫСТРОГО ДОСТУПА" if key.begins_with("quick") else "ВЫБЕРИТЕ ПРЕДМЕТ ДЛЯ ЭТОЙ РУКИ")
func _process(delta: float) -> void:
	if not world.startup_ready:
		if not is_instance_valid(modal):startup_failure()
		root.get_node("CapsuleWake").hide()
		return
	if not is_instance_valid(modal) and is_instance_valid(shade):close_modal()
	var wake_button:Button=root.get_node("CapsuleWake")
	wake_button.visible=not bool(world.state.data.awake) and not is_instance_valid(modal)
	wake_button.text="ВСТАТЬ ИЗ КАПСУЛЫ" if world.player.waking else "ОТКРЫТЬ КАПСУЛУ"
	# Containers can briefly measure wrapped text before their width is assigned.
	# Reconcile the live window after that deferred minimum-size pass has settled.
	if is_instance_valid(modal):
		var desired:Vector2=Vector2(990,800) if modal.get_meta("paper",false) else (modal.get_meta("preferred_size",Vector2(640,610)) if modal.get_meta("compact",false) else canvas_size-Vector2(48,72))
		if modal.size!=desired:
			modal.size=desired
			modal.position=(canvas_size-modal.size)/2 if modal.get_meta("paper",false) or modal.get_meta("compact",false) else Vector2(24,36)
	_update_world_marker()
	var controls_active: bool=modal==null and world.player.can_act()
	for key in ["MoveStick","AimStick"]:root.get_node(key).set_input_enabled(controls_active)
	if controls_active:
		world.player.move_vector=root.get_node("MoveStick").get_move_vector()
		world.player.sprinting=root.get_node("MoveStick").double_held and world.player.move_vector.length()>.05
		world.player.aim_vector=root.get_node("AimStick").get_move_vector()
		world.player.fire=world.player.aim_vector.length()>0.8
	else:
		world.player.clear_controls()
	refresh_clock+=delta
	if refresh_clock>0.15:
		refresh_clock=0
		objective.text=world.objective()
		_update_interaction()
		for key in bars: bars[key].value=world.state.data[key]
		health_readout.text="V-17 / %d%%" % roundi(float(world.state.data.health))
		var bleeding: bool=world.state.data.wounds.values().any(func(wound):return float(wound.bleeding)>0)
		health_readout.add_theme_color_override("font_color",Color("#ee9b83") if bleeding or float(world.state.data.health)<30 else Color("#bdcbd0"))
		health_readout.tooltip_text="ЕСТЬ КРОВОТЕЧЕНИЕ / откройте лечение" if bleeding else "Здоровье / откройте схему тела для лечения"
		if last_map_position.distance_squared_to(world.player.position)>0.04 or last_map_count!=world.state.data.visited.size():
			minimap.queue_redraw(); last_map_position=world.player.position; last_map_count=world.state.data.visited.size()
		var description: String="?"
		if world.state.data.checked: description="почти полный" if world.state.data.mag>=6 else ("меньше половины" if world.state.data.mag>0 else "пуст")
		weapon_status.text=("ОРУЖИЕ НЕ В РУКАХ" if world.state.weapon().is_empty() else "ПМ / МАГАЗИН: "+description)+"\nЗАПАС: "+str(world.state.amount("ammo"))+" × 9×18"
		if float(world.state.data.health)<=0 and not dead_shown:
			dead_shown=true
			var column:=window("V-17 / ЖИЗНЕННЫЕ ПОКАЗАТЕЛИ УТРАЧЕНЫ")
			modal.find_child("WindowClose",true,false).hide()
			button(column,"НАЧАТЬ УРОВЕНЬ ЗАНОВО",restart_level,400)
	if timer>0:
		timer-=delta; notice_panel.modulate.a=minf(1,timer)
	else:
		notice_panel.hide()
		if is_instance_valid(modal_feedback):modal_feedback.hide()
	if modal!=null:notice_panel.hide()
func notify(text: String) -> void:
	if text.is_empty(): return
	notice.text=text; timer=7; notice_panel.modulate.a=1;notice_panel.show()
	message_in_modal=is_instance_valid(modal_feedback)
	if message_in_modal:modal_feedback.text=text;modal_feedback.show()
func reset_controls() -> void:
	world.player.clear_controls()
	for key in ["MoveStick","AimStick"]:
		var stick=root.get_node_or_null(key)
		if stick:stick.reset()
func pointer_blocks_world() -> bool:
	if modal!=null or not world.player.can_act():return true
	if get_viewport().gui_get_hovered_control()!=null:return true
	for key in ["MoveStick","AimStick"]:
		var stick=root.get_node(key)
		if stick._pointer!=-1 or stick._mouse_down:return true
	return false
func close_modal() -> void:
	inventory_view=null;terminal_view=null
	moving_from=""
	if message_in_modal:
		timer=0;notice_panel.hide();message_in_modal=false
	if is_instance_valid(shade): shade.queue_free()
	shade=null
	if is_instance_valid(modal): modal.queue_free()
	for child in root.get_children():
		if child!=modal and child!=shade and child.has_meta("overlay_alpha"):
			child.modulate.a=float(child.get_meta("overlay_alpha"));child.remove_meta("overlay_alpha")
	modal=null;modal_feedback=null; world.paused=false
	call_deferred("_restore_hud_layout")
	reset_controls()
	world.save_state()
func _restore_hud_layout() -> void:
	if modal!=null:return
	_fit_canvas()
	for node in root.find_children("*","Control",true,false):
		if node is Container:node.queue_sort()
		node.queue_redraw()
	root.queue_redraw()
func window(title: String) -> VBoxContainer:
	world.cancel_repair()
	close_modal()
	for key in ["MoveStick","AimStick"]:root.get_node(key).set_input_enabled(false)
	for child in root.get_children():
		if child!=modal:
			child.set_meta("overlay_alpha",child.modulate.a);child.modulate.a=0
	shade=ColorRect.new(); shade.color=Color(0.005,0.01,0.015,0.65); shade.size=canvas_size; root.add_child(shade)
	modal=PanelContainer.new(); modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.position=Vector2(24,36); modal.size=canvas_size-Vector2(48,72)
	modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var surface:=style(); surface.set_content_margin_all(20); surface.border_width_top=1; surface.border_color=Polar.ICE
	modal.add_theme_stylebox_override("panel",surface); root.add_child(modal)
	_fit_canvas()
	var grain=preload("res://scripts/ui/document_material.gd").new();grain.name="WindowGrain";modal.add_child(grain)
	world.paused=true
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",10); modal.add_child(column)
	var header:=HBoxContainer.new(); column.add_child(header)
	var text:=label(header,title,24); text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close_button:=icon_button(header,"close","Закрыть",close_modal);close_button.name="WindowClose"
	column.add_child(HSeparator.new())
	modal_feedback=label(column,"",17);modal_feedback.name="WindowFeedback";modal_feedback.add_theme_color_override("font_color",Polar.GOLD);modal_feedback.hide()
	modal.modulate.a=0; create_tween().tween_property(modal,"modulate:a",1.0,0.18)
	call_deferred("_redraw_overlay")
	return column
func _redraw_overlay() -> void:
	# Rebuild draw commands once after replacing an overlay in the same frame.
	# Compatibility can otherwise retain stale commands from the retired window.
	if not is_instance_valid(modal): return
	modal.queue_redraw()
	for node in modal.find_children("*","Control",true,false): node.queue_redraw()
func bag(parent: Node) -> void:
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(580,440); parent.add_child(scroll)
	var sections:=VBoxContainer.new(); sections.add_theme_constant_override("separation",12); scroll.add_child(sections)
	for group in [["ЭКИПИРОВКА",["left","right","clothes","pocket0","pocket1"]],["БЫСТРЫЙ ДОСТУП",["quick0","quick1","quick2","quick3"]],["РЮКЗАК",[]]]:
		label(sections,group[0],12)
		var grid:=GridContainer.new(); grid.columns=6; grid.add_theme_constant_override("h_separation",6); grid.add_theme_constant_override("v_separation",6); sections.add_child(grid)
		var keys: Array=group[1]
		if group[0]=="РЮКЗАК":
			for i in range(18): keys.append("bag"+str(i))
		for key in keys:
			var cell:=make_slot(grid,key); cell.custom_minimum_size=Vector2(86,78)
	refresh_slots()
func update_details() -> void:
	if not is_instance_valid(detail_title): return
	var item: Dictionary=world.state.data.slots.get(selected,{})
	detail_title.text=State.ITEMS.get(item.get("id",""),{}).get("name","ВЫБЕРИТЕ ПРЕДМЕТ")
	detail_image.texture=icon_for(item.id) if not item.is_empty() else null
	for key in item_actions:
		if is_instance_valid(item_actions[key]):
			item_actions[key].disabled=item.is_empty() or (key=="use" and not world.state.can_consume_slot(selected)) or (key=="hand" and world.state.equip_target(selected).is_empty())
			if key=="split":item_actions[key].disabled=int(item.get("count",0))<2
	if is_instance_valid(item_actions.get("move")):item_actions.move.text="ОТМЕНИТЬ ПЕРЕНОС" if not moving_from.is_empty() else "ПЕРЕМЕСТИТЬ В ЯЧЕЙКУ"
	var hint: String="Коснитесь подсвеченной ячейки. Совместимые стопки объединятся." if not moving_from.is_empty() else "Перетащите предмет в ячейку или выберите действие."
	detail_description.text=("КОЛИЧЕСТВО  %s    /    СОСТОЯНИЕ  %s%%\n\n" % [item.get("count",1),item.get("condition",100)]+hint) if not item.is_empty() else "Снаряжение, карманы и быстрые слоты.\nВыберите предмет для осмотра."
func open_inventory() -> void:
	preload("res://iso/zarya/inventory_view.gd").new().build(self)
func equip_selected() -> void:
	var target: String=world.state.equip_target(selected)
	if target.is_empty():notify("НЕТ ПОДХОДЯЩЕЙ СВОБОДНОЙ РУКИ / ИСПОЛЬЗУЙТЕ ПЕРЕНОС В ЯЧЕЙКУ");return
	move_item(selected,target)
func split_selected() -> void:
	var target: String=world.state.split_slot(selected)
	if target.is_empty():notify("НУЖНА СТОПКА И СВОБОДНАЯ ЯЧЕЙКА РЮКЗАКА");return
	moving_from="";selected=target;refresh_slots();update_details();world.save_state();notify("ОДИН ПРЕДМЕТ ОТДЕЛЁН В РЮКЗАК")
func consume() -> void:
	var entry: Dictionary=world.state.data.slots.get(selected,{})
	if entry.is_empty(): return
	if entry.id in ["food","water"]:
		if not world.state.consume_slot(selected):notify("ЗАПАС ВОДЫ ПОЛОН" if entry.id=="water" else "ГОЛОДА НЕТ");return
		moving_from="";refresh_slots();update_details()
		notify("ЗАПАС ВОДЫ ВОСПОЛНЕН" if entry.id=="water" else "ПАЁК ИСПОЛЬЗОВАН")
		world.save_state()
func drop_selected() -> void:
	moving_from=""
	var entry: Dictionary=world.state.data.slots.get(selected,{})
	if entry.is_empty(): return
	var serial: int=int(world.state.data.get("next_drop_id",world.state.data.drops.size()))
	while world.state.data.containers.has("drop"+str(serial)):serial+=1
	var id: String="drop"+str(serial)
	world.state.data["next_drop_id"]=serial+1
	world.state.data.drops.append({"id":id,"item":entry.duplicate(),"position":[world.player.position.x,world.player.position.y,world.player.position.z]})
	world.state.data.slots.erase(selected)
	world.create_drop(world.state.data.drops.back())
	world.state.changed.emit();refresh_slots(); update_details();world.save_state()
func open_loot(action: Dictionary) -> void:
	preload("res://iso/zarya/inventory_view.gd").new().build(self,action)
func take_all(action: Dictionary) -> void:
	var count: int=world.state.loot_all(action.id)
	var remaining: bool=not world.state.data.containers.get(action.id,[]).is_empty()
	loot_flags()
	if not is_instance_valid(action.node) or action.node.is_queued_for_deletion():close_modal()
	else:open_loot(action)
	notify("РЮКЗАК ЗАПОЛНЕН / ЧАСТЬ ПРЕДМЕТОВ ОСТАЛАСЬ В ОБЪЕКТЕ" if remaining else ("ПРЕДМЕТЫ ПЕРЕНЕСЕНЫ В РЮКЗАК" if count>0 else "ОБЪЕКТ ПУСТ"))
func transfer(action: Dictionary, index: int) -> void:
	var taken: bool=world.state.loot(action.id,index)
	loot_flags()
	if not is_instance_valid(action.node) or action.node.is_queued_for_deletion():close_modal()
	else:open_loot(action)
	if not taken:notify("РЮКЗАК ЗАПОЛНЕН / ОСВОБОДИТЕ ЯЧЕЙКУ")
func loot_flags() -> void:
	if world.state.amount("pistol")>0:
		world.state.mark("armed")
		world.player.rig.perform("pickup")
	if world.state.amount("card")>0: world.state.mark("card")
	world.clear_empty_drops()
	world.save_state()
func reader_tools(parent: Node, text: RichTextLabel) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);parent.add_child(row)
	var caption:=label(row,"РАЗМЕР ТЕКСТА",16);caption.name="ReaderFontCaption";caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.custom_minimum_size.x=150;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var value:=label(row,str(world.state.data.get("reader_font_size",24)),16);value.name="ReaderFontValue";value.custom_minimum_size.x=34;value.autowrap_mode=TextServer.AUTOWRAP_OFF;value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	for step in [-2,2]:
		var control:=button(row,"А−" if step<0 else "А+",func():
			var px:=clampi(int(world.state.data.get("reader_font_size",24))+step,20,34)
			world.state.data["reader_font_size"]=px;text.add_theme_font_size_override("normal_font_size",px);value.text=str(px);world.save_state(),70)
		control.add_theme_font_size_override("font_size",20)
		control.name="ReaderDecrease" if step<0 else "ReaderIncrease"
func evidence_medium(action:Dictionary)->String:
	if action.has("medium"):return str(action.medium)
	var title:String=str(action.get("title","")).to_lower()
	return "terminal" if title.contains("переписк") or title.contains("терминал") or str(action.get("id","")) in ["identity_v17","guard_log","archive_chat","lab_observation"] else "paper"
func open_evidence(action: Dictionary) -> void:
	if evidence_medium(action)=="terminal":
		preload("res://iso/zarya/terminal_view.gd").new().build(self,action,action,true);return
	var column:=window("СЛУЖЕБНАЯ ЗАПИСКА")
	modal.set_meta("paper",true);modal.size=Vector2(990,800);modal.position=(canvas_size-modal.size)/2
	var sheet:=StyleBoxEmpty.new();sheet.set_content_margin_all(54);modal.add_theme_stylebox_override("panel",sheet)
	var grain=modal.get_node("WindowGrain");grain.kind="paper";grain.bleed=54;grain.image=load("res://assets/ui/bunker/paper.png");grain.queue_redraw()
	# The sheet is the window background, behind the live text and controls.
	grain.set_meta("full_paper",true)
	for child in column.get_children():
		if child is HBoxContainer:
			for item in child.get_children():
				if item is Label:item.add_theme_color_override("font_color",Color("#6f4037"))
	label(column,str(action.title),28).add_theme_color_override("font_color",Color("#2d302b"))
	var text:=RichTextLabel.new();text.name="EvidenceText";text.selection_enabled=true;text.size_flags_vertical=Control.SIZE_EXPAND_FILL;text.custom_minimum_size.y=250;text.add_theme_color_override("default_color",Color("#292d28"));text.add_theme_font_size_override("normal_font_size",int(world.state.data.get("reader_font_size",24)));text.add_theme_constant_override("line_separation",6);text.text=str(action.body).replace("\\n","\n");column.add_child(text)
	var tools:=VBoxContainer.new();column.add_child(tools);reader_tools(tools,text)
	for node in tools.find_children("*","Label",true,false):node.add_theme_color_override("font_color",Color("#55533f"))
	label(column,"КОПИЯ СОХРАНЕНА В КПК  /  V-17",14).add_theme_color_override("font_color",Color("#765346"))
	button(column,"УБРАТЬ ЗАПИСКУ",close_modal,320)
	for node in modal.find_children("*","Button",true,false):Polar.paper_button(node)
func open_terminal(action: Dictionary) -> void:
	var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://iso/bunker_records.json"))
	var record: Dictionary=records.get(action.record,{"title":"СЛУЖЕБНАЯ ЗАПИСЬ / СЕРОВ","body":"Резервный предохранитель оставлен в серверной. Карту заберите с моего рабочего места. После восстановления питания проверьте карантинную блокировку. Верхний уровень не отвечает."})
	record=record.duplicate(true)
	if not str(action.get("custom_text","")).is_empty(): record={"title":action.title,"body":action.custom_text}
	if action.id in ["power","generator","pump"]:
		record.body="Предохранитель установлен. Резервная цепь научно-технического уровня −2 готова к работе.\nПроверьте карантинную блокировку перед доступом к вертикальному узлу."
	if action.id=="archive": record.body=str(record.body)+"\n\nСИСТЕМА: грузовой шлюз требует подтверждения с верхнего уровня. Следуйте к лестничному узлу −1."
	preload("res://iso/zarya/terminal_view.gd").new().build(self,action,record)
func open_medical() -> void:
	if inventory_view==null:open_inventory()
	inventory_view.show_right("medical")
	refresh_medical()
func select_zone(zone: String) -> void:
	if zone not in State.ZONES:return
	selected_zone=zone
	if modal==null or not modal.get_meta("medical",false):open_medical()
	else:
		if inventory_view!=null:inventory_view.show_right("medical")
		refresh_medical()
func refresh_medical() -> void:
	if modal==null or not modal.get_meta("medical",false):return
	if selected_zone not in State.ZONES:selected_zone="Торс"
	var wound: Dictionary=world.state.data.wounds[selected_zone]
	medical_heading.text="ВЫБРАНО / "+selected_zone
	medical_readings.text="ПОВРЕЖДЕНИЕ  %d    ·    КРОВОТЕЧЕНИЕ  %.2f\nБОЛЬ  %d    ·    ЗДОРОВЬЕ  %d%%" % [int(wound.damage),float(wound.bleeding),int(wound.pain),roundi(float(world.state.data.health))]
	for zone in medical_zones:
		var entry: Dictionary=world.state.data.wounds[zone]
		medical_zones[zone].text=zone+(" •" if float(entry.damage)>0 or float(entry.bleeding)>0 or float(entry.pain)>0 else "")
		medical_zones[zone].tooltip_text="Повреждение %d / кровотечение %.2f / боль %d" % [int(entry.damage),float(entry.bleeding),int(entry.pain)]
		medical_zones[zone].button_pressed=zone==selected_zone
	for medicine in medical_actions:
		var action: Button=medical_actions[medicine]
		var count: int=world.state.amount(medicine)
		action.text=str(action.get_meta("caption"))+"\n"+str(State.ITEMS[medicine].name)+" × "+str(count)
		action.disabled=not world.state.can_treat(selected_zone,medicine)
		action.tooltip_text="Лечение этой области не требуется" if not world.state.needs_treatment(selected_zone,medicine) else ("Нет препарата в снаряжении" if count==0 else "Применить к выбранной области")
	medical_body.queue_redraw();hud_body.queue_redraw()
	if inventory_view!=null:inventory_view.refresh_summary()
func treat_selected(medicine: String) -> void:
	if not world.state.treat(selected_zone,medicine):
		notify("НЕТ ПРЕПАРАТА В СНАРЯЖЕНИИ" if world.state.amount(medicine)==0 else "ЛЕЧЕНИЕ ЭТОЙ ОБЛАСТИ НЕ ТРЕБУЕТСЯ");return
	world.player.rig.perform("treat");refresh_medical();world.save_state()
	notify(selected_zone+" / ПРЕПАРАТ ПРИМЕНЁН")
func open_pda() -> void:
	var column:=window("КПК  /  ЛИЧНЫЙ АРХИВ V-17")
	label(column,"ЛОКАЛЬНАЯ ПАМЯТЬ   •   ОБЪЕКТ «ЗАРЯ»   •   СВЯЗЬ ОТСУТСТВУЕТ",13)
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",28);column.add_child(row)
	var navigation:=VBoxContainer.new();navigation.custom_minimum_size.x=330;row.add_child(navigation)
	label(navigation,"СОХРАНЁННЫХ ЗАПИСЕЙ: "+str(world.state.data.records.size()),13)
	button(navigation,"ЖУРНАЛ БУНКЕРА",open_journal,320)
	var search:=LineEdit.new();search.name="ArchiveSearch";search.placeholder_text="Поиск по названию и тексту";search.clear_button_enabled=true;search.custom_minimum_size=Vector2(330,48);navigation.add_child(search)
	var reader:=VBoxContainer.new();reader.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(reader)
	var heading:=label(reader,"ТЕКУЩАЯ ЗАДАЧА",24);heading.name="ArchiveHeading"
	var text:=RichTextLabel.new();text.name="ArchiveBody";text.size_flags_vertical=Control.SIZE_EXPAND_FILL;text.custom_minimum_size=Vector2(720,260);text.add_theme_font_size_override("normal_font_size",int(world.state.data.get("reader_font_size",24)));text.text=world.objective();reader.add_child(text)
	reader_tools(reader,text)
	var pin:=button(reader,"ОТМЕТИТЬ МЕСТО НАХОДКИ",func():
		var selected_id:String=world.state.data.get("pda_selected","")
		world.state.data["tracked_record"]="" if world.state.data.get("tracked_record","")==selected_id else selected_id
		minimap.queue_redraw();world.save_state();open_pda(),320)
	pin.name="ArchivePin";pin.disabled=true
	var select_record:=func(id:String):
		world.state.data["pda_selected"]=id
		if id.is_empty():heading.text="ТЕКУЩАЯ ЗАДАЧА";text.text=world.objective();pin.disabled=true
		else:
			var record:Dictionary=world.state.data.records[id]
			heading.text=record.title;text.text=str(record.body).replace("\\n","\n");text.scroll_to_line(0);pin.disabled=not world.stations.any(func(action):return action.id==id)
			pin.text="СНЯТЬ ОТМЕТКУ" if world.state.data.get("tracked_record","")==id else "ОТМЕТИТЬ МЕСТО НАХОДКИ"
			if pin.disabled:pin.text="МЕСТО НАХОДКИ НЕИЗВЕСТНО"
	button(navigation,"ТЕКУЩАЯ ЗАДАЧА",func():select_record.call(""),320)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size=Vector2(330,260);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;navigation.add_child(scroll)
	var entries:=VBoxContainer.new();entries.name="ArchiveEntries";scroll.add_child(entries)
	var rebuild:=func(query:String):
		world.state.data["pda_search"]=query
		for child in entries.get_children():entries.remove_child(child);child.queue_free()
		var matches:=0
		for id in world.state.data.records:
			var record:Dictionary=world.state.data.records[id]
			if not query.strip_edges().is_empty() and not (str(record.title)+" "+str(record.body)).to_lower().contains(query.strip_edges().to_lower()):continue
			var entry:=button(entries,str(record.title),func():select_record.call(id),315);entry.set_meta("record_id",id);matches+=1
		if matches==0:label(entries,"Записей пока нет" if world.state.data.records.is_empty() else "Ничего не найдено",16)
	search.text=str(world.state.data.get("pda_search",""));search.text_changed.connect(rebuild);rebuild.call(search.text)
	var selected_id:String=world.state.data.get("pda_selected","")
	if world.state.data.records.has(selected_id):select_record.call(selected_id)
func open_journal() -> void:
	if not world.state.data.awake or float(world.state.data.health)<=0:return
	var column:=window("ЖУРНАЛ / ОБЪЕКТ «ЗАРЯ»");modal.set_meta("journal",true)
	var step: Dictionary=Journal.next_step(world)
	var heading:=label(column,step.title,25);heading.name="JournalObjective";heading.add_theme_color_override("font_color",Polar.GOLD)
	var detail:=label(column,step.detail,20);detail.name="JournalDetail"
	var scroll:=ScrollContainer.new();scroll.name="JournalScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	var entries:=VBoxContainer.new();entries.name="JournalEntries";entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries.add_theme_constant_override("separation",12);scroll.add_child(entries)
	label(entries,"ВОССТАНОВЛЕНИЕ РЕЗЕРВА",16)
	for milestone in Journal.milestones(world):
		var line:=label(entries,("✓  " if milestone.done else "○  ")+milestone.title,21)
		line.add_theme_color_override("font_color",Polar.ICE if milestone.done else Color("#83979f"))
	var traces: Array=Journal.traces(world);var found:=0
	for clue in traces:
		if clue.done:found+=1
	var count:=label(entries,"СЛЕДЫ СМЕНЫ / %d ИЗ %d" % [found,traces.size()],18);count.name="JournalClueCount"
	for clue in traces:
		var known: bool=clue.done
		if not known and not world.state.data.visited.has(clue.action.room):continue
		var action: Dictionary=clue.action
		var title: String=("✓  "+clue.title if known else "Неосмотренный след")+"\n"+clue.location
		var item:=button(entries,title,func():
			var record: Dictionary=world.state.data.records.get(action.id,{"title":action.title,"body":action.get("observation","")})
			var presentation:Dictionary=record.duplicate(true);presentation["id"]=action.id;presentation["medium"]=evidence_medium(action)
			open_evidence(presentation),600)
		item.name="JournalClue_"+clue.id;item.disabled=not known;item.custom_minimum_size.y=72;item.add_theme_font_size_override("font_size",18)
	button(column,"ОТКРЫТЬ КПК",open_pda,300)
func pause_menu() -> void:
	var column:=window("ПАУЗА / ОБЪЕКТ «ЗАРЯ»")
	modal.set_meta("compact",true); modal.size=Vector2(640,610); modal.position=(canvas_size-modal.size)/2
	label(column,"СИГНАЛ ПРИОСТАНОВЛЕН",13)
	label(column,"Комплекс подождёт. Возвращайтесь, когда будете готовы.",18)
	button(column,"ПРОДОЛЖИТЬ",close_modal,400)
	button(column,"НАСТРОЙКИ",func(): preload("res://scripts/ui/cinematic_pages.gd").open(null,self,"settings"),400)
	if world.custom_layout:button(column,"ГРАФИКА БУНКЕРА",open_bunker_graphics,400)
	button(column,"СОХРАНИТЬ",func(): world.save_state(); notify("СОХРАНЕНО"),400)
	button(column,"В ГЛАВНОЕ МЕНЮ",func():
		var mains=get_tree().get_nodes_in_group("main_root")
		if not mains.is_empty(): mains[0].to_main_menu(),400)
func bunker_complete()->void:
	var column=window("ВЫХОДНОЙ ШЛЮЗ / БУНКЕР ПРОЙДЕН")
	modal.name="BunkerComplete";modal.set_meta("compact",true);modal.set_meta("preferred_size",Vector2(780,620));modal.size=Vector2(780,620);modal.position=(canvas_size-modal.size)/2
	label(column,"РЕЗЕРВ K-2 — ВКЛЮЧЁН\nДАВЛЕНИЕ — СТАБИЛЬНО\nВЫХОДНОЙ ЦИКЛ — ПОДТВЕРЖДЁН",24)
	label(column,"Вы добрались до выхода. Прогресс бункера сохранён. Поверхность будет следующей локацией; сейчас можно вернуться и собрать оставшиеся следы смены.",22)
	button(column,"ПРОДОЛЖИТЬ ИССЛЕДОВАНИЕ БУНКЕРА",close_modal,600)
	button(column,"СОХРАНИТЬ И ВЕРНУТЬСЯ В МЕНЮ",func():
		world.save_state();var mains=get_tree().get_nodes_in_group("main_root")
		if not mains.is_empty():mains[0].to_main_menu(),600)
func open_bunker_graphics() -> void:
	var column:=window("ГРАФИКА / БУНКЕР")
	modal.set_meta("compact",true);modal.set_meta("preferred_size",Vector2(680,620));modal.size=Vector2(680,620);modal.position=(canvas_size-modal.size)/2
	label(column,"Меняется только качество 3D. Размер интерфейса сохраняется.",21)
	var names={"low":"ЭКОНОМНЫЙ — БЕЗ ДИНАМИЧЕСКИХ ТЕНЕЙ","balanced":"СБАЛАНСИРОВАННЫЙ — ОДНА ТЕНЬ","quality":"КАЧЕСТВО — ДВЕ ТЕНИ"}
	for id in ["low","balanced","quality"]:
		var profile_id: String=id
		button(column,("✓ " if world.visibility_controller.profile==id else "")+names[id],func():
			world.visibility_controller.set_profile(profile_id);world.save_state();open_bunker_graphics(),530)
	label(column,"Начните со сбалансированного. Если движение остаётся медленным, выберите экономный.",20)
	button(column,"НАЗАД",pause_menu,400)
func prologue() -> void:
	var column:=window("СЕВЕРНЫЙ АНКЛАВ / АЛЕКСЕЙ ВОЛКОВ")
	modal.set_meta("prologue",true);modal.find_child("WindowClose",true,false).hide()
	label(column,"Последнее, что вы помните, — холод.\n\nТеперь кто-то называет вас пациентом V-17. За стеклом работает незнакомое оборудование. Голос системы произносит вашу фамилию.\n\nВы — Алексей Волков. Вы не знаете, сколько времени прошло.",24)
	button(column,"ОТКРЫТЬ ГЛАЗА",world.player.request_wake,400)
func _unhandled_input(event: InputEvent) -> void:
	if not world.state.data.awake and world.player.locked:return
	if float(world.state.data.health)<=0:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_TAB: open_inventory()
		if event.keycode==KEY_M: open_pda()
		if event.keycode==KEY_ESCAPE:Back.request(get_tree());get_viewport().set_input_as_handled()
func handle_back() -> void:
	if not world.startup_ready:world.return_to_menu();return
	if world.is_queued_for_deletion() or not world.state.data.awake or float(world.state.data.health)<=0:return
	if not world.repair_action.is_empty():world.cancel_repair();return
	if modal!=null:close_modal()
	else:pause_menu()
func _exit_tree() -> void:
	Back.remove(self)
func startup_failure() -> void:
	if is_instance_valid(modal) and modal.get_meta("startup_failure",false):return
	var column=window("БУНКЕР НЕ ЗАГРУЗИЛСЯ")
	modal.name="StartupFailure";modal.set_meta("startup_failure",true)
	modal.find_child("WindowClose",true,false).hide()
	label(column,"Не удалось подготовить локацию. Прогресс не перезаписан.\n\n"+world.startup_error,24)
	label(column,"A-03.3 / "+world.startup_stage,16)
	var retry=button(column,"ПОВТОРИТЬ ЗАГРУЗКУ",world.retry_startup,460);retry.name="RetryStartup"
	var menu=button(column,"ГЛАВНОЕ МЕНЮ",world.return_to_menu,460);menu.name="StartupMenu"
	root.get_node("CapsuleWake").hide()

func restart_level() -> void:
	var game=get_node("/root/G")
	game.zsave.erase(world.state_key)
	game.zsave["iso_layer"]="bunker"
	var mains=get_tree().get_nodes_in_group("main_root")
	if not mains.is_empty(): mains[0]._enter_iso_world()
	else: get_tree().reload_current_scene()

func interaction_text(target: Dictionary) -> String:
	if target.is_empty(): return ""
	var title: String=target.get("title","ВЗАИМОДЕЙСТВОВАТЬ")
	if target.kind=="evidence":return ("В КПК / " if world.state.data.records.has(target.id) else "ПРОЧИТАТЬ / ")+title
	if target.kind=="inspect":return ("ОСМОТРЕНО / " if world.state.data.get("investigation_seen",{}).get(target.id,false) else "ОСМОТРЕТЬ / ")+title
	if target.kind=="loot":return ("ПУСТО / " if world.state.data.containers.get(target.id,[]).is_empty() else "ОБЫСКАТЬ / ")+title
	if target.kind=="repair" and world.state.flag(target.id):return "ГОТОВО / "+title
	return title
func _update_interaction() -> void:
	if modal!=null:return
	var target: Dictionary=world.nearest()
	var action_button: Button=root.get_node("Interact")
	if not bool(world.state.data.awake):
		action_button.disabled=false;action_button.icon=interaction_icons.hand;action_button.modulate=Color("#ffe1a9")
		action_button.tooltip_text="Встать из капсулы";interaction_hint.text="ОТКРЫВАЕТСЯ КАПСУЛА / КОСНИТЕСЬ, ЧТОБЫ ВСТАТЬ" if world.player.waking else "ОТКРЫТЬ КАПСУЛУ"
		return
	action_button.disabled=target.is_empty() or world.player.locked
	var icon_id: String={"door":"door","terminal":"terminal","record":"terminal","evidence":"search","loot":"search","locked":"search","container":"search"}.get(str(target.get("kind","")),"hand")
	action_button.icon=interaction_icons[icon_id]
	action_button.modulate=Color.WHITE if action_button.disabled else Color("#ffe1a9")
	interaction_hint.text=interaction_text(target)
	interaction_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	interaction_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	interaction_hint.max_lines_visible=2
	action_button.tooltip_text="Нет объекта рядом" if target.is_empty() else interaction_text(target)

func _update_world_marker() -> void:
	if not is_instance_valid(interaction_marker): return
	interaction_marker.hide()
	if modal!=null or world.player.locked: return
	var target: Dictionary=world.nearest()
	if target.is_empty(): return
	var camera: Camera3D=world.get_node("Camera")
	var point: Vector3=target.node.global_position
	point.y=maxf(world.ORIGIN.y+1.15,point.y+.25)
	if camera.is_position_behind(point): return
	var screen: Vector2=camera.unproject_position(point)
	if not get_viewport().get_visible_rect().has_point(screen): return
	interaction_marker.position=(screen-root.position)/root.scale-Vector2(23,46)
	var icon_id: String={"door":"door","terminal":"terminal","record":"terminal","loot":"search","locked":"search"}.get(str(target.get("kind","")),"hand")
	interaction_marker_icon.texture=interaction_icons[icon_id]
	interaction_marker.modulate=Color("#89cdd9") if target.kind=="evidence" and world.state.data.records.has(target.id) else Color.WHITE
	interaction_marker.show()
