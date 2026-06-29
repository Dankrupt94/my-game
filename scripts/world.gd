extends Node3D

const Hud := preload("res://scripts/hud.gd")
const PlayerController := preload("res://scripts/player_controller.gd")
const QuestNpc := preload("res://scripts/quest_npc.gd")
const TrainingDummy := preload("res://scripts/training_dummy.gd")

var player
var hud
var quest_npc
var training_dummy
var quest_state := "not_started"
var dummy_defeated := false

func _ready() -> void:
	_ensure_input_actions()
	_build_environment()
	_build_zone_props()
	_spawn_player()
	_spawn_training_dummy()
	_spawn_quest_npc()
	_build_hud()
	_wire_gameplay()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud.show_feedback("Welcome to Frostbound Yard")

func _process(_delta: float) -> void:
	_update_interaction_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("hotbar_1"):
		player.use_hotbar_slot(1)
	elif event.is_action_pressed("hotbar_2"):
		player.use_hotbar_slot(2)
	elif event.is_action_pressed("hotbar_3"):
		player.use_hotbar_slot(3)
	elif event.is_action_pressed("target_next"):
		player.set_target(training_dummy)
		hud.show_feedback("Target selected: Frostbound Training Dummy")

func _ensure_input_actions() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_forward", KEY_UP)
	_bind_key("move_back", KEY_S)
	_bind_key("move_back", KEY_DOWN)
	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_right", KEY_D)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("jump", KEY_SPACE)
	_bind_key("interact", KEY_E)
	_bind_key("target_next", KEY_TAB)
	_bind_key("hotbar_1", KEY_1)
	_bind_key("hotbar_2", KEY_2)
	_bind_key("hotbar_3", KEY_3)
	_bind_key("toggle_mouse", KEY_ESCAPE)

func _bind_key(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.54, 0.68, 0.82)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.79, 0.86)
	environment.ambient_light_energy = 0.9
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "LowWinterSun"
	sun.light_energy = 2.4
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "SnowyGround"
	add_child(ground)

	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(72.0, 72.0)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color(0.86, 0.91, 0.95), 0.72, 0.08)
	ground.add_child(ground_mesh)

	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(72.0, 0.2, 72.0)
	ground_shape.shape = box
	ground_shape.position.y = -0.1
	ground.add_child(ground_shape)

func _build_zone_props() -> void:
	_add_label("Frostbound Yard", Vector3(0.0, 4.4, -12.0), 42)
	_add_crystal(Vector3(-8.0, 0.0, -7.0), Color(0.42, 0.78, 1.0))
	_add_crystal(Vector3(9.0, 0.0, 5.5), Color(0.70, 0.92, 1.0))
	_add_tree(Vector3(-14.0, 0.0, -3.0), 1.15)
	_add_tree(Vector3(-16.0, 0.0, 8.0), 0.9)
	_add_tree(Vector3(15.0, 0.0, -8.0), 1.0)
	_add_training_ring()

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerController)
	player.position = Vector3(0.0, 0.0, 9.0)
	add_child(player)

func _spawn_training_dummy() -> void:
	training_dummy = Node3D.new()
	training_dummy.name = "FrostboundTrainingDummy"
	training_dummy.set_script(TrainingDummy)
	training_dummy.position = Vector3(0.0, 0.0, -3.5)
	add_child(training_dummy)

func _spawn_quest_npc() -> void:
	quest_npc = Node3D.new()
	quest_npc.name = "ScoutMira"
	quest_npc.set_script(QuestNpc)
	quest_npc.position = Vector3(-4.0, 0.0, 3.0)
	add_child(quest_npc)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "Hud"
	hud.set_script(Hud)
	add_child(hud)
	hud.set_quest(quest_state, dummy_defeated)
	hud.set_target(training_dummy.get("display_name"), training_dummy.get("health"), training_dummy.get("max_health"))

func _wire_gameplay() -> void:
	player.stats_changed.connect(hud.set_stats)
	player.action_feedback.connect(hud.show_feedback)
	player.target_changed.connect(_on_player_target_changed)
	player.set_target(training_dummy)
	hud.set_stats(player.get("health"), player.get("max_health"), player.get("resolve"), player.get("max_resolve"))

	training_dummy.health_changed.connect(_on_dummy_health_changed)
	training_dummy.defeated.connect(_on_dummy_defeated)

	quest_npc.quest_accepted.connect(_on_quest_accepted)
	quest_npc.quest_turned_in.connect(_on_quest_turned_in)
	quest_npc.quest_reminder.connect(hud.show_feedback)

func _try_interact() -> void:
	if player.global_position.distance_to(quest_npc.global_position) <= 3.2:
		quest_npc.interact(quest_state, dummy_defeated)
	else:
		hud.show_feedback("Move closer to someone you can talk to.")

func _update_interaction_prompt() -> void:
	if player == null or quest_npc == null or hud == null:
		return

	if player.global_position.distance_to(quest_npc.global_position) <= 3.2:
		hud.set_prompt(quest_npc.get_prompt(quest_state, dummy_defeated))
	else:
		hud.set_prompt("Tab: target dummy | 1/2/3: abilities | E: interact | Esc: mouse")

func _on_player_target_changed(target: Node3D) -> void:
	if target == null:
		hud.clear_target()
		return

	if target.has_method("get_target_payload"):
		var payload: Dictionary = target.call("get_target_payload")
		hud.set_target(payload["name"], payload["health"], payload["max_health"])

func _on_dummy_health_changed(current_health: int, max_health: int) -> void:
	hud.set_target(training_dummy.get("display_name"), current_health, max_health)

func _on_dummy_defeated() -> void:
	dummy_defeated = true
	hud.show_feedback("Training dummy defeated.")
	if quest_state == "accepted":
		quest_state = "ready_to_turn_in"
		hud.show_feedback("Return to Scout Mira.")
	hud.set_quest(quest_state, dummy_defeated)

func _on_quest_accepted() -> void:
	quest_state = "accepted"
	hud.set_quest(quest_state, dummy_defeated)
	hud.show_feedback("Quest accepted: First Strike at Frostbound")

func _on_quest_turned_in() -> void:
	quest_state = "completed"
	hud.set_quest(quest_state, dummy_defeated)
	hud.show_feedback("Quest complete. You earned a warm cloak and 45 copper.")

func _toggle_mouse_capture() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		hud.show_feedback("Mouse released.")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hud.show_feedback("Mouse captured.")

func _add_training_ring() -> void:
	var ring_material := _material(Color(0.28, 0.33, 0.36), 0.55, 0.25)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var post := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.height = 0.8
		mesh.top_radius = 0.08
		mesh.bottom_radius = 0.1
		post.mesh = mesh
		post.material_override = ring_material
		post.position = Vector3(cos(angle) * 4.0, 0.4, -3.5 + sin(angle) * 4.0)
		add_child(post)

func _add_tree(origin: Vector3, scale_factor: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 2.2 * scale_factor
	trunk_mesh.top_radius = 0.16 * scale_factor
	trunk_mesh.bottom_radius = 0.24 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color(0.29, 0.19, 0.12), 0.8, 0.45)
	trunk.position = origin + Vector3(0.0, 1.1 * scale_factor, 0.0)
	add_child(trunk)

	var needles := MeshInstance3D.new()
	var needle_mesh := CylinderMesh.new()
	needle_mesh.height = 2.4 * scale_factor
	needle_mesh.top_radius = 0.0
	needle_mesh.bottom_radius = 1.1 * scale_factor
	needles.mesh = needle_mesh
	needles.material_override = _material(Color(0.14, 0.31, 0.26), 0.65, 0.32)
	needles.position = origin + Vector3(0.0, 2.7 * scale_factor, 0.0)
	add_child(needles)

func _add_crystal(origin: Vector3, color: Color) -> void:
	var crystal := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.9, 2.4, 0.9)
	crystal.mesh = mesh
	crystal.material_override = _material(color, 0.12, 0.05)
	crystal.position = origin + Vector3(0.0, 1.2, 0.0)
	crystal.rotation_degrees.y = 25.0
	add_child(crystal)

func _add_label(text: String, position: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.position = position
	label.outline_size = 8
	label.modulate = Color(0.95, 0.98, 1.0)
	add_child(label)

func _material(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	return material
