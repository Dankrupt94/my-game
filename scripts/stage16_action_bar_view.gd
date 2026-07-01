extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const SLOT_COUNT := 144
const DEFAULT_TARGETED_SPELL_ID := 78
const DEFAULT_TARGET_ENTRY := 721
const DEFAULT_TARGET_NAME := "Nearby Creature"

var status_label: Label
var target_entry_input: SpinBox
var target_name_input: LineEdit
var slot_grid: GridContainer
var detail_log: TextEdit
var last_buttons: Array = []
var last_cast_result := {}
var self_test_finished := false


func _ready() -> void:
	_build_view()
	call_deferred("_load_action_buttons")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.06, 0.065)
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
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)

	var title := Label.new()
	title.text = "Action Bar"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Loading"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	var target_controls := HBoxContainer.new()
	target_controls.add_theme_constant_override("separation", 10)
	stack.add_child(target_controls)

	var target_label := Label.new()
	target_label.text = "Target"
	target_label.custom_minimum_size = Vector2(72, 34)
	target_controls.add_child(target_label)

	target_entry_input = SpinBox.new()
	target_entry_input.min_value = 1
	target_entry_input.max_value = 9999999
	target_entry_input.step = 1
	target_entry_input.value = DEFAULT_TARGET_ENTRY
	target_entry_input.custom_minimum_size = Vector2(130, 34)
	target_controls.add_child(target_entry_input)

	target_name_input = LineEdit.new()
	target_name_input.text = DEFAULT_TARGET_NAME
	target_name_input.custom_minimum_size = Vector2(180, 34)
	target_controls.add_child(target_name_input)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	stack.add_child(scroll)

	slot_grid = GridContainer.new()
	slot_grid.columns = 12
	slot_grid.add_theme_constant_override("h_separation", 8)
	slot_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(slot_grid)

	detail_log = TextEdit.new()
	detail_log.editable = false
	detail_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	detail_log.custom_minimum_size = Vector2(0, 250)
	stack.add_child(detail_log)


func _load_action_buttons() -> void:
	var bridge := ProtocolClientBridge.new()
	var result := bridge.action_buttons(TEST_CHARACTER_NAME)
	if not bool(result.get("ok", false)):
		status_label.text = "Failed"
		detail_log.text = str(result.get("error", result.get("output", "Unknown failure")))
		_finish_self_test(false, result)
		return

	var buttons: Array = result.get("buttons", [])
	last_buttons = buttons
	var populated_count := int(result.get("populated_count", _count_populated(buttons)))
	status_label.text = "Slots: " + str(result.get("slot_count", SLOT_COUNT)) + "  Used: " + str(populated_count)
	_render_slots(buttons)
	_render_details(result, buttons)
	print("ACTION_BAR_VIEW_READY slots=%s populated=%s state=%s" % [
		str(result.get("slot_count", 0)),
		str(populated_count),
		str(result.get("state", 0)),
	])
	if OS.get_environment("ACORE_ACTION_BAR_CAST_SELF_TEST") == "1":
		call_deferred("_cast_default_action_button")
	else:
		_finish_self_test(true, result)


func _render_slots(buttons: Array) -> void:
	for child in slot_grid.get_children():
		child.queue_free()

	var by_slot := {}
	for button in buttons:
		if typeof(button) == TYPE_DICTIONARY:
			by_slot[int(button.get("button", -1))] = button

	for slot in range(0, SLOT_COUNT):
		var button: Dictionary = by_slot.get(slot, {})
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(92, 54)
		if button.is_empty() or not bool(button.get("populated", true)):
			slot_button.text = str(slot) + "\nempty"
			slot_button.disabled = true
		else:
			slot_button.text = str(slot) + "\n" + _action_type_name(int(button.get("type", 0))) + " " + str(button.get("action", 0))
			slot_button.disabled = int(button.get("type", -1)) != 0
			if not slot_button.disabled:
				slot_button.pressed.connect(_cast_action_button.bind(button))
		slot_grid.add_child(slot_button)


func _render_details(result: Dictionary, buttons: Array) -> void:
	var lines := PackedStringArray()
	lines.append("Character: " + TEST_CHARACTER_NAME)
	lines.append("Action buttons seen: " + str(result.get("action_buttons_seen", false)))
	lines.append("Logged in world: " + str(result.get("logged_in_world", false)))
	lines.append("State: " + str(result.get("state", 0)))
	lines.append("Slots: " + str(result.get("slot_count", SLOT_COUNT)))
	lines.append("Populated: " + str(result.get("populated_count", _count_populated(buttons))))
	lines.append("")

	var shown := 0
	for button in buttons:
		if typeof(button) != TYPE_DICTIONARY:
			continue
		if not bool(button.get("populated", true)):
			continue
		lines.append("Button " + str(button.get("button", "?")) \
			+ "  " + _action_type_name(int(button.get("type", 0))) \
			+ " action " + str(button.get("action", "?")) \
			+ "  packed " + str(button.get("packed", "")))
		shown += 1
		if shown >= 80:
			break
	if shown == 0:
		lines.append("No populated action slots were reported by the server.")
	if not last_cast_result.is_empty():
		lines.append("")
		lines.append("Last action-button cast")
		lines.append("Button: " + str(last_cast_result.get("button", "?")))
		lines.append("Spell id: " + str(last_cast_result.get("spell_id", 0)))
		lines.append("Targeted: " + str(last_cast_result.get("targeted", false)))
		lines.append("Target found: " + str(last_cast_result.get("live_target_found", false)))
		lines.append("Accepted: " + str(last_cast_result.get("accepted", false)))
		lines.append("Response opcode: 0x" + ("%03x" % int(last_cast_result.get("response_opcode", 0))))
		lines.append("Response spell id: " + str(last_cast_result.get("response_spell_id", 0)))
		lines.append("Spell start: " + str(last_cast_result.get("spell_start", false)))
		lines.append("Spell go: " + str(last_cast_result.get("spell_go", false)))
	detail_log.text = "\n".join(lines)


func _cast_default_action_button() -> void:
	for button in last_buttons:
		if typeof(button) != TYPE_DICTIONARY:
			continue
		if not bool(button.get("populated", true)):
			continue
		if int(button.get("type", -1)) == 0 and int(button.get("action", 0)) == DEFAULT_TARGETED_SPELL_ID:
			_cast_action_button(button)
			return

	_finish_self_test(false, {
		"error": "No populated spell action button for spell " + str(DEFAULT_TARGETED_SPELL_ID),
	})


func _cast_action_button(action_button: Dictionary) -> void:
	var spell_id := int(action_button.get("action", 0))
	var slot := int(action_button.get("button", -1))
	if spell_id <= 0:
		last_cast_result = {
			"button": slot,
			"spell_id": spell_id,
			"accepted": false,
			"error": "Action button does not contain a spell id",
		}
		_render_details({"action_buttons_seen": true}, last_buttons)
		_finish_self_test(false, last_cast_result)
		return

	status_label.text = "Casting slot " + str(slot)
	var bridge := ProtocolClientBridge.new()
	var targeted := spell_id == DEFAULT_TARGETED_SPELL_ID
	var result: Dictionary
	if targeted:
		result = bridge.cast_spell_at_target(
			TEST_CHARACTER_NAME,
			spell_id,
			int(target_entry_input.value),
			target_name_input.text.strip_edges())
	else:
		result = bridge.cast_spell(TEST_CHARACTER_NAME, spell_id)

	result["button"] = slot
	result["spell_id"] = spell_id
	result["targeted"] = targeted
	last_cast_result = result
	status_label.text = "Cast accepted" if bool(result.get("ok", false)) else "Cast failed"
	_render_details({"action_buttons_seen": true}, last_buttons)

	if bool(result.get("ok", false)):
		print("ACTION_BAR_CAST_READY button=%s spell_id=%s opcode=0x%s accepted=true" % [
			str(slot),
			str(spell_id),
			"%03x" % int(result.get("response_opcode", 0)),
		])
		_finish_self_test(true, result)
	else:
		_finish_self_test(false, result)


func _count_populated(buttons: Array) -> int:
	var count := 0
	for button in buttons:
		if typeof(button) == TYPE_DICTIONARY and bool(button.get("populated", true)):
			count += 1
	return count


func _action_type_name(action_type: int) -> String:
	match action_type:
		0:
			return "spell"
		1:
			return "click"
		32:
			return "equip"
		64:
			return "macro"
		65:
			return "macro"
		128:
			return "item"
		_:
			return "type " + str(action_type)


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	var load_self_test := OS.get_environment("ACORE_ACTION_BAR_SELF_TEST") == "1"
	var cast_self_test := OS.get_environment("ACORE_ACTION_BAR_CAST_SELF_TEST") == "1"
	if not load_self_test and not cast_self_test:
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		if cast_self_test:
			print("ACTION_BAR_CAST_SELF_TEST_OK button=%s spell_id=%s opcode=0x%s accepted=%s" % [
				str(result.get("button", "?")),
				str(result.get("spell_id", DEFAULT_TARGETED_SPELL_ID)),
				"%03x" % int(result.get("response_opcode", 0)),
				str(result.get("accepted", false)),
			])
		else:
			print("ACTION_BAR_SELF_TEST_OK slots=%s populated=%s state=%s" % [
				str(result.get("slot_count", 0)),
				str(result.get("populated_count", 0)),
				str(result.get("state", 0)),
			])
		get_tree().quit(0)
	else:
		push_error("ACTION_BAR_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
