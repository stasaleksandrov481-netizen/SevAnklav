shader_type canvas_item;
render_mode unshaded;
uniform vec2 observer;
uniform vec2 facing = vec2(1.0,0.0);
varying vec2 world;
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment(){
 vec2 d=world-observer;
 float peripheral=1.0-smoothstep(-0.4,0.45,dot(normalize(d+vec2(0.001)),facing));
 float near_fade=smoothstep(55.0,150.0,length(d));
 COLOR=vec4(0.005,0.012,0.02,peripheral*near_fade*0.14);
}
