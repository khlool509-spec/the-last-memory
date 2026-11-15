class_name Daylight
extends RefCounted
## أوقات اليوم. كل وقت يغيّر الشمس والسماء والضباب والمحيط معاً،
## فلا يكفي رفع سطوع ضوء واحد — الإحساس بالنهار يأتي من اتساقها.

const KEYS := ["golden", "day", "dusk", "night"]
const LABELS := ["ساعة ذهبية", "نهار", "غروب", "ليل"]

const PRESETS := {
	"golden": {
		"sky_top": Color(0.235, 0.361, 0.569),
		"sky_horizon": Color(0.886, 0.741, 0.561),
		"ground_horizon": Color(0.329, 0.278, 0.224),
		"ground_bottom": Color(0.153, 0.133, 0.114),
		"sun_dir": Vector3(0.86, 0.26, -0.44),
		"sun_color": Color(1.0, 0.878, 0.714),
		"sun_energy": 1.55,
		"ambient_color": Color(0.502, 0.561, 0.651),
		"ambient_energy": 0.92,
		"fog_color": Color(0.729, 0.690, 0.639),
		"fog_near": 0.00040,
		"fog_far": 0.00110,
		"fog_begin": 90.0,
		"fog_end": 420.0,
		"sky_affect": 0.10,
		"exposure": 0.92,
		"saturation": 1.02,
		"lamp_scale": 0.35,
		"shadow_dist": 150.0,
		"foliage_tint": Color(1.0, 0.957, 0.886),
		"sun_disc": 11.0, "sun_size": 0.0021, "sun_glow": 3.4, "horizon_sharp": 4.2, "clouds": 0.56,
		"cloud_color": Color(1.0, 0.886, 0.722), "cloud_shadow": Color(0.447, 0.388, 0.400),
		"volumetric": 0.0022,
		"vol_albedo": Color(1.0, 0.922, 0.820),
		"vol_emission": Color(0.251, 0.173, 0.090),
	},
	"day": {
		"sky_top": Color(0.184, 0.357, 0.631),
		"sky_horizon": Color(0.686, 0.769, 0.835),
		"ground_horizon": Color(0.333, 0.333, 0.306),
		"ground_bottom": Color(0.188, 0.196, 0.180),
		"sun_dir": Vector3(0.377, 0.742, 0.555),
		"sun_color": Color(0.991, 1.0, 0.909),
		"sun_energy": 1.48,
		"ambient_color": Color(0.396, 0.467, 0.569),
		"ambient_energy": 0.90,
		"fog_color": Color(0.639, 0.698, 0.769),
		"fog_near": 0.00016,      # كثافة الضباب على المرتفعات
		"fog_far": 0.00062,       # في بطن الوادي
		"fog_begin": 110.0,
		"fog_end": 460.0,
		"sky_affect": 0.02,
		"exposure": 0.80,
		"saturation": 1.02,
		"lamp_scale": 0.10,       # الفوانيس تخفت في وضح النهار
		"shadow_dist": 150.0,
		"foliage_tint": Color(1.0, 1.0, 1.0),
		# سماء مصوّرة (pure sky): ركام حقيقي وشمس HDR. سماوات الغابة
		# المرشّحة لا تصلح خلفيةً — تملأ الأفق بجدار أشجار؛ تبقى
		# محفوظة للإضاءة وحدها إن لزم.
		"hdri": "kloofendal_48d_partly_cloudy_puresky_2k.hdr", "hdri_energy": 1.0,
		"sun_disc": 9.0, "sun_size": 0.0015, "sun_glow": 2.0, "horizon_sharp": 2.6, "clouds": 0.54,
		"cloud_color": Color(1.0, 0.988, 0.969), "cloud_shadow": Color(0.541, 0.580, 0.639),
		"volumetric": 0.0016,
		"vol_albedo": Color(0.961, 0.973, 1.0),
		"vol_emission": Color(0.090, 0.110, 0.149),
	},
	"dusk": {
		"sky_top": Color(0.133, 0.141, 0.251),
		"sky_horizon": Color(0.561, 0.361, 0.267),
		"ground_horizon": Color(0.192, 0.165, 0.153),
		"ground_bottom": Color(0.090, 0.082, 0.082),
		"sun_dir": Vector3(0.88, 0.16, -0.44),
		"sun_color": Color(1.0, 0.655, 0.408),
		"sun_energy": 0.90,
		"ambient_color": Color(0.329, 0.294, 0.322),
		"ambient_energy": 0.52,
		"fog_color": Color(0.392, 0.310, 0.290),
		"fog_near": 0.0075,
		"fog_far": 0.0190,
		"fog_begin": 24.0,
		"fog_end": 210.0,
		"sky_affect": 0.30,
		"exposure": 1.06,
		"saturation": 0.98,
		"lamp_scale": 0.65,
		"shadow_dist": 110.0,
		"foliage_tint": Color(0.82, 0.74, 0.70),
		"sun_disc": 7.0, "sun_size": 0.0024, "sun_glow": 4.0, "horizon_sharp": 5.0, "clouds": 0.62,
		"cloud_color": Color(1.0, 0.741, 0.533), "cloud_shadow": Color(0.306, 0.251, 0.290),
		"volumetric": 0.028, "vol_length": 180.0,
		"vol_albedo": Color(1.0, 0.839, 0.714),
		"vol_emission": Color(0.192, 0.133, 0.102),
	},
	"night": {
		"sky_top": Color(0.027, 0.035, 0.063),
		"sky_horizon": Color(0.098, 0.118, 0.161),
		"ground_horizon": Color(0.067, 0.078, 0.102),
		"ground_bottom": Color(0.016, 0.020, 0.031),
		"sun_dir": Vector3(0.52, 0.72, 0.46),
		"sun_color": Color(0.639, 0.725, 0.886),
		"sun_energy": 0.70,
		"ambient_color": Color(0.153, 0.184, 0.247),
		"ambient_energy": 0.42,
		"fog_color": Color(0.094, 0.122, 0.165),
		"fog_near": 0.0085,
		"fog_far": 0.0300,
		"fog_begin": 16.0,
		"fog_end": 142.0,
		"sky_affect": 0.45,
		"exposure": 1.12,
		"saturation": 0.90,
		"lamp_scale": 1.0,
		"shadow_dist": 80.0,
		"foliage_tint": Color(0.40, 0.46, 0.60),
		"sun_disc": 2.4, "sun_size": 0.0030, "sun_glow": 1.2, "horizon_sharp": 2.0, "clouds": 0.34,
		"cloud_color": Color(0.455, 0.506, 0.600), "cloud_shadow": Color(0.098, 0.114, 0.165),
		"volumetric": 0.038, "vol_length": 160.0,
		"vol_albedo": Color(0.741, 0.824, 1.0),
		"vol_emission": Color(0.035, 0.047, 0.078),
	},
}

static func preset(key: String) -> Dictionary:
	return PRESETS.get(key, PRESETS["night"])

## سطوع المستخدم 0..1 يُحوَّل إلى مضاعف تعريض 0.72..1.75.
## 0.5 = الوضع الطبيعي للوقت المختار.
static func exposure_multiplier(brightness01: float) -> float:
	var b := clampf(brightness01, 0.0, 1.0)
	return lerpf(0.72, 1.75, b)

## يطبّق الوقت والسطوع على البيئة والشمس دفعة واحدة
static func apply(env: Environment, sun: DirectionalLight3D, key: String, brightness01: float) -> void:
	var p := preset(key)

	# سماء HDRI مصوّرة حين يحدّدها الوقت: تعطي خلفية حقيقية وإضاءة
	# محيطة فيزيائية وانعكاسات من المصدر نفسه. وهي أقرب ما يُبلَغ من
	# إضاءة عامّة صحيحة بلا خبز، ولهذا تُفضَّل على السماء الإجرائية
	# في الأوقات التي لها HDRI. الليل يبقى إجرائياً.
	var hdri_name := str(p.get("hdri", ""))
	# علَم: السماء الحيّة تضبط بارامتراتها بنفسها، فلا تمرّ على
	# فرع السماء الإجرائية أدناه (بارامتراته مختلفة تماماً).
	var live_sky := false
	if env.sky and hdri_name != "":
		# السماء الحيّة: كرة HDRI تحمل الإضاءة، وفوقها طبقتا غيوم
		# متحرّكتان. السماء الساكنة ميتة مهما حسُنت صورتها.
		var path := "res://assets/hdri/" + hdri_name
		var sm2: ShaderMaterial
		var sh2: Shader = ResourceLoader.load("res://assets/shaders/sky_hdri_clouds.gdshader")
		if env.sky.sky_material is ShaderMaterial \
				and (env.sky.sky_material as ShaderMaterial).shader == sh2:
			sm2 = env.sky.sky_material as ShaderMaterial
		else:
			sm2 = ShaderMaterial.new()
			sm2.shader = sh2
			env.sky.sky_material = sm2
		if ResourceLoader.exists(path):
			sm2.set_shader_parameter("panorama", ResourceLoader.load(path))
		sm2.set_shader_parameter("pano_energy", float(p.get("hdri_energy", 1.0)))
		sm2.set_shader_parameter("sun_color", p["sun_color"])
		sm2.set_shader_parameter("cloud_amount", float(p.get("clouds", 0.46)))
		sm2.set_shader_parameter("cloud_lit", p.get("cloud_color", Color(1.0, 0.985, 0.96)))
		sm2.set_shader_parameter("cloud_dark", p.get("cloud_shadow", Color(0.43, 0.47, 0.55)))
		live_sky = true
	elif env.sky and hdri_name == "" and env.sky.sky_material is ShaderMaterial \
			and (env.sky.sky_material as ShaderMaterial).shader != null \
			and str((env.sky.sky_material as ShaderMaterial).shader.resource_path).ends_with("sky_hdri_clouds.gdshader"):
		# العودة من HDRI إلى السماء الإجرائية (الليل).
		# الشرط على PanoramaSkyMaterial وحده: بغيره كان وقتٌ إجرائيّ
		# يحمل ProceduralSkyMaterial يُستبدَل بشادر، فتنكسر كل شيفرة
		# تقرأ خصائص المادة الإجرائية.
		var shader: Shader = ResourceLoader.load("res://assets/shaders/sky.gdshader")
		var back := ShaderMaterial.new()
		back.shader = shader
		env.sky.sky_material = back

	if not live_sky and env.sky and env.sky.sky_material is ShaderMaterial:
		var sm := env.sky.sky_material as ShaderMaterial
		sm.set_shader_parameter("top_color", p["sky_top"])
		sm.set_shader_parameter("horizon_color", p["sky_horizon"])
		# لون ما تحت الأفق = لون الضباب نفسه. العالم 400 متراً،
		# فالكاميرا ترى طرفه؛ وبلون مختلف يظهر الطرف شريحة رمادية
		# عبر المشهد. بمطابقة الضباب تذوب الأرض البعيدة في السماء.
		var horizon_fog: Color = p["fog_color"]
		sm.set_shader_parameter("ground_color", horizon_fog.darkened(0.06))
		sm.set_shader_parameter("sun_color", p["sun_color"])
		sm.set_shader_parameter("sun_energy", float(p.get("sun_disc", 7.0)))
		sm.set_shader_parameter("sun_size", float(p.get("sun_size", 0.0016)))
		sm.set_shader_parameter("sun_glow", float(p.get("sun_glow", 2.6)))
		sm.set_shader_parameter("horizon_sharp", float(p.get("horizon_sharp", 3.0)))
		sm.set_shader_parameter("cloud_amount", float(p.get("clouds", 0.42)))
		sm.set_shader_parameter("cloud_color", p.get("cloud_color", Color(1.0, 0.96, 0.90)))
		sm.set_shader_parameter("cloud_shadow", p.get("cloud_shadow", Color(0.42, 0.45, 0.52)))
	elif not live_sky and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var pm := env.sky.sky_material as ProceduralSkyMaterial
		pm.sky_top_color = p["sky_top"]
		pm.sky_horizon_color = p["sky_horizon"]
		pm.ground_horizon_color = p["ground_horizon"]
		pm.ground_bottom_color = p["ground_bottom"]
	env.ambient_light_color = p["ambient_color"]
	env.ambient_light_energy = float(p["ambient_energy"])
	env.fog_light_color = p["fog_color"]
	env.fog_depth_begin = float(p["fog_begin"])
	env.fog_depth_end = float(p["fog_end"])
	env.fog_sky_affect = float(p["sky_affect"])
	env.tonemap_exposure = float(p["exposure"]) * exposure_multiplier(brightness01)
	env.adjustment_saturation = float(p["saturation"])

	# الضباب الحجمي: هو مصدر أعمدة الضوء بين الأشجار. غير مدعوم في
	# مصيّر الجوال، ومتاح هنا لأن المشروع انتقل إلى Forward+.
	# طول الضباب الحجمي محدود (صندوق أمام الكاميرا)، فعند طرفه يظهر
	# جدار رمادي أفقي عبر المشهد. في النهار إسهامه لا يُذكر وثمنه
	# هذا الجدار، فيُطفأ؛ ويبقى في الغروب والليل حيث يصنع الجوّ فعلاً.
	var vol := float(p.get("volumetric", 0.03))
	env.volumetric_fog_enabled = vol > 0.004
	env.volumetric_fog_density = vol
	env.volumetric_fog_albedo = p.get("vol_albedo", Color.WHITE)
	env.volumetric_fog_emission = p.get("vol_emission", Color.BLACK)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = float(p.get("vol_length", 128.0))
	env.volumetric_fog_detail_spread = 2.0

	if sun:
		sun.light_color = p["sun_color"]
		sun.light_energy = float(p["sun_energy"])
		sun.directional_shadow_max_distance = float(p["shadow_dist"])
		var d: Vector3 = p["sun_dir"]
		sun.transform = Transform3D(Basis(), d.normalized() * 120.0).looking_at(Vector3.ZERO, Vector3.UP)
