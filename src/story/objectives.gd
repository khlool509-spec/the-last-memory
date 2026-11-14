extends Node
## أهداف اللعب. مسجَّل كـ autoload باسم Goals.

signal objective_changed(text: String)
signal objective_completed(id: String)

var current_id: String = ""
var current_text: String = ""

const CHAPTER1 := [
	{"id": "wake", "text": "الهدف: انهض وتعرّف على المكان"},
	{"id": "find_note", "text": "الهدف: ابحث عن أثر يشرح ما حدث"},
	{"id": "follow_lanterns", "text": "الهدف: اتبع الفوانيس عبر الغابة"},
	{"id": "reach_gate", "text": "الهدف: صِل إلى البوابة الأثرية"},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_chapter(n: int) -> void:
	if n == 1 and not CHAPTER1.is_empty():
		set_objective(str(CHAPTER1[0]["id"]), str(CHAPTER1[0]["text"]))

func set_objective(id: String, text: String) -> void:
	current_id = id
	current_text = text
	SaveSystem.data["checkpoint"] = id
	objective_changed.emit(text)

func complete(id: String) -> void:
	if current_id != id:
		return
	objective_completed.emit(id)
	var idx := -1
	for i in CHAPTER1.size():
		if str(CHAPTER1[i]["id"]) == id:
			idx = i
			break
	if idx >= 0 and idx + 1 < CHAPTER1.size():
		var nxt: Dictionary = CHAPTER1[idx + 1]
		set_objective(str(nxt["id"]), str(nxt["text"]))
	else:
		set_objective("done", "الهدف: الفصل الأول اكتمل")
	SaveSystem.save_game()
