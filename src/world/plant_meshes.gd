class_name PlantMeshes
extends RefCounted
## مكتبة مجسّمات العالم. كل نوع يُدمج في شبكة واحدة بألوان رؤوس،
## فيُرسم بنداء رسم واحد مهما تكرّر — وهذا شرط الكثافة على الجوال.

# ---------- ألوان ----------
const BARK_DARK := Color(0.231, 0.184, 0.145)
const BARK_WARM := Color(0.325, 0.243, 0.169)
const BARK_PALE := Color(0.816, 0.800, 0.741)   # البتولا
const BARK_GREY := Color(0.337, 0.322, 0.290)
const DEAD_WOOD := Color(0.447, 0.400, 0.337)
const LEAF_PINE := Color(0.153, 0.278, 0.161)
const LEAF_SPRUCE := Color(0.122, 0.227, 0.149)
const LEAF_OAK := Color(0.290, 0.388, 0.176)
const LEAF_BIRCH := Color(0.396, 0.478, 0.227)
const LEAF_WILLOW := Color(0.337, 0.435, 0.251)
const ROCK_GREY := Color(0.400, 0.404, 0.408)
const MOSS := Color(0.306, 0.392, 0.200)

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


# ---------- بناء بسطحين: لحاء + بطاقات أوراق ----------
## الشجرة الحقيقية ليست مخروطاً مصمتاً: جذع بخامة لحاء، وأوراق
## على بطاقات ذات قناة شفافية. هذا الفرق بين «مجسّم» و«شجرة».
class Build:
	var bark := SurfaceTool.new()
	var leaf := SurfaceTool.new()
	var has_leaf := false
	func _init() -> void:
		bark.begin(Mesh.PRIMITIVE_TRIANGLES)
		leaf.begin(Mesh.PRIMITIVE_TRIANGLES)

## أسطوانة مدبّبة بإحداثيات خامة: الـ V يتبع الطول فيتمدّد اللحاء طبيعياً
static func _tube(st: SurfaceTool, base: Vector3, tip: Vector3,
		r0: float, r1: float, sides: int, c0: Color, c1: Color, v_scale: float = 4.0) -> void:
	var axis := tip - base
	var h := axis.length()
	if h < 0.0001:
		return
	var dir := axis / h
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var sx := dir.cross(up).normalized()
	var sz := sx.cross(dir).normalized()
	for i in sides:
		var u0 := float(i) / float(sides)
		var u1 := float(i + 1) / float(sides)
		var a0 := TAU * u0
		var a1 := TAU * u1
		var d0 := sx * cos(a0) + sz * sin(a0)
		var d1 := sx * cos(a1) + sz * sin(a1)
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		var t0 := tip + d0 * r1
		var t1 := tip + d1 * r1
		var vt := h * v_scale * 0.25
		_uvtri(st, b0, b1, t1, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, vt), c0, c0, c1)
		_uvtri(st, b0, t1, t0, Vector2(u0, 0), Vector2(u1, vt), Vector2(u0, vt), c0, c1, c1)

static func _uvtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	st.set_normal(n); st.set_color(ca); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(n); st.set_color(cb); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(n); st.set_color(cc); st.set_uv(uc); st.add_vertex(c)

## بطاقة ورق: مربّع يحمل خامة شفافة. تُرسم بوجهين فتُرى من الخلف.
## الأعمدة الطبيعية للبطاقة تُوجَّه للأعلى قليلاً فتستقبل ضوء السماء
## بدل أن تبدو مسطّحة سوداء.
static func _card(st: SurfaceTool, center: Vector3, right: Vector3, up: Vector3,
		w: float, h: float, tint: Color) -> void:
	var r := right * (w * 0.5)
	var u := up * (h * 0.5)
	var p0 := center - r - u
	var p1 := center + r - u
	var p2 := center + r + u
	var p3 := center - r + u
	var nrm := (center.normalized() * 0.55 + Vector3.UP * 0.75).normalized()
	for tri in [[p0, p1, p2, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
				[p0, p2, p3, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)]]:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		for item in [[a, tri[3]], [b, tri[4]], [c, tri[5]]]:
			st.set_normal(nrm)
			st.set_color(tint)
			st.set_uv(item[1])
			st.add_vertex(item[0])

## زوج متقاطع: بطاقتان متعامدتان تعطيان حجماً من كل الزوايا
static func _card_cross(st: SurfaceTool, center: Vector3, w: float, h: float,
		yaw: float, pitch: float, tint: Color) -> void:
	for k in 2:
		var a := yaw + float(k) * PI * 0.5
		var right := Vector3(cos(a), 0, sin(a))
		var up := Vector3(-sin(a) * sin(pitch), cos(pitch), cos(a) * sin(pitch))
		_card(st, center, right, up, w, h, tint)

static func _commit2(b: Build, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	b.bark.index()
	var mesh := b.bark.commit()
	if mesh == null:
		mesh = ArrayMesh.new()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, bark_mat)
	if b.has_leaf:
		b.leaf.index()
		var lm := b.leaf.commit()
		if lm != null and lm.get_surface_count() > 0:
			var arr := lm.surface_get_arrays(0)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, leaf_mat)
	return mesh

# ---------- الأشجار ----------
## detail: 1.0 قريب، 0.45 متوسط، 0.18 بعيد.
## التبسيط ليس حذفاً عشوائياً: الطبقات تقلّ والبطاقات تكبر، فيبقى
## الظلّ الخارجي للشجرة كما هو ولا يُلاحظ الانتقال.
static func pine(rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	var b := Build.new()
	var h := 1.0
	var sides := 7 if detail > 0.6 else (5 if detail > 0.3 else 4)
	_tube(b.bark, Vector3.ZERO, Vector3(0.012, h * 0.99, -0.008), 0.034, 0.008, sides,
		Color.WHITE, Color(0.88, 0.88, 0.88), 9.0)
	var grow := 1.0 / maxf(detail, 0.12)
	var tiers := maxi(3, int(round(9.0 * detail)))
	for i in tiers:
		var f := float(i) / float(tiers - 1)
		var y := lerpf(0.26, 0.93, f)
		var reach := lerpf(0.23, 0.055, f) * rng.randf_range(0.85, 1.15)
		var arms := maxi(2, int(lerpf(6.0, 3.0, f) * clampf(detail * 1.15, 0.34, 1.0)))
		for k in arms:
			var a := TAU * float(k) / float(arms) + f * 2.3 + rng.randf_range(-0.2, 0.2)
			var droop := lerpf(0.10, 0.03, f)
			var tip := Vector3(cos(a) * reach, y - droop, sin(a) * reach)
			if detail > 0.35:
				_tube(b.bark, Vector3(0, y, 0), tip, 0.011, 0.004, 4, Color(0.8, 0.8, 0.8), Color(0.7, 0.7, 0.7), 3.0)
			var cs := reach * rng.randf_range(1.5, 2.1) * sqrt(grow)
			_card(b.leaf, tip * 0.68 + Vector3(0, 0.012, 0),
				Vector3(cos(a), 0, sin(a)), Vector3(0, 1, 0), cs, cs * 0.62,
				Color(1, 1, 1).darkened(f * 0.12))
			if detail > 0.5:
				_card(b.leaf, tip * 0.68 + Vector3(0, 0.012, 0),
					Vector3(cos(a), 0, sin(a)), Vector3(-sin(a) * 0.35, 0.94, cos(a) * 0.35),
					cs * 0.92, cs * 0.55, Color(1, 1, 1))
	# قمة مدبّبة
	_card_cross(b.leaf, Vector3(0, 0.97, 0), 0.12, 0.17, 0.6, 0.0, Color.WHITE)
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("needle"))

static func spruce(rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	var b := Build.new()
	var grow := 1.0 / maxf(detail, 0.12)
	_tube(b.bark, Vector3.ZERO, Vector3(0, 0.99, 0), 0.029, 0.007, 6 if detail > 0.5 else 4,
		Color(0.86, 0.86, 0.86), Color(0.74, 0.74, 0.74), 10.0)
	var tiers := maxi(3, int(round(11.0 * detail)))
	for i in tiers:
		var f := float(i) / float(tiers - 1)
		var y := lerpf(0.14, 0.95, f)
		var reach := lerpf(0.185, 0.035, f) * rng.randf_range(0.85, 1.15)
		var arms := maxi(2, int(lerpf(5.0, 3.0, f) * clampf(detail * 1.15, 0.34, 1.0)))
		for k in arms:
			var a := TAU * float(k) / float(arms) + f * 1.9
			var tip := Vector3(cos(a) * reach, y - lerpf(0.08, 0.02, f), sin(a) * reach)
			if detail > 0.35:
				_tube(b.bark, Vector3(0, y, 0), tip, 0.009, 0.003, 4, Color(0.78, 0.78, 0.78), Color(0.68, 0.68, 0.68), 3.0)
			var cs := reach * rng.randf_range(1.6, 2.2) * sqrt(grow)
			_card(b.leaf, tip * 0.7, Vector3(cos(a), 0, sin(a)), Vector3(0, 1, 0),
				cs, cs * 0.58, Color(0.88, 0.95, 0.90))
	_card_cross(b.leaf, Vector3(0, 0.985, 0), 0.10, 0.15, 0.3, 0.0, Color(0.9, 0.96, 0.92))
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("needle"))

static func _broadleaf(rng: RandomNumberGenerator, trunk_r: float, fork: float,
		arms: int, canopy: float, pale: bool, tint: Color, detail: float = 1.0) -> ArrayMesh:
	var b := Build.new()
	var grow := 1.0 / maxf(detail, 0.12)
	arms = maxi(2, int(round(float(arms) * clampf(detail * 1.2, 0.4, 1.0))))
	canopy *= sqrt(grow)
	var lean := rng.randf_range(-0.045, 0.045)
	var top := Vector3(lean, fork, lean * 0.6)
	var bark_c := Color(1.6, 1.6, 1.6) if pale else Color.WHITE
	_tube(b.bark, Vector3.ZERO, top, trunk_r, trunk_r * 0.62,
		8 if detail > 0.6 else (5 if detail > 0.3 else 4), bark_c, bark_c * 0.92, 7.0)
	# جذور ظاهرة عند القاعدة: تربط الشجرة بالأرض بصرياً
	for k in (5 if detail > 0.6 else 0):
		var ra := TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
		_tube(b.bark, Vector3(cos(ra) * trunk_r * 2.2, -0.012, sin(ra) * trunk_r * 2.2),
			Vector3(0, trunk_r * 2.0, 0), trunk_r * 0.5, trunk_r * 0.85, 4, bark_c * 0.8, bark_c, 2.0)
	for i in arms:
		var a := TAU * float(i) / float(arms) + rng.randf_range(-0.35, 0.35)
		var reach := rng.randf_range(0.16, 0.27)
		var tip := top + Vector3(cos(a) * reach, rng.randf_range(0.16, 0.30), sin(a) * reach)
		if detail > 0.3:
			_tube(b.bark, top, tip, trunk_r * 0.52, trunk_r * 0.18, 4, bark_c, bark_c * 0.85, 3.0)
		# عنقود أوراق من بطاقات متقاطعة
		var cz := canopy * rng.randf_range(0.80, 1.18)
		for q in maxi(1, int(round(3.0 * detail))):
			var off := Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.03, 0.09), rng.randf_range(-0.07, 0.07))
			_card_cross(b.leaf, tip + off + Vector3(0, cz * 0.22, 0), cz, cz * 0.82,
				rng.randf_range(0.0, TAU), rng.randf_range(-0.35, 0.35), tint)
	# قلب التاج
	_card_cross(b.leaf, top + Vector3(0, canopy * 0.55, 0), canopy * 1.5, canopy * 1.15,
		rng.randf_range(0.0, TAU), 0.12, tint)
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("broad"))

static func oak(rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	return _broadleaf(rng, 0.052, 0.40, 5, 0.30, false, Color(0.86, 0.96, 0.74), detail)

static func birch(rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	return _broadleaf(rng, 0.030, 0.62, 4, 0.22, true, Color(1.02, 1.06, 0.80), detail)

static func willow(rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	var b := Build.new()
	var bend := rng.randf_range(0.09, 0.18) * (1.0 if rng.randf() < 0.5 else -1.0)
	var crown := Vector3(bend, 0.50, bend * 0.4)
	_tube(b.bark, Vector3.ZERO, crown, 0.062, 0.038, 8, Color.WHITE, Color(0.9, 0.9, 0.9), 6.0)
	for i in maxi(4, int(round(11.0 * detail))):
		var a := TAU * float(i) / float(maxi(4, int(round(11.0 * detail)))) + rng.randf_range(-0.2, 0.2)
		var rr := rng.randf_range(0.18, 0.30)
		var tip := crown + Vector3(cos(a) * rr, 0.10, sin(a) * rr)
		_tube(b.bark, crown, tip, 0.016, 0.005, 4, Color(0.9, 0.9, 0.9), Color(0.82, 0.82, 0.82), 2.5)
		# ستائر متهدّلة: بطاقات طويلة رأسية
		var drop := rng.randf_range(0.30, 0.48)
		_card(b.leaf, tip + Vector3(0, -drop * 0.42, 0), Vector3(cos(a), 0, sin(a)),
			Vector3(0, 1, 0), rng.randf_range(0.14, 0.22), drop, Color(0.80, 0.94, 0.70))
		if detail > 0.5:
			_card(b.leaf, tip + Vector3(0, -drop * 0.42, 0), Vector3(-sin(a), 0, cos(a)),
				Vector3(0, 1, 0), rng.randf_range(0.12, 0.20), drop * 0.9, Color(0.80, 0.94, 0.70))
	_card_cross(b.leaf, crown + Vector3(0, 0.12, 0), 0.52, 0.30, 0.4, 0.0, Color(0.78, 0.92, 0.68))
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("broad"))

static func dead_tree(rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	var b := Build.new()
	var h := rng.randf_range(0.55, 0.88)
	var lean := rng.randf_range(-0.09, 0.09)
	_tube(b.bark, Vector3.ZERO, Vector3(lean, h, lean * 0.5), 0.046, 0.011, 7,
		Color(0.78, 0.72, 0.64), Color(0.92, 0.86, 0.76), 8.0)
	for i in maxi(2, int(rng.randi_range(4, 7) * detail)):
		var y := rng.randf_range(0.26, h * 0.94)
		var a := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(0.12, 0.28)
		var tip := Vector3(cos(a) * reach, y + rng.randf_range(0.02, 0.18), sin(a) * reach)
		_tube(b.bark, Vector3(lean * y / h, y, 0.0), tip, 0.016, 0.003, 4,
			Color(0.84, 0.78, 0.70), Color(0.95, 0.90, 0.82), 3.0)
	return _commit2(b, WorldMaterials.bark(), null)

# ---------- ما تحت الشجر ----------
static func bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var b := Build.new()
	var lobes := rng.randi_range(4, 7)
	for i in lobes:
		var a := TAU * float(i) / float(lobes) + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(0.10, 0.24)
		var c := Vector3(cos(a) * r * 0.55, rng.randf_range(0.14, 0.30), sin(a) * r * 0.55)
		var sz := rng.randf_range(0.30, 0.52)
		_card_cross(b.leaf, c, sz, sz * 0.86, rng.randf_range(0.0, TAU),
			rng.randf_range(-0.25, 0.25), Color(0.78, 0.90, 0.64).darkened(rng.randf_range(0.0, 0.18)))
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("broad"))

static func fern(rng: RandomNumberGenerator) -> ArrayMesh:
	var b := Build.new()
	var fronds := rng.randi_range(4, 7)
	for i in fronds:
		var a := TAU * float(i) / float(fronds) + rng.randf_range(-0.25, 0.25)
		var lean := rng.randf_range(0.10, 0.20)
		var c := Vector3(cos(a) * lean, rng.randf_range(0.12, 0.22), sin(a) * lean)
		var sz := rng.randf_range(0.34, 0.54)
		_card(b.leaf, c, Vector3(cos(a), 0, sin(a)),
			Vector3(-sin(a) * 0.42, 0.90, cos(a) * 0.42), sz, sz * 0.72,
			Color(0.70, 0.88, 0.58))
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("broad"))

static func fern_old(rng: RandomNumberGenerator) -> ArrayMesh:
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

## خصلة عشب = بطاقتان متقاطعتان بخامة شفافة. أرخص من الأنصال
## المجسّمة وتبدو أكثف منها بكثير.
static func grass_tuft(rng: RandomNumberGenerator) -> ArrayMesh:
	var b := Build.new()
	var n := rng.randi_range(2, 3)
	for i in n:
		var w := rng.randf_range(0.30, 0.52)
		var h := rng.randf_range(0.26, 0.46)
		var off := Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.09, 0.09))
		_card_cross(b.leaf, off + Vector3(0, h * 0.5, 0), w, h,
			rng.randf_range(0.0, TAU), 0.0,
			Color(0.92, 0.96, 0.70).darkened(rng.randf_range(0.0, 0.22)))
	b.has_leaf = true
	return _commit2(b, WorldMaterials.bark(), WorldMaterials.leaf("grass"))

# ---------- صخور وحطام ----------
static func rock(rng: RandomNumberGenerator, angular: bool) -> ArrayMesh:
	var st := _begin()
	# كانت 2-3 حلقات و5-7 قطاعات: كتلة بأوجه قليلة تُقرأ مكعّباً.
	# الصخرة تحتاج صمتاً كافياً في الظلّية لتُقرأ حجراً.
	var rings := 4 if angular else 5
	var segs := 9 if angular else 11
	_blob(st, Vector3(0, 0.0, 0), rng.randf_range(0.42, 0.58), rng.randf_range(0.28, 0.46),
		rng.randf_range(0.42, 0.58), rings, segs, ROCK_GREY.darkened(rng.randf_range(0.0, 0.18)),
		rng, 0.38 if angular else 0.24)
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
static func build(species: String, rng: RandomNumberGenerator, detail: float = 1.0) -> ArrayMesh:
	match species:
		"pine": return pine(rng, detail)
		"spruce": return spruce(rng, detail)
		"oak": return oak(rng, detail)
		"birch": return birch(rng, detail)
		"willow": return willow(rng, detail)
		"dead": return dead_tree(rng, detail)
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
