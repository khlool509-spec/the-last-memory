extends SceneTree
func _initialize() -> void:
	for n in ["ground_albedo.png","ground_normal.png","bark_albedo.png","rock_albedo.png"] as Array[String]:
		var p := "res://assets/textures/world/" + n
		print("%-22s موجود=%s" % [n, str(ResourceLoader.exists(p))])
		if ResourceLoader.exists(p):
			var t: Texture2D = ResourceLoader.load(p)
			print("    حُمِّل=%s  %dx%d" % [str(t != null), t.get_width() if t else 0, t.get_height() if t else 0])
	var m := WorldMaterials.ground()
	print("خامة الأرض: albedo_texture=%s  normal=%s  vcol=%s  albedo=%s" % [
		str(m.albedo_texture != null), str(m.normal_texture != null),
		str(m.vertex_color_use_as_albedo), str(m.albedo_color)])
	# هل الشبكة تحمل UV فعلاً؟
	var d: WorldData = ResourceLoader.load("res://levels/ch01_forest/baked/world.res")
	var mesh: ArrayMesh = d.chunk_meshes[45]
	var arr := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	print("UV في الشبكة: %d قيمة، مثال %s و %s" % [uvs.size(), str(uvs[0]), str(uvs[220])])
	print("ألوان الرؤوس: %d، مثال %s" % [cols.size(), str(cols[0])])
	print("صيغة الشبكة: %d" % mesh.surface_get_format(0))
	quit(0)
