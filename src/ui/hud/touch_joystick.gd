class_name TouchJoystick
extends Control
## عصا تحكم افتراضية احترافية:
## - عائمة: تظهر عند موضع اللمس داخل منطقتها، لا في مكان ثابت يجبر الإبهام
## - تتبّع إصبع واحد بمعرّفه، فلا تتداخل مع لمسات الكاميرا أو الأزرار
## - منطقة ميتة، ومقبض محصور داخل نصف القطر، وتلاشٍ ناعم عند الرفع
## - تُرسم بالكود: حادّة على أي دقة وبلا أصول

signal direction_changed(dir: Vector2)

@export var radius: float = 110.0
@export var knob_radius: float = 46.0
@export var dead_zone: float = 0.14
@export var floating: bool = true

var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active: bool = false
var _alpha: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)

func _process(delta: float) -> void:
	var target := 1.0 if _active else 0.0
	var prev := _alpha
	_alpha = move_toward(_alpha, target, delta * 6.0)
	if not is_equal_approx(prev, _alpha):
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			_center = t.position if floating else size * 0.5
			_knob = _center
			_active = true
			_emit()
			queue_redraw()
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update_knob(d.position)
			accept_event()
	# دعم الفأرة للاختبار على سطح المكتب
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _touch_index == -1:
				_touch_index = -2
				_center = mb.position if floating else size * 0.5
				_knob = _center
				_active = true
				_emit()
				queue_redraw()
			elif not mb.pressed and _touch_index == -2:
				_release()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update_knob((event as InputEventMouseMotion).position)

func _update_knob(pos: Vector2) -> void:
	var delta := pos - _center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	_knob = _center + delta
	_emit()
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_active = false
	output = Vector2.ZERO
	direction_changed.emit(output)
	queue_redraw()

func _emit() -> void:
	var delta := (_knob - _center) / radius
	if delta.length() < dead_zone:
		output = Vector2.ZERO
	else:
		# إعادة تطبيع ما بعد المنطقة الميتة: لا قفزة مفاجئة عند تجاوزها
		var mag := inverse_lerp(dead_zone, 1.0, minf(delta.length(), 1.0))
		output = delta.normalized() * mag
	direction_changed.emit(output)

func _draw() -> void:
	if _alpha <= 0.01:
		return
	var a := _alpha
	var ring_bg := Palette.with_alpha(Palette.VOID, 0.45 * a)
	var ring_line := Palette.with_alpha(Palette.BLOOD, 0.75 * a)
	var knob_fill := Palette.with_alpha(Palette.BLOOD, 0.55 * a)
	var knob_line := Palette.with_alpha(Palette.EMBER, 0.95 * a)

	draw_circle(_center, radius, ring_bg)
	draw_arc(_center, radius, 0.0, TAU, 64, ring_line, 2.5, true)
	draw_arc(_center, radius * 0.62, 0.0, TAU, 48, Palette.with_alpha(Palette.SMOKE, 0.5 * a), 1.5, true)
	draw_circle(_knob, knob_radius, knob_fill)
	draw_arc(_knob, knob_radius, 0.0, TAU, 48, knob_line, 2.5, true)
	# مؤشر الاتجاه
	if output.length() > 0.05:
		draw_line(_center, _center + output * radius * 0.9,
			Palette.with_alpha(Palette.EMBER, 0.55 * a), 3.0, true)
