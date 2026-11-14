class_name UITheme
extends RefCounted
## يبني سمة الواجهة بالكود. السبب: ملفات .tres تُكتب يدوياً وتخطئ،
## والبناء البرمجي قابل للاختبار والمراجعة.

const FONT_REGULAR := "res://assets/fonts/Amiri-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/Amiri-Bold.ttf"

const SIZE_TITLE := 58
const SIZE_HEADING := 36
const SIZE_BUTTON := 27
const SIZE_BODY := 24
const SIZE_SMALL := 19

static func load_font(path: String) -> FontFile:
	var f := ResourceLoader.load(path)
	return f as FontFile if f is FontFile else null

static func build() -> Theme:
	var t := Theme.new()
	var regular := load_font(FONT_REGULAR)
	var bold := load_font(FONT_BOLD)
	if regular:
		t.default_font = regular
	t.default_font_size = SIZE_BODY

	_build_button(t, bold)
	_build_label(t)
	_build_slider(t)
	_build_panel(t)
	_build_scroll(t)
	return t

static func _flat(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

static func _build_button(t: Theme, bold: FontFile) -> void:
	var normal := _flat(Palette.with_alpha(Palette.NIGHT, 0.72), Palette.with_alpha(Palette.SMOKE, 0.9), 2, 4)
	var hover := _flat(Palette.with_alpha(Palette.BLOOD_DEEP, 0.55), Palette.BLOOD_HOT, 2, 4)
	hover.shadow_color = Palette.with_alpha(Palette.EMBER, 0.35)
	hover.shadow_size = 10
	var pressed := _flat(Palette.with_alpha(Palette.BLOOD, 0.75), Palette.EMBER, 2, 4)
	var focus := _flat(Color(0, 0, 0, 0), Palette.with_alpha(Palette.EMBER, 0.8), 2, 4)
	var disabled := _flat(Palette.with_alpha(Palette.ASH, 0.5), Palette.with_alpha(Palette.SMOKE, 0.4), 1, 4)

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Palette.BONE)
	t.set_color("font_hover_color", "Button", Color("#fff2ef"))
	t.set_color("font_pressed_color", "Button", Color("#ffffff"))
	t.set_color("font_disabled_color", "Button", Palette.MUTED)
	t.set_font_size("font_size", "Button", SIZE_BUTTON)
	if bold:
		t.set_font("font", "Button", bold)

static func _build_label(t: Theme) -> void:
	t.set_color("font_color", "Label", Palette.BONE)
	t.set_font_size("font_size", "Label", SIZE_BODY)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_constant("shadow_outline_size", "Label", 1)

static func _build_slider(t: Theme) -> void:
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Palette.with_alpha(Palette.VOID, 0.85)
	slider_bg.set_corner_radius_all(8)
	slider_bg.border_color = Palette.with_alpha(Palette.SMOKE, 0.9)
	slider_bg.set_border_width_all(1)
	slider_bg.content_margin_top = 7
	slider_bg.content_margin_bottom = 7

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Palette.BLOOD
	grabber_area.set_corner_radius_all(8)

	var grabber_hl := StyleBoxFlat.new()
	grabber_hl.bg_color = Palette.BLOOD_HOT
	grabber_hl.set_corner_radius_all(8)

	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", grabber_area)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber_hl)
	t.set_constant("center_grabber", "HSlider", 1)

static func _build_panel(t: Theme) -> void:
	var p := StyleBoxFlat.new()
	p.bg_color = Palette.with_alpha(Palette.NIGHT, 0.88)
	p.border_color = Palette.with_alpha(Palette.BLOOD, 0.85)
	p.set_border_width_all(2)
	p.set_corner_radius_all(6)
	p.set_content_margin_all(22)
	p.shadow_color = Color(0, 0, 0, 0.6)
	p.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", p)
	t.set_stylebox("panel", "Panel", p)

static func _build_scroll(t: Theme) -> void:
	var grab := StyleBoxFlat.new()
	grab.bg_color = Palette.with_alpha(Palette.BLOOD, 0.8)
	grab.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.with_alpha(Palette.VOID, 0.6)
	bg.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", bg)
