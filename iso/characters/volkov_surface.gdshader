shader_type spatial;
render_mode specular_disabled;
uniform sampler2D surfaces : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D face_surface : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 head_local;
void vertex(){head_local=VERTEX;}
void fragment(){
 int tile=int(floor(COLOR.a*8.0+.5))-1;
 vec3 color=COLOR.rgb;
 if(tile>=0){
  vec2 offset=vec2(float(tile%2),floor(float(tile)/2.0))*.5;
  vec3 fabric=texture(surfaces,offset+vec2(.008)+clamp(UV,vec2(0),vec2(1))*.484,1.0).rgb;
  color=mix(color,fabric,tile==2 ? .32 : .65);
 }
 if(UV2.x>.5){
  vec2 face_uv=vec2(head_local.x/.25+.5,(.24-head_local.y)/.28);
  vec4 face=texture(face_surface,face_uv);
  float front=smoothstep(.012,.070,head_local.z);
  color=mix(color,face.rgb,front*face.a*.94);
 }
 ALBEDO=color;ROUGHNESS=tile==3 ? .72 : .91;EMISSION=color*(UV2.x>.5 ? .045 : .025);
}
