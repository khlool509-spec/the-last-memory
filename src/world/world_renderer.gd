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
	"rock_s": 85.0, "rock_l": 130.0,
	"log": 60.0, "branch": 42.0, "root": 40.0, "mushroom": 26.0,
	"cobble": 50.0,
}
const CHUNK_RANGE := 300.0

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
func _build_scatter() -> void:
	scatter_root = Node3D.new()
	scatter_root.name = "Scatter"
	add_child(scatter_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldProfile.SEED

	# تجميع المفاتيح حسب المقطع ليبقى ترتيب العقد مفهوماً
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

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh_for(species, rng)
		mm.instance_count = count
		# المصفوفة مخبوزة بترتيب الـ buffer نفسه، فتُسنَد دفعة واحدة
		mm.buffer = arr

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [species, chunk_idx]
		mmi.multimesh = mm
		mmi.material_override = _mat_for(species)
		mmi.visibility_range_end = float(RANGE.get(species, 60.0))
		mmi.visibility_range_end_margin = 10.0
		# الظلال أغلى ما في المشهد: تبقى للأشجار وحدها
		mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if species in ["pine", "spruce", "oak", "birch", "willow", "dead", "rock_l"]
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		# مركز المقطع: يجعل قصّ المدى والـ frustum صحيحاً
		var ci := chunk_idx % data.grid
		var cj := int(chunk_idx / data.grid)
		mmi.position = Vector3.ZERO
		scatter_root.add_child(mmi)

func _mesh_for(species: String, rng: RandomNumberGenerator) -> ArrayMesh:
	if _mesh_cache.has(species):
		return _mesh_cache[species]
	var r := RandomNumberGenerator.new()
	r.seed = hash(species) + WorldProfile.SEED
	var m := PlantMeshes.build(species, r)
	_mesh_cache[species] = m
	return m

func _mat_for(species: String) -> Material:
	if _mat_cache.has(species):
		return _mat_cache[species]
	var m := WorldMaterials.foliage(species)
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

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := data.water_level
	for i in smooth.size() - 1:
		var a := smooth[i]
		var b := smooth[i + 1]
		var dir := (b - a).normalized()
		var nrm := dir.orthogonal()
		var f0 := float(i) / float(smooth.size() - 1)
		var f1 := float(i + 1) / float(smooth.size() - 1)
		var w0 := lerpf(4.0, 7.2, f0)
		var w1 := lerpf(4.0, 7.2, f1)
		var a0 := Vector3(a.x - nrm.x * w0, y, a.y - nrm.y * w0)
		var a1 := Vector3(a.x + nrm.x * w0, y, a.y + nrm.y * w0)
		var b0 := Vector3(b.x - nrm.x * w1, y, b.y - nrm.y * w1)
		var b1 := Vector3(b.x + nrm.x * w1, y, b.y + nrm.y * w1)
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
