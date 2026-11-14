class_name Toast
extends Control
## إشعار قصير يظهر أعلى الشاشة ثم يختفي. يُستخدم للالتقاط والتلميحات.

const LIFE := 2.4

static func show_on(parent: Control, text: String, glyph: String = "", accent: Color = Color(0.698, 0.071, 0.121)) -> Toast:
	var t := Toast.new()
	t.setup(text, glyph, accent)
	parent.add_child(t)
	return t

var _text := ""
var _glyph := ""
var _accent := Color(0.698, 0.071, 0.121)

func setup(text: String, glyph: String, accent: Color) -> void:
	_text = text
	_glyph = glyph
	_accent = accent

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_top = 96
	offset_left = -340
	offset_right = 340
	offset_bottom = 170
	custom_minimum_size = Vector2(680, 74)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.027, 0.027, 0.039, 0.92)
	sb.border_color = Color(_accent.r, _accent.g, _accent.b, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	if _glyph != "":
		var g := Label.new()
		g.text = _glyph
		g.add_theme_font_size_override("font_size", 30)
		g.add_theme_color_override("font_color", _accent.lightened(0.35))
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(g)

	var l := Label.new()
	l.text = _text
	l.layout_direction = Control.LAYOUT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", Color(0.914, 0.894, 0.863))
	row.add_child(l)

	modulate.a = 0.0
	position.y += 16
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(self, "position:y", position.y - 16, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(LIFE)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
