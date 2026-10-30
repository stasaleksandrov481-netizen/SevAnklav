extends SceneTree
func _initialize():call_deferred("run")
func run():
 var sections=JSON.parse_string(FileAccess.get_file_as_string("res://iso/maps/level2/wall_sections.json")).sections
 for name in ["WallMesh","SkirtMesh","CapMesh"]:
  var original=load("res://iso/maps/level2/"+name+".obj")
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for surface in original.get_surface_count():
   var arrays=original.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var order:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   for first in range(0,order.size() if not order.is_empty() else vertices.size(),3):
    var indices=[];var center=Vector3.ZERO
    for i in 3:
     var index:int=order[first+i] if not order.is_empty() else first+i
     indices.append(index);center+=vertices[index]/3
    var nearest=0;var distance=INF
    for i in sections.size():
     var spec=sections[i];var a=Vector2(spec.a[0],spec.a[1]);var b=Vector2(spec.b[0],spec.b[1])
     var d=Geometry2D.get_closest_point_to_segment(Vector2(center.x,center.z),a,b).distance_squared_to(Vector2(center.x,center.z))
     if d<distance:distance=d;nearest=i
    for index in indices:
     var code=nearest+1
     st.set_color(Color(float(code/256)/255.0,float(code%256)/255.0,0));st.set_normal(normals[index]);st.add_vertex(vertices[index])
  st.index();var result=st.commit()
  var path="res://iso/maps/level2/"+name+"Sections.res"
  assert(ResourceSaver.save(result,path)==OK);print("BAKED ",path," triangles=",result.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3)
 quit()
