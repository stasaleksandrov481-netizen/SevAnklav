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
func _init(save: Dictionary = {}) -> void:
	if not save.has("zarya2"):
		save["zarya2"] = {"version":1,"awake":false,"flags":{},"visited":{},"doors":{},"containers":{},"enemies":{},"records":{},"slots":{},"health":100.0,"food":100.0,"water":100.0,"wounds":{},"mag":0,"chamber":0,"checked":false,"position":[-24.0,0.95,-10.0],"drops":[]}
	data = save["zarya2"]
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
	for key in data.slots:
		if data.slots[key].id == id and not ITEMS[id].has("hands"):
			data.slots[key].count += count
			changed.emit()
			return true
	for i in range(18):
		var key := "bag"+str(i)
		if not data.slots.has(key):
			data.slots[key] = item(id,count)
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
func move_slot(source: String, target: String) -> bool:
	if source == target or not data.slots.has(source): return false
	var entry: Dictionary = data.slots[source]
	if target in ["left","right"]:
		if not ITEMS[entry.id].has("hands"): return false
		var other := "right" if target == "left" else "left"
		if data.slots.has(other) and int(ITEMS[data.slots[other].id].get("hands",1)) == 2: return false
		if int(ITEMS[entry.id].get("hands",1)) == 2 and data.slots.has(other) and other != source: return false
	var previous: Dictionary = data.slots.get(target,{})
	data.slots[target] = entry
	data.slots.erase(source)
	if not previous.is_empty(): data.slots[source] = previous
	changed.emit()
	return true
func equip(source: String) -> bool:
	return move_slot(source,"left" if not data.slots.has("left") else "right")
func weapon() -> String:
	for hand in ["right","left"]:
		var id: String = data.slots.get(hand,{}).get("id","")
		if id in ["pistol","rifle"]: return id
	return ""
func loot(id: String, index: int) -> bool:
	var list: Array = data.containers.get(id,[])
	if index < 0 or index >= list.size(): return false
	if not give(list[index].id,int(list[index].count)): return false
	list.remove_at(index)
	changed.emit()
	return true
func treat(zone: String, medicine: String) -> bool:
	if not data.wounds.has(zone): return false
	var wound: Dictionary = data.wounds[zone]
	if medicine == "band" and float(wound.bleeding) <= 0: return false
	if medicine == "medkit" and float(wound.damage) <= 0: return false
	if medicine == "morph" and float(wound.pain) <= 0: return false
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
