extends GameLevel
class_name ForestPreview

const FOREST_SCENE := "res://world.tscn"
var forest_root: Node3D

func build_world() -> void:
	name = "ForestPreview"
	chapter_index = 1
	ambient_key = ""

	if not ResourceLoader.exists(FOREST_SCENE):
		push_error("Forest scene missing: " + FOREST_SCENE)
		spawn_point = Vector3(0, 6.0, 0)
		return

	var packed := load(FOREST_SCENE) as PackedScene
	forest_root = packed.instantiate() as Node3D
	forest_root.name = "ForestWorld"
	add_child(forest_root)

	# The source demo contains its own keyboard player/UI. Remove those
	# pieces so THE LAST MEMORY's real mobile Player + HUD control the scene.
	_strip_source_demo_nodes(forest_root)

	# Source forest's original player starts around this location.
	# Keep the same area so the authored terrain is already underneath us.
	spawn_point = Vector3(116.5, 18.0, 97.25)
	spawn_yaw_deg = 150.0

	# Keep the old generated world only as gameplay-data logic; it must not
	# become a second visible/collidable ground under the new terrain.
	_disable_legacy_world_collision()

	# Safety collision only: it prevents an infinite fall, but never teleports or reloads the player.
	_create_ground_safety_zone()

func place_contents() -> void:
	# Preview intentionally keeps the authored forest clean:
	# player + mobile HUD + real terrain/foliage are the visible result.
	pass

func _strip_source_demo_nodes(root: Node) -> void:
	var remove_names := {
		"Player": true,
		"CanvasLayer": true,
	}
	for child in root.get_children().duplicate():
		if remove_names.has(child.name):
			child.queue_free()
		else:
			_strip_source_demo_nodes(child)

func _disable_legacy_world_collision() -> void:
	var legacy := get_node_or_null("WorldRenderer")
	if legacy:
		legacy.visible = false
		_disable_collisions_recursive(legacy)

func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		node.set_collision_layer(0)
		node.set_collision_mask(0)
	for child in node.get_children():
		_disable_collisions_recursive(child)

func _create_ground_safety_zone() -> void:
	if get_node_or_null("GroundSafetyZone") != null:
		return

	var body := StaticBody3D.new()
	body.name = "GroundSafetyZone"
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := CollisionShape3D.new()
	shape.name = "SafetyFloorCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(1024.0, 2.0, 1024.0)
	shape.shape = box
	shape.position.y = -8.0
	body.add_child(shape)
	add_child(body)
