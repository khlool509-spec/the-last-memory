extends Node
## يقرأ إعدادات البيئة والإضاءة من المشهد الجاري ويطبعها.
## قراءة فقط — لا يغيّر شيئاً.
func _ready() -> void:
	var lvl: Node3D = load("res://levels/ch01_forest/chapter_one.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var we: WorldEnvironment = null
	for n in lvl.find_children("*", "WorldEnvironment", true, false):
		we = n
	var e: Environment = we.environment
	print("=== البيئة ===")
	print("tonemap=%d exposure=%.3f white=%.2f" % [e.tonemap_mode, e.tonemap_exposure, e.tonemap_white])
	print("ambient_source=%d sky_contribution=%.2f ambient_energy=%.2f ambient_color=%s" % [
		e.ambient_light_source, e.ambient_light_sky_contribution,
		e.ambient_light_energy, str(e.ambient_light_color)])
	print("reflected_light_source=%d" % e.reflected_light_source)
	print("ssao=%s ssil=%s sdfgi=%s glow=%s" % [e.ssao_enabled, e.ssil_enabled, e.sdfgi_enabled, e.glow_enabled])
	print("fog=%s mode=%d density=%.5f aerial=%.2f sky_affect=%.2f begin=%.0f end=%.0f" % [
		e.fog_enabled, e.fog_mode, e.fog_density, e.fog_aerial_perspective,
		e.fog_sky_affect, e.fog_depth_begin, e.fog_depth_end])
	print("vol_fog=%s density=%.4f length=%.0f" % [
		e.volumetric_fog_enabled, e.volumetric_fog_density, e.volumetric_fog_length])
	print("adjust=%s sat=%.2f contrast=%.2f" % [e.adjustment_enabled, e.adjustment_saturation, e.adjustment_contrast])
	print("sky_material=%s" % (e.sky.sky_material.get_class() if e.sky else "(لا سماء)"))
	print("=== الشمس ===")
	for n in lvl.find_children("*", "DirectionalLight3D", true, false):
		var d := n as DirectionalLight3D
		print("energy=%.2f color=%s shadow=%s mode=%d max_dist=%.0f" % [
			d.light_energy, str(d.light_color), d.shadow_enabled,
			d.directional_shadow_mode, d.directional_shadow_max_distance])
		print("bias=%.4f normal_bias=%.2f blur=%.2f fade=%.2f angular=%.2f indirect=%.2f" % [
			d.shadow_bias, d.shadow_normal_bias, d.shadow_blur,
			d.directional_shadow_fade_start, d.light_angular_distance,
			d.light_indirect_energy])
		print("split1=%.2f split2=%.2f split3=%.2f pancake=%.1f" % [
			d.directional_shadow_split_1, d.directional_shadow_split_2,
			d.directional_shadow_split_3, d.directional_shadow_pancake_size])
	var omni := lvl.find_children("*", "OmniLight3D", true, false).size()
	var spot := lvl.find_children("*", "SpotLight3D", true, false).size()
	print("مصابيح: omni=%d spot=%d" % [omni, spot])
	var vp := get_viewport()
	print("=== المنفذ وقت التشغيل ===")
	print("msaa_3d=%d screen_space_aa=%d use_taa=%s scaling=%d" % [
		vp.msaa_3d, vp.screen_space_aa, vp.use_taa, vp.scaling_3d_mode])
	print("sky radiance=%d process=%d" % [e.sky.radiance_size, e.sky.process_mode])
	print("ssao=%s r=%.2f i=%.2f | ssil=%s r=%.2f i=%.2f" % [
		e.ssao_enabled, e.ssao_radius, e.ssao_intensity,
		e.ssil_enabled, e.ssil_radius, e.ssil_intensity])
	print("=== جودة الظل في إعدادات المشروع ===")
	for k in ["rendering/lights_and_shadows/directional_shadow/size",
			"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality",
			"rendering/anti_aliasing/quality/msaa_3d",
			"rendering/anti_aliasing/quality/screen_space_aa",
			"rendering/scaling_3d/mode", "rendering/scaling_3d/scale",
			"rendering/textures/default_filters/anisotropic_filtering_level"]:
		print("  %s = %s" % [k, str(ProjectSettings.get_setting(k))])
	get_tree().quit()
