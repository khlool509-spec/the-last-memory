extends Node
## مدير الرسومات: يحوّل كل إعداد إلى تغيير حقيقي في المصيّر.
## مسجَّل autoload باسم Graphics.
##
## لا شيء هنا تزييني: كل مفتاح يمسّ قياس التصيير أو خريطة الظل أو
## معدّل الإطارات أو تدرّج الألوان فعلاً. والقياس التكيّفي يقرأ زمن
## الإطار الحقيقي ويضبط القياس ليبلغ الهدف.

## مستويات الجودة — مضبوطة لكروت الجوال حصراً.
## SSAO و SSIL حُذفا: مصيّر Mobile لا يدعمهما، فإظهارهما في الإعدادات
## كان يَعِد بما لا يُنفَّذ. ما بقي كله يمسّ الصورة فعلاً على الجهاز:
## قياس التصيير، حجم خريطة الظل، دقّة الخامات، حدّ الـLOD، المسافة.
## وأعلى مستوى لا يتجاوز قياس 1.0 — فوق ذلك يعني تصيير 4000 بكسل
## عرضاً على شاشة 1440، وهو ما كان يُنتج سبعة فريم.
const QUALITY := {
	"lite":         {"scale": 0.50, "shadow": 0,    "tex": "512", "aniso": 0,
		"lod": 12.0, "aa": false, "glow": false, "far": 110.0, "label": "مخففة"},
	"ultra_smooth": {"scale": 0.62, "shadow": 1024, "tex": "512", "aniso": 0,
		"lod": 9.0,  "aa": false, "glow": false, "far": 140.0, "label": "سلاسة فائقة"},
	"smooth":       {"scale": 0.72, "shadow": 1024, "tex": "1k",  "aniso": 1,
		"lod": 7.0,  "aa": false, "glow": true,  "far": 170.0, "label": "سلسة"},
	"balanced":     {"scale": 0.85, "shadow": 2048, "tex": "1k",  "aniso": 1,
		"lod": 5.0,  "aa": false, "glow": true,  "far": 200.0, "label": "متوازنة"},
	"hd":           {"scale": 1.00, "shadow": 2048, "tex": "1k",  "aniso": 2,
		"lod": 4.0,  "aa": true,  "glow": true,  "far": 230.0, "label": "عالية الدقة"},
	"hdr":          {"scale": 1.00, "shadow": 4096, "tex": "1k",  "aniso": 2,
		"lod": 3.0,  "aa": true,  "glow": true,  "far": 260.0, "label": "HDR"},
	"ultra_hdr":    {"scale": 1.00, "shadow": 4096, "tex": "1k",  "aniso": 3,
		"lod": 2.0,  "aa": true,  "glow": true,  "far": 300.0, "label": "فائق HDR"},
}
const QUALITY_ORDER := ["lite", "ultra_smooth", "smooth", "balanced", "hd",
	"hdr", "ultra_hdr"]

## مستويات قديمة محفوظة من نسخ سابقة تُترجم إلى أقرب مستوى جوالي
const QUALITY_ALIAS := {"high_hdr": "ultra_hdr"}

## طبقات معدّل الإطارات
const FPS_TIER := {
	"power_save":    {"fps": 24,  "label": "توفير الطاقة"},
	"medium":        {"fps": 30,  "label": "متوسطة"},
	"high":          {"fps": 40,  "label": "مرتفع"},
	"ultra":         {"fps": 50,  "label": "فائقة"},
	"strong":        {"fps": 60,  "label": "قوية"},
	"extreme_plus":  {"fps": 90,  "label": "إكستريم+"},
	"ultra_extreme": {"fps": 120, "label": "ألترا إكستريم"},
}
const FPS_ORDER := ["power_save", "medium", "high", "ultra", "strong",
	"extreme_plus", "ultra_extreme"]

## أنماط الرسوم: تدرّج لوني حقيقي لا ترشيح سطحي
const STYLE := {
	"classic":   {"sat": 1.00, "con": 1.00, "exp": 1.00, "tone": 3, "label": "كلاسيكي"},
	"vivid":     {"sat": 1.34, "con": 1.12, "exp": 1.06, "tone": 3, "label": "زاه"},
	"realistic": {"sat": 0.96, "con": 1.04, "exp": 0.98, "tone": 3, "label": "واقعي"},
	"soft":      {"sat": 0.88, "con": 0.92, "exp": 1.04, "tone": 1, "label": "ناعم"},
	"cinematic": {"sat": 0.82, "con": 1.18, "exp": 0.94, "tone": 2, "label": "سينمائي"},
}
const STYLE_ORDER := ["classic", "vivid", "realistic", "soft", "cinematic"]

## أنماط عمى الألوان — تصحيح حقيقي (daltonization) لا تلوين
const CB_ORDER := ["none", "deuteranopia", "protanopia", "tritanopia"]
const CB_LABEL := {"none": "عادية", "deuteranopia": "عمى اللون الأخضر",
	"protanopia": "عمى اللون الأحمر", "tritanopia": "عمى اللون الأزرق"}

## الإعدادات الجاهزة
const PRESETS := {
	"fps":      {"gfx_quality": "smooth", "gfx_fps_tier": "extreme_plus",
		"gfx_shadows": false, "gfx_antialiasing": false, "gfx_adaptive": true},
	"balanced": {"gfx_quality": "balanced", "gfx_fps_tier": "strong",
		"gfx_shadows": true, "gfx_antialiasing": true, "gfx_adaptive": true},
	"quality":  {"gfx_quality": "ultra_hdr", "gfx_fps_tier": "high",
		"gfx_shadows": true, "gfx_antialiasing": true, "gfx_adaptive": false},
	"lite":     {"gfx_quality": "lite", "gfx_fps_tier": "medium",
		"gfx_shadows": false, "gfx_antialiasing": false, "gfx_adaptive": true},
}

signal applied(summary: String)

var _vp: Viewport = null
var _env: Environment = null
var _sun: DirectionalLight3D = null
var _cb_layer: CanvasLayer = null
var _cb_rect: ColorRect = null
var _fps_label: Label = null

# القياس التكيّفي
var _adaptive_scale := 1.0
var _frame_acc := 0.0
var _frame_n := 0
var _measured_fps := 0.0
var _tex_manual := false        # صحيح إذا غيّر اللاعب دقّة الخامات بنفسه
var _applied_tex := ""          # الدقّة المطبَّقة فعلاً على المواد

## ══════════════ كشف قوة الجهاز ══════════════
## يُنفَّذ مرة واحدة عند أول تشغيل، أو عند طلب اللاعب «تلقائي».
## لا تخمين في الفراغ: ثلاثة مؤشّرات حقيقية من النظام.
const TIER_BY_SCORE := [
	[0,  "lite"], [3, "ultra_smooth"], [5, "smooth"],
	[7,  "balanced"], [9, "hd"], [11, "ultra_hdr"],
]

## معالجات الرسوم المعروفة ودرجاتها. الرقم بعد الاسم هو الجيل،
## وهو أدقّ مؤشّر متاح من داخل المحرّك.
static func _gpu_score(name: String) -> int:
	var n := name.to_lower()
	var num := 0
	var digits := ""
	for ch in n:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	if digits != "":
		num = int(digits)
	if n.contains("adreno"):
		if num >= 740: return 5      # 8 Gen 3 وما بعده
		if num >= 730: return 4      # 8 Gen 1/2
		if num >= 640: return 3
		if num >= 610: return 2
		return 1
	if n.contains("mali"):
		if num >= 710: return 4      # Immortalis / G7xx
		if num >= 610: return 3
		if num >= 57:  return 2
		return 1
	if n.contains("xclipse"):
		return 4                     # Samsung RDNA
	if n.contains("powervr") or n.contains("apple"):
		return 4
	if n.contains("llvmpipe") or n.contains("lavapipe") or n.contains("software"):
		return 0                     # تصيير برمجي — ليس جهازاً حقيقياً
	return 2                         # مجهول: وسط محافظ

## يُرجع اسم مستوى الجودة المناسب لهذا الجهاز
func detect_device_tier() -> String:
	var gpu := RenderingServer.get_video_adapter_name()
	var score := _gpu_score(gpu)

	# الذاكرة الفيزيائية: أكبر قيد على الخامات
	var ram_gb := 0.0
	var mem := OS.get_memory_info()
	if mem.has("physical") and int(mem["physical"]) > 0:
		ram_gb = float(mem["physical"]) / 1073741824.0
	if ram_gb >= 11.0:   score += 3
	elif ram_gb >= 7.0:  score += 2
	elif ram_gb >= 5.0:  score += 1
	elif ram_gb > 0.0 and ram_gb < 3.5: score -= 2

	# عدد النوى: مؤشّر ثانوي
	var cores := OS.get_processor_count()
	if cores >= 8: score += 1
	elif cores <= 4: score -= 1

	var tier := "balanced"
	for pair in TIER_BY_SCORE:
		if score >= int(pair[0]):
			tier = str(pair[1])
	_last_detect = "%s · %.1f GB · %d نوى → %d نقاط → %s" % [
		gpu, ram_gb, cores, score, str(QUALITY[tier]["label"])]
	print("[Graphics] كشف الجهاز: ", _last_detect)
	return tier

var _last_detect := ""

func last_detect_report() -> String:
	return _last_detect

## يطبّق المستوى المكتشَف ويثبّت الإعداد على «تلقائي»
func apply_auto_detect() -> void:
	var tier := detect_device_tier()
	_applying_preset = true
	Settings.set_value("gfx_quality", tier)
	Settings.set_value("gfx_texture_res", str(QUALITY[tier]["tex"]))
	Settings.set_value("gfx_adaptive", true)
	# سقف الإطارات يتبع القوة: جهاز ضعيف يثبت على 30 أنفع من تذبذب
	var i := QUALITY_ORDER.find(tier)
	Settings.set_value("gfx_fps_tier",
		"medium" if i <= 1 else ("strong" if i <= 4 else "extreme_plus"))
	Settings.set_value("gfx_preset", "auto")
	Settings.set_value("gfx_auto_detected", true)
	_applying_preset = false
	_tex_manual = false
	apply_all()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = get_viewport()
	_build_colorblind_layer()
	_build_fps_overlay()
	Settings.changed.connect(_on_setting)
	if not bool(Settings.get_value("gfx_auto_detected")):
		call_deferred("apply_auto_detect")   # أول تشغيل: نختار للجهاز
	else:
		call_deferred("apply_all")

## يُستدعى من الفصل بعد بناء البيئة والشمس
func bind_world(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	apply_all()

func quality_label(k: String) -> String:
	return str(QUALITY.get(k, {}).get("label", k))

func fps_label(k: String) -> String:
	return str(FPS_TIER.get(k, {}).get("label", k))

func style_label(k: String) -> String:
	return str(STYLE.get(k, {}).get("label", k))

func measured_fps() -> float:
	return _measured_fps

var _applying_preset := false

func _on_setting(key: String, _v: Variant) -> void:
	if not (key.begins_with("gfx_") or key == "ui_safe_area"):
		return
	if key == "gfx_show_fps":
		_refresh_fps_overlay()
	if key == "gfx_texture_res" and not _applying_preset:
		_tex_manual = true
	if key == "gfx_preset":
		_applying_preset = true
		_apply_preset(str(Settings.get_value("gfx_preset")))
		_applying_preset = false
	elif not _applying_preset and key != "gfx_fps_cap":
		# تعديل يدوي لأي مفتاح يعني أن الإعداد لم يعد جاهزاً
		if str(Settings.get_value("gfx_preset")) != "custom":
			_applying_preset = true
			Settings.set_value("gfx_preset", "custom")
			_applying_preset = false
	apply_all()

func _apply_preset(name: String) -> void:
	if name == "auto":
		apply_auto_detect()          # يختار المستوى من قدرات الجهاز
		return
	if not PRESETS.has(name):
		return                       # "custom" لا يغيّر شيئاً
	for k in PRESETS[name]:
		Settings.set_value(k, PRESETS[name][k])

func apply_all() -> void:
	var q := str(Settings.get_value("gfx_quality"))
	if QUALITY_ALIAS.has(q):
		q = str(QUALITY_ALIAS[q])
		Settings.set_value("gfx_quality", q)   # ترقية إعداد محفوظ من نسخة قديمة
	if not QUALITY.has(q):
		q = "balanced"
	var spec: Dictionary = QUALITY[q]
	var power := bool(Settings.get_value("gfx_power_save"))

	# 1) قياس التصيير — أقوى رافعة أداء على الجوال
	var scale := float(spec["scale"])
	if power:
		scale = minf(scale, 0.70)
	scale *= _adaptive_scale
	if _vp:
		_vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_vp.scaling_3d_scale = clampf(scale, 0.45, 2.0)
		# 2) إزالة التسنّن
		# MSAA على كروت الجوال رخيص نسبياً (tile-based) لكنه ليس مجانياً:
		# يُفعَّل فقط إذا سمح المستوى وطلبه اللاعب.
		var aa := bool(spec["aa"]) and bool(Settings.get_value("gfx_antialiasing")) \
			and not power
		_vp.msaa_3d = Viewport.MSAA_2X if aa else Viewport.MSAA_DISABLED
		_vp.mesh_lod_threshold = float(spec["lod"])

	# 3) الظلال: خريطة الظل وحجمها
	var atlas := int(spec["shadow"])
	var shadows := bool(Settings.get_value("gfx_shadows")) and not power and atlas > 0
	if atlas > 0:
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	if _sun:
		_sun.shadow_enabled = shadows

	# 4) الحجب والارتداد
	if _env:
		# مصيّر Mobile لا يدعم SSAO ولا SSIL — نضمن إيقافهما بدل الوعد بهما
		_env.ssao_enabled = false
		_env.ssil_enabled = false
		_env.glow_enabled = bool(spec["glow"]) and not power
		# 5) نمط الرسوم: تدرّج لوني حقيقي
		var st := str(Settings.get_value("gfx_style"))
		if not STYLE.has(st):
			st = "classic"
		var s: Dictionary = STYLE[st]
		_env.adjustment_enabled = true
		_env.adjustment_saturation = float(s["sat"])
		_env.adjustment_contrast = float(s["con"])
		_env.tonemap_mode = int(s["tone"]) as Environment.ToneMapper
		_env.set_meta("style_exposure", float(s["exp"]))

	# 6) دقّة الخامات: أكبر رافعة لذاكرة الـGPU بعد قياس التصيير
	var want_tex := str(spec["tex"])
	if power:
		want_tex = "512"
	if str(Settings.get_value("gfx_texture_res")) != want_tex and not _tex_manual:
		_applying_preset = true
		Settings.set_value("gfx_texture_res", want_tex)
		_applying_preset = false
	if _applied_tex != str(Settings.get_value("gfx_texture_res")):
		_applied_tex = str(Settings.get_value("gfx_texture_res"))
		WorldMaterials.reload_textures()      # تبديل فوري على المواد القائمة
	# خرائط الإزاحة الموازية: أثقل حلقة في شيدر الأرض
	WorldMaterials.set_pom(QUALITY_ORDER.find(q) >= 3 and not power)

	# 7) ترشيح تباين الاتجاه
	ProjectSettings.set_setting(
		"rendering/textures/default_filters/anisotropic_filtering_level", int(spec["aniso"]))

	# 8) سقف معدّل الإطارات
	var tier := str(Settings.get_value("gfx_fps_tier"))
	var cap := int(FPS_TIER.get(tier, {}).get("fps", 60))
	if bool(Settings.get_value("gfx_fps_manual")):
		cap = int(Settings.get_value("gfx_fps_cap"))
	if power:
		cap = mini(cap, 30)
	Engine.max_fps = clampi(cap, 20, 144)

	# 8) إزاحة الشاشات غير القياسية: هامش علوي حقيقي للواجهة
	_apply_safe_area()

	# 9) عمى الألوان
	_update_colorblind()
	applied.emit("%s · %d إطاراً · قياس %.0f%%" % [
		quality_label(q), Engine.max_fps, (_vp.scaling_3d_scale if _vp else 1.0) * 100.0])

func _process(delta: float) -> void:
	# قياس زمن الإطار الحقيقي ثم الضبط التكيّفي نحو الهدف
	_frame_acc += delta
	_frame_n += 1
	if _frame_acc < 1.0:
		return
	_measured_fps = float(_frame_n) / _frame_acc
	_frame_acc = 0.0
	_frame_n = 0
	_refresh_fps_overlay()
	if not bool(Settings.get_value("gfx_adaptive")):
		if not is_equal_approx(_adaptive_scale, 1.0):
			_adaptive_scale = 1.0
			apply_all()
		return
	var target := float(Engine.max_fps) * 0.92
	var before := _adaptive_scale
	if _measured_fps < target * 0.82:
		_adaptive_scale = maxf(_adaptive_scale - 0.06, 0.62)
	elif _measured_fps > target * 1.06:
		_adaptive_scale = minf(_adaptive_scale + 0.03, 1.0)
	if not is_equal_approx(before, _adaptive_scale):
		apply_all()

## الهامش يُطبَّق على كل Control جذري في طبقات الواجهة، فيبتعد
## المحتوى عن القصّة العلوية في الشاشات المقوّسة.
func _apply_safe_area() -> void:
	var frac := clampf(float(Settings.get_value("ui_safe_area")), 0.0, 1.0)
	var px := frac * 110.0
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for cl in tree.current_scene.find_children("*", "CanvasLayer", true, false):
		for c in cl.get_children():
			if c is Control and (c as Control).anchors_preset == Control.PRESET_FULL_RECT:
				(c as Control).offset_top = px

# ---------------- عمى الألوان ----------------
## ══════════════ عدّاد الإطارات ══════════════
## لا يُقاس أداء الجوال من جهاز آخر. هذا العدّاد يعرض الرقم الحقيقي
## على الجهاز نفسه مع المستوى المطبَّق وقياس التصيير، حتى يكون
## الضبط التالي مبنياً على قياس لا على تخمين.
func _build_fps_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FpsLayer"
	layer.layer = 127
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fps_label.position = Vector2(16, 12)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.62))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.visible = false
	layer.add_child(_fps_label)
	add_child(layer)

func _refresh_fps_overlay() -> void:
	if _fps_label == null:
		return
	_fps_label.visible = bool(Settings.get_value("gfx_show_fps"))
	if not _fps_label.visible:
		return
	var q := str(Settings.get_value("gfx_quality"))
	var sc := 0.0
	if _vp:
		sc = _vp.scaling_3d_scale
	_fps_label.text = "%d FPS   %s   قياس %.2f   خامات %s" % [
		int(round(_measured_fps)), quality_label(q), sc,
		str(Settings.get_value("gfx_texture_res"))]

func _build_colorblind_layer() -> void:
	_cb_layer = CanvasLayer.new()
	_cb_layer.name = "ColorBlindLayer"
	_cb_layer.layer = 128            # فوق كل شيء بما فيه الواجهة
	_cb_rect = ColorRect.new()
	_cb_rect.name = "ColorBlindRect"
	_cb_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = ResourceLoader.load("res://assets/shaders/colorblind.gdshader")
	if sh:
		var m := ShaderMaterial.new()
		m.shader = sh
		_cb_rect.material = m
	_cb_rect.visible = false
	_cb_layer.add_child(_cb_rect)
	add_child(_cb_layer)

func _update_colorblind() -> void:
	if _cb_rect == null:
		return
	var mode := str(Settings.get_value("gfx_colorblind"))
	var idx := CB_ORDER.find(mode)
	if idx <= 0:
		_cb_rect.visible = false
		return
	_cb_rect.visible = true
	var m := _cb_rect.material as ShaderMaterial
	if m:
		m.set_shader_parameter("mode", idx)
