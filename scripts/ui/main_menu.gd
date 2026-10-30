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
 Back.install(self,handle_back)
 for child in get_children():remove_child(child);child.queue_free()
 add_child(preload("res://scripts/ui/menu_music.gd").new())
 menu_root=Control.new();add_child(menu_root)
 menu_canvas=Control.new();menu_canvas.size=Vector2(1536,864);menu_canvas.theme=P.make_theme();menu_root.add_child(menu_canvas)
 _fit_menu();get_viewport().size_changed.connect(_fit_menu)
 var bg=TextureRect.new();bg.texture=preload("res://assets/ui/bunker/menu_background.png");bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.size=Vector2(1536,864);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;menu_canvas.add_child(bg)
 var title_font=FontVariation.new();title_font.base_font=P.FONT;title_font.variation_embolden=1.4;title_font.spacing_glyph=3
 var title=_label("СЕВЕРНЫЙ\nАНКЛАВ",76,Color("#ced6d7"));title.name="GameTitle";title.position=Vector2(90,103);title.add_theme_font_override("font",title_font);title.add_theme_color_override("font_outline_color",Color("#151b20"));title.add_theme_constant_override("outline_size",4);title.add_theme_color_override("font_shadow_color",Color(0,0,0,.9));title.add_theme_constant_override("shadow_offset_y",5);menu_canvas.add_child(title)
 var labels=["ПРОДОЛЖИТЬ","CO-OP ИГРА","НОВАЯ ИГРА","ЗАГРУЗИТЬ ИГРУ","НАСТРОЙКИ","ВЫХОД"]
 var callbacks=[func():launch(func():continue_pressed.emit()),open_coop,request_new_game,func():launch(func():load_pressed.emit()),func():settings_pressed.emit(),func():open_confirmation("quit")]
 var glyphs=["play","coop","new","load","gear","exit"]
 for i in range(labels.size()):
  var b=Button.new();b.name="MenuAction"+str(i);b.text=labels[i];b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.position=Vector2(90,310+i*70);b.size=Vector2(390,60);b.add_theme_font_size_override("font_size",22);P.button(b,i==0)
  var normal=P.surface(16);normal.bg_color=Color(.035,.055,.065,.94);normal.border_color=Color("#4b5b62")
  if i==0:normal.bg_color=Color(.18,.035,.03,.94);normal.border_color=Color("#9d4e43")
  b.add_theme_stylebox_override("normal",normal);b.icon=load("res://assets/ui/bunker/icons/"+glyphs[i]+".svg");b.expand_icon=true;b.add_theme_constant_override("icon_max_width",25);b.add_theme_constant_override("h_separation",18);b.pressed.connect(callbacks[i]);menu_canvas.add_child(b)
  if i==1:
   b.text="CO-OP ИГРА"
   var badge=_label("В РАЗРАБОТКЕ",12,P.MUTED);badge.position=Vector2(259,22);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(badge)
  if i in [0,3] and not has_progress():b.disabled=true;b.tooltip_text="Сначала начните новую игру"
 var socials=HBoxContainer.new();socials.position=Vector2(26,24);socials.add_theme_constant_override("separation",10);menu_canvas.add_child(socials)
 for item in [["telegram","TELEGRAM","https://t.me/SevAnklav"],["tiktok","TIKTOK","https://www.tiktok.com/@sevanklav"]]:
  var b=Button.new();b.icon=load("res://assets/ui/controls/"+item[0]+".svg");b.expand_icon=true;b.add_theme_constant_override("icon_max_width",25);b.custom_minimum_size=Vector2(48,48);b.tooltip_text=item[1];b.accessibility_name=item[1];P.button(b);var url:String=item[2];b.pressed.connect(func():OS.shell_open(url));socials.add_child(b)
 var code=_label("СЕКРЕТНЫЙ ОБЪЕКТ №742\nСЕВЕРНЫЙ АНКЛАВ\nБЛОК A-03",15,P.MUTED);code.position=Vector2(1260,30);menu_canvas.add_child(code)
 var quote=_label("НЕКОТОРЫЕ ДВЕРИ ЛУЧШЕ\nОСТАВИТЬ ЗАКРЫТЫМИ…",16,P.MUTED);quote.position=Vector2(1200,775);menu_canvas.add_child(quote)
 var version=_label("V-17  /  УРОВЕНЬ −2",13,P.MUTED);version.position=Vector2(28,826);menu_canvas.add_child(version)
 var snow=Snow.new();snow.size=Vector2(1536,864);snow.modulate.a=.35;snow.mouse_filter=Control.MOUSE_FILTER_IGNORE;menu_canvas.add_child(snow)
 menu_canvas.modulate.a=0;create_tween().tween_property(menu_canvas,"modulate:a",1.0,0.45)
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
