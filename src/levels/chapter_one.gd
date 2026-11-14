class_name ChapterOne
extends GameLevel
## الفصل الأول: الغابة المنسية.
## يستيقظ المجهول في مقطع غابة ليلية، يجد أثراً، يتبع الفوانيس، ويصل إلى البوابة.

const SEED := 20261114
const GROUND_SIZE := 160.0
const GATE_Z := -36.0

var _rng := RandomNumberGenerator.new()
var _blocked: Array[Vector3] = []

func _init() -> void:
	chapter_index = 1
	spawn_point = Vector3(0, 1.3, 14.0)
	spawn_yaw_deg = 0.0

func build_world() -> void:
	name = "ChapterOneForest"
	_rng.seed = SEED
	_build_environment()
	add_child(ForestBuilder.make_ground(GROUND_SIZE))
	_build_path()
	_build_trees()
	add_child(ForestBuilder.make_shrubs(_rng, 340, 56.0))
	add_child(ForestBuilder.make_far_forest(_rng, 240, 60.0, 98.0))
	_build_rocks()
	_build_gate()
	add_child(ForestBuilder.make_bounds(62.0))

# ---------- البيئة ----------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.016, 0.020, 0.035)
	sm.sky_horizon_color = Color(0.055, 0.071, 0.106)
	sm.ground_bottom_color = Color(0.012, 0.016, 0.024)
	sm.ground_horizon_color = Color(0.043, 0.055, 0.078)
	sm.sun_angle_max = 18.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.38
	env.ambient_light_color = Color(0.157, 0.192, 0.251)
	# ضباب عمقي فقط — الحجمي غير مدعوم على Mobile renderer
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.106, 0.133, 0.180)
	env.fog_light_energy = 0.8
	env.fog_density = 0.028
	env.fog_depth_begin = 12.0
	env.fog_depth_end = 86.0
	env.fog_sky_affect = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 0.92
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 0.88
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.631, 0.722, 0.878)
	moon.light_energy = 0.62
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55.0
	moon.shadow_bias = 0.04
	moon.transform = Transform3D(Basis(), Vector3(18, 34, 22)).looking_at(Vector3.ZERO, Vector3.UP)
	add_child(moon)

# ---------- الممر ----------
func _path_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0, 0, 18),
		Vector3(1.5, 0, 8),
		Vector3(-2.0, 0, -1),
		Vector3(1.0, 0, -11),
		Vector3(-1.5, 0, -21),
		Vector3(0, 0, -30),
		Vector3(0, 0, GATE_Z + 2.0),
	])

func _build_path() -> void:
	var pts := _path_points()
	add_child(ForestBuilder.make_path(pts, 3.2))
	for p in pts:
		_blocked.append(p)

func _near_path(p: Vector3, margin: float) -> bool:
	for b in _blocked:
		if Vector2(p.x - b.x, p.z - b.z).length() < margin:
			return true
	# الممر خط مستمر: امنع أي شجرة ضمن شريط حول محور Z
	if absf(p.x) < margin and p.z > GATE_Z - 2.0 and p.z < 20.0:
		return true
	return false

# ---------- الأشجار ----------
## الغابة تُبنى حول الممر لا عشوائياً في الساحة: حزام كثيف على
## جانبي الطريق يصنع ممراً مغلقاً، ثم حشو أبعد يغلق الأفق.
## الأشجار القريبة فقط لها تصادم؛ البقية MultiMesh بنداءي رسم.
const COLLIDE_RADIUS := 15.0

func _dist_to_path(p: Vector3) -> float:
	var pts := _path_points()
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, _seg_dist(p, pts[i], pts[i + 1]))
	return best

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.0001 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
	return (ap - ab * t).length()

func _build_trees() -> void:
	var pts := _path_points()
	var collide: Array[Vector3] = []
	var visual: Array = []

	# 1) حزام كثيف على جانبي الممر. تُجمع المرشّحات أولاً ثم تُختار
	# أشجار التصادم موزّعة على طول الممر — لا أول 46 وإلا تكدّست عند البداية.
	var belt: Array = []
	var steps := 48
	for i in steps:
		var f := float(i) / float(steps - 1)
		var along := _point_along(pts, f)
		for side in [-1.0, 1.0]:
			var count := _rng.randi_range(2, 4)
			for k in count:
				var off := _rng.randf_range(4.2, 13.5)
				var jitter := Vector3(_rng.randf_range(-2.2, 2.2), 0.0, _rng.randf_range(-2.6, 2.6))
				var p := along + Vector3(side * off, 0.0, 0.0) + jitter
				if _reject(p) or _dist_to_path(p) < 3.4:
					continue
				belt.append({"p": p, "f": f})

	var want_collide := 48
	var near_belt: Array = []
	for e in belt:
		if _dist_to_path(e["p"]) <= COLLIDE_RADIUS:
			near_belt.append(e)
	var stride := maxf(1.0, float(near_belt.size()) / float(want_collide))
	var taken := {}
	var ci := 0.0
	while ci < float(near_belt.size()) and collide.size() < want_collide:
		var idx := int(ci)
		taken[idx] = true
		collide.append(near_belt[idx]["p"])
		ci += stride
	for i in near_belt.size():
		if not taken.has(i):
			visual.append(near_belt[i]["p"])
	for e in belt:
		if _dist_to_path(e["p"]) > COLLIDE_RADIUS:
			visual.append(e["p"])

	# 2) حشو الغابة حول الممر حتى 58 متراً
	var guard := 0
	while visual.size() < 420 and guard < 6000:
		guard += 1
		var ang := _rng.randf_range(0.0, TAU)
		var rad := sqrt(_rng.randf()) * 58.0
		var p := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad - 9.0)
		if _reject(p) or _dist_to_path(p) < 5.5:
			continue
		visual.append(p)

	var near_root := Node3D.new()
	near_root.name = "NearTrees"
	add_child(near_root)
	for p in collide:
		var t := ForestBuilder.make_tree(_rng, true)
		t.position = p
		near_root.add_child(t)

	add_child(ForestBuilder.make_tree_field(_rng, visual, "TreeField"))

func _point_along(pts: PackedVector3Array, f: float) -> Vector3:
	var total := 0.0
	var lens: Array[float] = []
	for i in pts.size() - 1:
		var l := Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
		lens.append(l)
		total += l
	var want := f * total
	var acc := 0.0
	for i in lens.size():
		if acc + lens[i] >= want:
			var t := 0.0 if lens[i] < 0.001 else (want - acc) / lens[i]
			return pts[i].lerp(pts[i + 1], t)
		acc += lens[i]
	return pts[pts.size() - 1]

## يرفض المواضع المحجوزة: نقطة البداية والبوابة والسور
func _reject(p: Vector3) -> bool:
	if p.distance_to(Vector3(spawn_point.x, 0.0, spawn_point.z)) < 5.5:
		return true
	if absf(p.z - GATE_Z) < 4.5:
		return true
	if p.z < GATE_Z - 3.0 and absf(p.x) < 10.0:
		return true
	return false

func _build_rocks() -> void:
	var root := Node3D.new()
	root.name = "Rocks"
	add_child(root)
	for i in 26:
		var ang := _rng.randf_range(0.0, TAU)
		var rad := _rng.randf_range(6.0, 48.0)
		var p := Vector3(cos(ang) * rad, 0.2, sin(ang) * rad - 6.0)
		if _near_path(p, 3.0):
			continue
		var r := ForestBuilder.make_rock(_rng)
		r.position = p
		root.add_child(r)

func _build_gate() -> void:
	var g := ForestBuilder.make_gate()
	g.position = Vector3(0, 0, GATE_Z)
	add_child(g)

	# سور حجري يمتد يميناً ويساراً فيصبح العبور ممكناً من البوابة فقط
	var wall_mat := ForestBuilder.mat(Color(0.098, 0.102, 0.114), 0.95)
	for side in [-1.0, 1.0]:
		for i in 11:
			var seg := StaticBody3D.new()
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(6.0, 3.6, 0.9)
			mi.mesh = bm
			mi.material_override = wall_mat
			mi.position = Vector3(0, 1.8, 0)
			seg.add_child(mi)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(6.0, 3.6, 0.9)
			cs.shape = box
			cs.position = Vector3(0, 1.8, 0)
			seg.add_child(cs)
			seg.position = Vector3(side * (3.6 + i * 6.0), 0, GATE_Z)
			add_child(seg)

# ---------- المحتوى ----------
func place_contents() -> void:
	_place_lanterns()
	_place_note_awakening()
	_place_items()
	_place_triggers()

func _place_lanterns() -> void:
	var spots := [
		Vector3(2.6, 0, 7.0),
		Vector3(-3.4, 0, -2.0),
		Vector3(2.8, 0, -12.0),
		Vector3(-3.0, 0, -22.0),
		Vector3(2.4, 0, -31.0),
	]
	var root := Node3D.new()
	root.name = "Lanterns"
	add_child(root)
	for s in spots:
		var l := ForestBuilder.make_lantern(2.4)
		l.position = s
		root.add_child(l)

func _place_note_awakening() -> void:
	var n := NoteItem.new()
	n.name = "NoteAwakening"
	n.item_id = "note_awakening"
	n.position = Vector3(1.4, 0.9, 11.2)
	var paper := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.015, 0.46)
	paper.mesh = bm
	paper.material_override = ForestBuilder.emissive(Color(0.85, 0.82, 0.74), 0.35)
	paper.rotation = Vector3(0.0, 0.5, 0.18)
	n.add_child(paper)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.6
	cs.shape = sp
	n.add_child(cs)
	n.read_requested.connect(func(id: String) -> void:
		read_note(id)
		Goals.complete("find_note"))
	add_child(n)

func _place_items() -> void:
	_pickup("lantern", Vector3(-2.2, 0.85, 2.4), _glow_box(Color(1.0, 0.62, 0.32)))
	_pickup("old_key", Vector3(5.6, 0.75, -8.2), _glow_box(Color(0.72, 0.65, 0.44)))
	_pickup("pendant", Vector3(-5.1, 0.8, -18.5), _glow_box(Color(0.78, 0.80, 0.86)))

	var burnt := NoteItem.new()
	burnt.name = "NoteLantern"
	burnt.item_id = "note_lantern"
	burnt.position = Vector3(3.2, 0.85, -25.0)
	var paper := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.015, 0.38)
	paper.mesh = bm
	paper.material_override = ForestBuilder.emissive(Color(0.76, 0.70, 0.60), 0.3)
	paper.rotation = Vector3(0.0, -0.7, 0.1)
	burnt.add_child(paper)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.6
	cs.shape = sp
	burnt.add_child(cs)
	burnt.read_requested.connect(func(id: String) -> void: read_note(id))
	add_child(burnt)

func _glow_box(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.26, 0.26, 0.26)
	mi.mesh = bm
	mi.material_override = ForestBuilder.emissive(col, 1.1)
	return mi

func _pickup(item_id: String, pos: Vector3, visual: Node3D) -> void:
	var p := Pickup.new()
	p.name = "Pickup_" + item_id
	p.item_id = item_id
	p.position = pos
	p.add_child(visual)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.55
	cs.shape = sp
	p.add_child(cs)
	var halo := OmniLight3D.new()
	halo.light_color = Color(1.0, 0.82, 0.60)
	halo.light_energy = 0.9
	halo.omni_range = 3.2
	halo.shadow_enabled = false
	p.add_child(halo)
	add_child(p)

func _place_triggers() -> void:
	var t_wake := TriggerZone.new()
	t_wake.name = "TriggerWake"
	t_wake.save_flag = "ch1_wake"
	t_wake.setup_sphere(7.0)
	t_wake.position = Vector3(0.8, 1.0, 10.5)
	t_wake.entered.connect(func(_b: Node3D) -> void:
		hud.toast("رأسك يؤلمك. لا تذكر كيف وصلت إلى هنا.", "", Palette.MOON_DIM)
		Goals.complete("wake"))
	add_child(t_wake)

	var t_follow := TriggerZone.new()
	t_follow.name = "TriggerFollow"
	t_follow.save_flag = "ch1_follow"
	t_follow.setup_box(Vector3(14.0, 4.0, 5.0))
	t_follow.position = Vector3(0, 1.5, 0.0)
	t_follow.entered.connect(func(_b: Node3D) -> void:
		Goals.complete("follow_lanterns"))
	add_child(t_follow)

	var t_gate := TriggerZone.new()
	t_gate.name = "TriggerGate"
	t_gate.save_flag = "ch1_gate"
	t_gate.setup_box(Vector3(10.0, 4.0, 6.0))
	t_gate.position = Vector3(0, 1.5, GATE_Z + 5.0)
	t_gate.entered.connect(_on_reach_gate)
	add_child(t_gate)

func _on_reach_gate(_b: Node3D) -> void:
	Goals.complete("reach_gate")
	hud.toast("البوابة… الرموز عليها تتحرك حين لا تنظر إليها.", "✵", Palette.BLOOD)
	Audio.play("gate", 1.0, -2.0)
	SaveSystem.unlock_chapter(2)
