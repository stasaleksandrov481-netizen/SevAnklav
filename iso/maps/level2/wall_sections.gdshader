shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, specular_disabled;
#include "res://iso/maps/level2/visibility.gdshaderinc"
uniform sampler2D concrete : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_states : filter_nearest, repeat_disable;
uniform sampler2D section_ids : filter_nearest, repeat_disable;
uniform vec3 tint : source_color = vec3(.64,.70,.72);
uniform bool textured = true;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz-origin;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float visible=bunker_visibility(world_position);
 if(visible<.005){discard;}
 vec2 ids=texture(section_ids,(world_position.xz+vec2(35.0,15.0))/vec2(70.0,30.0)).rg;
 float section=floor(ids.r*255.0+.5)*256.0+floor(ids.g*255.0+.5);
 float faded=texture(wall_states,vec2((section+.5)/512.0,.5)).r;
 vec3 color=tint;
 if(textured){
  vec3 p=world_position*vec3(.22,.36,.22);
  vec3 w=pow(abs(world_normal),vec3(8.0));w/=max(w.x+w.y+w.z,.001);
  color*=texture(concrete,p.zy).rgb*w.x+texture(concrete,p.xz).rgb*w.y+texture(concrete,p.xy).rgb*w.z;
 }
 float upper=smoothstep(.28,.58,world_position.y);
 ALBEDO=color*visible;EMISSION=color*visible*.035;ROUGHNESS=.94;
 ALPHA=mix(1.0,.22,faded*upper);
}
