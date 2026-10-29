shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D concrete : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.64,0.70,0.72);
uniform bool textured = true;
uniform bool floor_surface = false;
uniform sampler2D room_ids : filter_nearest, repeat_disable;
uniform float active_room = 1.0;
uniform float reveal = 1.0;
uniform vec3 origin;
uniform vec3 player_position;
uniform vec3 camera_position;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float room_visibility(){
 vec2 uv=(world_position.xz-origin.xz+vec2(35.0,15.0))/vec2(70.0,30.0);
 float id=floor(texture(room_ids,uv).r*255.0+0.5);
 return 1.0-step(0.4,abs(id-active_room));
}
void fragment(){
 float visible=room_visibility();
 if(!floor_surface){
  vec2 uv=(world_position.xz-origin.xz+vec2(35.0,15.0))/vec2(70.0,30.0);
  vec2 offsets[4]={vec2(.35/70.0,0),vec2(-.35/70.0,0),vec2(0,.35/30.0),vec2(0,-.35/30.0)};
  for(int i=0;i<4;i++){
   float id=floor(texture(room_ids,uv+offsets[i]).r*255.0+0.5);
   visible=max(visible,1.0-step(0.4,abs(id-active_room)));
  }
 }
 if(!floor_surface){
  vec3 target=player_position+vec3(0.0,0.55,0.0);
  vec3 ray=normalize(camera_position-target);
  vec3 delta=world_position-target;
  float along=dot(delta,ray);
  float radius=length(delta-ray*along);
  float cut=(1.0-smoothstep(1.25,2.05,radius))*smoothstep(0.25,0.75,along)*(1.0-step(9.0,along))*step(0.42,world_position.y);
  float noise=fract(sin(dot(floor((world_position-origin)*50.0),vec3(12.9898,78.233,37.719)))*43758.5453);
  if(cut>noise){discard;}
 }
 vec3 color=tint;
 if(textured){
  vec3 p=(world_position-origin)*vec3(0.22,0.36,0.22);
  vec3 w=pow(abs(world_normal),vec3(8.0));w/=max(w.x+w.y+w.z,0.001);
  color*=texture(concrete,p.zy).rgb*w.x+texture(concrete,p.xz).rgb*w.y+texture(concrete,p.xy).rgb*w.z;
 }
 ALBEDO=color*visible*reveal;ROUGHNESS=0.94;METALLIC=0.0;
}
