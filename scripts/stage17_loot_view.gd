extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const LOOT_TARGET_ENTRY := 38

var status_label: Label
var target_label: Label
var loot_label: Label
var item_list: ItemList
var self_test_finished := false


func _ready() -> void:
	_build_view()
	call_deferred("_run_loot_probe")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.055, 0.052)
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
	header.add_theme_constant_override("separation", 14)
	stack.add_child(header)

	var title := Label.new()
	title.text = "Loot"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Loading"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	target_label = Label.new()
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label.text = "Waiting for AzerothCore loot response."
	stack.add_child(target_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	stack.add_child(action_row)

	var refresh_button := Button.new()
	refresh_button.text = "Test Loot"
	refresh_button.pressed.connect(_run_loot_probe)
	action_row.add_child(refresh_button)

	loot_label = Label.new()
	loot_label.text = "Loot: idle"
	loot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(loot_label)

	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(item_list)


func _run_loot_probe() -> void:
	status_label.text = "Running"
	loot_label.text = "Loot: opening"
	item_list.clear()
	var bridge := ProtocolClientBridge.new()
	var result := bridge.loot_open_probe(TEST_CHARACTER_NAME, LOOT_TARGET_ENTRY, "Nearby Creature")
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = str(result.get("error", result.get("output", "Loot probe failed")))
		_finish_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Target %s entry %s, response opcode 0x%s." % [
		str(result.get("target_guid", "0x0")),
		str(result.get("target_entry", LOOT_TARGET_ENTRY)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	]
	_render_loot(result)
	print("LOOT_OPEN_SELF_TEST_READY target_entry=%s loot_response_seen=%s release_response_seen=%s loot_error=%s gold=%s item_count=%s opcode=0x%s" % [
		str(result.get("target_entry", LOOT_TARGET_ENTRY)),
		str(result.get("loot_response_seen", false)),
		str(result.get("loot_release_response_seen", false)),
		str(result.get("loot_error", false)),
		str(result.get("gold", 0)),
		str(result.get("item_count", 0)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_self_test(true, result)


func _render_loot(result: Dictionary) -> void:
	if bool(result.get("loot_response_seen", false)):
		if bool(result.get("loot_error", false)):
			loot_label.text = "Loot: error " + str(result.get("loot_error_code", 0))
			item_list.add_item("Server denied loot: error " + str(result.get("loot_error_code", 0)))
			return
		loot_label.text = "Loot: " + _money_text(int(result.get("gold", 0)))
		var items: Array = result.get("items", [])
		if items.is_empty():
			item_list.add_item("No item slots")
			return
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			item_list.add_item("Slot %s: item %s x%s" % [
				str(item.get("slot", 0)),
				str(item.get("item_id", 0)),
				str(item.get("count", 0)),
			])
		return

	if bool(result.get("loot_release_response_seen", false)):
		loot_label.text = "Loot: closed by server"
		item_list.add_item("The target is not lootable yet.")
		return

	loot_label.text = "Loot: no response"
	item_list.add_item("No loot response was received.")


func _money_text(copper: int) -> String:
	var gold := copper / 10000
	var silver := (copper / 100) % 100
	var copper_only := copper % 100
	return "%sg %ss %sc" % [str(gold), str(silver), str(copper_only)]


func _opcode_hex(value: int) -> String:
	return "%03x" % [value & 0xFFFF]


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_LOOT_OPEN_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("LOOT_OPEN_SELF_TEST_OK response_opcode=0x%s loot_response=%s release_response=%s" % [
			_opcode_hex(int(result.get("response_opcode", 0))),
			str(result.get("loot_response_seen", false)),
			str(result.get("loot_release_response_seen", false)),
		])
		get_tree().quit(0)
	else:
		push_error("LOOT_OPEN_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
