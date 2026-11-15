class_name CompassStrip
extends Control
## شريط البوصلة أعلى الشاشة — نفس منطق ببجي: شريط أفقي يتحرّك عكس
## دوران الكاميرا، عليه درجات كل 15° وأسماء الجهات الأصلية، ومؤشّر
## ثابت في المنتصف يقرأ الاتجاه الحالي.
##
## لا يُستخدم Label لأن المحتوى ينزلق باستمرار: الرسم المباشر أرخص
## من تحريك عشرات العُقد كل إطار.

## نطاق أوسع: الشريط يعرض ربع دائرة الاتجاهات تقريباً على شاشة
## عريضة، فيرى اللاعب الجهة التي يقصدها قبل أن يستدير إليها.
const DEG_PER_PX := 0.17
const MAJOR := 15                 # علامة كبيرة كل 15 درجة
const CARDINALS := {
	0: "N", 45: "NE", 90: "E", 135: "SE",
	180: "S", 225: "SW", 270: "W", 315: "NW",
}

var heading: float = 0.0          # 0..360، صفر = شمال
var _font: Font
var _font_small: Font

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 46)
	_font = UITheme.load_font(UITheme.FONT_BOLD)
	_font_small = UITheme.load_font(UITheme.FONT_REGULAR)

## يُستدعى من الـHUD كل إطار باتجاه الكاميرا
func set_heading(deg: float) -> void:
	var d := fposmod(deg, 360.0)
	if absf(d - heading) < 0.05:
		return
	heading = d
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := w * 0.5

	# خلفية متدرّجة الشفافية: واضحة في الوسط وتتلاشى عند الطرفين
	# فلا تقطع الشريط بحافّة حادّة.
	var steps := 24
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var fade: float = 1.0 - absf(t0 - 0.5) * 2.0
		var a: float = 0.34 * pow(clampf(fade, 0.0, 1.0), 0.6)
		draw_rect(Rect2(w * t0, 0.0, w * (t1 - t0) + 1.0, h),
			Color(0.04, 0.05, 0.06, a), true)

	# نطاق الدرجات الظاهر على الشريط
	var span := w * DEG_PER_PX
	var from := heading - span * 0.5
	var first := int(floor(from / float(MAJOR))) * MAJOR

	var deg := first
	while float(deg) < heading + span * 0.5 + float(MAJOR):
		var off := (float(deg) - heading)
		# أقصر فرق زاوي: بدون هذا يقفز الشريط عند عبور الشمال
		off = fposmod(off + 180.0, 360.0) - 180.0
		var x := mid + off / DEG_PER_PX
		if x > -60.0 and x < w + 60.0:
			var norm := int(fposmod(float(deg), 360.0))
			var dist: float = clampf(1.0 - absf(x - mid) / (w * 0.5), 0.0, 1.0)
			var alpha: float = 0.35 + 0.65 * pow(dist, 0.7)
			if CARDINALS.has(norm):
				var txt: String = str(CARDINALS[norm])
				var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 22).x
				draw_string(_font, Vector2(x - tw * 0.5, h * 0.60), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
					Color(1, 1, 1, alpha))
			else:
				var num := str(norm)
				var nw := _font_small.get_string_size(num,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				draw_string(_font_small, Vector2(x - nw * 0.5, h * 0.52), num,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
					Color(0.86, 0.88, 0.90, alpha * 0.75))
				draw_line(Vector2(x, h * 0.62), Vector2(x, h * 0.76),
					Color(1, 1, 1, alpha * 0.4), 1.0)
		deg += MAJOR

	# المؤشّر الثابت ورقم الاتجاه الحالي تحته
	var cur := str(int(round(heading)))
	var cw := _font.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(_font, Vector2(mid - cw * 0.5, h * 0.98), cur,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.97))
	# مثلّث صغير يشير لأسفل من أعلى الشريط
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid - 7.0, 1.0), Vector2(mid + 7.0, 1.0), Vector2(mid, 11.0),
	]), Color(1, 1, 1, 0.95))
