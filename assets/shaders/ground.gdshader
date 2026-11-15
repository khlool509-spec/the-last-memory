shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// أرض من ثلاث خامات PBR مصوّرة + طبقة نطاق واسع + صخر على الميل،
// كلها بإسقاط ثلاثي المحاور، فوقها طبقة بلل.
//
// ما يحلّه كل جزء:
//  • الإسقاط الثلاثي — الإسقاط المستوي على XZ يمطّ الخامة على كل
//    سطح رأسي، فيصير الجرف دهاناً مسحوباً.
//  • ثلاث طبقات بقناعين — طين رطب / أرض بعشب / فرش أوراق. الانتقال
//    يتبع الاستواء والنطاق الواسع، لا ضجيجاً عشوائياً.
//  • دوران العيّنة الثانية — تمنع توافق دورتَي التكرار فتختفي الشبكة.
//  • البلل — المنخفض قرب الماء يغمق ويصير أملس وينعكس فيه الضوء.
//    هذا أبرز ما يميّز الأرض الحقيقية عن بلاطة خامة مسطّحة.

uniform sampler2D a_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D c_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D c_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D c_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_disp : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D b_disp : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float a_scale = 2.35;        // طين الغابة — المقاس الواقعي المعلَن
uniform float b_scale = 2.00;        // أرض بعشب
uniform float c_scale = 2.14;        // فرش أوراق
uniform float macro_scale = 90.0;    // تضاريس جوية
uniform float rock_scale = 9.0;
uniform float blend_angle = 2.399;
uniform float tri_sharp : hint_range(1.0, 16.0) = 5.0;
uniform float mask_lo : hint_range(0.0, 1.0) = 0.26;
uniform float mask_hi : hint_range(0.0, 1.0) = 0.70;
uniform float litter_lo : hint_range(0.0, 1.0) = 0.62;
uniform float litter_hi : hint_range(0.0, 1.0) = 0.90;
uniform float macro_strength : hint_range(0.0, 2.0) = 0.85;
uniform float macro_hue : hint_range(0.0, 1.0) = 0.12;
uniform float slope_start : hint_range(0.0, 1.0) = 0.50;
uniform float slope_end : hint_range(0.0, 1.0) = 0.92;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.0;
uniform float normal_far_begin = 95.0;
uniform float normal_far_end = 430.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.40;

// إزاحة المنظور (POM): الأرض القريبة كانت تُقرأ سجّادة مطبوعة لأن
// الخامة مسطّحة مهما حسُنت. الإزاحة تُزحزح نقطة المعاينة بحسب زاوية
// النظر وعمق الخامة، فتختفي الحصى خلف بعضها ويظهر عمق حقيقي.
// الكلفة محصورة في المتر الأول: الخطوات تهبط إلى صفر مع البعد.
uniform float pom_depth : hint_range(0.0, 0.2) = 0.055;   // أمتار
uniform float pom_near = 3.0;      // كامل الخطوات حتى هنا
uniform float pom_far = 26.0;      // صفر خطوات بعدها
uniform int pom_steps_max = 14;
uniform int pom_steps_min = 4;
uniform float pom_enable : hint_range(0.0, 1.0) = 1.0;
uniform float rough_lo : hint_range(0.0, 1.0) = 0.55;
uniform float rough_hi : hint_range(0.0, 1.0) = 0.97;

// البلل
uniform float water_level = -2.6;
uniform float wet_rise = 3.4;             // أمتار فوق الماء يبقى الطين مشبعاً
uniform float wet_amount : hint_range(0.0, 1.0) = 1.0;
uniform float puddle_rough : hint_range(0.0, 1.0) = 0.07;
uniform float wet_darken : hint_range(0.0, 1.0) = 0.34;

uniform vec3 rock_tint : source_color = vec3(0.70, 0.70, 0.68);
uniform vec3 tint : source_color = vec3(0.96, 1.00, 1.00);
uniform float use_vcol : hint_range(0.0, 1.0) = 1.0;
uniform int dbg = 0;   // 1: ‏R=صخر G=قناع B=بلل

varying vec3 v_world;
varying vec3 v_world_normal;

mat2 rot2(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

vec3 tri_weights(vec3 n, float sharp) {
	vec3 w = pow(abs(n), vec3(sharp));
	return w / max(w.x + w.y + w.z, 0.0001);
}

vec3 tri_sample(sampler2D tex, vec3 wp, vec3 w, float scale) {
	return texture(tex, wp.zy / scale).rgb * w.x
		+ texture(tex, wp.xz / scale).rgb * w.y
		+ texture(tex, wp.xy / scale).rgb * w.z;
}

// نتوء بأسلوب whiteout: انحراف كل مستوٍ يُجمع على العمودي الهندسي،
// فلا ينقلب اتجاه الضوء عند تبديل المستوي الغالب.
vec3 tri_normal(sampler2D tex, vec3 wp, vec3 w, float scale, vec3 gn) {
	vec3 nx = texture(tex, wp.zy / scale).rgb * 2.0 - 1.0;
	vec3 ny = texture(tex, wp.xz / scale).rgb * 2.0 - 1.0;
	vec3 nz = texture(tex, wp.xy / scale).rgb * 2.0 - 1.0;
	return normalize(gn
		+ vec3(0.0, nx.y, nx.x) * w.x
		+ vec3(ny.x, 0.0, ny.y) * w.y
		+ vec3(nz.x, nz.y, 0.0) * w.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wp = v_world;
	vec3 wn = normalize(v_world_normal);
	vec3 tw = tri_weights(wn, tri_sharp);
	mat2 R = rot2(blend_angle);

	vec3 mac = tri_sample(macro_diff, wp, tw, macro_scale);
	float mac_l = dot(mac, vec3(0.299, 0.587, 0.114));

	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float flat_w = 1.0 - smoothstep(0.06, 0.30, slope);

	// قناع العشب: نطاق واسع مرجَّح بالاستواء
	float mk = smoothstep(mask_lo, mask_hi, mac_l * 0.62 + flat_w * 0.38);
	// قناع الفرش: الأوراق تتجمّع في المنبسط المحمي لا على المنحدر
	// الأوراق تستقرّ حيث لا ينزلقها الميل ولا يجرفها الماء
	float lit_m = smoothstep(litter_lo, litter_hi,
		(1.0 - mac_l) * 0.28 + flat_w * 0.72) * (1.0 - smoothstep(0.10, 0.26, slope));

	// --- إزاحة المنظور على المستوى الأفقي ---
	// الأرض أفقية الغالب، فالإزاحة تُحسب على XZ وتخفت على الأوجه
	// الرأسية حيث لا معنى لها.
	vec3 vdir = normalize(wp - CAMERA_POSITION_WORLD);
	float cam_d = length(wp - CAMERA_POSITION_WORLD);
	// الزاوية الزاحفة جداً تُطيل مسير الشعاع فتظهر خطوط ممطوطة:
	// الإزاحة تخفت كلما اقترب النظر من مماسّة السطح. هذا ليس إخفاءً
	// للمشكلة بل حدّها الفيزيائي — عند المماسّة لا يُرى العمق أصلاً.
	float graze = smoothstep(0.08, 0.40, abs(vdir.y));
	float pom_w = (1.0 - smoothstep(pom_near, pom_far, cam_d)) * tw.y * graze;
	vec2 par = vec2(0.0);
	pom_w *= pom_enable;
	if (pom_w > 0.01 && pom_depth > 0.0) {
		int steps = int(mix(float(pom_steps_min), float(pom_steps_max), pom_w));
		vec2 dir = vdir.xz / max(abs(vdir.y), 0.45) * pom_depth;
		float step_h = 1.0 / float(steps);
		float cur_h = 1.0;
		vec2 dstep = dir * step_h;
		vec2 off = vec2(0.0);
		float sampled = mix(
			texture(a_disp, (wp.xz + off) / a_scale).r,
			texture(b_disp, (wp.xz + off) / b_scale).r, mk);
		for (int i = 0; i < steps; i++) {
			if (sampled >= cur_h) { break; }
			off -= dstep;
			cur_h -= step_h;
			sampled = mix(
				texture(a_disp, (wp.xz + off) / a_scale).r,
				texture(b_disp, (wp.xz + off) / b_scale).r, mk);
		}
		// خطوة تنقيح واحدة: تقاطع خطّي بين آخر عيّنتين
		vec2 prev = off + dstep;
		float h_prev = mix(
			texture(a_disp, (wp.xz + prev) / a_scale).r,
			texture(b_disp, (wp.xz + prev) / b_scale).r, mk) - (cur_h + step_h);
		float h_cur = sampled - cur_h;
		float w8 = h_cur / max(h_cur - h_prev, 0.0001);
		par = mix(off, prev, clamp(w8, 0.0, 1.0)) * pom_w;
		float lim = pom_depth * 2.0;
		par = clamp(par, vec2(-lim), vec2(lim));
	}
	vec3 wpp = vec3(wp.x + par.x, wp.y, wp.z + par.y);

	vec3 wp_b = vec3((R * wpp.xz).x, wp.y, (R * wpp.xz).y) + vec3(37.1, 0.0, 11.7);
	vec3 wp_c = vec3((R * wpp.zx).x, wp.y, (R * wpp.zx).y) + vec3(-19.3, 0.0, 61.7);

	vec3 d_a = tri_sample(a_diff, wpp, tw, a_scale);
	vec3 d_b = tri_sample(b_diff, wp_b, tw, b_scale);
	vec3 d_c = tri_sample(c_diff, wp_c, tw, c_scale);
	vec3 alb = mix(mix(d_a, d_b, mk), d_c, lit_m);

	vec3 n_a = tri_normal(a_norm, wpp, tw, a_scale, wn);
	vec3 n_b = tri_normal(b_norm, wp_b, tw, b_scale, wn);
	vec3 n_c = tri_normal(c_norm, wp_c, tw, c_scale, wn);
	vec3 nrm = normalize(mix(mix(n_a, n_b, mk), n_c, lit_m));

	vec3 arm = mix(mix(tri_sample(a_arm, wpp, tw, a_scale),
		tri_sample(b_arm, wp_b, tw, b_scale), mk),
		tri_sample(c_arm, wp_c, tw, c_scale), lit_m);

	alb *= clamp(1.0 + (mac_l - 0.5) * macro_strength, 0.58, 1.52);
	alb = mix(alb, alb * (mac / max(mac_l, 0.001)), macro_hue);

	// الصخر على الميل
	float rock_w = smoothstep(slope_start, slope_end, slope);
	vec3 r_col = tri_sample(rock_diff, wp, tw, rock_scale);
	vec3 r_nrm = tri_normal(rock_norm, wp, tw, rock_scale, wn);
	vec3 r_arm = tri_sample(rock_arm, wp, tw, rock_scale);

	vec3 vc = mix(vec3(1.0), COLOR.rgb, use_vcol);
	vec3 col = mix(alb * vc, r_col * rock_tint, rock_w);
	nrm = normalize(mix(nrm, r_nrm, rock_w));
	arm = mix(arm, r_arm, rock_w);

	// البلل: قرب الماء، على المنبسط، وبتفاوت واسع يمنع حزاماً منتظماً
	float near_water = 1.0 - smoothstep(0.0, wet_rise, wp.y - water_level);
	float wet = clamp(near_water * flat_w * (0.45 + mac_l * 0.85), 0.0, 1.0) * wet_amount;
	wet *= 1.0 - rock_w * 0.55;
	// الضفة: الطين المبلّل يغمق، لكن الإعتام يخفّ حيث يشتدّ الصخر
	// وإلا اجتمع الاثنان فصارت الضفة شريطاً أسود يفصل الماء عن الأرض.
	col *= mix(1.0, 1.0 - wet_darken * (1.0 - rock_w * 0.6), wet);     // المبلّل أغمق لأن الماء يملأ المسام
	float rough = mix(rough_lo, rough_hi, arm.g);
	rough = mix(rough, puddle_rough, wet);
	nrm = normalize(mix(nrm, wn, wet * 0.75));  // سطح الماء يسوّي النتوء

	float d = cam_d;
	float near_w = 1.0 - smoothstep(normal_far_begin, normal_far_end, d);
	vec3 pert = normalize(mix(wn, nrm, normal_strength * mix(0.25, 1.0, near_w)));

	if (dbg == 1) {
		ALBEDO = vec3(rock_w, mk, wet);
		EMISSION = vec3(rock_w, mk, wet);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		ROUGHNESS = 1.0;
		AO = 1.0;
		SPECULAR = 0.0;
		METALLIC = 0.0;
	} else {
		ALBEDO = col * tint;
		NORMAL = normalize((VIEW_MATRIX * vec4(pert, 0.0)).xyz);
		ROUGHNESS = rough;
		AO = mix(1.0, arm.r, ao_strength * near_w * (1.0 - wet * 0.6));
		AO_LIGHT_AFFECT = 0.6;
		METALLIC = 0.0;
		SPECULAR = mix(0.14, 0.62, wet);
	}
}
