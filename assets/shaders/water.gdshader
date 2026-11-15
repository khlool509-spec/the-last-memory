shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// نهر: سطح متعدّد المقاييس بموج هندسي حقيقي، لا لوح مستوٍ عليه
// خريطة نتوء.
//
// لماذا الموج الهندسي ضروري: اللوح المستوي ظلّيته خطّ مستقيم مهما
// بلغت خريطة النتوء، فيُقرأ سطحاً مطبوعاً عند الزوايا الزاحفة —
// وهي أكثر زوايا النظر إلى نهر. بإزاحة القمم تتموّج الظلّية نفسها.
//
// الجريان: اتجاهه وسرعته مخبوزان في ألوان القمم (rg الاتجاه،
// b السرعة، a القرب من المحور). والإزاحة ذات طورين متباعدين نصف
// دورة لمنع مطّ النمط — طريقة خرائط الجريان المعروفة.
//
// الشاطئ: اللوح يتجاوز المجرى إلى الضفة عمداً، والحدّ يُرسَم
// بالشفافية حسب عمق الماء المقروء من مخزن العمق. فلا حافّة شبكة
// مستقيمة ولا أسافين.

uniform float anim_time = -1.0;   // ≥0 يستبدل TIME للالتقاط
uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// مصيّر Mobile لا يوفّر مخزن العمق للشيدرات، وقراءة لون الشاشة
// مكلفة عليه. العمق يأتي الآن من بيانات مخبوزة في لون الرأس:
// COLOR.a = بُعد النقطة عن الضفة (0 عند الحافة، 1 في وسط المجرى).
uniform float channel_depth : hint_range(0.2, 4.0) = 1.35;  // عمق الوسط بالأمتار

// قياس من مرجع ببجي: متوسط مساحة الماء خطّياً (0.168, 0.254, 0.262)
// ومدى العيّنات من القريب إلى الأفق 0.147 → 0.319. أي أن ماء ببجي
// شبه موحّد اللون: تدرّج العمق خفيف جداً، والتشبّع منخفض، والقيمة
// فاتحة. نسبة القنوات ≈ 0.64 : 0.97 : 1.00
uniform vec3 shallow_color : source_color = vec3(0.205, 0.292, 0.300);
uniform vec3 deep_color : source_color = vec3(0.132, 0.212, 0.224);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.95);
uniform vec3 bed_tint : source_color = vec3(0.40, 0.40, 0.36);  // حصى القاع

uniform float depth_fade = 2.2;
uniform float shore_fade = 0.80;
uniform float flow_speed = 0.62;
uniform float flow_cycle = 3.0;

// الموج الهندسي: ثلاث موجات بأطوال وسرعات مختلفة
uniform float wave_len_a = 5.6;
uniform float wave_amp_a = 0.145;
uniform float wave_len_b = 2.3;
uniform float wave_amp_b = 0.072;
uniform float wave_len_c = 0.9;
uniform float wave_amp_c = 0.028;
uniform float wave_steep : hint_range(0.0, 1.0) = 0.80;

uniform float ripple_scale = 1.4;
uniform float ripple_fine = 0.42;
uniform float ripple_strength : hint_range(0.0, 3.0) = 1.3;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.6;
uniform float rough_calm : hint_range(0.0, 1.0) = 0.055;
uniform float rough_churn : hint_range(0.0, 1.0) = 0.34;
uniform float foam_depth = 0.95;     // أمتار يظهر فيها زبد الضحل
uniform float refraction : hint_range(0.0, 0.3) = 0.055;
uniform vec3 sky_color : source_color = vec3(0.47, 0.61, 0.74);
uniform float reflect_amount : hint_range(0.0, 1.0) = 0.62;

varying vec3 v_world;
varying vec4 v_flow;
varying vec3 v_wave_n;
varying float v_churn;

float t_now() {
	return anim_time >= 0.0 ? anim_time : TIME;
}

// موجة جيبية متقدّمة مع التيار. تُرجع الارتفاع، وتكتب الميل.
float wave(vec2 p, vec2 dir, float len, float amp, float t, float sp, inout vec2 slope) {
	float k = 6.2831853 / max(len, 0.05);
	float phase = dot(p, dir) * k - t * sp * k * 0.55;
	float s = sin(phase);
	slope += dir * (cos(phase) * amp * k);
	return s * amp;
}

void vertex() {
	v_flow = COLOR;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 dir = normalize((COLOR.rg - 0.5) * 2.0 + vec2(0.0001));
	float speed = max(COLOR.b, 0.2);
	// السعة تتلاشى عند الضفة: الماء الضحل لا يحمل موجاً كبيراً
	float mid = COLOR.a;
	float amp_w = mid * mid * (0.45 + speed * 0.85);
	float t = t_now();

	vec2 slope = vec2(0.0);
	float h = 0.0;
	h += wave(wp.xz, dir, wave_len_a, wave_amp_a * amp_w, t, speed, slope);
	// الموجتان الأخريان بزوايا مائلة فلا تصطفّ القمم في صفوف
	vec2 d2 = vec2(dir.x * 0.81 - dir.y * 0.59, dir.x * 0.59 + dir.y * 0.81);
	vec2 d3 = vec2(dir.x * 0.81 + dir.y * 0.59, -dir.x * 0.59 + dir.y * 0.81);
	h += wave(wp.xz, d2, wave_len_b, wave_amp_b * amp_w, t, speed * 1.3, slope);
	h += wave(wp.xz, d3, wave_len_c, wave_amp_c * amp_w, t, speed * 1.9, slope);

	VERTEX.y += h;
	// عموديّ الموج من ميله: هذا ما يجعل الإضاءة تتبع الشكل الحقيقي
	v_wave_n = normalize(vec3(-slope.x * wave_steep, 1.0, -slope.y * wave_steep));
	v_world = wp + vec3(0.0, h, 0.0);
	// الاضطراب: يشتدّ مع السرعة وفي الوسط
	v_churn = clamp((speed - 0.55) * 2.4, 0.0, 1.0) * mid;
}

vec3 flow_sample(vec2 uv, vec2 dir, float phase, float scale) {
	return texture(ripple_tex, uv * scale - dir * phase).rgb * 2.0 - 1.0;
}

void fragment() {
	vec2 dir = normalize((v_flow.rg - 0.5) * 2.0 + vec2(0.0001));
	float speed = max(v_flow.b, 0.2);
	float t = t_now();

	// طوران متباعدان نصف دورة ووزن مثلثي: جريان متّصل بلا مطّ
	float tc = t / flow_cycle;
	float p0 = fract(tc);
	float p1 = fract(tc + 0.5);
	float w = abs(1.0 - 2.0 * p0);
	vec2 d = dir * flow_speed * speed * flow_cycle;

	vec2 uv = v_world.xz / ripple_scale;
	vec3 r_coarse = mix(flow_sample(uv, d, p0, 1.0), flow_sample(uv, d, p1, 1.0), w);
	vec2 dr = vec2(dir.x * 0.87 - dir.y * 0.5, dir.x * 0.5 + dir.y * 0.87);
	vec2 d2 = dr * flow_speed * speed * flow_cycle * 2.1;
	vec3 r_fine = mix(flow_sample(uv, d2, p0, ripple_scale / ripple_fine),
		flow_sample(uv, d2, p1, ripple_scale / ripple_fine), w);

	// نتوء الخامة فوق عمودي الموج الهندسي
	vec3 micro = normalize(r_coarse + r_fine * 0.7);
	vec3 n = normalize(v_wave_n + vec3(micro.x, 0.0, micro.y)
		* ripple_strength * (0.35 + speed * 0.5));

	// عمق الماء من مقطع المجرى المخبوز: الضفة ضحلة والوسط أعمق.
	// منحنى تربيعي لأن قاع النهر مقعّر لا مسطّح.
	float mid_f = clamp(v_flow.a, 0.0, 1.0);
	float water_depth = channel_depth * mid_f * mid_f;
	float dt = clamp(water_depth / depth_fade, 0.0, 1.0);

	// قاع مرئي في الضحل: حصى فاتح يظهر عبر الماء عند الضفاف،
	// ويبتلعه الامتصاص كلما عمُق المجرى. هذا ما يجعل النهر يُقرأ
	// كنهر لا كشريط ملوّن — التدرّج من الحافة إلى الوسط.
	vec2 buv = v_world.xz / 1.7 + n.xz * refraction * 2.0;
	float bed = texture(ripple_tex, buv).g * 0.5 + 0.5;
	vec3 bed_col = bed_tint * (0.72 + 0.56 * bed);
	vec3 absorb = mix(shallow_color, deep_color, dt);
		// المرجع يُظهر القاع عبر غشاء موحّد لا تدرّجاً حادّاً، لذا الخلط
	// يبدأ مبكراً وينتهي مبكراً: الماء يُقرأ كسطح واحد له عمق.
	vec3 col = mix(bed_col * absorb * 1.15 + absorb * 0.45,
		absorb, smoothstep(0.0, 0.55, dt));

	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), fresnel_power);

	// الرغوة من ثلاثة مصادر حقيقية:
	//  • الضحل (قرب الضفة والصخور — كلاهما يرفع القاع)
	//  • الاضطراب في المضائق والتيار السريع
	//  • قمم الموج الهندسي: الزبد يتجمّع على القمّة لا في البطن
	float shallow_f = 1.0 - smoothstep(0.0, foam_depth, water_depth);
	float crest = smoothstep(0.35, 0.95, v_wave_n.y < 0.999 ? (1.0 - v_wave_n.y) * 42.0 : 0.0);
	float churn_f = v_churn * (0.35 + 0.65 * (r_fine.y * 0.5 + 0.5));
	float foam = clamp(shallow_f * 0.26 + churn_f * crest * 0.42, 0.0, 1.0);
	// تلاشٍ تدريجي: الزبد لا يظهر ويختفي فجأة
	foam *= 0.55 + 0.45 * (r_coarse.y * 0.5 + 0.5);

		// انعكاس السماء: لون السماء المحيط يُمزج حسب الفرينل. هذا ما
	// يجعل الماء يعكس بوضوح من زاوية منخفضة ويبقى صافياً من فوق.
	vec3 sky_ref = sky_color * (0.85 + 0.30 * r_coarse.y);
	vec3 surf = mix(col, sky_ref, clamp(fres * reflect_amount, 0.0, 0.82));
	ALBEDO = mix(surf, foam_color, foam);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(mix(rough_calm, rough_churn, v_churn), 0.72, foam) + fres * 0.10;
	METALLIC = 0.0;
		// بريق مكبوح عمداً: المطلوب انعكاس يُرى لا وهج يؤذي النظر.
	SPECULAR = mix(0.38, 0.20, foam);
	// الخشونة ترتفع مع بُعد النظر فيتفتّت قرص الشمس بدل أن يتركّز
	RIM = 0.18;
	float shore = smoothstep(0.0, shore_fade, water_depth);
	// قاعدة شفافية لا تهبط إلى الصفر داخل المجرى: الماء الضحل
	// يبقى مرئياً كغشاء، ولا يختفي تاركاً القاع عارياً.
	ALPHA = clamp(shore + foam * 0.8, 0.0, 1.0)
		* mix(0.86, 1.0, clamp(dt + fres * 0.55, 0.0, 1.0));
}
