class_name Interactor
extends Node3D
## يركَّب على اللاعب. يجد أقرب هدف أمامه ويرسل إشارات للواجهة.

signal target_changed(target: Interactable, prompt_text: String)

@export var max_distance: float = 3.2
@export var max_angle_deg: float = 85.0
@export var scan_interval: float = 0.12

var current: Interactable = null
var _timer := 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = scan_interval
	_scan()

func _scan() -> void:
	var best: Interactable = null
	var best_score := INF
	var origin := global_position
	var fwd := -global_transform.basis.z
	var cos_limit := cos(deg_to_rad(max_angle_deg))

	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_inside_tree() or not it.can_use():
			continue
		var to: Vector3 = it.global_position - origin
		var d := to.length()
		if d > max_distance or d < 0.001:
			continue
		var dir := to / d
		var flat_fwd := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
		if flat_fwd.length() > 0.001 and flat_dir.length() > 0.001:
			if flat_fwd.dot(flat_dir) < cos_limit:
				continue
		var score := d - flat_fwd.dot(flat_dir) * 0.6
		if score < best_score:
			best_score = score
			best = it

	if best != current:
		current = best
		var txt := ""
		if current != null:
			txt = current.get_prompt()
		target_changed.emit(current, txt)

func try_use() -> bool:
	if current == null or not current.can_use():
		return false
	current.use(get_parent())
	_timer = 0.0
	_scan()
	return true
