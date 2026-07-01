extends Node3D

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")
const ClientObjectManager = preload("res://scripts/client_object_manager.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const BRIDGE_BASE_URL := "http://127.0.0.1:8765"
const NEARBY_TOOL := "res://tools/nearby_world_objects.py"
const WORLD_TO_GODOT_SCALE := 0.16

var object_manager := ClientObjectManager.new()
var camera: Camera3D
var status_label: Label
var detail_label: Label
var self_test_finished := false
var center_x := 0.0
var center_y := 0.0
var center_z := 0.0


func _ready() -> void:
	_build_view()
	_load_visibility()


func _build_view() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.78
	environment_node.environment = environment
	add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 34, 0)
	light.light_energy = 1.25
	add_child(light)

	_add_grid()
	camera = Camera3D.new()
	camera.fov = 56
	camera.position = Vector3(0, 34, 54)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.03
	panel.anchor_right = 0.48
	panel.anchor_bottom = 0.22
	canvas.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	status_label = Label.new()
	status_label.text = "Loading object visibility..."
	status_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(status_label)

	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = "Reading live player position and local world spawns."
	stack.add_child(detail_label)


func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-80, 81, 10):
		mesh.surface_set_color(Color(0.25, 0.28, 0.31))
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


func _load_visibility() -> void:
	var bridge := ProtocolClientBridge.new()
	var login_result := bridge.enter_world(TEST_CHARACTER_NAME)
	if not bool(login_result.get("ok", false)):
		_set_status("Object visibility failed", str(login_result.get("error", login_result.get("output", "enter world failed"))))
		_finish_self_test(false, {})
		return

	var login: Dictionary = login_result.get("login", {})
	center_x = float(login.get("x", 0.0))
	center_y = float(login.get("y", 0.0))
	center_z = float(login.get("z", 0.0))

	_spawn_player_marker(login_result)
	_request_nearby_objects(login, login_result)


func _request_nearby_objects(login: Dictionary, login_result: Dictionary) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_nearby_response.bind(login, login_result, request))
	var query := "map=%s&x=%s&y=%s&radius=80&limit=30" % [
		str(int(login.get("map", 0))).uri_encode(),
		str(float(login.get("x", 0.0))).uri_encode(),
		str(float(login.get("y", 0.0))).uri_encode(),
	]
	var error := request.request(BRIDGE_BASE_URL + "/nearby?" + query)
	if error != OK:
		request.queue_free()
		_apply_nearby_report(_load_nearby_objects(login), login_result)


func _on_nearby_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	login: Dictionary,
	login_result: Dictionary,
	request: HTTPRequest) -> void:
	request.queue_free()
	var body_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_apply_nearby_report(_load_nearby_objects(login), login_result)
		return
	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_apply_nearby_report({"ok": false, "error": "host bridge returned invalid JSON"}, login_result)
		return
	var payload: Dictionary = parsed
	var report: Dictionary = payload.get("report", payload)
	_apply_nearby_report(report, login_result)


func _apply_nearby_report(nearby: Dictionary, login_result: Dictionary) -> void:
	if not bool(nearby.get("ok", false)):
		_set_status("Object visibility failed", str(nearby.get("error", "nearby object query failed")))
		_finish_self_test(false, nearby)
		return

	object_manager.clear()
	object_manager.apply_rows(nearby.get("objects", []))
	_spawn_visible_objects(object_manager.all_objects())

	var update: Dictionary = login_result.get("update", {})
	var update_seen := bool(update.get("seen", login_result.get("update_object_seen", false)))
	_set_status(
		"Object visibility ready",
		"Visible placeholders: %d creatures, %d objects. Packet update seen: %s." % [
			object_manager.count_by_kind("creature"),
			object_manager.count_by_kind("gameobject"),
			"yes" if update_seen else "not in this login sample",
		])
	_finish_self_test(object_manager.count() > 0, {
		"nearby": nearby,
		"update_seen": update_seen,
	})


func _load_nearby_objects(login: Dictionary) -> Dictionary:
	var tool := ProjectSettings.globalize_path(NEARBY_TOOL)
	var output: Array = []
	var exit_code := OS.execute(
		"python3",
		PackedStringArray([
			tool,
			"--map",
			str(int(login.get("map", 0))),
			"--x",
			str(float(login.get("x", 0.0))),
			"--y",
			str(float(login.get("y", 0.0))),
			"--radius",
			"80",
			"--limit",
			"30",
		]),
		output,
		true,
		false)
	var text := "\n".join(output)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "nearby object query returned invalid JSON", "output": text, "exit_code": exit_code}
	var result: Dictionary = parsed
	result["exit_code"] = exit_code
	if exit_code != 0:
		result["ok"] = false
	return result


func _spawn_player_marker(login_result: Dictionary) -> void:
	var character: Dictionary = login_result.get("character", {})
	var marker := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 1.4
	mesh.height = 5.4
	marker.mesh = mesh
	marker.material_override = _material(Color(1.0, 0.82, 0.22))
	marker.position = Vector3.ZERO
	add_child(marker)
	_add_label(marker, str(character.get("name", TEST_CHARACTER_NAME)), Color(1.0, 0.95, 0.75), 5.0)


func _spawn_visible_objects(rows: Array) -> void:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var kind := str(row.get("kind", ""))
		var node := MeshInstance3D.new()
		if kind == "gameobject":
			var box := BoxMesh.new()
			box.size = Vector3(1.6, 1.6, 1.6)
			node.mesh = box
			node.material_override = _material(Color(0.55, 0.58, 0.62))
		else:
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.8
			capsule.height = 3.2
			node.mesh = capsule
			node.material_override = _material(Color(0.86, 0.18, 0.16))
		node.position = _godot_position(row)
		node.rotation.y = -float(row.get("orientation", 0.0))
		add_child(node)
		if float(row.get("distance", 999.0)) < 35.0:
			_add_label(node, _short_label(str(row.get("name", kind))), Color(0.92, 0.95, 1.0), 2.6)


func _godot_position(row: Dictionary) -> Vector3:
	return Vector3(
		(float(row.get("x", center_x)) - center_x) * WORLD_TO_GODOT_SCALE,
		(float(row.get("z", center_z)) - center_z) * WORLD_TO_GODOT_SCALE,
		-(float(row.get("y", center_y)) - center_y) * WORLD_TO_GODOT_SCALE)


func _add_label(parent: Node3D, text: String, color: Color, height: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 15
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, height, 0)
	parent.add_child(label)


func _short_label(text: String) -> String:
	if text.length() <= 22:
		return text
	return text.substr(0, 20) + ".."


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	return material


func _set_status(title: String, details: String) -> void:
	if status_label != null:
		status_label.text = title
	if detail_label != null:
		detail_label.text = details
	print(title + ": " + details)


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_OBJECT_VISIBILITY_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true
	if ok:
		print("OBJECT_VISIBILITY_SELF_TEST_OK creatures=%d gameobjects=%d update_seen=%s" % [
			object_manager.count_by_kind("creature"),
			object_manager.count_by_kind("gameobject"),
			"1" if bool(result.get("update_seen", false)) else "0",
		])
		get_tree().quit(0)
	else:
		push_error("OBJECT_VISIBILITY_SELF_TEST_FAILED: " + str(result.get("error", "unknown")))
		get_tree().quit(1)
