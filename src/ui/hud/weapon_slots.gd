class_name WeaponSlots
extends Control
## خانات السلاح أسفل الوسط — مثل ببجي: خانتان رئيسيتان مع عدّاد
## الذخيرة، والمختارة منهما مؤطّرة بلون ذهبي.

signal slot_selected(index: int)

const SLOT_W := 148.0
const SLOT_H := 52.0

var slots: Array = [
	{"name": "بندقية", "mag": 30, "ammo": 90, "has": true},
	{"name": "مسدّس", "mag": 12, "ammo": 48, "has": true},
]
var current: int = 0

var _font: Font
var _font_b: Font
var _touch := -1

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SLOT_W * 2.0 + 10.0, SLOT_H)
	_font = UITheme.load_font(UITheme.FONT_REGULAR)
	_font_b = UITheme.load_font(UITheme.FONT_BOLD)

func set_ammo(idx: int, mag: int, reserve: int) -> void:
	if idx < 0 or idx >= slots.size():
		return
	slots[idx]["mag"] = mag
	slots[idx]["ammo"] = reserve
	queue_redraw()

func select(idx: int) -> void:
	if idx == current or idx < 0 or idx >= slots.size():
		return
	current = idx
	queue_redraw()
	slot_selected.emit(idx)

func _gui_input(event: InputEvent) -> void:
	var p := Vector2.ZERO
	var down := false
	if event is InputEventScreenTouch:
		p = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		p = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
	else:
		return
	if not down:
		return
	var idx := int(p.x / (SLOT_W + 10.0))
	if idx >= 0 and idx < slots.size():
		select(idx)
		accept_event()

func _draw() -> void:
	for i in slots.size():
		var s: Dictionary = slots[i]
		var x := float(i) * (SLOT_W + 10.0)
		var r := Rect2(x, 0, SLOT_W, SLOT_H)
		var on: bool = (i == current)
		draw_rect(r, Color(0.05, 0.06, 0.07, 0.62 if on else 0.44), true)
		draw_rect(r, Color(0.92, 0.78, 0.36, 0.95) if on
			else Color(1, 1, 1, 0.16), false, 2.0 if on else 1.0)

		# رسم صورة سلاح مبسّطة: خط السبطانة والمخزن والقبضة
		var cy := 18.0
		var gx := x + 16.0
		var col := Color(0.90, 0.91, 0.92, 0.92 if on else 0.62)
		draw_line(Vector2(gx, cy), Vector2(gx + 62.0, cy), col, 3.0)
		draw_line(Vector2(gx + 44.0, cy), Vector2(gx + 38.0, cy + 13.0), col, 3.0)
		draw_rect(Rect2(gx + 20.0, cy + 2.0, 12.0, 11.0), col, true)

		var ammo := "%d/%d" % [int(s["mag"]), int(s["ammo"])]
		draw_string(_font_b, Vector2(x + 86.0, SLOT_H - 14.0), ammo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19,
			Color(1, 1, 1, 0.96) if on else Color(1, 1, 1, 0.58))
		draw_string(_font, Vector2(x + 16.0, SLOT_H - 4.0), str(s["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.42))
