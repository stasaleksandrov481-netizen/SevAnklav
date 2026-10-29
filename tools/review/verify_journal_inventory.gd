extends SceneTree
const Journal=preload("res://iso/zarya/journal.gd")
var checks:=0
func _initialize():call_deferred("run")
func check(ok: bool, message: String) -> bool:
	if not ok:push_error(message);quit(1);return false
	checks+=1;return true
func cell(ui,key):
	for item in ui.slots:
		if is_instance_valid(item) and ui.modal.is_ancestor_of(item) and item.key==key:return item
	return null
func run():
	var state_script=load("res://iso/zarya/state.gd")
	var s=state_script.new({})
	s.data.slots={"bag0":{"id":"water","count":3,"condition":47,"batch":{"label":"A"}},"bag1":{"id":"water","count":2,"condition":47,"batch":{"label":"A"}}}
	if not check(s.move_slot("bag0","bag1") and not s.data.slots.has("bag0") and s.data.slots.bag1.count==5,"Compatible stacks did not combine"):return
	s.data.slots.bag0={"id":"water","count":1,"condition":18,"batch":{"label":"B"}}
	if not check(s.move_slot("bag0","bag1") and s.data.slots.bag0.count==5 and s.data.slots.bag1.condition==18,"Different item properties were merged or lost"):return
	var before: Dictionary=s.data.slots.duplicate(true)
	for target in ["clothes","left","bag18","bag-1","bag01","quick4","missing"]:
		if not check(not s.move_slot("bag0",target) and s.data.slots==before,"Invalid destination changed inventory: "+target):return
	var split: String=s.split_slot("bag0")
	if not check(not split.is_empty() and s.data.slots[split].count==1 and s.data.slots.bag0.count==4,"Splitting lost or duplicated units"):return
	s.data.slots[split].batch.label="changed"
	if not check(s.data.slots.bag0.batch.label=="A","Split item retained a mutable metadata alias"):return
	if not check(s.split_slot(split).is_empty() and s.split_slot("missing").is_empty(),"Invalid split succeeded"):return
	s.data.slots={}
	for i in 18:s.data.slots["bag"+str(i)]=s.item("water",2)
	before=s.data.slots.duplicate(true)
	if not check(s.split_slot("bag0").is_empty() and s.data.slots==before,"Splitting into a full bag consumed an item"):return
	s.data.slots={"bag0":s.item("uniform"),"left":s.item("pistol"),"right":s.item("flashlight"),"bag1":s.item("pistol")}
	if not check(s.equip("bag0") and s.data.slots.clothes.id=="uniform" and not s.data.slots.has("bag0"),"Uniform did not equip as clothing"):return
	before=s.data.slots.duplicate(true)
	if not check(not s.equip("bag1") and s.data.slots==before,"Equip replaced an occupied hand"):return
	if not check(s.move_slot("left","bag0") and s.equip("bag1") and s.data.slots.left.id=="pistol","Equip did not use the free hand"):return
	s.data.slots.bag2=s.item("rifle")
	if not check(not s.equip("bag2"),"Two-handed weapon equipped while other hand occupied"):return
	var game=root.get_node("G");game.zsave=game._default_zsave()
	var prior=state_script.new(game.zsave,"zarya_layout3");prior.data.awake=true
	var scene=load("res://iso/bunker_world.tscn");var w=scene.instantiate();root.add_child(w)
	for i in 12:await physics_frame
	w.player.set_physics_process(false)
	var ui=w.hud
	if not check(Journal.next_step(w).id=="identity_v17" and Journal.traces(w).size()==13,"Fresh journal has the wrong initial step or missing traces"):return
	w.state.data.slots={"bag0":w.state.item("fuse")}
	if not check(Journal.next_step(w).id=="relay_k2","Out-of-order supplies forced replaying earlier steps"):return
	ui.selected="bag0";ui.open_inventory();ui.drop_selected()
	var drop_id: String=w.state.data.drops.back().id
	if not check(Journal.next_step(w).id==drop_id,"Journal points to an empty crate after dropping the fuse"):return
	var action=w.stations.filter(func(a):return a.id==drop_id)[0];ui.transfer(action,0)
	if not check(Journal.next_step(w).id=="relay_k2","Picking up the fuse did not restore the repair objective"):return
	w.state.take("fuse");w.state.mark("relay_k2")
	if not check(Journal.next_step(w).id=="pump_valve","Repair objective did not advance"):return
	w.state.data.records.archive_chat={"title":"Архив / переписка","body":"Проверка записи"};w.state.mark("pump_valve")
	if not check(Journal.next_step(w).id=="lab_observation","Journal did not skip a previously found clue"):return
	ui.close_modal();ui.root.get_node("Tasks/OpenJournal").pressed.emit()
	if not check(ui.modal.get_meta("journal",false) and w.paused and ui.modal.find_child("JournalObjective",true,false).text==w.objective(),"HUD journal button did not open the current objective"):return
	if not check(ui.modal.find_child("JournalClue_identity_v17",true,false).disabled,"Unfound evidence can be read through the journal"):return
	ui.modal.find_child("JournalClue_archive_chat",true,false).pressed.emit()
	if not check(ui.modal.find_child("EvidenceText",true,false).text=="Проверка записи","Found journal evidence did not open the saved text"):return
	w.state.data.slots={"bag0":{"id":"water","count":3,"condition":47,"batch":{"label":"A"}},"bag1":w.state.item("uniform")}
	ui.selected="bag0";ui.open_inventory();ui.item_actions.move.pressed.emit()
	if not check(ui.moving_from=="bag0","Tap transfer did not arm"):return
	cell(ui,"clothes").pressed.emit()
	if not check(ui.moving_from=="bag0" and w.state.data.slots.bag0.count==3 and not w.state.data.slots.has("clothes"),"Rejected clothing transfer mutated items or cancelled selection"):return
	cell(ui,"quick1").pressed.emit()
	if not check(ui.moving_from.is_empty() and ui.selected=="quick1" and w.state.data.slots.quick1.condition==47 and not w.state.data.slots.has("bag0"),"Tap transfer lost metadata or focus"):return
	var saved:=ConfigFile.new()
	if not check(saved.load("user://anklav_rts.cfg")==OK and saved.get_value("zcamp","zsave")[w.state_key].slots.quick1.condition==47,"Tap transfer was not saved immediately"):return
	ui.item_actions.move.pressed.emit();cell(ui,"quick1").pressed.emit()
	if not check(ui.moving_from.is_empty() and w.state.data.slots.quick1.count==3,"Repeat source tap did not cancel safely"):return
	ui.item_actions.split.pressed.emit()
	if not check(ui.selected=="bag0" and w.state.data.slots.bag0.count==1 and w.state.data.slots.quick1.count==2,"Split control did not focus the separated unit"):return
	cell(ui,"bag1").pressed.emit();ui.item_actions.hand.pressed.emit()
	if not check(ui.selected=="clothes" and w.state.data.slots.clothes.id=="uniform","Clothing action has no valid destination or lost focus"):return
	ui.select_slot("quick1");ui.begin_move();ui.open_pda();ui.open_inventory()
	if not check(ui.moving_from.is_empty(),"Transfer selection leaked between windows"):return
	var drag_cell=cell(ui,"bag2");drag_cell._drop_data(Vector2.ZERO,"quick1")
	saved=ConfigFile.new()
	if not check(saved.load("user://anklav_rts.cfg")==OK and saved.get_value("zcamp","zsave")[w.state_key].slots.bag2.count==2,"Drag transfer did not save the moved stack"):return
	w.state.data.water=40;ui.select_slot("bag0");ui.begin_move();ui.consume()
	if not check(ui.moving_from.is_empty() and not w.state.data.slots.has("bag0"),"Using the last unit left a transfer attached to an empty source"):return
	if not check(ui.item_actions.move.disabled and ui.notice.text.contains("ВОДЫ ВОСПОЛНЕН"),"Consumption left a stale transfer prompt"):return
	w.state.data.health=63;w.state.data.wounds["Левая рука"].bleeding=.4;ui.close_modal();ui._process(.2)
	if not check(ui.health_readout.text.contains("63%") and ui.health_readout.tooltip_text.contains("КРОВОТЕЧЕНИЕ"),"HUD hides health or bleeding state"):return
	w.state.data.records={}
	for clue in Journal.traces(w):w.state.data.investigation_seen[clue.id]=true
	if not check(Journal.next_step(w).id=="complete","Fully inspected bunker never finishes its journal"):return
	if not check(w.doors.filter(func(d):return d.info.kind=="sealed").all(func(d):return not d.opened),"Journal completion unlocked an external location"):return
	for dimensions in [Vector2i(1600,900),Vector2i(960,540),Vector2i(720,1280)]:
		root.size=dimensions
		ui.open_inventory();ui.select_slot("bag2");ui.begin_move()
		for i in 6:await process_frame
		if not check(ui.modal.get_rect().end.x<=ui.canvas_size.x and ui.modal.get_rect().end.y<=ui.canvas_size.y,"Inventory panel extends beyond the visible canvas"):return
		if not check(ui.item_actions.split.get_global_rect().end.x<=ui.modal.get_global_rect().end.x and ui.item_actions.split.get_global_rect().end.y<=ui.modal.get_global_rect().end.y,"Inventory actions overflow on resize"):return
		ui.open_journal()
		for i in 6:await process_frame
		if not check(ui.modal.get_rect().end.x<=ui.canvas_size.x and ui.modal.get_rect().end.y<=ui.canvas_size.y,"Journal panel extends beyond the visible canvas"):return
		var scroll=ui.modal.find_child("JournalScroll",true,false)
		if not check(scroll.get_global_rect().end.y<=ui.modal.get_global_rect().end.y and ui.modal.find_child("JournalClueCount",true,false).text.contains("13 ИЗ 13"),"Journal scroll/count is broken on resize"):return
	w.save_state();w.queue_free()
	for i in 5:await process_frame
	game._load_save();w=scene.instantiate();root.add_child(w)
	for i in 8:await physics_frame
	if not check(Journal.next_step(w).id=="complete" and w.state.data.slots.bag2.count==2,"Disk reload lost the journal or item transfer"):return
	w.queue_free()
	for i in 5:await process_frame
	print("JOURNAL INVENTORY PASS: ",checks," checks; progression, out-of-order clues, dropped fuse, touch moves, stack metadata, clothes, save, health, three layouts")
	quit()
