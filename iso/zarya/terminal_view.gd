extends RefCounted
const BunkerSkin=preload("res://scripts/ui/bunker_skin.gd")
var ui
var action:Dictionary
var record:Dictionary
var readonly:=false
var host:Control
var content:VBoxContainer
var selected:="home"
var tabs:Dictionary={}
func build(owner,source:Dictionary,data:Dictionary,read_only:=false)->void:
 ui=owner;action=source;record=data;readonly=read_only
 var column=ui.window("ТЕРМИНАЛ / A-03");host=ui.modal;ui.terminal_view=self;host.set_meta("terminal",true)
 var bezel=BunkerSkin.surface(32);bezel.bg_color=Color(.018,.061,.077,.64);bezel.border_color=Color(.36,.70,.76,.52);bezel.set_border_width_all(1);bezel.set_corner_radius_all(16);host.add_theme_stylebox_override("panel",bezel)
 ui.shade.color=Color(.006,.018,.025,.14)
 var glass=preload("res://scripts/ui/terminal_glass.gd").new();glass.name="TerminalGlass";host.add_child(glass);host.move_child(glass,0)
 ui.label(column,"СЕВЕРНЫЙ АНКЛАВ   /   ОПЕРАТОР V-17   /   ОПТИЧЕСКИЙ КАНАЛ",15)
 var row=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",18);column.add_child(row)
 var nav=VBoxContainer.new();nav.custom_minimum_size.x=220;nav.add_theme_constant_override("separation",8);row.add_child(nav)
 for entry in [["home","Главная","home"],["messages","Сообщения","mail"],["logs","Журналы","logs"],["systems","Системы","gear"],["cameras","Камеры","camera"],["access","Доступ","lock"]]:
  var id:String=entry[0]
  var b=ui.button(nav,entry[1],func():select_tab(id),220);b.name="TerminalTab_"+id;b.custom_minimum_size.y=72;b.toggle_mode=true;b.icon=load("res://assets/ui/bunker/icons/"+entry[2]+".svg");b.expand_icon=true;b.add_theme_constant_override("icon_max_width",25);tabs[id]=b
 ui.button(nav,"НАЗАД",ui.close_modal,220)
 for b in tabs.values():
  var normal=BunkerSkin.surface(14);normal.bg_color=Color(.02,.09,.11,.24);normal.border_color=Color(.35,.65,.72,.35);b.add_theme_stylebox_override("normal",normal)
  var pressed=normal.duplicate();pressed.bg_color=Color(.18,.42,.46,.44);pressed.border_color=Color(.5,.85,.88,.75);b.add_theme_stylebox_override("pressed",pressed)
 var frame=PanelContainer.new();frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var screen=BunkerSkin.surface(22);screen.bg_color=Color(.005,.025,.033,.25);screen.border_color=Color(.37,.70,.74,.30);frame.add_theme_stylebox_override("panel",screen);row.add_child(frame)
 content=VBoxContainer.new();content.name="TerminalContent";content.add_theme_constant_override("separation",14);frame.add_child(content)
 var save=ui.button(column,"ВЕРНУТЬСЯ К ИССЛЕДОВАНИЮ" if readonly else "ЗАГРУЗИТЬ ЗАПИСЬ / ВЫПОЛНИТЬ ДЕЙСТВИЕ",apply,520);save.name="TerminalApply";save.custom_minimum_size.y=60
 select_tab("messages" if readonly else "home")
func select_tab(id:String)->void:
 selected=id
 for key in tabs:tabs[key].button_pressed=key==id
 for child in content.get_children():content.remove_child(child);child.queue_free()
 if id=="home":
  ui.label(content,"СИСТЕМА БУНКЕРА / ЛОКАЛЬНЫЙ УЗЕЛ",23)
  ui.label(content,"СОСТОЯНИЕ: ЧАСТИЧНАЯ РАБОТОСПОСОБНОСТЬ\nСЕАНС: "+str(action.get("title","A-03")),18)
  content.add_child(HSeparator.new());show_record(record)
 elif id=="messages":show_record(record)
 elif id=="logs":
  ui.label(content,"СОХРАНЁННЫЕ ЖУРНАЛЫ",23)
  var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
  var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",10);scroll.add_child(list)
  for key in ui.world.state.data.records:
   var entry:Dictionary=ui.world.state.data.records[key]
   var item=ui.button(list,str(entry.title),func():
    for child in content.get_children():content.remove_child(child);child.queue_free()
    show_record(entry),600);item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  if ui.world.state.data.records.is_empty():ui.label(list,"ЛОКАЛЬНЫЙ АРХИВ ПУСТ",19)
 elif id=="systems":
  ui.label(content,"РЕЗЕРВНЫЕ СИСТЕМЫ",23)
  for entry in [["relay_k2","РЕЛЕ К-2"],["pump_valve","РЕЗЕРВНЫЙ КЛАПАН"]]:
   var done:bool=ui.world.state.flag(entry[0])
   var status=ui.label(content,entry[1]+"\n"+("РАБОТА ВОССТАНОВЛЕНА" if done else "ТРЕБУЕТСЯ ОБСЛУЖИВАНИЕ"),22);status.add_theme_color_override("font_color",BunkerSkin.ICE if done else BunkerSkin.GOLD)
 elif id=="cameras":
  ui.label(content,"ВИДЕОНАБЛЮДЕНИЕ / КАНАЛ НЕДОСТУПЕН",23)
  ui.label(content,"Видеопоток отсутствует. Доступны только сохранённые сообщения поста наблюдения.",21)
  if action.get("record","")=="cameras":show_record(record)
 elif id=="access":
  ui.label(content,"КОНТРОЛЬ ДОСТУПА",23)
  var card:bool=ui.world.state.amount("card")>0
  ui.label(content,"КАРТА ИНЖЕНЕРА: "+("ОБНАРУЖЕНА" if card else "НЕ ПРЕДЪЯВЛЕНА")+"\n\nВЫХОДНОЙ ЦИКЛ: "+("ГОТОВ" if ui.world.state.flag("pump_valve") else "ВОССТАНОВИТЕ K-2 И ДАВЛЕНИЕ")+"",22)
func show_record(entry:Dictionary)->void:
 ui.label(content,str(entry.get("title","СЛУЖЕБНАЯ ЗАПИСЬ")),24)
 var text=RichTextLabel.new();text.name="EvidenceText";text.selection_enabled=true;text.size_flags_vertical=Control.SIZE_EXPAND_FILL;text.custom_minimum_size.y=160;text.add_theme_color_override("default_color",Color("#a9cecb"));text.add_theme_font_size_override("normal_font_size",int(ui.world.state.data.get("reader_font_size",24)));text.add_theme_constant_override("line_separation",5);text.text=str(entry.get("body","")).replace("\\n","\n");content.add_child(text)
 ui.reader_tools(content,text)
func apply()->void:
 if ui.modal!=host or host.is_queued_for_deletion():return
 if readonly:ui.close_modal();return
 if ui.world.activate(action.id):
  var stored=record.duplicate(true);stored.medium="terminal";stored.source_id=action.id
  ui.world.state.data.records[action.id]=stored;ui.world.save_state();ui.notify("ДАННЫЕ СОХРАНЕНЫ В КПК")
