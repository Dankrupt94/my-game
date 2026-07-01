extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const DEFAULT_SPELL_ID := 2457

var status_label: Label
var spell_id_input: SpinBox
var cast_button: Button
var result_log: TextEdit
var self_test_finished := false


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_SPELL_CAST_SELF_TEST") == "1":
		call_deferred("_cast_selected_spell")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.065, 0.07)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)

	var title := Label.new()
	title.text = "Spell Cast"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	stack.add_child(controls)

	spell_id_input = SpinBox.new()
	spell_id_input.min_value = 1
	spell_id_input.max_value = 100000
	spell_id_input.step = 1
	spell_id_input.value = DEFAULT_SPELL_ID
	spell_id_input.custom_minimum_size = Vector2(160, 38)
	controls.add_child(spell_id_input)

	cast_button = Button.new()
	cast_button.text = "Cast"
	cast_button.custom_minimum_size = Vector2(120, 38)
	cast_button.pressed.connect(_cast_selected_spell)
	controls.add_child(cast_button)

	result_log = TextEdit.new()
	result_log.editable = false
	result_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	result_log.custom_minimum_size = Vector2(0, 500)
	result_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(result_log)


func _cast_selected_spell() -> void:
	var spell_id := int(spell_id_input.value)
	status_label.text = "Casting"
	cast_button.disabled = true

	var bridge := ProtocolClientBridge.new()
	var result := bridge.cast_spell(TEST_CHARACTER_NAME, spell_id)
	cast_button.disabled = false

	var ok := bool(result.get("ok", false))
	status_label.text = "Accepted" if ok else "Failed"
	_render_result(result)
	if ok:
		print("SPELL_CAST_VIEW_READY spell_id=%s opcode=0x%s accepted=true" % [
			str(result.get("spell_id", spell_id)),
			"%03x" % int(result.get("response_opcode", 0)),
		])
		_finish_self_test(true, result)
	else:
		_finish_self_test(false, result)


func _render_result(result: Dictionary) -> void:
	var lines := PackedStringArray()
	lines.append("Character: " + TEST_CHARACTER_NAME)
	lines.append("Spell id: " + str(result.get("spell_id", int(spell_id_input.value))))
	lines.append("Cast sent: " + str(result.get("cast_sent", false)))
	lines.append("Logged in world: " + str(result.get("logged_in_world", false)))
	lines.append("Response seen: " + str(result.get("response_seen", false)))
	lines.append("Accepted: " + str(result.get("accepted", false)))
	lines.append("Response opcode: 0x" + ("%03x" % int(result.get("response_opcode", 0))))
	lines.append("Response spell id: " + str(result.get("response_spell_id", 0)))
	lines.append("Cast count: " + str(result.get("cast_count", 0)))
	lines.append("Cast flags: 0x" + ("%x" % int(result.get("cast_flags", 0))))
	lines.append("Fail reason: " + str(result.get("fail_reason", 0)))
	lines.append("Spell start: " + str(result.get("spell_start", false)))
	lines.append("Spell go: " + str(result.get("spell_go", false)))
	lines.append("Cast failed: " + str(result.get("cast_failed", false)))
	lines.append("Spell failure: " + str(result.get("spell_failure", false)))
	if result.has("source"):
		lines.append("Source: " + str(result["source"]))
	var output := str(result.get("output", "")).strip_edges()
	if not output.is_empty() and not bool(result.get("ok", false)):
		lines.append("")
		lines.append(output)
	result_log.text = "\n".join(lines)


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_SPELL_CAST_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("SPELL_CAST_SELF_TEST_OK spell_id=%s opcode=0x%s accepted=%s" % [
			str(result.get("spell_id", DEFAULT_SPELL_ID)),
			"%03x" % int(result.get("response_opcode", 0)),
			str(result.get("accepted", false)),
		])
		get_tree().quit(0)
	else:
		push_error("SPELL_CAST_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
