extends Node2D
var b
var clock:=0.0
var tick:=0.0
var devices: Array=[]
func _ready() -> void:
    z_index=16
    var mat:=CanvasItemMaterial.new();mat.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=mat
    for prop in b.props:
        if prop.has("style10"): devices.append(prop)
func _process(delta: float) -> void:
    clock+=delta;tick-=delta
    if tick<=0: tick=.12;queue_redraw()
func _draw() -> void:
    if b==null: return
    var center: Vector2=b.camera.get_screen_center_position()
    var view: Vector2=b.get_viewport_rect().size/b.camera.zoom
    var bounds:=Rect2(center-view*.5,view).grow(90)
    for prop in devices:
        if not bounds.has_point(prop.spr.position): continue
        var style:=str(prop.style10)
        var colour: Color=Color(.5,.74,.78,.60)
        if style in ["power","emergency"]: colour=Color(.81,.56,.3,.56)
        elif style=="security": colour=Color(.61,.7,.52,.5)
        elif style=="medical": colour=Color(.6,.78,.75,.60)
        if prop.get("id10","")=="restore10" and not b.records.has("power"): colour=Color(.58,.34,.22,.35)
        var p: Vector2=prop.spr.position+Vector2(-8,-5).rotated(prop.spr.rotation)
        if style in ["paper","carrier"]:
            if b.investigation10.state.found.has(prop.get("id10","")): continue
            draw_circle(p+Vector2(8,-9),1.5,Color(.72,.84,.88,.45+.12*sin(clock)))
        else:
            draw_line(p,p+Vector2(8,0).rotated(prop.spr.rotation),colour,1.3,true)
            if b.records.has("power") and style in ["server","power","research"]: draw_circle(p+Vector2(11,2),1,Color(.48,.68,.58,.6))
    if b.investigation10.state.events.has("shutter"):
        # A protective screen only covers the already sealed observation glass.
        draw_rect(Rect2(1752,376,536,10),Color(.24,.33,.38,.8))
        for i in range(1760,2280,32): draw_line(Vector2(i,376),Vector2(i,386),Color(.11,.19,.24,.7),2)
