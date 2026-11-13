class_name TouchLookArea
extends Control
## منطقة النظر: سحب الإصبع يدوّر الكاميرا. تتبّع إصبع مستقل عن العصا،
## فيمكن المشي والنظر في الوقت نفسه بإصبعين.

signal look_delta(delta: Vector2)

var _touch_index: int = -1
var _mouse_active: bool = false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			look_delta.emit(d.relative)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_active = mb.pressed
	elif event is InputEventMouseMotion and _mouse_active:
		look_delta.emit((event as InputEventMouseMotion).relative)
