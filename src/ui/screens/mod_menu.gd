class_name ModMenu
extends CanvasLayer
## Lightweight mobile developer menu. It never performs automatic recovery.
signal closed()

var player: Player
var panel: PanelContainer
var fly_button: Button
var speed_slider: HSlider
var status: Label
var saved_point: Vector3
var has_saved_point := false

func setup(target: Player) -> void:
	player = target

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Mod Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	fly_button = Button.new()
	fly_button.text = "Fly: OFF"
	fly_button.custom_minimum_size.y = 58
	fly_button.pressed.connect(_toggle_fly)
	col.add_child(fly_button)

	var speed_label := Label.new()
	speed_label.text = "Fly Speed"
	col.add_child(speed_label)
	speed_slider = HSlider.new()
	speed_slider.min_value = 2.0
	speed_slider.max_value = 30.0
	speed_slider.step = 0.5
	speed_slider.value = 8.0
	speed_slider.value_changed.connect(_on_speed_changed)
	col.add_child(speed_slider)

	var save_btn := Button.new()
	save_btn.text = "Save Teleport Point"
	save_btn.custom_minimum_size.y = 52
	save_btn.pressed.connect(_save_point)
	col.add_child(save_btn)

	var tp_btn := Button.new()
	tp_btn.text = "Teleport to Saved Point"
	tp_btn.custom_minimum_size.y = 52
	tp_btn.pressed.connect(_teleport_saved)
	col.add_child(tp_btn)

	var up := Button.new()
	up.text = "Fly Up"
	up.custom_minimum_size.y = 48
	up.button_down.connect(func(): _set_vertical(1.0))
	up.button_up.connect(func(): _set_vertical(0.0))
	col.add_child(up)

	var down := Button.new()
	down.text = "Fly Down"
	down.custom_minimum_size.y = 48
	down.button_down.connect(func(): _set_vertical(-1.0))
	down.button_up.connect(func(): _set_vertical(0.0))
	col.add_child(down)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 56
	close.pressed.connect(close_menu)
	col.add_child(close)

func open_menu() -> void:
	visible = true
	get_tree().paused = false
	if player:
		player.set_mod_fly_speed(speed_slider.value)
	_update_state()

func close_menu() -> void:
	if player:
		player.set_mod_fly(false)
		player.set_mod_fly_vertical(0.0)
	visible = false
	closed.emit()

func _toggle_fly() -> void:
	if not player:
		return
	player.set_mod_fly(not player.mod_fly_enabled)
	_update_state()

func _on_speed_changed(value: float) -> void:
	if player:
		player.set_mod_fly_speed(value)
	_update_state()

func _set_vertical(value: float) -> void:
	if player and player.mod_fly_enabled:
		player.set_mod_fly_vertical(value)

func _save_point() -> void:
	if not player:
		return
	saved_point = player.global_position
	has_saved_point = true
	status.text = "Saved: %.1f, %.1f, %.1f" % [saved_point.x, saved_point.y, saved_point.z]

func _teleport_saved() -> void:
	if not player or not has_saved_point:
		status.text = "No saved point"
		return
	player.set_mod_fly(false)
	player.global_position = saved_point + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO
	status.text = "Teleported to saved point"

func _update_state() -> void:
	if not player:
		status.text = "Player unavailable"
		return
	fly_button.text = "Fly: ON" if player.mod_fly_enabled else "Fly: OFF"
	status.text = "Speed: %.1f" % player.mod_fly_speed
