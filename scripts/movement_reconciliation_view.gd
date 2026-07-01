extends Node3D

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const MOVE_DELTA_X := 0.20
const WORLD_TO_GODOT_SCALE := 0.02

var status_label: Label
var detail_label: Label
var camera: Camera3D
var self_test_finished := false


func _ready() -> void:
	_build_view()
	_run_movement_probe()


func _build_view() -> void:
	status_label = Label.new()
	detail_label = Label.new()

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.78, 0.82)
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 36, 0)
	add_child(light)

	_add_grid()
	camera = Camera3D.new()
	camera.position = Vector3(8, 22, 38)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.03
	panel.anchor_right = 0.45
	panel.anchor_bottom = 0.22
	canvas.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	status_label.text = "Running movement probe..."
	status_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(status_label)

	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = "Sending one start/stop movement step to AzerothCore."
	stack.add_child(detail_label)


func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-80, 81, 10):
		mesh.surface_set_color(Color(0.28, 0.31, 0.34))
		mesh.surface_add_vertex(Vector3(i, 0, -80))
		mesh.surface_add_vertex(Vector3(i, 0, 80))
		mesh.surface_add_vertex(Vector3(-80, 0, i))
		mesh.surface_add_vertex(Vector3(80, 0, i))
	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	grid.material_override = material
	add_child(grid)


func _run_movement_probe() -> void:
	var bridge := ProtocolClientBridge.new()
	var result := bridge.move_heartbeat(TEST_CHARACTER_NAME, MOVE_DELTA_X, 0.0, 0.0)
	if bool(result.get("ok", false)):
		_apply_result(result)
		_finish_self_test(true, result)
	else:
		_set_status("Movement probe failed", str(result.get("error", result.get("output", "Unknown error"))))
		_finish_self_test(false, result)


func _apply_result(result: Dictionary) -> void:
	var before: Dictionary = result.get("before", {})
	var target: Dictionary = result.get("target", {})
	var live: Dictionary = result.get("live", {})
	var after: Dictionary = result.get("after", {})
	var live_drift := float(result.get("live_drift", result.get("drift", 999.0)))
	var saved_drift := float(result.get("saved_drift", 999.0))

	_add_marker("Before", _godot_position(before), Color(0.9, 0.28, 0.22))
	_add_marker("Target", _godot_position(target), Color(0.2, 0.48, 1.0))
	_add_marker("Live", _godot_position(live), Color(0.92, 0.78, 0.18))
	_add_marker("Saved", _godot_position(after), Color(0.2, 0.78, 0.38))

	var center := _godot_position(live)
	if camera != null:
		camera.position = center + Vector3(7, 12, 20)
		camera.look_at(center, Vector3.UP)

	_set_status(
		"Movement reconciliation ready",
		"Moved %s by %.2f WoW units. Live accepted: %s. Live drift: %.3f. Saved drift: %.3f." % [
			TEST_CHARACTER_NAME,
			MOVE_DELTA_X,
			"yes" if bool(result.get("live_position_accepted", false)) else "no",
			live_drift,
			saved_drift,
		])


func _add_marker(text: String, position: Vector3, color: Color) -> void:
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.3
	mesh.height = 2.6
	body.mesh = mesh
	body.position = position
	body.material_override = _material(color)
	add_child(body)

	var label := Label3D.new()
	label.text = text
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.4, 0)
	body.add_child(label)


func _godot_position(value: Dictionary) -> Vector3:
	return Vector3(
		float(value.get("x", 0.0)) * WORLD_TO_GODOT_SCALE,
		float(value.get("z", 0.0)) * WORLD_TO_GODOT_SCALE,
		-float(value.get("y", 0.0)) * WORLD_TO_GODOT_SCALE)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material


func _set_status(title: String, details: String) -> void:
	if status_label != null:
		status_label.text = title
	if detail_label != null:
		detail_label.text = details
	print(title + ": " + details)


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_MOVEMENT_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("MOVEMENT_RECONCILIATION_SELF_TEST_OK live_drift=%.3f saved_drift=%.3f" % [
			float(result.get("live_drift", result.get("drift", 999.0))),
			float(result.get("saved_drift", 999.0)),
		])
		get_tree().quit(0)
	else:
		push_error("MOVEMENT_RECONCILIATION_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
