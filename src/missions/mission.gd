class_name Mission
extends RefCounted
## وصف مهمة واحدة. بيانات خالصة بلا أي منطق مشهد،
## فيمكن اختبارها كاملة بلا محرك رسوميات.

enum Kind {
	REACH,      ## الوصول إلى موضع
	COLLECT,    ## جمع عدد من الأغراض
	INTERACT,   ## التفاعل مع جسم محدد
	RETURN,     ## العودة إلى نقطة البداية
}

enum State { LOCKED, ACTIVE, DONE }

var id: String = ""
var title: String = ""
var detail: String = ""
var kind: int = Kind.REACH
var target_id: String = ""
var required: int = 1
var progress: int = 0
var state: int = State.LOCKED
var hint: String = ""

func _init(data: Dictionary = {}) -> void:
	id = String(data.get("id", ""))
	title = String(data.get("title", ""))
	detail = String(data.get("detail", ""))
	kind = int(data.get("kind", Kind.REACH))
	target_id = String(data.get("target", ""))
	required = maxi(1, int(data.get("required", 1)))
	hint = String(data.get("hint", ""))

func is_done() -> bool:
	return state == State.DONE

func ratio() -> float:
	return clampf(float(progress) / float(required), 0.0, 1.0)

## نص الهدف كما يظهر في الواجهة
func objective_text() -> String:
	if required > 1:
		return "%s  (%d/%d)" % [title, progress, required]
	return title

func to_dict() -> Dictionary:
	return {"id": id, "progress": progress, "state": state}

func apply_dict(d: Dictionary) -> void:
	progress = int(d.get("progress", 0))
	state = int(d.get("state", State.LOCKED))
