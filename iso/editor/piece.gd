@tool
extends Node3D
@export_enum("Wall", "Floor", "Block") var kind := "Wall":
	set(v): kind=v; rebuild_later()
@export var dimensions := Vector3(3,2.8,0.2):
	set(v): dimensions=v.max(Vector3.ONE*0.02); rebuild_later()
@export var material: Material:
	set(v): material=v; rebuild_later()
@export var solid := true:
	set(v): solid=v; rebuild_later()
var pending:=false
func _ready() -> void: rebuild()
func rebuild_later() -> void:
	if is_inside_tree() and not pending: pending=true; call_deferred("rebuild")
func rebuild() -> void:
	pending=false
	if has_node("Generated"): var old=get_node("Generated"); remove_child(old); old.queue_free()
	var generated:=Node3D.new(); generated.name="Generated"; add_child(generated)
	var mesh:=MeshInstance3D.new(); mesh.name="Surface"; var box:=BoxMesh.new(); box.size=dimensions; mesh.mesh=box
	if material: mesh.material_override=material
	else:
		var m:=StandardMaterial3D.new(); m.albedo_color=Color("#61737b"); m.roughness=0.8
		if kind=="Wall": m.albedo_texture=preload("res://assets/iso/concrete_panels.png")
		mesh.material_override=m
	generated.add_child(mesh)
	if solid:
		var body:=StaticBody3D.new(); generated.add_child(body)
		var shape:=CollisionShape3D.new(); var b:=BoxShape3D.new(); b.size=dimensions; shape.shape=b; body.add_child(shape)
