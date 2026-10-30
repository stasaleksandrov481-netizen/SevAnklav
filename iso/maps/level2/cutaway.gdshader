shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://iso/maps/level2/visibility.gdshaderinc"
uniform sampler2D concrete : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.64,0.70,0.72);
uniform bool textured = true;
uniform bool floor_surface = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float visible=bunker_visibility(world_position);
 if(visible<0.005){discard;}
 vec3 color=tint;
 if(textured){
  vec3 p=(world_position-origin)*vec3(0.22,0.36,0.22);
  vec3 w=pow(abs(world_normal),vec3(8.0));w/=max(w.x+w.y+w.z,0.001);
  color*=texture(concrete,p.zy).rgb*w.x+texture(concrete,p.xz).rgb*w.y+texture(concrete,p.xy).rgb*w.z;
 }
 ALBEDO=color*visible;EMISSION=color*visible*(floor_surface ? 0.075 : 0.025);
 ROUGHNESS=0.94;METALLIC=0.0;
}
