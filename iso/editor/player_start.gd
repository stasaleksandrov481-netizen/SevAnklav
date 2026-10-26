@tool
extends Marker3D
func _ready() -> void:
	if Engine.is_editor_hint():
		var preview := Node3D.new()
		preview.name = "Generated"
		add_child(preview)
		var label := Label3D.new()
		label.text = "СТАРТ ИГРОКА"
		label.position.y = 1.3
		label.pixel_size = 0.005
		preview.add_child(label)
