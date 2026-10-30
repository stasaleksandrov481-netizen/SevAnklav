class_name MainMenuScreen
extends CanvasLayer
signal play_pressed
signal mil_pressed
signal settings_pressed
signal help_pressed
signal quit_pressed
signal continue_pressed
signal load_pressed
const P=preload("res://scripts/ui/bunker_skin.gd")
const Back=preload("res://scripts/ui/native_back.gd")
var menu_root:Control
var menu_canvas:Control
var coop_modal:Control
var confirm_modal:Control
var transitioning:=false
func _ready()->void:
 # The authored scene is the single source of the menu's visible layout.
 # Script-only callers use that same layout instead of a second menu builder.
 if not has_node("MenuRoot"):
  var template=load("res://scenes/ui/MainMenu.tscn").instantiate()
  var layout=template.get_node("MenuRoot");template.remove_child(layout);add_child(layout);template.free()
 layer=10
 menu_root=get_node("MenuRoot");menu_canvas=menu_root.get_node("MenuCanvas")
 Back.install(self,handle_back)
 add_child(preload("res://scripts/ui/menu_music.gd").new())
 menu_canvas.theme=P.make_theme()
 var callbacks=[func():launch(func():continue_pressed.emit()),open_coop,request_new_game,func():launch(func():load_pressed.emit()),func():settings_pressed.emit(),func():open_confirmation("quit")]
 for i in 6:
  var control:Button=menu_canvas.get_node("MenuAction"+str(i))
  control.pressed.connect(callbacks[i])
  if i in [0,3]:
   control.disabled=not has_progress();control.tooltip_text="Сначала начните новую игру" if control.disabled else ""
 for item in [["Telegram","https://t.me/SevAnklav"],["TikTok","https://www.tiktok.com/@sevanklav"]]:
  var control:Button=menu_canvas.get_node("SocialLinks/"+str(item[0]));var url:String=item[1]
  control.pressed.connect(func():OS.shell_open(url))
 var snow=Snow.new();snow.size=Vector2(1536,864);snow.modulate.a=.35;snow.mouse_filter=Control.MOUSE_FILTER_IGNORE;menu_canvas.add_child(snow)
 _fit_menu();get_viewport().size_changed.connect(_fit_menu)
 menu_canvas.modulate.a=0;create_tween().tween_property(menu_canvas,"modulate:a",1.0,0.45)
 call_deferred("_ensure_game_owner")
func _ensure_game_owner()->void:
 # F6 / direct launch of the menu must still open a functional game controller.
 if get_tree().current_scene==self and get_tree().get_nodes_in_group("main_root").is_empty():
  get_tree().change_scene_to_file("res://scenes/main.tscn")
func _label(text:String,px:int,color:Color)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",px);l.add_theme_color_override("font_color",color);return l
func _fit_menu()->void:
 if menu_canvas==null:return
 var vp=get_viewport().get_visible_rect().size
 menu_root.size=vp
 var k=minf(vp.x/1536.0,vp.y/864.0)
 menu_canvas.scale=Vector2.ONE*k;menu_canvas.position=(vp-Vector2(1536,864)*k)/2
func open_coop()->void:
 if is_instance_valid(coop_modal) or is_instance_valid(confirm_modal) or transitioning:return
 coop_modal=Control.new();coop_modal.name="CoopModal";coop_modal.size=Vector2(1536,864);menu_canvas.add_child(coop_modal)
 var shade=ColorRect.new();shade.size=coop_modal.size;shade.color=Color(0.015,0.025,0.035,0.88);coop_modal.add_child(shade)
 var card=PanelContainer.new();card.position=Vector2(468,244);card.size=Vector2(600,376);card.add_theme_stylebox_override("panel",P.surface(30,true));coop_modal.add_child(card)
 var col=VBoxContainer.new();col.add_theme_constant_override("separation",22);card.add_child(col)
 col.add_child(_label("СЕВЕРНЫЙ АНКЛАВ  /  СОВМЕСТНЫЙ РЕЖИМ",12,P.ICE))
 col.add_child(_label("CO-OP ИГРА",36,P.TEXT))
 col.add_child(HSeparator.new())
 var body=_label("СИГНАЛ ЕЩЁ НЕ УСТАНОВЛЕН",16,P.GOLD);col.add_child(body)
 var desc=_label("Совместный режим в разработке.\nНовости о нём появятся в наших социальных сетях.",17,P.MUTED);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(desc)
 var close=Button.new();close.text="ВЕРНУТЬСЯ В МЕНЮ";close.custom_minimum_size.y=52;P.button(close,true);close.pressed.connect(close_coop);col.add_child(close);close.grab_focus()
 coop_modal.modulate.a=0;create_tween().tween_property(coop_modal,"modulate:a",1.0,0.2)
func close_coop()->void:
 if is_instance_valid(coop_modal):coop_modal.queue_free()
 coop_modal=null
 menu_canvas.get_node("MenuAction1").grab_focus()
func has_progress()->bool:
 return G.zsave.has("zarya_layout3") or bool(G.zsave.get("seen_prologue",false))
func launch(action:Callable)->void:
 if transitioning:return
 transitioning=true
 for i in 6:menu_canvas.get_node("MenuAction"+str(i)).disabled=true
 action.call()
func request_new_game()->void:
 if transitioning:return
 if has_progress():open_confirmation("new")
 else:launch(func():play_pressed.emit())
func open_confirmation(kind:String)->void:
 if is_instance_valid(confirm_modal) or is_instance_valid(coop_modal) or transitioning:return
 confirm_modal=Control.new();confirm_modal.name="ConfirmModal";confirm_modal.size=Vector2(1536,864);confirm_modal.set_meta("kind",kind);menu_canvas.add_child(confirm_modal)
 var shade=ColorRect.new();shade.size=confirm_modal.size;shade.color=Color(0.015,0.025,0.035,.9);confirm_modal.add_child(shade)
 var card=PanelContainer.new();card.position=Vector2(468,244);card.size=Vector2(600,376);card.add_theme_stylebox_override("panel",P.surface(30,true));confirm_modal.add_child(card)
 var col=VBoxContainer.new();col.add_theme_constant_override("separation",22);card.add_child(col)
 col.add_child(_label("НАЧАТЬ ЗАНОВО?" if kind=="new" else "ВЫЙТИ ИЗ ИГРЫ?",30,P.TEXT))
 var desc=_label("Прогресс первой истории будет заменён. Настройки сохранятся." if kind=="new" else "Текущий прогресс уже сохранён. Можно вернуться позже.",20,P.MUTED);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(desc)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);col.add_child(row)
 var cancel=Button.new();cancel.name="ConfirmCancel";cancel.text="ОТМЕНА";cancel.custom_minimum_size=Vector2(220,58);P.button(cancel);cancel.pressed.connect(close_confirmation);row.add_child(cancel)
 var accept=Button.new();accept.name="ConfirmAccept";accept.text="НАЧАТЬ ЗАНОВО" if kind=="new" else "ВЫЙТИ";accept.custom_minimum_size=Vector2(280,58);P.button(accept,true);row.add_child(accept)
 var dialog=confirm_modal
 accept.pressed.connect(func():
  if confirm_modal!=dialog or dialog.is_queued_for_deletion():return
  close_confirmation()
  if kind=="new":launch(func():play_pressed.emit())
  else:launch(func():quit_pressed.emit()))
 cancel.grab_focus()
func close_confirmation()->void:
 if is_instance_valid(confirm_modal):
  var index=2 if confirm_modal.get_meta("kind","")=="new" else 5
  confirm_modal.queue_free();menu_canvas.get_node("MenuAction"+str(index)).grab_focus()
 confirm_modal=null
func handle_back()->void:
 if transitioning:return
 if is_instance_valid(coop_modal):close_coop()
 elif is_instance_valid(confirm_modal):close_confirmation()
 else:open_confirmation("quit")
func _exit_tree()->void:Back.remove(self)
func _unhandled_input(event:InputEvent)->void:
 if event.is_action_pressed("ui_cancel"):Back.request(get_tree());get_viewport().set_input_as_handled()
class Snow extends Control:
    var t := 0.0
    var flakes: Array = []
    func _ready() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = 742
        for i in range(115):
            flakes.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.2,1.0), rng.randf_range(0.0,TAU)))
    func _process(delta: float) -> void:
        t += delta
        queue_redraw()
    func _draw() -> void:
        for f in flakes:
            var x := fposmod(f.x + t * (0.012 + f.z * 0.022) + sin(t * 0.3 + f.w) * 0.008, 1.0) * size.x
            var y := fposmod(f.y + t * (0.018 + f.z * 0.035), 1.0) * size.y
            draw_line(Vector2(x,y),Vector2(x+f.z*2.0,y+f.z*4.0),Color(0.83,0.92,1.0,0.10+f.z*0.25),0.5+f.z)
