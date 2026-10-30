shader_type spatial;
render_mode specular_disabled;
#include "res://iso/maps/level2/visibility.gdshaderinc"
uniform vec4 color : source_color = vec4(0.5,0.6,0.6,1.0);
uniform sampler2D surface_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int surface_tile = -1;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz-origin;}
void fragment(){
 float visible=bunker_visibility(world_position);
 if(visible<0.005){discard;}
 vec3 surface=color.rgb;
 if(surface_tile>=0){
  vec2 tile=vec2(float(surface_tile%2),floor(float(surface_tile)/2.0));
  surface*=texture(surface_atlas,tile*0.5+vec2(0.008)+clamp(UV,vec2(0.0),vec2(1.0))*0.484).rgb;
 }
 ALBEDO=surface*visible;EMISSION=surface*visible*.025;ROUGHNESS=0.85;
}
