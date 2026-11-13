extends CanvasLayer
## انتقالات بين الشاشات مع تلاشٍ أسود. مسجَّل كـ autoload باسم Router.

signal transition_finished(path: String)

const FADE_OUT := 0.35
const FADE_IN := 0.45

var _overlay: ColorRect
var _busy := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	# تلاشٍ داخل عند بدء التشغيل
	_overlay.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, FADE_IN)

func go_to(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("مشهد غير موجود: " + path)
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, FADE_OUT)
	await tw.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("فشل الانتقال إلى %s (%d)" % [path, err])
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_overlay, "modulate:a", 0.0, FADE_IN)
	await tw2.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	transition_finished.emit(path)

func quit_game() -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, FADE_OUT)
	await tw.finished
	get_tree().quit()
