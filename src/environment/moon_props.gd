class_name MoonProps
extends RefCounted
## مصنع مجسّمات سطح القمر. كلها مبنية من أشكال أوّلية بالكود:
## لا ملفات نماذج، ولا شيء يحتاج استيراداً.

const GOLD := Color("#c9a227")
const WHITE_PANEL := Color("#d8d6d0")
const DARK_PANEL := Color("#3b3e45")
const METAL := Color("#8e9299")
const ROCK := Color("#5e5b58")
const LAMP := Color("#9fd7ff")

static func mat(albedo: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	return m

static func emissive(c: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

static func _mesh(mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	return mi

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func _cyl(r_top: float, r_bot: float, h: float, seg: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

# ---------------------------------------------------------------- المركبة

## مركبة الهبوط: مركز الخريطة ونقطة العودة.
static func make_lander() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Lander"
	body.collision_layer = 1
	body.collision_mask = 0

	var foil := mat(GOLD, 0.42, 0.85)
	var panel := mat(WHITE_PANEL, 0.78)
	var dark := mat(DARK_PANEL, 0.7, 0.2)
	var steel := mat(METAL, 0.45, 0.8)

	# قاعدة مثمّنة ملفوفة برقائق ذهبية
	body.add_child(_mesh(_cyl(1.95, 2.25, 1.5, 8), foil, Vector3(0, 1.45, 0)))
	# مقصورة الطاقم
	body.add_child(_mesh(_cyl(1.35, 1.75, 2.1, 8), panel, Vector3(0, 3.25, 0)))
	# القبة العليا
	var dome := SphereMesh.new()
	dome.radius = 1.3
	dome.height = 1.5
	dome.radial_segments = 14
	dome.rings = 7
	body.add_child(_mesh(dome, panel, Vector3(0, 4.35, 0)))

	# نافذة مضيئة
	body.add_child(_mesh(_box(Vector3(0.95, 0.5, 0.08)), emissive(LAMP, 1.1), Vector3(0, 3.7, -1.62)))

	# أربع أرجل بأقدام عريضة
	for i in 4:
		var ang := TAU * (float(i) / 4.0) + PI * 0.25
		var dirv := Vector3(cos(ang), 0.0, sin(ang))
		var leg := _mesh(_cyl(0.11, 0.11, 3.1, 6), steel, dirv * 2.0 + Vector3(0, 0.95, 0))
		leg.rotation = Vector3(dirv.z * 0.42, 0.0, -dirv.x * 0.42)
		body.add_child(leg)
		body.add_child(_mesh(_cyl(0.62, 0.62, 0.18, 10), steel, dirv * 2.72 + Vector3(0, 0.12, 0)))

	# سلّم الهبوط
	body.add_child(_mesh(_box(Vector3(0.7, 2.4, 0.07)), steel, Vector3(0, 1.3, -2.1), Vector3(-0.2, 0, 0)))
	for s in 5:
		body.add_child(_mesh(_box(Vector3(0.62, 0.05, 0.16)), steel,
			Vector3(0, 0.35 + float(s) * 0.52, -2.2 - float(s) * 0.1)))

	# طبق الهوائي
	var dish := SphereMesh.new()
	dish.radius = 0.72
	dish.height = 0.62
	dish.radial_segments = 14
	dish.rings = 6
	dish.is_hemisphere = true
	body.add_child(_mesh(dish, panel, Vector3(1.5, 4.5, 0.6), Vector3(-0.9, 0.4, 0)))

	# كشّاف هبوط: يضيء محيط المركبة فيكون معلماً ليلياً
	var lamp := OmniLight3D.new()
	lamp.name = "LanderLamp"
	lamp.light_color = Color("#cfe0f2")
	lamp.light_energy = 3.2
	lamp.omni_range = 26.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 4.2, 0)
	body.add_child(lamp)

	# تصادم مبسّط: أسطوانة واحدة تغطّي الجسم
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.2
	shape.height = 5.4
	col.shape = shape
	col.position = Vector3(0, 2.7, 0)
	body.add_child(col)
	return body

# ---------------------------------------------------------------- الصخور

## صخرة زينة بتصادم: تُولَّد بشكل غير منتظم من بذرة
static func make_boulder(rng: RandomNumberGenerator) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var r := rng.randf_range(0.5, 2.3)
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * rng.randf_range(1.2, 1.9)
	sphere.radial_segments = 7
	sphere.rings = 4
	var mi := _mesh(sphere, mat(ROCK.lerp(Color("#787472"), rng.randf()), 1.0), Vector3(0, r * 0.45, 0))
	mi.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	mi.scale = Vector3(1.0, rng.randf_range(0.55, 0.9), rng.randf_range(0.8, 1.25))
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var cs := SphereShape3D.new()
	cs.radius = r * 0.85
	col.shape = cs
	col.position = Vector3(0, r * 0.45, 0)
	body.add_child(col)
	return body

## عيّنة ثرى قابلة للجمع
static func make_sample(sample_id: String) -> Interactable:
	var it := Interactable.new()
	it.name = "Sample_" + sample_id
	it.interact_id = sample_id
	it.prompt = "اجمع العيّنة"
	it.reach = 2.6
	it.once = true

	var holder := Node3D.new()
	holder.name = "Visual"
	it.add_child(holder)

	var crystal := SphereMesh.new()
	crystal.radius = 0.34
	crystal.height = 0.6
	crystal.radial_segments = 6
	crystal.rings = 3
	holder.add_child(_mesh(crystal, mat(Color("#4a4744"), 0.95), Vector3(0, 0.3, 0)))
	# وهج خافت يجعلها مرئية في الظل القاسي
	holder.add_child(_mesh(_cyl(0.05, 0.22, 1.5, 8), _beacon_mat(Color("#8fd3ff")), Vector3(0, 0.9, 0)))

	var glow := OmniLight3D.new()
	glow.light_color = Color("#8fd3ff")
	glow.light_energy = 1.5
	glow.omni_range = 5.5
	glow.shadow_enabled = false
	glow.position = Vector3(0, 0.7, 0)
	holder.add_child(glow)
	return it

static func _beacon_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r, c.g, c.b, 0.33)
	return m

# ---------------------------------------------------------------- المنشآت

## هوائي اتصال معطّل: مهمة إصلاح
static func make_antenna(antenna_id: String) -> Interactable:
	var it := Interactable.new()
	it.name = "Antenna"
	it.interact_id = antenna_id
	it.prompt = "أصلح الهوائي"
	it.reach = 3.4
	it.once = true

	var steel := mat(METAL, 0.5, 0.75)
	it.add_child(_mesh(_cyl(1.0, 1.25, 0.35, 10), mat(DARK_PANEL, 0.8), Vector3(0, 0.18, 0)))
	it.add_child(_mesh(_cyl(0.13, 0.17, 5.2, 8), steel, Vector3(0, 2.75, 0)))
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var guy := _mesh(_cyl(0.035, 0.035, 3.4, 4), steel,
			Vector3(cos(ang) * 0.8, 1.6, sin(ang) * 0.8))
		guy.rotation = Vector3(sin(ang) * 0.45, 0.0, -cos(ang) * 0.45)
		it.add_child(guy)

	var dish := SphereMesh.new()
	dish.radius = 1.35
	dish.height = 1.0
	dish.radial_segments = 16
	dish.rings = 7
	dish.is_hemisphere = true
	it.add_child(_mesh(dish, mat(WHITE_PANEL, 0.7), Vector3(0, 5.3, 0), Vector3(-1.15, 0.0, 0.0)))
	it.add_child(_mesh(_cyl(0.05, 0.05, 1.0, 6), steel, Vector3(0, 5.5, -0.5), Vector3(-1.15, 0, 0)))

	# ضوء عطل أحمر يخفق — يتحوّل أخضر بعد الإصلاح
	var bulb := _mesh(_box(Vector3(0.22, 0.22, 0.22)), emissive(Color("#e4192b"), 3.0), Vector3(0, 1.1, 0.3))
	bulb.name = "StatusBulb"
	it.add_child(bulb)
	return it

## محطة أكسجين: الاستعمال يعيد ملء البدلة، ويمكن تكراره
static func make_oxygen_station(station_id: String) -> Interactable:
	var it := Interactable.new()
	it.name = "OxygenStation"
	it.interact_id = station_id
	it.prompt = "أعد ملء الأكسجين"
	it.reach = 3.0
	it.once = false

	it.add_child(_mesh(_box(Vector3(1.8, 0.3, 1.2)), mat(DARK_PANEL, 0.8), Vector3(0, 0.15, 0)))
	for i in 3:
		var x := -0.55 + float(i) * 0.55
		it.add_child(_mesh(_cyl(0.24, 0.24, 1.5, 10), mat(Color("#2f6f8f"), 0.5, 0.6), Vector3(x, 1.05, 0)))
		it.add_child(_mesh(_cyl(0.1, 0.1, 0.25, 6), mat(METAL, 0.4, 0.8), Vector3(x, 1.9, 0)))
	it.add_child(_mesh(_box(Vector3(0.5, 0.36, 0.1)), emissive(Color("#53d98a"), 2.2), Vector3(0, 1.3, -0.65)))

	var glow := OmniLight3D.new()
	glow.light_color = Color("#53d98a")
	glow.light_energy = 1.8
	glow.omni_range = 7.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.4, 0)
	it.add_child(glow)
	return it

## العَلَم: لمسة النهاية بعد إتمام المهام
static func make_flag() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Flag"
	body.collision_layer = 1
	body.collision_mask = 0
	var steel := mat(METAL, 0.45, 0.8)
	body.add_child(_mesh(_cyl(0.045, 0.045, 3.0, 6), steel, Vector3(0, 1.5, 0)))
	body.add_child(_mesh(_cyl(0.035, 0.035, 1.3, 6), steel, Vector3(0.65, 2.9, 0), Vector3(0, 0, PI * 0.5)))
	# القماش مشدود بقضيب أفقي: لا هواء يرفرفه
	body.add_child(_mesh(_box(Vector3(1.3, 0.8, 0.02)), mat(Color("#b2121f"), 0.9), Vector3(0.65, 2.5, 0)))
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.25
	cs.height = 3.0
	col.shape = cs
	col.position = Vector3(0, 1.5, 0)
	body.add_child(col)
	return body
