extends Node3D

const DASHBOARD_SCENE := "res://main.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/character_select_view.tscn"
const CHAT_SCENE := "res://scenes/stage16_chat_view.tscn"
const SPELLBOOK_SCENE := "res://scenes/stage16_spellbook_view.tscn"
const ACTION_BAR_SCENE := "res://scenes/stage16_action_bar_view.tscn"
const QUEST_SCENE := "res://scenes/quest_view.tscn"
const SETTINGS_SCENE := "res://scenes/settings_view.tscn"

const WORLD_TO_GODOT_SCALE := 0.02
const GRID_EXTENT := 220
const GRID_STEP := 20

var player_marker: CharacterBody3D
var target_marker: MeshInstance3D
var camera: Camera3D
var status_label: Label
var detail_label: Label
var target_label: Label
var quest_label: Label
var session_label: Label
var action_buttons: Array[Button] = []

var camera_yaw := 0.0
var marker_velocity := Vector3.ZERO


func _ready() -> void:
	_build_world()
	_build_hud()
	_apply_session_context()
	if OS.get_environment("ACORE_WORLD_SESSION_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _physics_process(delta: float) -> void:
	_update_camera_input(delta)
	_update_marker_movement(delta)
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

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 8)
	layout.add_child(action_bar)

	_add_action_button(action_bar, "Chat", CHAT_SCENE)
	_add_action_button(action_bar, "Spells", SPELLBOOK_SCENE)
	_add_action_button(action_bar, "Actions", ACTION_BAR_SCENE)
	_add_action_button(action_bar, "Quests", QUEST_SCENE)
	_add_action_button(action_bar, "Options", SETTINGS_SCENE)
	_add_action_button(action_bar, "Roster", CHARACTER_SELECT_SCENE)
	_add_action_button(action_bar, "Dashboard", DASHBOARD_SCENE)


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
	var visible_count := int(update.get("visible_object_count", 0))
	target_label.text = "Visible objects: %s. Use the linked panels for chat, spells, action bars, quests, and options." % str(visible_count)
	quest_label.text = "Quest tracker: waiting for live quest-log integration."
	session_label.text = source_text
	_update_camera()


func _update_camera_input(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		camera_yaw += 1.8 * delta
	if Input.is_action_pressed("ui_right"):
		camera_yaw -= 1.8 * delta


func _update_marker_movement(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		direction.z -= 1.0
	if Input.is_action_pressed("ui_down"):
		direction.z += 1.0
	if direction.length() > 0.0:
		direction = direction.normalized().rotated(Vector3.UP, camera_yaw)
	marker_velocity.x = direction.x * 14.0
	marker_velocity.z = direction.z * 14.0
	player_marker.velocity = marker_velocity
	player_marker.move_and_slide()
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


func _add_action_button(parent: Control, label_text: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104, 36)
	button.pressed.connect(func(): _open_scene(scene_path))
	parent.add_child(button)
	action_buttons.append(button)


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
	_apply_session_data(synthetic_character, synthetic_result, "Synthetic world-session self-test.")

	var marker_ok := player_marker != null and player_marker.position.distance_to(_godot_position(-8949.95, -132.49, 83.53)) < 0.01
	var hud_ok := detail_label.text.find("Codexstage") != -1 and target_label.text.find("Visible objects: 3") != -1
	var actions_ok := action_buttons.size() == 7
	if marker_ok and hud_ok and actions_ok:
		print("WORLD_SESSION_SELF_TEST_OK character=Codexstage map=0 actions=%s marker=(%.2f,%.2f,%.2f)" % [
			str(action_buttons.size()),
			player_marker.position.x,
			player_marker.position.y,
			player_marker.position.z,
		])
		get_tree().quit(0)
		return

	push_error("WORLD_SESSION_SELF_TEST_FAILED marker_ok=%s hud_ok=%s actions_ok=%s" % [
		str(marker_ok),
		str(hud_ok),
		str(actions_ok),
	])
	get_tree().quit(1)
