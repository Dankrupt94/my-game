extends Node

var abilities := {
	"Attack": { "cooldown": 1.0, "timer": 0.0 },
	"Fireball": { "cooldown": 3.0, "timer": 0.0 },
	"Heal": { "cooldown": 6.0, "timer": 0.0 }
}

signal cooldown_updated(ability_name: String, progress: float)

func _process(delta: float) -> void:
	for name in abilities:
		var ability = abilities[name]
		if ability["timer"] > 0.0:
			ability["timer"] = max(0.0, ability["timer"] - delta)
			var progress = ability["timer"] / ability["cooldown"]
			cooldown_updated.emit(name, progress)

func trigger_ability(name: String) -> bool:
	if not abilities.has(name):
		return false
		
	var ability = abilities[name]
	if ability["timer"] > 0.0:
		return false # On cooldown
		
	ability["timer"] = ability["cooldown"]
	return true
