extends Node
## يلتقط تسلسلاً زمنياً من المشهد الجاري لإثبات الحركة فعلاً.
##
## التصيير البرمجي يستغرق ثوانيَ للإطار، فلو تُرك زمن الشادر للساعة
## الحقيقية لقفزت الحركة. هنا يُضبَط `anim_time` في خامتَي الماء
## والسماء بخطوة ثابتة، فالتسلسل الناتج حركة متّصلة بمعدّل معلوم.

const OUT := "res://shots/seq/"

func _ready() -> void:
	var lvl: Node3D = load("res://levels/ch01_forest/chapter_one.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in lvl.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false

	var w = lvl.world
	var p_bridge = w.poi("bridge")
	var p_cross = w.poi("crossroad")
	var views := {
		"river": {"from": Vector3(p_bridge.x + 17, p_bridge.y + 5.0, p_bridge.z + 13),
			"to": Vector3(p_bridge.x - 4, w.data.water_level + 0.6, p_bridge.z - 6), "fov": 54.0},
		"river_close": {"from": Vector3(p_bridge.x + 8.0, w.data.water_level + 4.2, p_bridge.z + 7.5),
			"to": Vector3(p_bridge.x - 3, w.data.water_level, p_bridge.z - 4), "fov": 48.0},
		"sky": {"from": _eye(w, p_cross.x, p_cross.z, 2.2),
			"to": _eye(w, p_cross.x + 40, p_cross.z + 41, 52.0), "fov": 72.0},
	}
	var which := str(OS.get_environment("SEQ_VIEW"))
	if which == "" or not views.has(which):
		which = "river"
	var v: Dictionary = views[which]

	var frames := int(OS.get_environment("SEQ_FRAMES")) if OS.get_environment("SEQ_FRAMES") != "" else 24
	var dt := float(OS.get_environment("SEQ_DT")) if OS.get_environment("SEQ_DT") != "" else 0.1

	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = v["from"]
	cam.look_at(v["to"], Vector3.UP)
	cam.fov = float(v["fov"])

	var water_mat := WorldMaterials.water()
	var env: Environment = null
	for n in lvl.find_children("*", "WorldEnvironment", true, false):
		env = (n as WorldEnvironment).environment
	var sky_mat: ShaderMaterial = null
	if env and env.sky and env.sky.sky_material is ShaderMaterial:
		sky_mat = env.sky.sky_material as ShaderMaterial

	var d := DirAccess.open("res://")
	if d and not d.dir_exists("shots/seq"):
		d.make_dir_recursive("shots/seq")
	for i in 26:
		await get_tree().process_frame

	var vp := get_viewport()
	for i in frames:
		var t := float(i) * dt
		water_mat.set_shader_parameter("anim_time", t)
		if sky_mat:
			sky_mat.set_shader_parameter("anim_time", t * 12.0)   # الغيوم أبطأ فتُسرَّع للعرض
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s%s_%03d.png" % [OUT, which, i])
		print("إطار %3d/%d  t=%.2f ث" % [i + 1, frames, t])
	print("تم: %s" % which)
	get_tree().quit()

func _eye(w, x: float, z: float, lift: float) -> Vector3:
	return Vector3(x, w.height_at(x, z) + lift, z)
