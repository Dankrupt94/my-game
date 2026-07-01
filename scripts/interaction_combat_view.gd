extends Node3D

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const INTERACTION_ENTRY := 823
const COMBAT_ENTRY := 721

var status_label: Label
var target_label: Label
var combat_log: TextEdit
var camera: Camera3D
var self_test_finished := false


func _ready() -> void:
	_build_view()
	_run_stage_probe()


func _build_view() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.8)
	environment.ambient_light_energy = 0.82
	environment_node.environment = environment
	add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, 32, 0)
	light.light_energy = 1.2
	add_child(light)

	_add_grid()
	camera = Camera3D.new()
	camera.fov = 54
	camera.position = Vector3(8, 20, 34)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	_add_marker("Player", Vector3(-5, 1.5, 0), Color(1.0, 0.82, 0.22), CapsuleMesh.new())
	_add_marker("NPC", Vector3(2, 1.5, -4), Color(0.25, 0.58, 1.0), CapsuleMesh.new())
	_add_marker("Creature", Vector3(7, 1.0, 4), Color(0.9, 0.25, 0.18), SphereMesh.new())

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.03
	panel.anchor_right = 0.56
	panel.anchor_bottom = 0.34
	canvas.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)

	status_label = Label.new()
	status_label.text = "Running interaction and combat probes..."
	status_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(status_label)

	target_label = Label.new()
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label.text = "Waiting for live AzerothCore target IDs."
	stack.add_child(target_label)

	combat_log = TextEdit.new()
	combat_log.editable = false
	combat_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	combat_log.custom_minimum_size = Vector2(0, 118)
	stack.add_child(combat_log)


func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-60, 61, 10):
		mesh.surface_set_color(Color(0.25, 0.28, 0.31))
		mesh.surface_add_vertex(Vector3(i, 0, -60))
		mesh.surface_add_vertex(Vector3(i, 0, 60))
		mesh.surface_add_vertex(Vector3(-60, 0, i))
		mesh.surface_add_vertex(Vector3(60, 0, i))
	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	grid.material_override = material
	add_child(grid)


func _add_marker(text: String, position: Vector3, color: Color, mesh: Mesh) -> void:
	var body := MeshInstance3D.new()
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


func _run_stage_probe() -> void:
	var bridge := ProtocolClientBridge.new()
	_log("Finding a live NPC target and sending interaction.")
	var interaction := bridge.interact_with_npc(TEST_CHARACTER_NAME, INTERACTION_ENTRY, "Nearby NPC")
	if not bool(interaction.get("ok", false)):
		_apply_failure("Interaction failed", interaction)
		return
	_log("Gossip response received: opcode 0x%s" % _opcode_hex(int(interaction.get("response_opcode", 0))))

	_log("Finding a live creature target and sending attack swing.")
	var combat := bridge.combat_probe(TEST_CHARACTER_NAME, COMBAT_ENTRY, "Nearby Creature")
	if not bool(combat.get("ok", false)):
		_apply_failure("Combat probe failed", combat)
		return
	_log("Combat response received: opcode 0x%s" % _opcode_hex(int(combat.get("response_opcode", 0))))

	_apply_success(interaction, combat)


func _apply_success(interaction: Dictionary, combat: Dictionary) -> void:
	var interaction_guid := str(interaction.get("target_guid", "0x0"))
	var combat_guid := str(combat.get("target_guid", "0x0"))
	status_label.text = "Interaction and combat ready"
	target_label.text = "Target frame: NPC %s entry %s, creature %s entry %s." % [
		interaction_guid,
		str(interaction.get("target_entry", INTERACTION_ENTRY)),
		combat_guid,
		str(combat.get("target_entry", COMBAT_ENTRY)),
	]
	_finish_self_test(true, {
		"interaction": interaction,
		"combat": combat,
	})


func _apply_failure(title: String, result: Dictionary) -> void:
	status_label.text = title
	target_label.text = str(result.get("error", result.get("output", "Unknown failure")))
	_log(target_label.text)
	_finish_self_test(false, result)


func _log(line: String) -> void:
	if combat_log != null:
		combat_log.text += line + "\n"
	print(line)


func _opcode_hex(value: int) -> String:
	return "%03x" % [value & 0xFFFF]


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	return material


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_INTERACTION_COMBAT_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		var interaction: Dictionary = result.get("interaction", {})
		var combat: Dictionary = result.get("combat", {})
		print("INTERACTION_COMBAT_SELF_TEST_OK gossip_opcode=0x%s combat_opcode=0x%s" % [
			_opcode_hex(int(interaction.get("response_opcode", 0))),
			_opcode_hex(int(combat.get("response_opcode", 0))),
		])
		get_tree().quit(0)
	else:
		push_error("INTERACTION_COMBAT_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
