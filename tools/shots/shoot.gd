extends Node
## آلة اللقطات: تُشغَّل تحت Xvfb مع lavapipe فتصوّر المشهد فعلياً.
## تُخفى الواجهة، وتُنتظر إطارات كافية ليستقر الضباب الحجمي والظلال.

const OUT := "res://shots/"
const W := 1280
const H := 720
const WARM := 26          # إطارات التسخين قبل أول لقطة
const SETTLE := 14        # إطارات بين لقطة وأخرى

var lvl: ChapterOne
var cam: Camera3D
var tag := "run"

## زوايا مختارة: واسعة، قريبة، مبانٍ، ومنظور اللاعب
var SHOTS := []

func _ready() -> void:
	tag = str(OS.get_environment("SHOT_TAG"))
	if tag == "":
		tag = "run"
	get_window().size = Vector2i(W, H)

	SaveSystem.start_new_game()
	Inv._sync_from_save()
	var packed: PackedScene = load("res://levels/ch01_forest/chapter_one.tscn")
	lvl = packed.instantiate() as ChapterOne
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame

	# إخفاء الواجهة: نريد المشهد لا الأزرار
	if lvl.hud:
		lvl.hud.visible = false
	for c in lvl.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false

	var w := lvl.world
	var p_spawn := w.poi("spawn")
	var p_cross := w.poi("crossroad")
	var p_bridge := w.poi("bridge")
	var p_house := w.poi("old_house")
	var p_over := w.poi("overlook")
	var p_hut := w.poi("hut")

	SHOTS = [
		{"name": "01_vista", "from": Vector3(p_over.x - 6, p_over.y + 11, p_over.z + 6),
		 "to": Vector3(p_bridge.x, p_bridge.y + 6, p_bridge.z), "fov": 62.0},
		{"name": "02_forest_close", "from": _eye(w, p_cross.x + 14, p_cross.z - 22, 1.65),
		 "to": _eye(w, p_cross.x - 4, p_cross.z - 46, 3.2), "fov": 68.0},
		{"name": "03_river_bridge", "from": _eye(w, p_bridge.x + 24, p_bridge.z + 20, 6.0),
		 "to": Vector3(p_bridge.x, w.data.water_level + 1.5, p_bridge.z), "fov": 60.0},
		{"name": "04_house", "from": _eye(w, p_house.x + 13, p_house.z + 13, 3.2),
		 "to": Vector3(p_house.x, p_house.y + 2.4, p_house.z), "fov": 58.0},
		{"name": "05_player_pov", "from": _eye(w, p_spawn.x + 1.2, p_spawn.z + 4.6, 2.0),
		 "to": _eye(w, p_cross.x, p_cross.z, 2.0), "fov": 70.0},
		{"name": "07_ground", "from": _eye(w, p_cross.x + 30, p_cross.z + 30, 3.0),
		 "to": _eye(w, p_cross.x + 30.1, p_cross.z + 30.1, 0.0), "fov": 70.0},
		{"name": "06_hut_trail", "from": _eye(w, p_hut.x + 11, p_hut.z + 9, 2.6),
		 "to": Vector3(p_hut.x, p_hut.y + 1.8, p_hut.z), "fov": 62.0},
	]

	cam = Camera3D.new()
	cam.name = "ShotCam"
	cam.far = 500.0
	cam.current = true
	add_child(cam)

	var t0 := Time.get_ticks_msec()
	for i in WARM:
		await get_tree().process_frame
	print("تسخين: %d ms" % (Time.get_ticks_msec() - t0))

	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("shots"):
		dir.make_dir("shots")

	var only := str(OS.get_environment("SHOT_ONLY"))
	for s in SHOTS:
		if only != "" and not str(s["name"]).contains(only):
			continue
		cam.global_position = s["from"]
		cam.look_at(s["to"], Vector3.UP)
		cam.fov = float(s["fov"])
		var t1 := Time.get_ticks_msec()
		for i in SETTLE:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s%s_%s.png" % [OUT, tag, str(s["name"])]
		var err := img.save_png(path)
		var nonblack := _content_ratio(img)
		print("%-18s %s  %dx%d  محتوى=%.1f%%  %d ms" % [
			str(s["name"]), ("حُفظت" if err == OK else "فشلت"),
			img.get_width(), img.get_height(), nonblack * 100.0,
			Time.get_ticks_msec() - t1])

	print("المسار: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit(0)

## نسبة البكسلات غير السوداء — يكشف اللقطة الفارغة
func _content_ratio(img: Image) -> float:
	var n := 0
	var total := 0
	var step := 7
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			total += 1
			if img.get_pixel(x, y).v > 0.035:
				n += 1
	return float(n) / maxf(1.0, float(total))

func _eye(w: WorldRenderer, x: float, z: float, lift: float) -> Vector3:
	return Vector3(x, w.height_at(x, z) + lift, z)
