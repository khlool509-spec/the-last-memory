class_name MenuButton3D
extends Button
## زر القائمة: تمييز دموي متحرك عند التحديد، وشريط جانبي، وتكبير خفيف.

var _bar: ColorRect
var _tw: Tween

func _init(label: String = "") -> void:
	text = label

func _ready() -> void:
	custom_minimum_size = Vector2(430, 72)
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	pivot_offset = custom_minimum_size * 0.5

	_bar = ColorRect.new()
	_bar.color = Palette.BLOOD_HOT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_bar.custom_minimum_size = Vector2(5, 0)
	_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar.modulate.a = 0.0
	add_child(_bar)

	mouse_entered.connect(_on_focus_like)
	focus_entered.connect(_on_focus_like)
	mouse_exited.connect(_on_blur_like)
	focus_exited.connect(_on_blur_like)
	pressed.connect(_on_pressed)

func _on_focus_like() -> void:
	_animate(1.0, Vector2(1.035, 1.035))

func _on_blur_like() -> void:
	_animate(0.0, Vector2.ONE)

func _animate(bar_alpha: float, target_scale: Vector2) -> void:
	if _tw and _tw.is_running():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw.tween_property(_bar, "modulate:a", bar_alpha, 0.16)
	_tw.tween_property(self, "scale", target_scale, 0.16)

func _on_pressed() -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2(0.97, 0.97), 0.07)
	tw.tween_property(self, "scale", Vector2(1.035, 1.035), 0.12)
