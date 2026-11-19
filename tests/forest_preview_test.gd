extends Node

var _fail := 0

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label, "  ", detail)

func _ready() -> void:
	print("=== Terrain3D spawn + controls regression test ===")
	var packed := load("res://levels/ch01_forest/forest_preview.tscn") as PackedScene
	_check("forest preview scene loads", packed != null)
	if packed == null:
		get_tree().quit(1)
		return
	var level := packed.instantiate() as ForestPreview
	_check("scene instantiates as ForestPreview", level != null)
	if level == null:
		get_tree().quit(1)
		return
	add_child(level)
	await get_tree().process_frame

	var terrain: Node = level.forest_root.get_node_or_null("Terrain3D") if level.forest_root else null
	var terrain_layer := int(terrain.get("collision_layer")) if terrain else 0
	_check("Terrain3D node exists", terrain != null)
	_check("Terrain3D collision layer is bit 4", terrain_layer == 4, "layer=%d" % terrain_layer)
	_check("player exists", level.player != null)
	_check("mobile HUD exists", level.hud != null)
	_check("movement joystick exists", level.hud != null and level.hud.joystick != null)
	_check("touch look area exists", level.hud != null and level.hud.look_area != null)
	_check("HUD movement signal is connected", level.hud != null and level.hud.move_input.get_connections().size() > 0)
	_check("mod menu is mounted", level.mod_menu != null)

	var follow_camera: Camera3D = level.cam.get_camera() if level.cam != null else null
	_check("third-person camera exists and is current",
		follow_camera != null and follow_camera.current)

	var has_sun := false
	var stack: Array[Node] = [level.forest_root] if level.forest_root != null else []
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is DirectionalLight3D:
			has_sun = true
		for child in node.get_children():
			stack.append(child)
	_check("authored forest has directional sunlight", has_sun)

	if level.player:
		_check("player collision mask includes Terrain3D",
			(level.player.collision_mask & terrain_layer) == terrain_layer,
			"mask=%d terrain_layer=%d" % [level.player.collision_mask, terrain_layer])
		_check("native floor snap is enabled", level.player.floor_snap_length >= 0.55,
			"floor_snap_length=%.2f" % level.player.floor_snap_length)
		_check("player starts upright", level.player.stance == "standing",
			"stance=%s" % level.player.stance)

	for i in 90:
		await get_tree().physics_frame
	if level.player:
		_check("player is standing on Terrain3D", level.player.is_on_floor(),
			"y=%.2f velocity_y=%.2f" % [level.player.global_position.y, level.player.velocity.y])
		_check("player is not below the map", level.player.global_position.y > -1.0,
			"y=%.2f" % level.player.global_position.y)
		var before := level.player.global_position
		level.player.set_move_input(Vector2(0.0, -1.0))
		for i in 35:
			await get_tree().physics_frame
		level.player.set_move_input(Vector2.ZERO)
		var moved := Vector2(
			level.player.global_position.x - before.x,
			level.player.global_position.z - before.z
		).length()
		_check("player movement still works", moved > 0.5, "moved=%.2f" % moved)

	level.queue_free()
	await get_tree().process_frame
	print("=== Terrain3D regression: %d failure(s) ===" % _fail)
	get_tree().quit(_fail)
