extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const TRAINER_TARGET_ENTRY := 911
const TRAINER_TARGET_NAME := "Nearby Trainer"
const TRAINER_BUY_TEST_SPELL_ID := 6673
const SMSG_TRAINER_LIST := 0x1B1
const SMSG_TRAINER_BUY_SUCCEEDED := 0x1B3
const SMSG_TRAINER_BUY_FAILED := 0x1B4

var status_label: Label
var target_label: Label
var trainer_label: Label
var target_entry_input: SpinBox
var target_name_input: LineEdit
var target_picker: ItemList
var spell_list: ItemList
var visible_targets: Array = []
var selected_target_selector := ""
var applying_scanned_target := false


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_TRAINER_TARGET_PICKER_SELF_TEST") == "1":
		call_deferred("_run_target_picker_self_test")
	elif OS.get_environment("ACORE_TRAINER_BUY_SUCCESS_SELF_TEST") == "1":
		call_deferred("_run_trainer_buy_success_probe")
	elif OS.get_environment("ACORE_TRAINER_BUY_SELF_TEST") == "1":
		call_deferred("_run_trainer_buy_probe")
	elif OS.get_environment("ACORE_TRAINER_LIST_SELF_TEST") == "1":
		call_deferred("_run_trainer_list_probe")
	else:
		call_deferred("_scan_visible_targets")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.052, 0.05, 0.046)
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
	title.text = "Trainer"
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
	target_label.text = "Waiting for AzerothCore trainer response."
	stack.add_child(target_label)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	stack.add_child(target_row)

	var target_caption := Label.new()
	target_caption.text = "Target"
	target_caption.custom_minimum_size = Vector2(64, 34)
	target_row.add_child(target_caption)

	target_entry_input = SpinBox.new()
	target_entry_input.min_value = 1
	target_entry_input.max_value = 9999999
	target_entry_input.step = 1
	target_entry_input.value = TRAINER_TARGET_ENTRY
	target_entry_input.custom_minimum_size = Vector2(130, 34)
	target_entry_input.value_changed.connect(_on_target_manual_changed)
	target_row.add_child(target_entry_input)

	target_name_input = LineEdit.new()
	target_name_input.text = TRAINER_TARGET_NAME
	target_name_input.custom_minimum_size = Vector2(210, 34)
	target_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_name_input.text_changed.connect(_on_target_name_changed)
	target_row.add_child(target_name_input)

	var scan_button := Button.new()
	scan_button.text = "Scan"
	scan_button.custom_minimum_size = Vector2(82, 34)
	scan_button.pressed.connect(_scan_visible_targets)
	target_row.add_child(scan_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.custom_minimum_size = Vector2(96, 34)
	refresh_button.pressed.connect(_run_trainer_list_probe)
	target_row.add_child(refresh_button)

	var learn_button := Button.new()
	learn_button.text = "Try Learn"
	learn_button.custom_minimum_size = Vector2(108, 34)
	learn_button.pressed.connect(_run_trainer_buy_probe)
	target_row.add_child(learn_button)

	var verify_button := Button.new()
	verify_button.text = "Verify Learn"
	verify_button.custom_minimum_size = Vector2(120, 34)
	verify_button.pressed.connect(_run_trainer_buy_success_probe)
	target_row.add_child(verify_button)

	target_picker = ItemList.new()
	target_picker.custom_minimum_size = Vector2(0, 110)
	target_picker.item_selected.connect(_on_target_selected)
	stack.add_child(target_picker)

	trainer_label = Label.new()
	trainer_label.text = "Trainer: idle"
	trainer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(trainer_label)

	spell_list = ItemList.new()
	spell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spell_list)


func _run_trainer_list_probe() -> void:
	status_label.text = "Running"
	trainer_label.text = "Trainer: loading"
	spell_list.clear()

	var bridge := ProtocolClientBridge.new()
	var result := bridge.trainer_list_probe_selector(TEST_CHARACTER_NAME, _target_selector(), _target_name())
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Trainer list probe failed", result)
		_finish_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Target %s entry %s, moved close=%s, returned=%s, response opcode 0x%s." % [
		str(result.get("target_guid", "0x0")),
		str(result.get("target_entry", _target_entry())),
		str(result.get("approach_movement_sent", false)),
		str(result.get("return_movement_sent", false)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	]
	_render_trainer(result)
	print("TRAINER_LIST_SELF_TEST_READY target_entry=%s moved_close=%s returned=%s spell_count=%s opcode=0x%s" % [
		str(result.get("target_entry", _target_entry())),
		str(result.get("approach_movement_sent", false)),
		str(result.get("return_movement_sent", false)),
		str(result.get("spell_count", 0)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_self_test(true, result)


func _run_trainer_buy_probe() -> void:
	status_label.text = "Running"
	trainer_label.text = "Trainer: sending spell request"
	spell_list.clear()

	var bridge := ProtocolClientBridge.new()
	var result := bridge.trainer_buy_spell_probe_selector(
		TEST_CHARACTER_NAME,
		_target_selector(),
		_target_name(),
		TRAINER_BUY_TEST_SPELL_ID)
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Trainer buy probe failed", result)
		_finish_buy_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Target %s entry %s, moved close=%s, returned=%s, buy opcode 0x%s." % [
		str(result.get("target_guid", "0x0")),
		str(result.get("target_entry", _target_entry())),
		str(result.get("approach_movement_sent", false)),
		str(result.get("return_movement_sent", false)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	]
	_render_trainer_buy(result)
	print("TRAINER_BUY_SELF_TEST_READY target_entry=%s spell_id=%s moved_close=%s returned=%s succeeded=%s failed=%s failure_reason=%s opcode=0x%s" % [
		str(result.get("target_entry", _target_entry())),
		str(result.get("spell_id", TRAINER_BUY_TEST_SPELL_ID)),
		str(result.get("approach_movement_sent", false)),
		str(result.get("return_movement_sent", false)),
		str(result.get("buy_succeeded", false)),
		str(result.get("buy_failed", false)),
		str(result.get("failure_reason", 0)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_buy_self_test(true, result)


func _run_trainer_buy_success_probe() -> void:
	status_label.text = "Running"
	trainer_label.text = "Trainer: verifying spell learn"
	spell_list.clear()

	var bridge := ProtocolClientBridge.new()
	var before_inventory := bridge.inventory_snapshot(TEST_CHARACTER_NAME)
	if not bool(before_inventory.get("ok", false)):
		var inventory_failure := {
			"ok": false,
			"error": "before inventory snapshot failed",
			"before_inventory": before_inventory,
		}
		status_label.text = "Failed"
		target_label.text = _failure_summary("Trainer buy success probe failed", inventory_failure)
		_finish_buy_success_self_test(false, inventory_failure)
		return

	var before_spellbook := bridge.spellbook(TEST_CHARACTER_NAME)
	if not bool(before_spellbook.get("ok", false)):
		var spellbook_failure := {
			"ok": false,
			"error": "before spellbook snapshot failed",
			"before_spellbook": before_spellbook,
		}
		status_label.text = "Failed"
		target_label.text = _failure_summary("Trainer buy success probe failed", spellbook_failure)
		_finish_buy_success_self_test(false, spellbook_failure)
		return

	var spell_known_before := _spellbook_has_spell(before_spellbook, TRAINER_BUY_TEST_SPELL_ID)
	if spell_known_before:
		var learned_failure := {
			"ok": false,
			"error": "test spell is already learned; run tools/prepare_trainer_buy_fixture.py first",
			"spell_id": TRAINER_BUY_TEST_SPELL_ID,
			"spell_known_before": true,
			"before_coinage": int(before_inventory.get("coinage", 0)),
		}
		status_label.text = "Failed"
		target_label.text = _failure_summary("Trainer buy success probe failed", learned_failure)
		_finish_buy_success_self_test(false, learned_failure)
		return

	var buy_result := bridge.trainer_buy_spell_probe_selector(
		TEST_CHARACTER_NAME,
		_target_selector(),
		_target_name(),
		TRAINER_BUY_TEST_SPELL_ID)
	var after_inventory := bridge.inventory_snapshot(TEST_CHARACTER_NAME)
	var after_spellbook := bridge.spellbook(TEST_CHARACTER_NAME)

	var result := buy_result.duplicate(true)
	result["before_coinage"] = int(before_inventory.get("coinage", 0))
	result["after_coinage"] = int(after_inventory.get("coinage", 0))
	result["coinage_delta"] = int(result["after_coinage"]) - int(result["before_coinage"])
	result["before_coinage_seen"] = bool(before_inventory.get("coinage_seen", false))
	result["after_coinage_seen"] = bool(after_inventory.get("coinage_seen", false))
	result["spell_known_before"] = spell_known_before
	result["spell_known_after"] = _spellbook_has_spell(after_spellbook, TRAINER_BUY_TEST_SPELL_ID)
	result["after_inventory_ok"] = bool(after_inventory.get("ok", false))
	result["after_spellbook_ok"] = bool(after_spellbook.get("ok", false))
	result["success_verified"] = bool(result.get("buy_succeeded", false)) \
		and not bool(result["spell_known_before"]) \
		and bool(result["spell_known_after"]) \
		and bool(result["before_coinage_seen"]) \
		and bool(result["after_coinage_seen"]) \
		and int(result["coinage_delta"]) < 0

	status_label.text = "Ready" if bool(result["success_verified"]) else "Failed"
	target_label.text = "Spell %s learned=%s, money %s -> %s." % [
		str(TRAINER_BUY_TEST_SPELL_ID),
		str(result["spell_known_after"]),
		_money_text(int(result["before_coinage"])),
		_money_text(int(result["after_coinage"])),
	]
	_render_trainer_buy_success(result)
	print("TRAINER_BUY_SUCCESS_SELF_TEST_READY spell_id=%s succeeded=%s before_known=%s after_known=%s before_coinage=%s after_coinage=%s coinage_delta=%s opcode=0x%s" % [
		str(TRAINER_BUY_TEST_SPELL_ID),
		str(result.get("buy_succeeded", false)),
		str(result["spell_known_before"]),
		str(result["spell_known_after"]),
		str(result["before_coinage"]),
		str(result["after_coinage"]),
		str(result["coinage_delta"]),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_buy_success_self_test(bool(result["success_verified"]), result)


func _run_target_picker_self_test() -> void:
	_scan_visible_targets(true)


func _scan_visible_targets(finish_self_test := false) -> Dictionary:
	status_label.text = "Scanning"
	trainer_label.text = "Trainer: scanning"
	spell_list.clear()
	target_picker.clear()
	target_picker.add_item("Scanning live visible units...")

	var bridge := ProtocolClientBridge.new()
	var result := bridge.visible_targets_snapshot(TEST_CHARACTER_NAME)
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Trainer target scan failed", result)
		target_picker.clear()
		target_picker.add_item("Target scan failed")
		if finish_self_test:
			_finish_target_picker_self_test(false, result)
		return result

	visible_targets = _extract_visible_targets(result)
	target_picker.clear()
	if visible_targets.is_empty():
		status_label.text = "Failed"
		target_label.text = "No visible unit targets were available in the login update."
		target_picker.add_item("No visible unit targets")
		result["target_picker_count"] = 0
		if finish_self_test:
			_finish_target_picker_self_test(false, result)
		return result

	for target in visible_targets:
		if typeof(target) != TYPE_DICTIONARY:
			continue
		var index := target_picker.add_item(_target_picker_text(target))
		target_picker.set_item_metadata(index, target)

	var selected_index := _default_target_index(visible_targets)
	target_picker.select(selected_index)
	var selected: Dictionary = visible_targets[selected_index]
	_apply_target(selected)
	status_label.text = "Ready"
	trainer_label.text = "Trainer: target selected"
	target_label.text = "Selected %s from %s visible unit target(s)." % [
		_target_picker_text(selected),
		str(visible_targets.size()),
	]

	result["target_picker_count"] = visible_targets.size()
	result["selected_target"] = selected
	print("TRAINER_TARGET_PICKER_SELF_TEST_READY target_count=%s selected_entry=%s selected_guid=%s distance=%s" % [
		str(visible_targets.size()),
		str(selected.get("entry", 0)),
		str(selected.get("guid", "0x0")),
		str(selected.get("distance", 0.0)),
	])
	if finish_self_test:
		_finish_target_picker_self_test(true, result)
	return result


func _target_entry() -> int:
	if target_entry_input == null:
		return TRAINER_TARGET_ENTRY
	return int(target_entry_input.value)


func _target_name() -> String:
	if target_name_input == null:
		return TRAINER_TARGET_NAME
	var value := target_name_input.text.strip_edges()
	return TRAINER_TARGET_NAME if value.is_empty() else value


func _target_selector() -> String:
	if not selected_target_selector.is_empty():
		return selected_target_selector
	return str(_target_entry())


func _on_target_manual_changed(_value: float) -> void:
	if not applying_scanned_target:
		selected_target_selector = ""


func _on_target_name_changed(_value: String) -> void:
	if not applying_scanned_target:
		selected_target_selector = ""


func _on_target_selected(index: int) -> void:
	if target_picker == null or index < 0 or index >= target_picker.item_count:
		return
	var metadata = target_picker.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return
	var target: Dictionary = metadata
	_apply_target(target)
	target_label.text = "Selected " + _target_picker_text(target) + "."


func _apply_target(target: Dictionary) -> void:
	applying_scanned_target = true
	selected_target_selector = str(target.get("guid", "")).strip_edges()
	target_entry_input.value = int(target.get("entry", TRAINER_TARGET_ENTRY))
	target_name_input.text = _target_name_from_visible(target)
	applying_scanned_target = false


func _extract_visible_targets(result: Dictionary) -> Array:
	var login: Dictionary = result.get("login", {})
	var update: Dictionary = result.get("update", {})
	var objects: Array = []
	if typeof(update.get("visible_objects", [])) == TYPE_ARRAY and not update.get("visible_objects", []).is_empty():
		objects = update.get("visible_objects", [])
	elif typeof(result.get("visible_objects", [])) == TYPE_ARRAY:
		objects = result.get("visible_objects", [])

	var targets: Array = []
	var seen := {}
	for object in objects:
		if typeof(object) != TYPE_DICTIONARY:
			continue
		var entry := int(object.get("entry", 0))
		var object_type := int(object.get("object_type", object.get("type", 0)))
		var guid := str(object.get("guid", ""))
		if entry <= 0 or object_type != 3 or not bool(object.get("has_position", false)):
			continue
		if seen.has(guid):
			continue
		seen[guid] = true
		var target: Dictionary = object.duplicate(true)
		target["distance"] = _distance_from_login(login, object)
		targets.append(target)

	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 999999.0)) < float(b.get("distance", 999999.0)))
	return targets


func _default_target_index(targets: Array) -> int:
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		if int(target.get("entry", 0)) == TRAINER_TARGET_ENTRY:
			return index
	return 0


func _distance_from_login(login: Dictionary, object: Dictionary) -> float:
	if login.is_empty():
		return 0.0
	var dx := float(object.get("x", 0.0)) - float(login.get("x", 0.0))
	var dy := float(object.get("y", 0.0)) - float(login.get("y", 0.0))
	var dz := float(object.get("z", 0.0)) - float(login.get("z", 0.0))
	return sqrt(dx * dx + dy * dy + dz * dz)


func _target_picker_text(target: Dictionary) -> String:
	return "%s, %.1fm" % [
		_target_name_from_visible(target),
		float(target.get("distance", 0.0)),
	]


func _target_name_from_visible(target: Dictionary) -> String:
	var name := str(target.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	var entry := int(target.get("entry", 0))
	if entry == TRAINER_TARGET_ENTRY:
		return TRAINER_TARGET_NAME
	return "Unit " + str(entry)


func _render_trainer(result: Dictionary) -> void:
	var greeting := str(result.get("greeting", "")).strip_edges()
	var spell_count := int(result.get("spell_count", 0))
	trainer_label.text = "Trainer type %s, %s spell(s). %s" % [
		str(result.get("trainer_type", 0)),
		str(spell_count),
		greeting,
	]

	var spells: Array = result.get("spells", [])
	if spells.is_empty():
		spell_list.add_item("No trainable spells returned")
		return

	for spell in spells:
		if typeof(spell) != TYPE_DICTIONARY:
			continue
		var item_index := spell_list.add_item(_trainer_spell_row(spell))
		spell_list.set_item_disabled(item_index, int(spell.get("usable", 0)) != 0)


func _render_trainer_buy(result: Dictionary) -> void:
	var spell_id := int(result.get("spell_id", TRAINER_BUY_TEST_SPELL_ID))
	if bool(result.get("buy_succeeded", false)):
		trainer_label.text = "Learned spell %s." % str(spell_id)
		spell_list.add_item("Spell %s learned by server response" % str(spell_id))
		return

	var reason := int(result.get("failure_reason", 0))
	trainer_label.text = "Spell %s was not learned: %s." % [
		str(spell_id),
		_trainer_failure_reason(reason),
	]
	spell_list.add_item("Spell %s failed: %s" % [
		str(spell_id),
		_trainer_failure_reason(reason),
	])
	if int(result.get("spell_count", 0)) > 0:
		spell_list.add_item("Trainer list was visible with %s spell row(s)" % str(result.get("spell_count", 0)))


func _render_trainer_buy_success(result: Dictionary) -> void:
	trainer_label.text = "Learned spell %s, money changed by %s." % [
		str(TRAINER_BUY_TEST_SPELL_ID),
		_money_text(abs(int(result.get("coinage_delta", 0)))),
	]
	spell_list.add_item("Spell known before: %s" % str(result.get("spell_known_before", false)))
	spell_list.add_item("Spell known after: %s" % str(result.get("spell_known_after", false)))
	spell_list.add_item("Money before: %s" % _money_text(int(result.get("before_coinage", 0))))
	spell_list.add_item("Money after: %s" % _money_text(int(result.get("after_coinage", 0))))
	spell_list.add_item("Trainer response opcode: 0x%s" % _opcode_hex(int(result.get("response_opcode", 0))))


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_TRAINER_LIST_SELF_TEST") != "1":
		return
	if ok \
			and bool(result.get("trainer_list_response_seen", false)) \
			and int(result.get("spell_count", 0)) > 0 \
			and int(result.get("response_opcode", 0)) == SMSG_TRAINER_LIST:
		print("TRAINER_LIST_SELF_TEST_OK spell_count=%s response_opcode=0x%s" % [
			str(result.get("spell_count", 0)),
			_opcode_hex(int(result.get("response_opcode", 0))),
		])
		get_tree().quit(0)
		return

	push_error("TRAINER_LIST_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)


func _finish_buy_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_TRAINER_BUY_SELF_TEST") != "1":
		return
	var opcode := int(result.get("response_opcode", 0))
	if ok \
			and bool(result.get("trainer_list_response_seen", false)) \
			and bool(result.get("buy_spell_sent", false)) \
			and bool(result.get("buy_response_seen", false)) \
			and (opcode == SMSG_TRAINER_BUY_SUCCEEDED or opcode == SMSG_TRAINER_BUY_FAILED):
		print("TRAINER_BUY_SELF_TEST_OK spell_id=%s succeeded=%s failed=%s failure_reason=%s response_opcode=0x%s" % [
			str(result.get("spell_id", TRAINER_BUY_TEST_SPELL_ID)),
			str(result.get("buy_succeeded", false)),
			str(result.get("buy_failed", false)),
			str(result.get("failure_reason", 0)),
			_opcode_hex(opcode),
		])
		get_tree().quit(0)
		return

	push_error("TRAINER_BUY_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)


func _finish_target_picker_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_TRAINER_TARGET_PICKER_SELF_TEST") != "1":
		return
	var selected: Dictionary = result.get("selected_target", {})
	if ok \
			and int(result.get("target_picker_count", 0)) > 0 \
			and int(selected.get("entry", 0)) == TRAINER_TARGET_ENTRY \
			and not str(selected.get("guid", "")).is_empty():
		print("TRAINER_TARGET_PICKER_SELF_TEST_OK target_count=%s selected_entry=%s selected_guid=%s" % [
			str(result.get("target_picker_count", 0)),
			str(selected.get("entry", 0)),
			str(selected.get("guid", "0x0")),
		])
		get_tree().quit(0)
		return

	push_error("TRAINER_TARGET_PICKER_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)


func _finish_buy_success_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_TRAINER_BUY_SUCCESS_SELF_TEST") != "1":
		return
	if ok \
			and bool(result.get("success_verified", false)) \
			and bool(result.get("buy_succeeded", false)) \
			and int(result.get("response_opcode", 0)) == SMSG_TRAINER_BUY_SUCCEEDED:
		print("TRAINER_BUY_SUCCESS_SELF_TEST_OK spell_id=%s coinage_delta=%s response_opcode=0x%s" % [
			str(TRAINER_BUY_TEST_SPELL_ID),
			str(result.get("coinage_delta", 0)),
			_opcode_hex(int(result.get("response_opcode", 0))),
		])
		get_tree().quit(0)
		return

	push_error("TRAINER_BUY_SUCCESS_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)


func _failure_summary(prefix: String, result: Dictionary) -> String:
	var source := str(result.get("source", "unknown source"))
	var output := str(result.get("output", "")).strip_edges()
	if output.length() > 420:
		output = output.substr(0, 420) + "..."
	if output.is_empty():
		return "%s via %s." % [prefix, source]
	return "%s via %s: %s" % [prefix, source, output]


func _trainer_failure_reason(reason: int) -> String:
	match reason:
		0:
			return "unavailable"
		1:
			return "not enough money"
		2:
			return "not enough skill"
		_:
			return "failure " + str(reason)


func _trainer_spell_row(spell: Dictionary) -> String:
	return "Spell %s | %s | %s | %s" % [
		str(spell.get("spell_id", 0)),
		_trainer_spell_status(int(spell.get("usable", 0))),
		_money_text(int(spell.get("money_cost", 0))),
		_trainer_spell_requirements(spell),
	]


func _trainer_spell_status(state: int) -> String:
	match state:
		0:
			return "available"
		1:
			return "unavailable"
		2:
			return "known"
		_:
			return "state " + str(state)


func _trainer_spell_requirements(spell: Dictionary) -> String:
	var parts: Array[String] = []
	var req_level := int(spell.get("req_level", 0))
	if req_level > 0:
		parts.append("level " + str(req_level))
	var skill_line := int(spell.get("req_skill_line", 0))
	var skill_rank := int(spell.get("req_skill_rank", 0))
	if skill_line > 0 or skill_rank > 0:
		parts.append("skill %s/%s" % [str(skill_line), str(skill_rank)])
	for ability_key in ["req_ability_1", "req_ability_2", "req_ability_3"]:
		var ability := int(spell.get(ability_key, 0))
		if ability > 0:
			parts.append("spell " + str(ability))
	if parts.is_empty():
		return "no extra requirements"
	return ", ".join(parts)


func _money_text(copper: int) -> String:
	var gold := copper / 10000
	var silver := (copper / 100) % 100
	var copper_only := copper % 100
	if gold > 0:
		return "%sg %ss %sc" % [str(gold), str(silver), str(copper_only)]
	if silver > 0:
		return "%ss %sc" % [str(silver), str(copper_only)]
	return "%sc" % str(copper_only)


func _spellbook_has_spell(result: Dictionary, spell_id: int) -> bool:
	var spells: Array = result.get("spells", [])
	for spell in spells:
		if typeof(spell) != TYPE_DICTIONARY:
			continue
		if int(spell.get("id", spell.get("spell_id", 0))) == spell_id:
			return true
	return false


func _opcode_hex(value: int) -> String:
	var text := "%x" % value
	if text.length() < 3:
		text = text.lpad(3, "0")
	return text
