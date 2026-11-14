class_name NoteItem
extends Interactable
## ورقة تُقرأ. تفتح واجهة القراءة ثم تُضاف للمذكرات.

signal read_requested(item_id: String)

@export var item_id: String = "note_awakening"

func _ready() -> void:
	if save_flag == "" and item_id != "":
		save_flag = "read_" + item_id
	prompt = "اقرأ"
	one_shot = true
	super._ready()

func _on_use(_by: Node) -> void:
	if item_id != "":
		Inv.add(item_id)
	read_requested.emit(item_id)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: visible = false)
