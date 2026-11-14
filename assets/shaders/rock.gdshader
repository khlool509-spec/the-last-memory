shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// صخور بإسقاط ثلاثي المحاور. المجسّمات مولَّدة بلا إحداثيات خامة
// صالحة، والصخرة سطح من كل اتجاه — فالإسقاط المستوي يمطّ الخامة
// على نصفها. بالإسقاط الثلاثي يبقى المقياس واحداً على كل وجه،
// وهو ما يجعل الصخرة تُقرأ حجراً لا كتلة ملوّنة.

uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 2.6;
uniform float tri_sharp : hint_range(1.0, 16.0) = 4.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.9;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.7;
uniform float rough_lo : hint_range(0.0, 1.0) = 0.58;
uniform float rough_hi : hint_range(0.0, 1.0) = 0.98;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 v_world;
varying vec3 v_wnorm;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tw_of(vec3 n) {
	vec3 w = pow(abs(n), vec3(tri_sharp));
	return w / max(w.x + w.y + w.z, 0.0001);
}

vec3 tri(sampler2D t, vec3 p, vec3 w, float s) {
	return texture(t, p.zy / s).rgb * w.x
		+ texture(t, p.xz / s).rgb * w.y
		+ texture(t, p.xy / s).rgb * w.z;
}

void fragment() {
	vec3 gn = normalize(v_wnorm);
	vec3 w = tw_of(gn);
	vec3 p = v_world;

	vec3 alb = tri(rock_diff, p, w, tex_scale);
	vec3 arm = tri(rock_arm, p, w, tex_scale);

	vec3 nx = texture(rock_norm, p.zy / tex_scale).rgb * 2.0 - 1.0;
	vec3 ny = texture(rock_norm, p.xz / tex_scale).rgb * 2.0 - 1.0;
	vec3 nz = texture(rock_norm, p.xy / tex_scale).rgb * 2.0 - 1.0;
	vec3 bump = vec3(0.0, nx.y, nx.x) * w.x
		+ vec3(ny.x, 0.0, ny.y) * w.y
		+ vec3(nz.x, nz.y, 0.0) * w.z;
	vec3 n = normalize(gn + bump * normal_strength);

	// لون النسخة يبقى مؤثّراً خفيفاً فلا تتطابق كل الصخور
	vec3 vc = mix(vec3(1.0), COLOR.rgb * 1.15, 0.45);

	ALBEDO = alb * tint * vc;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(rough_lo, rough_hi, arm.g);
	AO = mix(1.0, arm.r, ao_strength);
	AO_LIGHT_AFFECT = 0.55;
	METALLIC = 0.0;
	SPECULAR = 0.16;
}
