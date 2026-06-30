extends Node

@export var initial_state: String = "Idle"

var states: Dictionary = {}
var current_state: RefCounted
var player: CharacterBody3D

func init(parent_player: CharacterBody3D) -> void:
	player = parent_player
	
	states["Idle"] = load("res://scripts/player_states/idle_state.gd").new()
	states["Move"] = load("res://scripts/player_states/move_state.gd").new()
	states["Jump"] = load("res://scripts/player_states/jump_state.gd").new()
	
	for state_name in states:
		states[state_name].player = player
		states[state_name].state_machine = self
		
	change_state(initial_state)

func change_state(new_state_name: String) -> void:
	if current_state and current_state.has_method("exit"):
		current_state.exit()
	current_state = states.get(new_state_name)
	if current_state and current_state.has_method("enter"):
		current_state.enter()

func _unhandled_input(event: InputEvent) -> void:
	if current_state and current_state.has_method("handle_input"):
		current_state.handle_input(event)

func _process(delta: float) -> void:
	if current_state and current_state.has_method("update"):
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state and current_state.has_method("physics_update"):
		current_state.physics_update(delta)
