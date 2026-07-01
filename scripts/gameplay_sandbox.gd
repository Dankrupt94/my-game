extends Node3D

const SettingsRuntime = preload("res://scripts/settings_runtime.gd")

const MOVE_SPEED := 6.0
const GRAVITY := 18.0
const CAMERA_DISTANCE := 8.0
const CAMERA_HEIGHT := 4.6
const ATTACK_RANGE := 3.2
const INTERACT_RANGE := 3.0
const RESOURCE_MAX := 100.0
const PLAYER_HEALTH_MAX := 100.0
const ENEMY_HEALTH_MAX := 100.0
const BRIDGE_BASE_URL := "http://127.0.0.1:8765"
const SAVE_PATH := "res://local_runtime/sandbox-state.json"

var player_body: CharacterBody3D
var camera: Camera3D
var npc: Node3D
var enemy: Node3D
var data_spawn_root: Node3D
var target_marker: MeshInstance3D
var status_label: Label
var target_label: Label
var quest_label: Label
var data_label: Label
var inventory_label: Label
var health_bar: ProgressBar
var resource_bar: ProgressBar
var enemy_bar: ProgressBar
var strike_button: Button
var talk_button: Button

var camera_yaw := 0.0
var player_health := PLAYER_HEALTH_MAX
var player_resource := RESOURCE_MAX
var enemy_health := ENEMY_HEALTH_MAX
var quest_started := false
var quest_complete := false
var selected_index := -1
var selectable_targets: Array[Node3D] = []
var enemy_pulse_timer := 0.0
var tab_was_pressed := false
var attack_was_pressed := false
var interact_was_pressed := false
var reset_was_pressed := false
var pending_data_requests := 0
var data_records := {}
var spawned_data_nodes: Array[Node3D] = []
var loaded_inventory := PackedStringArray()


func _ready() -> void:
	_apply_saved_keybindings()
	if OS.get_environment("ACORE_SANDBOX_KEYBIND_SETTINGS_SELF_TEST") == "1":
		set_physics_process(false)
		_run_keybind_settings_self_test()
		return
	_build_world()
	_build_ui()
	selectable_targets = [npc, enemy]
	_select_target(0)
	_update_ui("Sandbox ready.")
	if OS.get_environment("ACORE_SANDBOX_SELF_TEST") == "1":
		_run_self_test()
		return
	if OS.get_environment("ACORE_SANDBOX_PERSISTENCE_SELF_TEST") == "1":
		_run_persistence_self_test()
		return
	_load_bridge_data()


func _physics_process(delta: float) -> void:
	_update_camera_input(delta)
	_update_player_movement(delta)
	_update_key_actions()
	_update_enemy_pressure(delta)
	_regenerate_resource(delta)
	_update_camera()
	_update_target_marker()
	_update_ui()


func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.14, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.63, 0.68)
	environment.ambient_light_energy = 0.9
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_energy = 2.1
	add_child(sun)

	_add_floor()
	_add_obstacles()
	player_body = _create_actor("Player", Vector3(0, 1.0, 4.0), Color(0.28, 0.67, 0.93), true)
	npc = _create_actor("Bridge Mentor", Vector3(-5.5, 1.0, -2.5), Color(0.45, 0.84, 0.58), false)
	enemy = _create_actor("Training Echo", Vector3(5.0, 1.0, -3.0), Color(0.95, 0.35, 0.28), false)
	data_spawn_root = Node3D.new()
	data_spawn_root.name = "AzerothCoreDataPlaceholders"
	add_child(data_spawn_root)
	target_marker = _create_target_marker()

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_update_camera()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "SandboxFloor"
	add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(34, 0.25, 34)
	floor_mesh.mesh = box
	floor_mesh.material_override = _material(Color(0.18, 0.23, 0.20))
	floor_body.add_child(floor_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	floor_body.add_child(collision)


func _add_obstacles() -> void:
	for data in [
		{"position": Vector3(-2.0, 0.5, -5.5), "size": Vector3(3.0, 1.0, 1.2), "color": Color(0.32, 0.39, 0.42)},
		{"position": Vector3(3.0, 0.5, 2.0), "size": Vector3(1.4, 1.0, 3.4), "color": Color(0.40, 0.36, 0.30)},
		{"position": Vector3(-6.0, 0.5, 4.5), "size": Vector3(2.2, 1.0, 2.2), "color": Color(0.26, 0.31, 0.36)},
	]:
		var body := StaticBody3D.new()
		body.position = data["position"]
		add_child(body)

		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = data["size"]
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _material(data["color"])
		body.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = data["size"]
		collision.shape = shape
		body.add_child(collision)


func _create_actor(actor_name: String, actor_position: Vector3, color: Color, controllable: bool, parent: Node = null) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = actor_name
	body.position = actor_position
	if parent == null:
		add_child(body)
	else:
		parent.add_child(body)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.45
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var label := Label3D.new()
	label.text = actor_name
	label.position = Vector3(0, 1.55, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.92, 0.95, 0.94)
	body.add_child(label)

	if controllable:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := BoxMesh.new()
		shoulder_mesh.size = Vector3(1.0, 0.2, 0.25)
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(0, 0.35, -0.05)
		shoulder.material_override = _material(Color(0.10, 0.20, 0.28))
		body.add_child(shoulder)

	return body


func _create_target_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 0.9
	mesh.height = 0.05
	marker.mesh = mesh
	marker.material_override = _material(Color(1.0, 0.82, 0.24, 0.72))
	marker.visible = false
	add_child(marker)
	return marker


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := MarginContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_bottom", 16)
	layer.add_child(root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	root.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	layout.add_child(top_row)

	health_bar = _bar("Health", PLAYER_HEALTH_MAX)
	top_row.add_child(health_bar)
	resource_bar = _bar("Focus", RESOURCE_MAX)
	top_row.add_child(resource_bar)
	enemy_bar = _bar("Target", ENEMY_HEALTH_MAX)
	top_row.add_child(enemy_bar)

	target_label = _hud_label()
	layout.add_child(target_label)
	quest_label = _hud_label()
	layout.add_child(quest_label)
	status_label = _hud_label()
	layout.add_child(status_label)
	data_label = _hud_label()
	layout.add_child(data_label)
	inventory_label = _hud_label()
	layout.add_child(inventory_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 8)
	layout.add_child(action_bar)

	var target_button := _action_button("Target", Callable(self, "_select_next_target"))
	action_bar.add_child(target_button)
	strike_button = _action_button("Strike", Callable(self, "_try_attack"))
	action_bar.add_child(strike_button)
	talk_button = _action_button("Talk", Callable(self, "_try_interact"))
	action_bar.add_child(talk_button)
	action_bar.add_child(_action_button("Reset", Callable(self, "_reset_sandbox")))
	action_bar.add_child(_action_button("Save", Callable(self, "_save_state")))
	action_bar.add_child(_action_button("Load", Callable(self, "_load_state")))
	action_bar.add_child(_action_button("Reload", Callable(self, "_logout_login_reload")))
	action_bar.add_child(_action_button("Dashboard", Callable(self, "_return_to_dashboard")))


func _update_camera_input(delta: float) -> void:
	if Input.is_action_pressed("camera_left"):
		camera_yaw += 1.9 * delta
	if Input.is_action_pressed("camera_right"):
		camera_yaw -= 1.9 * delta


func _update_player_movement(delta: float) -> void:
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

	player_body.velocity.x = direction.x * MOVE_SPEED
	player_body.velocity.z = direction.z * MOVE_SPEED
	if player_body.is_on_floor():
		player_body.velocity.y = 0.0
	else:
		player_body.velocity.y -= GRAVITY * delta

	player_body.move_and_slide()
	if direction.length() > 0.01:
		player_body.look_at(player_body.global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)


func _update_key_actions() -> void:
	var tab_pressed := Input.is_action_pressed("target_next")
	if tab_pressed and not tab_was_pressed:
		_select_next_target()
	tab_was_pressed = tab_pressed

	var attack_pressed := Input.is_action_pressed("attack_primary")
	if attack_pressed and not attack_was_pressed:
		_try_attack()
	attack_was_pressed = attack_pressed

	var interact_pressed := Input.is_action_pressed("interact")
	if interact_pressed and not interact_was_pressed:
		_try_interact()
	interact_was_pressed = interact_pressed

	var reset_pressed := Input.is_action_pressed("reset_sandbox")
	if reset_pressed and not reset_was_pressed:
		_reset_sandbox()
	reset_was_pressed = reset_pressed


func _apply_saved_keybindings(path: String = SettingsRuntime.SETTINGS_FILE_PATH) -> void:
	SettingsRuntime.apply_keybindings(SettingsRuntime.load_settings(path))


func _run_keybind_settings_self_test() -> void:
	var test_settings := SettingsRuntime.default_settings()
	test_settings["keybindings"]["move_forward"] = KEY_UP
	var save_error := SettingsRuntime.save_settings(test_settings, SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	if save_error != OK:
		push_error("SANDBOX_KEYBIND_SETTINGS_SELF_TEST_FAILED: could not save temporary settings")
		get_tree().quit(1)
		return
	_apply_saved_keybindings(SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	var events := InputMap.action_get_events("move_forward")
	var matched := false
	for event in events:
		if event is InputEventKey and event.physical_keycode == KEY_UP:
			matched = true
			break
	SettingsRuntime.delete_settings_file(SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	if not matched:
		push_error("SANDBOX_KEYBIND_SETTINGS_SELF_TEST_FAILED: move_forward did not use saved keybinding")
		get_tree().quit(1)
		return
	print("SANDBOX_KEYBIND_SETTINGS_SELF_TEST_OK move_forward=KEY_UP")
	get_tree().quit(0)


func _update_enemy_pressure(delta: float) -> void:
	if enemy_health <= 0.0 or player_health <= 0.0:
		return

	enemy_pulse_timer -= delta
	if enemy_pulse_timer > 0.0:
		return

	if player_body.global_position.distance_to(enemy.global_position) <= 2.35:
		player_health = max(0.0, player_health - 6.0)
		enemy_pulse_timer = 1.1
		if player_health <= 0.0:
			_update_ui("Training reset needed.")
		else:
			_update_ui("The echo pushes back.")


func _regenerate_resource(delta: float) -> void:
	player_resource = min(RESOURCE_MAX, player_resource + 14.0 * delta)


func _update_camera() -> void:
	var target := player_body.global_position + Vector3(0, 1.05, 0)
	var offset := Basis(Vector3.UP, camera_yaw) * Vector3(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)


func _update_target_marker() -> void:
	var target := _current_target()
	if target == null:
		target_marker.visible = false
		return

	target_marker.visible = true
	target_marker.global_position = target.global_position + Vector3(0, 0.07, 0)


func _select_next_target() -> void:
	_select_target(selected_index + 1)


func _select_target(index: int) -> void:
	if selectable_targets.is_empty():
		selected_index = -1
		return
	selected_index = wrapi(index, 0, selectable_targets.size())
	_update_ui("Target selected.")


func _current_target() -> Node3D:
	if selected_index < 0 or selected_index >= selectable_targets.size():
		return null
	return selectable_targets[selected_index]


func _try_attack() -> void:
	var target := _current_target()
	if target != enemy:
		_update_ui("No enemy targeted.")
		return
	if enemy_health <= 0.0:
		_update_ui("Target already down.")
		return
	if player_body.global_position.distance_to(enemy.global_position) > ATTACK_RANGE:
		_update_ui("Target out of range.")
		return
	if player_resource < 15.0:
		_update_ui("Not enough focus.")
		return

	player_resource -= 15.0
	enemy_health = max(0.0, enemy_health - 22.0)
	if enemy_health <= 0.0:
		if quest_started:
			quest_complete = true
		enemy.visible = false
		_update_ui("Training echo defeated.")
	else:
		_update_ui("Strike landed.")


func _try_interact() -> void:
	var target := _current_target()
	if target != npc:
		_update_ui("No one to talk to.")
		return
	if player_body.global_position.distance_to(npc.global_position) > INTERACT_RANGE:
		_update_ui("Move closer.")
		return

	quest_started = true
	if enemy_health <= 0.0:
		quest_complete = true
	if quest_complete:
		_update_ui("Task complete.")
	else:
		_update_ui("Task accepted.")


func _reset_sandbox() -> void:
	player_body.global_position = Vector3(0, 1.0, 4.0)
	player_body.velocity = Vector3.ZERO
	player_health = PLAYER_HEALTH_MAX
	player_resource = RESOURCE_MAX
	enemy_health = ENEMY_HEALTH_MAX
	enemy.visible = true
	quest_started = false
	quest_complete = false
	loaded_inventory.clear()
	_select_target(0)
	_update_ui("Sandbox reset.")


func _load_bridge_data() -> void:
	data_records = {}
	pending_data_requests = 0
	for request in [
		{"view": "characters", "search": "", "limit": 3},
		{"view": "creatures", "search": "wolf", "limit": 3},
		{"view": "quests", "search": "wolf", "limit": 3},
		{"view": "items", "search": "sword", "limit": 3},
	]:
		_request_data_view(str(request["view"]), str(request["search"]), int(request["limit"]))


func _request_data_view(view: String, search: String, limit: int) -> void:
	pending_data_requests += 1
	var request := HTTPRequest.new()
	request.timeout = 20
	add_child(request)
	request.request_completed.connect(Callable(self, "_on_data_request_completed").bind(view, request))
	var path := "/data?view=" + view.uri_encode() + "&search=" + search.uri_encode() + "&limit=" + str(limit)
	var error := request.request(BRIDGE_BASE_URL + path)
	if error != OK:
		request.queue_free()
		pending_data_requests -= 1
		_note_data_error(view, "request could not start")


func _on_data_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	view: String,
	request: HTTPRequest
) -> void:
	var body_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(body_text)
	var payload: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var request_ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 and bool(payload.get("ok", false))
	if request_ok:
		var rows := _rows_from_data_payload(payload, view)
		data_records[view] = rows
		if view == "creatures":
			_spawn_data_creatures(rows)
		_update_data_ui()
	else:
		_note_data_error(view, "bridge data request failed")

	pending_data_requests -= 1
	request.queue_free()
	_maybe_finish_data_self_test()


func _rows_from_data_payload(payload: Dictionary, view: String) -> Array:
	var report: Dictionary = payload.get("report", {})
	var views: Dictionary = report.get("views", {})
	var view_payload: Dictionary = views.get(view, {})
	var rows: Array = view_payload.get("rows", [])
	return rows


func _spawn_data_creatures(rows: Array) -> void:
	for child in data_spawn_root.get_children():
		child.queue_free()
	spawned_data_nodes.clear()

	var count: int = min(rows.size(), 3)
	for index in range(count):
		var row: Dictionary = rows[index]
		var level: int = int(str(row.get("maxlevel", "1")))
		var color: Color = Color(0.82, 0.58 + min(level, 20) * 0.01, 0.28)
		var actor := _create_actor(
			str(row.get("name", "Data Creature")),
			Vector3(-6.5 + index * 3.2, 1.0, -8.2),
			color,
			false,
			data_spawn_root
		)
		actor.set_meta("acore_entry", str(row.get("entry", "")))
		actor.set_meta("acore_level", str(row.get("minlevel", "?")) + "-" + str(row.get("maxlevel", "?")))
		spawned_data_nodes.append(actor)

	selectable_targets = [npc, enemy]
	selectable_targets.append_array(spawned_data_nodes)


func _update_data_ui() -> void:
	if data_label == null:
		return

	var characters: Array = data_records.get("characters", [])
	var quests: Array = data_records.get("quests", [])
	var creatures: Array = data_records.get("creatures", [])

	var character_text := _record_list(characters, "name", "No characters")
	var quest_text := _record_list(quests, "title", "No quests")
	var item_text := _inventory_text()
	data_label.text = "Characters: " + character_text + " | Quest data: " + quest_text
	inventory_label.text = "Items: " + item_text + " | Creature placeholders: " + str(creatures.size())


func _record_list(rows: Array, key: String, empty_text: String) -> String:
	if rows.is_empty():
		return empty_text
	var names := PackedStringArray()
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			names.append(str(row.get(key, "?")))
	return ", ".join(names)


func _inventory_text() -> String:
	if not loaded_inventory.is_empty():
		return ", ".join(loaded_inventory)
	var items: Array = data_records.get("items", [])
	return _record_list(items, "name", "No items")


func _inventory_names() -> Array:
	if not loaded_inventory.is_empty():
		return Array(loaded_inventory)
	var items: Array = data_records.get("items", [])
	var names := []
	for row in items:
		if typeof(row) == TYPE_DICTIONARY:
			names.append(str(row.get("name", "Unknown Item")))
	if names.is_empty():
		names.append("Practice Token")
	return names


func _save_state() -> bool:
	var save_path := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var state := {
		"schema_version": 1,
		"identity": {
			"id": "local_sandbox_user",
			"display_name": "Local Sandbox User",
		},
		"character": {
			"id": "local_sandbox_character",
			"name": "Sandbox Scout",
		},
		"position": _vector_to_dict(player_body.global_position),
		"health": player_health,
		"focus": player_resource,
		"quest_started": quest_started,
		"quest_complete": quest_complete,
		"inventory": _inventory_names(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_update_ui("Save failed.")
		return false
	file.store_string(JSON.stringify(state, "\t") + "\n")
	_update_ui("State saved.")
	return true


func _load_state(message: String = "State loaded.") -> bool:
	var save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(save_path):
		_update_ui("No saved state yet.")
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_update_ui("Load failed.")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_update_ui("Save file was not valid JSON.")
		return false
	var state: Dictionary = parsed
	var position: Dictionary = state.get("position", {})
	player_body.global_position = _dict_to_vector(position, player_body.global_position)
	player_body.velocity = Vector3.ZERO
	player_health = float(state.get("health", PLAYER_HEALTH_MAX))
	player_resource = float(state.get("focus", RESOURCE_MAX))
	quest_started = bool(state.get("quest_started", false))
	quest_complete = bool(state.get("quest_complete", false))
	loaded_inventory.clear()
	var inventory: Array = state.get("inventory", [])
	for item in inventory:
		loaded_inventory.append(str(item))
	_update_data_ui()
	_update_ui(message)
	return true


func _logout_login_reload() -> void:
	if not _save_state():
		return
	player_body.global_position = Vector3(0, 1.0, 4.0)
	player_health = PLAYER_HEALTH_MAX
	player_resource = RESOURCE_MAX
	quest_started = false
	quest_complete = false
	loaded_inventory.clear()
	_load_state("Logout/login reload complete.")


func _vector_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _dict_to_vector(value: Dictionary, fallback: Vector3) -> Vector3:
	return Vector3(
		float(value.get("x", fallback.x)),
		float(value.get("y", fallback.y)),
		float(value.get("z", fallback.z))
	)


func _note_data_error(view: String, message: String) -> void:
	data_records[view] = []
	_update_ui("Data " + view + ": " + message)
	_maybe_finish_data_self_test()


func _maybe_finish_data_self_test() -> void:
	if OS.get_environment("ACORE_SANDBOX_DATA_SELF_TEST") != "1":
		return
	if pending_data_requests > 0:
		return
	for view in ["characters", "creatures", "quests", "items"]:
		if not data_records.has(view) or data_records[view].is_empty():
			_fail_data_self_test(view + " did not load rows")
			return
	if spawned_data_nodes.is_empty():
		_fail_data_self_test("creature placeholders were not spawned")
		return
	print("SANDBOX_DATA_SELF_TEST_OK")
	get_tree().quit(0)


func _fail_data_self_test(message: String) -> void:
	push_error("SANDBOX_DATA_SELF_TEST_FAILED: " + message)
	get_tree().quit(1)


func _run_persistence_self_test() -> void:
	player_body.global_position = Vector3(2.5, 1.0, -2.5)
	player_health = 73.0
	player_resource = 44.0
	quest_started = true
	quest_complete = true
	loaded_inventory = PackedStringArray(["Saved Token", "Practice Blade"])
	if not _save_state():
		_fail_persistence_self_test("save failed")
		return
	player_body.global_position = Vector3.ZERO
	player_health = 1.0
	player_resource = 1.0
	quest_started = false
	quest_complete = false
	loaded_inventory.clear()
	if not _load_state("Persistence self-test loaded."):
		_fail_persistence_self_test("load failed")
		return
	if player_body.global_position.distance_to(Vector3(2.5, 1.0, -2.5)) > 0.01:
		_fail_persistence_self_test("position did not restore")
		return
	if int(player_health) != 73 or int(player_resource) != 44:
		_fail_persistence_self_test("health/focus did not restore")
		return
	if not quest_started or not quest_complete:
		_fail_persistence_self_test("quest flags did not restore")
		return
	if loaded_inventory.size() != 2 or loaded_inventory[0] != "Saved Token":
		_fail_persistence_self_test("inventory did not restore")
		return
	print("SANDBOX_PERSISTENCE_SELF_TEST_OK")
	get_tree().quit(0)


func _fail_persistence_self_test(message: String) -> void:
	push_error("SANDBOX_PERSISTENCE_SELF_TEST_FAILED: " + message)
	get_tree().quit(1)


func _run_self_test() -> void:
	_select_target(0)
	player_body.global_position = npc.global_position + Vector3(0, 0, 1.4)
	_try_interact()
	if not quest_started:
		_fail_self_test("mentor interaction did not start the task")
		return

	_select_target(1)
	player_body.global_position = enemy.global_position + Vector3(0, 0, 2.0)
	var attempts := 0
	while enemy_health > 0.0 and attempts < 8:
		player_resource = RESOURCE_MAX
		_try_attack()
		attempts += 1

	_update_ui()
	if enemy_health > 0.0:
		_fail_self_test("enemy was not defeated")
		return
	if not quest_complete:
		_fail_self_test("task did not complete after enemy defeat")
		return
	if enemy.visible:
		_fail_self_test("enemy did not hide after defeat")
		return
	if int(enemy_bar.value) != int(enemy_health):
		_fail_self_test("enemy health UI did not match enemy health")
		return

	print("SANDBOX_SELF_TEST_OK")
	get_tree().quit(0)


func _fail_self_test(message: String) -> void:
	push_error("SANDBOX_SELF_TEST_FAILED: " + message)
	get_tree().quit(1)


func _return_to_dashboard() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _update_ui(message: String = "") -> void:
	if health_bar == null:
		return

	health_bar.value = player_health
	resource_bar.value = player_resource
	enemy_bar.value = enemy_health
	enemy_bar.visible = _current_target() == enemy
	strike_button.disabled = _current_target() != enemy or enemy_health <= 0.0
	talk_button.disabled = _current_target() != npc

	var target := _current_target()
	target_label.text = "Target: " + (str(target.name) if target != null else "None")
	if quest_complete:
		quest_label.text = "Task: Complete"
	elif quest_started:
		quest_label.text = "Task: Defeat the training echo"
	else:
		quest_label.text = "Task: Talk to the mentor"

	if not message.is_empty():
		status_label.text = message


func _bar(label: String, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = max_value
	bar.custom_minimum_size = Vector2(190, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.tooltip_text = label
	return bar


func _hud_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	return label


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)
	button.pressed.connect(callback)
	return button


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
