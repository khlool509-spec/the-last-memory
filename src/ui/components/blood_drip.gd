class_name BloodDrip
extends Control
## أثر دم أسفل الشعار.
##
## النسخة الأولى كانت خطوطاً متساوية التباعد فبدت مسطرة. هذه النسخة
## تبني حافة سفلية غير منتظمة كمضلّع، ثم تُسقط منها قطرات متفاوتة
## الطول والسمك مع رؤوس مستديرة وقطيرات منفصلة.

@export var color: Color = Palette.BLOOD
@export var highlight: Color = Color(1, 1, 1, 0.14)
@export var band_height: float = 9.0
@export var max_length: float = 40.0
@export var drip_count: int = 5
@export var rng_seed: int = 20261114

var _band: PackedVector2Array = PackedVector2Array()
var _drips: Array = []
var _specks: Array = []

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = band_height + max_length + 10.0
	_regen()
	resized.connect(_regen)

func _regen() -> void:
	var w := maxf(size.x, 8.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# الحافة السفلية: خط متموّج غير منتظم بدل خط مستقيم
	var pts: Array[Vector2] = []
	var steps := 26
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := w * t
		var y := band_height * (0.55 + 0.45 * sin(t * 11.0 + rng_seed * 0.1)) \
			+ rng.randf_range(-1.6, 1.6)
		pts.append(Vector2(x, maxf(y, 1.0)))
	var poly: Array[Vector2] = [Vector2(0, 0)]
	poly.append_array(pts)
	poly.append(Vector2(w, 0))
	_band = PackedVector2Array(poly)

	# قطرات: مواضع عشوائية غير متساوية التباعد
	_drips.clear()
	var used: Array[float] = []
	for i in drip_count:
		var x := w * rng.randf_range(0.06, 0.94)
		var too_close := false
		for u in used:
			if absf(u - x) < w * 0.09:
				too_close = true
		if too_close:
			continue
		used.append(x)
		_drips.append({
			"x": x,
			"len": max_length * rng.randf_range(0.30, 1.0),
			"w": rng.randf_range(2.6, 6.2),
		})

	# قطيرات منفصلة تحت بعض القطرات
	_specks.clear()
	for d in _drips:
		if rng.randf() < 0.45:
			_specks.append({
				"p": Vector2(d["x"] + rng.randf_range(-3.0, 3.0),
					float(d["len"]) + band_height + rng.randf_range(7.0, 16.0)),
				"r": rng.randf_range(1.6, 3.0),
			})
	queue_redraw()

func _draw() -> void:
	if _band.size() >= 3:
		draw_colored_polygon(_band, color)
	for d in _drips:
		var x: float = d["x"]
		var l: float = d["len"]
		var hw: float = d["w"] * 0.5
		var top := band_height * 0.6
		var bottom := band_height + l
		# جذع يضيق نحو الأسفل
		var stem := PackedVector2Array([
			Vector2(x - hw, top),
			Vector2(x + hw, top),
			Vector2(x + hw * 0.52, bottom),
			Vector2(x - hw * 0.52, bottom),
		])
		draw_colored_polygon(stem, color)
		# رأس مستدير
		draw_circle(Vector2(x, bottom), hw * 0.95, color)
		draw_circle(Vector2(x - hw * 0.3, bottom - hw * 0.3), hw * 0.3, highlight)
	for s in _specks:
		draw_circle(s["p"], s["r"], color)
