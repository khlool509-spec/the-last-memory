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
	_normalize()
	game_loaded.emit()
	return true

## JSON يعيد كل الأعداد كـ float، فـ [1,2] تصير [1.0,2.0]
## وعندها Array.has(2) يرجع false وتظهر الفصول مقفلة بعد إعادة الفتح.
## خطأ حقيقي كُشف باختبار، فالتطبيع صار جزءاً من التحميل.
func _normalize() -> void:
	var ints: Array = []
	for v in data.get("chapters_unlocked", []):
		var n := int(v)
		if not ints.has(n):
			ints.append(n)
	if ints.is_empty():
		ints = [1]
	ints.sort()
	data["chapters_unlocked"] = ints

	data["chapter"] = int(data.get("chapter", 1))
	data["version"] = int(data.get("version", VERSION))
	data["play_seconds"] = float(data.get("play_seconds", 0.0))

	var ids: Array = []
	for v in data.get("collectibles", []):
		var sid := str(v)
		if not ids.has(sid):
			ids.append(sid)
	data["collectibles"] = ids

	var pos: Array = data.get("player_position", [0.0, 1.0, 0.0])
	var fixed: Array = []
	for i in 3:
		fixed.append(float(pos[i]) if i < pos.size() else 0.0)
	data["player_position"] = fixed

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func is_chapter_unlocked(n: int) -> bool:
	if not has_save():
		return n == 1
	for v in data.get("chapters_unlocked", [1]):
		if int(v) == n:
			return true
	return false

## فتح فصل. chapters_unlocked مصفوفة أرقام لا عدّاد — خطأ حقيقي وقع هنا.
func unlock_chapter(n: int) -> bool:
	if is_chapter_unlocked(n):
		return false
	var arr: Array = data.get("chapters_unlocked", [1])
	arr.append(n)
	arr.sort()
	data["chapters_unlocked"] = arr
	save_game()
	return true

func highest_unlocked() -> int:
	var arr: Array = data.get("chapters_unlocked", [1])
	var hi := 1
	for v in arr:
		hi = maxi(hi, int(v))
	return hi

func collected_ids() -> Array:
	return data.get("collectibles", [])
