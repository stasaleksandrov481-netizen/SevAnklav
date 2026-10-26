extends CanvasLayer
const State=preload("res://iso/zarya/state.gd")
const Icons=preload("res://scripts/ui/equipment_icons.gd")
var world
var root: Control
var objective: Label
var notice: Label
var bars := {}
var slots: Array = []
var modal: Control
var selected := ""
var selected_zone := "Торс"
var minimap
var weapon_status: Label
var dead_shown := false
var timer := 0.0
var refresh_clock := 0.0
func style() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(0.025,0.045,0.06,0.94)
	s.border_color=Color("#536b78")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(12)
	return s
func label(parent: Node, text: String, size := 18) -> Label:
	var result:=Label.new(); result.text=text
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("#bdcbd0"))
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result
func button(parent: Node, text: String, callback: Callable, width := 110) -> Button:
	var b:=Button.new(); b.text=text
	b.custom_minimum_size=Vector2(width,52)
	b.add_theme_stylebox_override("normal",style())
	b.add_theme_stylebox_override("hover",style())
	b.add_theme_stylebox_override("pressed",style())
	b.add_theme_color_override("font_color",Color("#b8d1dc"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
func panel(parent: Node, at: Vector2, dimensions: Vector2) -> PanelContainer:
	var p:=PanelContainer.new(); p.position=at; p.custom_minimum_size=dimensions
	p.add_theme_stylebox_override("panel",style()); parent.add_child(p)
	return p
func _ready() -> void:
	world=get_parent(); world.hud=self
	root=Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	var top:=HBoxContainer.new(); top.position=Vector2(20,18); top.add_theme_constant_override("separation",10); root.add_child(top)
	var task:=panel(top,Vector2.ZERO,Vector2(330,100)); var column:=VBoxContainer.new(); task.add_child(column)
	label(column,"ЗАДАЧИ / ЗАРЯ −2",14); objective=label(column,"",18)
	var statuses:=panel(top,Vector2.ZERO,Vector2(285,100)); var stack:=VBoxContainer.new(); statuses.add_child(stack)
	for entry in [["health","ЗДОРОВЬЕ",Color("#74be91")],["food","ПИТАНИЕ",Color("#d3b267")],["water","ВОДА",Color("#70a8c8")]]:
		var row:=HBoxContainer.new(); stack.add_child(row)
		var title:=label(row,entry[1],13); title.custom_minimum_size.x=100
		var bar:=ProgressBar.new(); bar.custom_minimum_size=Vector2(145,16); bar.show_percentage=false
		var fill:=StyleBoxFlat.new(); fill.bg_color=entry[2]; bar.add_theme_stylebox_override("fill",fill)
		row.add_child(bar); bars[entry[0]]=bar
	button(top,"РЮКЗАК",open_inventory)
	button(top,"КПК",open_pda,85)
	button(top,"ПАУЗА",pause_menu,85)
	button(top,"СВЕТ",func(): world.state.data["flash_on"]=not world.state.data.get("flash_on",false),70)
	button(top,"+",func(): world.get_node("Camera").desired_size=maxf(10,world.get_node("Camera").desired_size-1),52)
	button(top,"−",func(): world.get_node("Camera").desired_size=minf(24,world.get_node("Camera").desired_size+1),52)
	minimap=preload("res://iso/zarya/minimap.gd").new(); minimap.world=world
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT); minimap.offset_left=-275; minimap.offset_right=-20; minimap.offset_top=18; minimap.offset_bottom=153; root.add_child(minimap)
	var bottom:=HBoxContainer.new(); bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left=-425; bottom.offset_right=425; bottom.offset_top=-125; bottom.offset_bottom=-18
	bottom.add_theme_constant_override("separation",5); root.add_child(bottom)
	for entry in [["left","ЛЕВАЯ РУКА"],["right","ПРАВАЯ РУКА"],["quick0","ЛЕЧЕНИЕ"],["quick1","БЫСТРЫЙ"],["quick2","БЫСТРЫЙ"],["quick3","УТИЛИТЫ"]]:
		var col:=VBoxContainer.new(); bottom.add_child(col)
		label(col,entry[1],12)
		make_slot(col,entry[0])
	var actions:=VBoxContainer.new(); bottom.add_child(actions)
	button(actions,"ПРОВЕРИТЬ",world.player.check_ammo,120)
	button(actions,"ПЕРЕЗАРЯДИТЬ",world.player.reload,120)
	for side in [0,1]:
		var stick:=preload("res://iso/touch_pad.gd").new()
		stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if side==0 else Control.PRESET_BOTTOM_RIGHT)
		stick.offset_left=25 if side==0 else -255
		stick.offset_right=255 if side==0 else -25
		stick.offset_top=-360; stick.offset_bottom=-130
		stick.set_meta("side",side); root.add_child(stick)
		stick.name="MoveStick" if side==0 else "AimStick"
	var interact:=button(root,"ВЗАИМОДЕЙСТВИЕ",func(): world.interact(),170)
	interact.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); interact.offset_left=-455; interact.offset_right=-265; interact.offset_top=-210; interact.offset_bottom=-150
	notice=label(root,"",18); notice.position=Vector2(400,155); notice.custom_minimum_size=Vector2(740,70)
	weapon_status=label(root,"",16)
	weapon_status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_status.offset_left=-400; weapon_status.offset_right=-20; weapon_status.offset_top=-110; weapon_status.offset_bottom=-40
	var silhouette=preload("res://iso/zarya/body.gd").new()
	silhouette.ui=self
	silhouette.position=Vector2(12,get_viewport().get_visible_rect().size.y-110)
	silhouette.scale=Vector2(0.22,0.22)
	silhouette.size=Vector2(340,410)
	silhouette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(silhouette)
	var med_button=button(root,"+",open_medical,50)
	med_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	med_button.offset_left=90; med_button.offset_right=142; med_button.offset_top=-85; med_button.offset_bottom=-30
	world.state.changed.connect(func(): silhouette.queue_redraw())
	world.state.changed.connect(refresh_slots)
	refresh_slots()
func icon_for(id: String) -> Texture2D:
	var texture:=Icons.get_icon(id)
	if texture!=null: return texture
	var path: String="res://assets/icons/"+str(State.ITEMS.get(id,{}).get("icon","gear"))+".svg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
func make_slot(parent: Node, key: String) -> Button:
	var cell:=preload("res://iso/zarya/slot.gd").new()
	cell.ui=self; cell.key=key; cell.custom_minimum_size=Vector2(90,78)
	cell.add_theme_stylebox_override("normal",style()); cell.expand_icon=true
	cell.add_theme_constant_override("icon_max_width",52)
	cell.pressed.connect(func(): selected=key; notify("ВЫБРАНО: "+str(world.state.data.slots.get(key,{}).get("id","ПУСТО"))))
	parent.add_child(cell); slots.append(cell)
	return cell
func refresh_slots() -> void:
	var kept: Array=[]
	for cell in slots:
		if not is_instance_valid(cell): continue
		kept.append(cell)
		var item: Dictionary=world.state.data.slots.get(cell.key,{})
		cell.icon=icon_for(item.get("id","")) if not item.is_empty() else null
		cell.text=str(item.get("count","+"))
		cell.tooltip_text=State.ITEMS.get(item.get("id",""),{}).get("name","Пусто")
	slots=kept
func _process(delta: float) -> void:
	if modal==null:
		world.player.move_vector=root.get_node("MoveStick").get_move_vector()
		world.player.aim_vector=root.get_node("AimStick").get_move_vector()
		world.player.fire=world.player.aim_vector.length()>0.8
	else:
		world.player.move_vector=Vector2.ZERO; world.player.aim_vector=Vector2.ZERO; world.player.fire=false
	refresh_clock+=delta
	if refresh_clock>0.15:
		refresh_clock=0
		objective.text=world.objective()
		for key in bars: bars[key].value=world.state.data[key]
		minimap.queue_redraw()
		var description: String="?"
		if world.state.data.checked: description="почти полный" if world.state.data.mag>=6 else ("меньше половины" if world.state.data.mag>0 else "пуст")
		weapon_status.text=("ОРУЖИЕ НЕ В РУКАХ" if world.state.weapon().is_empty() else "ПМ / МАГАЗИН: "+description)+"\nЗАПАС: "+str(world.state.amount("ammo"))+" × 9×18"
		if float(world.state.data.health)<=0 and not dead_shown:
			dead_shown=true
			var column:=window("V-17 / ЖИЗНЕННЫЕ ПОКАЗАТЕЛИ УТРАЧЕНЫ")
			button(column,"НАЧАТЬ УРОВЕНЬ ЗАНОВО",restart_level,400)
	if timer>0:
		timer-=delta; notice.modulate.a=minf(1,timer)
func notify(text: String) -> void:
	if text.is_empty(): return
	notice.text=text; timer=7; notice.modulate.a=1
func close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal=null; world.paused=false
	world.player.move_vector=Vector2.ZERO; world.player.aim_vector=Vector2.ZERO; world.player.fire=false
	world.save_state()
func window(title: String) -> VBoxContainer:
	close_modal()
	modal=PanelContainer.new(); modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.offset_left=-570; modal.offset_right=570; modal.offset_top=-310; modal.offset_bottom=310
	modal.add_theme_stylebox_override("panel",style()); root.add_child(modal)
	world.paused=true
	var column:=VBoxContainer.new(); modal.add_child(column)
	var header:=HBoxContainer.new(); column.add_child(header)
	var text:=label(header,title,22); text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(header,"ЗАКРЫТЬ",close_modal)
	modal.modulate.a=0; create_tween().tween_property(modal,"modulate:a",1.0,0.18)
	return column
func bag(parent: Node) -> void:
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(520,350); parent.add_child(scroll)
	var grid:=GridContainer.new(); grid.columns=5; scroll.add_child(grid)
	for key in ["left","right","clothes","pocket0","pocket1","quick0","quick1","quick2","quick3"]: make_slot(grid,key)
	for i in range(18): make_slot(grid,"bag"+str(i))
	refresh_slots()
func open_inventory() -> void:
	var column:=window("ВОЛКОВ / СНАРЯЖЕНИЕ")
	var row:=HBoxContainer.new(); column.add_child(row); bag(row)
	var side:=VBoxContainer.new(); side.custom_minimum_size.x=390; row.add_child(side)
	label(side,"Выберите предмет. Перетащите в слот или используйте действия ниже.",18)
	button(side,"В ЛЕВУЮ / ПРАВУЮ РУКУ",func(): world.state.equip(selected); refresh_slots(),240)
	button(side,"ПЕРЕМЕСТИТЬ В КАРМАН",func(): world.state.move_slot(selected,"pocket0"); refresh_slots(),240)
	button(side,"ЛЕЧЕНИЕ",open_medical,240)
	button(side,"ИСПОЛЬЗОВАТЬ ПАЁК / ВОДУ",consume,240)
	button(side,"ВЫБРОСИТЬ",drop_selected,240)
func consume() -> void:
	var entry: Dictionary=world.state.data.slots.get(selected,{})
	if entry.is_empty(): return
	if entry.id in ["food","water"]:
		world.state.take(entry.id)
		world.state.data[entry.id]=minf(100,float(world.state.data[entry.id])+30)
		refresh_slots()
func drop_selected() -> void:
	var entry: Dictionary=world.state.data.slots.get(selected,{})
	if entry.is_empty(): return
	var id: String="drop"+str(world.state.data.drops.size())
	world.state.data.drops.append({"id":id,"item":entry.duplicate(),"position":[world.player.position.x,world.player.position.y,world.player.position.z]})
	world.state.data.slots.erase(selected)
	world.create_drop(world.state.data.drops.back())
	refresh_slots()
func open_loot(action: Dictionary) -> void:
	var column:=window("ОБЫСК / "+str(action.title))
	var row:=HBoxContainer.new(); column.add_child(row)
	var left:=VBoxContainer.new(); row.add_child(left); label(left,"ИНВЕНТАРЬ ВОЛКОВА",18); bag(left)
	var right:=VBoxContainer.new(); right.custom_minimum_size.x=420; row.add_child(right)
	label(right,action.title,18)
	var list: Array=world.state.data.containers.get(action.id,[])
	if list.is_empty(): label(right,"ПУСТО / ПРЕДМЕТЫ УЖЕ ЗАБРАНЫ",16)
	for i in range(list.size()):
		var item: Dictionary=list[i]
		var b:=button(right,State.ITEMS[item.id].name+" × "+str(item.count)+" / 100%",func(): transfer(action,i),380)
		b.icon=icon_for(item.id); b.expand_icon=true; b.add_theme_constant_override("icon_max_width",36)
	button(right,"ВЗЯТЬ ВСЁ",func():
		while not world.state.data.containers[action.id].is_empty():
			if not world.state.loot(action.id,0): break
		loot_flags(); open_loot(action),380)
func transfer(action: Dictionary, index: int) -> void:
	world.state.loot(action.id,index)
	loot_flags()
	open_loot(action)
func loot_flags() -> void:
	if world.state.amount("pistol")>0:
		world.state.mark("armed")
		world.player.rig.perform("pickup")
	if world.state.amount("card")>0: world.state.mark("card")
	world.save_state()
func open_terminal(action: Dictionary) -> void:
	var column:=window("ЗАРЯ / ЛОКАЛЬНЫЙ УЗЕЛ / "+str(action.title))
	label(column,"ОПЕРАТОР V-17   •   УРОВЕНЬ −2   •   СЕТЬ ИЗОЛИРОВАНА",14)
	var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://iso/bunker_records.json"))
	var record: Dictionary=records.get(action.record,{"title":"СЛУЖЕБНАЯ ЗАПИСЬ / СЕРОВ","body":"Резервный предохранитель оставлен в серверной. Карту заберите с моего рабочего места. После восстановления питания проверьте карантинную блокировку. Верхний уровень не отвечает."})
	record=record.duplicate(true)
	if action.id in ["power","generator","pump"]:
		record.body="Предохранитель установлен. Резервная цепь научно-технического уровня −2 готова к работе.\nПроверьте карантинную блокировку перед доступом к вертикальному узлу."
	if action.id=="archive": record.body=str(record.body)+"\n\nСИСТЕМА: грузовой шлюз требует подтверждения с верхнего уровня. Следуйте к лестничному узлу −1."
	label(column,record.title,22)
	var text:=RichTextLabel.new(); text.custom_minimum_size=Vector2(1050,350); text.text=str(record.body).replace("\\n","\n"); column.add_child(text)
	button(column,"ЗАГРУЗИТЬ ЗАПИСЬ / ВЫПОЛНИТЬ ДЕЙСТВИЕ",func():
		if world.activate(action.id):
			world.state.data.records[action.id]=record
			notify("ДАННЫЕ СОХРАНЕНЫ В КПК")
			world.save_state(),480)
func open_medical() -> void:
	var column:=window("МЕДИЦИНСКИЙ МОНИТОРИНГ / V-17")
	var row:=HBoxContainer.new(); column.add_child(row)
	var body:=preload("res://iso/zarya/body.gd").new(); body.ui=self; body.custom_minimum_size=Vector2(340,410); row.add_child(body)
	var side:=VBoxContainer.new(); side.custom_minimum_size.x=650; row.add_child(side)
	label(side,"Выберите область на схеме",18)
	for zone in State.ZONES:
		var wound: Dictionary=world.state.data.wounds[zone]
		button(side,zone+" / повреждение %d · кровотечение %.2f" % [int(wound.damage),float(wound.bleeding)],func(): selected_zone=zone; notify("ВЫБРАНО: "+zone),550)
	var actions:=HBoxContainer.new(); column.add_child(actions)
	for entry in [["band","ПЕРЕВЯЗАТЬ"],["medkit","ОБРАБОТАТЬ"],["morph","ОБЕЗБОЛИТЬ"]]:
		button(actions,entry[1],func():
			if world.state.treat(selected_zone,entry[0]): world.player.rig.perform("treat"); open_medical()
			else: notify("НЕТ ПРЕПАРАТА ИЛИ ПОКАЗАНИЙ К ПРИМЕНЕНИЮ"),220)
func open_pda() -> void:
	var column:=window("КПК / АРХИВ ПРОЕКТА")
	var text:=RichTextLabel.new(); text.custom_minimum_size=Vector2(1050,470)
	for record in world.state.data.records.values(): text.text+=str(record.title)+"\n"+str(record.body).replace("\\n","\n")+"\n\n"
	if text.text.is_empty(): text.text="Нет загруженных записей."
	column.add_child(text)
func pause_menu() -> void:
	var column:=window("ПАУЗА / ОБЪЕКТ «ЗАРЯ»")
	button(column,"ПРОДОЛЖИТЬ",close_modal,400)
	button(column,"СОХРАНИТЬ",func(): world.save_state(); notify("СОХРАНЕНО"),400)
	button(column,"В ГЛАВНОЕ МЕНЮ",func():
		var mains=get_tree().get_nodes_in_group("main_root")
		if not mains.is_empty(): mains[0].to_main_menu(),400)
func prologue() -> void:
	var column:=window("СЕВЕРНЫЙ АНКЛАВ / АЛЕКСЕЙ ВОЛКОВ")
	label(column,"Последнее, что вы помните, — холод.\n\nТеперь кто-то называет вас пациентом V-17. За стеклом работает незнакомое оборудование. Голос системы произносит вашу фамилию.\n\nВы — Алексей Волков. Вы не знаете, сколько времени прошло.",24)
	button(column,"ОТКРЫТЬ ГЛАЗА",func(): close_modal(); world.player.awaken(),400)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_TAB: open_inventory()
		if event.keycode==KEY_M: open_pda()
		if event.keycode==KEY_ESCAPE: close_modal() if modal!=null else pause_menu()

func restart_level() -> void:
	var game=get_node("/root/G")
	game.zsave.erase("zarya2")
	game.zsave["iso_layer"]="bunker"
	var mains=get_tree().get_nodes_in_group("main_root")
	if not mains.is_empty(): mains[0]._enter_iso_world()
	else: get_tree().reload_current_scene()
