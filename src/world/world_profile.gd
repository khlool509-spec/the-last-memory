class_name WorldProfile
extends RefCounted
## المصدر الوحيد لشكل العالم. كل شيء آخر يستعلم منه:
## التضاريس والنهر والطرق والنبات والمباني — فيخرج عالم واحد مترابط
## لا طبقات ملصوقة فوق بعضها.
##
## القاعدة: لا أحد يحسب ارتفاعاً بنفسه. من احتاج ارتفاعاً سأل height().

const SEED := 20261114

# حدود العالم
const HALF := 200.0          # العالم 400×400 متر
const WATER_LEVEL := -2.6    # سطح الماء بالنسبة للصفر

# التضاريس
const BASE_AMP := 17.0       # سعة التلال الكبرى
const RIDGE_AMP := 13.0      # سعة الحواف الصخرية
const DETAIL_AMP := 1.15     # خشونة قريبة
const OUTCROP_AMP := 7.0     # نتوءات صخرية حادّة تكسر استدارة التلال
const GULLY_AMP := 2.6       # قنوات حتّ ينحتها الماء في المنحدرات
const TERRACE := 2.9         # ارتفاع المصطبة الصخرية بالمتر

# النهر
const RIVER_HALF_WIDTH := 5.0
const RIVER_DEPTH := 3.2
const BANK_WIDTH := 12.0
const VALLEY_WIDTH := 52.0    # الوادي العريض الذي يجري فيه النهر

## معالم مصمَّمة: الضجيج وحده يعطي أرضاً بلا هوية. هذه تعطي العالم
## مرتفعاً يُطل، ومنخفضاً يختبئ، وحوضاً يسكنه الناس.
const FEATURES := [
	{"c": Vector2(128, -42),  "r": 78.0, "a": 12.5},   # مرتفع الإطلالة
	{"c": Vector2(-4, -124),  "r": 66.0, "a": 8.0},    # نتوء البوابة
	{"c": Vector2(70, -112),  "r": 44.0, "a": -7.0},   # المنخفض
	{"c": Vector2(-150, -70), "r": 80.0, "a": 9.5},    # مرتفع الشمال الغربي
	{"c": Vector2(-60, 58),   "r": 86.0, "a": -4.2},   # حوض المساكن
	{"c": Vector2(150, 140),  "r": 70.0, "a": 6.0},    # مرتفع الجنوب الشرقي
	{"c": Vector2(-170, 150), "r": 62.0, "a": 7.5},    # كتف الجنوب الغربي
]

var _base: FastNoiseLite
var _ridge: FastNoiseLite
var _detail: FastNoiseLite
var _warp: FastNoiseLite
var _outcrop: FastNoiseLite
var _gully: FastNoiseLite
var _biome_noise: FastNoiseLite

## مسار النهر: نقاط مركزية يُستوفى بينها
var river_points: PackedVector2Array = PackedVector2Array()
## مناطق مسطّحة محجوزة للمباني: Vector3(x, z, radius) مع ارتفاعها
var pads: Array = []
## مقاطع الطرق: كل مقطع {a: Vector2, b: Vector2, w: float}
var road_segments: Array = []

func _init() -> void:
	_base = _make_noise(SEED, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0042, 4, 0.48)
	_ridge = _make_noise(SEED + 101, FastNoiseLite.TYPE_SIMPLEX, 0.0075, 3, 0.5)
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_detail = _make_noise(SEED + 202, FastNoiseLite.TYPE_SIMPLEX, 0.052, 3, 0.52)
	_warp = _make_noise(SEED + 303, FastNoiseLite.TYPE_SIMPLEX, 0.0031, 2, 0.5)
	# نتوءات: حوافّ حادّة بتردّد أعلى من الحواف الكبرى
	_outcrop = _make_noise(SEED + 505, FastNoiseLite.TYPE_SIMPLEX, 0.0186, 3, 0.46)
	_outcrop.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	# قنوات الحتّ: حوافّ مقلوبة تُحفر في السفوح
	_gully = _make_noise(SEED + 606, FastNoiseLite.TYPE_SIMPLEX, 0.0122, 2, 0.5)
	_gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_biome_noise = _make_noise(SEED + 404, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0098, 2, 0.5)
	_build_river()
	_build_roads()
	_build_pads()

static func _make_noise(sd: int, t: int, freq: float, octaves: int, gain: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sd
	n.noise_type = t
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.fractal_lacunarity = 2.03
	return n

# ---------------- النهر ----------------
## النهر يدخل من الشمال الغربي ويخرج جنوباً، منحنياً لا مستقيماً.
func _build_river() -> void:
	river_points = PackedVector2Array([
		Vector2(-186, -178),
		Vector2(-148, -138),
		Vector2(-118, -96),
		Vector2(-104, -52),
		Vector2(-86, -14),
		Vector2(-52, 12),
		Vector2(-16, 26),
		Vector2(14, 48),
		Vector2(26, 86),
		Vector2(12, 124),
		Vector2(18, 162),
		Vector2(40, 196),
	])

## أقرب مسافة أفقية إلى محور النهر
func river_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in river_points.size() - 1:
		best = minf(best, _seg_distance(p, river_points[i], river_points[i + 1]))
	return best

## كم تقدّم النهر عند أقرب نقطة (0 عند المنبع، 1 عند المصب)
func river_progress(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	var best_i := 0
	var best_t := 0.0
	for i in river_points.size() - 1:
		var t := _seg_param(p, river_points[i], river_points[i + 1])
		var q: Vector2 = river_points[i].lerp(river_points[i + 1], t)
		var d := p.distance_to(q)
		if d < best:
			best = d
			best_i = i
			best_t = t
	return (float(best_i) + best_t) / float(maxi(1, river_points.size() - 1))

static func _seg_param(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return 0.0
	return clampf((p - a).dot(ab) / l2, 0.0, 1.0)

static func _seg_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := _seg_param(p, a, b)
	return p.distance_to(a.lerp(b, t))

# ---------------- الطرق ----------------
## مواقع العالم. الطرق تصل بينها، والمباني تجلس عليها.
const POI := {
	"spawn":      Vector2(96, 150),
	"crossroad":  Vector2(58, 92),
	"hut":        Vector2(112, 74),
	"bridge":     Vector2(20, 64),
	"old_house":  Vector2(-46, 44),
	"store":      Vector2(-96, 72),
	"well":       Vector2(-28, 8),
	"ruin":       Vector2(-132, -34),
	"gate":       Vector2(-4, -124),
	"overlook":   Vector2(128, -42),
	"hollow":     Vector2(70, -112),
}

func _build_roads() -> void:
	var links := [
		["spawn", "crossroad", 3.4],
		["crossroad", "hut", 2.6],
		["crossroad", "bridge", 3.2],
		["bridge", "old_house", 3.0],
		["old_house", "store", 2.4],
		["old_house", "well", 2.2],
		["well", "gate", 2.8],
		["store", "ruin", 1.9],
		["crossroad", "overlook", 1.8],
		["overlook", "hollow", 1.6],
		["hollow", "gate", 1.7],
	]
	for l in links:
		var a: Vector2 = POI[l[0]]
		var b: Vector2 = POI[l[1]]
		var w: float = l[2]
		# الطريق لا يمشي مستقيماً: يُقسَّم ويُزاح بضجيج فيبدو متتبّعاً للأرض
		var steps := maxi(3, int(a.distance_to(b) / 14.0))
		var prev := a
		for i in range(1, steps + 1):
			var t := float(i) / float(steps)
			var mid := a.lerp(b, t)
			if i < steps:
				var perp := (b - a).orthogonal().normalized()
				var wob := _warp.get_noise_2d(mid.x * 2.4, mid.y * 2.4) * 9.0
				mid += perp * wob
			road_segments.append({"a": prev, "b": mid, "w": w})
			prev = mid

func road_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for s in road_segments:
		best = minf(best, _seg_distance(p, s["a"], s["b"]))
	return best

## المسافة منسوبة إلى عرض الطريق: 0 في المنتصف، 1 عند الحافة
func road_factor(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for s in road_segments:
		var d := _seg_distance(p, s["a"], s["b"])
		var f: float = d / maxf(0.5, float(s["w"]))
		best = minf(best, f)
	return best

# ---------------- أرضيات المباني ----------------
func _build_pads() -> void:
	var defs := [
		{"key": "hut", "r": 7.0},
		{"key": "old_house", "r": 11.0},
		{"key": "store", "r": 8.5},
		{"key": "well", "r": 5.0},
		{"key": "ruin", "r": 10.0},
		{"key": "gate", "r": 9.0},
		{"key": "overlook", "r": 6.0},
		{"key": "spawn", "r": 6.5},
	]
	for d in defs:
		var c: Vector2 = POI[d["key"]]
		pads.append({"key": d["key"], "c": c, "r": float(d["r"]), "y": 0.0})
	# ارتفاع كل أرضية = ارتفاع الأرض الخام في مركزها
	for p in pads:
		p["y"] = _raw_height(p["c"].x, p["c"].y)

func pad_height(key: String) -> float:
	for p in pads:
		if p["key"] == key:
			return float(p["y"])
	return 0.0

func pad_center(key: String) -> Vector3:
	for p in pads:
		if p["key"] == key:
			return Vector3(p["c"].x, float(p["y"]), p["c"].y)
	return Vector3.ZERO

# ---------------- الارتفاع ----------------
## الأرض الخام قبل النهر والطرق والمباني.
## كلها موجبة الاتجاه: أخفض نقطة طبيعية تبقى فوق سطح الماء، فلا يغرق
## العالم. الشيء الوحيد الذي ينزل تحت الماء هو مجرى النهر المنحوت.
func _raw_height(x: float, z: float) -> float:
	# تشويه المجال: يكسر انتظام الضجيج فلا تظهر أنماط متكررة
	var wx := x + _warp.get_noise_2d(x, z) * 58.0
	var wz := z + _warp.get_noise_2d(x + 713.0, z - 219.0) * 58.0

	# 0..1 مع انحياز نحو المنخفض: بطون واسعة ومرتفعات قليلة
	var n01 := _base.get_noise_2d(wx, wz) * 0.5 + 0.5
	var base := pow(clampf(n01, 0.0, 1.0), 1.25) * BASE_AMP

	# الحواف الصخرية تظهر في المرتفعات فقط، فلا تنبت صخور في البطون
	var ridge_mask := clampf(base / BASE_AMP * 1.5 - 0.25, 0.0, 1.0)
	var ridge := absf(_ridge.get_noise_2d(wx, wz)) * RIDGE_AMP * ridge_mask * ridge_mask

	# التفصيل يأخذ الإحداثيات المشوّهة مُدارة بزاوية غير قياسية.
	# بالإحداثيات الخام كانت شبكة سمبلكس تظهر خطوطاً قطرية منتظمة
	# كل ~19 متراً عبر الخريطة كلها — وهي ما كان يُرى كتموّج «مخمل».
	var rx := wx * 0.8660254 - wz * 0.5
	var rz := wx * 0.5 + wz * 0.8660254
	var h := base + ridge + _detail.get_noise_2d(rx, rz) * DETAIL_AMP

	# نتوءات صخرية: حوافّ حادّة تنبت من المرتفعات. بدونها تبقى
	# التضاريس تلالاً مستديرة بلا هوية جيولوجية — وهو أظهر فارق
	# عن المرجع السينمائي بعد الإضاءة.
	var rock_mask := clampf(base / BASE_AMP * 1.7 - 0.42, 0.0, 1.0)
	var oc := absf(_outcrop.get_noise_2d(wx * 1.0, wz * 1.0))
	oc = pow(oc, 2.1)                       # الأسّ يُضيّق القمم فتصير حوافّ لا نتوءات ناعمة
	var outcrop := oc * OUTCROP_AMP * rock_mask
	h += outcrop

	# تصطّب: الصخر المكشوف يتكسّر طبقات أفقية، لا منحدراً أملس.
	# يُطبَّق بقدر كشف الصخر فقط فلا تتدرّج المروج.
	if rock_mask > 0.02:
		var t_amt := clampf(rock_mask * (0.35 + oc * 0.65), 0.0, 1.0) * 0.55
		var terraced := roundf(h / TERRACE) * TERRACE
		h = lerpf(h, terraced, t_amt)

	# قنوات الحتّ: الماء ينحت أخاديد في السفوح، والمنبسط لا يُحفر
	var gl := 1.0 - absf(_gully.get_noise_2d(wx, wz))
	h -= pow(clampf(gl, 0.0, 1.0), 3.0) * GULLY_AMP * clampf(rock_mask * 1.4, 0.0, 1.0)

	h += _features_at(x, z)
	return h

## المعالم المصمَّمة: قباب وأحواض ناعمة الحواف تُضاف فوق الضجيج
func _features_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var sum := 0.0
	for f in FEATURES:
		var c: Vector2 = f["c"]
		var r: float = float(f["r"])
		var d := p.distance_to(c)
		if d >= r:
			continue
		var t := 1.0 - d / r
		sum += float(f["a"]) * t * t * (3.0 - 2.0 * t)
	return sum

## الارتفاع النهائي: الأرض الخام بعد نحت النهر وتسوية الطرق والأرضيات
func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	h = _carve_river(x, z, h)
	h = _flatten_roads(x, z, h)
	h = _flatten_pads(x, z, h)
	return h

## النهر على مرحلتين: وادٍ عريض يهبط إليه السفح، ثم مجرى منحوت فيه.
## المرحلة الأولى هي الفرق بين «نهر في وادٍ» و«شق في أرض مستوية».
func _carve_river(x: float, z: float, h: float) -> float:
	var d := river_distance(x, z)
	if d > VALLEY_WIDTH:
		return h

	# قاع النهر ينحدر مع تقدّمه فيجري الماء في اتجاه واحد
	var prog := river_progress(x, z)
	var bed := WATER_LEVEL - RIVER_DEPTH + lerpf(1.9, -1.6, prog)

	# 1) الوادي: خفض تدريجي كلما اقتربنا من المحور
	var vt := clampf(d / VALLEY_WIDTH, 0.0, 1.0)
	vt = vt * vt * (3.0 - 2.0 * vt)
	var valley_floor := bed + 4.6
	var out := lerpf(minf(h, valley_floor), h, vt)

	if d > BANK_WIDTH:
		return out

	# 2) المجرى
	if d <= RIVER_HALF_WIDTH:
		var t := d / RIVER_HALF_WIDTH
		# الارتفاع عند الحافّة يبقى تحت سطح الماء على طول المجرى:
		# بـ1.4 م كان القاع يعلو السطح أعلى النهر فتظهر التضاريس خلاله.
		return minf(out, bed + (t * t) * 0.85)

	# 3) الضفة بين المجرى والوادي
	var bt := (d - RIVER_HALF_WIDTH) / (BANK_WIDTH - RIVER_HALF_WIDTH)
	bt = bt * bt * (3.0 - 2.0 * bt)
	return minf(out, lerpf(bed + 1.4, out, bt))

func _flatten_roads(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	var best_d := INF
	var best_seg: Dictionary = {}
	for s in road_segments:
		var d := _seg_distance(p, s["a"], s["b"])
		if d < best_d:
			best_d = d
			best_seg = s
	if best_seg.is_empty():
		return h
	var w: float = float(best_seg["w"])
	var outer := w * 2.6
	if best_d > outer:
		return h
	# الطريق لا يُسطَّح تماماً: يُنعَّم فقط فيبقى تابعاً للتضاريس
	var a: Vector2 = best_seg["a"]
	var b: Vector2 = best_seg["b"]
	var t := _seg_param(p, a, b)
	var on := a.lerp(b, t)
	var target := _raw_height(on.x, on.y)
	target = _carve_river(on.x, on.y, target)
	var k := 1.0 - clampf((best_d - w * 0.5) / maxf(0.001, outer - w * 0.5), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return lerpf(h, target - 0.12, k * 0.92)

func _flatten_pads(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	var out := h
	for pad in pads:
		var c: Vector2 = pad["c"]
		var r: float = float(pad["r"])
		var d := p.distance_to(c)
		if d > r * 1.9:
			continue
		var k := 1.0 - clampf((d - r * 0.55) / maxf(0.001, r * 1.9 - r * 0.55), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		out = lerpf(out, float(pad["y"]), k)
	return out

## المنسوب الطبيعي (بلا ميل): مفيد لتحديد المرتفعات الحقيقية
func elevation01(x: float, z: float) -> float:
	return clampf((height(x, z) + 18.0) / 40.0, 0.0, 1.0)

func normal(x: float, z: float, e: float = 0.6) -> Vector3:
	var hl := height(x - e, z)
	var hr := height(x + e, z)
	var hd := height(x, z - e)
	var hu := height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

## الميل 0 (مستوٍ) إلى 1 (جدار)
func slope(x: float, z: float) -> float:
	return clampf(1.0 - normal(x, z).y, 0.0, 1.0)

func is_underwater(x: float, z: float) -> bool:
	return height(x, z) < WATER_LEVEL - 0.05

func in_bounds(x: float, z: float) -> bool:
	return absf(x) < HALF and absf(z) < HALF
