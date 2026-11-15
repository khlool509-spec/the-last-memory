class_name WorldRenderer
extends Node3D
## يُركّب العالم المخبوز: الأرض، التصادم، النبات، الماء.
## كل شيء هنا رخيص — القراءة والتركيب فقط، لا توليد.

const WORLD_RES := "res://levels/ch01_forest/baked/world.res"

## مدى الظهور لكل نوع: الصمت البصري البعيد هو ما يجعل الكثافة القريبة ممكنة
const RANGE := {
	"pine": 128.0, "spruce": 128.0, "oak": 120.0, "birch": 120.0,
	"willow": 105.0, "dead": 112.0,
	"bush": 52.0, "fern": 38.0, "grass": 28.0,
	"rock_s": 85.0, "rock_l": 170.0, "rock_xl": 320.0,
	"log": 60.0, "branch": 42.0, "root": 40.0, "mushroom": 26.0,
	"cobble": 50.0,
}
const CHUNK_RANGE := 300.0

## أنواع تحمل سطحين بخامتين مختلفتين
const MULTI_SURFACE := ["pine", "spruce", "oak", "birch", "willow", "dead", "bush", "fern", "grass"]

var data: WorldData
var terrain_root: Node3D
var scatter_root: Node3D
var water_root: Node3D
var body: StaticBody3D

var _mesh_cache: Dictionary = {}     # species -> ArrayMesh
var _mat_cache: Dictionary = {}      # species -> Material
var _ground_mat: Material

func _ready() -> void:
	name = "World"
	data = ResourceLoader.load(WORLD_RES)
	if data == null:
		push_error("العالم المخبوز غير موجود: " + WORLD_RES)
		return
	_build_terrain()
	_build_collision()
	_build_scatter()
	_build_water()

# ---------------- الأرض ----------------
func _build_terrain() -> void:
	terrain_root = Node3D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)
	_ground_mat = WorldMaterials.ground()
	# تشخيص: FLAT_GROUND=1 يستبدل خامة الأرض ببياض سادة،
	# فيفصل ما تصنعه الخامة عمّا تصنعه الهندسة والسوية.
	if OS.get_environment("FLAT_GROUND") == "1":
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.72, 0.72, 0.72)
		fm.roughness = 0.95
		fm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_ground_mat = fm
	for j in data.grid:
		for i in data.grid:
			var idx := j * data.grid + i
			if idx >= data.chunk_meshes.size():
				continue
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [i, j]
			mi.mesh = data.chunk_meshes[idx]
			mi.material_override = _ground_mat
			mi.position = data.chunk_origin(i, j)
			mi.visibility_range_end = CHUNK_RANGE
			mi.visibility_range_end_margin = 40.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			terrain_root.add_child(mi)

## التصادم من خريطة الارتفاع: شكل واحد يغطي العالم كله بدقة متر،
## أرخص بكثير من مئة شبكة مقعّرة ولا يترك ثقوباً بين المقاطع.
func _build_collision() -> void:
	body = StaticBody3D.new()
	body.name = "TerrainBody"
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = data.height_res
	shape.map_depth = data.height_res
	shape.map_data = data.height_map
	var cs := CollisionShape3D.new()
	cs.name = "TerrainShape"
	cs.shape = shape
	# خلايا الشكل متباعدة وحدة واحدة، والعيّنات كل مترين → تكبير مطابق
	cs.scale = Vector3(data.height_step, 1.0, data.height_step)
	body.add_child(cs)

# ---------------- النبات ----------------
## مستويات التفصيل: ثلاث نسخ من كل شجرة، تُعرض كل واحدة في نطاق مسافة.
## هذا هو الفرق بين 2.9 مليون مثلث و ربعها، وهو شرط 60 إطاراً.
const TREES := ["pine", "spruce", "oak", "birch", "willow", "dead"]
const LOD_BANDS := [
	{"detail": 1.00, "begin": 0.0,  "end": 34.0},
	{"detail": 0.45, "begin": 34.0, "end": 76.0},
	{"detail": 0.18, "begin": 76.0, "end": 0.0},   # 0 = حتى مدى النوع
]
const FADE := 6.0

## مضاعف المسافات حسب إعداد الجودة
var quality_scale: float = 1.0
var vegetation_hidden: bool = false

func _build_scatter() -> void:
	scatter_root = Node3D.new()
	scatter_root.name = "Scatter"
	add_child(scatter_root)
	quality_scale = _quality_scale()

	# إطفاء مؤقت للنبات: البيانات والمجسّمات والخامات كلها باقية،
	# يُستأنف الرسم بتبديل الإعداد بلا إعادة خبز ولا فقد شيء.
	var show_plants := bool(Settings.get_value("show_vegetation"))
	var show_rocks := bool(Settings.get_value("show_rocks"))
	vegetation_hidden = not show_plants
	if not show_plants and not show_rocks:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = WorldProfile.SEED
	var keys: Array = data.scatter.keys()
	keys.sort()

	for key in keys:
		var parts := str(key).split(":")
		if parts.size() != 2:
			continue
		var species := parts[0]
		var chunk_idx := int(parts[1])
		var arr: PackedFloat32Array = data.scatter[key]
		var count := int(arr.size() / 12.0)
		if count == 0:
			continue
		var is_rock := species.begins_with("rock")
		if is_rock and not show_rocks:
			continue
		if not is_rock and not show_plants:
			continue
		var far: float = float(RANGE.get(species, 60.0)) * quality_scale
		var colored := _colored_buffer(arr, count, species)

		if species in TREES:
			for li in LOD_BANDS.size():
				var band: Dictionary = LOD_BANDS[li]
				var b0: float = float(band["begin"]) * quality_scale
				var b1: float = float(band["end"]) * quality_scale
				if b1 <= 0.0:
					b1 = far
				if b0 >= far:
					continue
				_add_batch(species, chunk_idx, colored, count, float(band["detail"]),
					b0, minf(b1, far), li, rng)
		else:
			_add_batch(species, chunk_idx, colored, count, 1.0, 0.0, far, 0, rng)

func _add_batch(species: String, chunk_idx: int, buf: PackedFloat32Array, count: int,
		detail: float, begin: float, end: float, lod: int, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh_for(species, rng, detail, lod)
	mm.instance_count = count
	mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "%s_%d_L%d" % [species, chunk_idx, lod]
	mmi.multimesh = mm
	if not species in MULTI_SURFACE:
		mmi.material_override = _mat_for(species)
	mmi.visibility_range_begin = begin
	mmi.visibility_range_begin_margin = FADE if begin > 0.0 else 0.0
	mmi.visibility_range_end = end
	mmi.visibility_range_end_margin = FADE
	# التلاشي المتبادل يمنع القفزة المفاجئة بين مستويين
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if (species in TREES or species == "rock_l" or species == "rock_xl") and lod == 0
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	scatter_root.add_child(mmi)

## يضيف لوناً لكل نسخة: تفاوت خفيف في الحرارة والسطوع.
## شجرتان متجاورتان بنفس اللون تماماً هو أوضح ما يفضح التكرار.
func _colored_buffer(src: PackedFloat32Array, count: int, species: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count * 16)
	var warm := 0.10
	var bright := 0.16
	if species in ["grass", "fern", "bush"]:
		warm = 0.14
		bright = 0.22
	for k in count:
		var si := k * 12
		var di := k * 16
		for j in 12:
			out[di + j] = src[si + j]
		# بذرة ثابتة من موضع النسخة: نفس الشجرة تأخذ نفس اللون دائماً
		var px: float = src[si + 3]
		var pz: float = src[si + 11]
		var h: float = sin(px * 12.9898 + pz * 78.233) * 43758.5453
		var n1: float = h - floor(h)
		var h2: float = sin(px * 39.3468 + pz * 11.1357) * 24634.6345
		var n2: float = h2 - floor(h2)
		var w: float = (n1 - 0.5) * 2.0 * warm
		var v: float = 1.0 + (n2 - 0.5) * 2.0 * bright
		out[di + 12] = clampf((1.0 + w) * v, 0.45, 1.6)
		out[di + 13] = clampf(v, 0.45, 1.6)
		out[di + 14] = clampf((1.0 - w) * v, 0.45, 1.6)
		out[di + 15] = 1.0
	return out

func _quality_scale() -> float:
	var q := str(Settings.get_value("graphics_quality"))
	match q:
		"low": return 0.62
		"medium": return 0.84
	return 1.0

func _mesh_for(species: String, rng: RandomNumberGenerator, detail: float, lod: int) -> ArrayMesh:
	var key := "%s|%d" % [species, lod]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = hash(species) + WorldProfile.SEED
	var m := PlantMeshes.build(species, r, detail)
	_mesh_cache[key] = m
	return m

func _mat_for(species: String) -> Material:
	if _mat_cache.has(species):
		return _mat_cache[species]
	# الصخور خامة حجر مصوّرة بإسقاط ثلاثي، لا لون قمم كالنبات
	var m: Material = WorldMaterials.rock_scatter() if species.begins_with("rock") \
		else WorldMaterials.foliage(species)
	_mat_cache[species] = m
	return m

# ---------------- الماء ----------------
## شريط يتبع محور النهر ويتسع مع تقدّمه، سطحه عند منسوب الماء.
func _build_water() -> void:
	water_root = Node3D.new()
	water_root.name = "Water"
	add_child(water_root)

	var pts := data.river_points
	if pts.size() < 2:
		return
	# تنعيم المحور بـ Catmull-Rom فلا تظهر زوايا حادة
	var smooth := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var steps := 6
		for s in steps:
			var t := float(s) / float(steps)
			smooth.append(_catmull(p0, p1, p2, p3, t))
	smooth.append(pts[pts.size() - 1])

	# عموديّ المفصل: عمودي كل نقطة هو متوسط عموديّ الضلعين المجاورين.
	# بعمودي ضلع واحد تنفرج الحافّة الخارجية عند المنعطفات فتخرج من
	# المجرى المنحوت، فتبرز التضاريس خلال اللوح بأسافين مثلثة.
	var norms := PackedVector2Array()
	var widths := PackedFloat32Array()
	var lim := WorldProfile.RIVER_HALF_WIDTH - 0.45
	var n_pts := smooth.size()
	for i in n_pts:
		var prev: Vector2 = smooth[maxi(i - 1, 0)]
		var next: Vector2 = smooth[mini(i + 1, n_pts - 1)]
		var d_in := (smooth[i] - prev)
		var d_out := (next - smooth[i])
		if d_in.length() < 0.001:
			d_in = d_out
		if d_out.length() < 0.001:
			d_out = d_in
		var nn := (d_in.normalized().orthogonal() + d_out.normalized().orthogonal())
		if nn.length() < 0.001:
			nn = d_out.normalized().orthogonal()
		norms.append(nn.normalized())
		# انعطاف حادّ ⇒ عرض أقل، وإلا تجاوزت الحافّة الخارجية المجرى
		var turn := absf(d_in.normalized().angle_to(d_out.normalized()))
		var narrow := clampf(1.0 - turn * 1.15, 0.52, 1.0)
		var f := float(i) / float(n_pts - 1)
		widths.append(minf(lerpf(3.6, 4.8, f), lim) * narrow)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := data.water_level
	for i in n_pts - 1:
		var a := smooth[i]
		var b := smooth[i + 1]
		var na := norms[i]
		var nb := norms[i + 1]
		var f0 := float(i) / float(n_pts - 1)
		var f1 := float(i + 1) / float(n_pts - 1)
		var w0 := widths[i]
		var w1 := widths[i + 1]
		var a0 := Vector3(a.x - na.x * w0, y, a.y - na.y * w0)
		var a1 := Vector3(a.x + na.x * w0, y, a.y + na.y * w0)
		var b0 := Vector3(b.x - nb.x * w1, y, b.y - nb.y * w1)
		var b1 := Vector3(b.x + nb.x * w1, y, b.y + nb.y * w1)
		_wquad(st, a0, a1, b1, b0, f0, f1)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	mi.mesh = st.commit()
	mi.material_override = WorldMaterials.water()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_root.add_child(mi)

func _wquad(st: SurfaceTool, a0: Vector3, a1: Vector3, b1: Vector3, b0: Vector3, f0: float, f1: float) -> void:
	st.set_uv(Vector2(0.0, f0 * 42.0)); st.add_vertex(a0)
	st.set_uv(Vector2(1.0, f0 * 42.0)); st.add_vertex(a1)
	st.set_uv(Vector2(1.0, f1 * 42.0)); st.add_vertex(b1)
	st.set_uv(Vector2(0.0, f0 * 42.0)); st.add_vertex(a0)
	st.set_uv(Vector2(1.0, f1 * 42.0)); st.add_vertex(b1)
	st.set_uv(Vector2(0.0, f1 * 42.0)); st.add_vertex(b0)

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

# ---------------- استعلامات ----------------
func height_at(x: float, z: float) -> float:
	return data.sample_height(x, z) if data else 0.0

func drop_to_ground(p: Vector3, offset: float = 0.0) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.z) + offset, p.z)

func poi(key: String) -> Vector3:
	if data and data.poi.has(key):
		return data.poi[key]
	return Vector3.ZERO
