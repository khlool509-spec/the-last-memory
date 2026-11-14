extends SceneTree
## يفرّغ دالة الارتفاع إلى شبكة خام ليعاينها بايثون بالتظليل التلّي.
## الهدف: رؤية شكل الأرض قبل بناء أي شيء فوقها.

const N := 400   # دقة المعاينة

func _initialize() -> void:
	var wp := WorldProfile.new()
	var half := WorldProfile.HALF
	var step := (half * 2.0) / float(N - 1)
	var t0 := Time.get_ticks_msec()

	var heights := PackedFloat32Array()
	heights.resize(N * N)
	var roads := PackedFloat32Array()
	roads.resize(N * N)
	var rivers := PackedFloat32Array()
	rivers.resize(N * N)

	for j in N:
		var z := -half + float(j) * step
		for i in N:
			var x := -half + float(i) * step
			var idx := j * N + i
			heights[idx] = wp.height(x, z)
			roads[idx] = wp.road_distance(x, z)
			rivers[idx] = wp.river_distance(x, z)
	var ms := Time.get_ticks_msec() - t0

	var lo := INF
	var hi := -INF
	for v in heights:
		lo = minf(lo, v)
		hi = maxf(hi, v)

	var pois := {}
	for k in WorldProfile.POI:
		var c: Vector2 = WorldProfile.POI[k]
		pois[k] = [c.x, c.y, wp.height(c.x, c.y)]

	var rp := []
	for p in wp.river_points:
		rp.append([p.x, p.y])
	var rs := []
	for s in wp.road_segments:
		rs.append([s["a"].x, s["a"].y, s["b"].x, s["b"].y, s["w"]])

	var out := {
		"n": N, "half": half, "water": WorldProfile.WATER_LEVEL,
		"min": lo, "max": hi,
		"heights": Array(heights), "roads": Array(roads), "rivers": Array(rivers),
		"poi": pois, "river_points": rp, "road_segments": rs,
	}
	var f := FileAccess.open("user://profile_dump.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("DUMP ", ProjectSettings.globalize_path("user://profile_dump.json"))
	print("شبكة %dx%d في %d ms  |  الارتفاع من %.1f إلى %.1f متر" % [N, N, ms, lo, hi])
	print("مقاطع الطرق: %d  |  نقاط النهر: %d" % [wp.road_segments.size(), wp.river_points.size()])
	quit(0)
