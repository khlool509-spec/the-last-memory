class_name ActionButton
extends Control
## زر لمس دائري: حلقة + رمز، مع ارتداد عند الضغط ونبض عند التفعيل.
## لا يستخدم Button لأن اللمس هنا يحتاج تتبّع إصبع مستقل وشكلاً دائرياً.

signal pressed_changed(is_down: bool)
signal tapped()

@export var glyph: String = "●"
@export var label_text: String = ""
@export var radius: float = 58.0
@export var accent: Color = Palette.BLOOD
@export var hold_mode: bool = false

var is_down: bool = false
var _touch_index: int = -1
var _scale: float = 1.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = UITheme.load_font(UITheme.FONT_BOLD)
	set_process(true)

func _process(delta: float) -> void:
	var target := 0.9 if is_down else 1.0
	var prev := _scale
	_scale = move_toward(_scale, target, delta * 7.0)
	if not is_equal_approx(prev, _scale):
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1 and _inside(t.position):
			_set_down(true)
			_touch_index = t.index
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			_set_down(false)
			tapped.emit()
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and _inside(mb.position):
			if mb.pressed:
				_set_down(true)
			else:
				_set_down(false)
				tapped.emit()
			accept_event()

func _inside(p: Vector2) -> bool:
	return p.distance_to(size * 0.5) <= radius * 1.1

func _set_down(v: bool) -> void:
	if is_down == v:
		return
	is_down = v
	pressed_changed.emit(v)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := radius * _scale
	var fill_a := 0.5 if is_down else 0.26
	draw_circle(c, r, Palette.with_alpha(Palette.VOID, 0.55))
	draw_circle(c, r, Palette.with_alpha(accent, fill_a))
	draw_arc(c, r, 0.0, TAU, 56, Palette.with_alpha(accent, 0.95), 3.0, true)
	if is_down:
		draw_arc(c, r + 6.0, 0.0, TAU, 56, Palette.with_alpha(Palette.EMBER, 0.45), 2.0, true)
	if _font:
		var gsize := int(radius * 0.72)
		var gw := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gsize)
		draw_string(_font, c + Vector2(-gw.x * 0.5, gsize * 0.36), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, gsize, Palette.BONE)
		if label_text != "":
			var lsize := 17
			var lw := _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, lsize)
			draw_string(_font, c + Vector2(-lw.x * 0.5, r + 22.0), label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, lsize, Palette.with_alpha(Palette.DUST, 0.9))
