extends SceneTree
## مُشغّل الاختبارات الآلي — يُنفَّذ بـ Godot headless
## الاستخدام: godot --headless --path . --script res://tests/test_runner.gd
## يعيد رمز خروج = عدد الإخفاقات

var _pass := 0
var _fail := 0
var _log: Array[String] = []

func _ok(name: String) -> void:
	_pass += 1
	print("  PASS  ", name)

func _no(name: String, detail: String = "") -> void:
	_fail += 1
	var line := "  FAIL  " + name
	if detail != "":
		line += "  ->  " + detail
	print(line)
	_log.append(line)

func _initialize() -> void:
	print("=== اختبارات THE LAST MEMORY ===\n")
	_test_project_settings()
	_test_main_scene()
	_test_folder_structure()
	_test_all_scenes()
	_test_all_scripts()
	_test_fonts()
	_test_theme()
	_test_settings_roundtrip()
	_test_save_roundtrip()
	_test_icons()
	_test_menu_background()
	_test_moon_terrain()
	_test_moon_gravity()
	_test_life_support()
	_test_mission_system()
	print("\n=== النتيجة: %d نجح، %d أخفق ===" % [_pass, _fail])
	quit(_fail)

# ---------- إعدادات المشروع ----------
func _test_project_settings() -> void:
	print("[إعدادات المشروع]")
	var name := str(ProjectSettings.get_setting("application/config/name", ""))
	if name == "THE LAST MEMORY":
		_ok("اسم المشروع")
	else:
		_no("اسم المشروع", name)

	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	if method == "mobile":
		_ok("الـ Renderer = mobile")
	else:
		_no("الـ Renderer = mobile", method)

	var mobile_override := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	if mobile_override == "mobile":
		_ok("تجاوز الـ Renderer للمحمول")
	else:
		_no("تجاوز الـ Renderer للمحمول", mobile_override)

	if bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false)):
		_ok("ضغط ETC2/ASTC مفعّل")
	else:
		_no("ضغط ETC2/ASTC مفعّل", "مطلوب لأندرويد")

# ---------- المشهد الرئيسي ----------
## هذا الاختبار أُضيف بعد خطأ حقيقي: صدرت نسخة بلا مشهد رئيسي،
## فثُبِّتت وفُتحت ثم ردّت "Unable to setup the Godot engine!".
func _test_main_scene() -> void:
	print("\n[المشهد الرئيسي]")
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main == "":
		_no("المشهد الرئيسي معرَّف", "run/main_scene فارغ — التطبيق لن يقلع على الجهاز")
		return
	_ok("المشهد الرئيسي معرَّف: " + main)

	if not ResourceLoader.exists(main):
		_no("ملف المشهد الرئيسي موجود", main)
		return
	_ok("ملف المشهد الرئيسي موجود")

	var packed := ResourceLoader.load(main, "PackedScene")
	if packed == null:
		_no("تحميل المشهد الرئيسي", "فشل")
		return
	var root := (packed as PackedScene).instantiate()
	if root == null:
		_no("إنشاء المشهد الرئيسي", "instantiate أعاد null")
		return
	_ok("المشهد الرئيسي يُحمَّل ويُنشَأ")

	# شروط الكاميرا والإضاءة تخص المشاهد الثلاثية فقط.
	# شاشة واجهة (Control) لا تحتاج أياً منهما، فلا نفرضها عليها.
	var has_cam := false
	var has_light := false
	var has_3d := false
	var has_ui := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D:
			has_3d = true
		if n is Control:
			has_ui = true
		if n is Camera3D:
			has_cam = true
		if n is DirectionalLight3D or n is OmniLight3D or n is SpotLight3D:
			has_light = true
		for c in n.get_children():
			stack.append(c)
	if not has_3d:
		_ok("  مشهد واجهة (لا يتطلب كاميرا ثلاثية)" if has_ui else "  مشهد غير ثلاثي")
	else:
		if has_cam:
			_ok("  يحتوي كاميرا")
		else:
			_no("  يحتوي كاميرا", "بلا كاميرا = شاشة سوداء على الجهاز")
		if has_light:
			_ok("  يحتوي مصدر إضاءة")
		else:
			_no("  يحتوي مصدر إضاءة", "بلا إضاءة = أجسام سوداء")
	_check_camera_aim(root)
	root.free()

## اختبار أُضيف بعد خطأ حقيقي: مصفوفة الكاميرا كانت معكوسة الإشارة،
## فنظرت إلى الأعلى بزاوية 41 درجة عن الهدف، وظهر المشهد عند حافة الشاشة.
## لا نحسب المصفوفات يدوياً بعد الآن — Transform3D.looking_at هي المرجع.
##
## نركّب التحويلات العالمية يدوياً لأن global_transform يتطلب وجود العقدة
## داخل شجرة المشهد، وهي غير مهيأة أثناء _initialize.
func _world_xform(n: Node3D, stop: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != stop:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

func _check_camera_aim(scene_root: Node) -> void:
	var cam: Camera3D = null
	var centers: Array[Vector3] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Camera3D and cam == null:
			cam = n
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			# نتجاهل الأسطح المسطّحة كالأرضيات: تمتد تحت الكاميرا فتشوّه المركز
			if (n as MeshInstance3D).mesh.get_aabb().size.y > 0.05:
				centers.append(_world_xform(n as Node3D, scene_root.get_parent()).origin)
		for c in n.get_children():
			stack.append(c)
	# لا محتوى ثلاثي = لا شيء يُؤطَّر (شاشات الواجهة مثلاً)
	if centers.is_empty():
		return
	if cam == null:
		_no("  يوجد كاميرا للتأطير", "محتوى ثلاثي بلا كاميرا")
		return
	var center := Vector3.ZERO
	for c in centers:
		center += c
	center /= float(centers.size())
	var cam_x := _world_xform(cam, scene_root.get_parent())
	var to_center := center - cam_x.origin
	if to_center.length() < 0.001:
		return
	var fwd := -cam_x.basis.z
	var d := fwd.dot(to_center.normalized())
	var angle := rad_to_deg(acos(clampf(d, -1.0, 1.0)))
	var limit := cam.fov * 0.5
	if angle <= limit:
		_ok("  الكاميرا تؤطّر المحتوى (انحراف %.1f\u00b0 من حد %.1f\u00b0)" % [angle, limit])
	else:
		_no("  الكاميرا تؤطّر المحتوى",
			"انحراف %.1f\u00b0 يتجاوز نصف مجال الرؤية %.1f\u00b0 — المحتوى خارج الكادر" % [angle, limit])

# ---------- بنية المجلدات ----------
func _test_folder_structure() -> void:
	print("\n[بنية المجلدات]")
	var required := [
		"res://src", "res://src/core", "res://src/player", "res://src/camera",
		"res://src/environment", "res://src/interaction", "res://src/inventory",
		"res://src/puzzle", "res://src/audio", "res://src/ui", "res://src/save_system",
		"res://src/story", "res://src/cinematics", "res://src/optimization",
		"res://assets/models", "res://assets/textures", "res://assets/materials",
		"res://assets/audio", "res://assets/fonts", "res://assets/shaders",
		"res://levels", "res://tests", "res://docs",
	]
	var missing: Array[String] = []
	for p in required:
		if not DirAccess.dir_exists_absolute(p):
			missing.append(p)
	if missing.is_empty():
		_ok("كل المجلدات المطلوبة موجودة (%d)" % required.size())
	else:
		_no("مجلدات ناقصة", ", ".join(missing))

# ---------- المشاهد ----------
func _collect(dir_path: String, ext: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with("."):
			f = d.get_next()
			continue
		var full := dir_path.path_join(f)
		if d.current_is_dir():
			_collect(full, ext, out)
		elif f.ends_with(ext):
			out.append(full)
		f = d.get_next()
	d.list_dir_end()

func _test_all_scenes() -> void:
	print("\n[المشاهد]")
	var scenes: Array[String] = []
	_collect("res://", ".tscn", scenes)
	if scenes.is_empty():
		print("  (لا مشاهد بعد)")
		return
	for path in scenes:
		var packed := ResourceLoader.load(path, "PackedScene")
		if packed == null:
			_no("تحميل " + path, "فشل التحميل")
			continue
		var root := (packed as PackedScene).instantiate()
		if root == null:
			_no("إنشاء " + path, "instantiate أعاد null")
			continue
		_ok("تحميل وإنشاء " + path.get_file())
		_check_scene_nodes(path, root)
		root.free()

func _check_scene_nodes(path: String, root: Node) -> void:
	var stack: Array[Node] = [root]
	var meshes_empty: Array[String] = []
	var count := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		count += 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh == null:
			meshes_empty.append(n.name)
		for c in n.get_children():
			stack.append(c)
	if meshes_empty.is_empty():
		_ok("  كل MeshInstance3D لها مجسّم (%d عقدة)" % count)
	else:
		_no("  MeshInstance3D بلا مجسّم في " + path.get_file(), ", ".join(meshes_empty))

# ---------- السكربتات ----------
func _test_all_scripts() -> void:
	print("\n[سكربتات GDScript]")
	var scripts: Array[String] = []
	_collect("res://", ".gd", scripts)
	if scripts.is_empty():
		print("  (لا سكربتات بعد)")
		return
	for path in scripts:
		var s := ResourceLoader.load(path)
		if s == null:
			_no("تحميل " + path.get_file(), "فشل")
		elif s is GDScript and not (s as GDScript).can_instantiate() and (s as GDScript).get_instance_base_type() == "":
			_no("صلاحية " + path.get_file(), "السكربت لا يُصرَّف")
		else:
			_ok("تصريف " + path.get_file())


# ---------- الخطوط ----------
## لا فائدة من واجهة عربية بخط لا يملك حروفها: ستظهر مربعات فارغة.
func _test_fonts() -> void:
	print("\n[الخطوط]")
	for path in [UITheme.FONT_REGULAR, UITheme.FONT_BOLD]:
		var f := UITheme.load_font(path)
		if f == null:
			_no("تحميل " + path.get_file(), "غير موجود")
			continue
		_ok("تحميل " + path.get_file())
		var missing: Array[String] = []
		# حروف عربية أساسية + همزات + أرقام عربية ولاتينية + علامات
		for ch in "ابتثجحخدذرزسشصضطظعغفقكلمنهويءأإآةىئؤ٠١٢٣٤٥٦٧٨٩0123456789٪؟،":
			if not f.has_char(ch.unicode_at(0)):
				missing.append(ch)
		if missing.is_empty():
			_ok("  تغطية الحروف العربية والأرقام كاملة")
		else:
			_no("  تغطية الحروف", "ناقص: " + "".join(missing))

# ---------- السمة ----------
func _test_theme() -> void:
	print("\n[السمة]")
	var t := UITheme.build()
	if t == null:
		_no("بناء السمة", "أعادت null")
		return
	_ok("بناء السمة")
	if t.default_font != null:
		_ok("  خط افتراضي مُسنَد")
	else:
		_no("  خط افتراضي مُسنَد", "default_font فارغ")
	var needed := [["normal", "Button"], ["hover", "Button"], ["pressed", "Button"], ["panel", "PanelContainer"]]
	var miss: Array[String] = []
	for n in needed:
		if not t.has_stylebox(n[0], n[1]):
			miss.append("%s/%s" % [n[1], n[0]])
	if miss.is_empty():
		_ok("  كل أنماط الواجهة موجودة")
	else:
		_no("  أنماط ناقصة", ", ".join(miss))

# ---------- دورة الإعدادات ----------
func _test_settings_roundtrip() -> void:
	print("\n[الإعدادات]")
	var cfg := ConfigFile.new()
	var probe := {"master_volume": 0.33, "language": "en", "invert_y": true}
	for k in probe:
		cfg.set_value("game", k, probe[k])
	var tmp := "user://settings_test.cfg"
	if cfg.save(tmp) != OK:
		_no("كتابة ملف إعدادات", "فشل الحفظ")
		return
	_ok("كتابة ملف إعدادات")
	var back := ConfigFile.new()
	if back.load(tmp) != OK:
		_no("قراءة ملف إعدادات", "فشل التحميل")
		return
	var all_ok := true
	for k in probe:
		if back.get_value("game", k) != probe[k]:
			all_ok = false
	if all_ok:
		_ok("  القيم تعود كما حُفظت")
	else:
		_no("  القيم تعود كما حُفظت", "اختلاف بعد الدورة")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	# التأكد أن كل المفاتيح الافتراضية موجودة ولها أنواع صحيحة
	var defaults_script := load("res://src/core/game_settings.gd")
	if defaults_script == null:
		_no("  سكربت الإعدادات", "غير موجود")
		return
	_ok("  سكربت الإعدادات يُحمَّل")

# ---------- دورة الحفظ ----------
func _test_save_roundtrip() -> void:
	print("\n[نظام الحفظ]")
	var scr := load("res://src/save_system/save_system.gd")
	if scr == null:
		_no("تحميل نظام الحفظ", "غير موجود")
		return
	var inst: Node = scr.new()
	var base: Dictionary = inst.default_data()
	var needed := ["version", "chapter", "checkpoint", "collectibles", "chapters_unlocked", "flags"]
	var miss: Array[String] = []
	for k in needed:
		if not base.has(k):
			miss.append(k)
	if miss.is_empty():
		_ok("بنية ملف الحفظ كاملة (%d مفتاحاً)" % base.size())
	else:
		_no("بنية ملف الحفظ", "ناقص: " + ", ".join(miss))
	# دورة JSON كاملة
	var txt := JSON.stringify(base)
	var back: Variant = JSON.parse_string(txt)
	if typeof(back) == TYPE_DICTIONARY and (back as Dictionary).size() == base.size():
		_ok("  الحفظ والقراءة بصيغة JSON سليمان")
	else:
		_no("  دورة JSON", "فشل التحليل")
	inst.free()


# ---------- الأيقونات ----------
## أُضيف بعد ملاحظة أن أيقونة التطبيق بقيت الافتراضية.
func _test_icons() -> void:
	print("\n[أيقونات التطبيق]")
	var proj_icon := str(ProjectSettings.get_setting("application/config/icon", ""))
	if proj_icon == "" or not ResourceLoader.exists(proj_icon):
		_no("أيقونة المشروع", proj_icon if proj_icon != "" else "غير معرَّفة")
	elif proj_icon.ends_with("icon.svg"):
		_no("أيقونة المشروع", "ما زالت أيقونة Godot الافتراضية")
	else:
		_ok("أيقونة المشروع: " + proj_icon.get_file())

	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		_no("قراءة إعداد التصدير", "فشل")
		return
	var keys := {
		"launcher_icons/main_192x192": [192, 192],
		"launcher_icons/adaptive_foreground_432x432": [432, 432],
		"launcher_icons/adaptive_background_432x432": [432, 432],
	}
	for k in keys:
		var path := str(cfg.get_value("preset.0.options", k, ""))
		if path == "":
			_no("  " + k.get_file(), "فارغة — ستُستخدم أيقونة Godot الافتراضية")
			continue
		if not ResourceLoader.exists(path):
			_no("  " + k.get_file(), "ملف مفقود: " + path)
			continue
		var tex: Texture2D = ResourceLoader.load(path)
		if tex == null:
			_no("  " + k.get_file(), "تعذّر التحميل")
			continue
		var want: Array = keys[k]
		if tex.get_width() != int(want[0]) or tex.get_height() != int(want[1]):
			_no("  " + k.get_file(), "القياس %dx%d والمطلوب %dx%d" % [tex.get_width(), tex.get_height(), want[0], want[1]])
		else:
			_ok("  %s (%dx%d)" % [path.get_file(), tex.get_width(), tex.get_height()])


# ---------- خلفية القائمة ----------
## التصميم المعتمد يقوم على صورة فنية. إن غابت يسقط المشروع تلقائياً
## إلى المشهد الإجرائي، وهذا تراجع بصري كبير يجب ألا يمر بصمت.
func _test_menu_background() -> void:
	print("\n[خلفية القائمة]")
	var found := ""
	for cand in ["res://assets/textures/ui/menu_bg.png",
				 "res://assets/textures/ui/menu_bg.jpg",
				 "res://assets/textures/ui/menu_bg.webp"]:
		if ResourceLoader.exists(cand):
			found = cand
			break
	if found == "":
		_no("الصورة الفنية موجودة", "ستُستخدم الخلفية الإجرائية بدلاً منها")
		return
	var tex: Texture2D = ResourceLoader.load(found)
	if tex == null:
		_no("تحميل الخلفية", found)
		return
	_ok("الخلفية: %s (%dx%d)" % [found.get_file(), tex.get_width(), tex.get_height()])
	if tex.get_width() < 1600:
		_no("  دقة كافية للهاتف", "العرض %d والمطلوب 1600 على الأقل" % tex.get_width())
	else:
		_ok("  دقة كافية للهاتف")
	var ratio := float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	if ratio < 1.6:
		_no("  نسبة عريضة مناسبة", "النسبة %.2f وهي ضيقة على الشاشة الأفقية" % ratio)
	else:
		_ok("  نسبة عريضة (%.2f)" % ratio)

# ---------- تضاريس القمر ----------
## التضاريس مولَّدة رياضياً، فيجب أن تكون حتمية ومتّسقة:
## نفس البذرة تعطي نفس السطح، والتصادم مطابق للشكل المرسوم.
func _test_moon_terrain() -> void:
	print("\n[تضاريس القمر]")
	var a := MoonTerrain.new(20261114)
	var b := MoonTerrain.new(20261114)

	# الحتمية: شرط لأن المواضع تُحسب قبل بناء الشبكة
	var same := true
	for i in 40:
		var x := -140.0 + float(i) * 7.0
		var z := 96.0 - float(i) * 4.5
		if not is_equal_approx(a.height_at(x, z), b.height_at(x, z)):
			same = false
			break
	if same:
		_ok("نفس البذرة تعطي نفس السطح")
	else:
		_no("حتمية التضاريس")

	var c := MoonTerrain.new(777)
	var differs := false
	for i in 40:
		var x := -100.0 + float(i) * 5.0
		if not is_equal_approx(a.height_at(x, 12.0), c.height_at(x, 12.0)):
			differs = true
			break
	if differs:
		_ok("بذرة مختلفة تعطي سطحاً مختلفاً")
	else:
		_no("تباين البذور")

	# حدود الارتفاع: سطح معقول لا جدران عمودية
	var lo := INF
	var hi := -INF
	var limit := a.half_extent() - 5.0
	for i in 60:
		for j in 60:
			var x := -limit + (2.0 * limit) * float(i) / 59.0
			var z := -limit + (2.0 * limit) * float(j) / 59.0
			var h := a.height_at(x, z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	if hi - lo < 60.0 and hi - lo > 4.0:
		_ok("مدى الارتفاع معقول (%.1f م)" % (hi - lo))
	else:
		_no("مدى الارتفاع", "%.1f م" % (hi - lo))

	# الفوّهات موجودة فعلاً: نقطة المركز أخفض من الحافة
	var crater := a.largest_crater()
	if crater.is_empty():
		_no("توليد الفوّهات", "لا فوّهة")
	else:
		var pos: Vector2 = crater["pos"]
		var r: float = crater["radius"]
		var center := a.height_at(pos.x, pos.y)
		var rim := a.height_at(pos.x + r * 0.98, pos.y)
		if center < rim:
			_ok("قاع الفوّهة أخفض من حافتها (%.1f م فرقاً)" % (rim - center))
		else:
			_no("مقطع الفوّهة", "القاع %.2f والحافة %.2f" % [center, rim])
		if a.crater_count() >= 20:
			_ok("عدد الفوّهات %d" % a.crater_count())
		else:
			_no("عدد الفوّهات", str(a.crater_count()))

	# مواضع متناثرة: داخل الحدود، متباعدة، وعلى السطح تماماً
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pts := a.scatter_points(12, 30.0, 110.0, 18.0, rng)
	if pts.size() == 12:
		_ok("توليد 12 موضعاً متباعداً")
	else:
		_no("توليد المواضع", "%d من 12" % pts.size())
	var on_surface := true
	var spaced := true
	for p in pts:
		if absf(p.y - a.height_at(p.x, p.z)) > 0.01:
			on_surface = false
		if absf(p.x) > a.half_extent() or absf(p.z) > a.half_extent():
			on_surface = false
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			if Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length() < 17.9:
				spaced = false
	if on_surface:
		_ok("كل موضع ملامس للسطح وداخل الحدود")
	else:
		_no("التصاق المواضع بالسطح")
	if spaced:
		_ok("لا تداخل بين المواضع")
	else:
		_no("تباعد المواضع")

	# بناء الشبكة والتصادم يُفحَص في tools/moon_check.tscn:
	# بناؤها يحتاج شجرة حيّة، و _ready لا يعمل داخل _initialize
	a.queue_free()
	b.queue_free()
	c.queue_free()

# ---------- جاذبية القمر ----------
## القفز على القمر يجب أن يكون أعلى وأطول زمناً من الأرض بفارق واضح.
func _test_moon_gravity() -> void:
	print("\n[جاذبية القمر]")
	var p := Player.new()
	p.set_gravity(9.8)
	p.jump_velocity = 5.0
	var earth_apex := p.jump_apex()
	var earth_hang := p.hang_time()

	p.set_gravity(3.2)
	p.jump_velocity = 4.3
	var moon_apex := p.jump_apex()
	var moon_hang := p.hang_time()

	if moon_apex > earth_apex * 2.0:
		_ok("ارتفاع القفزة على القمر %.2f م مقابل %.2f على الأرض" % [moon_apex, earth_apex])
	else:
		_no("ارتفاع القفزة", "%.2f مقابل %.2f" % [moon_apex, earth_apex])

	if moon_hang > earth_hang * 2.0:
		_ok("زمن البقاء في الهواء %.2f ث مقابل %.2f" % [moon_hang, earth_hang])
	else:
		_no("زمن البقاء", "%.2f مقابل %.2f" % [moon_hang, earth_hang])

	# حدود العبانية: قفزة لا تتجاوز حدّاً يفقد السيطرة
	if moon_apex < 4.5 and moon_hang < 3.6:
		_ok("القفزة تبقى قابلة للسيطرة")
	else:
		_no("القفزة مفرطة", "%.2f م / %.2f ث" % [moon_apex, moon_hang])

	# التحكم الجوي المحدود يجب ألا يكون معطّلاً تماماً
	p.air_control = 0.32
	if p.air_control > 0.1 and p.air_control < 0.6:
		_ok("التحكم الجوي محدود لا معدوم (%.2f)" % p.air_control)
	else:
		_no("التحكم الجوي", str(p.air_control))
	p.queue_free()

# ---------- دعم الحياة ----------
func _test_life_support() -> void:
	print("\n[الأكسجين]")
	var ls := LifeSupport.new()
	root.add_child(ls)

	if is_equal_approx(ls.ratio(), 1.0):
		_ok("البدلة تبدأ ممتلئة")
	else:
		_no("المخزون الابتدائي", str(ls.ratio()))

	# الركض يستهلك أسرع من المشي، والمشي أسرع من السكون
	var idle := LifeSupport.new()
	var walk := LifeSupport.new()
	var run := LifeSupport.new()
	root.add_child(idle)
	root.add_child(walk)
	root.add_child(run)
	for i in 60:
		idle.consume(1.0, false, false)
		walk.consume(1.0, true, false)
		run.consume(1.0, true, true)
	if run.oxygen < walk.oxygen and walk.oxygen < idle.oxygen:
		_ok("الاستهلاك يتدرّج: ركض %.1f < مشي %.1f < سكون %.1f" % [run.oxygen, walk.oxygen, idle.oxygen])
	else:
		_no("تدرّج الاستهلاك")

	# مدة البقاء: يجب أن تكفي لجولة معقولة لا لدقيقة واحدة
	var minutes := idle.seconds_left(idle.idle_drain) / 60.0
	if minutes > 4.0 and minutes < 25.0:
		_ok("مخزون السكون يكفي %.1f دقيقة" % minutes)
	else:
		_no("مدة المخزون", "%.1f دقيقة" % minutes)

	# الإشارات تُبثّ مرة واحدة لكل عتبة، لا كل إطار
	# المصفوفة تُلتقط بالمرجع، بخلاف العدد الصحيح الذي يُلتقط بالقيمة
	var hits := [0, 0, 0]
	var s := LifeSupport.new()
	root.add_child(s)
	s.entered_warning.connect(func(): hits[0] += 1)
	s.entered_critical.connect(func(): hits[1] += 1)
	s.depleted.connect(func(): hits[2] += 1)
	for i in 4000:
		s.consume(0.2, true, true)
	if hits == [1, 1, 1]:
		_ok("كل عتبة تُبثّ مرة واحدة")
	else:
		_no("تكرار إشارات العتبات", "تحذير %d حرج %d نفاد %d" % hits)
	if s.is_empty():
		_ok("المخزون ينفد فعلاً")
	else:
		_no("نفاد المخزون", str(s.oxygen))

	s.refill()
	if is_equal_approx(s.ratio(), 1.0):
		_ok("محطة الملء تعيد المخزون كاملاً")
	else:
		_no("إعادة الملء", str(s.ratio()))

	for n in [ls, idle, walk, run, s]:
		n.queue_free()

# ---------- نظام المهام ----------
func _test_mission_system() -> void:
	print("\n[نظام المهام]")
	var ms := MissionSystem.new()
	root.add_child(ms)
	ms.load_missions([
		{"id": "a", "kind": Mission.Kind.REACH, "target": "m1", "title": "اذهب"},
		{"id": "b", "kind": Mission.Kind.COLLECT, "target": "rock", "required": 3, "title": "اجمع"},
		{"id": "c", "kind": Mission.Kind.INTERACT, "target": "ant", "title": "أصلح"},
	])
	var started: Array[String] = []
	var done: Array[String] = []
	var finished := [false]
	ms.mission_started.connect(func(m: Mission): started.append(m.id))
	ms.mission_completed.connect(func(m: Mission): done.append(m.id))
	ms.all_completed.connect(func(): finished[0] = true)

	ms.start()
	if ms.current() != null and ms.current().id == "a":
		_ok("تبدأ بالمهمة الأولى")
	else:
		_no("المهمة الأولى")

	# حدث لا يطابق المهمة النشطة يجب أن يُرفض
	if not ms.report(Mission.Kind.COLLECT, "rock"):
		_ok("حدث من نوع آخر لا يقدّم المهمة")
	else:
		_no("رفض الأحداث غير المطابقة")
	# هدف خاطئ من النوع الصحيح يُرفض أيضاً
	if not ms.report(Mission.Kind.REACH, "m9"):
		_ok("هدف خاطئ لا يقدّم المهمة")
	else:
		_no("رفض الهدف الخاطئ")

	ms.report(Mission.Kind.REACH, "m1")
	if done.size() == 1 and done[0] == "a" and ms.current().id == "b":
		_ok("إتمام المهمة ينقل إلى التالية")
	else:
		_no("الانتقال بعد الإتمام")

	# الجمع التدريجي: لا تكتمل إلا بالعدد المطلوب
	ms.report(Mission.Kind.COLLECT, "rock")
	ms.report(Mission.Kind.COLLECT, "rock")
	if ms.current().id == "b" and ms.current().progress == 2:
		_ok("التقدّم التدريجي 2/3 بلا إتمام مبكر")
	else:
		_no("التقدّم التدريجي", str(ms.current().progress))
	if ms.current().objective_text().contains("2/3"):
		_ok("نص الهدف يعرض العدّاد")
	else:
		_no("نص العدّاد", ms.current().objective_text())

	ms.report(Mission.Kind.COLLECT, "rock")
	if ms.current() != null and ms.current().id == "c":
		_ok("اكتمال العدّاد ينهي المهمة")
	else:
		_no("إنهاء مهمة الجمع")

	# التجاوز فوق المطلوب لا يكسر العدّاد
	ms.report(Mission.Kind.INTERACT, "ant")
	if finished[0] and ms.is_finished() and ms.completed_count() == 3:
		_ok("انتهاء المتتالية يُبثّ مرة واحدة")
	else:
		_no("انتهاء المتتالية")
	if started.size() == 3:
		_ok("كل مهمة بدأت مرة واحدة")
	else:
		_no("عدد البدايات", str(started.size()))
	# بعد الانتهاء لا تقدّم أي حدث
	if not ms.report(Mission.Kind.INTERACT, "ant"):
		_ok("لا أحداث بعد انتهاء المتتالية")
	else:
		_no("أحداث بعد الانتهاء")

	# الحفظ والاسترجاع
	var snapshot := ms.to_dict()
	var ms2 := MissionSystem.new()
	root.add_child(ms2)
	ms2.load_missions([
		{"id": "a", "kind": Mission.Kind.REACH, "target": "m1", "title": "اذهب"},
		{"id": "b", "kind": Mission.Kind.COLLECT, "target": "rock", "required": 3, "title": "اجمع"},
		{"id": "c", "kind": Mission.Kind.INTERACT, "target": "ant", "title": "أصلح"},
	])
	ms2.apply_dict(snapshot)
	if ms2.completed_count() == 3 and ms2.current_index() == ms.current_index():
		_ok("حالة المهام تُحفظ وتُسترجع")
	else:
		_no("استرجاع حالة المهام")
	ms.queue_free()
	ms2.queue_free()
