class_name WorldMaterials
extends RefCounted
## خامات العالم. كلها StandardMaterial3D مضبوطة لمصيّر الجوال:
## لا شفافية مرتّبة، ولا شيدرات مخصّصة في المسار الحرج.

const TEX := "res://assets/textures/world/"

static func _tex(name: String) -> Texture2D:
	var p := TEX + name
	if ResourceLoader.exists(p):
		return ResourceLoader.load(p)
	return null

## صبغة النبات تتغيّر مع وقت اليوم: ألوان الرؤوس مؤلَّفة للنهار،
## والليل يبرّدها ويخفضها بدل إعادة خبز العالم.
static var foliage_tint: Color = Color.WHITE
static var _foliage_mats: Array[StandardMaterial3D] = []

static func set_foliage_tint(c: Color) -> void:
	foliage_tint = c
	for m in _foliage_mats:
		if is_instance_valid(m):
			m.albedo_color = c

## أرض الغابة: شيدر بمقياسين ومزج صخري حسب الميل.
## خامة واحدة مكرّرة بمقياس واحد تُظهر شبكة بلاط مهما حسُنت؛ المقياسان
## يكسرانها، والميل يضع الصخر حيث ينبغي.
static var _ground_mat: ShaderMaterial = null
const PBR := "res://assets/textures/pbr/"

static func _pbr(name: String) -> Texture2D:
	var p := PBR + name
	if ResourceLoader.exists(p):
		return ResourceLoader.load(p)
	push_warning("خامة PBR مفقودة: " + p)
	return null

## أرض الغابة: خامات مصوّرة من Poly Haven برخصة CC0، بمقاييسها الواقعية.
## المصادر والبصمات في assets/textures/pbr/MANIFEST.json
static func ground() -> ShaderMaterial:
	if _ground_mat != null:
		return _ground_mat
	var sh: Shader = ResourceLoader.load("res://assets/shaders/ground.gdshader")
	var m := ShaderMaterial.new()
	m.shader = sh
	# تفصيل أ: تربة وحصى (forest_ground_04، بلاطة 3.15 م)
	m.set_shader_parameter("a_diff", _pbr("forest_ground_04_diff_2k.jpg"))
	m.set_shader_parameter("a_norm", _pbr("forest_ground_04_nor_2k.jpg"))
	m.set_shader_parameter("a_arm", _pbr("forest_ground_04_arm_2k.jpg"))
	# تفصيل ب: أرض غابة بعشب (forrest_ground_01، بلاطة 2.00 م)
	m.set_shader_parameter("b_diff", _pbr("forrest_ground_01_diff_2k.jpg"))
	m.set_shader_parameter("b_norm", _pbr("forrest_ground_01_nor_2k.jpg"))
	m.set_shader_parameter("b_arm", _pbr("forrest_ground_01_arm_2k.jpg"))
	# نطاق واسع: تضاريس جوية (rocky_terrain_02، بلاطة 90 م)
	m.set_shader_parameter("macro_diff", _pbr("rocky_terrain_02_diff_2k.jpg"))
	# الصخر على المنحدرات (aerial_rocks_02)
	m.set_shader_parameter("rock_diff", _pbr("aerial_rocks_02_diff_2k.jpg"))
	m.set_shader_parameter("rock_norm", _pbr("aerial_rocks_02_nor_2k.jpg"))
	m.set_shader_parameter("rock_arm", _pbr("aerial_rocks_02_arm_2k.jpg"))
	if OS.get_environment("NO_VCOL") == "1":
		m.set_shader_parameter("use_vcol", 0.0)
	if OS.get_environment("GROUND_DBG") != "":
		m.set_shader_parameter("dbg", int(OS.get_environment("GROUND_DBG")))
	_ground_mat = m
	return m

## لحاء الأشجار: خامة حقيقية بإحداثيات تتبع الجذع
static var _bark_mat: StandardMaterial3D = null
static func bark() -> StandardMaterial3D:
	if _bark_mat != null:
		return _bark_mat
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("bark_albedo.png")
	m.normal_enabled = true
	m.normal_texture = _tex("bark_normal.png")
	m.normal_scale = 1.1
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.93
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_bark_mat = m
	return m

## أوراق على بطاقات: قصّ ألفا لا شفافية مرتّبة — أرخص ولا يحتاج ترتيباً.
## الإضاءة من الوجهين لأن البطاقة سطح رقيق يُرى من الجهتين.
static var _leaf_mats: Dictionary = {}
static func leaf(kind: String) -> StandardMaterial3D:
	if _leaf_mats.has(kind):
		return _leaf_mats[kind]
	var files := {"needle": "leaf_needle.png", "broad": "leaf_broad.png", "grass": "grass_card.png"}
	var file: String = str(files.get(kind, "leaf_broad.png"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(file)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = foliage_tint
	m.roughness = 0.88
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# ضوء يتخلّل الورقة: يمنع الأوراق الخلفية من أن تصير صمّاء سوداء
	m.backlight_enabled = true
	m.backlight = Color(0.42, 0.52, 0.30)
	_leaf_mats[kind] = m
	_foliage_mats.append(m)
	return m

## نبات وحطام بلون الرأس وحده: نوع واحد = نداء رسم واحد
static func foliage(species: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = foliage_tint
	m.roughness = 0.94
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if species in ["fern", "grass", "willow", "bush"]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_foliage_mats.append(m)
	return m

## الماء: شادر بعمق وتدفّق وانعكاس فرنل، لا لوح أزرق شفّاف
static var _water_mat: ShaderMaterial = null
static func water() -> ShaderMaterial:
	if _water_mat != null:
		return _water_mat
	var sh: Shader = ResourceLoader.load("res://assets/shaders/water.gdshader")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("ripple_tex", _tex("water_normal.png"))
	m.render_priority = 1
	_water_mat = m
	return m


## خشب المباني والجسور
## الخشب والحجر: خامات PBR مصوّرة (Poly Haven، CC0) بخريطة ORM واحدة
## (أحمر=حجب، أخضر=خشونة، أزرق=معدنية) — وهي تماماً ترتيب خرائط arm.
##
## كانت هذه الخامات تضرب لوناً غامقاً في خامة غامقة أصلاً
## (0.30 × 0.25 ≈ 0.07) فتخرج المباني سوداء في وضح النهار.
## اللون الآن تعديل خفيف حول الأبيض، والتفصيل من الصورة.
static var _orm_cache: Dictionary = {}

static func _orm(base: String, uv: float, tint: Color) -> ORMMaterial3D:
	var key := "%s|%.3f|%s" % [base, uv, tint]
	if _orm_cache.has(key):
		return _orm_cache[key]
	var m := ORMMaterial3D.new()
	m.albedo_texture = _pbr(base + "_diff_2k.jpg")
	m.normal_enabled = true
	m.normal_texture = _pbr(base + "_nor_2k.jpg")
	m.normal_scale = 0.85
	m.orm_texture = _pbr(base + "_arm_2k.jpg")
	m.albedo_color = tint
	m.uv1_scale = Vector3(uv, uv, uv)
	m.metallic = 0.0
	_orm_cache[key] = m
	return m

## لون النداء القديم كان يُضرب في الخامة فيُسوّدها؛ صار يُرفع إلى
## نطاق ضيق حول الأبيض ليبقى التمييز بين الخشب الفاتح والغامق.
static func _lift(c: Color, warm: float = 0.0) -> Color:
	var l := clampf(c.get_luminance(), 0.05, 1.0)
	var k := lerpf(0.78, 1.12, clampf(l * 2.4, 0.0, 1.0))
	# انحياز دافئ للخشب: الرمادي الصافي كان يسلبه لونه تحت سماء زرقاء
	return Color(k, k * lerpf(1.0, 0.94, warm), k * lerpf(1.0, 0.84, warm))

static func timber(tint: Color = Color(0.302, 0.235, 0.173)) -> ORMMaterial3D:
	return _orm("weathered_plank_siding", 2.6, _lift(tint, 1.0))

static func planks(tint: Color = Color.WHITE) -> ORMMaterial3D:
	return _orm("weathered_planks", 2.2, _lift(tint, 0.85))

static func roof(tint: Color = Color.WHITE) -> ORMMaterial3D:
	return _orm("roof_07", 2.2, _lift(tint))

static func stone(tint: Color = Color(0.46, 0.46, 0.47)) -> ORMMaterial3D:
	return _orm("lichen_rock", 2.2, _lift(tint).darkened(0.12))


static func plain(col: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

static func emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	return m
