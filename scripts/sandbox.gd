extends Node3D

const FLOATING_TEXT_SCENE := preload("res://scenes/floating_text.tscn")
const SettingsRuntime = preload("res://scripts/settings_runtime.gd")

@onready var player: CharacterBody3D = $Player
@onready var targeting_system: Node3D = $TargetingSystem
@onready var cooldown_manager: Node = $CooldownManager

func _ready() -> void:
	SettingsRuntime.apply_keybindings(SettingsRuntime.load_settings())
	_ensure_input_action("move_forward", KEY_W)
	_ensure_input_action("move_backward", KEY_S)
	_ensure_input_action("move_left", KEY_A)
	_ensure_input_action("move_right", KEY_D)
	_ensure_input_action("jump", KEY_SPACE)
	_ensure_input_action("interact", KEY_F)
	_ensure_input_action("attack_1", KEY_1)

	if targeting_system:
		targeting_system.target_changed.connect(_on_target_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_focus_next"): # Tab
		if targeting_system:
			targeting_system.cycle_tab_target()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera := get_viewport().get_camera_3d()
		if camera and targeting_system:
			targeting_system.handle_click_targeting(camera, event.position)

	if event.is_action_just_pressed("attack_1"):
		_try_cast("Attack")

func _ensure_input_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _try_cast(ability_name: String) -> void:
	if not cooldown_manager or not targeting_system:
		return
		
	var target = targeting_system.current_target
	if not target:
		return # Need a target to cast
		
	if cooldown_manager.trigger_ability(ability_name):
		_on_player_casted_ability(ability_name, target)

func _on_player_casted_ability(ability_name: String, target: Node3D) -> void:
	if not target or not target.has_node("EntityStats"):
		return
		
	var stats = target.get_node("EntityStats")
	var damage := 0.0
	var text_color := Color(1, 1, 1)
	
	match ability_name:
		"Attack":
			damage = randf_range(10.0, 15.0)
			text_color = Color(0.95, 0.35, 0.35)
		"Fireball":
			damage = randf_range(25.0, 35.0)
			text_color = Color(1.0, 0.60, 0.20)
			
	stats.take_damage(damage)
	_spawn_floating_text(target.global_position + Vector3(0, 1.5, 0), str(int(damage)), text_color)

func _spawn_floating_text(pos: Vector3, amount: String, color: Color) -> void:
	var fct = FLOATING_TEXT_SCENE.instantiate()
	add_child(fct)
	fct.global_position = pos
	fct.setup(amount, color)

func _on_target_changed(new_target: Node3D) -> void:
	# Wired to UI Target Frame updates later
	pass
