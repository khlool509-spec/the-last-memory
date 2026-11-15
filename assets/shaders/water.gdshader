shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// نهر متدفّق: الماء يجري فعلاً في اتجاه المجرى، لا بتمرير إحداثيات
// الخامة تمريراً منتظماً.
//
// التقنية: خريطة جريان مخبوزة في ألوان القمم —
//   COLOR.rg = اتجاه التيار الأفقي (حول 0.5)
//   COLOR.b  = السرعة (أعلى في المضائق)
// ومزج ذو طورين: عيّنتان من خريطة النتوء تُزاحان مع التيار بطورين
// متباعدين نصف دورة، ويُمزَج بينهما بوزن مثلثي. بالطور الواحد يُمطّ
// النمط بلا حدّ ويظهر الزحف؛ بالطورين يُعاد تصفيره دورياً فيبقى
// الجريان مستمرّاً بلا مطّ — وهي طريقة خرائط الجريان المعروفة.

uniform float anim_time = -1.0;   // ≥0 يستبدل TIME للالتقاط
uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_depth : hint_depth_texture, filter_linear;
uniform sampler2D screen_color : hint_screen_texture, filter_linear_mipmap;

uniform vec3 shallow_color : source_color = vec3(0.36, 0.49, 0.43);
uniform vec3 deep_color : source_color = vec3(0.07, 0.16, 0.19);
uniform vec3 foam_color : source_color = vec3(0.86, 0.90, 0.90);
uniform float depth_fade = 2.6;
uniform float shore_fade = 1.60;
uniform float flow_speed = 0.55;        // أمتار في الثانية تقريباً
uniform float flow_cycle = 3.2;         // ثوانٍ لدورة إعادة التصفير
uniform float ripple_scale = 1.5;
uniform float ripple_fine = 4.2;        // موجة ثانية أدقّ وأسرع
uniform float ripple_strength : hint_range(0.0, 2.0) = 1.05;
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.2;
uniform float roughness_near : hint_range(0.0, 1.0) = 0.22;
uniform float roughness_far : hint_range(0.0, 1.0) = 0.03;
uniform float foam_shore = 1.15;        // أمتار من عمق الرغوة عند الضفة
uniform float foam_speed = 1.4;
uniform float refraction : hint_range(0.0, 0.2) = 0.035;

varying vec3 v_world;
varying vec4 v_flow;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_flow = COLOR;
}

// عيّنة نتوء مُزاحة مع التيار بطور محدّد
vec3 flow_sample(vec2 uv, vec2 dir, float phase, float scale) {
	return texture(ripple_tex, uv * scale - dir * phase).rgb * 2.0 - 1.0;
}

float t_now() {
	return anim_time >= 0.0 ? anim_time : TIME;
}

void fragment() {
	vec2 dir = (v_flow.rg - 0.5) * 2.0;
	float speed = max(v_flow.b, 0.2);
	// إحداثيات عالمية: النمط يلتصق بالمكان لا بالشبكة
	vec2 uv = v_world.xz / ripple_scale;
	vec2 uvf = v_world.xz / ripple_fine;

	// طوران متباعدان نصف دورة، ووزن مثلثي يخفي لحظة إعادة التصفير
	float t = t_now() / flow_cycle;
	float p0 = fract(t);
	float p1 = fract(t + 0.5);
	float w = abs(1.0 - 2.0 * p0);
	vec2 d = dir * flow_speed * speed * flow_cycle;

	vec3 n0 = flow_sample(uv, d, p0, 1.0);
	vec3 n1 = flow_sample(uv, d, p1, 1.0);
	vec3 coarse = mix(n0, n1, w);

	// موجة دقيقة أسرع وبزاوية مائلة: تكسر انتظام الموجة الكبرى
	vec2 dr = vec2(dir.x * 0.87 - dir.y * 0.5, dir.x * 0.5 + dir.y * 0.87);
	vec3 f0 = flow_sample(uvf, dr * flow_speed * speed * flow_cycle * 1.9, p0, 1.0);
	vec3 f1 = flow_sample(uvf, dr * flow_speed * speed * flow_cycle * 1.9, p1, 1.0);
	vec3 fine = mix(f0, f1, w);

	vec3 nrm = normalize(coarse + fine * 0.55);

	// عمق الماء من فرق العمق بين القاع والسطح
	float scene_z = texture(screen_depth, SCREEN_UV).r;
	vec4 wp4 = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_z, 1.0);
	wp4.xyz /= wp4.w;
	float water_depth = max(-wp4.z - (-VERTEX.z), 0.0);

	float dt = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, dt);

	// انكسار: ما تحت الماء يُزاح بمقدار نتوء السطح
	vec2 ruv = SCREEN_UV + nrm.xz * refraction * (0.35 + dt * 0.65);
	vec3 below = texture(screen_color, ruv).rgb;
	col = mix(below * mix(vec3(1.0), col * 2.2, 0.72), col, clamp(dt * 1.15, 0.0, 1.0));

	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), fresnel_power);

	// رغوة: عند الضفة حيث يَضحل، وحيث يشتدّ التيار في المضيق
	float shore_f = 1.0 - smoothstep(0.0, foam_shore, water_depth);
	float churn = smoothstep(0.62, 1.0, speed) * (0.5 + 0.5 * sin(
		dot(v_world.xz, dir) * 2.2 - t_now() * foam_speed * speed * 3.0));
	float foam = clamp(shore_f * 0.85 + churn * 0.45 * shore_f, 0.0, 1.0);
	// تموّج الرغوة نفسه يتحرّك مع التيار فلا تبدو خطّاً ثابتاً
	foam *= 0.55 + 0.45 * (coarse.y * 0.5 + 0.5);

	ALBEDO = mix(col, foam_color, foam);
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ripple_strength * (0.6 + speed * 0.7);
	ROUGHNESS = mix(mix(roughness_near, roughness_far, fres), 0.72, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.65, 0.3, foam);
	float shore = smoothstep(0.0, shore_fade, water_depth);
	ALPHA = clamp(shore + foam * 0.75, 0.0, 1.0)
		* mix(0.72, 0.97, clamp(dt + fres * 0.5, 0.0, 1.0));
}
