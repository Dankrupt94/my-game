extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const LOOT_OPEN_TARGET_ENTRY := 38
const CORPSE_LOOT_TARGET_ENTRY := 299

var status_label: Label
var target_label: Label
var loot_label: Label
var target_entry_input: SpinBox
var target_name_input: LineEdit
var target_picker: ItemList
var item_list: ItemList
var inventory_list: ItemList
var visible_targets: Array = []
var self_test_finished := false


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_LOOT_TARGET_PICKER_SELF_TEST") == "1":
		call_deferred("_run_target_picker_self_test")
	elif OS.get_environment("ACORE_LOOT_INVENTORY_SELF_TEST") == "1":
		call_deferred("_run_loot_inventory_handoff_probe")
	elif OS.get_environment("ACORE_CORPSE_LOOT_SELF_TEST") == "1":
		call_deferred("_run_corpse_loot_probe")
	elif OS.get_environment("ACORE_LOOT_OPEN_SELF_TEST") == "1":
		call_deferred("_run_loot_probe")
	else:
		call_deferred("_scan_visible_targets")


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
	target_entry_input.value = CORPSE_LOOT_TARGET_ENTRY
	target_entry_input.custom_minimum_size = Vector2(130, 34)
	target_row.add_child(target_entry_input)

	target_name_input = LineEdit.new()
	target_name_input.text = "Nearby Creature"
	target_name_input.custom_minimum_size = Vector2(180, 34)
	target_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_child(target_name_input)

	var scan_button := Button.new()
	scan_button.text = "Scan"
	scan_button.custom_minimum_size = Vector2(86, 34)
	scan_button.pressed.connect(_scan_visible_targets)
	target_row.add_child(scan_button)

	target_picker = ItemList.new()
	target_picker.custom_minimum_size = Vector2(0, 118)
	target_picker.item_selected.connect(_on_target_selected)
	stack.add_child(target_picker)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	stack.add_child(action_row)

	var refresh_button := Button.new()
	refresh_button.text = "Test Loot"
	refresh_button.pressed.connect(_run_loot_probe)
	action_row.add_child(refresh_button)

	var corpse_button := Button.new()
	corpse_button.text = "Fight + Loot"
	corpse_button.pressed.connect(_run_corpse_loot_probe)
	action_row.add_child(corpse_button)

	var handoff_button := Button.new()
	handoff_button.text = "Loot + Bag"
	handoff_button.pressed.connect(_run_loot_inventory_handoff_probe)
	action_row.add_child(handoff_button)

	loot_label = Label.new()
	loot_label.text = "Loot: idle"
	loot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(loot_label)

	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(item_list)

	inventory_list = ItemList.new()
	inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(inventory_list)


func _run_loot_probe() -> void:
	status_label.text = "Running"
	loot_label.text = "Loot: opening"
	item_list.clear()
	inventory_list.clear()
	var bridge := ProtocolClientBridge.new()
	var target_entry := LOOT_OPEN_TARGET_ENTRY
	var target_name := "Nearby Creature"
	if OS.get_environment("ACORE_LOOT_OPEN_SELF_TEST") != "1":
		target_entry = _target_entry()
		target_name = _target_name()
	var result := bridge.loot_open_probe(TEST_CHARACTER_NAME, target_entry, target_name)
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Loot probe failed", result)
		_finish_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Target %s entry %s, response opcode 0x%s." % [
		str(result.get("target_guid", "0x0")),
		str(result.get("target_entry", LOOT_OPEN_TARGET_ENTRY)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	]
	_render_loot(result)
	print("LOOT_OPEN_SELF_TEST_READY target_entry=%s loot_response_seen=%s release_response_seen=%s loot_error=%s gold=%s item_count=%s opcode=0x%s" % [
		str(result.get("target_entry", LOOT_OPEN_TARGET_ENTRY)),
		str(result.get("loot_response_seen", false)),
		str(result.get("loot_release_response_seen", false)),
		str(result.get("loot_error", false)),
		str(result.get("gold", 0)),
		str(result.get("item_count", 0)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_self_test(true, result)


func _run_corpse_loot_probe() -> void:
	status_label.text = "Running"
	loot_label.text = "Loot: fighting"
	item_list.clear()
	inventory_list.clear()
	var bridge := ProtocolClientBridge.new()
	var result := bridge.corpse_loot_probe(TEST_CHARACTER_NAME, _target_entry(), _target_name())
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Corpse loot probe failed", result)
		_finish_corpse_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Target %s died with lootable=%s, response opcode 0x%s." % [
		str(result.get("target_guid", "0x0")),
		str(result.get("target_lootable_seen", false)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	]
	_render_loot(result)
	print("CORPSE_LOOT_SELF_TEST_READY target_entry=%s dead=%s lootable=%s loot_response_seen=%s money_notify=%s item_removed=%s release_response=%s gold=%s item_count=%s opcode=0x%s" % [
		str(result.get("target_entry", _target_entry())),
		str(result.get("target_dead_seen", false)),
		str(result.get("target_lootable_seen", false)),
		str(result.get("loot_response_seen", false)),
		str(result.get("loot_money_notify_seen", false)),
		str(result.get("loot_item_removed_count", 0)),
		str(result.get("loot_release_response_seen", false)),
		str(result.get("gold", 0)),
		str(result.get("item_count", 0)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_corpse_self_test(true, result)


func _run_loot_inventory_handoff_probe() -> void:
	status_label.text = "Running"
	loot_label.text = "Loot: bag check"
	item_list.clear()
	inventory_list.clear()
	var bridge := ProtocolClientBridge.new()
	var result := bridge.loot_inventory_handoff_probe(TEST_CHARACTER_NAME, _target_entry(), _target_name())
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Loot inventory probe failed", result)
		_finish_loot_inventory_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Loot changed %s inventory slot(s); populated %s -> %s." % [
		str(result.get("changed_slot_count", 0)),
		str(result.get("before_populated", 0)),
		str(result.get("after_populated", 0)),
	]
	_render_loot(result)
	_render_inventory_changes(result)
	_render_inventory_after(result)
	print("LOOT_INVENTORY_SELF_TEST_READY target_entry=%s dead=%s loot_response_seen=%s item_removed=%s inventory_before=%s inventory_after=%s changed_slots=%s added_slots=%s stack_changed=%s coinage_delta=%s handoff=%s opcode=0x%s" % [
		str(result.get("target_entry", _target_entry())),
		str(result.get("target_dead_seen", false)),
		str(result.get("loot_response_seen", false)),
		str(result.get("loot_item_removed_count", 0)),
		str(result.get("inventory_before_seen", false)),
		str(result.get("inventory_after_seen", false)),
		str(result.get("changed_slot_count", 0)),
		str(result.get("added_slot_count", 0)),
		str(result.get("stack_changed_slot_count", 0)),
		str(result.get("coinage_delta", 0)),
		str(result.get("handoff_confirmed", false)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_loot_inventory_self_test(true, result)


func _run_target_picker_self_test() -> void:
	_scan_visible_targets(true)


func _scan_visible_targets(finish_self_test := false) -> Dictionary:
	status_label.text = "Scanning"
	loot_label.text = "Loot: idle"
	item_list.clear()
	inventory_list.clear()
	target_picker.clear()
	target_picker.add_item("Scanning live visible creatures...")

	var bridge := ProtocolClientBridge.new()
	var result := bridge.visible_targets_snapshot(TEST_CHARACTER_NAME)
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Target scan failed", result)
		target_picker.clear()
		target_picker.add_item("Target scan failed")
		if finish_self_test:
			_finish_target_picker_self_test(false, result)
		return result

	visible_targets = _extract_visible_targets(result)
	target_picker.clear()
	if visible_targets.is_empty():
		status_label.text = "Failed"
		target_label.text = "No live creature targets were visible in the login update."
		target_picker.add_item("No visible creature targets")
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
	target_label.text = "Selected %s from %s visible creature target(s)." % [
		_target_picker_text(selected),
		str(visible_targets.size()),
	]

	result["target_picker_count"] = visible_targets.size()
	result["selected_target"] = selected
	print("LOOT_TARGET_PICKER_SELF_TEST_READY target_count=%s selected_entry=%s selected_guid=%s distance=%s" % [
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
		return CORPSE_LOOT_TARGET_ENTRY
	return int(target_entry_input.value)


func _target_name() -> String:
	if target_name_input == null:
		return "Nearby Creature"
	var value := target_name_input.text.strip_edges()
	return "Nearby Creature" if value.is_empty() else value


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
	target_entry_input.value = int(target.get("entry", CORPSE_LOOT_TARGET_ENTRY))
	target_name_input.text = _target_name_from_visible(target)


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
		if int(target.get("entry", 0)) == CORPSE_LOOT_TARGET_ENTRY:
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
	var health_text := ""
	if bool(target.get("health_seen", false)):
		health_text = " hp %s/%s" % [
			str(target.get("health", 0)),
			str(target.get("max_health", 0)),
		]
	return "%s, %.1fm%s" % [
		_target_name_from_visible(target),
		float(target.get("distance", 0.0)),
		health_text,
	]


func _target_name_from_visible(target: Dictionary) -> String:
	var name := str(target.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	return "Creature " + str(target.get("entry", 0))


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


func _render_inventory_changes(result: Dictionary) -> void:
	var changed: Array = result.get("changed_slots", [])
	if changed.is_empty():
		item_list.add_item("Inventory did not change.")
		return
	item_list.add_item("Inventory changes:")
	for slot in changed:
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var item_name := str(slot.get("item_name", ""))
		if item_name.is_empty():
			item_name = "item " + str(slot.get("item_entry", 0))
		item_list.add_item("Bag slot %s: %s x%s" % [
			str(slot.get("slot", 0)),
			item_name,
			str(slot.get("stack_count", 0)),
		])


func _render_inventory_after(result: Dictionary) -> void:
	inventory_list.clear()
	var inventory: Dictionary = result.get("inventory_after", {})
	var slots: Array = inventory.get("slots", [])
	if slots.is_empty():
		var changed: Array = result.get("changed_slots", [])
		if changed.is_empty():
			inventory_list.add_item("Inventory snapshot unavailable")
			return
		inventory_list.add_item("Changed inventory slots")
		for slot in changed:
			if typeof(slot) == TYPE_DICTIONARY:
				inventory_list.add_item(_inventory_slot_text(slot))
		return

	inventory_list.add_item("Inventory after loot")
	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		if not bool(slot.get("populated", false)):
			continue
		inventory_list.add_item(_inventory_slot_text(slot))


func _inventory_slot_text(slot: Dictionary) -> String:
	var item_name := str(slot.get("item_name", ""))
	if item_name.is_empty():
		item_name = "item " + str(slot.get("item_entry", 0))
	return "Slot %s: %s x%s" % [
		str(slot.get("slot", 0)),
		item_name,
		str(slot.get("stack_count", 0)),
	]


func _money_text(copper: int) -> String:
	var gold := copper / 10000
	var silver := (copper / 100) % 100
	var copper_only := copper % 100
	return "%sg %ss %sc" % [str(gold), str(silver), str(copper_only)]


func _opcode_hex(value: int) -> String:
	return "%03x" % [value & 0xFFFF]


func _failure_summary(prefix: String, result: Dictionary) -> String:
	var details: Array[String] = [
		"target_entry=" + str(result.get("target_entry", "?")),
		"live_target=" + str(result.get("live_target_found", false)),
		"dead=" + str(result.get("target_dead_seen", false)),
		"lootable=" + str(result.get("target_lootable_seen", false)),
		"loot_response=" + str(result.get("loot_response_seen", false)),
		"release_response=" + str(result.get("loot_release_response_seen", false)),
		"handoff=" + str(result.get("handoff_confirmed", false)),
		"changed_slots=" + str(result.get("changed_slot_count", 0)),
		"opcode=0x" + _opcode_hex(int(result.get("response_opcode", 0))),
	]
	var error_text := str(result.get("error", ""))
	if error_text.is_empty():
		error_text = str(result.get("output", ""))
	if not error_text.is_empty():
		details.append("error=" + error_text.left(180))
	return prefix + ": " + ", ".join(details)


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
		push_error("LOOT_OPEN_SELF_TEST_FAILED: " + _failure_summary("Loot probe failed", result))
		get_tree().quit(1)


func _finish_corpse_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_CORPSE_LOOT_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("CORPSE_LOOT_SELF_TEST_OK response_opcode=0x%s dead=%s loot_response=%s money_notify=%s item_removed=%s release_response=%s" % [
			_opcode_hex(int(result.get("response_opcode", 0))),
			str(result.get("target_dead_seen", false)),
			str(result.get("loot_response_seen", false)),
			str(result.get("loot_money_notify_seen", false)),
			str(result.get("loot_item_removed_count", 0)),
			str(result.get("loot_release_response_seen", false)),
		])
		get_tree().quit(0)
	else:
		push_error("CORPSE_LOOT_SELF_TEST_FAILED: " + _failure_summary("Corpse loot probe failed", result))
		get_tree().quit(1)


func _finish_loot_inventory_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_LOOT_INVENTORY_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("LOOT_INVENTORY_SELF_TEST_OK response_opcode=0x%s changed_slots=%s added_slots=%s handoff=%s" % [
			_opcode_hex(int(result.get("response_opcode", 0))),
			str(result.get("changed_slot_count", 0)),
			str(result.get("added_slot_count", 0)),
			str(result.get("handoff_confirmed", false)),
		])
		get_tree().quit(0)
	else:
		push_error("LOOT_INVENTORY_SELF_TEST_FAILED: " + _failure_summary("Loot inventory probe failed", result))
		get_tree().quit(1)


func _finish_target_picker_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_LOOT_TARGET_PICKER_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		var selected: Dictionary = result.get("selected_target", {})
		print("LOOT_TARGET_PICKER_SELF_TEST_OK target_count=%s selected_entry=%s selected_guid=%s" % [
			str(result.get("target_picker_count", 0)),
			str(selected.get("entry", 0)),
			str(selected.get("guid", "0x0")),
		])
		get_tree().quit(0)
	else:
		push_error("LOOT_TARGET_PICKER_SELF_TEST_FAILED: " + _failure_summary("Target picker failed", result))
		get_tree().quit(1)
