class_name DoorGate
extends Interactable
## باب أو بوابة. قد تتطلب مفتاحاً.

signal opened()
signal refused(reason: String)

@export var required_item: String = ""
@export var consume_item: bool = false
@export var locked_prompt: String = "مقفل"
@export var open_angle_deg: float = 92.0
@export var open_time: float = 1.1

var _is_open := false
@onready var _leaf: Node3D = get_node_or_null("Leaf") as Node3D

func _ready() -> void:
	one_shot = false
	prompt = "افتح"
	super._ready()
	if _consumed:
		_snap_open()

func get_prompt() -> String:
	if _is_open:
		return ""
	if required_item != "" and not Inv.has(required_item):
		return locked_prompt
	return prompt

func can_use() -> bool:
	return enabled and not _is_open

func use(by: Node = null) -> void:
	if not can_use():
		return
	if required_item != "" and not Inv.has(required_item):
		refused.emit("تحتاج: " + ItemDB.display_name(required_item))
		return
	if consume_item and required_item != "":
		Inv.remove(required_item)
	_is_open = true
	if save_flag != "":
		var flags: Dictionary = SaveSystem.data.get("flags", {})
		flags[save_flag] = true
		SaveSystem.data["flags"] = flags
		SaveSystem.save_game()
	_swing()
	opened.emit()
	used.emit(by)

func _swing() -> void:
	if _leaf == null:
		return
	var tw := create_tween()
	tw.tween_property(_leaf, "rotation:y", deg_to_rad(open_angle_deg), open_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _snap_open() -> void:
	_is_open = true
	if _leaf != null:
		_leaf.rotation.y = deg_to_rad(open_angle_deg)

func _on_already_used() -> void:
	pass  # الأبواب تبقى مرئية، فقط مفتوحة
