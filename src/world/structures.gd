class_name Structures
extends RefCounted
## مباني العالم ومنشآته. كل مبنى يُبنى من قطع، وله هوية مختلفة:
## أبعاد وسقف وأبواب ونوافذ وأثاث مختلفة، فلا يتكرّر مبنى مرتين.
## المباني قابلة للدخول فعلاً: جدرانها فيها فتحات وأرضيتها مستوية.

const WOOD_DARK := Color(0.169, 0.133, 0.102)
const WOOD_MID := Color(0.251, 0.196, 0.141)
const WOOD_PALE := Color(0.337, 0.286, 0.216)
const STONE_COL := Color(0.267, 0.263, 0.251)
const ROOF_COL := Color(0.141, 0.125, 0.110)
const FLOOR_COL := Color(0.196, 0.161, 0.125)

# ---------------- أدوات ----------------
## صندوق بتصادم: اللبنة الأساسية لكل مبنى
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		collide: bool = true, rot_y: float = 0.0) -> Node3D:
	var node: Node3D
	if collide:
		node = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		node.add_child(cs)
	else:
		node = Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	node.add_child(mi)
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	return node

## جدار فيه فتحة باب: يُبنى مقطعين وعتبة
static func wall_with_door(parent: Node3D, length: float, height: float, thick: float,
		pos: Vector3, rot_y: float, mat: Material, door_w: float, door_h: float,
		door_off: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	var left_len := (length * 0.5) + door_off - (door_w * 0.5)
	var right_len := (length * 0.5) - door_off - (door_w * 0.5)
	if left_len > 0.02:
		box(holder, Vector3(left_len, height, thick),
			Vector3(-length * 0.5 + left_len * 0.5, height * 0.5, 0), mat)
	if right_len > 0.02:
		box(holder, Vector3(right_len, height, thick),
			Vector3(length * 0.5 - right_len * 0.5, height * 0.5, 0), mat)
	if height - door_h > 0.04:
		box(holder, Vector3(door_w, height - door_h, thick),
			Vector3(door_off, door_h + (height - door_h) * 0.5, 0), mat)

## جدار فيه نافذة
static func wall_with_window(parent: Node3D, length: float, height: float, thick: float,
		pos: Vector3, rot_y: float, mat: Material, win_w: float, win_h: float, sill: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	var side := (length - win_w) * 0.5
	if side > 0.02:
		box(holder, Vector3(side, height, thick), Vector3(-length * 0.5 + side * 0.5, height * 0.5, 0), mat)
		box(holder, Vector3(side, height, thick), Vector3(length * 0.5 - side * 0.5, height * 0.5, 0), mat)
	box(holder, Vector3(win_w, sill, thick), Vector3(0, sill * 0.5, 0), mat)
	var top_h := height - sill - win_h
	if top_h > 0.02:
		box(holder, Vector3(win_w, top_h, thick), Vector3(0, sill + win_h + top_h * 0.5, 0), mat)
	# إطار النافذة
	var frame := WorldMaterials.plain(WOOD_DARK, 0.9)
	box(holder, Vector3(win_w + 0.1, 0.07, thick + 0.06), Vector3(0, sill, 0), frame, false)
	box(holder, Vector3(win_w + 0.1, 0.07, thick + 0.06), Vector3(0, sill + win_h, 0), frame, false)

static func plain_wall(parent: Node3D, length: float, height: float, thick: float,
		pos: Vector3, rot_y: float, mat: Material) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	box(holder, Vector3(length, height, thick), Vector3(0, height * 0.5, 0), mat)

## سقف جملوني من لوحين مائلين
static func gable_roof(parent: Node3D, w: float, d: float, wall_h: float, rise: float,
		mat: Material, overhang: float = 0.35) -> void:
	var span := w * 0.5 + overhang
	var slope_len := sqrt(span * span + rise * rise)
	var angle := atan2(rise, span)
	for s in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(slope_len, 0.14, d + overhang * 2.0)
		mi.mesh = bm
		mi.material_override = mat
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bm.size
		cs.shape = sh
		sb.add_child(cs)
		sb.add_child(mi)
		sb.position = Vector3(s * span * 0.5, wall_h + rise * 0.5, 0)
		sb.rotation.z = -s * angle
		Lod.tag(sb, Lod.SILHOUETTE)
		parent.add_child(sb)
	# الجملون المثلث عند الطرفين
	var gm := WorldMaterials.plain(WOOD_DARK, 0.95)
	for s in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-w * 0.5, 0, 0)
		var b := Vector3(w * 0.5, 0, 0)
		var c := Vector3(0, rise, 0)
		for tri in [[a, b, c], [a, c, b]]:
			var t0: Vector3 = tri[0]
			var t1: Vector3 = tri[1]
			var t2: Vector3 = tri[2]
			var n := (t1 - t0).cross(t2 - t0).normalized()
			for v in [t0, t1, t2]:
				st.set_normal(n)
				st.add_vertex(v)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = gm
		mi.position = Vector3(0, wall_h, s * d * 0.5)
		parent.add_child(mi)

## أرضية داخلية
static func floor_slab(parent: Node3D, w: float, d: float, y: float, mat: Material) -> void:
	box(parent, Vector3(w, 0.18, d), Vector3(0, y - 0.09, 0), mat)

## ضوء داخلي دافئ
static func interior_light(parent: Node3D, pos: Vector3, energy: float = 1.6) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.76, 0.48)
	l.light_energy = energy
	l.omni_range = 7.0
	l.omni_attenuation = 1.5
	l.shadow_enabled = false
	l.position = pos
	parent.add_child(l)
	return l

# ---------------- أثاث ----------------
static func table(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> void:
	var m := WorldMaterials.plain(WOOD_MID, 0.9)
	var holder := Node3D.new()
	Lod.tag(holder, Lod.FURNITURE)
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	box(holder, Vector3(1.3, 0.08, 0.8), Vector3(0, 0.74, 0), m)
	for sx in [-0.55, 0.55]:
		for sz in [-0.32, 0.32]:
			box(holder, Vector3(0.09, 0.72, 0.09), Vector3(sx, 0.36, sz), m, false)

static func shelf(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> void:
	var m := WorldMaterials.plain(WOOD_DARK, 0.92)
	var holder := Node3D.new()
	Lod.tag(holder, Lod.FURNITURE)
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	box(holder, Vector3(1.1, 0.06, 0.32), Vector3(0, 0.85, 0), m)
	box(holder, Vector3(1.1, 0.06, 0.32), Vector3(0, 1.35, 0), m)
	for sx in [-0.5, 0.5]:
		box(holder, Vector3(0.08, 1.6, 0.32), Vector3(sx, 0.8, 0), m, false)

static func crate(parent: Node3D, pos: Vector3, s: float = 0.6, rot_y: float = 0.0) -> Node3D:
	var c := box(parent, Vector3(s, s, s), pos + Vector3(0, s * 0.5, 0),
		WorldMaterials.plain(WOOD_PALE.darkened(0.15), 0.95), true, rot_y)
	Lod.tag(c, Lod.PROP)
	return c

static func barrel(parent: Node3D, pos: Vector3) -> void:
	var m := WorldMaterials.plain(WOOD_MID.darkened(0.2), 0.9)
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.30
	cm.height = 0.78
	cm.radial_segments = 9
	mi.mesh = cm
	mi.material_override = m
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.78
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos + Vector3(0, 0.39, 0)
	Lod.tag(sb, Lod.PROP)
	parent.add_child(sb)

static func bed(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> void:
	var holder := Node3D.new()
	Lod.tag(holder, Lod.FURNITURE)
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	box(holder, Vector3(0.95, 0.30, 1.95), Vector3(0, 0.15, 0), WorldMaterials.plain(WOOD_DARK, 0.92))
	box(holder, Vector3(0.92, 0.16, 1.85), Vector3(0, 0.38, 0), WorldMaterials.plain(Color(0.337, 0.302, 0.251), 0.98), false)
	box(holder, Vector3(0.92, 0.10, 0.36), Vector3(0, 0.50, -0.72), WorldMaterials.plain(Color(0.42, 0.39, 0.34), 0.98), false)

# ---------------- منشآت ----------------
## جسر ألواح يعبر النهر، بدرابزين وركائز تنزل إلى الماء
static func plank_bridge(world: WorldRenderer, center: Vector3, length: float, width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bridge"
	var wood := WorldMaterials.timber(WOOD_MID)
	var dark := WorldMaterials.plain(WOOD_DARK, 0.95)

	# يُوجَّه عمودياً على مجرى النهر عند هذه النقطة
	var deck_y := world.data.water_level + 2.3
	var ang := _river_angle(world, center) + PI * 0.5
	root.position = Vector3(center.x, deck_y, center.z)
	root.rotation.y = ang

	# الألواح
	var planks := int(length / 0.42)
	for i in planks:
		var t := (float(i) + 0.5) / float(planks) - 0.5
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, 0.09, 0.36)
		mi.mesh = bm
		mi.material_override = wood
		mi.position = Vector3(0, 0, t * length)
		mi.rotation.z = deg_to_rad(randf_range(-0.6, 0.6))
		root.add_child(mi)
	# سطح تصادم واحد تحت الألواح
	box(root, Vector3(width, 0.16, length), Vector3(0, -0.10, 0), dark)
	# عوارض طولية
	for sx in [-width * 0.42, width * 0.42]:
		box(root, Vector3(0.16, 0.22, length), Vector3(sx, -0.20, 0), dark, false)
	# درابزين
	Lod.tag(root, Lod.STRUCTURE)
	for sx in [-width * 0.5 + 0.08, width * 0.5 - 0.08]:
		var posts := 7
		for i in posts:
			var t := float(i) / float(posts - 1) - 0.5
			box(root, Vector3(0.11, 1.05, 0.11), Vector3(sx, 0.52, t * length * 0.96), dark)
		box(root, Vector3(0.09, 0.09, length), Vector3(sx, 1.0, 0), wood, false)
	# ركائز تنزل إلى القاع
	for t in [-0.34, 0.0, 0.34]:
		var wx := center.x + sin(ang) * 0.0
		var h := world.height_at(center.x - sin(ang) * t * length, center.z + cos(ang) * t * length)
		var drop := deck_y - h
		if drop > 0.3:
			box(root, Vector3(0.26, drop, 0.26), Vector3(0, -drop * 0.5 - 0.18, t * length), dark, false)
	return root

static func _river_angle(world: WorldRenderer, p: Vector3) -> float:
	var pts := world.data.river_points
	var best := INF
	var ang := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 < 0.001 else clampf((Vector2(p.x, p.z) - a).dot(ab) / l2, 0.0, 1.0)
		var q := a.lerp(b, t)
		var d := Vector2(p.x, p.z).distance_to(q)
		if d < best:
			best = d
			ang = atan2(ab.x, ab.y)
	return ang

## بئر حجري
static func well(world: WorldRenderer, center: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Well"
	root.position = Vector3(center.x, world.height_at(center.x, center.z), center.z)
	var st_m := WorldMaterials.stone(Color(0.35, 0.35, 0.34))
	var wood := WorldMaterials.timber(WOOD_DARK)
	var segs := 12
	for i in segs:
		var a := TAU * float(i) / float(segs)
		box(root, Vector3(0.42, 0.95, 0.30),
			Vector3(cos(a) * 1.05, 0.48, sin(a) * 1.05), st_m, true, -a)
	# فوهة مظلمة
	var hole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.92
	cm.bottom_radius = 0.92
	cm.height = 0.1
	cm.radial_segments = 12
	hole.mesh = cm
	hole.material_override = WorldMaterials.plain(Color(0.016, 0.016, 0.020), 1.0)
	hole.position = Vector3(0, 0.90, 0)
	root.add_child(hole)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.14, 1.9, 0.14), Vector3(sx * 1.0, 1.9, 0), wood)
	box(root, Vector3(2.4, 0.14, 0.14), Vector3(0, 2.8, 0), wood, false)
	# دلو معلّق
	box(root, Vector3(0.30, 0.34, 0.30), Vector3(0, 2.2, 0), wood, false)
	box(root, Vector3(0.03, 0.5, 0.03), Vector3(0, 2.6, 0), WorldMaterials.plain(Color(0.2,0.2,0.2)), false)
	return root

# ---------------- المباني ----------------
## كوخ الحارس: غرفة واحدة ضيّقة، سقف منحدر، شرفة أمامية.
static func watchman_hut(world: WorldRenderer, center: Vector3, face: float) -> Node3D:
	var root := Node3D.new()
	root.name = "WatchmanHut"
	var y := world.height_at(center.x, center.z)
	root.position = Vector3(center.x, y, center.z)
	root.rotation.y = face

	var w := 4.6
	var d := 4.0
	var h := 2.5
	var t := 0.22
	var timber := WorldMaterials.timber(WOOD_MID)
	var dark := WorldMaterials.timber(WOOD_DARK)

	floor_slab(root, w, d, 0.12, WorldMaterials.plain(FLOOR_COL, 0.95))
	# الواجهة فيها الباب، والخلف نافذة، والجانبان مصمتان
	wall_with_door(root, w, h, t, Vector3(0, 0.12, d * 0.5), 0.0, timber, 1.15, 2.05, 0.4)
	wall_with_window(root, w, h, t, Vector3(0, 0.12, -d * 0.5), 0.0, timber, 1.0, 0.85, 1.05)
	plain_wall(root, d, h, t, Vector3(-w * 0.5, 0.12, 0), PI * 0.5, timber)
	wall_with_window(root, d, h, t, Vector3(w * 0.5, 0.12, 0), PI * 0.5, timber, 0.9, 0.8, 1.1)
	gable_roof(root, w, d, h + 0.12, 1.1, WorldMaterials.plain(ROOF_COL, 0.96))

	# شرفة أمامية على عمودين
	box(root, Vector3(w + 0.4, 0.12, 1.5), Vector3(0, 0.1, d * 0.5 + 0.75), dark)
	for sx in [-w * 0.42, w * 0.42]:
		box(root, Vector3(0.16, 2.2, 0.16), Vector3(sx, 1.2, d * 0.5 + 1.3), dark)
	box(root, Vector3(w + 0.4, 0.16, 1.7), Vector3(0, 2.3, d * 0.5 + 0.8),
		WorldMaterials.plain(ROOF_COL.darkened(0.1), 0.96), false)

	# الداخل
	bed(root, Vector3(-1.2, 0.12, -0.9), PI * 0.5)
	table(root, Vector3(1.1, 0.12, 0.7), 0.3)
	crate(root, Vector3(1.6, 0.12, -1.3), 0.52, 0.4)
	interior_light(root, Vector3(0, 2.0, 0), 1.25)
	root.set_meta("interior", Vector3(0.2, 0.3, -0.4))
	root.set_meta("door_world", Vector3(0.4, 0.3, d * 0.5 + 0.5))
	return root

## المنزل القديم: غرفتان وممر، أكبر وأعلى، ونوافذ مكسورة.
static func old_house(world: WorldRenderer, center: Vector3, face: float) -> Node3D:
	var root := Node3D.new()
	root.name = "OldHouse"
	var y := world.height_at(center.x, center.z)
	root.position = Vector3(center.x, y, center.z)
	root.rotation.y = face

	var w := 8.4
	var d := 6.6
	var h := 3.1
	var t := 0.26
	var stone_m := WorldMaterials.stone(Color(0.33, 0.32, 0.30))
	var timber := WorldMaterials.timber(WOOD_DARK)

	floor_slab(root, w, d, 0.14, WorldMaterials.plain(FLOOR_COL.darkened(0.15), 0.96))
	wall_with_door(root, w, h, t, Vector3(0, 0.14, d * 0.5), 0.0, stone_m, 1.25, 2.2, -1.6)
	wall_with_window(root, w, h, t, Vector3(0, 0.14, -d * 0.5), 0.0, stone_m, 1.3, 1.0, 1.25)
	wall_with_window(root, d, h, t, Vector3(-w * 0.5, 0.14, 0), PI * 0.5, stone_m, 1.1, 1.0, 1.2)
	wall_with_window(root, d, h, t, Vector3(w * 0.5, 0.14, 0), PI * 0.5, stone_m, 1.1, 1.0, 1.2)
	# جدار داخلي يقسم المنزل غرفتين، فيه فتحة مرور
	wall_with_door(root, d - t, h, 0.18, Vector3(1.0, 0.14, 0), PI * 0.5, timber, 1.0, 2.1, 1.3)
	gable_roof(root, w, d, h + 0.14, 1.6, WorldMaterials.plain(ROOF_COL.darkened(0.08), 0.96))

	# مدخنة حجرية
	box(root, Vector3(0.9, 2.6, 0.9), Vector3(-w * 0.32, h + 1.0, -d * 0.22), stone_m)

	# الغرفة الكبرى
	table(root, Vector3(-2.2, 0.14, 0.9), 0.15)
	shelf(root, Vector3(-3.5, 0.14, -2.6), 0.0)
	crate(root, Vector3(-3.2, 0.14, 2.0), 0.58, 0.6)
	barrel(root, Vector3(-1.1, 0.14, -2.3))
	# الغرفة الصغرى
	bed(root, Vector3(2.6, 0.14, -1.6), 0.0)
	shelf(root, Vector3(3.3, 0.14, 1.6), -PI * 0.5)
	interior_light(root, Vector3(-1.8, 2.4, 0.0), 1.35)
	interior_light(root, Vector3(2.6, 2.4, 0.2), 0.95)
	root.set_meta("interior", Vector3(-1.8, 0.4, 0.0))
	root.set_meta("door_world", Vector3(-1.6, 0.4, d * 0.5 + 0.6))
	return root

## المخزن: مبنى طويل منخفض، سقف شبه مسطّح، صناديق وبراميل.
static func storehouse(world: WorldRenderer, center: Vector3, face: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Storehouse"
	var y := world.height_at(center.x, center.z)
	root.position = Vector3(center.x, y, center.z)
	root.rotation.y = face

	var w := 7.0
	var d := 4.4
	var h := 2.7
	var t := 0.2
	var timber := WorldMaterials.timber(WOOD_PALE.darkened(0.25))
	floor_slab(root, w, d, 0.12, WorldMaterials.plain(FLOOR_COL.darkened(0.2), 0.96))
	wall_with_door(root, w, h, t, Vector3(0, 0.12, d * 0.5), 0.0, timber, 1.6, 2.25, 0.0)
	plain_wall(root, w, h, t, Vector3(0, 0.12, -d * 0.5), 0.0, timber)
	wall_with_window(root, d, h, t, Vector3(-w * 0.5, 0.12, 0), PI * 0.5, timber, 0.8, 0.6, 1.5)
	plain_wall(root, d, h, t, Vector3(w * 0.5, 0.12, 0), PI * 0.5, timber)
	gable_roof(root, w, d, h + 0.12, 0.7, WorldMaterials.plain(ROOF_COL.lightened(0.04), 0.96), 0.5)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for i in 7:
		crate(root, Vector3(rng.randf_range(-2.8, 2.8), 0.12, rng.randf_range(-1.5, 1.4)),
			rng.randf_range(0.42, 0.68), rng.randf_range(0.0, TAU))
	for i in 4:
		barrel(root, Vector3(rng.randf_range(-2.9, 2.9), 0.12, rng.randf_range(-1.6, 1.5)))
	shelf(root, Vector3(-3.0, 0.12, -1.6), 0.0)
	interior_light(root, Vector3(0, 2.2, 0), 1.0)
	root.set_meta("interior", Vector3(0.0, 0.4, -0.6))
	root.set_meta("door_world", Vector3(0.0, 0.4, d * 0.5 + 0.6))
	return root

## الخرِبة: جدران حجرية مكسورة بلا سقف، نصفها ساقط.
static func ruin(world: WorldRenderer, center: Vector3, face: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Ruin"
	var y := world.height_at(center.x, center.z)
	root.position = Vector3(center.x, y, center.z)
	root.rotation.y = face

	var w := 9.0
	var d := 7.0
	var t := 0.34
	var stone_m := WorldMaterials.stone(Color(0.29, 0.29, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3312

	floor_slab(root, w, d, 0.10, WorldMaterials.plain(Color(0.20, 0.19, 0.18), 0.98))
	# جدران متفاوتة الارتفاع: الانهيار هو ما يجعلها خرِبة لا صندوقاً
	var sides := [
		{"len": w, "pos": Vector3(0, 0.10, d * 0.5), "rot": 0.0, "hs": [2.9, 1.2, 2.4, 0.5]},
		{"len": w, "pos": Vector3(0, 0.10, -d * 0.5), "rot": 0.0, "hs": [3.1, 2.6, 0.8, 2.2]},
		{"len": d, "pos": Vector3(-w * 0.5, 0.10, 0), "rot": PI * 0.5, "hs": [2.2, 0.6, 1.8]},
		{"len": d, "pos": Vector3(w * 0.5, 0.10, 0), "rot": PI * 0.5, "hs": [0.7, 2.8, 3.0]},
	]
	for s in sides:
		var holder := Node3D.new()
		holder.position = s["pos"]
		holder.rotation.y = float(s["rot"])
		root.add_child(holder)
		var hs: Array = s["hs"]
		var seg_len: float = float(s["len"]) / float(hs.size())
		for i in hs.size():
			var hh: float = float(hs[i])
			if hh < 0.25:
				continue
			box(holder, Vector3(seg_len * 0.98, hh, t),
				Vector3(-float(s["len"]) * 0.5 + seg_len * (float(i) + 0.5), hh * 0.5, 0), stone_m)
	# حجارة ساقطة في الداخل
	for i in 11:
		var r := PlantMeshes.rock(rng, true)
		var mi := MeshInstance3D.new()
		mi.mesh = r
		mi.material_override = WorldMaterials.foliage("rock_l")
		var s2 := rng.randf_range(0.5, 1.5)
		mi.scale = Vector3(s2, s2 * 0.7, s2)
		mi.position = Vector3(rng.randf_range(-3.6, 3.6), 0.2, rng.randf_range(-2.6, 2.6))
		mi.rotation.y = rng.randf_range(0.0, TAU)
		root.add_child(mi)
	# عمود باقٍ وحيد
	box(root, Vector3(0.6, 3.4, 0.6), Vector3(-2.2, 1.8, 1.0), stone_m)
	root.set_meta("interior", Vector3(0.0, 0.4, 0.0))
	return root

## باب يُفتح فعلاً: مفصّل من جانب، وله نص تفاعل وصوت.
## يُمرَّر مفتاح مطلوب فيصير الباب لغزاً صغيراً بدل زينة.
static func hinged_door(w: float, h: float, required_item: String = "") -> DoorGate:
	var d := DoorGate.new()
	d.name = "Door"
	d.required_item = required_item
	d.prompt = "افتح الباب"
	d.locked_prompt = "الباب مقفل" if required_item == "" else "مقفل — تحتاج مفتاحاً"
	d.open_angle_deg = 96.0
	d.open_time = 1.0

	var leaf := Node3D.new()
	leaf.name = "Leaf"
	d.add_child(leaf)

	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.09)
	mi.mesh = bm
	mi.material_override = WorldMaterials.timber(WOOD_DARK)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	body.add_child(cs)
	# المفصلة عند الحافة: الورقة تدور حول طرفها لا حول مركزها
	body.position = Vector3(w * 0.5, h * 0.5, 0)
	leaf.add_child(body)

	# ألواح ومقبض
	for i in 3:
		var p := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(w * 0.26, h * 0.92, 0.015)
		p.mesh = pm
		p.material_override = WorldMaterials.plain(WOOD_MID.darkened(0.25), 0.95)
		p.position = Vector3(w * (0.2 + 0.3 * float(i)), h * 0.5, 0.055)
		leaf.add_child(p)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.055
	km.height = 0.11
	knob.mesh = km
	knob.material_override = WorldMaterials.plain(Color(0.22, 0.19, 0.16), 0.5)
	knob.position = Vector3(w * 0.86, h * 0.48, 0.09)
	leaf.add_child(knob)

	var area := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(w + 0.9, h, 1.5)
	area.shape = ash
	area.position = Vector3(w * 0.5, h * 0.5, 0)
	d.add_child(area)
	return d

## درج أو صندوق يُفتح ويعطي غرضاً
static func container_box(item_id: String, label: String) -> Pickup:
	var p := Pickup.new()
	p.item_id = item_id
	p.prompt = label
	p.spin_speed = 0.0
	p.bob_height = 0.0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.42, 0.44)
	mi.mesh = bm
	mi.material_override = WorldMaterials.plain(WOOD_PALE.darkened(0.2), 0.94)
	p.add_child(mi)
	var front := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.56, 0.1, 0.03)
	front.mesh = fm
	front.material_override = WorldMaterials.plain(Color(0.19, 0.16, 0.13), 0.7)
	front.position = Vector3(0, 0.02, 0.235)
	p.add_child(front)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.75
	cs.shape = sh
	p.add_child(cs)
	return p

## ورقة موضوعة على سطح، مضيئة قليلاً فتُرى في العتمة
static func paper_note(item_id: String) -> NoteItem:
	var n := NoteItem.new()
	n.item_id = item_id
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.30, 0.012, 0.40)
	mi.mesh = bm
	mi.material_override = WorldMaterials.emissive(Color(0.84, 0.81, 0.73), 0.30)
	mi.rotation.y = randf_range(-0.6, 0.6)
	n.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7
	cs.shape = sh
	n.add_child(cs)
	return n

## فانوس معلّق: علامة طريق ومصدر ضوء
static func lantern_post(energy: float = 2.2) -> Node3D:
	return ForestBuilder.make_lantern(energy)
