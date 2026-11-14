class_name InteractPrompt
extends Control
## شارة "تفاعل" تظهر فوق زر التفاعل حين يوجد هدف قريب.

var _label: Label
var _panel: PanelContainer
var _shown := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -270
	offset_right = 270
	offset_top = -300
	offset_bottom = -244

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.027, 0.027, 0.039, 0.88)
	sb.border_color = Color(0.812, 0.878, 0.949, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_label = Label.new()
	_label.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.914, 0.894, 0.863))
	_panel.add_child(_label)

	modulate.a = 0.0
	visible = false

func show_prompt(text: String) -> void:
	if text.strip_edges() == "":
		hide_prompt()
		return
	_label.text = text
	if _shown:
		return
	_shown = true
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)

func hide_prompt() -> void:
	if not _shown:
		return
	_shown = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func() -> void: visible = false)
