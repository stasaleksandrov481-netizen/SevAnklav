extends RefCounted
const ATLAS=preload("res://assets/ui/v7/equipment_atlas.png")
const REGIONS={"pistol": [81, 165, 470, 359], "flashlight": [697, 126, 492, 420], "rifle": [24, 843, 603, 224], "knife": [627, 694, 586, 478]}
static var cache: Dictionary={}
static func get_icon(id: String) -> Texture2D:
    if id=="pistol": return preload("res://assets/bunker/v8/pm_icon.svg")
    if not REGIONS.has(id): return null
    if cache.has(id): return cache[id]
    var p: Array=REGIONS[id]
    var t:=AtlasTexture.new();t.atlas=ATLAS;t.region=Rect2(p[0],p[1],p[2],p[3]);cache[id]=t
    return t
