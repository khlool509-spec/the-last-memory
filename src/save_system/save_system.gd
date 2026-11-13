extends Node
## نظام الحفظ. مسجَّل كـ autoload باسم SaveSystem.
## ملف واحد الآن؛ خانات متعددة تُضاف في المرحلة 6.

signal game_saved()
signal game_loaded()

const SAVE_PATH := "user://save_01.json"
const VERSION := 1

var data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"created_utc": Time.get_datetime_string_from_system(true),
		"chapter": 1,
		"checkpoint": "start",
		"play_seconds": 0.0,
		"player_position": [0.0, 1.0, 0.0],
		"collectibles": [],
		"chapters_unlocked": [1],
		"flags": {},
	}

func start_new_game() -> void:
	data = default_data()
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("تعذّر فتح ملف الحفظ للكتابة")
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	game_saved.emit()
	return true

func load_game() -> bool:
	if not has_save():
		data = default_data()
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ملف حفظ تالف — بدء لعبة جديدة")
		data = default_data()
		return false
	data = parsed
	# ترقية الملفات القديمة بإضافة المفاتيح الناقصة
	var base := default_data()
	for k in base:
		if not data.has(k):
			data[k] = base[k]
	game_loaded.emit()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func is_chapter_unlocked(n: int) -> bool:
	if not has_save():
		return n == 1
	var arr: Array = data.get("chapters_unlocked", [1])
	return arr.has(n)

func collected_ids() -> Array:
	return data.get("collectibles", [])
