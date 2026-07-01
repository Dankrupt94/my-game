extends Node3D

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const WORLD_TO_GODOT_SCALE := 0.02
const GRID_EXTENT := 220
const GRID_STEP := 20

var marker: MeshInstance3D
var marker_label: Label3D
var camera: Camera3D
var status_label: Label
var detail_label: Label
var self_test_finished := false


func _ready() -> void:
	_build_world_view()
	_enter_world()


func _build_world_view() -> void:
	status_label = Label.new()
	detail_label = Label.new()

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, 38, 0)
	light.light_energy = 1.35
	add_child(light)

	_add_grid()
	_add_axis_label("X", Vector3(GRID_EXTENT + 12, 0, 0), Color(0.92, 0.18, 0.16))
	_add_axis_label("Y", Vector3(0, 0, -GRID_EXTENT - 12), Color(0.16, 0.62, 0.96))

	marker = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 2.2
	mesh.height = 8.0
	marker.mesh = mesh
	marker.material_override = _material(Color(1.0, 0.84, 0.22))
	add_child(marker)

	marker_label = Label3D.new()
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_label.font_size = 20
	marker_label.modulate = Color(1, 1, 1)
	marker_label.position = Vector3(0, 7, 0)
	marker.add_child(marker_label)

	camera = Camera3D.new()
	camera.fov = 58
	add_child(camera)
	camera.current = true

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.03
	panel.anchor_right = 0.42
	panel.anchor_bottom = 0.23
	canvas.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	status_label.text = "Entering world..."
	status_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(status_label)

	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = "Waiting for AzerothCore."
	stack.add_child(detail_label)


func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-GRID_EXTENT, GRID_EXTENT + 1, GRID_STEP):
		var strong := i == 0
		mesh.surface_set_color(Color(0.45, 0.49, 0.52) if strong else Color(0.24, 0.28, 0.31))
		mesh.surface_add_vertex(Vector3(i, 0, -GRID_EXTENT))
		mesh.surface_add_vertex(Vector3(i, 0, GRID_EXTENT))
		mesh.surface_add_vertex(Vector3(-GRID_EXTENT, 0, i))
		mesh.surface_add_vertex(Vector3(GRID_EXTENT, 0, i))

	mesh.surface_set_color(Color(0.92, 0.18, 0.16))
	mesh.surface_add_vertex(Vector3(-GRID_EXTENT, 0.06, 0))
	mesh.surface_add_vertex(Vector3(GRID_EXTENT, 0.06, 0))
	mesh.surface_set_color(Color(0.16, 0.62, 0.96))
	mesh.surface_add_vertex(Vector3(0, 0.08, -GRID_EXTENT))
	mesh.surface_add_vertex(Vector3(0, 0.08, GRID_EXTENT))
	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	grid.material_override = material
	add_child(grid)


func _add_axis_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _enter_world() -> void:
	var bridge := ProtocolClientBridge.new()
	var result := bridge.enter_world(TEST_CHARACTER_NAME)
	if bool(result.get("ok", false)):
		_apply_enter_world_result(result)
		_finish_self_test(true, result)
	else:
		_set_status_text("Enter world failed", str(result.get("error", result.get("output", "Unknown error"))))
		_finish_self_test(false, result)


func _apply_enter_world_result(result: Dictionary) -> void:
	var login: Dictionary = result.get("login", {})
	var marker_position := _godot_position_from_login(login)

	var character: Dictionary = result.get("character", {})
	var character_name := str(character.get("name", TEST_CHARACTER_NAME))
	var update: Dictionary = result.get("update", {})
	var update_seen := bool(update.get("seen", result.get("update_object_seen", false)))

	_set_status_text("World login ready", "Character %s entered map %s at WoW position (%s, %s, %s). Update object seen: %s." % [
		character_name,
		str(login.get("map", "?")),
		"%.2f" % float(login.get("x", 0.0)),
		"%.2f" % float(login.get("y", 0.0)),
		"%.2f" % float(login.get("z", 0.0)),
		"yes" if update_seen else "not yet",
	])

	if marker != null:
		marker.position = marker_position
	if marker_label != null:
		marker_label.text = "%s\nmap %s" % [character_name, str(login.get("map", "?"))]
	if camera != null:
		camera.position = marker_position + Vector3(46, 42, 62)
		camera.look_at(marker_position + Vector3(0, 2.5, 0), Vector3.UP)


func _godot_position_from_login(login: Dictionary) -> Vector3:
	var wow_x := float(login.get("x", 0.0))
	var wow_y := float(login.get("y", 0.0))
	var wow_z := float(login.get("z", 0.0))
	return Vector3(
		wow_x * WORLD_TO_GODOT_SCALE,
		wow_z * WORLD_TO_GODOT_SCALE,
		-wow_y * WORLD_TO_GODOT_SCALE)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	return material


func _set_status_text(title: String, details: String) -> void:
	if status_label != null:
		status_label.text = title
	if detail_label != null:
		detail_label.text = details
	if status_label == null or detail_label == null:
		print(title + ": " + details)


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_ENTER_WORLD_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		var login: Dictionary = result.get("login", {})
		print("ENTER_WORLD_VIEW_SELF_TEST_OK map=%s x=%.2f y=%.2f z=%.2f" % [
			str(login.get("map", "?")),
			float(login.get("x", 0.0)),
			float(login.get("y", 0.0)),
			float(login.get("z", 0.0)),
		])
		get_tree().quit(0)
	else:
		push_error("ENTER_WORLD_VIEW_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
