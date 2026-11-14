extends Node
## الحقيبة والمذكرات. مسجَّل كـ autoload باسم Inv.
## يحفظ عبر SaveSystem تلقائياً عند كل تغيير.

signal item_added(id: String)
signal item_removed(id: String)
signal note_added(id: String)
signal changed()

var items: Array[String] = []
var notes: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveSystem.game_loaded.connect(_sync_from_save)
	_sync_from_save()

func _sync_from_save() -> void:
	items.clear()
	notes.clear()
	for v in SaveSystem.data.get("collectibles", []):
		var id := str(v)
		if not ItemDB.exists(id):
			continue
		if ItemDB.is_note(id):
			if not notes.has(id):
				notes.append(id)
		elif not items.has(id):
			items.append(id)
	changed.emit()

func has(id: String) -> bool:
	return items.has(id) or notes.has(id)

func add(id: String) -> bool:
	if not ItemDB.exists(id) or has(id):
		return false
	if ItemDB.is_note(id):
		notes.append(id)
		note_added.emit(id)
	else:
		items.append(id)
		item_added.emit(id)
	_write_save()
	changed.emit()
	return true

func remove(id: String) -> bool:
	var removed := items.has(id) or notes.has(id)
	items.erase(id)
	notes.erase(id)
	if removed:
		item_removed.emit(id)
		_write_save()
		changed.emit()
	return removed

func total_collected() -> int:
	return items.size() + notes.size()

func _write_save() -> void:
	var all: Array = []
	all.append_array(items)
	all.append_array(notes)
	SaveSystem.data["collectibles"] = all
	SaveSystem.save_game()
