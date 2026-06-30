extends "res://scripts/player_states/player_state.gd"

func enter() -> void:
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("Jump")

func physics_update(_delta: float) -> void:
	if player.is_on_floor():
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir != Vector2.ZERO:
			state_machine.change_state("Move")
		else:
			state_machine.change_state("Idle")
