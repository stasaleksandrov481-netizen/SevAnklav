extends Node2D
var b
func _process(_delta: float) -> void:
    visible=b.player["spr"].visible and b.player["alive"]
    position=b.player["spr"].position
    rotation=b.player["aim"]
    queue_redraw()
func _draw() -> void:
    for i in range(2):
        var item:=str(b.loadout7.hands()[i])
        if item=="flashlight":
            var y: float=-11 if i==0 else 11
            draw_rect(Rect2(13,y-2,14,4),Color(0.10,0.15,0.18))
            draw_line(Vector2(15,y-2),Vector2(25,y-2),Color(0.57,0.66,0.69),1)
            draw_circle(Vector2(28,y),3,Color(0.12,0.19,0.22))
            draw_circle(Vector2(29,y),1.8,Color(0.61,0.77,0.8) if not b.zp.get("flash_off",false) else Color(0.07,0.10,0.12))
        elif item.begins_with("weapon:") and item.trim_prefix("weapon:")!=b.loadout7.weapon():
            var y: float=-10 if i==0 else 10
            draw_rect(Rect2(14,y-2,13,4),Color(0.08,0.11,0.13))
            draw_line(Vector2(25,y),Vector2(31,y),Color(0.32,0.40,0.43),2)
        elif item!="" and not item.begins_with("weapon:"):
            var tex: Texture2D=b.loadout7.icon_of(item)
            if tex!=null: draw_texture_rect(tex,Rect2(16,-16 if i==0 else 7,12,12),false)
