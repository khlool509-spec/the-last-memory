shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ماء نهر: لونه يتبع عمقه، وشفافيته تخفت عند الضفة فلا يظهر حدّ
// مقصوص، وموجتان متحركتان بسرعتين مختلفتين تمنعان نمطاً واحداً
// زاحفاً، وانعكاس فرنل يجعل البعيد مرآة والقريب شفافاً.

uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_depth : hint_depth_texture, filter_linear;

uniform vec3 shallow_color : source_color = vec3(0.36, 0.49, 0.43);
uniform vec3 deep_color : source_color = vec3(0.07, 0.16, 0.19);
uniform float depth_fade = 2.6;        // أمتار حتى اللون العميق
uniform float shore_fade = 1.60;       // أمتار يذوب فيها الحدّ
uniform float flow_speed = 0.22;       // تدفّق مع مجرى النهر (محور V)
uniform float ripple_scale = 2.4;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.42;
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.2;
uniform float roughness_near : hint_range(0.0, 1.0) = 0.16;
uniform float roughness_far : hint_range(0.0, 1.0) = 0.03;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// موجتان: إحداهما تزحف مع التيار والأخرى تعاكسه قليلاً وبمقياس آخر
	vec2 uv1 = UV * ripple_scale + vec2(0.0, -TIME * flow_speed);
	vec2 uv2 = UV * ripple_scale * 1.73 + vec2(TIME * flow_speed * 0.31,
		-TIME * flow_speed * 0.62);
	vec3 n1 = texture(ripple_tex, uv1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(ripple_tex, uv2).rgb * 2.0 - 1.0;
	vec3 nrm = normalize(mix(n1, n2, 0.5));

	// عمق الماء من فرق العمق بين القاع والسطح
	float scene_z = texture(screen_depth, SCREEN_UV).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_z, 1.0);
	world_pos.xyz /= world_pos.w;
	float bottom = -world_pos.z;
	float here = -VERTEX.z;
	float water_depth = max(bottom - here, 0.0);

	float dt = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, dt);

	// فرنل: السطح البعيد يعكس السماء، والقريب يُرى من خلاله
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), fresnel_power);

	ALBEDO = col;
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ripple_strength;
	ROUGHNESS = mix(roughness_near, roughness_far, fres);
	METALLIC = 0.0;
	SPECULAR = 0.65;
	// الحدّ عند الضفة يذوب بدل أن يُقصّ، والعميق يصير معتماً
	float shore = smoothstep(0.0, shore_fade, water_depth);
	ALPHA = shore * mix(0.70, 0.96, clamp(dt + fres * 0.5, 0.0, 1.0));
}
