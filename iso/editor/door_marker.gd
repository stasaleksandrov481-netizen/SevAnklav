@tool
extends Node3D
@export var door_id := ""
@export var room_a := ""
@export var room_b := ""
@export_enum("manual","auto","hermetic","card","electronic","bulkhead","damaged","gate") var kind := "manual":
	set(v):
		kind=v
		if is_inside_tree(): call_deferred("_preview")
@export var lock := ""
func _ready() -> void: _preview()
func _preview() -> void:
	if not Engine.is_editor_hint(): return
	if has_node("Generated"): var old=get_node("Generated"); remove_child(old); old.queue_free()
	var g:=Node3D.new(); g.name="Generated"; add_child(g)
	var p=preload("res://iso/editor/piece.gd").new(); p.name="Preview"; p.kind="Block"; p.dimensions=Vector3(3 if kind=="gate" else 1.4,2.5,0.2); p.position.y=1.25; p.solid=false; g.add_child(p)
	var text:=Label3D.new(); text.text="ДВЕРЬ / "+kind; text.position.y=2.8; text.pixel_size=0.005; g.add_child(text)
