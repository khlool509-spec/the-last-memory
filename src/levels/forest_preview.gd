extends GameLevel
class_name ForestPreview

const FOREST_SCENE := "res://world.tscn"
var forest_root: Node3D

func _ready() -> void:
	super._ready()
	call_deferred("_align_player_to_terrain")

func _align_player_to_terrain() -> void:
	if not is_instance_valid(player):
		return
	# Keep physics paused for this one startup placement until Terrain3D's collision is ready.
	player.set_physics_process(false)
	await get_tree().physics_frame
	if not is_instance_valid(player) or not is_inside_tree():
		return
	var from := Vector3(player.global_position.x, 256.0, player.global_position.z)
	var to := Vector3(player.global_position.x, -64.0, player.global_position.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 << 2)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_error("ForestPreview: spawn ray did not hit Terrain3D collision")
		player.set_physics_process(true)
		return
	var ground: Vector3 = hit["position"]
	player.global_position = Vector3(player.global_position.x, ground.y + 0.08, player.global_position.z)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	SaveSystem.data["player_position"] = [
		player.global_position.x, player.global_position.y, player.global_position.z
	]
	SaveSystem.save_game()
	print("[ForestPreview] Spawn aligned to Terrain3D at Y=%.2f" % ground.y)

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
			root.remove_child(child)
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
