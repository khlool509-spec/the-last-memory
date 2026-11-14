class_name MoonTerrain
extends StaticBody3D
## سطح القمر: تضاريس مولَّدة رياضياً — بحر قمري متموّج وحقل فوّهات
## بحواف مرتفعة وقذائف منتشرة، مع تصادم مطابق للشكل تماماً.
##
## كل الارتفاعات تأتي من `height_at()` وحدها، فأي جسم يوضَع على السطح
## يستقر عليه بالضبط بلا تخمين ولا إسقاط فيزيائي.

const SIZE := 300.0          # طول الضلع بالأمتار
const RES := 150             # عدد الخلايا على الضلع (خلية = 2 متر)
const CRATER_COUNT := 26

var _craters: Array[Dictionary] = []
var _noise: FastNoiseLite
var _detail: FastNoiseLite
var _mesh_instance: MeshInstance3D

func _init(world_seed: int = 20261114) -> void:
	_build_noise(world_seed)
	_scatter_craters(world_seed)

func _ready() -> void:
	name = "MoonTerrain"
	collision_layer = 1
	collision_mask = 0
	_build_mesh()

# ---------------------------------------------------------------- الارتفاع

## ارتفاع السطح عند أي نقطة أفقية. المصدر الوحيد للحقيقة.
func height_at(x: float, z: float) -> float:
	var h := 0.0

	# بحر قمري: تموّج عريض بالغ النعومة
	h += _noise.get_noise_2d(x, z) * 6.5

	# تلال متوسطة
	h += _noise.get_noise_2d(x * 2.7 + 500.0, z * 2.7 - 320.0) * 1.9

	# حُبيبات الثرى: خشونة دقيقة
	h += _detail.get_noise_2d(x * 9.0, z * 9.0) * 0.28

	# الفوّهات تُطبَّق فوق كل ما سبق
	for c in _craters:
		h += _crater_delta(x, z, c)

	return h

## الميل السطحي (0 مستوٍ، 1 شديد الانحدار) — يُستخدم لرفض مواضع غير صالحة
func slope_at(x: float, z: float) -> float:
	var e := 1.0
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return clampf(Vector2(hx, hz).length() / (2.0 * e), 0.0, 1.0)

func normal_at(x: float, z: float) -> Vector3:
	var e := 0.75
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func half_extent() -> float:
	return SIZE * 0.5

## أقرب موضع صالح للوقوف: داخل الحدود وبميل معقول
func find_flat_spot(near: Vector2, radius: float, rng: RandomNumberGenerator) -> Vector3:
	var limit := half_extent() - 12.0
	var best := Vector2(clampf(near.x, -limit, limit), clampf(near.y, -limit, limit))
	var best_slope := slope_at(best.x, best.y)
	for i in 48:
		var ang := rng.randf() * TAU
		var r := rng.randf() * radius
		var p := near + Vector2(cos(ang), sin(ang)) * r
		p.x = clampf(p.x, -limit, limit)
		p.y = clampf(p.y, -limit, limit)
		var s := slope_at(p.x, p.y)
		if s < best_slope:
			best = p
			best_slope = s
		if best_slope < 0.10:
			break
	return Vector3(best.x, height_at(best.x, best.y), best.y)

# ---------------------------------------------------------------- الفوّهات

func _build_noise(world_seed: int) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0032
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.46

	_detail = FastNoiseLite.new()
	_detail.seed = world_seed + 7
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.011
	_detail.fractal_octaves = 2

func _scatter_craters(world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 991
	var limit := SIZE * 0.5
	for i in CRATER_COUNT:
		# توزيع أُسّي: الفوّهات الصغيرة أكثر بكثير من الكبيرة، كما في الواقع
		var t := rng.randf()
		var radius := lerpf(6.0, 46.0, pow(t, 2.3))
		var cx := rng.randf_range(-limit, limit)
		var cz := rng.randf_range(-limit, limit)
		# منطقة الهبوط تبقى مفتوحة: لا فوّهة كبيرة قرب المركز
		if Vector2(cx, cz).length() < radius + 22.0:
			cx += signf(cx if absf(cx) > 0.01 else 1.0) * (radius + 26.0)
			cz += signf(cz if absf(cz) > 0.01 else 1.0) * (radius + 26.0)
			cx = clampf(cx, -limit, limit)
			cz = clampf(cz, -limit, limit)
		_craters.append({
			"pos": Vector2(cx, cz),
			"radius": radius,
			"depth": radius * rng.randf_range(0.13, 0.21),
			"rim": radius * rng.randf_range(0.045, 0.085),
			"wobble": rng.randf_range(0.0, TAU),
			"irregular": rng.randf_range(0.04, 0.13),
		})

## مقطع فوّهة ارتطام: قاع وعائي، حافة مرتفعة، قذائف تتلاشى للخارج
func _crater_delta(x: float, z: float, c: Dictionary) -> float:
	var pos: Vector2 = c["pos"]
	var radius: float = c["radius"]
	var dx := x - pos.x
	var dz := z - pos.y
	var d := sqrt(dx * dx + dz * dz)

	# حافة غير منتظمة: الفوّهات الحقيقية ليست دوائر مثالية
	var ang := atan2(dz, dx)
	var wob: float = 1.0 + sin(ang * 3.0 + float(c["wobble"])) * float(c["irregular"])
	var r := radius * wob

	var outer := r * 2.1
	if d > outer:
		return 0.0

	var depth: float = c["depth"]
	var rim: float = c["rim"]
	var u := d / r

	if u < 1.0:
		# القاع: قطع مكافئ ينعدم ميله عند الحافة فلا تظهر كسرة
		var bowl := -depth * (1.0 - u * u)
		var lip := rim * smoothstep(0.55, 1.0, u)
		return bowl + lip
	# خارج الحافة: القذائف تنحدر إلى الصفر
	var t := (d - r) / maxf(0.001, outer - r)
	return rim * (1.0 - smoothstep(0.0, 1.0, t))

# ---------------------------------------------------------------- الشبكة

func _build_mesh() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var step := SIZE / float(RES)
	var origin := -SIZE * 0.5
	var side := RES + 1

	verts.resize(side * side)
	normals.resize(side * side)
	uvs.resize(side * side)

	for j in side:
		for i in side:
			var x := origin + float(i) * step
			var z := origin + float(j) * step
			var idx := j * side + i
			verts[idx] = Vector3(x, height_at(x, z), z)
			normals[idx] = normal_at(x, z)
			uvs[idx] = Vector2(float(i) / float(RES), float(j) / float(RES)) * 24.0

	for j in RES:
		for i in RES:
			var a := j * side + i
			var b := a + 1
			var c := a + side
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Surface"
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _regolith_material()
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh_instance)

	# تصادم مطابق للشكل: لا تقريب بصناديق
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for k in indices.size():
		faces[k] = verts[indices[k]]
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.name = "SurfaceCollision"
	col.shape = shape
	add_child(col)

func _regolith_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# الثرى القمري رمادي داكن جداً: انعكاسه نحو 11% فقط
	m.albedo_color = Color("#6d6a67")
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance

func triangle_count() -> int:
	return RES * RES * 2

## أكبر فوّهة في الخريطة — تُستعمل كموقع مهمة
func largest_crater() -> Dictionary:
	var best := {}
	var best_r := -1.0
	for c in _craters:
		if float(c["radius"]) > best_r:
			best_r = float(c["radius"])
			best = c
	return best

func crater_count() -> int:
	return _craters.size()

## مواضع متباعدة صالحة للوقوف، تبعد عن المركز مسافة ضمن المدى
func scatter_points(count: int, min_dist: float, max_dist: float, spacing: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var tries := 0
	while out.size() < count and tries < count * 260:
		tries += 1
		var ang := rng.randf() * TAU
		var r := rng.randf_range(min_dist, max_dist)
		var x := cos(ang) * r
		var z := sin(ang) * r
		if absf(x) > half_extent() - 10.0 or absf(z) > half_extent() - 10.0:
			continue
		if slope_at(x, z) > 0.34:
			continue
		var p := Vector3(x, height_at(x, z), z)
		var ok := true
		for q in out:
			if Vector2(p.x - q.x, p.z - q.z).length() < spacing:
				ok = false
				break
		if ok:
			out.append(p)
	return out
