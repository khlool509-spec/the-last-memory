extends Node
## يقيس كلفة التصيير من المشهد الجاري، من ثلاث كاميرات ثابتة.
##
## ما يُنقَل كما هو: استدعاءات الرسم، الكائنات، المثلثات، ذاكرة
## العتاد — هذه مستقلّة عن المحوّل. أما زمن الإطار فمن مصيّر برمجي
## (llvmpipe)، فلا يدلّ على جهاز حقيقي ويُستعمل للمقارنة النسبية
## بين نسختين من المشهد نفسه وحدها.

const WARM := 24
const SAMPLES := 8

func _ready() -> void:
	var lvl: Node3D = load("res://levels/ch01_forest/chapter_one.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in lvl.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var w = lvl.world
	var p_over = w.poi("overlook")
	var p_cross = w.poi("crossroad")
	var views := [
		{"n": "عريض", "from": Vector3(p_over.x - 12, p_over.y + 19, p_over.z + 16),
		 "to": Vector3(p_cross.x, p_cross.y + 4, p_cross.z)},
		{"n": "قريب", "from": _eye(w, p_cross.x + 3.5, p_cross.z + 5.0, 1.35),
		 "to": _eye(w, p_cross.x + 1.0, p_cross.z - 1.5, 0.05)},
		{"n": "سماء", "from": _eye(w, p_cross.x, p_cross.z, 2.2),
		 "to": _eye(w, p_cross.x + 46, p_cross.z + 47, 30.0)},
	]
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	for i in WARM:
		await get_tree().process_frame

	var env: Environment = null
	for n in lvl.find_children("*", "WorldEnvironment", true, false):
		env = (n as WorldEnvironment).environment
	print("=== كلفة التصيير ===")
	print("ssao=%s ssil=%s sdfgi=%s vol_fog=%s msaa=%d" % [
		env.ssao_enabled, env.ssil_enabled, env.sdfgi_enabled,
		env.volumetric_fog_enabled, get_viewport().msaa_3d])
	var tag := str(OS.get_environment("PERF_TAG"))
	for v in views:
		cam.global_position = v["from"]
		cam.look_at(v["to"], Vector3.UP)
		for i in 10:
			await get_tree().process_frame
		var t_sum := 0.0
		var dc := 0.0
		var prim := 0.0
		var obj := 0.0
		for i in SAMPLES:
			await get_tree().process_frame
			t_sum += Performance.get_monitor(Performance.TIME_PROCESS)
			dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		var n := float(SAMPLES)
		print("%s | %-6s | استدعاءات=%5d كائنات=%5d مثلثات=%8d | زمن=%6.1f مللي" % [
			tag, str(v["n"]), int(dc / n), int(obj / n), int(prim / n), t_sum / n * 1000.0])
	print("ذاكرة العتاد = %.1f ميغابايت" % (
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	get_tree().quit()

func _eye(w, x: float, z: float, lift: float) -> Vector3:
	return Vector3(x, w.height_at(x, z) + lift, z)
