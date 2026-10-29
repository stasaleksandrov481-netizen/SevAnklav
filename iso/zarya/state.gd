extends RefCounted
signal changed
const ITEMS := {
 "uniform":{"name":"Форма сотрудника","icon":"shield"},
 "pistol":{"name":"ПМ / 9×18","icon":"pistol","hands":1},"rifle":{"name":"Карабин","icon":"rifle","hands":2},
 "flashlight":{"name":"Фонарь","icon":"flashlight","hands":1},"band":{"name":"Бинт","icon":"bandage"},"medkit":{"name":"Аптечка","icon":"medkit"},
 "morph":{"name":"Обезболивающее","icon":"medkit"},"food":{"name":"Паёк","icon":"food"},"water":{"name":"Вода","icon":"drop"},
 "ammo":{"name":"9×18 мм","icon":"ammo"},"card":{"name":"Карта инженера","icon":"keycard"},"fuse":{"name":"Предохранитель","icon":"gear"},"tool":{"name":"Инструменты","icon":"gear"}}
const ZONES := ["Голова","Торс","Левая рука","Правая рука","Левая нога","Правая нога"]
var data: Dictionary
func _init(save: Dictionary = {}, save_key := "zarya2") -> void:
	if not save.has(save_key):
		save[save_key] = {"version":1,"awake":false,"flags":{},"visited":{},"doors":{},"containers":{},"enemies":{},"records":{},"slots":{},"health":100.0,"food":100.0,"water":100.0,"wounds":{},"mag":0,"chamber":0,"checked":false,"position":[-24.0,0.95,-10.0],"drops":[]}
	data = save[save_key]
	for zone in ZONES:
		if not data.wounds.has(zone): data.wounds[zone] = {"damage":0.0,"bleeding":0.0,"pain":0.0}
func flag(id: String) -> bool: return bool(data.flags.get(id,false))
func mark(id: String) -> void:
	data.flags[id] = true
	changed.emit()
func item(id: String, count := 1) -> Dictionary: return {"id":id,"count":count,"condition":100}
func amount(id: String) -> int:
	var result := 0
	for entry in data.slots.values():
		if entry.get("id","") == id: result += int(entry.count)
	return result
func give(id: String, count := 1) -> bool:
	return receive(item(id,count))
func receive(entry: Dictionary) -> bool:
	# Preserve condition and item-specific fields when taking an object back.
	var id: String=entry.get("id","")
	if not ITEMS.has(id) or int(entry.get("count",0))<=0: return false
	var incoming: Dictionary=entry.duplicate(true)
	if not incoming.has("condition"): incoming.condition=100
	var properties: Dictionary=incoming.duplicate(true); properties.erase("count")
	for key in data.slots:
		var existing: Dictionary=data.slots[key].duplicate(true); existing.erase("count")
		if not existing.has("condition"): existing.condition=100
		if existing == properties and not ITEMS[id].has("hands"):
			data.slots[key].count += int(incoming.count)
			changed.emit()
			return true
	for i in range(18):
		var key := "bag"+str(i)
		if not data.slots.has(key):
			data.slots[key] = incoming
			changed.emit()
			return true
	return false
func take(id: String, count := 1) -> bool:
	if amount(id)<count: return false
	for key in data.slots.keys():
		if data.slots[key].id != id: continue
		var n := mini(count,int(data.slots[key].count))
		data.slots[key].count -= n
		count -= n
		if data.slots[key].count <= 0: data.slots.erase(key)
		if count == 0: break
	changed.emit()
	return true
func valid_slot(key: String) -> bool:
	if key in ["left","right","clothes","pocket0","pocket1"]:return true
	for prefix in ["bag","quick"]:
		for i in (18 if prefix=="bag" else 4):
			if key==prefix+str(i):return true
	return false
func accepts_slot(key: String, entry: Dictionary) -> bool:
	if not valid_slot(key) or not ITEMS.has(entry.get("id","")) or int(entry.get("count",0))<=0:return false
	if key=="clothes":return entry.id=="uniform" and int(entry.count)==1
	if key in ["left","right"]:return ITEMS[entry.id].has("hands") and int(entry.count)==1
	return true
func stack_matches(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or ITEMS.get(a.get("id",""),{}).has("hands"):return false
	var left: Dictionary=a.duplicate(true);var right: Dictionary=b.duplicate(true)
	left.erase("count");right.erase("count")
	if not left.has("condition"):left.condition=100
	if not right.has("condition"):right.condition=100
	return left==right
func can_move_slot(source: String, target: String) -> bool:
	if source == target or not valid_slot(source) or not data.slots.has(source): return false
	if not accepts_slot(target,data.slots[source]):return false
	if data.slots.has(target) and not accepts_slot(source,data.slots[target]):return false
	var after: Dictionary=data.slots.duplicate()
	var incoming: Dictionary=after[source]
	after.erase(source)
	if after.has(target):after[source]=after[target]
	after[target]=incoming
	for hand in ["left","right"]:
		if not after.has(hand):continue
		var definition:Dictionary=ITEMS.get(after[hand].id,{})
		if not definition.has("hands"):return false
		var other: String="right" if hand=="left" else "left"
		if int(definition.hands)==2 and after.has(other):return false
	return true
func move_slot(source: String, target: String) -> bool:
	if not can_move_slot(source,target):return false
	var entry: Dictionary = data.slots[source]
	var previous: Dictionary = data.slots.get(target,{})
	if target!="clothes" and stack_matches(entry,previous):
		previous.count=int(previous.count)+int(entry.count)
		data.slots.erase(source);changed.emit();return true
	data.slots[target] = entry
	data.slots.erase(source)
	if not previous.is_empty(): data.slots[source] = previous
	changed.emit()
	return true
func equip(source: String) -> bool:
	var target:=equip_target(source)
	return not target.is_empty() and move_slot(source,target)
func equip_target(source: String) -> String:
	if not data.slots.has(source):return ""
	if data.slots[source].get("id","")=="uniform":return "clothes" if can_move_slot(source,"clothes") else ""
	for hand in ["left","right"]:
		if not data.slots.has(hand) and can_move_slot(source,hand):return hand
	return ""
func split_slot(source: String) -> String:
	var entry: Dictionary=data.slots.get(source,{})
	if int(entry.get("count",0))<2:return ""
	for i in 18:
		var target: String="bag"+str(i)
		if data.slots.has(target):continue
		var unit: Dictionary=entry.duplicate(true);unit.count=1
		entry.count=int(entry.count)-1;data.slots[target]=unit;changed.emit();return target
	return ""
func weapon() -> String:
	for hand in ["right","left"]:
		var id: String = data.slots.get(hand,{}).get("id","")
		if id in ["pistol","rifle"]: return id
	return ""
func loot(id: String, index: int) -> bool:
	var list: Array = data.containers.get(id,[])
	if index < 0 or index >= list.size(): return false
	if not receive(list[index]): return false
	list.remove_at(index)
	changed.emit()
	return true
func loot_all(id: String) -> int:
	# A full bag may still accept later entries into existing stacks.
	var list: Array=data.containers.get(id,[])
	var index:=0
	var transferred:=0
	while index<list.size():
		if loot(id,index): transferred+=1
		else: index+=1
	return transferred
func can_consume_slot(key: String) -> bool:
	var entry: Dictionary=data.slots.get(key,{})
	var id: String=entry.get("id","")
	return id in ["food","water"] and int(entry.get("count",0))>0 and float(data.get(id,100.0))<99.5
func consume_slot(key: String) -> bool:
	if not can_consume_slot(key):return false
	var entry: Dictionary=data.slots[key]
	var id: String=entry.id
	entry.count=int(entry.count)-1
	if entry.count<=0:data.slots.erase(key)
	data[id]=clampf(float(data.get(id,100.0))+30.0,0,100)
	changed.emit()
	return true
func needs_treatment(zone: String, medicine: String) -> bool:
	if not data.wounds.has(zone) or float(data.health)<=0:return false
	var field: String={"band":"bleeding","medkit":"damage","morph":"pain"}.get(medicine,"")
	return not field.is_empty() and float(data.wounds[zone].get(field,0))>0
func can_treat(zone: String, medicine: String) -> bool:
	return needs_treatment(zone,medicine) and amount(medicine)>0
func treat(zone: String, medicine: String) -> bool:
	if not can_treat(zone,medicine): return false
	var wound: Dictionary = data.wounds[zone]
	if not take(medicine): return false
	match medicine:
		"band": wound.bleeding = maxf(0,float(wound.bleeding)-0.7)
		"medkit":
			wound.damage = maxf(0,float(wound.damage)-22)
			data.health = minf(100,float(data.health)+15)
		"morph": wound.pain = maxf(0,float(wound.pain)-30)
	changed.emit()
	return true
func hit(zone: String, damage: float) -> void:
	data.wounds[zone].damage += damage
	data.wounds[zone].bleeding += 0.12
	data.wounds[zone].pain += damage
	data.health = maxf(0,float(data.health)-damage)
	changed.emit()
