class_name ForestBuilder
extends RefCounted
## يبني غابة ليلية بالكود. الأشجار القريبة أجسام حقيقية بتصادم،
## والبعيدة MultiMesh بلا تصادم حفاظاً على الأداء على الجوال.

const TRUNK := Color(0.078, 0.071, 0.063)
const TRUNK_PALE := Color(0.129, 0.114, 0.098)
const LEAF_DARK := Color(0.035, 0.055, 0.047)
const LEAF_MID := Color(0.051, 0.078, 0.063)
const GROUND := Color(0.055, 0.059, 0.051)
const ROCK := Color(0.102, 0.106, 0.118)

static func mat(col: Color, rough: float = 0.95, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

static func emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

# ---------- الأرض ----------
static func make_ground(size: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	mi.mesh = pm
	mi.material_override = mat(GROUND, 0.98)
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 0.6, size)
	col.shape = box
	col.position = Vector3(0, -0.3, 0)
	body.add_child(col)
	return body

## ممر ترابي فاتح يرشد اللاعب بصرياً
static func make_path(points: PackedVector3Array, width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Path"
	var m := mat(Color(0.129, 0.118, 0.098), 1.0)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var len_ab := a.distance_to(b)
		bm.size = Vector3(width, 0.06, len_ab + width * 0.5)
		seg.mesh = bm
		seg.material_override = m
		var mid := (a + b) * 0.5
		mid.y = 0.03
		var look_target := Vector3(b.x, 0.03, b.z)
		if mid.distance_to(look_target) > 0.01:
			seg.transform = Transform3D(Basis(), mid).looking_at(look_target, Vector3.UP)
		else:
			seg.position = mid
		root.add_child(seg)
	return root

# ---------- الأشجار ----------
static func make_tree(rng: RandomNumberGenerator, with_collision: bool) -> Node3D:
	var h := rng.randf_range(5.5, 11.0)
	var r := rng.randf_range(0.17, 0.34)
	var lean := rng.randf_range(-0.07, 0.07)

	var root: Node3D
	if with_collision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.height = h
		cyl.radius = maxf(r * 1.5, 0.3)
		cs.shape = cyl
		cs.position = Vector3(0, h * 0.5, 0)
		sb.add_child(cs)
		root = sb
	else:
		root = Node3D.new()

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.45
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 7
	cm.rings = 1
	trunk.mesh = cm
	trunk.position = Vector3(0, h * 0.5, 0)
	trunk.rotation = Vector3(lean, rng.randf_range(0.0, TAU), lean * 0.6)
	trunk.material_override = mat(TRUNK if rng.randf() < 0.7 else TRUNK_PALE, 0.98)
	root.add_child(trunk)

	# طبقات أوراق مخروطية — صنوبر ليلي
	var layers := rng.randi_range(3, 4)
	var base_y := h * rng.randf_range(0.42, 0.52)
	for i in layers:
		var f := float(i) / float(layers)
		var cone := MeshInstance3D.new()
		var cone_m := CylinderMesh.new()
		cone_m.top_radius = 0.0
		cone_m.bottom_radius = lerpf(h * 0.26, h * 0.10, f) * rng.randf_range(0.88, 1.12)
		cone_m.height = lerpf(h * 0.34, h * 0.24, f)
		cone_m.radial_segments = 8
		cone_m.rings = 1
		cone.mesh = cone_m
		cone.position = Vector3(lean * base_y, base_y + f * (h - base_y) * 0.92, lean * base_y * 0.6)
		cone.rotation.y = rng.randf_range(0.0, TAU)
		cone.material_override = mat(LEAF_DARK if i % 2 == 0 else LEAF_MID, 0.99)
		root.add_child(cone)
	return root

## حقل أشجار بصري بلا تصادم: جذوع وأوراق في MultiMesh واحد لكل طبقة،
## فمئات الأشجار تكلّف نداءي رسم بدل مئات. هذا ما يجعل الغابة كثيفة
## على الجوال دون أن ينهار الأداء.
static func make_tree_field(rng: RandomNumberGenerator, spots: Array, nm: String) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	var n := spots.size()
	if n == 0:
		return root

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.26
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1

	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 1.0
	canopy_mesh.height = 1.0
	canopy_mesh.radial_segments = 7
	canopy_mesh.rings = 1

	var trunks := MultiMeshInstance3D.new()
	trunks.name = "Trunks"
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.mesh = trunk_mesh
	tm.instance_count = n

	# ثلاث طبقات أوراق لكل شجرة في MultiMesh واحد
	var canopies := MultiMeshInstance3D.new()
	canopies.name = "Canopy"
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = canopy_mesh
	cm.instance_count = n * 3

	for i in n:
		var pos: Vector3 = spots[i]
		var h := rng.randf_range(5.5, 12.5)
		var w := rng.randf_range(0.8, 1.35)
		var yaw := rng.randf_range(0.0, TAU)
		var tb := Basis().rotated(Vector3.UP, yaw).scaled(Vector3(w, h, w))
		tm.set_instance_transform(i, Transform3D(tb, pos + Vector3(0, h * 0.5, 0)))

		var base_y := h * rng.randf_range(0.40, 0.50)
		for k in 3:
			var f := float(k) / 3.0
			var rad := lerpf(h * 0.27, h * 0.11, f) * rng.randf_range(0.85, 1.15) * w
			var ch := lerpf(h * 0.36, h * 0.26, f)
			var cb := Basis().rotated(Vector3.UP, yaw + float(k) * 0.9) \
				.scaled(Vector3(rad, ch, rad))
			var cy := base_y + f * (h - base_y) * 0.95 + ch * 0.5
			cm.set_instance_transform(i * 3 + k, Transform3D(cb, pos + Vector3(0, cy, 0)))

	trunks.multimesh = tm
	trunks.material_override = mat(TRUNK, 0.98)
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trunks)

	canopies.multimesh = cm
	canopies.material_override = mat(LEAF_DARK, 0.99)
	canopies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(canopies)

	# بالتشغيل الصامت يُهمل خادم العرض الوهمي بيانات MultiMesh فلا تُقرأ
	# مواضعها مرة أخرى. تُحفظ هنا كبيانات وصفية ليبقى التوزيع قابلاً للاختبار.
	root.set_meta("spots", spots.duplicate())
	root.set_meta("tree_count", n)
	return root

## سياج بصري بعيد يغلق الأفق
static func make_far_forest(rng: RandomNumberGenerator, count: int, r_min: float, r_max: float) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FarForest"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.5
	cone.height = 9.0
	cone.radial_segments = 6
	cone.rings = 1
	mm.mesh = cone
	mm.instance_count = count
	for i in count:
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(r_min, r_max)
		var s := rng.randf_range(0.75, 1.75)
		var b := Basis().scaled(Vector3(s, s * rng.randf_range(0.85, 1.3), s))
		b = b.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		var pos := Vector3(cos(ang) * rad, 4.5 * s, sin(ang) * rad)
		mm.set_instance_transform(i, Transform3D(b, pos))
	mmi.multimesh = mm
	mmi.material_override = mat(LEAF_DARK.darkened(0.25), 1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

# ---------- تفاصيل ----------
static func make_rock(rng: RandomNumberGenerator) -> Node3D:
	var sb := StaticBody3D.new()
	var s := rng.randf_range(0.5, 1.6)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s * 0.5
	sm.height = s * 0.72
	sm.radial_segments = 7
	sm.rings = 4
	mi.mesh = sm
	mi.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.4, 0.4))
	mi.material_override = mat(ROCK, 0.9)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = s * 0.45
	cs.shape = sp
	sb.add_child(cs)
	return sb

## فانوس: ضوء دافئ + هالة. علامة الطريق في الفصل الأول.
static func make_lantern(energy: float = 2.6) -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern"

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.07
	pm.height = 2.1
	pm.radial_segments = 6
	post.mesh = pm
	post.position = Vector3(0, 1.05, 0)
	post.material_override = mat(Color(0.09, 0.082, 0.071), 0.85, 0.2)
	root.add_child(post)

	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.42, 0.05, 0.05)
	arm.mesh = am
	arm.position = Vector3(0.18, 2.08, 0)
	arm.material_override = post.material_override
	root.add_child(arm)

	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.26, 0.34, 0.26)
	glass.mesh = gm
	glass.position = Vector3(0.36, 1.86, 0)
	glass.material_override = emissive(Color(1.0, 0.64, 0.30), 2.4)
	root.add_child(glass)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.70, 0.40)
	light.light_energy = energy
	light.omni_range = 9.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0.36, 1.86, 0)
	root.add_child(light)
	return root

## شجيرات منخفضة تملأ الأرض وتكسر الفراغ
static func make_shrubs(rng: RandomNumberGenerator, count: int, radius: float) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Shrubs"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.7
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	mm.instance_count = count
	for i in count:
		var ang := rng.randf_range(0.0, TAU)
		var rad := sqrt(rng.randf()) * radius
		var s := rng.randf_range(0.5, 1.5)
		var b := Basis().scaled(Vector3(s * 1.3, s * 0.65, s * 1.3))
		b = b.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(ang) * rad, 0.12 * s, sin(ang) * rad)))
	mmi.multimesh = mm
	mmi.material_override = mat(LEAF_DARK.darkened(0.1), 1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## حدود غير مرئية: بدونها يمشي اللاعب حتى حافة الأرض ويسقط.
static func make_bounds(half: float, height: float = 14.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Bounds"
	var thickness := 2.0
	var sides := [
		{"pos": Vector3(0, height * 0.5, -half), "size": Vector3(half * 2.0 + thickness, height, thickness)},
		{"pos": Vector3(0, height * 0.5, half), "size": Vector3(half * 2.0 + thickness, height, thickness)},
		{"pos": Vector3(-half, height * 0.5, 0), "size": Vector3(thickness, height, half * 2.0 + thickness)},
		{"pos": Vector3(half, height * 0.5, 0), "size": Vector3(thickness, height, half * 2.0 + thickness)},
	]
	for s in sides:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s["size"]
		cs.shape = box
		body.add_child(cs)
		body.position = s["pos"]
		root.add_child(body)
	return root

## سور حجري + بوابة أثرية (هدف الفصل الأول)
static func make_gate() -> Node3D:
	var root := Node3D.new()
	root.name = "AncientGate"
	var stone := mat(Color(0.118, 0.122, 0.133), 0.92)

	for sx in [-1.0, 1.0]:
		var pillar := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 6.4, 1.4)
		mi.mesh = bm
		mi.material_override = stone
		mi.position = Vector3(0, 3.2, 0)
		pillar.add_child(mi)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 6.4, 1.4)
		cs.shape = box
		cs.position = Vector3(0, 3.2, 0)
		pillar.add_child(cs)
		pillar.position = Vector3(sx * 2.6, 0, 0)
		root.add_child(pillar)

		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(1.8, 0.4, 1.8)
		cap.mesh = cm
		cap.material_override = stone
		cap.position = Vector3(sx * 2.6, 6.6, 0)
		root.add_child(cap)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(7.2, 1.0, 1.1)
	lintel.mesh = lm
	lintel.material_override = stone
	lintel.position = Vector3(0, 6.1, 0)
	root.add_child(lintel)

	var sigil := MeshInstance3D.new()
	var sm := TorusMesh.new()
	sm.inner_radius = 0.34
	sm.outer_radius = 0.58
	sm.rings = 10
	sm.ring_segments = 7
	sigil.mesh = sm
	sigil.material_override = emissive(Color(0.76, 0.12, 0.17), 1.9)
	sigil.position = Vector3(0, 6.1, 0.6)
	sigil.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(sigil)
	return root
