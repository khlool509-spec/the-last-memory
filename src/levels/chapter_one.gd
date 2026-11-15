class_name ChapterOne
extends GameLevel
## الفصل الأول: الغابة المنسية — عالم مفتوح 400×400 متر.
## كل الشكل يأتي من WorldProfile المخبوز؛ هنا يُركَّب ويُسكَن.

var world: WorldRenderer
var _sun: DirectionalLight3D
## كم عقدة أُزيلت بالدمج — تقرؤها الاختبارات والمسبار
var merged_nodes: int = 0
var _env: Environment
var _lamps: Array[OmniLight3D] = []
var _glows: Array[MeshInstance3D] = []
var _preset: Dictionary = {}

func _init() -> void:
	chapter_index = 1
	ambient_key = "forest"

func build_world() -> void:
	name = "ChapterOneForest"
	_build_environment()
	world = WorldRenderer.new()
	add_child(world)

	# نقطة البداية من موقع العالم نفسه، مرفوعة فوق الأرض
	var s := world.poi("spawn")
	spawn_point = Vector3(s.x, s.y + 1.4, s.z)
	# يواجه مفترق الطرق فيرى الطريق أمامه
	var cross := world.poi("crossroad")
	var dir := Vector2(cross.x - s.x, cross.z - s.z)
	spawn_yaw_deg = rad_to_deg(atan2(-dir.x, -dir.y))

	_biome = Biome.new(WorldProfile.new())
	_build_bridges()
	_build_landmarks()

# ---------------- الجو ----------------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	# خريطة الإشعاع هي مصدر الضوء المحيط كلّه. بـINCREMENTAL تُبنى
	# على مدى إطارات كثيرة فتبقى باهتة، فيخرج الظل أسود مهما رُفعت
	# طاقة المحيط. السماء هنا لا تتغيّر إلا عند تبديل وقت اليوم،
	# فبناؤها مرّة بجودة عالية هو الصواب وأرخص من الزيادي.
	# (128 لا 256: الثانية تُبنى بالتصيير البرمجي في دقائق لا ثوانٍ.)
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var shader: Shader = ResourceLoader.load("res://assets/shaders/sky.gdshader")
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# الملء المحيطي: تُرك على الافتراضي فسقطت الظلال سوداء تماماً.
	# في الواقع لا يوجد ظل أسود تحت سماء مفتوحة — السماء نفسها مصدر
	# ضوء يملأ ما تحجبه الشمس. هذا سبب البقع الداكنة التي صوّرها
	# اللاعب: ليست عيباً في الظل بل غياب الضوء المرتد.
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.85

	# ضباب عمقي: العمق البصري ومحدّد المدى معاً. الحجمي غير مدعوم هنا.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_energy = 1.0
	env.fog_density = 0.010
	env.fog_aerial_perspective = 0.55
	# ضباب بارتفاع: الضباب العمقي وحده يملأ السماء القريبة من الأفق
	# بحزام أبيض لأنه يطال كل بُعد بالتساوي. بالارتفاع يستقرّ في بطن
	# الوادي ويخفّ فوقه، فيصير منظوراً جوّياً لا جداراً.
	# القيم الأولى (6.0 / 0.055) أغرقت بطن الوادي كلّه في بياض:
	# أرض النهر تحت 6 أمتار فدخلت كلها في الطبقة الكثيفة.
	# الارتفاع الآن عند منسوب الماء تقريباً والكثافة عُشر ما كانت.
	env.fog_height = 1.5
	env.fog_height_density = 0.006

	# حجب محيطي: يُعتم الشقوق وملتقى الجدار بالأرض. بدونه يطفو كل
	# جسم فوق الأرض بلا تماسّ، وهو أظهر فارق عن المرجع السينمائي.
	# تقييم الإضاءة غير المباشرة: SDFGI يُفعَّل بمفتاح بيئة للقياس
	# وحده. القرار يُبنى على الكلفة المقيسة لا على الاسم.
	if OS.get_environment("GI_SDFGI") == "1":
		env.sdfgi_enabled = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.25
		env.sdfgi_use_occlusion = true
		env.sdfgi_energy = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.4
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.07
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.12
	env.ssao_ao_channel_affect = 0.35

	# ارتداد غير مباشر في فضاء الشاشة: العشب المشمس يُلقي ضوءه على
	# الجدار الظليل، فيكفّ الظل عن أن يكون أسود ميتاً.
	env.ssil_enabled = true
	env.ssil_radius = 4.5
	env.ssil_intensity = 1.15
	env.ssil_sharpness = 0.96
	env.ssil_normal_rejection = 1.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	we.environment = env
	_env = env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.name = "KeyLight"
	_sun.shadow_enabled = true
	# تقسيمان لا أربعة: أطلس 2048 على الجوال مقسوماً على أربعة يعطي
	# 1024 لكل تقسيم، وهي دقّة تُنتج تشوّه ظل يظهر كبقع مثلثة داكنة.
	# بتقسيمين يصير لكل واحد 1448، والفرق مرئي مباشرة.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# انحياز أعلى: مع دقّة الجوال المنخفضة، الانحياز الصغير يُنتج
	# «حَبّ الظل» — خطوطاً داكنة على أسطح مضاءة.
	_sun.shadow_bias = 0.06
	_sun.shadow_normal_bias = 2.4
	# مدى الظل: الافتراضي 100 م يقطع الظل بخط مستقيم عبر الشاشة.
	_sun.directional_shadow_max_distance = 165.0
	_sun.directional_shadow_fade_start = 0.82
	# الشمس قرص عرضه 0.53 درجة لا نقطة. بصفر كان كل ظل حادّاً كالسكّين
	# مهما بَعُد؛ بالعرض الزاوي يتّسع شبه الظلّ مع المسافة كما في الواقع.
	_sun.light_angular_distance = 0.55
	_sun.shadow_blur = 1.0
	# التقسيمات تُقرّب دقّة الظل من الكاميرا حيث تُرى الحافّة
	_sun.directional_shadow_split_1 = 0.11
	_sun.directional_shadow_split_2 = 0.34
	_sun.directional_shadow_split_3 = 0.60
	_sun.directional_shadow_blend_splits = true
	add_child(_sun)

	# ربط مدير الرسومات بالبيئة والشمس: من هنا تصير إعدادات
	# الجودة والظلال والنمط تغييرات حقيقية في هذا المشهد.
	Graphics.bind_world(_env, _sun)
	_apply_daylight()
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if key == "time_of_day" or key == "brightness":
			_apply_daylight())

## يطبّق وقت اليوم والسطوع على كل ما يتأثر بهما معاً
func _apply_daylight() -> void:
	var key := str(Settings.get_value("time_of_day"))
	var bright := float(Settings.get_value("brightness"))
	_preset = Daylight.preset(key)
	Daylight.apply(_env, _sun, key, bright)
	WorldMaterials.set_foliage_tint(_preset.get("foliage_tint", Color.WHITE))
	_fog_density = lerpf(float(_preset["fog_near"]), float(_preset["fog_far"]), 0.5)
	_fog_color = _preset["fog_color"]
	_scale_lamps()

## الفوانيس وأضواء الداخل تخفت نهاراً فلا تبدو مصابيح في وضح الشمس.
## الزجاج المتوهّج يخفت معها، وإلا بقي مربعاً مضيئاً تحت الشمس.
func _scale_lamps() -> void:
	var k := float(_preset.get("lamp_scale", 1.0))
	for l in _lamps:
		if is_instance_valid(l):
			l.light_energy = l.get_meta("base_energy", 2.0) * k
	for g in _glows:
		if is_instance_valid(g):
			var m := g.material_override as StandardMaterial3D
			if m:
				m.emission_energy_multiplier = g.get_meta("base_emission", 2.0) * maxf(k, 0.18)

func _register_lamps(root: Node) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var mm := mi.material_override as StandardMaterial3D
		if mm and mm.emission_enabled and mm.emission_energy_multiplier > 1.0:
			if not mi.has_meta("base_emission"):
				mi.set_meta("base_emission", mm.emission_energy_multiplier)
			_glows.append(mi)
	if root is OmniLight3D:
		var l := root as OmniLight3D
		if not l.has_meta("base_energy"):
			l.set_meta("base_energy", l.light_energy)
		_lamps.append(l)
	for c in root.get_children():
		_register_lamps(c)

# ---------------- الجسور ----------------
## الطرق تعبر النهر؛ بلا جسر يسقط اللاعب في الماء.
func _build_bridges() -> void:
	var root := Node3D.new()
	root.name = "Bridges"
	add_child(root)
	var b := world.poi("bridge")
	root.add_child(Structures.plank_bridge(world, Vector3(b.x, 0, b.z), 26.0, 4.2))

# ---------------- المعالم والمباني ----------------
var buildings: Dictionary = {}

func _build_landmarks() -> void:
	var root := Node3D.new()
	root.name = "Landmarks"
	add_child(root)

	# البوابة الأثرية على نتوء مرتفع: تُرى من بعيد فتجذب الاستكشاف
	var g := world.poi("gate")
	var gate := ForestBuilder.make_gate()
	gate.position = Vector3(g.x, world.height_at(g.x, g.z), g.z)
	gate.rotation.y = deg_to_rad(18.0)
	root.add_child(gate)

	# كل مبنى يواجه أقرب طريق إليه، فيبدو مبنياً لأجل الناس لا موضوعاً عشوائياً
	buildings["hut"] = Structures.watchman_hut(world, world.poi("hut"), _face_road(world.poi("hut")))
	buildings["old_house"] = Structures.old_house(world, world.poi("old_house"), _face_road(world.poi("old_house")))
	buildings["store"] = Structures.storehouse(world, world.poi("store"), _face_road(world.poi("store")))
	buildings["ruin"] = Structures.ruin(world, world.poi("ruin"), deg_to_rad(28.0))
	buildings["well"] = Structures.well(world, world.poi("well"))
	for k in buildings:
		root.add_child(buildings[k])

	_build_lantern_trail(root)

## يوجّه المبنى نحو أقرب نقطة على شبكة الطرق
func _face_road(p: Vector3) -> float:
	var best := INF
	var target := Vector2(p.x, p.z)
	for seg in world.data.road_segments:
		var a := Vector2(seg[0], seg[1])
		var b := Vector2(seg[2], seg[3])
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 < 0.001 else clampf((Vector2(p.x, p.z) - a).dot(ab) / l2, 0.0, 1.0)
		var q := a.lerp(b, t)
		var d := Vector2(p.x, p.z).distance_to(q)
		if d < best and d > 0.5:
			best = d
			target = q
	var dir := target - Vector2(p.x, p.z)
	return atan2(dir.x, dir.y)

## فوانيس على الطريق الرئيسي: ترشد الليل وتحدّد المسار الآمن
func _build_lantern_trail(root: Node3D) -> void:
	var chain := ["spawn", "crossroad", "bridge", "old_house", "well", "gate"]
	for i in chain.size() - 1:
		var a := world.poi(chain[i])
		var b := world.poi(chain[i + 1])
		var steps := maxi(2, int(Vector2(b.x - a.x, b.z - a.z).length() / 22.0))
		for k in range(1, steps):
			var t := float(k) / float(steps)
			var x := lerpf(a.x, b.x, t)
			var z := lerpf(a.z, b.z, t)
			# يُزاح جانباً فلا يقف في منتصف الطريق
			var off := 2.6 if k % 2 == 0 else -2.6
			var perp := Vector2(b.z - a.z, a.x - b.x).normalized() * off
			x += perp.x
			z += perp.y
			if world.height_at(x, z) < world.data.water_level + 0.4:
				continue
			var l := Structures.lantern_post(2.0)
			l.position = Vector3(x, world.height_at(x, z), z)
			l.rotation.y = randf_range(0.0, TAU)
			root.add_child(l)

func place_contents() -> void:
	_place_story_items()
	_place_doors()
	_place_triggers()
	# دمج أشكال البناء الساكنة قبل مستويات التفصيل: 302 عقدة مقابل
	# 21,880 مثلثاً — الكلفة في عدد الاستدعاءات لا في الهندسة.
	# يُنفَّذ قبل Lod.apply ليأخذ الناتج المدموج نطاقات الرؤية.
	var merged := 0
	if bool(Settings.get_value("merge_statics")):
		for bn in ["Landmarks", "Bridges"]:
			var br := get_node_or_null(bn)
			if br:
				for b in br.get_children():
					if b is Node3D:
						merged += MeshMerge.merge_subtree(b)
	merged_nodes = merged

	# مستويات التفصيل على كل ما بُني: مبانٍ وجسور ومعالم وما يُضاف لاحقاً
	var qs := Lod.scale_for_quality(str(Settings.get_value("graphics_quality")))
	var touched := 0
	for group_name in ["Landmarks", "Bridges", "Story"]:
		var g := get_node_or_null(group_name)
		if g:
			touched += Lod.apply(g, Lod.STRUCTURE, qs)
	Lod.apply_lights(self, 52.0 * qs)

	_lamps.clear()
	_glows.clear()
	_register_lamps(self)
	_scale_lamps()

## الأهداف تتقدّم بالوصول إلى أماكن حقيقية، لا بعدّاد خفي
func _place_triggers() -> void:
	var root := Node3D.new()
	root.name = "Triggers"
	add_child(root)

	var s := world.poi("spawn")
	var t_wake := TriggerZone.new()
	t_wake.name = "TriggerWake"
	t_wake.save_flag = "ch1_wake"
	t_wake.setup_sphere(9.0)
	t_wake.position = Vector3(s.x, s.y + 1.0, s.z)
	t_wake.entered.connect(func(_b: Node3D) -> void:
		hud.toast("رأسك يؤلمك. لا تذكر كيف وصلت إلى هنا.", "", Palette.MOON_DIM)
		Goals.complete("wake"))
	root.add_child(t_wake)

	var cr := world.poi("crossroad")
	var t_follow := TriggerZone.new()
	t_follow.name = "TriggerCrossroad"
	t_follow.save_flag = "ch1_follow"
	t_follow.setup_sphere(11.0)
	t_follow.position = Vector3(cr.x, cr.y + 1.5, cr.z)
	t_follow.entered.connect(func(_b: Node3D) -> void:
		hud.toast("مفترق طرق. أحدهم مرّ من هنا كثيراً.", "", Palette.DUST)
		Goals.complete("follow_lanterns"))
	root.add_child(t_follow)

	var g := world.poi("gate")
	var t_gate := TriggerZone.new()
	t_gate.name = "TriggerGate"
	t_gate.save_flag = "ch1_gate"
	t_gate.setup_sphere(12.0)
	t_gate.position = Vector3(g.x, g.y + 1.5, g.z)
	t_gate.entered.connect(_on_reach_gate)
	root.add_child(t_gate)

	# اكتشافات صامتة تكافئ الاستكشاف بلا هدف معلن
	var finds := [
		["ruin", "حجارة قديمة. هذا المكان كان مسكوناً.", 11.0],
		["overlook", "من هنا يُرى الوادي كله. والنهر يلمع تحت القمر.", 10.0],
		["well", "بئر. الحبل مقطوع والدلو ما زال معلّقاً.", 7.0],
		["hollow", "منخفض مظلم. لا يصله ضوء القمر.", 9.0],
	]
	for f in finds:
		var p3 := world.poi(str(f[0]))
		var tz := TriggerZone.new()
		tz.name = "Find_" + str(f[0])
		tz.save_flag = "found_" + str(f[0])
		tz.setup_sphere(float(f[2]))
		tz.position = Vector3(p3.x, p3.y + 1.5, p3.z)
		var msg := str(f[1])
		tz.entered.connect(func(_b: Node3D) -> void:
			hud.toast(msg, "", Palette.MOON_DIM))
		root.add_child(tz)

func _on_reach_gate(_b: Node3D) -> void:
	Goals.complete("reach_gate")
	hud.toast("البوابة… الرموز عليها تتحرك حين لا تنظر إليها.", "✵", Palette.BLOOD)
	Audio.play("gate", 1.0, -2.0)
	SaveSystem.unlock_chapter(2)

## الأغراض تُروى بمكانها: الورقة الأولى عند الاستيقاظ، والمفتاح في
## المخزن، والقلادة في الخرِبة — فالقصة تُكتشف بالمشي لا بالشرح.
func _place_story_items() -> void:
	var root := Node3D.new()
	root.name = "Story"
	add_child(root)

	var s := world.poi("spawn")
	var n1 := Structures.paper_note("note_awakening")
	n1.position = _ground(s.x + 2.2, s.z - 1.4, 0.9)
	n1.read_requested.connect(func(id: String) -> void:
		read_note(id)
		Goals.complete("find_note"))
	root.add_child(n1)

	var st := world.poi("store")
	var key := Structures.container_box("old_key", "افتح الصندوق")
	key.position = _ground(st.x + 1.6, st.z - 0.9, 0.22)
	root.add_child(key)

	var r := world.poi("ruin")
	root.add_child(_pickup_at("pendant", r.x + 1.8, r.z + 1.2, 0.8, Color(0.78, 0.80, 0.86)))

	var h := world.poi("hut")
	var n2 := Structures.paper_note("note_lantern")
	n2.position = _ground(h.x - 1.1, h.z + 0.7, 0.95)
	n2.read_requested.connect(func(id: String) -> void: read_note(id))
	root.add_child(n2)

	var ov := world.poi("overlook")
	root.add_child(_pickup_at("lantern", ov.x + 1.2, ov.z - 1.0, 0.8, Color(1.0, 0.62, 0.32)))

	var hol := world.poi("hollow")
	root.add_child(_pickup_at("gate_sigil", hol.x - 1.4, hol.z + 1.1, 0.8, Color(0.76, 0.14, 0.19)))

func _pickup_at(item_id: String, x: float, z: float, lift: float, glow: Color) -> Pickup:
	var p := Pickup.new()
	p.item_id = item_id
	p.position = _ground(x, z, lift)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.24, 0.24)
	mi.mesh = bm
	mi.material_override = WorldMaterials.emissive(glow, 1.0)
	p.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	cs.shape = sh
	p.add_child(cs)
	var halo := OmniLight3D.new()
	halo.light_color = glow
	halo.light_energy = 0.8
	halo.omni_range = 3.4
	halo.shadow_enabled = false
	p.add_child(halo)
	return p

## الأبواب تُركَّب في فتحات المباني نفسها
func _place_doors() -> void:
	var specs := [
		{"b": "hut", "w": 1.15, "h": 2.05, "key": ""},
		{"b": "old_house", "w": 1.25, "h": 2.2, "key": "old_key"},
		{"b": "store", "w": 1.6, "h": 2.25, "key": ""},
	]
	for sp in specs:
		var host: Node3D = buildings.get(sp["b"])
		if host == null or not host.has_meta("door_world"):
			continue
		var local: Vector3 = host.get_meta("door_world")
		var d := Structures.hinged_door(float(sp["w"]), float(sp["h"]), str(sp["key"]))
		d.position = local - Vector3(float(sp["w"]) * 0.5, 0.0, 0.5)
		d.save_flag = "door_" + str(sp["b"])
		d.opened.connect(func() -> void:
			hud.toast("انفتح الباب", "", Palette.MOON_DIM)
			Audio.play("ui_click", 0.7, -4.0))
		d.refused.connect(func(reason: String) -> void:
			hud.toast(reason, "", Palette.SMOKE))
		host.add_child(d)

func _ground(x: float, z: float, lift: float) -> Vector3:
	return Vector3(x, world.height_at(x, z) + lift, z)

# ---------------- المناطق: صوت وضباب يتبعان المكان ----------------
const ZONE_TICK := 0.28
var _zone_t := 0.0
var _fog_density := 0.016
var _fog_color := Color(0.094, 0.122, 0.165)
var _biome: Biome

func _zone_update() -> void:
	if player == null or world == null:
		return
	var p := player.global_position
	var ground := world.height_at(p.x, p.z)
	var wl := world.data.water_level

	# قرب النهر
	var river_d := INF
	for i in world.data.river_points.size() - 1:
		var a := world.data.river_points[i]
		var b := world.data.river_points[i + 1]
		var ab := b - a
		var l2 := ab.length_squared()
		var tt := 0.0 if l2 < 0.001 else clampf((Vector2(p.x, p.z) - a).dot(ab) / l2, 0.0, 1.0)
		river_d = minf(river_d, Vector2(p.x, p.z).distance_to(a.lerp(b, tt)))

	# داخل مبنى مسقوف. الخرِبة بلا سقف والبئر ليس مبنى، فيُستثنيان.
	const ROOFED := ["hut", "old_house", "store"]
	var inside := false
	for k in ROOFED:
		var b: Node3D = buildings.get(k)
		if b == null:
			continue
		var r: float = 3.2 if k == "hut" else (4.6 if k == "old_house" else 3.6)
		if Vector2(p.x - b.global_position.x, p.z - b.global_position.z).length() < r:
			inside = true
			break

	# صوت النهر يخفت تدريجياً ويصمت تماماً عند 50 متراً.
	# التربيع يجعل الانخفاض سريعاً قرب الحافة وبطيئاً قرب الماء،
	# وهو ما تفعله الصوتيات الحقيقية: الشدّة تتناقص مع مربّع المسافة.
	var w_river := clampf(1.0 - river_d / 50.0, 0.0, 1.0)
	w_river = w_river * w_river
	var w_indoor := 1.0 if inside else 0.0
	var w_forest := clampf(1.0 - w_indoor, 0.0, 1.0) * clampf(1.0 - w_river * 0.55, 0.35, 1.0) * 0.55
	Audio.set_layer_mix({"forest": w_forest, "river": w_river, "indoor": w_indoor})

	# الانفتاح: كم يرتفع الموضع فوق منسوب الماء. يستخدمه الضباب أدناه.
	var open := clampf((ground - wl) / 14.0, 0.0, 1.0)

	# السطح تحت القدم
	var on_structure := p.y > ground + 0.55
	if on_structure:
		player.surface = "wood"
	elif ground < wl + 0.35 or river_d < WorldProfile.RIVER_HALF_WIDTH + 1.0:
		player.surface = "water"
	else:
		var kind := _biome.at(p.x, p.z) if _biome else Biome.Kind.FOREST
		if kind == Biome.Kind.ROCKY:
			player.surface = "stone"
		elif kind == Biome.Kind.SETTLED:
			player.surface = "stone"
		else:
			player.surface = "grass"

	# الضباب يثقل في بطن الوادي ويخفّ على المرتفعات
	var f_far := float(_preset.get("fog_far", 0.030))
	var f_near := float(_preset.get("fog_near", 0.0085))
	var want_density := lerpf(f_far, f_near, open)
	if inside:
		want_density = f_near * 0.45
	var base_fog: Color = _preset.get("fog_color", Color(0.094, 0.122, 0.165))
	var want_color := base_fog.lerp(base_fog.lightened(0.06), w_river)
	_fog_density = lerpf(_fog_density, want_density, 0.12)
	_fog_color = _fog_color.lerp(want_color, 0.12)
	if _env:
		_env.fog_density = _fog_density
		_env.fog_light_color = _fog_color

func _process(delta: float) -> void:
	super._process(delta)
	_zone_t -= delta
	if _zone_t <= 0.0:
		_zone_t = ZONE_TICK
		_zone_update()
