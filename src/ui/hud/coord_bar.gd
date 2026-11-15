class_name CoordBar
extends Control
## شريط الإحداثيات أسفل الشاشة — يقابل السطر الذي يعرضه ببجي أسفل
## يساره: الموقع والارتفاع والاتجاه والوقت ومعدّل الإطارات.
##
## ليس زينة: هو أداة القياس التي يقرأ منها اللاعب أين يقف وكيف يؤدّي
## الجهاز، وهو ما نحتاجه لضبط الأداء بقياس لا بتخمين.

var pos3: Vector3 = Vector3.ZERO
var heading: float = 0.0
var speed: float = 0.0
var state: String = ""

var _font: Font
var _acc := 0.0

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 26)
	_font = UITheme.load_font(UITheme.FONT_REGULAR)
	set_process(true)

func _process(delta: float) -> void:
	# تحديث عشر مرّات في الثانية: الرقم يُقرأ لا يُسابَق، وتحديثه كل
	# إطار يفرض إعادة رسم بلا فائدة.
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		queue_redraw()

func set_state(p: Vector3, deg: float, spd: float, st: String) -> void:
	pos3 = p
	heading = deg
	speed = spd
	state = st

func _draw() -> void:
	var cardinal: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][
		int(round(fposmod(heading, 360.0) / 45.0)) % 8]
	var txt := "X %.1f   Z %.1f   ارتفاع %.1f م   %s %d°   %.1f م/ث   %d FPS" % [
		pos3.x, pos3.z, pos3.y, cardinal, int(round(heading)),
		speed, int(round(Engine.get_frames_per_second()))]
	if state != "":
		txt = state + "   " + txt
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_rect(Rect2(0, 0, w + 20.0, size.y), Color(0.04, 0.05, 0.06, 0.52), true)
	draw_string(_font, Vector2(10, size.y * 0.72), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.90, 0.92, 0.92))
