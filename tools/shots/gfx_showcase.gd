extends Node
## يلتقط المشهد نفسه بكل نمط رسوم وبكل وضع عمى ألوان — دليل بصري
## أن الإعدادات تغيّر الصورة فعلاً لا الواجهة وحدها.
const OUT := "res://shots/gfx/"

func _ready() -> void:
	var lvl: Node3D = load("res://levels/ch01_forest/chapter_one.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in lvl.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var w = lvl.world
	var p_over = w.poi("overlook")
	var p_bridge = w.poi("bridge")
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(p_over.x - 12, p_over.y + 19, p_over.z + 16)
	cam.look_at(Vector3(p_bridge.x, p_bridge.y + 6, p_bridge.z), Vector3.UP)
	cam.fov = 68.0
	var d := DirAccess.open("res://")
	if d and not d.dir_exists("shots/gfx"):
		d.make_dir_recursive("shots/gfx")
	for i in 26:
		await get_tree().process_frame

	var what := str(OS.get_environment("GFX_SET"))
	var items: Array = Graphics.STYLE_ORDER if what != "cb" else Graphics.CB_ORDER
	var key := "gfx_style" if what != "cb" else "gfx_colorblind"
	for it in items:
		Settings.set_value(key, it)
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s%s_%s.png" % [OUT, what if what != "" else "style", str(it)])
		print("  %s = %s" % [key, it])
	get_tree().quit()
