class_name MiniMap
extends Control
## خريطة مصغّرة أعلى اليمين — مثل ببجي: صورة ثابتة للعالم تُخبَز مرّة
## واحدة عند الإقلاع، ويُرسم فوقها سهم اللاعب ونطاق رؤيته.
##
## لا SubViewport ولا كاميرا ثانية: تصيير العالم مرّتين كل إطار على
## معالج جوال ثمنه ثلث معدّل الإطارات. الخبز مرّة واحدة يجعل كلفة
## الخريطة في التشغيل رسم سهم فقط.

const MAP_PX := 256               # دقّة الصورة المخبوزة
const VIEW_M := 150.0             # كم متراً يغطّي إطار الخريطة

var world_half: float = 200.0
var player_pos: Vector2 = Vector2.ZERO
var player_yaw: float = 0.0
var north_up: bool = true         # ببجي يثبّت الشمال لأعلى

var _tex: ImageTexture = null
var _font: Font

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(186, 186)
	_font = UITheme.load_font(UITheme.FONT_REGULAR)

## تُخبز الصورة من ارتفاع التضاريس ومسار النهر. تُستدعى مرّة بعد
## بناء العالم؛ تكلفتها ~60 ملّي ثانية ولا تتكرّر.
func bake(profile, river: PackedVector2Array) -> void:
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var step := (world_half * 2.0) / float(MAP_PX)
	var water: float = profile.WATER_LEVEL
	for py in MAP_PX:
		var z := -world_half + float(py) * step
		for px in MAP_PX:
			var x := -world_half + float(px) * step
			var h: float = profile.height(x, z)
			var c: Color
			if h <= water:
				c = Color(0.27, 0.42, 0.46)          # ماء
			else:
				# تظليل بالارتفاع: الوادي داكن والقمم فاتحة، فتُقرأ
				# التضاريس بلمحة كما في خريطة ببجي.
				var t: float = clampf((h - water) / 26.0, 0.0, 1.0)
				c = Color(0.22, 0.26, 0.19).lerp(Color(0.62, 0.60, 0.44), t)
			img.set_pixel(px, py, c)
	# النهر يُرسم خطّاً فوق التظليل ليبقى مقروءاً حتى حين يضيق
	for i in range(1, river.size()):
		_line(img, river[i - 1], river[i], step, Color(0.30, 0.52, 0.58))
	_tex = ImageTexture.create_from_image(img)
	queue_redraw()

func _line(img: Image, a: Vector2, b: Vector2, step: float, col: Color) -> void:
	var n := int(a.distance_to(b) / step) + 1
	for k in n + 1:
		var p := a.lerp(b, float(k) / float(n))
		var px := int((p.x + world_half) / step)
		var py := int((p.y + world_half) / step)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var qx := px + dx
				var qy := py + dy
				if qx >= 0 and qx < MAP_PX and qy >= 0 and qy < MAP_PX:
					img.set_pixel(qx, qy, col)

func set_player(pos: Vector2, yaw: float) -> void:
	if pos.distance_squared_to(player_pos) < 0.04 \
			and absf(yaw - player_yaw) < 0.01:
		return
	player_pos = pos
	player_yaw = yaw
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.05, 0.06, 0.07, 0.72), true)
	if _tex == null:
		draw_rect(r, Color(1, 1, 1, 0.10), false, 2.0)
		return

	# قصّ المنطقة المحيطة باللاعب من الصورة المخبوزة
	var span := VIEW_M / (world_half * 2.0) * float(MAP_PX)
	var cx := (player_pos.x + world_half) / (world_half * 2.0) * float(MAP_PX)
	var cy := (player_pos.y + world_half) / (world_half * 2.0) * float(MAP_PX)
	var src := Rect2(cx - span * 0.5, cy - span * 0.5, span, span)
	draw_texture_rect_region(_tex, r, src)

	# إطار وشبكة خفيفة
	draw_rect(r, Color(1, 1, 1, 0.16), false, 2.0)

	# مخروط الرؤية ثم سهم اللاعب في المركز
	var c := size * 0.5
	var fwd := Vector2(sin(player_yaw), -cos(player_yaw))
	var left := fwd.rotated(-0.42) * 44.0
	var right := fwd.rotated(0.42) * 44.0
	draw_colored_polygon(PackedVector2Array([c, c + left, c + right]),
		Color(1.0, 0.96, 0.75, 0.20))
	var tip := c + fwd * 11.0
	var bl := c + fwd.rotated(2.5) * 8.0
	var br := c + fwd.rotated(-2.5) * 8.0
	draw_colored_polygon(PackedVector2Array([tip, bl, br]),
		Color(1.0, 0.92, 0.42, 0.98))

	# حرف الشمال في الزاوية: الخريطة مثبّتة شمالاً كما في ببجي
	draw_string(_font, Vector2(8, 20), "N", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 16, Color(1, 1, 1, 0.70))
