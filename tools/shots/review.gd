extends Node
## مراجعة بصرية: يفتح مشهد الفصل الأول كما هو ويلتقط أربع لقطات
## من المشروع الجاري فعلاً. لا يغيّر إعداداً ولا خامةً ولا إضاءة —
## يضيف كاميرا ويحفظ ما يراه المصيّر.
##
## المصيّر يُختار من سطر الأوامر (REVIEW_TAG يميّز المجموعة)، فلا
## يُلمس renderer/rendering_method في project.godot.

const OUT := "res://shots/review_v0.7.0/"
const WARM := 30          # إطارات تهيئة قبل أول لقطة
const SETTLE := 16        # إطارات بين ضبط الكاميرا والحفظ

var cam: Camera3D
var lvl: Node3D
var shots: Array = []

func _ready() -> void:
	lvl = load("res://levels/ch01_forest/chapter_one.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in lvl.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false

	if not (lvl is Node3D) or not lvl.has_method("get") or lvl.get("world") == null:
		push_error("المشهد لم يُحمَّل — غالباً خطأ ترجمة في سكربت الفصل")
		get_tree().quit(2)
		return
	var w = lvl.world
	var p_over = w.poi("overlook")
	var p_cross = w.poi("crossroad")
	var p_house = w.poi("old_house")
	var p_bridge = w.poi("bridge")

	shots = [
		# أ: منظر عريض — تضاريس وسماء وأفق وتكوين عام
		{"name": "A_wide_environment",
		 "from": Vector3(p_over.x - 12, p_over.y + 19, p_over.z + 16),
		 "to": Vector3(p_bridge.x, p_bridge.y + 6, p_bridge.z), "fov": 68.0},
		# ب: الأرض عن قرب — جودة الخامة ومقياسها وتنوّع السطح
		{"name": "B_terrain_closeup",
		 "from": _eye(w, p_cross.x + 3.5, p_cross.z + 5.0, 1.35),
		 "to": _eye(w, p_cross.x + 1.0, p_cross.z - 1.5, 0.05), "fov": 58.0},
		# ج: السماء والأفق — عمق الجوّ وتدرّج الإضاءة
		{"name": "C_sky_horizon",
		 "from": _eye(w, p_cross.x, p_cross.z, 2.2),
		 "to": _eye(w, p_cross.x + 46, p_cross.z + 47, 30.0), "fov": 74.0},
		# هـ: الأرض بزاوية زاحفة من ارتفاع القدم — الاختبار الحقيقي
		# لإزاحة المنظور: العمق لا يُرى إلا في الزوايا المائلة.
		{"name": "E_ground_grazing",
		 "from": _eye(w, p_cross.x + 1.2, p_cross.z + 2.0, 0.45),
		 "to": _eye(w, p_cross.x + 9.0, p_cross.z + 11.0, 0.30), "fov": 50.0},
		# د: الإضاءة — ظلال واستجابة الخامات والإضاءة المحيطة
		{"name": "D_lighting_shadows",
		 "from": _eye(w, p_house.x - 13, p_house.z - 11, 3.4),
		 "to": Vector3(p_house.x, p_house.y + 1.8, p_house.z), "fov": 54.0},
	]

	cam = Camera3D.new()
	cam.current = true
	add_child(cam)
	for i in WARM:
		await get_tree().process_frame

	var tag := str(OS.get_environment("REVIEW_TAG"))
	if tag == "":
		tag = "run"
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("shots/review_v0.7.0"):
		dir.make_dir_recursive("shots/review_v0.7.0")

	var vp := get_viewport()
	# إعداد المشروع قد يُتجاوَز من سطر الأوامر، فيُقرأ المستعمل فعلاً
	var args := OS.get_cmdline_args()
	var actual := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	for i in args.size():
		if args[i] == "--rendering-method" and i + 1 < args.size():
			actual = args[i + 1]
	print("مصيّر المشروع: %s | المستعمل فعلاً: %s | المحوّل: %s | القياس: %dx%d" % [
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		actual, RenderingServer.get_video_adapter_name(),
		vp.get_visible_rect().size.x, vp.get_visible_rect().size.y])
	var only := str(OS.get_environment("REVIEW_ONLY"))
	for s in shots:
		if only != "" and not str(s["name"]).begins_with(only):
			continue
		cam.global_position = s["from"]
		cam.look_at(s["to"], Vector3.UP)
		cam.fov = float(s["fov"])
		for i in SETTLE:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := "%s%s__%s.png" % [OUT, str(s["name"]), tag]
		img.save_png(path)
		print("  %-22s %s  %dx%d  محتوى=%.1f%%" % [
			str(s["name"]), path, img.get_width(), img.get_height(),
			_content(img) * 100.0])
	get_tree().quit()

## نسبة البكسلات غير السوداء: يكشف إطاراً فارغاً يُحفظ بلا تحذير
func _content(img: Image) -> float:
	var lit := 0
	var tot := 0
	for y in range(0, img.get_height(), 7):
		for x in range(0, img.get_width(), 7):
			tot += 1
			if img.get_pixel(x, y).get_luminance() > 0.015:
				lit += 1
	return float(lit) / maxf(float(tot), 1.0)

func _eye(w, x: float, z: float, lift: float) -> Vector3:
	return Vector3(x, w.height_at(x, z) + lift, z)
