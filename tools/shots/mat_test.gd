extends Node
## مشهد صغير لفحص خامة الأرض معزولة: مستوٍ واحد بإحداثيات العالم نفسها،
## إضاءة بسيطة، كاميرا قريبة. لا غابة ولا ضباب يخفي النتيجة.
func _ready() -> void:
	get_window().size = Vector2i(960, 540)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.55)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.transform = Transform3D(Basis(), Vector3(6, 9, 5)).looking_at(Vector3.ZERO, Vector3.UP)
	add_child(sun)

	# المقطع المخبوز الحقيقي نفسه — لا مستوٍ مصنوع للاختبار
	var d: WorldData = ResourceLoader.load("res://levels/ch01_forest/baked/world.res")
	var mi := MeshInstance3D.new()
	mi.mesh = d.chunk_meshes[45]
	mi.material_override = WorldMaterials.ground()
	add_child(mi)
	var arr := (d.chunk_meshes[45] as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in vs:
		lo = lo.min(v)
		hi = hi.max(v)
	print("المقطع: %d رأس، الحدود %s .. %s" % [vs.size(), str(lo), str(hi)])
	print("UV: %s .. %s" % [str(uvs[0]), str(uvs[uvs.size()-1])])
	var mid := (lo + hi) * 0.5

	var cam := Camera3D.new()
	cam.current = true
	# حساب رياضي خالص: look_at على عقدة خارج الشجرة لا يعمل
	cam.transform = Transform3D(Basis(), mid + Vector3(0, 9.0, 16.0)).looking_at(mid, Vector3.UP)
	add_child(cam)

	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/mat_ground.png")
	# تقرير حالة الخامة فعلياً
	var m := mi.material_override as StandardMaterial3D
	print("albedo_texture=%s  uv1_scale=%s  vcol=%s  rough_tex=%s  ao=%s" % [
		str(m.albedo_texture), str(m.uv1_scale), str(m.vertex_color_use_as_albedo),
		str(m.roughness_texture != null), str(m.ao_enabled)])
	print("حُفظت: shots/mat_ground.png")
	get_tree().quit(0)
