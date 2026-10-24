shader_type canvas_item;
uniform sampler2D next_step : source_color, filter_linear;
uniform sampler2D turn_from : source_color, filter_linear;
uniform sampler2D turn_from_next : source_color, filter_linear;
uniform float walk_mix = 0.0;
uniform float turn_mix = 1.0;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
 vec4 a=mix(texture(TEXTURE,UV),texture(next_step,UV),walk_mix);
 vec4 old=mix(texture(turn_from,UV),texture(turn_from_next,UV),walk_mix);
 COLOR=mix(old,a,turn_mix)*tint;
}
