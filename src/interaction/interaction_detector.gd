class_name InteractionDetector
extends Node
## يتتبّع أقرب جسم قابل للتفاعل ضمن مدى اللاعب، ويبثّ تغيّر الهدف
## فتعرض الواجهة اسمه وتُفعَّل زر التفاعل.

signal focus_changed(target: Interactable)

@export var search_interval: float = 0.12

var _owner3d: Node3D
var _focus: Interactable = null
var _acc: float = 0.0

func setup(body: Node3D) -> void:
	_owner3d = body

func get_focus() -> Interactable:
	return _focus

func use_focus() -> bool:
	if _focus == null or not _focus.can_use():
		return false
	var ok := _focus.use()
	if ok:
		_refresh(true)
	return ok

func _process(delta: float) -> void:
	_acc += delta
	if _acc < search_interval:
		return
	_acc = 0.0
	_refresh(false)

func _refresh(force: bool) -> void:
	if _owner3d == null or not is_instance_valid(_owner3d):
		return
	var tree := _owner3d.get_tree()
	if tree == null:
		return
	var best: Interactable = null
	var best_d := INF
	var origin := _owner3d.global_position
	for node in tree.get_nodes_in_group("interactables"):
		var it := node as Interactable
		if it == null or not it.can_use():
			continue
		var d := it.distance_to_point(origin)
		if d <= it.reach and d < best_d:
			best = it
			best_d = d
	if force or best != _focus:
		_focus = best
		focus_changed.emit(_focus)
