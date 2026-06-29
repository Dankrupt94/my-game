extends Node3D

signal quest_accepted
signal quest_turned_in
signal quest_reminder(message: String)

var display_name := "Scout Mira"

func _ready() -> void:
	_build_npc()

func get_prompt(quest_state: String, dummy_defeated: bool) -> String:
	match quest_state:
		"not_started":
			return "Press E: accept Scout Mira's training quest"
		"accepted":
			if dummy_defeated:
				return "Press E: report success to Scout Mira"
			return "Press E: ask Scout Mira about the training dummy"
		"ready_to_turn_in":
			return "Press E: complete First Strike at Frostbound"
		"completed":
			return "Scout Mira: The yard is yours to practice in."
		_:
			return "Press E: talk"

func interact(quest_state: String, dummy_defeated: bool) -> void:
	match quest_state:
		"not_started":
			quest_accepted.emit()
		"accepted":
			if dummy_defeated:
				quest_turned_in.emit()
			else:
				quest_reminder.emit("Scout Mira: Target the dummy with Tab, then use 1 or 2.")
		"ready_to_turn_in":
			quest_turned_in.emit()
		"completed":
			quest_reminder.emit("Scout Mira: Keep practicing. The pass gets colder after sundown.")
		_:
			quest_reminder.emit("Scout Mira watches the snowline.")

func _build_npc() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.7
	body.mesh = body_mesh
	body.material_override = _material(Color(0.18, 0.42, 0.36), 0.62, 0.12)
	body.position.y = 0.86
	add_child(body)

	var hood := MeshInstance3D.new()
	var hood_mesh := SphereMesh.new()
	hood_mesh.radius = 0.38
	hood_mesh.height = 0.48
	hood.mesh = hood_mesh
	hood.material_override = _material(Color(0.12, 0.23, 0.24), 0.68, 0.08)
	hood.position.y = 1.82
	add_child(hood)

	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.12, 1.3, 0.04)
	banner.mesh = banner_mesh
	banner.material_override = _material(Color(0.78, 0.82, 0.86), 0.55, 0.2)
	banner.position = Vector3(-0.55, 1.24, 0.0)
	add_child(banner)

	var label := Label3D.new()
	label.text = "%s\n!" % display_name
	label.position = Vector3(0.0, 2.75, 0.0)
	label.font_size = 28
	label.outline_size = 7
	label.modulate = Color(1.0, 0.92, 0.45)
	add_child(label)

func _material(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	return material

