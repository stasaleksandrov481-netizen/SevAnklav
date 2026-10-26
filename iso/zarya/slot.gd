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
	if ui.world.state.move_slot(data,key): ui.selected=key
	ui.refresh_slots()
	ui.update_details()

func _draw() -> void:
	if ui==null: return
	var item: Dictionary=ui.world.state.data.slots.get(key,{})
	var font:=ThemeDB.fallback_font
	if item.is_empty():
		var caption: String={"left":"Л", "right":"П", "clothes":"ОДЕЖДА", "pocket0":"КАРМАН", "pocket1":"КАРМАН"}.get(key,"")
		draw_string(font,Vector2(10,size.y-10),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#627078"))
	else:
		var count: String=str(item.get("count",1))
		draw_string(font,Vector2(size.x-22,size.y-11),count,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#dce5e8"))
		var condition: float=float(item.get("condition",100))/100
		draw_rect(Rect2(10,size.y-4,(size.x-20)*condition,1),Color("#7b9198"))
	if ui.selected==key:
		draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)),Color("#c0d4db"),false,1.5)
		draw_line(Vector2(2,2),Vector2(22,2),Color("#e2b572"),2)
