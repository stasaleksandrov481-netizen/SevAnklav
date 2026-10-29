extends "res://iso/capsule.gd"
func _rebuild() -> void:
 var generated=Node3D.new();generated.name="Generated";add_child(generated)
 var steel=_mat(Color("#536a77"),0.55);var dark=_mat(Color("#182c35"),0.2);var padding=_mat(Color("#7e9295"));var glass=_mat(Color(.25,.5,.6,.22),0.1,true)
 _box(generated,"Base",Vector3(2.3,.38,1.22),Vector3(0,.35,0),dark)
 _box(generated,"Mattress",Vector3(1.9,.12,.82),Vector3(0,.76,0),padding)
 for x in [-1.03,1.03]:
  var rib=MeshInstance3D.new();var ring=TorusMesh.new();ring.inner_radius=.48;ring.outer_radius=.57;ring.rings=20;ring.ring_segments=8;rib.mesh=ring;rib.rotation.z=PI/2;rib.position=Vector3(x,1.03,0);rib.material_override=steel;generated.add_child(rib)
  _box(generated,"Foot",Vector3(.24,.2,1.38),Vector3(x,.10,0),steel)
 for z in [-.49,.49]:_box(generated,"Support rail",Vector3(2.2,.1,.08),Vector3(0,.68,z),steel)
 var lid=MeshInstance3D.new();lid.name="Glass shell";var shell=SphereMesh.new();shell.radius=1;shell.height=2;shell.radial_segments=20;shell.rings=10;lid.mesh=shell;lid.scale=Vector3(.98,.46,.52);lid.position=Vector3(0,1.12,0);lid.material_override=glass;generated.add_child(lid)
 _box(generated,"Control housing",Vector3(.42,.24,.12),Vector3(.7,.74,.65),steel)
 _box(generated,"Status screen",Vector3(.3,.1,.012),Vector3(.7,.78,.717),_mat(Color("#669daa")))
 var plate=Label3D.new();plate.text="V-17";plate.font_size=64;plate.pixel_size=.002;plate.position=Vector3(-.45,.44,.617);plate.modulate=Color("#aebdc1");generated.add_child(plate)
 var body=StaticBody3D.new();generated.add_child(body);var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2.3,.95,1.22);shape.shape=box;shape.position.y=.5;body.add_child(shape)
