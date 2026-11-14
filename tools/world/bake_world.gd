extends SceneTree
## يخبز العالم مرة واحدة إلى ملف مورد، فلا يدفع الجوال ثمن التوليد.
## يُشغَّل: godot --headless --path . --script tools/world/bake_world.gd

const OUT := "res://levels/ch01_forest/baked/world.res"
const CHUNK := 40.0
const GRID := 10
const CHUNK_QUADS := 20          # 2 متر لكل مربع
const HEIGHT_STEP := 2.0

var wp: WorldProfile
var bio: Biome
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	rng.seed = WorldProfile.SEED
	wp = WorldProfile.new()
	bio = Biome.new(wp)

	var data := WorldData.new()
	data.chunk_size = CHUNK
	data.grid = GRID
	data.world_half = WorldProfile.HALF
	data.water_level = WorldProfile.WATER_LEVEL
	data.height_step = HEIGHT_STEP
	data.height_res = int((WorldProfile.HALF * 2.0) / HEIGHT_STEP) + 1
	data.river_points = wp.river_points
	for s in wp.road_segments:
		data.road_segments.append([s["a"].x, s["a"].y, s["b"].x, s["b"].y, s["w"]])
	for k in WorldProfile.POI:
		var c: Vector2 = WorldProfile.POI[k]
		data.poi[k] = Vector3(c.x, wp.height(c.x, c.y), c.y)

	print("[1/3] شبكات الأرض …")
	var tris := 0
	for j in GRID:
		for i in GRID:
			var m := _chunk_mesh(i, j)
			data.chunk_meshes.append(m)
			if m.get_surface_count() > 0:
				tris += m.surface_get_array_index_len(0) / 3
	print("    %d مقطع، %d مثلث" % [data.chunk_meshes.size(), tris])

	print("[2/3] خريطة التصادم …")
	data.height_map = _height_map(data.height_res)
	print("    %dx%d عيّنة" % [data.height_res, data.height_res])

	print("[3/3] توزيع النبات والتفاصيل …")
	_scatter(data)
	var total := 0
	for key in data.scatter:
		var a: PackedFloat32Array = data.scatter[key]
		total += int(a.size() / 12.0)
	print("    %d نسخة في %d مجموعة" % [total, data.scatter.size()])

	var err := ResourceSaver.save(data, OUT)
	if err != OK:
		push_error("فشل حفظ العالم: %d" % err)
		quit(1)
		return
	print("حُفظ: %s  في %.1f ثانية" % [OUT, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)

# ---------------- شبكة المقطع ----------------
func _chunk_mesh(ci: int, cj: int) -> ArrayMesh:
	var ox := -WorldProfile.HALF + float(ci) * CHUNK
	var oz := -WorldProfile.HALF + float(cj) * CHUNK
	var step := CHUNK / float(CHUNK_QUADS)
	var n := CHUNK_QUADS + 1

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n * n); norms.resize(n * n); cols.resize(n * n); uvs.resize(n * n)

	for j in n:
		var z := oz + float(j) * step
		for i in n:
			var x := ox + float(i) * step
			var idx := j * n + i
			var h := wp.height(x, z)
			verts[idx] = Vector3(x - ox, h, z - oz)   # محلي، والعقدة تُزاح
			norms[idx] = wp.normal(x, z, step * 0.5)
			cols[idx] = bio.ground_color(x, z)
			uvs[idx] = Vector2(x, z) / 7.0            # إحداثيات عالمية: تتبلّط بلا خياطة
	var idxs := PackedInt32Array()
	for j in CHUNK_QUADS:
		for i in CHUNK_QUADS:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			# لفّ الوجه الأمامي: كان معكوساً فكانت الأرض تُقصّ بالكامل
			# ولا تُرسم إطلاقاً — ما كان يُرى مكانها هو السماء والضباب.
			idxs.append(a); idxs.append(b); idxs.append(c)
			idxs.append(b); idxs.append(d); idxs.append(c)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

# ---------------- خريطة التصادم ----------------
## تُعيّن عند نفس نقاط الشبكة المرئية تماماً، فلا يطفو اللاعب ولا يغوص.
func _height_map(res: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(res * res)
	var half := WorldProfile.HALF
	for j in res:
		var z := -half + float(j) * HEIGHT_STEP
		for i in res:
			out[j * res + i] = wp.height(-half + float(i) * HEIGHT_STEP, z)
	return out

# ---------------- التوزيع ----------------
## شبكة مُزاحة عشوائياً: توزيع طبيعي بلا صفوف مكشوفة وبلا كلفة بواسون.
const LAYERS := [
	{"group": "tree",   "cell": 3.3,  "slope_max": 0.46, "jitter": 0.96},
	{"group": "bush",   "cell": 3.1,  "slope_max": 0.54, "jitter": 0.96},
	{"group": "fern",   "cell": 2.6,  "slope_max": 0.50, "jitter": 0.97},
	{"group": "grass",  "cell": 1.9,  "slope_max": 0.58, "jitter": 1.0},
	{"group": "rock_s", "cell": 7.5,  "slope_max": 0.85, "jitter": 0.9},
	{"group": "rock_l", "cell": 23.0, "slope_max": 0.85, "jitter": 0.9},
	{"group": "log",    "cell": 18.0, "slope_max": 0.30, "jitter": 0.9},
	{"group": "branch", "cell": 9.5, "slope_max": 0.40, "jitter": 0.95},
	{"group": "root",   "cell": 19.0, "slope_max": 0.35, "jitter": 0.9},
	{"group": "mushroom","cell": 11.0,"slope_max": 0.30, "jitter": 0.9},
]

func _scatter(data: WorldData) -> void:
	var half := WorldProfile.HALF
	for layer in LAYERS:
		var cell: float = float(layer["cell"])
		var cells := int((half * 2.0) / cell)
		var jit: float = float(layer["jitter"]) * cell * 0.5
		for cj in cells:
			for ci in cells:
				var x := -half + (float(ci) + 0.5) * cell + rng.randf_range(-jit, jit)
				var z := -half + (float(cj) + 0.5) * cell + rng.randf_range(-jit, jit)
				if absf(x) > half - 3.0 or absf(z) > half - 3.0:
					continue
				_try_place(data, str(layer["group"]), x, z, float(layer["slope_max"]))

func _try_place(data: WorldData, group: String, x: float, z: float, slope_max: float) -> void:
	var h := wp.height(x, z)
	if h < WorldProfile.WATER_LEVEL + 0.12:
		return                                   # لا نبات في الماء
	var sl := wp.slope(x, z)
	if sl > slope_max:
		return
	var rf := wp.road_factor(x, z)
	if rf < 1.15:
		return                                   # الطريق يبقى سالكاً
	for pad in wp.pads:
		var c: Vector2 = pad["c"]
		if Vector2(x, z).distance_to(c) < float(pad["r"]) * 0.82:
			return                               # لا نبات داخل أرضيات المباني

	var kind := bio.at(x, z)
	var species := group
	var chance := 1.0
	match group:
		"tree":
			chance = bio.tree_density(kind) * 0.80
			species = _pick_species(bio.species_mix(kind), x, z)
		"bush", "fern":
			chance = bio.undergrowth_density(kind) * 0.52
		"grass":
			chance = bio.undergrowth_density(kind) * 0.55
		"rock_s", "rock_l":
			chance = 0.18 + sl * 0.95 + (0.5 if kind == Biome.Kind.ROCKY else 0.0)
		"log", "branch", "root":
			chance = 0.30 + (0.42 if kind == Biome.Kind.DEEP or kind == Biome.Kind.FOREST else 0.0)
		"mushroom":
			chance = 0.12 + (0.5 if kind == Biome.Kind.DEEP else 0.0)
	# قرب الطريق يخفّ كل شيء تدريجياً، فتبدو الحافة طبيعية لا مقصوصة
	if rf < 2.6:
		chance *= clampf((rf - 1.15) / 1.45, 0.0, 1.0)
	if rng.randf() > clampf(chance, 0.0, 1.0):
		return

	var t := _instance_transform(group, species, x, h, z, sl)
	var ci := clampi(int((x + WorldProfile.HALF) / CHUNK), 0, GRID - 1)
	var cj := clampi(int((z + WorldProfile.HALF) / CHUNK), 0, GRID - 1)
	var key := "%s:%d" % [species, cj * GRID + ci]
	if not data.scatter.has(key):
		data.scatter[key] = PackedFloat32Array()
	var arr: PackedFloat32Array = data.scatter[key]
	WorldData.pack_transform(arr, t)
	data.scatter[key] = arr

func _pick_species(mix: Dictionary, x: float, z: float) -> String:
	var r := rng.randf()
	var acc := 0.0
	for k in mix:
		acc += float(mix[k])
		if r <= acc:
			return str(k)
	return str(mix.keys()[0])

## الحجم والدوران والميل: الأشجار تقف شاقولية، والحطام يتبع ميل الأرض
func _instance_transform(group: String, species: String, x: float, y: float, z: float, sl: float) -> Transform3D:
	var scale_v := 1.0
	match species:
		"pine": scale_v = rng.randf_range(7.5, 15.5)
		"spruce": scale_v = rng.randf_range(8.0, 14.0)
		"oak": scale_v = rng.randf_range(7.0, 12.5)
		"birch": scale_v = rng.randf_range(6.5, 11.0)
		"willow": scale_v = rng.randf_range(6.0, 9.5)
		"dead": scale_v = rng.randf_range(5.0, 10.5)
		"bush": scale_v = rng.randf_range(0.8, 1.9)
		"fern": scale_v = rng.randf_range(0.7, 1.5)
		"grass": scale_v = rng.randf_range(0.7, 1.6)
		"rock_s": scale_v = rng.randf_range(0.5, 1.5)
		"rock_l": scale_v = rng.randf_range(1.8, 4.6)
		"log": scale_v = rng.randf_range(1.0, 2.4)
		"branch": scale_v = rng.randf_range(0.7, 1.5)
		"root": scale_v = rng.randf_range(0.8, 1.7)
		"mushroom": scale_v = rng.randf_range(0.8, 1.6)
		"cobble": scale_v = rng.randf_range(0.8, 1.4)

	var b := Basis()
	var upright := group == "tree" or species == "bush" or species == "fern" or species == "grass"
	if not upright:
		# يتبع ميل الأرض: الصخور والجذوع لا تقف شاقولية على منحدر
		var n := wp.normal(x, z)
		var ax := n.cross(Vector3.UP)
		if ax.length() > 0.001:
			b = Basis(ax.normalized(), -asin(clampf(ax.length(), -1.0, 1.0)))
	elif group == "tree":
		# ميل خفيف يكسر الشاقولية التامة
		var lean := minf(sl, 0.2) * 0.9
		var la := rng.randf_range(0.0, TAU)
		b = Basis(Vector3(cos(la), 0, sin(la)), lean * rng.randf_range(0.3, 1.0))
	b = b.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
	# تفاوت أفقي طفيف فلا تبدو النسخ متطابقة
	var sx := scale_v * rng.randf_range(0.9, 1.1)
	var sz := scale_v * rng.randf_range(0.9, 1.1)
	b = b.scaled(Vector3(sx, scale_v, sz))
	var sink := 0.0
	if group == "tree":
		sink = 0.25 * scale_v * 0.05
	return Transform3D(b, Vector3(x, y - sink, z))
