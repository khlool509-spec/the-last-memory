extends Node
## يتحقّق أن كل إعداد رسومي يغيّر المصيّر فعلاً، لا الواجهة وحدها
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport()
	print("=== أثر كل إعداد على المصيّر ===")

	for q in Graphics.QUALITY_ORDER:
		Settings.set_value("gfx_quality", q)
		await get_tree().process_frame
		print("  %-14s قياس=%.2f  msaa=%d  عتبة التفصيل=%.1f" % [
			Graphics.quality_label(q), vp.scaling_3d_scale, vp.msaa_3d, vp.mesh_lod_threshold])

	print("--- معدّل الإطارات ---")
	for t in Graphics.FPS_ORDER:
		Settings.set_value("gfx_fps_tier", t)
		await get_tree().process_frame
		print("  %-16s max_fps=%d" % [Graphics.fps_label(t), Engine.max_fps])

	print("--- تنعيم الحواف ---")
	Settings.set_value("gfx_quality", "hd")
	for v in [true, false]:
		Settings.set_value("gfx_antialiasing", v)
		await get_tree().process_frame
		print("  %s → msaa=%d" % ["تفعيل" if v else "تعطيل", vp.msaa_3d])

	print("--- توفير الطاقة ---")
	Settings.set_value("gfx_antialiasing", true)
	for v in [false, true]:
		Settings.set_value("gfx_power_save", v)
		await get_tree().process_frame
		print("  %s → قياس=%.2f msaa=%d max_fps=%d" % [
			"تفعيل" if v else "تعطيل", vp.scaling_3d_scale, vp.msaa_3d, Engine.max_fps])
	Settings.set_value("gfx_power_save", false)

	print("--- الإعدادات الجاهزة ---")
	for p in ["fps", "balanced", "quality"]:
		Settings.set_value("gfx_preset", p)
		await get_tree().process_frame
		print("  %-9s → جودة=%s إطارات=%s ظلال=%s" % [p,
			Settings.get_value("gfx_quality"), Settings.get_value("gfx_fps_tier"),
			Settings.get_value("gfx_shadows")])

	print("--- عمى الألوان ---")
	for m in Graphics.CB_ORDER:
		Settings.set_value("gfx_colorblind", m)
		await get_tree().process_frame
		var r := Graphics.get_node_or_null("ColorBlindLayer/ColorBlindRect")
		print("  %-14s طبقة التصحيح ظاهرة=%s" % [Graphics.CB_LABEL[m], r.visible if r else "?"])
	Settings.set_value("gfx_colorblind", "none")
	get_tree().quit()
