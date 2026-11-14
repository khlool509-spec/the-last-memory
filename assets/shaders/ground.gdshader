shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// أرض من خامات PBR مصوّرة (Poly Haven، رخصة CC0).
//
// ثلاث طبقات بمقاييس العالم الحقيقي المعلَنة مع كل خامة:
//   • تفصيل أ — تربة وحصى، بلاطتها 3.15 م
//   • تفصيل ب — أرض غابة بعشب، بلاطتها 2.00 م
//   • نطاق واسع — تضاريس جوية، بلاطتها 90 م
// يُمزَج أ وب بقناع مأخوذ من الطبقة الواسعة نفسها، فتوزيع العشب
// والتربة يتبع نمط تضاريس حقيقياً لا ضجيجاً، وتختفي شبكة التبليط
// لأن دورة القناع 90 متراً لا بضعة أمتار.
//
// الصخر يظهر على المنحدرات حسب الميل.
// خرائط ARM: أحمر=حجب، أخضر=خشونة، أزرق=معدنية.

uniform sampler2D a_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float a_scale = 3.15;        // المقاس الواقعي المعلَن للخامة
uniform float b_scale = 2.00;
uniform float macro_scale = 90.0;
uniform float rock_scale = 9.0;
uniform float blend_angle = 2.399;   // دوران العيّنة الثانية يكسر توافق الدورتين
uniform float mask_lo : hint_range(0.0, 1.0) = 0.26;
uniform float mask_hi : hint_range(0.0, 1.0) = 0.62;
uniform float macro_strength : hint_range(0.0, 2.0) = 0.85;
uniform float macro_hue : hint_range(0.0, 1.0) = 0.30;   // نقل لون الطبقة الواسعة
uniform float slope_start : hint_range(0.0, 1.0) = 0.44;
uniform float slope_end : hint_range(0.0, 1.0) = 0.72;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.0;
uniform float normal_far_begin = 55.0;
uniform float normal_far_end = 240.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.40;
uniform float rough_lo : hint_range(0.0, 1.0) = 0.55;    // إعادة مدّ الخشونة
uniform float rough_hi : hint_range(0.0, 1.0) = 0.97;
uniform vec3 rock_tint : source_color = vec3(0.70, 0.70, 0.68);
uniform vec3 tint : source_color = vec3(1.10, 1.09, 1.05);
uniform float use_vcol : hint_range(0.0, 1.0) = 1.0;
uniform int dbg = 0;   // 1: ‏R=الصخر G=القناع B=السطوع الواسع

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

	vec3 mac = texture(macro_diff, wxz / macro_scale).rgb;
	float mac_l = dot(mac, vec3(0.299, 0.587, 0.114));

	// الميل: 0 مستوٍ، 1 جدار — يُحسب مبكراً لأن القناع يستعمله
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);

	// القناع من الطبقة الواسعة: التوزيع يتبع تضاريس مصوّرة حقيقية.
	// ويُرجَّح بالاستواء: العشب يثبت على المنبسط، والتربة تنكشف على
	// المنحدر حيث يجرفها المطر — فيتغيّر الغطاء محلياً لا كل 90 متراً.
	float flat_w = 1.0 - smoothstep(0.06, 0.30, slope);
	float mk = smoothstep(mask_lo, mask_hi, mac_l * 0.62 + flat_w * 0.38);

	vec2 uv_a = wxz / a_scale;
	vec2 uv_b = (R * wxz) / b_scale + vec2(37.1, 11.7);

	vec3 d_a = texture(a_diff, uv_a).rgb;
	vec3 d_b = texture(b_diff, uv_b).rgb;
	vec3 alb = mix(d_a, d_b, mk);

	vec3 n_a = texture(a_norm, uv_a).rgb * 2.0 - 1.0;
	vec3 n_b = texture(b_norm, uv_b).rgb * 2.0 - 1.0;
	n_b.xy = R * n_b.xy;   // تدوير المماس مع العيّنة وإلا انقلب اتجاه الضوء
	vec3 nrm = normalize(mix(n_a, n_b, mk));

	vec3 arm = mix(texture(a_arm, uv_a).rgb, texture(b_arm, uv_b).rgb, mk);

	// الطبقة الواسعة تنقل سطوعها ولونها، فلا تبقى الأرض لوناً واحداً
	alb *= clamp(1.0 + (mac_l - 0.5) * macro_strength, 0.58, 1.52);
	alb = mix(alb, alb * (mac / max(mac_l, 0.001)), macro_hue);

	float rock_w = smoothstep(slope_start, slope_end, slope);
	vec2 uv_r = wxz / rock_scale;
	vec3 r_col = texture(rock_diff, uv_r).rgb;
	vec3 r_nrm = texture(rock_norm, uv_r).rgb * 2.0 - 1.0;
	vec3 r_arm = texture(rock_arm, uv_r).rgb;

	vec3 vc = mix(vec3(1.0), COLOR.rgb, use_vcol);
	vec3 col = mix(alb * vc, r_col * rock_tint, rock_w);
	nrm = normalize(mix(nrm, r_nrm, rock_w));
	arm = mix(arm, r_arm, rock_w);

	// الشبكات المخبوزة بلا ARRAY_TANGENT، وإسقاط الأرض مستوٍ على XZ،
	// فإطار المماس معروف تحليلياً ولا حاجة لتخزينه في الملف.
	vec3 wn = normalize(v_world_normal);
	vec3 t_dir = normalize(cross(vec3(0.0, 0.0, 1.0), wn));
	vec3 b_dir = normalize(cross(wn, t_dir));
	float d = length(v_world - CAMERA_POSITION_WORLD);
	float near_w = 1.0 - smoothstep(normal_far_begin, normal_far_end, d);
	float bump = normal_strength * mix(0.16, 1.0, near_w);
	vec3 pert = normalize(wn + (t_dir * nrm.x + b_dir * nrm.y) * bump);

	if (dbg == 1) {
		ALBEDO = vec3(rock_w, mk, mac_l);
		EMISSION = vec3(rock_w, mk, mac_l);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		ROUGHNESS = 1.0;
		AO = 1.0;
		SPECULAR = 0.0;
		METALLIC = 0.0;
	} else {
		ALBEDO = col * tint;
		NORMAL = normalize((VIEW_MATRIX * vec4(pert, 0.0)).xyz);
		ROUGHNESS = mix(rough_lo, rough_hi, arm.g);
		AO = mix(1.0, arm.r, ao_strength * near_w);
		AO_LIGHT_AFFECT = 0.6;
		METALLIC = 0.0;
		SPECULAR = 0.14;
	}
}
