class_name OrnateFrame
extends Control
## إطار مزخرف بزوايا دموية — يُرسم بالكود لا بصورة، فيبقى حاداً على أي دقة.

@export var line_color: Color = Palette.BLOOD
@export var accent_color: Color = Palette.EMBER
@export var thickness: float = 2.0
@export var corner_len: float = 34.0
@export var inset: float = 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var c := line_color
	# الإطار الخافت
	draw_rect(r, Color(c.r, c.g, c.b, 0.35), false, thickness)
	# الزوايا البارزة
	var L := minf(corner_len, minf(r.size.x, r.size.y) * 0.4)
	var pts := [
		[r.position, Vector2(L, 0), Vector2(0, L)],
		[Vector2(r.end.x, r.position.y), Vector2(-L, 0), Vector2(0, L)],
		[Vector2(r.position.x, r.end.y), Vector2(L, 0), Vector2(0, -L)],
		[r.end, Vector2(-L, 0), Vector2(0, -L)],
	]
	for p in pts:
		var o: Vector2 = p[0]
		draw_line(o, o + (p[1] as Vector2), accent_color, thickness + 0.5)
		draw_line(o, o + (p[2] as Vector2), accent_color, thickness + 0.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
