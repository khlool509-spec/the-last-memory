class_name Chapters
extends RefCounted
## بيانات الفصول الخمسة — مصدر واحد تستهلكه كل الشاشات.

const DATA := [
	{"n": 1, "ar": "الغابة المنسية", "en": "The Forgotten Forest",
	 "desc": "يستيقظ بلا ذاكرة بين أشجار لا نهاية لها.",
	 "scene": "res://levels/ch01_forest/chapter_one.tscn"},
	{"n": 2, "ar": "بوابة الأسرار", "en": "The Gate of Secrets",
	 "desc": "بوابة أثرية وكتاب ألغاز لا يُفتح بالمفاتيح."},
	{"n": 3, "ar": "البيت الصامت", "en": "The Silent House",
	 "desc": "منزل مهجور يعرف اسمه أكثر مما يعرفه هو."},
	{"n": 4, "ar": "ما وراء الجدار", "en": "Beyond the Wall",
	 "desc": "ممرات تحت الأرض ومختبر لم يُغلق بعد."},
	{"n": 5, "ar": "الحقيقة الأخيرة", "en": "The Final Truth",
	 "desc": "كل دليل جمعه يقوده إلى نهاية مختلفة."},
]

static func get_chapter(n: int) -> Dictionary:
	for c in DATA:
		if int(c["n"]) == n:
			return c
	return {}

## مسار مشهد الفصل، أو "" إذا لم يُبنَ بعد
static func scene_path(n: int) -> String:
	var c := get_chapter(n)
	return str(c.get("scene", ""))

static func is_playable(n: int) -> bool:
	var path := scene_path(n)
	return path != "" and ResourceLoader.exists(path)

static func first_playable() -> String:
	for c in DATA:
		var path := str(c.get("scene", ""))
		if path != "" and ResourceLoader.exists(path):
			return path
	return ""
