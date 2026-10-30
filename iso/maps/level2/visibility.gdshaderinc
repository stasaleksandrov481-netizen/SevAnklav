uniform sampler2D room_ids : filter_nearest, repeat_disable;
uniform sampler2D known_rooms : filter_nearest, repeat_disable;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec3 origin;
uniform float boundary_padding = 0.16;
float bunker_visibility(vec3 point){
 vec2 uv=(point.xz-origin.xz+vec2(35.0,15.0))/vec2(70.0,30.0);
 vec4 sight=texture(visibility_map,uv);
 float known=0.0;
 vec2 offsets[5]={vec2(0.0),vec2(boundary_padding/70.0,0),vec2(-boundary_padding/70.0,0),vec2(0,boundary_padding/30.0),vec2(0,-boundary_padding/30.0)};
 for(int i=0;i<5;i++){
  float id=floor(texture(room_ids,uv+offsets[i]).r*255.0+0.5);
  known=max(known,texture(known_rooms,vec2((id+.5)/64.0,.5)).r);
 }
 return max(known,max(sight.r,sight.g));
}
