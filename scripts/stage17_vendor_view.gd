extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const VENDOR_TARGET_ENTRY := 1213
const VENDOR_TARGET_NAME := "Nearby Vendor"
const SMSG_LIST_INVENTORY := 0x19F
const INFINITE_STOCK := 0xFFFFFFFF

var status_label: Label
var target_label: Label
var vendor_label: Label
var target_entry_input: SpinBox
var target_name_input: LineEdit
var target_picker: ItemList
var item_list: ItemList
var visible_targets: Array = []
var selected_target_selector := ""
var applying_scanned_target := false


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_VENDOR_TARGET_PICKER_SELF_TEST") == "1":
		call_deferred("_run_target_picker_self_test")
	elif OS.get_environment("ACORE_VENDOR_LIST_SELF_TEST") == "1":
		call_deferred("_run_vendor_list_self_test")
	else:
		call_deferred("_scan_visible_targets")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.045, 0.052, 0.052)
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
	title.text = "Vendor"
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
	target_label.text = "Waiting for AzerothCore vendor response."
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
	target_entry_input.value = VENDOR_TARGET_ENTRY
	target_entry_input.custom_minimum_size = Vector2(130, 34)
	target_entry_input.value_changed.connect(_on_target_manual_changed)
	target_row.add_child(target_entry_input)

	target_name_input = LineEdit.new()
	target_name_input.text = VENDOR_TARGET_NAME
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
	refresh_button.pressed.connect(_run_vendor_list_probe)
	target_row.add_child(refresh_button)

	target_picker = ItemList.new()
	target_picker.custom_minimum_size = Vector2(0, 110)
	target_picker.item_selected.connect(_on_target_selected)
	stack.add_child(target_picker)

	vendor_label = Label.new()
	vendor_label.text = "Vendor: idle"
	vendor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(vendor_label)

	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(item_list)


func _run_vendor_list_self_test() -> void:
	var scan_result := _scan_visible_targets(false)
	if not bool(scan_result.get("ok", false)):
		_finish_vendor_list_self_test(false, scan_result)
		return
	_run_vendor_list_probe()


func _run_vendor_list_probe() -> void:
	status_label.text = "Running"
	vendor_label.text = "Vendor: loading"
	item_list.clear()

	var bridge := ProtocolClientBridge.new()
	var result := bridge.vendor_list_probe_selector(TEST_CHARACTER_NAME, _target_selector(), _target_name())
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Vendor list probe failed", result)
		_finish_vendor_list_self_test(false, result)
		return

	status_label.text = "Ready"
	target_label.text = "Target %s entry %s, moved close=%s, returned=%s, response opcode 0x%s." % [
		str(result.get("target_guid", "0x0")),
		str(result.get("target_entry", _target_entry())),
		str(result.get("approach_movement_sent", false)),
		str(result.get("return_movement_sent", false)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	]
	_render_vendor(result)
	print("VENDOR_LIST_SELF_TEST_READY target_entry=%s moved_close=%s returned=%s item_count=%s opcode=0x%s" % [
		str(result.get("target_entry", _target_entry())),
		str(result.get("approach_movement_sent", false)),
		str(result.get("return_movement_sent", false)),
		str(result.get("item_count", 0)),
		_opcode_hex(int(result.get("response_opcode", 0))),
	])
	_finish_vendor_list_self_test(true, result)


func _run_target_picker_self_test() -> void:
	_scan_visible_targets(true)


func _scan_visible_targets(finish_self_test := false) -> Dictionary:
	status_label.text = "Scanning"
	vendor_label.text = "Vendor: scanning"
	item_list.clear()
	target_picker.clear()
	target_picker.add_item("Scanning live visible units...")

	var bridge := ProtocolClientBridge.new()
	var result := bridge.visible_targets_snapshot(TEST_CHARACTER_NAME)
	var ok := bool(result.get("ok", false))
	if not ok:
		status_label.text = "Failed"
		target_label.text = _failure_summary("Vendor target scan failed", result)
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
	vendor_label.text = "Vendor: target selected"
	target_label.text = "Selected %s from %s visible unit target(s)." % [
		_target_picker_text(selected),
		str(visible_targets.size()),
	]

	result["target_picker_count"] = visible_targets.size()
	result["selected_target"] = selected
	print("VENDOR_TARGET_PICKER_SELF_TEST_READY target_count=%s selected_entry=%s selected_guid=%s distance=%s" % [
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
		return VENDOR_TARGET_ENTRY
	return int(target_entry_input.value)


func _target_name() -> String:
	if target_name_input == null:
		return VENDOR_TARGET_NAME
	var value := target_name_input.text.strip_edges()
	return VENDOR_TARGET_NAME if value.is_empty() else value


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
	target_entry_input.value = int(target.get("entry", VENDOR_TARGET_ENTRY))
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
		if int(target.get("entry", 0)) == VENDOR_TARGET_ENTRY:
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
	var entry := int(target.get("entry", 0))
	if entry == VENDOR_TARGET_ENTRY:
		return VENDOR_TARGET_NAME
	return "Unit " + str(entry)


func _render_vendor(result: Dictionary) -> void:
	var item_count := int(result.get("item_count", 0))
	vendor_label.text = "Vendor returned %s item row(s)." % str(item_count)

	var items: Array = result.get("items", [])
	if items.is_empty():
		item_list.add_item("No vendor items returned. Error code %s" % str(result.get("error_code", 0)))
		return

	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		item_list.add_item(_vendor_item_row(item))


func _finish_vendor_list_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_VENDOR_LIST_SELF_TEST") != "1":
		return
	if ok \
			and bool(result.get("vendor_list_response_seen", false)) \
			and int(result.get("item_count", 0)) > 0 \
			and int(result.get("response_opcode", 0)) == SMSG_LIST_INVENTORY:
		print("VENDOR_LIST_SELF_TEST_OK item_count=%s response_opcode=0x%s" % [
			str(result.get("item_count", 0)),
			_opcode_hex(int(result.get("response_opcode", 0))),
		])
		get_tree().quit(0)
		return

	push_error("VENDOR_LIST_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)


func _finish_target_picker_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_VENDOR_TARGET_PICKER_SELF_TEST") != "1":
		return
	var selected: Dictionary = result.get("selected_target", {})
	if ok \
			and int(result.get("target_picker_count", 0)) > 0 \
			and int(selected.get("entry", 0)) == VENDOR_TARGET_ENTRY \
			and not str(selected.get("guid", "")).is_empty():
		print("VENDOR_TARGET_PICKER_SELF_TEST_OK target_count=%s selected_entry=%s selected_guid=%s" % [
			str(result.get("target_picker_count", 0)),
			str(selected.get("entry", 0)),
			str(selected.get("guid", "0x0")),
		])
		get_tree().quit(0)
		return

	push_error("VENDOR_TARGET_PICKER_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)


func _failure_summary(prefix: String, result: Dictionary) -> String:
	var source := str(result.get("source", "unknown source"))
	var output := str(result.get("output", "")).strip_edges()
	if output.length() > 420:
		output = output.substr(0, 420) + "..."
	if output.is_empty():
		return "%s via %s." % [prefix, source]
	return "%s via %s: %s" % [prefix, source, output]


func _vendor_item_row(item: Dictionary) -> String:
	return "Slot %s | Item %s | %s each | count %s | stock %s | durability %s | cost %s" % [
		str(item.get("vendor_slot", 0)),
		str(item.get("item_id", 0)),
		_money_text(int(item.get("buy_price", 0))),
		str(item.get("buy_count", 0)),
		_stock_text(int(item.get("left_in_stock", 0))),
		str(item.get("max_durability", 0)),
		str(item.get("extended_cost", 0)),
	]


func _stock_text(stock: int) -> String:
	if stock == INFINITE_STOCK:
		return "unlimited"
	return str(stock)


func _money_text(copper: int) -> String:
	var gold := copper / 10000
	var silver := (copper / 100) % 100
	var copper_only := copper % 100
	if gold > 0:
		return "%sg %ss %sc" % [str(gold), str(silver), str(copper_only)]
	if silver > 0:
		return "%ss %sc" % [str(silver), str(copper_only)]
	return "%sc" % str(copper_only)


func _opcode_hex(value: int) -> String:
	var text := "%x" % value
	if text.length() < 3:
		text = text.lpad(3, "0")
	return text
