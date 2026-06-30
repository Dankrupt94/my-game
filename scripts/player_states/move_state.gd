extends "res://scripts/player_states/player_state.gd"

func enter() -> void:
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("Run")

func physics_update(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		state_machine.change_state("Idle")
		return

	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		state_machine.change_state("Jump")
		return
