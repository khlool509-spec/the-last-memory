class_name Interactable
extends Area3D
## قاعدة كل شيء يمكن التفاعل معه. يُشتق منها: Pickup, NoteItem, DoorGate.

signal used(by: Node)

@export var prompt: String = "تفاعل"
@export var one_shot: bool = true
@export var enabled: bool = true
@export var save_flag: String = ""

var _consumed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	if save_flag != "" and SaveSystem.data.get("flags", {}).get(save_flag, false):
		_consumed = true
		enabled = false
		_on_already_used()

func can_use() -> bool:
	return enabled and not (_consumed and one_shot)

func get_prompt() -> String:
	return prompt

func use(by: Node = null) -> void:
	if not can_use():
		return
	if one_shot:
		_consumed = true
		enabled = false
	if save_flag != "":
		var flags: Dictionary = SaveSystem.data.get("flags", {})
		flags[save_flag] = true
		SaveSystem.data["flags"] = flags
		SaveSystem.save_game()
	_on_use(by)
	used.emit(by)

## للتجاوز في المشتقات
func _on_use(_by: Node) -> void:
	pass

func _on_already_used() -> void:
	visible = false
