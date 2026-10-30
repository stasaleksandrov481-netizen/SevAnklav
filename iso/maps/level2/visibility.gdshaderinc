uniform sampler2D room_ids : filter_nearest, repeat_disable;
uniform sampler2D known_rooms : filter_nearest, repeat_disable;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec3 origin;
uniform float boundary_padding = 0.16;
float known_at(vec2 uv){
 float id=floor(texture(room_ids,uv).r*255.0+0.5);
 return texture(known_rooms,vec2((id+.5)/64.0,.5)).r;
}
// Coordinates are made local in the vertex stage, before interpolation.
// Mobile fragment precision must not subtract world coordinates around 3500 m.
float bunker_visibility(vec3 point){
 vec2 uv=(point.xz+vec2(35.0,15.0))/vec2(70.0,30.0);
 vec4 sight=texture(visibility_map,uv);
 vec2 dx=vec2(boundary_padding/70.0,0.0);vec2 dz=vec2(0.0,boundary_padding/30.0);
 float known=max(known_at(uv),max(max(known_at(uv+dx),known_at(uv-dx)),max(known_at(uv+dz),known_at(uv-dz))));
 return max(known,max(sight.r,sight.g));
}
