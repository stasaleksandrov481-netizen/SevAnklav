extends RefCounted
# Static shapes join existing room/material batches: no per-crate scripts/lights.
const PAINT=Color("#b7c2b7")
const LABEL=Color("#c5c2a8")
static func surface_box(f,p,size:Vector3,at:Vector3,tile:int)->void:
 var mesh=BoxMesh.new();mesh.size=size;f.part(p,mesh,at,PAINT,Vector3.ZERO,tile)
static func bevel_mesh(size:Vector3,edge:float)->ArrayMesh:
 var x=size.x*.5;var z=size.z*.5
 var outline=[Vector2(-x+edge,-z),Vector2(x-edge,-z),Vector2(x,-z+edge),Vector2(x,z-edge),Vector2(x-edge,z),Vector2(-x+edge,z),Vector2(-x,z-edge),Vector2(-x,-z+edge)]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 8:
  var a:Vector2=outline[i];var b:Vector2=outline[(i+1)%8]
  var low_a=Vector3(a.x,-size.y*.5,a.y);var low_b=Vector3(b.x,-size.y*.5,b.y)
  var high_a=low_a+Vector3.UP*size.y;var high_b=low_b+Vector3.UP*size.y
  var normal=Vector3(b.y-a.y,0,a.x-b.x).normalized()
  var vertices=[low_a,high_a,high_b,low_a,high_b,low_b]
  var uvs=[Vector2(0,1),Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2.ONE]
  # Godot uses clockwise front faces; normals stay pointed outwards.
  for k in [0,2,1,3,5,4]:
   st.set_normal(normal);st.set_uv(uvs[k]);st.add_vertex(vertices[k])
  for top in [false,true]:
   var y=size.y*.5*(1 if top else -1)
   var face=[Vector3(0,y,0),Vector3(a.x,y,a.y),Vector3(b.x,y,b.y)] if top else [Vector3(0,y,0),Vector3(b.x,y,b.y),Vector3(a.x,y,a.y)]
   for vertex in face:
    st.set_normal(Vector3.UP if top else Vector3.DOWN);st.set_uv(Vector2(vertex.x/size.x+.5,vertex.z/size.z+.5));st.add_vertex(vertex)
 return st.commit()
static func case_body(f,p,size:Vector3,at:Vector3,tile:int)->void:
 f.part(p,bevel_mesh(size,.055),at,PAINT,Vector3.ZERO,tile)
static func label(f,p,at:Vector3,width:float)->void:
 f.box(p,Vector3(width,.085,.008),at,LABEL)
 for i in 3:f.box(p,Vector3(width*.64,.009,.009),at+Vector3(-width*.08,.023-i*.024,.005),f.DARK)
static func build(f,p,style:String)->void:
 if style not in ["timber","steel","canvas","toolcase"]:style="timber"
 p.set_meta("storage_style",style)
 var size=Vector3(.82,.66,.58)
 match style:
  "timber":
   surface_box(f,p,Vector3(.78,.54,.54),Vector3(0,.31,0),0)
   surface_box(f,p,Vector3(.82,.06,.58),Vector3(0,.61,0),0)
   for x in [-.28,.28]:
    for z in [-.285,.285]:f.box(p,Vector3(.042,.59,.025),Vector3(x,.32,z),f.STEEL)
    f.box(p,Vector3(.042,.023,.59),Vector3(x,.65,0),f.STEEL)
   for z in [-.286,.286]:
    f.box(p,Vector3(.79,.045,.026),Vector3(0,.10,z),f.DARK)
    f.box(p,Vector3(.20,.045,.027),Vector3(0,.44,z),f.DARK)
   label(f,p,Vector3(.04,.30,.289),.19)
  "steel":
   size=Vector3(.87,.515,.55)
   case_body(f,p,Vector3(.86,.36,.54),Vector3(0,.25,0),1)
   case_body(f,p,Vector3(.87,.085,.55),Vector3(0,.47,0),1)
   f.box(p,Vector3(.75,.018,.017),Vector3(0,.42,.272),f.DARK)
   for x in [-.27,.27]:
    f.box(p,Vector3(.05,.105,.028),Vector3(x,.405,.284),f.STEEL)
    f.box(p,Vector3(.06,.03,.034),Vector3(x,.37,.29),LABEL)
   for x in [-.34,.34]:
    for z in [-.21,.21]:f.box(p,Vector3(.10,.05,.10),Vector3(x,.025,z),f.DARK)
   for z in [-.28,.28]:
    f.tube(p,.018,.22,Vector3(0,.25,z),f.STEEL,Vector3(0,0,PI/2))
    for x in [-.11,.11]:f.box(p,Vector3(.026,.07,.04),Vector3(x,.285,z),f.STEEL)
   label(f,p,Vector3(.15,.22,.28),.16)
  "canvas":
   size=Vector3(.71,.61,.60)
   surface_box(f,p,Vector3(.67,.42,.54),Vector3(0,.25,0),0)
   f.part(p,bevel_mesh(Vector3(.71,.19,.59),.065),Vector3(0,.485,0),Color("#b8b5a2"),Vector3.ZERO,2)
   for x in [-.22,.22]:
    f.box(p,Vector3(.045,.025,.60),Vector3(x,.592,0),f.DARK)
    f.box(p,Vector3(.045,.49,.018),Vector3(x,.34,.30),f.DARK)
    f.box(p,Vector3(.065,.045,.025),Vector3(x,.24,.312),f.STEEL)
   label(f,p,Vector3(0,.30,.28),.20)
  "toolcase":
   size=Vector3(.75,.45,.44)
   case_body(f,p,Vector3(.74,.23,.43),Vector3(0,.155,0),1)
   case_body(f,p,Vector3(.75,.075,.44),Vector3(0,.31,0),1)
   for x in [-.23,0,.23]:f.box(p,Vector3(.032,.024,.35),Vector3(x,.36,0),f.STEEL)
   for x in [-.22,.22]:f.box(p,Vector3(.045,.085,.035),Vector3(x,.27,.23),LABEL)
   for x in [-.11,.11]:f.box(p,Vector3(.025,.055,.025),Vector3(x,.40,0),f.DARK)
   f.tube(p,.018,.23,Vector3(0,.43,0),f.DARK,Vector3(0,0,PI/2))
   label(f,p,Vector3(0,.15,.22),.16)
 p.set_meta("storage_size",size)
 f.collider(p,size)
