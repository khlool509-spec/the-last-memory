class_name MissionSystem
extends Node
## متتالية المهام: مهمة نشطة واحدة في كل لحظة، والتقدّم يُبلَّغ بالأحداث.
## لا يعرف شيئاً عن المشهد ولا عن الواجهة — يُوصَل بالإشارات.

signal mission_started(mission: Mission)
signal progress_changed(mission: Mission)
signal mission_completed(mission: Mission)
signal all_completed()

var missions: Array[Mission] = []
var _index: int = -1

func load_missions(defs: Array) -> void:
	missions.clear()
	for d in defs:
		missions.append(Mission.new(d))
	_index = -1

func start() -> void:
	_index = -1
	_advance()

func current() -> Mission:
	if _index < 0 or _index >= missions.size():
		return null
	return missions[_index]

func current_index() -> int:
	return _index

func completed_count() -> int:
	var n := 0
	for m in missions:
		if m.is_done():
			n += 1
	return n

func is_finished() -> bool:
	return _index >= missions.size()

## يُستدعى عند حدث في العالم. يتقدّم فقط إن طابق الحدث المهمة النشطة.
func report(kind: int, target_id: String, amount: int = 1) -> bool:
	var m := current()
	if m == null or m.state != Mission.State.ACTIVE:
		return false
	if m.kind != kind:
		return false
	if m.target_id != "" and m.target_id != target_id:
		return false

	m.progress = mini(m.required, m.progress + maxi(1, amount))
	progress_changed.emit(m)
	if m.progress >= m.required:
		_complete(m)
	return true

func _complete(m: Mission) -> void:
	m.state = Mission.State.DONE
	mission_completed.emit(m)
	_advance()

func _advance() -> void:
	_index += 1
	if _index >= missions.size():
		all_completed.emit()
		return
	var m := missions[_index]
	m.state = Mission.State.ACTIVE
	mission_started.emit(m)

# ---------------------------------------------------------------- الحفظ

func to_dict() -> Dictionary:
	var arr := []
	for m in missions:
		arr.append(m.to_dict())
	return {"index": _index, "missions": arr}

func apply_dict(d: Dictionary) -> void:
	var arr: Array = d.get("missions", [])
	for entry in arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var mid := String(entry.get("id", ""))
		for m in missions:
			if m.id == mid:
				m.apply_dict(entry)
				break
	_index = int(d.get("index", -1))
