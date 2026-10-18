shader_type spatial;
uniform vec4 base_color : source_color = vec4(.25,.27,.29,1.0);
uniform float wetness = 0.15;
varying vec3 world_position;
float noise2(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	vec2 k=vec2(127.1,311.7);
	float a=fract(sin(dot(i,k))*43758.5453);
	float b=fract(sin(dot(i+vec2(1,0),k))*43758.5453);
	float c=fract(sin(dot(i+vec2(0,1),k))*43758.5453);
	float d=fract(sin(dot(i+vec2(1,1),k))*43758.5453);
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=world_position.xz;
	float grain=noise2(p*10.0);
	float patches=noise2(p*.55);
	float damp=smoothstep(.58,.80,noise2(p*.14))*wetness;
	ALBEDO=base_color.rgb*(.88+.045*grain+.08*patches-damp*.35);
	ROUGHNESS=clamp(.94-damp*.6,.4,1.0);
	METALLIC=.02;
}
