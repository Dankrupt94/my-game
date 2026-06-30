extends RefCounted
class_name PlayerStateBase

var player: CharacterBody3D
var state_machine: Node

func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
