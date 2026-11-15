class_name Tutorial
extends CanvasLayer
## تعليمات عربية تُرافق اللاعب حتى يُتقن كل عنصر من عناصر التحكّم.
##
## لا تُعرض كلها دفعة واحدة ولا تختفي بمؤقّت: كل خطوة تنتظر أن
## **يفعلها** اللاعب فعلاً، فإذا فعلها انتقلت إلى التالية. من يعرف
## اللعب يتجاوزها في ثوانٍ دون أن يُجبَر على قراءتها، ومن لا يعرف
## تبقى أمامه حتى يفهم. هذا ما يعنيه «حتى يفهم آلية اللعب».
##
## وتُحفظ بعد إتمامها فلا تُعاد في كل تشغيل.

signal finished()

const KEY := "tutorial_done"
const HOLD := 0.65        # ثانية من الاستمرار حتى تُحتسب الخطوة

## الخطوات بالترتيب. "check" اسم شرط يُقاس من حالة اللاعب.
const STEPS := [
	{"text": "حرّك إصبعك على العصا اليسرى للمشي", "check": "move",
		"glyph": "◎"},
	{"text": "اسحب على الجانب الأيمن من الشاشة لتدوير الكاميرا",
		"check": "look", "glyph": "👁"},
	{"text": "اضغط «ركض» وتحرّك لتجري", "check": "run", "glyph": "»"},
	{"text": "اضغط «قفز» للوثب فوق العوائق", "check": "jump", "glyph": "⤒"},
	{"text": "اضغط «قرفصاء» لتنخفض وتصير أهدأ", "check": "crouch",
		"glyph": "⌄"},
	{"text": "اضغط «انبطاح» لتختفي خلف الحواجز", "check": "prone",
		"glyph": "▁"},
	{"text": "اضغط «تصويب» لرفع السلاح أمامك", "check": "aim", "glyph": "⊕"},
	{"text": "اضغط «إطلاق» وأنت مصوّب", "check": "fire", "glyph": "◉"},
	{"text": "انزل إلى النهر — ستسبح تلقائياً حين يغمرك الماء",
		"check": "swim", "glyph": "≈"},
	{"text": "اضغط «غوص» وأنت في الماء لتنزل تحت السطح",
		"check": "dive", "glyph": "▼"},
	{"text": "أحسنت. تعرف الآن كيف تتحرّك — ابدأ باستكشاف الوادي",
		"check": "done", "glyph": "✓"},
]

var _player: Node = null
var _idx := 0
var _hold := 0.0
var _panel: PanelContainer
var _label: Label
var _glyph: Label
var _prog: ColorRect
var _prog_bg: ColorRect
var _seen_look := 0.0

static func already_done() -> bool:
	return bool(Settings.get_value(KEY))

func setup(player: Node) -> void:
	_player = player

func _ready() -> void:
	name = "Tutorial"
	layer = 24
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	_show_step()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)

	_panel = PanelContainer.new()
	_panel.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# أعلى الوسط تحت شريط البوصلة: لا يغطّي الأزرار ولا مركز الشاشة
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_top = 64
	_panel.offset_bottom = 132
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.068, 0.88)
	sb.border_color = Palette.BLOOD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var col := VBoxContainer.new()
	col.layout_direction = Control.LAYOUT_DIRECTION_RTL
	col.add_theme_constant_override("separation", 7)
	_panel.add_child(col)

	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	_glyph = Label.new()
	_glyph.add_theme_font_size_override("font_size", 26)
	_glyph.add_theme_color_override("font_color", Palette.BLOOD_HOT)
	row.add_child(_glyph)

	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 21)
	row.add_child(_label)

	# شريط تقدّم: يمتلئ بينما يُنفّذ اللاعب، فيعرف أن فعله يُحتسب
	_prog_bg = ColorRect.new()
	_prog_bg.color = Color(1, 1, 1, 0.10)
	_prog_bg.custom_minimum_size = Vector2(0, 4)
	col.add_child(_prog_bg)
	_prog = ColorRect.new()
	_prog.color = Palette.BLOOD
	_prog.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_prog.anchor_right = 0.0
	_prog_bg.add_child(_prog)

func _show_step() -> void:
	if _idx >= STEPS.size():
		_complete()
		return
	var st: Dictionary = STEPS[_idx]
	_label.text = str(st["text"])
	_glyph.text = str(st["glyph"])
	_hold = 0.0
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)
	if str(st["check"]) == "done":
		# الخطوة الأخيرة تهنئة لا شرط: تبقى ثلاث ثوانٍ ثم تنتهي
		await get_tree().create_timer(3.0).timeout
		_complete()

func _process(delta: float) -> void:
	if _player == null or _idx >= STEPS.size():
		return
	var st: Dictionary = STEPS[_idx]
	var key := str(st["check"])
	if key == "done":
		return
	if _met(key, delta):
		_hold += delta
	else:
		_hold = maxf(_hold - delta * 1.4, 0.0)
	_prog.anchor_right = clampf(_hold / HOLD, 0.0, 1.0)
	if _hold >= HOLD:
		_advance()

## هل الشرط متحقّق الآن؟ كلها تُقرأ من حالة اللاعب الحقيقية لا من
## ضغط الزر — فلا تُحتسب خطوة لم تُنفَّذ فعلاً.
func _met(key: String, delta: float) -> bool:
	match key:
		"move":
			return Vector2(_player.velocity.x, _player.velocity.z).length() > 0.9
		"look":
			# تراكم دوران الكاميرا: اللاعب يدير المشهد لا يلمس فقط
			var cam := _player.get_parent().get_node_or_null("FollowCamera")
			if cam == null:
				_seen_look += delta * 0.4     # لا كاميرا: لا نعلّق اللاعب
			else:
				_seen_look += absf(cam.rotation.y - _last_yaw) * 4.0
				_last_yaw = cam.rotation.y
			return _seen_look > 1.0
		"run":
			return _player.is_running()
		"jump":
			return not _player.is_on_floor() and _player.velocity.y > 0.5
		"crouch":
			return str(_player.stance) == "crouch"
		"prone":
			return str(_player.stance) == "prone"
		"aim":
			return bool(_player.is_aiming)
		"fire":
			return bool(_player.is_firing)
		"swim":
			return bool(_player.in_water)
		"dive":
			return bool(_player.submerged)
	return false

var _last_yaw := 0.0

func _advance() -> void:
	_idx += 1
	_hold = 0.0
	_prog.anchor_right = 0.0
	Audio.play("ui_click")
	_show_step()

## تخطٍّ يدوي: من يعرف اللعب لا يُحبس في التعليمات
func skip() -> void:
	_complete()

func _complete() -> void:
	Settings.set_value(KEY, true)
	Settings.save_settings()
	finished.emit()
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
