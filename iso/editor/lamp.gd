@tool
extends Node3D
@export var emergency := false:
	set(v): emergency=v; refresh()
@export var energy := 2.7:
	set(v): energy=v; refresh()
@export var radius := 10.0:
	set(v): radius=v; refresh()
@export var tint := Color("#bad2df"):
	set(v): tint=v; refresh()
func refresh() -> void:
	if is_inside_tree(): call_deferred("rebuild")
func _ready() -> void: rebuild()
func rebuild() -> void:
	if has_node("Generated"): var old=get_node("Generated"); remove_child(old); old.queue_free()
	var g:=Node3D.new(); g.name="Generated"; g.set_meta("fixture",true); add_child(g)
	var mesh:=MeshInstance3D.new(); mesh.name="Fixture"; var b:=BoxMesh.new(); b.size=Vector3(0.5,0.16,0.12) if emergency else Vector3(0.95,0.25,0.18); mesh.mesh=b
	var m:=StandardMaterial3D.new(); m.albedo_color=Color("#a34434") if emergency else Color("#a9bfc9"); mesh.material_override=m; g.add_child(mesh)
	var light:=OmniLight3D.new(); light.name="Light"; light.position.z=0.25 if not emergency else 0; light.light_color=tint; light.light_energy=energy; light.omni_range=radius; light.shadow_enabled=true; g.add_child(light)
