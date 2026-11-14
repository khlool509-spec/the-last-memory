class_name BloodDrip
extends Control
## قطرات دم تسيل أسفل عنصر — تُرسم بالكود فتبقى حادّة على أي دقة.
## تطابق معالجة الشعار في الهوية المعتمدة.

@export var drip_count: int = 7
@export var color: Color = Palette.BLOOD
@export var max_length: float = 46.0
@export var thickness: float = 5.0
@export var rng_seed: int = 20261114

var _drips: Array = []

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = max_length + 14.0
	_regen()
	resized.connect(_regen)

func _regen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_drips.clear()
	var w := maxf(size.x, 1.0)
	for i in drip_count:
		var x := w * (float(i) + 0.5 + rng.randf_range(-0.28, 0.28)) / float(drip_count)
		var len_px := max_length * rng.randf_range(0.28, 1.0)
		var r := thickness * rng.randf_range(0.5, 1.0)
		_drips.append({"x": x, "len": len_px, "r": r})
	queue_redraw()

func _draw() -> void:
	# شريط علوي يربط القطرات بالعنصر فوقها
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 3.0)), color)
	for d in _drips:
		var x: float = d["x"]
		var l: float = d["len"]
		var r: float = d["r"]
		draw_line(Vector2(x, 0.0), Vector2(x, l), color, r * 1.25, true)
		draw_circle(Vector2(x, l), r, color)
		# بريق خفيف يعطي القطرة حجماً
		draw_circle(Vector2(x - r * 0.3, l - r * 0.3), r * 0.32,
			Color(1, 1, 1, 0.18))
