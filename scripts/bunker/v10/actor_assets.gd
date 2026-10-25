extends RefCounted
const ATLAS=preload("res://assets/bunker/v10/volkov_modules.png")
const REGIONS={"torso": [0.015783540022547914, 0.08229988726042842, 0.314543404735062, 0.3855693348365276], "head": [0.3810597519729425, 0.05975197294250282, 0.15388951521984218, 0.3788049605411499], "upper": [0.6268320180383314, 0.06877113866967305, 0.12514092446448705, 0.3945885005636979], "lower": [0.8562570462232244, 0.0, 0.09019165727170236, 0.4813979706877114], "thigh": [0.06257046223224352, 0.5219842164599775, 0.15388951521984218, 0.447576099210823], "calf": [0.35174746335963925, 0.5310033821871477, 0.11781285231116122, 0.42841037204058624], "boot": [0.6234498308906427, 0.5287485907553551, 0.09695603156708005, 0.4509582863585118], "hand": [0.8410372040586246, 0.616685456595265, 0.1076662908680947, 0.3314543404735062]}
static func texture(key: String) -> AtlasTexture:
    var uv: Array=REGIONS[key]
    var tex:=AtlasTexture.new();tex.atlas=ATLAS
    tex.region=Rect2(Vector2(uv[0],uv[1])*ATLAS.get_size(),Vector2(uv[2],uv[3])*ATLAS.get_size())
    return tex

static func sleeve() -> AtlasTexture:
    var full:=texture("lower")
    var r:=full.region
    full.region=Rect2(r.position+Vector2(0,r.size.y*.45),Vector2(r.size.x,r.size.y*.55))
    return full
