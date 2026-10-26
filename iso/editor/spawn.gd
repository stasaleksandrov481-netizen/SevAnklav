@tool
extends Node3D
@export var spawn_id := "subject"
func _ready() -> void:
	if not Engine.is_editor_hint(): return
	var g:=Node3D.new(); g.name="Generated"; add_child(g)
	var model:=MeshInstance3D.new(); var mesh:=CapsuleMesh.new(); mesh.radius=0.3; mesh.height=1.8; model.mesh=mesh
	var m:=StandardMaterial3D.new(); m.albedo_color=Color(0.7,0.2,0.15,0.6); m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; model.material_override=m; g.add_child(model)
