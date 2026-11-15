class_name HudLayoutEditor
extends Control
## محرّر مواضع أزرار الشاشة — يُفتح من الإعدادات.
##
## كل زر يُسحب بالإصبع إلى حيث يناسب يد اللاعب، ثم يُحفظ المخطّط
## فيُطبَّق على الواجهة في كل جلسة بعدها. أيدي الناس وأحجام شاشاتهم
## تختلف، وموضع زر الإطلاق الذي يناسب إبهاماً لا يناسب آخر.
##
## المخطّط يُخزَّن إزاحات نسبية إلى حجم الشاشة لا بكسلات مطلقة، فلا
## ينكسر حين يغيّر اللاعب جهازه أو يدير الشاشة.

signal closed()

const KEY := "hud_layout"
## الأزرار القابلة للتحريك واسم كل منها كما يراه اللاعب
const ITEMS := {
	"fire":     {"label": "إطلاق",       "r": 64.0, "def": Vector2(-0.085, -0.300)},
	"aim":      {"label": "تصويب",       "r": 46.0, "def": Vector2(-0.075, -0.520)},
	"reload":   {"label": "تعبئة",       "r": 42.0, "def": Vector2(-0.215, -0.300)},
	"crouch":   {"label": "قرفصاء",      "r": 40.0, "def": Vector2(-0.030, -0.430)},
	"prone":    {"label": "انبطاح",      "r": 40.0, "def": Vector2(-0.030, -0.560)},
	"autorun":  {"label": "ركض تلقائي",  "r": 42.0, "def": Vector2(-0.215, -0.470)},
	"jump":     {"label": "قفز",         "r": 52.0, "def": Vector2(-0.150, -0.180)},
	"interact": {"label": "تفاعل",       "r": 62.0, "def": Vector2(-0.075, -0.150)},
	"stick":    {"label": "عصا الحركة",  "r": 86.0, "def": Vector2(0.150, -0.250)},
}

var _nodes: Dictionary = {}
var _drag: String = ""
var _grab: Vector2 = Vector2.ZERO
var _font: Font

## يقرأ المخطّط المحفوظ، ويعود إلى الافتراضي لأي زر غير محفوظ
static func layout() -> Dictionary:
	var raw = Settings.get_value(KEY)
	var out: Dictionary = {}
	for k in ITEMS:
		var d: Vector2 = ITEMS[k]["def"]
		if raw is Dictionary and raw.has(k):
			var v = raw[k]
			if v is Array and v.size() == 2:
				d = Vector2(float(v[0]), float(v[1]))
		out[k] = d
	return out

## يحوّل الإزاحة النسبية إلى موضع بالبكسل داخل شاشة بحجم معلوم
static func to_pixels(rel: Vector2, screen: Vector2) -> Vector2:
	# س موجب = من اليسار، س سالب = من اليمين. وكذلك ص مع الأعلى/الأسفل.
	var x := rel.x * screen.x if rel.x >= 0.0 else screen.x + rel.x * screen.x
	var y := rel.y * screen.y if rel.y >= 0.0 else screen.y + rel.y * screen.y
	return Vector2(x, y)

func _ready() -> void:
	name = "HudLayoutEditor"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.build()
	_font = UITheme.load_font(UITheme.FONT_REGULAR)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.045, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hint := Label.new()
	hint.text = "اسحب كل زر إلى المكان المناسب ليدك، ثم احفظ"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Palette.DUST)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 18
	hint.offset_bottom = 54
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_build_handles()
	_build_buttons()

func _build_handles() -> void:
	var lay := layout()
	var screen := get_viewport_rect().size
	for k in ITEMS:
		var h := _Handle.new()
		h.key = k
		h.label = str(ITEMS[k]["label"])
		h.radius = float(ITEMS[k]["r"])
		h.position = to_pixels(lay[k], screen) - Vector2(h.radius, h.radius)
		h.custom_minimum_size = Vector2(h.radius * 2.0, h.radius * 2.0)
		h.size = h.custom_minimum_size
		h.editor = self
		add_child(h)
		_nodes[k] = h

func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -86
	row.offset_bottom = -18
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var save := Button.new()
	save.text = "حفظ المخطّط"
	save.custom_minimum_size = Vector2(240, 60)
	save.add_theme_font_size_override("font_size", 22)
	save.pressed.connect(_save)
	row.add_child(save)

	var reset := Button.new()
	reset.text = "إعادة الافتراضي"
	reset.custom_minimum_size = Vector2(220, 60)
	reset.pressed.connect(_reset)
	row.add_child(reset)

	var cancel := Button.new()
	cancel.text = "إلغاء"
	cancel.custom_minimum_size = Vector2(170, 60)
	cancel.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	row.add_child(cancel)

var _touch_id := -2

func begin_drag(key: String, touch: int, at: Vector2) -> void:
	_drag = key
	_touch_id = touch
	var n: Control = _nodes[key]
	_grab = at - n.position
	(n as _Handle).set_down(true)

func _drag_to(at: Vector2) -> void:
	if _drag == "":
		return
	var n: Control = _nodes[_drag]
	var s := get_viewport_rect().size
	# لا يخرج زر عن الشاشة: زرّ لا يُرى لا يُضغط
	n.position = Vector2(
		clampf(at.x - _grab.x, 0.0, s.x - n.size.x),
		clampf(at.y - _grab.y, 0.0, s.y - n.size.y))

func _end_drag() -> void:
	if _drag != "" and _nodes.has(_drag):
		(_nodes[_drag] as _Handle).set_down(false)
	_drag = ""
	_touch_id = -2

## التقاط الحركة على مستوى الشاشة كلها لا داخل المقبض وحده
func _input(event: InputEvent) -> void:
	if _drag == "":
		return
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touch_id == -1 or d.index == _touch_id:
			_drag_to(d.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if not t.pressed and (_touch_id == -1 or t.index == _touch_id):
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _touch_id == -1:
		_drag_to((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_drag()
			get_viewport().set_input_as_handled()

func _save() -> void:
	var s := get_viewport_rect().size
	var out: Dictionary = {}
	for k in _nodes:
		var n: Control = _nodes[k]
		var c := n.position + n.size * 0.5
		# نحفظ نسبةً إلى الحافة الأقرب: يمين الشاشة سالب، يسارها موجب
		var rx := (c.x / s.x) if c.x < s.x * 0.5 else ((c.x - s.x) / s.x)
		var ry := (c.y / s.y) if c.y < s.y * 0.5 else ((c.y - s.y) / s.y)
		out[k] = [rx, ry]
	Settings.set_value(KEY, out)
	Settings.save_settings()
	closed.emit()
	queue_free()

func _reset() -> void:
	var screen := get_viewport_rect().size
	for k in _nodes:
		var n: Control = _nodes[k]
		n.position = to_pixels(ITEMS[k]["def"], screen) - n.size * 0.5

## مقبض قابل للسحب: دائرة باسم الزر عليها
class _Handle:
	extends Control
	var key := ""
	var label := ""
	var radius := 50.0
	var editor: HudLayoutEditor = null
	var _down := false
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = UITheme.load_font(UITheme.FONT_REGULAR)

	func set_down(v: bool) -> void:
		if _down == v:
			return
		_down = v
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		# المقبض يبلّغ ببداية اللمس فقط. المتابعة على مستوى المحرّر
		# لأن الإصبع يخرج عن الدائرة فور تحرّكه، فتتوقّف أحداث
		# ‎_gui_input‎ وينقطع السحب — وهذا ما كان يحدث.
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				editor.begin_drag(key, t.index, global_position + t.position)
				accept_event()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				editor.begin_drag(key, -1, global_position + mb.position)
				accept_event()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, radius, Color(0.55, 0.10, 0.13, 0.42 if _down else 0.26))
		draw_arc(c, radius, 0.0, TAU, 40,
			Color(0.95, 0.30, 0.32, 0.95), 2.5, true)
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_font, c - Vector2(w * 0.5, -5.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.95))
