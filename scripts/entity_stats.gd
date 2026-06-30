extends Node

@export var max_health := 100.0
@export var current_health := 100.0
@export var entity_name := "Placeholder Entity"

signal health_changed(current: float, max_val: float)
signal entity_died

func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0:
		entity_died.emit()

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
