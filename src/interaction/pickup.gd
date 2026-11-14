class_name Pickup
extends Interactable
## غرض يُلتقط ويدخل الحقيبة.

@export var item_id: String = ""
@export var spin_speed: float = 0.9
@export var bob_height: float = 0.12

var _t := 0.0
var _base_y := 0.0

func _ready() -> void:
	if save_flag == "" and item_id != "":
		save_flag = "picked_" + item_id
	if prompt == "تفاعل" and item_id != "":
		prompt = "التقط: " + ItemDB.display_name(item_id)
	super._ready()
	_base_y = position.y
	set_process(can_use())

func _process(delta: float) -> void:
	_t += delta
	rotate_y(spin_speed * delta)
	position.y = _base_y + sin(_t * 1.7) * bob_height

func _on_use(_by: Node) -> void:
	if item_id != "":
		Inv.add(item_id)
	set_process(false)
	_fade_out()

func _fade_out() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.28).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", _base_y + 0.9, 0.28)
	tw.chain().tween_callback(func() -> void: visible = false)
