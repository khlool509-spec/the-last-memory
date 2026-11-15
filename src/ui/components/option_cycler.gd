class_name OptionCycler
extends HBoxContainer
## صف إعداد بخيارات متعددة: ‹ القيمة › — مناسب للمس أكثر من القوائم المنسدلة.

signal option_changed(value: Variant)

var key: String
var _values: Array = []
var _labels: Array = []
var _index: int = 0
var _value_label: Label
var _title: Label

func _init(setting_key: String, title_text: String, values: Array, labels: Array, glyph: String = "") -> void:
	key = setting_key
	_values = values
	_labels = labels
	name = "Opt_" + setting_key
	_build(title_text, glyph)

func _build(title_text: String, glyph: String) -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_theme_constant_override("separation", 16)
	custom_minimum_size.y = 56

	if glyph != "":
		var ic := Label.new()
		ic.text = glyph
		ic.custom_minimum_size = Vector2(38, 0)
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.add_theme_color_override("font_color", Palette.BLOOD_HOT)
		add_child(ic)

	_title = Label.new()
	_title.text = title_text
	_title.custom_minimum_size = Vector2(190, 0)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	var prev := _arrow("‹")
	prev.pressed.connect(func(): _step(-1))
	add_child(prev)

	_value_label = Label.new()
	_value_label.custom_minimum_size = Vector2(170, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_color_override("font_color", Palette.BONE)
	add_child(_value_label)

	var next := _arrow("›")
	next.pressed.connect(func(): _step(1))
	add_child(next)

func _arrow(glyph: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = Vector2(56, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	b.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	return b

func _ready() -> void:
	var cur: Variant = Settings.get_value(key)
	_index = maxi(0, _values.find(cur))
	_refresh()

func _step(dir: int) -> void:
	if _values.is_empty():
		return
	_index = wrapi(_index + dir, 0, _values.size())
	Settings.set_value(key, _values[_index])
	Settings.save_settings()
	_refresh()
	option_changed.emit(_values[_index])

func _refresh() -> void:
	if _index >= 0 and _index < _labels.size():
		_value_label.text = str(_labels[_index])
	var tw := create_tween()
	tw.tween_property(_value_label, "modulate:a", 0.4, 0.05)
	tw.tween_property(_value_label, "modulate:a", 1.0, 0.12)

## يُعيد قراءة القيمة من الإعدادات — بعد إعادة الضبط مثلاً
func refresh_from_settings() -> void:
	var v: Variant = Settings.get_value(key)
	var i := _values.find(v)
	if i >= 0:
		_index = i
		if _value_label:
			_value_label.text = str(_labels[_index])
