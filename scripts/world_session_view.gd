extends Node3D

const SettingsRuntime = preload("res://scripts/settings_runtime.gd")

const DASHBOARD_SCENE := "res://main.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/character_select_view.tscn"

const WORLD_TO_GODOT_SCALE := 0.02
const GRID_EXTENT := 220
const GRID_STEP := 20
const MARKER_MOVE_SPEED := 14.0
const WORLD_SESSION_LAYOUT_FILE_PATH := "user://world-session-layout.cfg"
const WORLD_SESSION_LAYOUT_SELF_TEST_FILE_PATH := "user://world-session-layout-self-test.cfg"
const PANEL_DEFAULT_POSITION := Vector2(18.0, 156.0)
const PANEL_DEFAULT_SIZE := Vector2(560.0, 260.0)
const PANEL_DRAG_GRID := 10.0
const PANEL_NAMES := ["chat", "spells", "actions", "quests", "options"]

var player_marker: CharacterBody3D
var target_marker: MeshInstance3D
var camera: Camera3D
var status_label: Label
var detail_label: Label
var target_label: Label
var quest_label: Label
var session_label: Label
var panel_overlay: Control
var panel_shell: PanelContainer
var panel_title_label: Label
var panel_body: VBoxContainer
var session_panels := {}
var action_buttons: Array[Button] = []
var shortcut_slots: Array[Button] = []

var layout_file_path := WORLD_SESSION_LAYOUT_FILE_PATH
var camera_yaw := 0.0
var marker_velocity := Vector3.ZERO
var authoritative_marker_position := Vector3.ZERO
var visible_object_count := 0
var selected_target_index := -1
var target_was_pressed := false
var attack_was_pressed := false
var interact_was_pressed := false
var reset_was_pressed := false
var jump_was_pressed := false
var active_panel_name := ""
var panel_dragging_name := ""
var panel_drag_offset := Vector2.ZERO


func _ready() -> void:
	if OS.get_environment("ACORE_WORLD_SESSION_LAYOUT_SELF_TEST") == "1":
		layout_file_path = WORLD_SESSION_LAYOUT_SELF_TEST_FILE_PATH
		_delete_layout_file(layout_file_path)
	_apply_saved_keybindings()
	_build_world()
	_build_hud()
	_apply_session_context()
	if OS.get_environment("ACORE_WORLD_SESSION_LAYOUT_SELF_TEST") == "1":
		call_deferred("_run_layout_self_test")
	elif OS.get_environment("ACORE_WORLD_SESSION_KEYBIND_SELF_TEST") == "1":
		call_deferred("_run_keybind_settings_self_test")
	elif OS.get_environment("ACORE_WORLD_SESSION_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _physics_process(delta: float) -> void:
	_update_camera_input(delta)
	_update_marker_movement(delta)
	_update_key_actions()
	_update_camera()


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.72, 0.80)
	environment.ambient_light_energy = 0.85
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 36, 0)
	sun.light_energy = 1.7
	add_child(sun)

	_add_grid()
	_add_axis_label("X", Vector3(GRID_EXTENT + 14, 0, 0), Color(0.9, 0.18, 0.16))
	_add_axis_label("Y", Vector3(0, 0, -GRID_EXTENT - 14), Color(0.16, 0.62, 0.96))

	player_marker = CharacterBody3D.new()
	player_marker.name = "SessionPlayerMarker"
	add_child(player_marker)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 1.8
	capsule_shape.height = 6.0
	collision.shape = capsule_shape
	player_marker.add_child(collision)

	var marker_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.8
	capsule.height = 6.0
	marker_mesh.mesh = capsule
	marker_mesh.material_override = _material(Color(0.95, 0.73, 0.24))
	player_marker.add_child(marker_mesh)

	var label := Label3D.new()
	label.name = "CharacterLabel"
	label.position = Vector3(0, 5.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 20
	label.modulate = Color(0.96, 0.97, 0.92)
	player_marker.add_child(label)

	target_marker = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 3.1
	ring.bottom_radius = 3.1
	ring.height = 0.08
	target_marker.mesh = ring
	target_marker.material_override = _material(Color(0.24, 0.76, 0.95, 0.48))
	target_marker.position = Vector3(0, 0.04, 0)
	add_child(target_marker)

	camera = Camera3D.new()
	camera.fov = 58
	camera.current = true
	add_child(camera)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := MarginContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 14)
	layer.add_child(root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	root.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	layout.add_child(top_row)

	var health := _bar("Health", 100.0)
	health.value = 100.0
	top_row.add_child(health)
	var power := _bar("Power", 100.0)
	power.value = 100.0
	top_row.add_child(power)
	var target := _bar("Target", 100.0)
	target.value = 0.0
	top_row.add_child(target)

	status_label = _hud_label()
	layout.add_child(status_label)
	detail_label = _hud_label()
	layout.add_child(detail_label)
	target_label = _hud_label()
	layout.add_child(target_label)
	quest_label = _hud_label()
	layout.add_child(quest_label)
	session_label = _hud_label()
	layout.add_child(session_label)

	_build_panel_shell(layer)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var shortcut_grid := GridContainer.new()
	shortcut_grid.columns = 12
	shortcut_grid.add_theme_constant_override("h_separation", 6)
	shortcut_grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(shortcut_grid)
	_build_shortcut_slots(shortcut_grid)

	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 8)
	layout.add_child(nav_bar)

	_add_panel_button(nav_bar, "Chat", "chat")
	_add_panel_button(nav_bar, "Spells", "spells")
	_add_panel_button(nav_bar, "Actions", "actions")
	_add_panel_button(nav_bar, "Quests", "quests")
	_add_panel_button(nav_bar, "Options", "options")
	_add_scene_button(nav_bar, "Roster", CHARACTER_SELECT_SCENE)
	_add_scene_button(nav_bar, "Dashboard", DASHBOARD_SCENE)


func _apply_session_context() -> void:
	var context := _session_context()
	if context == null:
		_apply_session_data({}, {}, "No active session context.")
		return
	var character: Dictionary = context.selected_character
	var enter_result: Dictionary = context.last_enter_world_result
	_apply_session_data(character, enter_result, "Session loaded from login flow.")


func _apply_session_data(character: Dictionary, enter_result: Dictionary, source_text: String) -> void:
	var login: Dictionary = enter_result.get("login", {})
	var update: Dictionary = enter_result.get("update", {})
	var character_name := str(character.get("name", enter_result.get("character_name", "Unknown")))
	var map_id := int(login.get("map", character.get("map", 0)))
	var wow_x := float(login.get("x", character.get("x", 0.0)))
	var wow_y := float(login.get("y", character.get("y", 0.0)))
	var wow_z := float(login.get("z", character.get("z", 0.0)))
	var marker_position := _godot_position(wow_x, wow_y, wow_z)

	player_marker.position = marker_position
	authoritative_marker_position = marker_position
	target_marker.position = Vector3(marker_position.x, 0.04, marker_position.z)
	var name_label := player_marker.get_node_or_null("CharacterLabel")
	if name_label is Label3D:
		name_label.text = "%s\nmap %s" % [character_name, str(map_id)]

	status_label.text = "World Session"
	detail_label.text = "%s Level %s %s on map %s at %.2f, %.2f, %.2f." % [
		character_name,
		str(character.get("level", "?")),
		str(character.get("class", "")),
		str(map_id),
		wow_x,
		wow_y,
		wow_z,
	]
	visible_object_count = int(update.get("visible_object_count", 0))
	selected_target_index = -1
	_refresh_target_label()
	quest_label.text = "Quest tracker: waiting for live quest-log integration."
	session_label.text = source_text
	_update_camera()


func _update_camera_input(delta: float) -> void:
	if Input.is_action_pressed("camera_left"):
		camera_yaw += 1.8 * delta
	if Input.is_action_pressed("camera_right"):
		camera_yaw -= 1.8 * delta


func _update_marker_movement(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input.z += 1.0
	if Input.is_action_pressed("move_left"):
		input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input.x += 1.0

	var direction := Vector3.ZERO
	if input.length() > 0.0:
		var basis := Basis(Vector3.UP, camera_yaw)
		direction = (basis * input).normalized()
	marker_velocity.x = direction.x * MARKER_MOVE_SPEED
	marker_velocity.z = direction.z * MARKER_MOVE_SPEED
	player_marker.velocity = marker_velocity
	player_marker.move_and_slide()
	_sync_target_marker()


func _update_key_actions() -> void:
	var target_pressed := Input.is_action_pressed("target_next")
	if target_pressed and not target_was_pressed:
		_select_next_target()
	target_was_pressed = target_pressed

	var attack_pressed := Input.is_action_pressed("attack_primary")
	if attack_pressed and not attack_was_pressed:
		_queue_primary_action()
	attack_was_pressed = attack_pressed

	var interact_pressed := Input.is_action_pressed("interact")
	if interact_pressed and not interact_was_pressed:
		_queue_interact()
	interact_was_pressed = interact_pressed

	var reset_pressed := Input.is_action_pressed("reset_sandbox")
	if reset_pressed and not reset_was_pressed:
		_reset_marker_to_session()
	reset_was_pressed = reset_pressed

	var jump_pressed := Input.is_action_pressed("jump")
	if jump_pressed and not jump_was_pressed:
		_queue_jump()
	jump_was_pressed = jump_pressed


func _select_next_target() -> void:
	if visible_object_count <= 0:
		selected_target_index = -1
		status_label.text = "Targeting is waiting for a live visible-object snapshot."
		_refresh_target_label()
		return

	selected_target_index = (selected_target_index + 1) % visible_object_count
	status_label.text = "Target selected from the latest world-session snapshot."
	_refresh_target_label()


func _queue_primary_action() -> void:
	if selected_target_index < 0:
		status_label.text = "Primary action queued; select a visible target when live targeting is attached."
		return
	status_label.text = "Primary action queued for target %s; combat execution waits for the persistent live session." % str(selected_target_index + 1)


func _queue_interact() -> void:
	if selected_target_index < 0:
		quest_label.text = "Interaction queued; live NPC/gameobject selection is not attached yet."
		return
	quest_label.text = "Interaction queued for target %s; NPC panels will attach here after the live click bridge lands." % str(selected_target_index + 1)


func _reset_marker_to_session() -> void:
	player_marker.position = authoritative_marker_position
	player_marker.velocity = Vector3.ZERO
	marker_velocity = Vector3.ZERO
	_sync_target_marker()
	status_label.text = "Marker returned to the last server-reported position."
	_update_camera()


func _queue_jump() -> void:
	status_label.text = "Jump input received; server-synchronized vertical movement remains a live-session task."


func _refresh_target_label() -> void:
	if visible_object_count <= 0:
		target_label.text = "Visible objects: 0. Target cycling is waiting for the live object stream."
		return
	if selected_target_index < 0:
		target_label.text = "Visible objects: %s. Press the saved target key to cycle the snapshot." % str(visible_object_count)
		return
	target_label.text = "Target %s of %s selected from the latest visible-object snapshot." % [
		str(selected_target_index + 1),
		str(visible_object_count),
	]


func _sync_target_marker() -> void:
	target_marker.position = Vector3(player_marker.position.x, 0.04, player_marker.position.z)


func _update_camera() -> void:
	if camera == null or player_marker == null:
		return
	var offset := Vector3(0, 24, 44).rotated(Vector3.UP, camera_yaw)
	camera.position = player_marker.position + offset
	camera.look_at(player_marker.position + Vector3(0, 3.0, 0), Vector3.UP)


func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-GRID_EXTENT, GRID_EXTENT + 1, GRID_STEP):
		var strong := i == 0
		mesh.surface_set_color(Color(0.46, 0.50, 0.54) if strong else Color(0.24, 0.29, 0.32))
		mesh.surface_add_vertex(Vector3(i, 0, -GRID_EXTENT))
		mesh.surface_add_vertex(Vector3(i, 0, GRID_EXTENT))
		mesh.surface_add_vertex(Vector3(-GRID_EXTENT, 0, i))
		mesh.surface_add_vertex(Vector3(GRID_EXTENT, 0, i))

	mesh.surface_set_color(Color(0.9, 0.18, 0.16))
	mesh.surface_add_vertex(Vector3(-GRID_EXTENT, 0.06, 0))
	mesh.surface_add_vertex(Vector3(GRID_EXTENT, 0.06, 0))
	mesh.surface_set_color(Color(0.16, 0.62, 0.96))
	mesh.surface_add_vertex(Vector3(0, 0.08, -GRID_EXTENT))
	mesh.surface_add_vertex(Vector3(0, 0.08, GRID_EXTENT))
	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	grid.material_override = material
	add_child(grid)


func _add_axis_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _bar(label_text: String, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, 18)
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	bar.tooltip_text = label_text
	return bar


func _hud_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.92, 0.95, 0.94)
	return label


func _build_panel_shell(parent: CanvasLayer) -> void:
	panel_overlay = Control.new()
	panel_overlay.name = "SessionPanelOverlay"
	panel_overlay.anchor_right = 1.0
	panel_overlay.anchor_bottom = 1.0
	panel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel_overlay)

	for i in range(PANEL_NAMES.size()):
		_create_session_panel(PANEL_NAMES[i], i)
	_load_panel_layout()
	_activate_panel("chat")


func _create_session_panel(panel_name: String, index: int) -> void:
	var shell := PanelContainer.new()
	shell.name = "SessionPanel" + panel_name.capitalize()
	shell.visible = false
	shell.custom_minimum_size = PANEL_DEFAULT_SIZE
	shell.size = shell.custom_minimum_size
	shell.position = _default_panel_position(panel_name)
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.052, 0.058, 0.88)
	panel_style.border_color = Color(0.28, 0.34, 0.36, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	shell.add_theme_stylebox_override("panel", panel_style)
	panel_overlay.add_child(shell)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	shell.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_panel_header_gui_input.bind(panel_name))
	stack.add_child(header)

	var title_label := _panel_label(_panel_title(panel_name), 17)
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.gui_input.connect(_on_panel_header_gui_input.bind(panel_name))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(Callable(self, "_hide_session_panel").bind(panel_name))
	header.add_child(close_button)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.custom_minimum_size = Vector2(500.0, 0.0)
	stack.add_child(body)

	session_panels[panel_name] = {
		"shell": shell,
		"title": title_label,
		"body": body,
		"index": index,
	}


func _activate_panel(panel_name: String) -> bool:
	var info: Dictionary = session_panels.get(panel_name, {})
	if info.is_empty():
		return false
	panel_shell = info.get("shell", null)
	panel_title_label = info.get("title", null)
	panel_body = info.get("body", null)
	active_panel_name = panel_name
	return panel_shell != null and panel_title_label != null and panel_body != null


func _panel_shell(panel_name: String) -> PanelContainer:
	var info: Dictionary = session_panels.get(panel_name, {})
	if info.is_empty():
		return null
	return info.get("shell", null)


func _panel_title(panel_name: String) -> String:
	match panel_name:
		"chat":
			return "Chat"
		"spells":
			return "Spells"
		"actions":
			return "Actions"
		"quests":
			return "Quests"
		"options":
			return "Options"
		_:
			return "Session Panel"


func _default_panel_position(panel_name: String) -> Vector2:
	var index := PANEL_NAMES.find(panel_name)
	if index < 0:
		index = 0
	return PANEL_DEFAULT_POSITION + Vector2(index * 34.0, index * 28.0)


func _layout_section(panel_name: String) -> String:
	return "SessionPanel:" + panel_name


func _build_shortcut_slots(parent: Control) -> void:
	shortcut_slots.clear()
	_add_shortcut_slot(parent, "1", "Primary", Callable(self, "_queue_primary_action"))
	_add_shortcut_slot(parent, "2", "Interact", Callable(self, "_queue_interact"))
	_add_shortcut_slot(parent, "3", "Target", Callable(self, "_select_next_target"))
	_add_shortcut_slot(parent, "4", "Spells", Callable(self, "_show_session_panel").bind("spells"))
	_add_shortcut_slot(parent, "5", "Actions", Callable(self, "_show_session_panel").bind("actions"))
	_add_shortcut_slot(parent, "6", "Quests", Callable(self, "_show_session_panel").bind("quests"))
	_add_shortcut_slot(parent, "7", "Chat", Callable(self, "_show_session_panel").bind("chat"))
	_add_shortcut_slot(parent, "8", "Options", Callable(self, "_show_session_panel").bind("options"))
	_add_shortcut_slot(parent, "9", "Reset", Callable(self, "_reset_marker_to_session"))
	_add_shortcut_slot(parent, "0", "Jump", Callable(self, "_queue_jump"))
	_add_shortcut_slot(parent, "-", "Bag", Callable(self, "_show_session_panel").bind("actions"))
	_add_shortcut_slot(parent, "=", "Map", Callable(self, "_show_session_panel").bind("quests"))


func _add_shortcut_slot(parent: Control, key_text: String, label_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [key_text, label_text]
	button.tooltip_text = label_text
	button.custom_minimum_size = Vector2(72, 50)
	button.pressed.connect(action)
	parent.add_child(button)
	shortcut_slots.append(button)


func _add_panel_button(parent: Control, label_text: String, panel_name: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104, 36)
	button.pressed.connect(func(): _show_session_panel(panel_name))
	parent.add_child(button)
	action_buttons.append(button)


func _add_scene_button(parent: Control, label_text: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104, 36)
	button.pressed.connect(func(): _open_scene(scene_path))
	parent.add_child(button)
	action_buttons.append(button)


func _show_session_panel(panel_name: String) -> void:
	if not _activate_panel(panel_name):
		return
	_clear_panel_body()
	panel_shell.visible = true
	panel_shell.move_to_front()
	match panel_name:
		"chat":
			_build_chat_panel()
		"spells":
			_build_spells_panel()
		"actions":
			_build_actions_panel()
		"quests":
			_build_quests_panel()
		"options":
			_build_options_panel()
		_:
			panel_title_label.text = "Session Panel"
			panel_body.add_child(_panel_label("No panel is registered for " + panel_name + ".", 14))
	panel_shell.size = PANEL_DEFAULT_SIZE
	_set_panel_position(panel_name, panel_shell.position)


func _hide_session_panel(panel_name: String = "") -> void:
	var target_name := active_panel_name if panel_name.is_empty() else panel_name
	var shell := _panel_shell(target_name)
	if shell != null:
		shell.visible = false


func _on_panel_header_gui_input(event: InputEvent, panel_name: String) -> void:
	var shell := _panel_shell(panel_name)
	if shell == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			panel_dragging_name = panel_name
			panel_drag_offset = shell.get_global_mouse_position() - shell.global_position
			shell.z_index = 50
			_activate_panel(panel_name)
			shell.move_to_front()
		elif panel_dragging_name == panel_name:
			panel_dragging_name = ""
			shell.z_index = 0
			_set_panel_position(panel_name, shell.position, true)
			_save_panel_layout()
	elif event is InputEventMouseMotion and panel_dragging_name == panel_name:
		var next_position := shell.get_global_mouse_position() - panel_drag_offset
		_set_panel_position(panel_name, next_position)


func _set_panel_position(panel_name: String, next_position: Vector2, snap_to_grid: bool = false) -> void:
	var shell := _panel_shell(panel_name)
	if shell == null:
		return
	var target := next_position
	if snap_to_grid:
		target = Vector2(snapped(target.x, PANEL_DRAG_GRID), snapped(target.y, PANEL_DRAG_GRID))
	shell.position = _clamp_panel_position(panel_name, target)


func _clamp_panel_position(panel_name: String, next_position: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < PANEL_DEFAULT_SIZE.x + 120.0 or viewport_size.y < PANEL_DEFAULT_SIZE.y + 120.0:
		viewport_size = Vector2(1280.0, 720.0)
	var panel_size := PANEL_DEFAULT_SIZE
	var max_x: float = max(0.0, viewport_size.x - panel_size.x - 12.0)
	var max_y: float = max(0.0, viewport_size.y - panel_size.y - 12.0)
	return Vector2(clamp(next_position.x, 0.0, max_x), clamp(next_position.y, 0.0, max_y))


func _save_panel_layout() -> Error:
	var config := ConfigFile.new()
	for panel_name in PANEL_NAMES:
		var shell := _panel_shell(panel_name)
		if shell == null:
			continue
		var section := _layout_section(panel_name)
		config.set_value(section, "position", shell.position)
		config.set_value(section, "size", shell.size)
	var error := config.save(layout_file_path)
	if error == OK:
		session_label.text = "HUD layout saved."
	else:
		session_label.text = "HUD layout save failed."
	return error


func _load_panel_layout() -> void:
	var config := ConfigFile.new()
	if config.load(layout_file_path) != OK:
		for panel_name in PANEL_NAMES:
			_set_panel_position(panel_name, _default_panel_position(panel_name))
		return

	for panel_name in PANEL_NAMES:
		var shell := _panel_shell(panel_name)
		if shell == null:
			continue
		var section := _layout_section(panel_name)
		if config.has_section_key(section, "size"):
			var stored_size = config.get_value(section, "size")
			if typeof(stored_size) == TYPE_VECTOR2:
				shell.size = stored_size
		if config.has_section_key(section, "position"):
			var stored_position = config.get_value(section, "position")
			if typeof(stored_position) == TYPE_VECTOR2:
				_set_panel_position(panel_name, stored_position)
		else:
			_set_panel_position(panel_name, _default_panel_position(panel_name))


func _reset_panel_layout() -> void:
	_delete_layout_file(layout_file_path)
	for panel_name in PANEL_NAMES:
		var shell := _panel_shell(panel_name)
		if shell != null:
			shell.size = PANEL_DEFAULT_SIZE
		_set_panel_position(panel_name, _default_panel_position(panel_name))
	session_label.text = "HUD layout reset."


func _delete_layout_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _clear_panel_body() -> void:
	for child in panel_body.get_children():
		child.queue_free()


func _build_chat_panel() -> void:
	panel_title_label.text = "Chat"
	panel_body.add_child(_panel_label("Say", 13))
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	panel_body.add_child(input_row)

	var input := LineEdit.new()
	input.placeholder_text = "Message"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(input)

	var send_button := Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(86, 32)
	send_button.pressed.connect(func(): _queue_chat_line(input.text))
	input.text_submitted.connect(func(message: String): _queue_chat_line(message))
	input_row.add_child(send_button)

	panel_body.add_child(_panel_label("Channel state: local queue.", 13))


func _build_spells_panel() -> void:
	panel_title_label.text = "Spells"
	panel_body.add_child(_panel_label("Known spells: no session rows yet.", 13))
	panel_body.add_child(_panel_label("Active inputs: primary action, target next, interact, and jump.", 13))


func _build_actions_panel() -> void:
	panel_title_label.text = "Actions"
	var rows := [
		"Target: " + ("none" if selected_target_index < 0 else str(selected_target_index + 1)),
		"Visible objects: " + str(visible_object_count),
		"Primary: queued in HUD.",
		"Interact: queued in HUD.",
		"Reset: returns the marker to the last server-reported position.",
	]
	for row in rows:
		panel_body.add_child(_panel_label(row, 13))


func _build_quests_panel() -> void:
	panel_title_label.text = "Quests"
	panel_body.add_child(_panel_label(quest_label.text, 13))
	panel_body.add_child(_panel_label("Tracked objective rows: none in this session yet.", 13))


func _build_options_panel() -> void:
	panel_title_label.text = "Options"
	var settings := SettingsRuntime.load_settings()
	var keybindings: Dictionary = settings.get("keybindings", {})
	var key_lines := [
		"Move forward: " + _key_name(int(keybindings.get("move_forward", KEY_W))),
		"Move backward: " + _key_name(int(keybindings.get("move_backward", KEY_S))),
		"Move left: " + _key_name(int(keybindings.get("move_left", KEY_A))),
		"Move right: " + _key_name(int(keybindings.get("move_right", KEY_D))),
		"Camera left/right: %s / %s" % [
			_key_name(int(keybindings.get("camera_left", KEY_Q))),
			_key_name(int(keybindings.get("camera_right", KEY_E))),
		],
		"Target/action/interact: %s / %s / %s" % [
			_key_name(int(keybindings.get("target_next", KEY_TAB))),
			_key_name(int(keybindings.get("attack_primary", KEY_1))),
			_key_name(int(keybindings.get("interact", KEY_F))),
		],
	]
	for line in key_lines:
		panel_body.add_child(_panel_label(line, 13))

	var reset_button := Button.new()
	reset_button.text = "Reset HUD"
	reset_button.custom_minimum_size = Vector2(120, 32)
	reset_button.pressed.connect(_reset_panel_layout)
	panel_body.add_child(reset_button)


func _queue_chat_line(message: String) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		status_label.text = "Chat input is empty."
		return
	status_label.text = "Chat queued locally: " + trimmed.left(48)


func _panel_label(text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500.0, 0.0)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(0.91, 0.94, 0.92)
	return label


func _key_name(keycode: int) -> String:
	var key_name := OS.get_keycode_string(keycode)
	return key_name if not key_name.is_empty() else str(keycode)


func _open_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK and status_label != null:
		status_label.text = "Could not open " + scene_path


func _godot_position(wow_x: float, wow_y: float, wow_z: float) -> Vector3:
	return Vector3(wow_x * WORLD_TO_GODOT_SCALE, wow_z * WORLD_TO_GODOT_SCALE, -wow_y * WORLD_TO_GODOT_SCALE)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material


func _session_context() -> Node:
	return get_node_or_null("/root/SessionContext")


func _apply_saved_keybindings(path: String = SettingsRuntime.SETTINGS_FILE_PATH) -> void:
	SettingsRuntime.apply_keybindings(SettingsRuntime.load_settings(path))


func _input_action_has_key(action: String, keycode: int) -> bool:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _run_keybind_settings_self_test() -> void:
	var test_settings := SettingsRuntime.default_settings()
	test_settings["keybindings"]["move_forward"] = KEY_UP
	test_settings["keybindings"]["camera_left"] = KEY_LEFT
	test_settings["keybindings"]["target_next"] = KEY_T
	test_settings["keybindings"]["attack_primary"] = KEY_2
	test_settings["keybindings"]["interact"] = KEY_G
	test_settings["keybindings"]["reset_sandbox"] = KEY_BACKSPACE
	test_settings["keybindings"]["jump"] = KEY_SPACE
	var save_error := SettingsRuntime.save_settings(test_settings, SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	if save_error != OK:
		push_error("WORLD_SESSION_KEYBIND_SETTINGS_SELF_TEST_FAILED: could not save temporary settings")
		get_tree().quit(1)
		return

	_apply_saved_keybindings(SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	var bindings_ok := (
		_input_action_has_key("move_forward", KEY_UP)
		and _input_action_has_key("camera_left", KEY_LEFT)
		and _input_action_has_key("target_next", KEY_T)
		and _input_action_has_key("attack_primary", KEY_2)
		and _input_action_has_key("interact", KEY_G)
		and _input_action_has_key("reset_sandbox", KEY_BACKSPACE)
		and _input_action_has_key("jump", KEY_SPACE)
	)
	SettingsRuntime.delete_settings_file(SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	if not bindings_ok:
		push_error("WORLD_SESSION_KEYBIND_SETTINGS_SELF_TEST_FAILED: saved bindings were not applied")
		get_tree().quit(1)
		return

	print("WORLD_SESSION_KEYBIND_SETTINGS_SELF_TEST_OK move_forward=KEY_UP camera_left=KEY_LEFT target_next=KEY_T")
	get_tree().quit(0)


func _run_layout_self_test() -> void:
	_show_session_panel("options")
	_show_session_panel("actions")
	var options_shell := _panel_shell("options")
	var actions_shell := _panel_shell("actions")
	options_shell.size = PANEL_DEFAULT_SIZE
	actions_shell.size = PANEL_DEFAULT_SIZE
	_set_panel_position("options", Vector2(267.0, 318.0), true)
	_set_panel_position("actions", Vector2(381.0, 246.0), true)
	var options_position := _clamp_panel_position("options", Vector2(270.0, 320.0))
	var actions_position := _clamp_panel_position("actions", Vector2(380.0, 250.0))
	var snap_ok := (
		options_shell.position.distance_to(options_position) < 0.01
		and actions_shell.position.distance_to(actions_position) < 0.01
	)
	var save_ok := _save_panel_layout() == OK

	options_shell.position = Vector2.ZERO
	actions_shell.position = Vector2.ZERO
	_load_panel_layout()
	var load_ok := (
		options_shell.position.distance_to(options_position) < 0.01
		and actions_shell.position.distance_to(actions_position) < 0.01
	)

	_reset_panel_layout()
	var options_reset_position := _clamp_panel_position("options", _default_panel_position("options"))
	var actions_reset_position := _clamp_panel_position("actions", _default_panel_position("actions"))
	var reset_ok := (
		options_shell.position.distance_to(options_reset_position) < 0.01
		and actions_shell.position.distance_to(actions_reset_position) < 0.01
	)
	var cleanup_ok := not FileAccess.file_exists(ProjectSettings.globalize_path(layout_file_path))

	if snap_ok and save_ok and load_ok and reset_ok and cleanup_ok:
		print("WORLD_SESSION_LAYOUT_SELF_TEST_OK options=(%.1f,%.1f) actions=(%.1f,%.1f) reset=true" % [
			options_position.x,
			options_position.y,
			actions_position.x,
			actions_position.y,
		])
		get_tree().quit(0)
		return

	_delete_layout_file(layout_file_path)
	push_error("WORLD_SESSION_LAYOUT_SELF_TEST_FAILED snap_ok=%s save_ok=%s load_ok=%s reset_ok=%s cleanup_ok=%s" % [
		str(snap_ok),
		str(save_ok),
		str(load_ok),
		str(reset_ok),
		str(cleanup_ok),
	])
	get_tree().quit(1)


func _run_self_test() -> void:
	var synthetic_character := {
		"name": "Codexstage",
		"level": 80,
		"class": "Warrior",
		"map": 0,
		"x": -8949.95,
		"y": -132.49,
		"z": 83.53,
	}
	var synthetic_result := {
		"ok": true,
		"character_name": "Codexstage",
		"login": {
			"map": 0,
			"x": -8949.95,
			"y": -132.49,
			"z": 83.53,
			"orientation": 0.0,
		},
		"update": {
			"visible_object_count": 3,
		},
	}

	var no_target_result := synthetic_result.duplicate(true)
	no_target_result["update"]["visible_object_count"] = 0
	_apply_session_data(synthetic_character, no_target_result, "Synthetic no-target world-session self-test.")
	_select_next_target()
	var no_target_key_ok := selected_target_index == -1 and target_label.text.find("Visible objects: 0") != -1
	_queue_primary_action()
	var no_target_action_ok := status_label.text.find("select a visible target") != -1
	_queue_interact()
	var no_target_interact_ok := quest_label.text.find("not attached yet") != -1

	_apply_session_data(synthetic_character, synthetic_result, "Synthetic world-session self-test.")

	_select_next_target()
	var target_key_ok := target_label.text.find("Target 1 of 3") != -1
	_queue_primary_action()
	var action_key_ok := status_label.text.find("Primary action queued for target 1") != -1
	_queue_interact()
	var interact_key_ok := quest_label.text.find("Interaction queued for target 1") != -1
	player_marker.position += Vector3(8.0, 0.0, 0.0)
	_reset_marker_to_session()
	_show_session_panel("chat")
	var chat_shell := _panel_shell("chat")
	var chat_title: Label = session_panels.get("chat", {}).get("title", null)
	var chat_panel_ok := chat_shell != null and chat_shell.visible and chat_title != null and chat_title.text == "Chat"
	_show_session_panel("actions")
	var actions_shell := _panel_shell("actions")
	var actions_title: Label = session_panels.get("actions", {}).get("title", null)
	var actions_panel_ok := actions_shell != null and actions_shell.visible and actions_title != null and actions_title.text == "Actions"
	_show_session_panel("spells")
	var spells_shell := _panel_shell("spells")
	var spells_title: Label = session_panels.get("spells", {}).get("title", null)
	var spells_panel_ok := spells_shell != null and spells_shell.visible and spells_title != null and spells_title.text == "Spells"
	_show_session_panel("quests")
	var quests_shell := _panel_shell("quests")
	var quests_title: Label = session_panels.get("quests", {}).get("title", null)
	var quests_panel_ok := quests_shell != null and quests_shell.visible and quests_title != null and quests_title.text == "Quests"
	_show_session_panel("options")
	var options_shell := _panel_shell("options")
	var options_title: Label = session_panels.get("options", {}).get("title", null)
	var options_panel_ok := options_shell != null and options_shell.visible and options_title != null and options_title.text == "Options"
	var multi_panel_ok := chat_shell != null and actions_shell != null and chat_shell != actions_shell and chat_shell.visible and actions_shell.visible
	for panel_name in PANEL_NAMES:
		_hide_session_panel(panel_name)

	var marker_ok := player_marker != null and player_marker.position.distance_to(_godot_position(-8949.95, -132.49, 83.53)) < 0.01
	var hud_ok := detail_label.text.find("Codexstage") != -1 and visible_object_count == 3
	var actions_ok := action_buttons.size() == 7
	var shortcut_ok := shortcut_slots.size() == 12
	var input_ok := no_target_key_ok and no_target_action_ok and no_target_interact_ok and target_key_ok and action_key_ok and interact_key_ok
	var panel_ok := chat_panel_ok and actions_panel_ok and spells_panel_ok and quests_panel_ok and options_panel_ok and multi_panel_ok
	if marker_ok and hud_ok and actions_ok and shortcut_ok and input_ok and panel_ok:
		print("WORLD_SESSION_SELF_TEST_OK character=Codexstage map=0 actions=%s shortcuts=%s input=true panels=true marker=(%.2f,%.2f,%.2f)" % [
			str(action_buttons.size()),
			str(shortcut_slots.size()),
			player_marker.position.x,
			player_marker.position.y,
			player_marker.position.z,
		])
		get_tree().quit(0)
		return

	push_error("WORLD_SESSION_SELF_TEST_FAILED marker_ok=%s hud_ok=%s actions_ok=%s shortcut_ok=%s input_ok=%s panel_ok=%s" % [
		str(marker_ok),
		str(hud_ok),
		str(actions_ok),
		str(shortcut_ok),
		str(input_ok),
		str(panel_ok),
	])
	get_tree().quit(1)
