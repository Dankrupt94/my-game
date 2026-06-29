extends Node3D

signal health_changed(current_health: int, max_health: int)
signal defeated

var display_name := "Frostbound Training Dummy"
var max_health := 90
var health := 90
var is_defeated := false

var _body_material: StandardMaterial3D
var _label: Label3D

func _ready() -> void:
	_build_dummy()
	health_changed.emit(health, max_health)

func take_damage(amount: int, source_name: String) -> void:
	if is_defeated:
		return

	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_label.text = "%s\n%s - %d/%d" % [display_name, source_name, health, max_health]

	if health == 0:
		is_defeated = true
		_body_material.albedo_color = Color(0.33, 0.36, 0.39)
		_label.text = "%s\nDefeated" % display_name
		defeated.emit()

func get_target_payload() -> Dictionary:
	return {
		"name": display_name,
		"health": health,
		"max_health": max_health,
	}

func _build_dummy() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.height = 0.26
	base_mesh.top_radius = 0.78
	base_mesh.bottom_radius = 0.9
	base.mesh = base_mesh
	base.material_override = _material(Color(0.26, 0.22, 0.18), 0.72, 0.15)
	base.position.y = 0.13
	add_child(base)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.height = 2.1
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.16
	pole.mesh = pole_mesh
	pole.material_override = _material(Color(0.36, 0.25, 0.15), 0.85, 0.05)
	pole.position.y = 1.18
	add_child(pole)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.height = 1.15
	body_mesh.top_radius = 0.42
	body_mesh.bottom_radius = 0.48
	body.mesh = body_mesh
	_body_material = _material(Color(0.63, 0.34, 0.22), 0.78, 0.0)
	body.material_override = _body_material
	body.position.y = 1.35
	add_child(body)

	var arms := MeshInstance3D.new()
	var arms_mesh := BoxMesh.new()
	arms_mesh.size = Vector3(1.55, 0.16, 0.16)
	arms.mesh = arms_mesh
	arms.material_override = _material(Color(0.39, 0.27, 0.17), 0.82, 0.0)
	arms.position.y = 1.72
	add_child(arms)

	_label = Label3D.new()
	_label.text = "%s\n%d/%d" % [display_name, health, max_health]
	_label.position = Vector3(0.0, 2.65, 0.0)
	_label.font_size = 26
	_label.outline_size = 7
	_label.modulate = Color(1.0, 0.95, 0.82)
	add_child(_label)

func _material(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	return material

