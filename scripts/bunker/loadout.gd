extends RefCounted
var b
func gear_owned() -> bool:
    return b._obj_done("gear") or G.zsave.get("bunker3",{}).get("done",[]).has("gear")
func ensure() -> void:
    var owned: Array=[]
    var aliases: Dictionary={"pm":"pistol","makarov":"pistol","weapon:pistol":"pistol"}
    for entry in G.zsave.get("weapons",[]):
        var id: String=str(aliases.get(str(entry),str(entry)))
        if G.ZWEAPONS.has(id) and not owned.has(id): owned.append(id)
    var bag: Dictionary=G.zsave.get("inv",{})
    for key in bag.keys():
        var id: String=str(aliases.get(str(key),str(key).trim_prefix("weapon:")))
        if G.ZWEAPONS.has(id):
            if int(bag[key])>0 and not owned.has(id): owned.append(id)
            bag.erase(key)
    G.zsave["weapons"]=owned
    G.zsave["inv"]=bag
    if not (G.zsave.get("hands7") is Array) or G.zsave["hands7"].size()!=2:
        G.zsave["hands7"]=["",""]
        if gear_owned(): defaults()
    if not (G.zsave.get("quick") is Array) or G.zsave["quick"].size()!=6: G.zsave["quick"]=["","","","","",""]
    var used: Dictionary={}
    var hands: Array=G.zsave["hands7"]
    for i in range(2):
        var item:=str(hands[i])
        if item=="": continue
        if two_handed(item) and hands[0]==hands[1] and total(item)>0: continue
        if int(used.get(item,0))>=total(item): hands[i]=""
        else: used[item]=int(used.get(item,0))+1
    for i in range(6):
        if total(str(G.zsave["quick"][i]))<=0: G.zsave["quick"][i]=""
func defaults() -> void:
    var weapon: String="weapon:"+str(G.zsave.get("cur_weapon","pistol"))
    G.zsave["hands7"]=[weapon,weapon] if two_handed(weapon) else ["flashlight",weapon]
    G.zsave["equipment_ready7"]=true
func total(item: String) -> int:
    if item=="": return 0
    if item=="flashlight": return 1 if gear_owned() else 0
    if item.begins_with("weapon:"):
        return 1 if gear_owned() and G.zsave.get("weapons",[]).has(item.trim_prefix("weapon:")) else 0
    return int(G.zsave.get("inv",{}).get(item,0))
func two_handed(item: String) -> bool: return item in ["weapon:smg","weapon:shotgun","weapon:rifle"]
func hands() -> Array: return G.zsave.get("hands7",["",""])
func hand_of(item: String) -> int: return hands().find(item)
func in_bag(item: String) -> int:
    var reserved:=0
    for held in hands():
        if held==item: reserved+=1
    if two_handed(item) and reserved==2: reserved=1
    return maxi(0,total(item)-reserved)
func equip(item: String, target: int=-1) -> bool:
    ensure()
    if total(item)<=0: return false
    var held: Array=hands()
    if target<0:
        target=0 if two_handed(item) else held.find("")
        if target<0:
            b._inventory_message7("Обе руки заняты. Уберите предмет нажатием на слот руки.")
            return false
    if target>1: return false
    if in_bag(item)<=0 and not held.has(item): return false
    # Moving an existing unique tool to the other hand never creates another copy.
    if total(item)==1:
        for i in range(2):
            if held[i]==item: held[i]=""
    for current in held.duplicate():
        if two_handed(str(current)):
            held[0]="";held[1]=""
            break
    if two_handed(item): held[0]=item;held[1]=item
    else: held[target]=item
    b._med_sel_item=item if G.ZITEMS.has(item) else ""
    changed()
    return true
func put_away(index: int) -> void:
    ensure()
    if index<0 or index>1: return
    var held: Array=hands()
    var item:=str(held[index])
    if two_handed(item): held[0]="";held[1]=""
    else: held[index]=""
    changed()
func weapon() -> String:
    for i in [1,0]:
        var item:=str(hands()[i])
        if item.begins_with("weapon:"): return item.trim_prefix("weapon:")
    return ""
func all_items() -> Array:
    var items: Array=[]
    for item in G.zsave.get("inv",{}):
        if in_bag(item)>0: items.append(str(item))
    if in_bag("flashlight")>0: items.append("flashlight")
    for weapon_id in G.zsave.get("weapons",[]):
        var id: String="weapon:"+str(weapon_id)
        if in_bag(id)>0 and not items.has(id): items.append(id)
    return items
func slots() -> Array:
    ensure()
    var available:=all_items()
    var grid: Array=G.zsave.get("slots7",G.zsave.get("inv_slots",[])).duplicate()
    var seen: Array=[]
    for i in range(grid.size()):
        if not available.has(grid[i]) or seen.has(grid[i]): grid[i]=""
        elif grid[i]!="": seen.append(grid[i])
    while grid.size()<24: grid.append("")
    for item in available:
        if seen.has(item): continue
        var index:=grid.find("")
        if index<0: grid.append(item)
        else: grid[index]=item
        seen.append(item)
    while grid.size()%6!=0: grid.append("")
    G.zsave["slots7"]=grid
    return grid
func assign_quick(index: int, item: String) -> void:
    ensure()
    if index<0 or index>=6 or total(item)<=0: return
    G.zsave["quick"][index]=item
    changed()
func move_bag(from: int, to: int) -> void:
    var grid:=slots()
    if mini(from,to)<0 or maxi(from,to)>=grid.size(): return
    var temp=grid[from];grid[from]=grid[to];grid[to]=temp
    G.zsave["slots7"]=grid
    changed()
func changed() -> void:
    ensure()
    var active:=weapon()
    if active!="" and not b.player.is_empty() and b.player["weapon"]!=active:
        var mags: Dictionary=G.zsave.get("weapon_mags7",{})
        mags[str(b.player["weapon"])]=int(b.player["mag"])
        b.player["weapon"]=active
        b.player["mag"]=int(mags.get(active,1 if active=="knife" else 0))
        b.player["reload_t"]=0.0
        G.zsave["weapon_mags7"]=mags;G.zsave["cur_weapon"]=active
    b._inventory_changed7()
    G.write_save()
func name_of(item: String) -> String:
    if item=="flashlight": return "ФОНАРЬ"
    if item.begins_with("weapon:"): return str(G.Z_WEAPON_NAMES.get(item.trim_prefix("weapon:"),item))
    if G.ZITEMS.has(item): return str(G.ZITEMS[item]["name"])
    if G.ZLOOT.has(item): return str(G.ZLOOT[item]["name"])
    return item.to_upper()
func icon_of(item: String) -> Texture2D:
    if item=="flashlight": return preload("res://scripts/ui/equipment_icons.gd").get_icon("flashlight")
    if item.begins_with("weapon:"):
        var id:=item.trim_prefix("weapon:")
        var thumbnail: Texture2D=preload("res://scripts/ui/equipment_icons.gd").get_icon(id if id in ["pistol","knife"] else "rifle")
        if thumbnail!=null: return thumbnail
        for path in ["res://assets/sprites/z_w_"+id+".png","res://assets/sprites/z_"+id+".png"]:
            if ResourceLoader.exists(path): return load(path)
        return ZUI.icon("ammo")
    return ZMedUI.item_icon(item)
