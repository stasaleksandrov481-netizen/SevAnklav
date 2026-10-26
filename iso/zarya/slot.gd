extends Button
var ui
var key := ""
func _get_drag_data(_at: Vector2) -> Variant:
	if not ui.world.state.data.slots.has(key): return null
	var preview:=TextureRect.new(); preview.texture=icon; preview.custom_minimum_size=Vector2(64,64)
	set_drag_preview(preview)
	return key
func _can_drop_data(_at: Vector2, data: Variant) -> bool: return data is String
func _drop_data(_at: Vector2, data: Variant) -> void:
	ui.world.state.move_slot(data,key)
	ui.refresh_slots()
