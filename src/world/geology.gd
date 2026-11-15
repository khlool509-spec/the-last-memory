class_name Geology
extends RefCounted
## تشكيلات صخرية من نماذج فوتوغرامترية ممسوحة (Poly Haven، CC0).
##
## الحدّ البنيوي الذي يعالجه هذا الملف: حقل الارتفاع دالةٌ أحاديّة
## القيمة — لكل (x,z) ارتفاع واحد. فلا يُنتج جرفاً عمودياً ولا رفّاً
## صخرياً مطبّقاً ولا كهفاً، مهما حسُن الضجيج أو الحتّ. وهي بالضبط
## ما يصنع هوية المراجع.
##
## الحلّ المهني: الحقل يحمل الشكل العامّ للأرض، والجيولوجيا الدرامية
## تُوضَع فوقه كقطع منحوتة. هذه القطع ممسوحة ضوئياً لا مولَّدة.

const DIR := "res://assets/models/"

## الكتل الكبيرة: اسم النموذج، مدى القياس، ومدى الرؤية بالمتر
const PIECES := {
	"rock_face_01":     {"scale": [1.6, 3.4], "range": 260.0, "sink": 0.34},
	"rock_face_02":     {"scale": [1.8, 3.8], "range": 240.0, "sink": 0.32},
	"rock_moss_set_01": {"scale": [1.0, 2.2], "range": 190.0, "sink": 0.30},
	"rock_moss_set_02": {"scale": [1.1, 2.4], "range": 190.0, "sink": 0.30},
	"boulder_01":       {"scale": [1.2, 3.0], "range": 170.0, "sink": 0.38},
}

static var _cache: Dictionary = {}

## يستخرج شبكة النموذج مرّة واحدة ويحتفظ بها
static func mesh_of(name: String) -> Mesh:
	if _cache.has(name):
		return _cache[name]
	var p := "%s%s/%s.gltf" % [DIR, name, name]
	if not ResourceLoader.exists(p):
		push_warning("نموذج جيولوجي مفقود: " + p)
		return null
	var ps: PackedScene = ResourceLoader.load(p)
	var inst := ps.instantiate()
	var found: Mesh = null
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			found = mi.mesh
			break
	inst.free()
	_cache[name] = found
	return found

## يبني التشكيلات على التضاريس. الوضع حتميّ ببذرة ثابتة، فالعالم
## نفسه في كل تشغيل، ويتبع الميل والارتفاع ومسار النهر.
static func build(world: WorldRenderer, wp: WorldProfile, parent: Node3D) -> int:
	var root := Node3D.new()
	root.name = "Geology"
	parent.add_child(root)

	var rng := RandomNumberGenerator.new()
	rng.seed = WorldProfile.SEED + 7717
	var clump := FastNoiseLite.new()
	clump.seed = WorldProfile.SEED + 7718
	clump.noise_type = FastNoiseLite.TYPE_SIMPLEX
	clump.frequency = 0.011

	var placed := 0
	var half := WorldProfile.HALF
	# شبكة فحص 9 أمتار: كثيفة بما يكفي لإيجاد المواضع الحادّة
	var step := 7.5
	var n := int((half * 2.0) / step)
	for j in n:
		for i in n:
			var x := -half + (float(i) + 0.5) * step + rng.randf_range(-4.0, 4.0)
			var z := -half + (float(j) + 0.5) * step + rng.randf_range(-4.0, 4.0)
			if absf(x) > half - 8.0 or absf(z) > half - 8.0:
				continue
			var h := wp.height(x, z)
			if h < WorldProfile.WATER_LEVEL - 0.4:
				continue
			if wp.road_factor(x, z) < 1.8:
				continue
			var skip := false
			for pad in wp.pads:
				if Vector2(x, z).distance_to(pad["c"] as Vector2) < float(pad["r"]) * 1.1:
					skip = true
					break
			if skip:
				continue

			var sl := wp.slope(x, z)
			var cl := clampf(clump.get_noise_2d(x, z) * 1.5 + 0.45, 0.0, 1.0)
			# الجروف تنبت حيث الأرض حادّة؛ الجلاميد حيث تتجمّع الكتل
			# عتبة الجرف مقيسة على توزيع ميل التضاريس الفعلي:
			# المئين 95 = 0.254 والمئين 99 = 0.404. بعتبة 0.46 كانت
			# فوق المئين 99 فلم يُوضع إلا جرفان في العالم كلّه.
			var want_face := sl > 0.26
			# الكتل على الأرض المستوية كانت تتناثر كقطع ملصوقة على
			# العشب. الجروف تبقى كما هي — مكانها الطبيعي الميل الحادّ —
			# وفرصة المستوي هبطت إلى الثلث فتبقى كتلة هنا وهناك لا حقل
			# حصى. المجموعات والبيانات كلها باقية بلا حذف.
			var chance := (0.55 if want_face else 0.028) * (0.25 + cl * cl * 1.6)
			if rng.randf() > chance:
				continue

			var key := _pick(rng, want_face)
			var mesh := mesh_of(key)
			if mesh == null:
				continue
			var spec: Dictionary = PIECES[key]
			var sr: Array = spec["scale"]
			var s := rng.randf_range(float(sr[0]), float(sr[1]))
			if want_face:
				s *= 1.0 + sl * 0.8      # الجروف أضخم على الأحدّ ميلاً

			var mi := MeshInstance3D.new()
			mi.name = "%s_%d" % [key, placed]
			mi.mesh = mesh
			# ميل يتبع الأرض ثم دوران حرّ: الكتلة لا تقف على عمودي تامّ
			var nrm := wp.normal(x, z)
			var b := Basis()
			var ax := nrm.cross(Vector3.UP)
			if ax.length() > 0.001:
				b = Basis(ax.normalized(), -asin(clampf(ax.length(), -1.0, 1.0)) * 0.65)
			b = b.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			var t2 := rng.randf_range(0.0, TAU)
			b = b.rotated(Vector3(cos(t2), 0.0, sin(t2)), rng.randf_range(-0.22, 0.22))
			b = b.scaled(Vector3(s * rng.randf_range(0.88, 1.12), s * rng.randf_range(0.80, 1.15),
				s * rng.randf_range(0.88, 1.12)))
			# الاستقرار على أخفض نقطة تحت بصمة الكتلة لا على مركزها.
			# على منحدر، تثبيت المركز وحده يرفع الطرف الأسفل عن الأرض
			# فتبدو الصخرة طائرة — وهذا ما كان يحدث فعلاً.
			# كسر «الصخور الطائرة»: لا تخمين بنسبة من الحجم، بل حساب
			# أدنى نقطة في المجسّم بعد الدوران والتحجيم، ووضعها عند
			# أخفض أرض تحت بصمته. نسبة الغوص كانت تُقاس من المركز،
			# فكتلة مائلة على منحدر يرتفع طرفها عن الأرض مهما غاصت.
			var ab := mesh.get_aabb()
			var low := INF
			var wide := 0.0
			for ci in 8:
				var c: Vector3 = b * ab.get_endpoint(ci)
				low = minf(low, c.y)
				wide = maxf(wide, Vector2(c.x, c.z).length())
			var h_min := h
			for a in 8:
				var ang := TAU * float(a) / 8.0
				h_min = minf(h_min, wp.height(x + cos(ang) * wide,
					z + sin(ang) * wide))
			# أدنى رأس يلامس أخفض أرض، ثم يُدفن بجزء من ارتفاع الكتلة
			var y := h_min - low - ab.size.y * s * float(spec["sink"])
			mi.transform = Transform3D(b, Vector3(x, y, z))
			mi.visibility_range_end = float(spec["range"])
			mi.visibility_range_end_margin = 24.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			# النماذج الممسوحة بكثافة سينمائية (20–66 ألف مثلث للقطعة).
			# الانحياز يُبكّر الانتقال إلى مستويات التفصيل الأخفّ التي
			# يولّدها المستورِد، فتهبط المثلثات المرسومة دون مسّ
			# الأصل ولا خاماته ولا عموديّاته.
			mi.lod_bias = 4.0
			root.add_child(mi)
			placed += 1
	return placed

static func _pick(rng: RandomNumberGenerator, face: bool) -> String:
	if face:
		return "rock_face_01" if rng.randf() < 0.55 else "rock_face_02"
	var r := rng.randf()
	if r < 0.40:
		return "rock_moss_set_01"
	if r < 0.74:
		return "rock_moss_set_02"
	return "boulder_01"
