class_name PlantMeshes
extends RefCounted
## مكتبة مجسّمات العالم. كل نوع يُدمج في شبكة واحدة بألوان رؤوس،
## فيُرسم بنداء رسم واحد مهما تكرّر — وهذا شرط الكثافة على الجوال.

# ---------- ألوان ----------
const BARK_DARK := Color(0.098, 0.082, 0.071)
const BARK_WARM := Color(0.149, 0.114, 0.086)
const BARK_PALE := Color(0.722, 0.702, 0.639)   # البتولا
const BARK_GREY := Color(0.235, 0.224, 0.204)
const DEAD_WOOD := Color(0.282, 0.251, 0.212)
const LEAF_PINE := Color(0.063, 0.110, 0.078)
const LEAF_SPRUCE := Color(0.047, 0.086, 0.071)
const LEAF_OAK := Color(0.118, 0.157, 0.082)
const LEAF_BIRCH := Color(0.165, 0.200, 0.106)
const LEAF_WILLOW := Color(0.145, 0.188, 0.118)
const ROCK_GREY := Color(0.196, 0.200, 0.212)
const MOSS := Color(0.129, 0.165, 0.102)

# ---------- أدوات بناء ----------
## أسطوانة مدبّبة: الجذوع والأغصان
static func _taper(st: SurfaceTool, base: Vector3, top_pt: Vector3,
		r0: float, r1: float, sides: int, c0: Color, c1: Color) -> void:
	var axis := (top_pt - base)
	var h := axis.length()
	if h < 0.0001:
		return
	var dir := axis / h
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var sx := dir.cross(up).normalized()
	var sz := sx.cross(dir).normalized()
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := sx * cos(a0) + sz * sin(a0)
		var d1 := sx * cos(a1) + sz * sin(a1)
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		var t0 := top_pt + d0 * r1
		var t1 := top_pt + d1 * r1
		_quad(st, b0, b1, t1, t0, c0, c0, c1, c1)

## مخروط: طبقات الأوراق الصنوبرية
static func _cone(st: SurfaceTool, base: Vector3, h: float, r: float,
		sides: int, c_base: Color, c_tip: Color) -> void:
	var apex := base + Vector3.UP * h
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := base + Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		_tri(st, p0, p1, apex, c_base, c_base, c_tip)

## كتلة أوراق: كرة منخفضة الدقة مشوّهة فلا تبدو كرة
static func _blob(st: SurfaceTool, c: Vector3, rx: float, ry: float, rz: float,
		rings: int, segs: int, col: Color, rng: RandomNumberGenerator, jitter: float) -> void:
	var pts := []
	for j in range(rings + 1):
		var v := PI * float(j) / float(rings)
		var row := []
		for i in range(segs + 1):
			var u := TAU * float(i) / float(segs)
			var n := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			var k := 1.0 + rng.randf_range(-jitter, jitter)
			row.append(c + Vector3(n.x * rx, n.y * ry, n.z * rz) * k)
		pts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var cc: Vector3 = pts[j + 1][i + 1]
			var dd: Vector3 = pts[j + 1][i]
			var shade := 1.0 - 0.22 * (float(j) / float(rings))
			var cl := Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
			_quad(st, a, b, cc, dd, cl, cl, cl, cl)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, d, ca, cc, cd)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	st.set_normal(n); st.set_color(ca); st.add_vertex(a)
	st.set_normal(n); st.set_color(cb); st.add_vertex(b)
	st.set_normal(n); st.set_color(cc); st.add_vertex(c)

static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.index()
	return st.commit()

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

# ---------- الأشجار ----------
static func pine(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var h := 1.0
	_taper(st, Vector3.ZERO, Vector3(0.015, h * 0.98, -0.01), 0.030, 0.009, 6, BARK_DARK, BARK_DARK.lightened(0.10))
	var layers := 5
	for i in layers:
		var f := float(i) / float(layers - 1)
		var y := lerpf(0.30, 0.86, f)
		var r := lerpf(0.21, 0.055, f) * rng.randf_range(0.92, 1.08)
		var lh := lerpf(0.26, 0.17, f)
		var tint := LEAF_PINE.lightened(f * 0.16)
		_cone(st, Vector3(0.0, y, 0.0), lh, r, 7, tint.darkened(0.18), tint)
	return _finish(st)

static func spruce(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	_taper(st, Vector3.ZERO, Vector3(0.0, 0.99, 0.0), 0.026, 0.007, 6, BARK_DARK, BARK_DARK)
	var layers := 7
	for i in layers:
		var f := float(i) / float(layers - 1)
		var y := lerpf(0.18, 0.90, f)
		var r := lerpf(0.165, 0.035, f) * rng.randf_range(0.9, 1.1)
		_cone(st, Vector3(0.0, y, 0.0), lerpf(0.21, 0.13, f), r, 6,
			LEAF_SPRUCE.darkened(0.15), LEAF_SPRUCE.lightened(f * 0.2))
	return _finish(st)

static func oak(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var fork := 0.42
	_taper(st, Vector3.ZERO, Vector3(0.02, fork, 0.01), 0.055, 0.038, 7, BARK_WARM, BARK_WARM)
	var arms := 4
	for i in arms:
		var a := TAU * float(i) / float(arms) + rng.randf_range(-0.3, 0.3)
		var reach := rng.randf_range(0.17, 0.27)
		var tip := Vector3(cos(a) * reach, fork + rng.randf_range(0.22, 0.34), sin(a) * reach)
		_taper(st, Vector3(0.02, fork, 0.01), tip, 0.028, 0.010, 5, BARK_WARM, BARK_WARM.darkened(0.1))
		_blob(st, tip + Vector3(0, 0.07, 0), rng.randf_range(0.19, 0.27), 0.17,
			rng.randf_range(0.19, 0.27), 3, 7, LEAF_OAK, rng, 0.17)
	_blob(st, Vector3(0, fork + 0.30, 0), 0.26, 0.20, 0.26, 3, 8, LEAF_OAK.darkened(0.12), rng, 0.15)
	return _finish(st)

static func birch(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var lean := rng.randf_range(-0.05, 0.05)
	_taper(st, Vector3.ZERO, Vector3(lean, 0.72, lean * 0.6), 0.030, 0.016, 6, BARK_PALE, BARK_PALE.lightened(0.08))
	# عُقد داكنة مميّزة للبتولا
	for i in 4:
		var y := rng.randf_range(0.14, 0.62)
		_taper(st, Vector3(lean * y / 0.72, y, 0.0), Vector3(lean * y / 0.72, y + 0.022, 0.0),
			0.032, 0.032, 6, BARK_GREY.darkened(0.3), BARK_GREY.darkened(0.3))
	for i in 3:
		var a := TAU * float(i) / 3.0 + rng.randf_range(-0.4, 0.4)
		var tip := Vector3(cos(a) * rng.randf_range(0.10, 0.18), rng.randf_range(0.78, 0.92), sin(a) * rng.randf_range(0.10, 0.18))
		_taper(st, Vector3(lean, 0.70, lean * 0.6), tip, 0.014, 0.006, 4, BARK_PALE, BARK_PALE)
		_blob(st, tip, rng.randf_range(0.14, 0.20), 0.15, rng.randf_range(0.14, 0.20), 3, 6, LEAF_BIRCH, rng, 0.2)
	return _finish(st)

static func willow(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var bend := rng.randf_range(0.10, 0.20) * (1.0 if rng.randf() < 0.5 else -1.0)
	_taper(st, Vector3.ZERO, Vector3(bend, 0.50, bend * 0.4), 0.065, 0.040, 7, BARK_GREY, BARK_GREY)
	var crown := Vector3(bend, 0.52, bend * 0.4)
	_blob(st, crown + Vector3(0, 0.12, 0), 0.30, 0.16, 0.30, 3, 8, LEAF_WILLOW, rng, 0.14)
	# أغصان متهدّلة: علامة الصفصاف
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.2, 0.2)
		var rr := rng.randf_range(0.20, 0.30)
		var top_pt := crown + Vector3(cos(a) * rr, 0.14, sin(a) * rr)
		var low := top_pt + Vector3(cos(a) * 0.05, -rng.randf_range(0.26, 0.42), sin(a) * 0.05)
		_taper(st, top_pt, low, 0.016, 0.004, 4, LEAF_WILLOW.darkened(0.25), LEAF_WILLOW.lightened(0.1))
	return _finish(st)

static func dead_tree(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var h := rng.randf_range(0.55, 0.88)
	var lean := rng.randf_range(-0.09, 0.09)
	_taper(st, Vector3.ZERO, Vector3(lean, h, lean * 0.5), 0.045, 0.012, 6, DEAD_WOOD.darkened(0.25), DEAD_WOOD)
	for i in rng.randi_range(3, 5):
		var y := rng.randf_range(0.30, h * 0.92)
		var a := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(0.12, 0.26)
		var tip := Vector3(cos(a) * reach, y + rng.randf_range(0.04, 0.16), sin(a) * reach)
		_taper(st, Vector3(lean * y / h, y, 0.0), tip, 0.016, 0.004, 4, DEAD_WOOD, DEAD_WOOD.lightened(0.12))
	return _finish(st)

# ---------- ما تحت الشجر ----------
static func bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var lobes := rng.randi_range(3, 5)
	for i in lobes:
		var a := TAU * float(i) / float(lobes)
		var r := rng.randf_range(0.10, 0.22)
		var c := Vector3(cos(a) * r * 0.7, rng.randf_range(0.10, 0.20), sin(a) * r * 0.7)
		_blob(st, c, r, r * rng.randf_range(0.6, 0.9), r, 2, 6,
			LEAF_OAK.darkened(rng.randf_range(0.0, 0.22)), rng, 0.24)
	return _finish(st)

static func fern(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var fronds := rng.randi_range(5, 8)
	for i in fronds:
		var a := TAU * float(i) / float(fronds) + rng.randf_range(-0.2, 0.2)
		var len_f := rng.randf_range(0.22, 0.38)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tip := dir * len_f + Vector3.UP * rng.randf_range(0.10, 0.22)
		var side := dir.cross(Vector3.UP).normalized() * 0.035
		var base := Vector3(0, 0.02, 0)
		var mid := base.lerp(tip, 0.5) + Vector3.UP * 0.07
		_tri(st, base - side, base + side, mid + side, MOSS.darkened(0.2), MOSS.darkened(0.2), MOSS)
		_tri(st, base - side, mid + side, mid - side, MOSS.darkened(0.2), MOSS, MOSS)
		_tri(st, mid - side, mid + side, tip, MOSS, MOSS, MOSS.lightened(0.18))
	return _finish(st)

static func grass_tuft(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var blades := rng.randi_range(5, 9)
	for i in blades:
		var a := rng.randf_range(0.0, TAU)
		var lean := rng.randf_range(0.03, 0.12)
		var hh := rng.randf_range(0.14, 0.30)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tip := dir * lean + Vector3.UP * hh
		var side := dir.cross(Vector3.UP).normalized() * rng.randf_range(0.012, 0.022)
		var root := dir * 0.02
		var lo := MOSS.darkened(0.3)
		var hi := Color(0.247, 0.278, 0.137)
		_tri(st, root - side, root + side, tip, lo, lo, hi)
	return _finish(st)

# ---------- صخور وحطام ----------
static func rock(rng: RandomNumberGenerator, angular: bool) -> ArrayMesh:
	var st := _begin()
	var rings := 2 if angular else 3
	var segs := 5 if angular else 7
	_blob(st, Vector3(0, 0.0, 0), rng.randf_range(0.42, 0.58), rng.randf_range(0.28, 0.46),
		rng.randf_range(0.42, 0.58), rings, segs, ROCK_GREY.darkened(rng.randf_range(0.0, 0.18)),
		rng, 0.30 if angular else 0.18)
	return _finish(st)

static func log_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var l := rng.randf_range(0.7, 1.0)
	_taper(st, Vector3(-l * 0.5, 0.0, 0.0), Vector3(l * 0.5, rng.randf_range(-0.02, 0.05), 0.0),
		rng.randf_range(0.09, 0.14), rng.randf_range(0.07, 0.12), 7, DEAD_WOOD.darkened(0.2), DEAD_WOOD)
	# طحلب على الجانب العلوي
	_blob(st, Vector3(rng.randf_range(-0.2, 0.2), 0.08, 0.0), 0.16, 0.035, 0.09, 2, 5, MOSS, rng, 0.25)
	return _finish(st)

static func branch(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var l := rng.randf_range(0.35, 0.7)
	var a := rng.randf_range(0.0, TAU)
	var tip := Vector3(cos(a) * l, rng.randf_range(0.0, 0.06), sin(a) * l)
	_taper(st, Vector3.ZERO, tip, 0.028, 0.012, 4, DEAD_WOOD.darkened(0.3), DEAD_WOOD)
	if rng.randf() < 0.6:
		var t2 := tip * 0.55 + Vector3(rng.randf_range(-0.2, 0.2), 0.05, rng.randf_range(-0.2, 0.2))
		_taper(st, tip * 0.5, t2, 0.014, 0.005, 4, DEAD_WOOD.darkened(0.2), DEAD_WOOD)
	return _finish(st)

static func root_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	for i in rng.randi_range(2, 4):
		var a := TAU * float(i) / 3.0 + rng.randf_range(-0.4, 0.4)
		var l := rng.randf_range(0.25, 0.5)
		var mid := Vector3(cos(a) * l * 0.5, 0.07, sin(a) * l * 0.5)
		var tip := Vector3(cos(a) * l, -0.02, sin(a) * l)
		_taper(st, Vector3(0, 0.03, 0), mid, 0.045, 0.028, 5, BARK_DARK, BARK_DARK)
		_taper(st, mid, tip, 0.028, 0.010, 4, BARK_DARK, BARK_DARK.darkened(0.2))
	return _finish(st)

static func mushroom(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	var n := rng.randi_range(2, 4)
	for i in n:
		var off := Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.09, 0.09))
		var hh := rng.randf_range(0.035, 0.075)
		var cap_r := rng.randf_range(0.030, 0.055)
		var stem := Color(0.78, 0.74, 0.66)
		_taper(st, off, off + Vector3.UP * hh, 0.011, 0.014, 4, stem.darkened(0.3), stem)
		var cap_c := Color(0.55, 0.22, 0.17) if rng.randf() < 0.45 else Color(0.42, 0.36, 0.28)
		_blob(st, off + Vector3.UP * (hh + cap_r * 0.3), cap_r, cap_r * 0.55, cap_r, 2, 6, cap_c, rng, 0.1)
	return _finish(st)

## حجر مرصوف للطرق القديمة
static func cobble(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := _begin()
	_blob(st, Vector3(0, -0.02, 0), rng.randf_range(0.10, 0.17), rng.randf_range(0.045, 0.08),
		rng.randf_range(0.10, 0.17), 2, 5, Color(0.251, 0.243, 0.227).darkened(rng.randf_range(0.0, 0.25)), rng, 0.2)
	return _finish(st)

## بوابة الأصناف: اسم -> دالة
static func build(species: String, rng: RandomNumberGenerator) -> ArrayMesh:
	match species:
		"pine": return pine(rng)
		"spruce": return spruce(rng)
		"oak": return oak(rng)
		"birch": return birch(rng)
		"willow": return willow(rng)
		"dead": return dead_tree(rng)
		"bush": return bush(rng)
		"fern": return fern(rng)
		"grass": return grass_tuft(rng)
		"rock_s": return rock(rng, false)
		"rock_l": return rock(rng, true)
		"log": return log_mesh(rng)
		"branch": return branch(rng)
		"root": return root_mesh(rng)
		"mushroom": return mushroom(rng)
		"cobble": return cobble(rng)
	return null
