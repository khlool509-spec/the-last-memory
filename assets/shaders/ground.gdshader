shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// أرض بلا تبليط ظاهر.
// المشكلة التي يحلّها هذا الملف: بلاطة واحدة مكرّرة كل بضعة أمتار
// تُنتج شبكة بُقع منتظمة تُرى عبر الوادي كلّه مهما جُمّلت الخامة.
// الحل: عيّنتان من الخامة نفسها بمقياسين مختلفين وزاوية دوران غير
// قياسية، يُمزَج بينهما بقناع منخفض التردّد. لأن دورتَي التكرار لا
// تتوافقان، يصير الدور الظاهر هو دور القناع — مئات الأمتار.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D albedo2_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal2_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float detail_scale = 4.6;      // أمتار لكل بلاطة قريبة
uniform float scale_ratio = 1.73;      // نسبة غير نسبية تمنع توافق الدورتين
uniform float blend_angle = 2.399;     // راديان — زاوية دوران العيّنة الثانية
uniform float mask_scale = 72.0;       // أمتار لدورة قناع المزج
uniform float mask_lo = 0.20;          // معايرة على توزيع القناة
uniform float mask_hi = 0.46;
uniform float macro_scale = 61.0;      // تفاوت السطوع الواسع
uniform float macro_strength : hint_range(0.0, 2.0) = 0.9;
uniform float rock_scale = 5.0;
uniform float slope_start : hint_range(0.0, 1.0) = 0.34;
uniform float slope_end : hint_range(0.0, 1.0) = 0.62;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.15;
uniform float normal_far_begin = 55.0;  // تبدأ النتوءات بالخفوت
uniform float normal_far_end = 230.0;   // ويصير البعيد أملس فلا يومض
uniform float ao_strength : hint_range(0.0, 1.0) = 0.40;
uniform vec3 tint : source_color = vec3(1.0);
uniform float use_vcol : hint_range(0.0, 1.0) = 1.0;
uniform int dbg = 0;  // 1: ‏R=مزج الصخر G=قناع التبليط B=تعديل السطوع

varying vec3 v_world;
varying vec3 v_world_normal;

mat2 rot2(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 wxz = v_world.xz;
	mat2 R = rot2(blend_angle);

	// قناع المزج: تردّد منخفض جداً، فحدود المزج نفسها غير منتظمة
	// النافذة معايرة على متوسط القناة الفعلي (0.32)؛ النافذة السابقة
	// 0.34..0.66 كانت تُرجع صفراً في كل بقعة، فلم يُستعمل المزج أصلاً.
	float mk = texture(albedo_tex, wxz / mask_scale).g;
	mk = smoothstep(mask_lo, mask_hi, mk);

	vec2 uv_a = wxz / detail_scale;
	vec2 uv_b = (R * wxz) / (detail_scale * scale_ratio) + vec2(37.1, 11.7);

	vec3 alb = mix(texture(albedo_tex, uv_a).rgb, texture(albedo2_tex, uv_b).rgb, mk);

	vec3 n_a = texture(normal_tex, uv_a).rgb * 2.0 - 1.0;
	vec3 n_b = texture(normal2_tex, uv_b).rgb * 2.0 - 1.0;
	n_b.xy = R * n_b.xy;   // تدوير المماس مع العيّنة وإلا انقلب اتجاه الضوء
	vec3 nrm = normalize(mix(n_a, n_b, mk));

	float rough = mix(texture(rough_tex, uv_a).r, texture(rough_tex, uv_b).r, mk);
	float ao = mix(texture(ao_tex, uv_a).r, texture(ao_tex, uv_b).r, mk);

	// تفاوت سطوع واسع من خامة أخرى، فلا يردّد نمط الأرض نفسه
	float m = dot(texture(rock_albedo, wxz / macro_scale).rgb, vec3(0.3333)) - 0.5;
	alb *= clamp(1.0 + m * macro_strength, 0.62, 1.48);

	// الميل: 0 مستوٍ، 1 جدار
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);
	float rock_w = smoothstep(slope_start, slope_end, slope);
	vec2 uv_r = wxz / rock_scale;
	vec3 r_col = texture(rock_albedo, uv_r).rgb;
	vec3 r_nrm = texture(rock_normal, uv_r).rgb * 2.0 - 1.0;

	vec3 vc = mix(vec3(1.0), COLOR.rgb, use_vcol);
	vec3 col = mix(alb * vc, r_col * 0.62, rock_w);
	nrm = normalize(mix(nrm, r_nrm, rock_w));

	// النتوءات تخفت مع البعد: بلا ذلك يتحوّل البعيد إلى وميض نقاط
	float d = length(v_world - CAMERA_POSITION_WORLD);
	float near_w = 1.0 - smoothstep(normal_far_begin, normal_far_end, d);

	// شبكات الأرض المخبوزة لا تحمل مماسات (ARRAY_TANGENT)، فاستعمال
	// NORMAL_MAP كان يُحلّ على إطار مماس غير معرّف ويرسم شبكة معيّنات
	// بمقاس مربّع التضاريس (مترين). المُخرَج الهندسي للأرض مسطّح على
	// المستوى XZ، فالإطار معروف تحليلياً: لا حاجة لمماسات أصلاً.
	vec3 wn = normalize(v_world_normal);
	vec3 t_dir = normalize(cross(vec3(0.0, 0.0, 1.0), wn));
	vec3 b_dir = normalize(cross(wn, t_dir));
	float bump = normal_strength * mix(0.18, 1.0, near_w);
	vec3 pert = normalize(wn + (t_dir * nrm.x + b_dir * nrm.y) * bump);

	if (dbg == 1) {
		ALBEDO = vec3(rock_w, mk, clamp(1.0 + m * macro_strength, 0.0, 1.0));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		ROUGHNESS = 1.0;
		AO = 1.0;
		SPECULAR = 0.0;
		METALLIC = 0.0;
		EMISSION = vec3(rock_w, mk, clamp(1.0 + m * macro_strength, 0.0, 1.0));
	} else {
	ALBEDO = col * tint;
	NORMAL = normalize((VIEW_MATRIX * vec4(pert, 0.0)).xyz);
	ROUGHNESS = mix(rough, 0.90, rock_w);
	AO = mix(1.0, ao, ao_strength * near_w);
	AO_LIGHT_AFFECT = 0.5;
	SPECULAR = 0.12;
	METALLIC = 0.0;
	}
}
