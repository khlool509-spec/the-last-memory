class_name SettingSlider
extends HBoxContainer
## صف إعداد بمنزلق: أيقونة + عنوان + منزلق + نسبة مئوية.
## مربوط مباشرة بمفتاح في Settings، ويحفظ عند إفلات الإصبع.

signal value_changed(value: float)

var key: String
var _slider: HSlider
var _value_label: Label
var _title: Label

## المدى اختياري: الافتراضي نسبة 0..1، ويمكن تمرير مدى حقيقي
## (معدّل الإطارات مثلاً 20..120) فيُعرَض بالقيمة لا بالنسبة.
var _lo := 0.0
var _hi := 1.0
var _as_percent := true

func _init(setting_key: String, title_text: String, glyph: String = "",
		lo: float = 0.0, hi: float = 1.0, step: float = 0.01) -> void:
	key = setting_key
	name = "Row_" + setting_key
	_lo = lo
	_hi = hi
	_as_percent = is_equal_approx(lo, 0.0) and is_equal_approx(hi, 1.0)
	_build(title_text, glyph)
	_slider.min_value = lo
	_slider.max_value = hi
	_slider.step = step

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
		ic.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
		add_child(ic)

	_title = Label.new()
	_title.text = title_text
	_title.custom_minimum_size = Vector2(190, 0)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Palette.BONE)
	add_child(_title)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.custom_minimum_size = Vector2(240, 34)
	add_child(_slider)

	_value_label = Label.new()
	_value_label.custom_minimum_size = Vector2(78, 0)
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_value_label.add_theme_color_override("font_color", Palette.DUST)
	add_child(_value_label)

func _ready() -> void:
	var v := float(Settings.get_value(key))
	_slider.value = v
	_refresh(v)
	_slider.value_changed.connect(_on_slider_changed)
	_slider.drag_ended.connect(_on_drag_ended)

func _on_slider_changed(v: float) -> void:
	# المدى الحقيقي يُحفَظ عدداً صحيحاً (معدّل الإطارات مثلاً)
	Settings.set_value(key, v if _as_percent else int(round(v)))
	_refresh(v)
	value_changed.emit(v)

func _on_drag_ended(changed: bool) -> void:
	if changed:
		Settings.save_settings()

func _refresh(v: float) -> void:
	_value_label.text = ("%d%%" % int(round(v * 100.0))) if _as_percent \
		else ("%d" % int(round(v)))

func set_value(v: float) -> void:
	_slider.value = v
	_refresh(v)

## يُعيد قراءة القيمة من الإعدادات — بعد إعادة الضبط مثلاً
func refresh_from_settings() -> void:
	var v := float(Settings.get_value(key))
	_slider.set_value_no_signal(v)
	_refresh(v)
