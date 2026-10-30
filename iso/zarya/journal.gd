extends RefCounted
# Derived from the real world/save state: no separate quest flags or reset of old saves.
static func found(world, action: Dictionary) -> bool:
	return world.state.data.records.has(action.id) or bool(world.state.data.get("investigation_seen",{}).get(action.id,false))
static func location(world, action: Dictionary) -> String:
	return str(world.room_info(action.get("room","")).get("title","Бункер / уровень −2"))
static func traces(world) -> Array:
	var result: Array=[]
	for action in world.stations:
		if action.kind not in ["evidence","inspect"]:continue
		result.append({"id":action.id,"title":action.title,"location":location(world,action),"done":found(world,action),"action":action})
	return result
static func next_step(world) -> Dictionary:
	var state=world.state
	if not state.data.awake:return {"id":"wake","title":"Открыть глаза в капсуле V-17","detail":"Выберите «Открыть глаза» во вступлении."}
	if not state.flag("relay_k2"):
		if state.amount("fuse")>0:return {"id":"relay_k2","title":"Заменить вставку K-2 / 19","detail":"Предохранитель уже при вас, оружие не открывает шлюз. Из мастерской / 22 идите через насосную / 21 и генераторную / 20 в электрощитовую / 19. У распределительного блока удерживайте кнопку действия до конца."}
		for drop in state.data.drops:
			for entry in state.data.containers.get(drop.id,[]):
				if entry.get("id","")=="fuse" and int(entry.get("count",0))>0:
					return {"id":drop.id,"title":"Подобрать выложенный предохранитель","detail":"Вставка осталась в предмете на полу. Верните её в снаряжение; искать новую в пустом ящике не нужно."}
		if not state.data.records.has("identity_v17"):return {"id":"identity_v17","title":"Осмотреть медблок / 12","detail":"Проверьте диагностическое рабочее место рядом с капсулой: там сохранились сведения о пациенте V-17."}
		return {"id":"serov_tools","title":"Найти припасы в мастерской / 22","detail":"Ящик Серова стоит на верстаке у северной стены мастерской / 22. Заберите плавкую вставку K-2. Именно она продолжает путь к выходу; оружие пригодится для защиты."}
	if not state.flag("pump_valve"):return {"id":"pump_valve","title":"Открыть резервный клапан / 21","detail":"Контур K-2 восстановлен. Подойдите к резервному вентилю в насосной и завершите действие."}
	if not state.flag("bunker_complete"):return {"id":"exit","title":"Добраться до грузового шлюза / 27","detail":"Питание и давление восстановлены. Из насосной / 21 пройдите мастерскую / 22 и восточный коридор к грузовому шлюзу / 27. На внешней двери запустите выходной цикл. Дополнительные записки можно собрать позже."}
	var clues:=traces(world)
	for id in ["archive_chat","lab_observation","quarantine_note","guard_log","shift","identity_v17","technician","transfer","gromov","pump_note","volkov_tag","broken_receiver","abandoned_cart"]:
		for clue in clues:
			if clue.id==id and not clue.done:return {"id":id,"title":"Исследовать: "+clue.location,"detail":"Резерв стабилизирован. Осмотрите оставленные документы и предметы в этом помещении. Найденные записи доступны в КПК."}
	return {"id":"complete","title":"Бункер пройден","detail":"Вы дошли до грузового шлюза и восстановили аварийный выход. Найденные записи сохранены в КПК. Поверхность станет следующей локацией."}
static func milestones(world) -> Array:
	var s=world.state
	return [
		{"title":"Пробуждение V-17","done":bool(s.data.awake)},
		{"title":"Сведения о пациенте","done":s.data.records.has("identity_v17")},
		{"title":"Резервная вставка найдена","done":s.amount("fuse")>0 or s.flag("relay_k2")},
		{"title":"Контур K-2 восстановлен","done":s.flag("relay_k2")},
		{"title":"Давление стабилизировано","done":s.flag("pump_valve")},
		{"title":"Выходной шлюз достигнут","done":s.flag("bunker_complete")}
	]
