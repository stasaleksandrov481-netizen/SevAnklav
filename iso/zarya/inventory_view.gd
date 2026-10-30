extends RefCounted
const State=preload("res://iso/zarya/state.gd")
const BunkerSkin=preload("res://scripts/ui/bunker_skin.gd")
var ui
var panes:Dictionary={}
var tabs:Dictionary={}
var summary:Label
var bag_heading:Label
var loot:Dictionary={}
func build(owner,action:Dictionary={}) -> void:
 ui=owner;loot=action
 var column=ui.window("ИНВЕНТАРЬ / "+("ОБЫСК КОНТЕЙНЕРА" if not loot.is_empty() else "СОСТОЯНИЕ V-17"))
 ui.inventory_view=self;ui.modal.set_meta("inventory",true);ui.modal.set_meta("medical",true)
 ui.medical_zones={};ui.medical_actions={};ui.item_actions={}
 var row=HBoxContainer.new();row.name="InventoryColumns";row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",16);column.add_child(row)
 var equipment=frame(row,330);var middle=frame(row,480);var right=frame(row,420)
 right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 ui.label(equipment,"ОРГАНИЗМ / АЛЕКСЕЙ ВОЛКОВ",20)
 summary=ui.label(equipment,"",16);summary.name="InventoryVitals"
 var silhouette_area=Control.new();silhouette_area.custom_minimum_size=Vector2(290,330);equipment.add_child(silhouette_area)
 ui.medical_body=preload("res://iso/zarya/body.gd").new();ui.medical_body.ui=ui;ui.medical_body.name="MedicalBody";ui.medical_body.size=Vector2(340,410);ui.medical_body.scale=Vector2.ONE*.80;silhouette_area.add_child(ui.medical_body)
 silhouette_area.resized.connect(func():ui.medical_body.position.x=(silhouette_area.size.x-340*.80)/2)
 var hint=ui.label(equipment,"КОСНИТЕСЬ ПОВРЕЖДЁННОЙ ОБЛАСТИ",14);hint.add_theme_color_override("font_color",BunkerSkin.ICE)
 ui.label(equipment,"ЛЕВАЯ РУКА       ПРАВАЯ РУКА",14)
 var hands=HBoxContainer.new();hands.add_theme_constant_override("separation",8);equipment.add_child(hands)
 for key in ["left","right"]:
  var cell=ui.make_slot(hands,key);cell.custom_minimum_size=Vector2(130,76);cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 ui.label(equipment,"ОДЕЖДА                 КАРМАНЫ",14)
 var pockets=HBoxContainer.new();pockets.add_theme_constant_override("separation",8);equipment.add_child(pockets)
 for key in ["clothes","pocket0","pocket1"]:
  var cell=ui.make_slot(pockets,key);cell.custom_minimum_size=Vector2(84,68);cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 bag_heading=ui.label(middle,"",20)
 var scroll=ScrollContainer.new();scroll.name="InventoryBagScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size=Vector2(440,405);middle.add_child(scroll)
 var grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",7);grid.add_theme_constant_override("v_separation",7);scroll.add_child(grid)
 for i in 18:
  var cell=ui.make_slot(grid,"bag"+str(i));cell.custom_minimum_size=Vector2(103,86)
 ui.label(middle,"БЫСТРЫЙ ДОСТУП",16)
 var quick=HBoxContainer.new();quick.add_theme_constant_override("separation",7);middle.add_child(quick)
 for i in 4:
  var cell=ui.make_slot(quick,"quick"+str(i));cell.custom_minimum_size=Vector2(103,80)
 var navigation=HBoxContainer.new();navigation.add_theme_constant_override("separation",6);right.add_child(navigation)
 var types=["item","medical"]
 if not loot.is_empty():types.append("loot")
 for id in types:
  var target:String=id
  var tab=ui.button(navigation,{"item":"ПРЕДМЕТ","medical":"ЛЕЧЕНИЕ","loot":"ОБЫСК"}[id],func():show_right(target),110);tab.toggle_mode=true;tabs[id]=tab
 for id in ["item","medical","loot"]:
  var pane=VBoxContainer.new();pane.name="Inventory_"+id;pane.hide();pane.add_theme_constant_override("separation",12);pane.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(pane);panes[id]=pane
 build_item(panes.item);build_medical(panes.medical)
 if not loot.is_empty():build_loot(panes.loot)
 var links=HBoxContainer.new();links.add_theme_constant_override("separation",8);right.add_child(links)
 ui.button(links,"КПК",ui.open_pda,120);ui.button(links,"ЖУРНАЛ",ui.open_journal,140)
 refresh_summary();ui.refresh_slots();ui.update_details();ui.refresh_medical()
 show_right("loot" if not loot.is_empty() else "item")
func frame(parent:Node,width:float)->VBoxContainer:
 var plate=PanelContainer.new();plate.custom_minimum_size.x=width;plate.size_flags_vertical=Control.SIZE_EXPAND_FILL;plate.size_flags_horizontal=Control.SIZE_EXPAND_FILL;plate.add_theme_stylebox_override("panel",BunkerSkin.surface(14));parent.add_child(plate)
 var grain=preload("res://scripts/ui/document_material.gd").new();plate.add_child(grain)
 var col=VBoxContainer.new();col.add_theme_constant_override("separation",9);plate.add_child(col);return col
func build_item(side:VBoxContainer)->void:
 ui.detail_title=ui.label(side,"",24)
 ui.detail_image=TextureRect.new();ui.detail_image.custom_minimum_size=Vector2(320,144);ui.detail_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ui.detail_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;side.add_child(ui.detail_image)
 ui.detail_description=ui.label(side,"",18)
 var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",10);side.add_child(actions)
 ui.item_actions.hand=ui.icon_button(actions,"hand","Экипировать в свободную руку / надеть форму",ui.equip_selected)
 ui.item_actions.use=ui.icon_button(actions,"use","Использовать паёк или воду",ui.consume)
 ui.icon_button(actions,"medical","Лечение выбранной области",func():show_right("medical"))
 ui.item_actions.trash=ui.icon_button(actions,"trash","Выложить предмет на пол",ui.drop_selected)
 ui.label(side,"Экипировать · Использовать · Лечить · Выложить",14)
 ui.item_actions.move=ui.button(side,"ПЕРЕМЕСТИТЬ В ЯЧЕЙКУ",ui.begin_move,330)
 ui.item_actions.split=ui.button(side,"ОТДЕЛИТЬ 1 ПРЕДМЕТ",ui.split_selected,330)
func build_medical(side:VBoxContainer)->void:
 side.add_theme_constant_override("separation",8)
 ui.medical_heading=ui.label(side,"",24);ui.medical_heading.name="MedicalSelection"
 ui.medical_readings=ui.label(side,"",19);ui.medical_readings.name="MedicalReadings";ui.medical_readings.custom_minimum_size.y=70
 var zones=GridContainer.new();zones.columns=3;zones.add_theme_constant_override("h_separation",6);zones.add_theme_constant_override("v_separation",6);side.add_child(zones)
 for zone in State.ZONES:
  var target:String=zone
  var zone_button=ui.button(zones,zone,func():ui.select_zone(target),130);zone_button.toggle_mode=true;zone_button.custom_minimum_size.y=46;zone_button.name="MedicalZone"+str(State.ZONES.find(zone));ui.medical_zones[zone]=zone_button
 ui.label(side,"ДОСТУПНОЕ ЛЕЧЕНИЕ",14)
 for entry in [["band","ПЕРЕВЯЗАТЬ"],["medkit","ОБРАБОТАТЬ"],["morph","ОБЕЗБОЛИТЬ"]]:
  var medicine:String=entry[0]
  var action=ui.button(side,entry[1],func():ui.treat_selected(medicine),330);action.custom_minimum_size.y=62;action.name="Treat_"+medicine;action.set_meta("caption",entry[1]);ui.medical_actions[medicine]=action
func build_loot(side:VBoxContainer)->void:
 ui.label(side,str(loot.title),23)
 ui.label(side,"КОНТЕЙНЕР / НАЙДЕННЫЕ ПРЕДМЕТЫ",14)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y=320;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;side.add_child(scroll)
 var entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries.add_theme_constant_override("separation",10);scroll.add_child(entries)
 var list:Array=ui.world.state.data.containers.get(loot.id,[])
 if list.is_empty():ui.label(entries,"БОЛЬШЕ ПРЕДМЕТОВ\nНЕ ОБНАРУЖЕНО",19)
 for i in range(list.size()):
  var index:int=i;var item:Dictionary=list[i]
  var b=ui.button(entries,State.ITEMS[item.id].name+" × "+str(item.count)+"\nСОСТОЯНИЕ "+str(item.get("condition",100))+"%",func():ui.transfer(loot,index),340)
  b.icon=ui.icon_for(item.id);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",66);b.custom_minimum_size.y=96
 var take=ui.button(side,"ВЗЯТЬ ВСЁ",func():ui.take_all(loot),340);take.name="LootTakeAll";take.custom_minimum_size.y=64;take.disabled=list.is_empty()
func show_right(id:String)->void:
 for pane in panes.values():pane.hide()
 panes[id].show()
 ui._layout_hud()
 for key in tabs:tabs[key].button_pressed=key==id
 if id=="medical":ui.refresh_medical()
func refresh_summary()->void:
 if not is_instance_valid(summary):return
 var data:Dictionary=ui.world.state.data
 summary.text="ЗДОРОВЬЕ %d%%  /  ВОДА %d%%  /  ПИТАНИЕ %d%%" % [roundi(data.health),roundi(data.water),roundi(data.food)]
 var occupied:int=0
 for i in 18:
  if data.slots.has("bag"+str(i)):occupied+=1
 bag_heading.text="ИНВЕНТАРЬ        %d / 18 ЯЧЕЕК" % occupied
