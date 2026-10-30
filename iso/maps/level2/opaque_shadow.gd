extends RefCounted
# The camera may cut an object away visually. Its physical shadow stays whole.
# Mesh data is shared, and the original stops casting: no extra shadow geometry.
static var material:StandardMaterial3D
static func attach(source:MeshInstance3D,contact_height:float=0.0)->void:
 if source.mesh==null:return
 if source.get_node_or_null("OpaqueShadow")!=null:return
 if material==null:
  material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 source.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var shadow=MeshInstance3D.new();shadow.name="OpaqueShadow";shadow.mesh=source.mesh
 shadow.material_override=material;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
 # In the roofless bunker, a full-height invisible wall otherwise throws a
 # black curtain across the entire interior. Keep its floor contact shadow;
 # furniture and the character retain their complete shadows.
 if contact_height>0.0:
  var height=source.mesh.get_aabb().end.y
  if height>contact_height:shadow.scale.y=contact_height/height
 shadow.layers=source.layers;source.add_child(shadow)
