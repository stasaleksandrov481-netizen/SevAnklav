shader_type spatial;
render_mode specular_disabled;
uniform vec4 color : source_color = vec4(0.5,0.6,0.6,1.0);
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
 vec3 target=player_position+vec3(0,0.6,0);
 vec3 ray=normalize(camera_position-target);vec3 delta=world_position-target;
 float along=dot(delta,ray);float radius=length(delta-ray*along);
 float cut=(1.0-smoothstep(.65,1.15,radius))*smoothstep(.3,.8,along)*(1.0-step(5.0,along))*smoothstep(1.45,1.8,world_position.y);
 float noise=fract(sin(dot(floor((world_position-origin)*50.0),vec3(12.9898,78.233,37.719)))*43758.5453);
 if(cut>noise){discard;}
 ALBEDO=color.rgb*reveal;ROUGHNESS=0.85;
}
