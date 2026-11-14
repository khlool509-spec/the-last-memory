class_name Biome
extends RefCounted
## المناطق الحيوية. تقرأ من WorldProfile وتقرّر: لون الأرض، نوع الشجر،
## كثافته، والعشب تحته. هي سبب اختلاف إحساس المكان بين ضفة النهر
## وقلب الغابة وقمة المرتفع.

enum Kind { WATER, SHORE, MEADOW, FOREST, DEEP, ROCKY, CLEARING, SETTLED }

const NAMES := ["water", "shore", "meadow", "forest", "deep", "rocky", "clearing", "settled"]

## ألوان الأرض لكل منطقة — تُخبز في ألوان رؤوس الشبكة
const GROUND := {
	Kind.WATER:    Color(0.149, 0.176, 0.165),
	Kind.SHORE:    Color(0.451, 0.412, 0.329),
	Kind.MEADOW:   Color(0.361, 0.439, 0.243),
	Kind.FOREST:   Color(0.251, 0.318, 0.192),
	Kind.DEEP:     Color(0.184, 0.243, 0.157),
	Kind.ROCKY:    Color(0.404, 0.400, 0.380),
	Kind.CLEARING: Color(0.420, 0.467, 0.286),
	Kind.SETTLED:  Color(0.376, 0.337, 0.255),
}

var _wp: WorldProfile
var _patch: FastNoiseLite      # بقع كثافة الغابة
var _open: FastNoiseLite       # فسحات مفتوحة

func _init(wp: WorldProfile) -> void:
	_wp = wp
	_patch = WorldProfile._make_noise(WorldProfile.SEED + 511, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0135, 3, 0.5)
	_open = WorldProfile._make_noise(WorldProfile.SEED + 622, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0088, 2, 0.5)

func at(x: float, z: float) -> int:
	var h := _wp.height(x, z)
	if h < _wp.WATER_LEVEL:
		return Kind.WATER
	var rd := _wp.river_distance(x, z)
	if rd < WorldProfile.BANK_WIDTH + 3.0 and h < _wp.WATER_LEVEL + 2.4:
		return Kind.SHORE
	var sl := _wp.slope(x, z)
	if sl > 0.40:
		return Kind.ROCKY
	if _wp.road_factor(x, z) < 2.2:
		return Kind.SETTLED
	var op := _open.get_noise_2d(x, z)
	if op > 0.46:
		return Kind.CLEARING
	if h > 13.0 and sl > 0.22:
		return Kind.ROCKY
	if rd < 36.0 and h < _wp.WATER_LEVEL + 7.0:
		return Kind.MEADOW
	var pt := _patch.get_noise_2d(x, z)
	if pt > 0.26:
		return Kind.DEEP
	if op < -0.40:
		return Kind.MEADOW
	return Kind.FOREST

func ground_color(x: float, z: float) -> Color:
	var k := at(x, z)
	var c: Color = GROUND[k]
	# تفاوت لوني ناعم فلا تبدو المنطقة لوناً واحداً مسطّحاً
	var v := _patch.get_noise_2d(x * 3.1, z * 3.1) * 0.085
	return Color(clampf(c.r + v, 0.0, 1.0), clampf(c.g + v * 1.2, 0.0, 1.0), clampf(c.b + v * 0.8, 0.0, 1.0), 1.0)

## كثافة الأشجار: نسبة 0..1 تُضرب في الكثافة الأساسية
func tree_density(kind: int) -> float:
	match kind:
		Kind.WATER: return 0.0
		Kind.SHORE: return 0.14
		Kind.MEADOW: return 0.22
		Kind.FOREST: return 1.0
		Kind.DEEP: return 1.55
		Kind.ROCKY: return 0.26
		Kind.CLEARING: return 0.10
		Kind.SETTLED: return 0.18
	return 0.6

## كثافة العشب والشجيرات
func undergrowth_density(kind: int) -> float:
	match kind:
		Kind.WATER: return 0.0
		Kind.SHORE: return 0.85
		Kind.MEADOW: return 1.45
		Kind.FOREST: return 1.0
		Kind.DEEP: return 0.75
		Kind.ROCKY: return 0.22
		Kind.CLEARING: return 1.30
		Kind.SETTLED: return 0.35
	return 0.7

## خليط الأنواع لكل منطقة: اسم -> وزن
func species_mix(kind: int) -> Dictionary:
	match kind:
		Kind.SHORE:
			return {"willow": 0.55, "birch": 0.30, "dead": 0.15}
		Kind.MEADOW:
			return {"birch": 0.45, "oak": 0.35, "pine": 0.12, "dead": 0.08}
		Kind.FOREST:
			return {"pine": 0.46, "oak": 0.24, "birch": 0.20, "dead": 0.10}
		Kind.DEEP:
			return {"pine": 0.68, "spruce": 0.22, "dead": 0.10}
		Kind.ROCKY:
			return {"pine": 0.40, "dead": 0.45, "spruce": 0.15}
		Kind.CLEARING:
			return {"birch": 0.50, "oak": 0.30, "dead": 0.20}
		Kind.SETTLED:
			return {"oak": 0.50, "birch": 0.35, "dead": 0.15}
	return {"pine": 0.5, "oak": 0.5}
