shader_type canvas_item;
uniform sampler2D clean_sky : source_color;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
    vec2 uv=UV;
    // Keep title and button pixels immobile. Animate only the coat and sky outside the logo.
    float coat=(1.0-smoothstep(0.22,0.27,uv.x))*smoothstep(0.49,0.67,uv.y);
    float hem=smoothstep(0.54,0.98,uv.y);
    uv.x+=coat*hem*(sin(TIME*1.45+uv.y*24.0)*0.0017+sin(TIME*0.61+uv.y*13.0)*0.0009);
    float sky_warp=(1.0-smoothstep(0.32,0.43,UV.y))*(1.0-smoothstep(0.29,0.33,UV.x));
    uv.x+=sky_warp*sin(TIME*0.016)*0.003;
    vec4 c=texture(TEXTURE,uv);
    vec2 box=abs(UV-vec2(0.136,0.366))/vec2(0.062,0.058);
    float cleanup=1.0-smoothstep(0.82,1.0,max(box.x,box.y));
    c=mix(c,texture(clean_sky,uv),cleanup);
    float sky=(1.0-smoothstep(0.35,0.48,UV.y))*(1.0-smoothstep(0.32,0.36,UV.x));
    float cloud=noise(UV*vec2(8.0,7.0)+vec2(TIME*0.004,0.0));
    c.rgb+=sky*(cloud-0.5)*0.035;
    float mist=exp(-pow((UV.y-0.72)/0.11,2.0))*(1.0-smoothstep(0.37,0.41,UV.x));
    c.rgb+=vec3(0.13,0.18,0.21)*mist*noise(UV*vec2(14.0,6.0)-vec2(TIME*0.015,0.0))*0.17;
    float lamp=exp(-length((UV-vec2(0.765,0.34))*vec2(32.0,45.0)));
    c.rgb+=vec3(0.22,0.015,0.005)*lamp*(0.5+0.5*sin(TIME*2.0));
    float beacon=exp(-length((UV-vec2(0.313,0.305))*vec2(170.0,200.0)));
    c.rgb+=vec3(0.45,0.018,0.004)*beacon*(0.5+0.5*sin(TIME*2.2));
    float breath=exp(-length((UV-vec2(0.68,0.77))*vec2(16.0,55.0)));
    c.rgb+=vec3(0.24,0.34,0.38)*breath*noise(UV*19.0-vec2(TIME*0.03,0.0))*0.16;
    COLOR=c;
}
