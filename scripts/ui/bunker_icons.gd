extends RefCounted
const ATLAS=preload("res://assets/ui/bunker/items.png")
const CELLS={"water":0,"food":1,"band":2,"medkit":3,"morph":4,"ammo":5,"uniform":6,"fuse":7,"card":8,"tool":9,"flashlight":10,"pistol":11,"rifle":12}
static var cache:Dictionary={}
static func get_icon(id:String)->Texture2D:
 if not CELLS.has(id):return null
 if not cache.has(id):
  var index:int=CELLS[id];var tile:Vector2=ATLAS.get_size()/4.0
  var image=AtlasTexture.new();image.atlas=ATLAS;image.region=Rect2(Vector2(index%4,index/4)*tile,tile);image.filter_clip=true;cache[id]=image
 return cache[id]
