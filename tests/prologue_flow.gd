extends SceneTree
var failures := 0
var checks := 0
var handed_off := false
func prologue_done() -> void: handed_off = true
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.get_node("G").set_meta("qa8",true)
	for branch in [0,1]:
		root.get_node("G").zsave=root.get_node("G")._default_zsave()
		handed_off=false
		var intro=load("res://scripts/zprologue_zarya.gd").new(); intro.main_ref=self; root.add_child(intro)
		await process_frame
		intro._choose(branch); await create_timer(0.35).timeout
		check(intro.step==1 and intro.branch==("memory" if branch==0 else "listen"),"First choice preserves branch")
		intro._choose(0); await create_timer(0.35).timeout
		check(intro.step==2,"Second choice advances")
		intro._choose(0); await create_timer(0.55).timeout
		check(handed_off and root.get_node("G").zsave.seen_prologue,"Prologue hands off once to gameplay")
		intro.queue_free(); await process_frame
	print("PROLOGUE_CHECKS ",checks," FAILED ",failures)
	quit(1 if failures else 0)
