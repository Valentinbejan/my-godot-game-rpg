shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.025,0.10,0.13);
uniform vec3 crest_color : source_color = vec3(0.12,0.31,0.32);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	VERTEX.y += sin(world_position.x*2.0+TIME*0.55)*sin(world_position.z*1.7+TIME*0.4)*0.016;
}
void fragment() {
	vec2 p = world_position.xz;
	float ripple = sin(p.x*4.0+sin(p.y*2.2+TIME*0.4)*1.8+TIME*0.6);
	float cross_ripple = sin(p.y*5.2+p.x*1.6-TIME*0.35);
	float caustic = pow(max(0.0,ripple*cross_ripple),7.0);
	ALBEDO = mix(deep_color,crest_color,caustic*0.9+0.12);
	EMISSION = crest_color*caustic*0.22;
	METALLIC = 0.55;
	ROUGHNESS = 0.27;
	NORMAL_MAP = vec3(0.5+cos(p.x*3.0+TIME*0.5)*0.07,0.5+sin(p.y*4.0+TIME*0.4)*0.07,1.0);
}
