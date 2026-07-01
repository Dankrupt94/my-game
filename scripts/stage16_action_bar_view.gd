extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const SLOT_COUNT := 144

var status_label: Label
var slot_grid: GridContainer
var detail_log: TextEdit
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
	var populated_count := int(result.get("populated_count", _count_populated(buttons)))
	status_label.text = "Slots: " + str(result.get("slot_count", SLOT_COUNT)) + "  Used: " + str(populated_count)
	_render_slots(buttons)
	_render_details(result, buttons)
	print("ACTION_BAR_VIEW_READY slots=%s populated=%s state=%s" % [
		str(result.get("slot_count", 0)),
		str(populated_count),
		str(result.get("state", 0)),
	])
	_finish_self_test(true, result)


func _render_slots(buttons: Array) -> void:
	for child in slot_grid.get_children():
		child.queue_free()

	var by_slot := {}
	for button in buttons:
		if typeof(button) == TYPE_DICTIONARY:
			by_slot[int(button.get("button", -1))] = button

	for slot in range(0, min(SLOT_COUNT, 48)):
		var button: Dictionary = by_slot.get(slot, {})
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(92, 54)
		slot_grid.add_child(panel)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if button.is_empty() or not bool(button.get("populated", true)):
			label.text = str(slot) + "\nempty"
		else:
			label.text = str(slot) + "\n" + _action_type_name(int(button.get("type", 0))) + " " + str(button.get("action", 0))
		panel.add_child(label)


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
	detail_log.text = "\n".join(lines)


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
	if OS.get_environment("ACORE_ACTION_BAR_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("ACTION_BAR_SELF_TEST_OK slots=%s populated=%s state=%s" % [
			str(result.get("slot_count", 0)),
			str(result.get("populated_count", 0)),
			str(result.get("state", 0)),
		])
		get_tree().quit(0)
	else:
		push_error("ACTION_BAR_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
