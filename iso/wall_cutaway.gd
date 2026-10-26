extends RefCounted

static func blocks(visual: MeshInstance3D, point: Vector3, camera: Camera3D) -> bool:
	# Player origin is at waist height. Cover boots, shoulders and head rather
	# than a single oversized ray that also hit unrelated neighbouring walls.
	var right := camera.global_basis.x * 0.34
	var targets := [point + Vector3.UP * 0.75, point - Vector3.UP * 0.70, point + right, point - right]
	var bounds := visual.get_aabb().grow(0.06)
	for target: Vector3 in targets:
		var eye := target + camera.global_basis.z * camera.far
		if bounds.intersects_segment(visual.to_local(target), visual.to_local(eye)) != null: return true
	return false

static func update(visual: MeshInstance3D, point: Vector3, camera: Camera3D, delta: float, force_cut := false) -> void:
	var blocked := force_cut or blocks(visual, point, camera)
	if not blocked and not visual.has_meta("cut_alpha"): return
	if not visual.has_meta("cut_alpha"):
		var original: Material = visual.material_override
		var faded := original.duplicate() as StandardMaterial3D
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		visual.set_meta("cut_opaque", original)
		visual.set_meta("cut_faded", faded)
		visual.set_meta("cut_alpha", 1.0)
		var caster := MeshInstance3D.new()
		caster.mesh = visual.mesh
		caster.material_override = original
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.visible = false
		visual.add_child(caster)
		visual.set_meta("cut_caster", caster)
	var alpha := move_toward(float(visual.get_meta("cut_alpha")), 0.035 if blocked else 1.0, delta * 5.0)
	if alpha == float(visual.get_meta("cut_alpha")): return
	visual.set_meta("cut_alpha", alpha)
	var caster: MeshInstance3D = visual.get_meta("cut_caster")
	caster.visible = alpha < 1.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if alpha < 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if alpha >= 1.0:
		visual.material_override = visual.get_meta("cut_opaque")
	else:
		var material: StandardMaterial3D = visual.get_meta("cut_faded")
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
		visual.material_override = material
