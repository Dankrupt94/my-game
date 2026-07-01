extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const SLOT_NAMES := [
	"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
	"Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main Hand", "Off Hand", "Ranged", "Tabard",
	"Bag 1", "Bag 2", "Bag 3", "Bag 4",
	"Backpack 1", "Backpack 2", "Backpack 3", "Backpack 4", "Backpack 5", "Backpack 6", "Backpack 7", "Backpack 8",
	"Backpack 9", "Backpack 10", "Backpack 11", "Backpack 12", "Backpack 13", "Backpack 14", "Backpack 15", "Backpack 16",
]

var status_label: Label
var money_label: Label
var detail_label: Label
var swap_label: Label
var slot_grid: GridContainer
var self_test_finished := false
var mutation_self_test_finished := false


func _ready() -> void:
	_build_view()
	call_deferred("_load_inventory")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.058, 0.055)
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
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Loading"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	money_label = Label.new()
	money_label.text = "Money: -"
	money_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(money_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	stack.add_child(action_row)

	var swap_button := Button.new()
	swap_button.text = "Test Move"
	swap_button.tooltip_text = "Backpack 1 -> Backpack 3"
	swap_button.pressed.connect(_run_swap_probe)
	action_row.add_child(swap_button)

	var equipment_button := Button.new()
	equipment_button.text = "Test Unequip"
	equipment_button.tooltip_text = "Main hand -> Backpack 4"
	equipment_button.pressed.connect(_run_equipment_probe)
	action_row.add_child(equipment_button)

	swap_label = Label.new()
	swap_label.text = "Move: idle"
	swap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(swap_label)

	slot_grid = GridContainer.new()
	slot_grid.columns = 6
	slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(slot_grid)

	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size = Vector2(0, 54)
	detail_label.text = ""
	stack.add_child(detail_label)


func _load_inventory() -> void:
	var bridge := ProtocolClientBridge.new()
	var result := bridge.inventory_snapshot(TEST_CHARACTER_NAME)
	if not bool(result.get("ok", false)):
		status_label.text = "Failed"
		detail_label.text = str(result.get("error", result.get("output", "Unknown failure")))
		_finish_self_test(false, result)
		return

	var slots: Array = result.get("slots", [])
	status_label.text = "Slots: %s  Filled: %s  Named: %s" % [
		str(result.get("slot_count", slots.size())),
		str(result.get("populated_count", 0)),
		str(result.get("item_template_count", 0)),
	]
	money_label.text = "Money: " + _money_text(int(result.get("coinage", 0)))
	_render_slots(slots)
	print("INVENTORY_VIEW_READY slots=%s populated=%s details=%s names=%s coinage=%s" % [
		str(result.get("slot_count", slots.size())),
		str(result.get("populated_count", 0)),
		str(result.get("item_detail_count", 0)),
		str(result.get("item_template_count", 0)),
		str(result.get("coinage", 0)),
	])
	if OS.get_environment("ACORE_INVENTORY_SWAP_SELF_TEST") == "1" and not mutation_self_test_finished:
		call_deferred("_run_swap_probe")
		return
	if OS.get_environment("ACORE_EQUIPMENT_SWAP_SELF_TEST") == "1" and not mutation_self_test_finished:
		call_deferred("_run_equipment_probe")
		return
	_finish_self_test(slots.size() == 39, result)


func _render_slots(slots: Array) -> void:
	for child in slot_grid.get_children():
		child.queue_free()
	for i in range(39):
		var slot := _slot_at(slots, i)
		slot_grid.add_child(_slot_button(slot, i))
	if slots.size() > 0:
		_show_slot(_slot_at(slots, 0), 0)


func _slot_button(slot: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = _slot_name(index) + "\n" + _slot_state(slot)
	button.tooltip_text = str(slot.get("item_guid", "0x0"))
	button.pressed.connect(_show_slot.bind(slot, index))
	if bool(slot.get("populated", false)):
		button.add_theme_color_override("font_color", Color(0.95, 0.86, 0.48))
	else:
		button.add_theme_color_override("font_color", Color(0.72, 0.76, 0.75))
	return button


func _slot_at(slots: Array, index: int) -> Dictionary:
	for slot in slots:
		if typeof(slot) == TYPE_DICTIONARY and int(slot.get("slot", -1)) == index:
			return slot
	return {
		"slot": index,
		"section": _section_for_slot(index),
		"field_seen": false,
		"populated": false,
		"item_guid": "0x0",
	}


func _slot_name(index: int) -> String:
	if index >= 0 and index < SLOT_NAMES.size():
		return SLOT_NAMES[index]
	return "Slot " + str(index)


func _slot_state(slot: Dictionary) -> String:
	if bool(slot.get("populated", false)):
		var item_name := str(slot.get("item_name", ""))
		var stack := int(slot.get("stack_count", 0))
		if not item_name.is_empty():
			return item_name + (" x" + str(stack) if stack > 1 else "")
		var entry := int(slot.get("item_entry", 0))
		if entry > 0:
			return "Entry " + str(entry)
		return "Item " + _short_guid(str(slot.get("item_guid", "0x0")))
	if bool(slot.get("field_seen", false)):
		return "Empty"
	return "No update"


func _show_slot(slot: Dictionary, index: int) -> void:
	var durability := ""
	if int(slot.get("max_durability", 0)) > 0:
		durability = "  |  durability %s/%s" % [
			str(slot.get("durability", 0)),
			str(slot.get("max_durability", 0)),
		]
	detail_label.text = "%s  |  %s  |  %s  |  entry %s  |  stack %s%s" % [
		_slot_name(index),
		str(slot.get("section", _section_for_slot(index))),
		str(slot.get("item_guid", "0x0")),
		str(slot.get("item_entry", 0)),
		str(slot.get("stack_count", 0)),
		durability,
	]


func _run_swap_probe(
	source_slot: int = 23,
	destination_slot: int = 25,
	label_prefix: String = "Move",
	self_test_kind: String = "inventory") -> void:
	swap_label.text = label_prefix + ": running"
	var bridge := ProtocolClientBridge.new()
	var result := bridge.swap_inventory_slots(TEST_CHARACTER_NAME, source_slot, destination_slot)
	var ok := bool(result.get("ok", false))
	if ok:
		swap_label.text = label_prefix + ": restored"
	else:
		swap_label.text = label_prefix + ": failed"
		detail_label.text = str(result.get("error", result.get("output", "Inventory move failed")))
	print("INVENTORY_SWAP_READY source=%s destination=%s swap_confirmed=%s restore_confirmed=%s" % [
		str(result.get("source_slot", source_slot)),
		str(result.get("destination_slot", destination_slot)),
		str(result.get("swap_confirmed", false)),
		str(result.get("restore_confirmed", false)),
	])
	if OS.get_environment("ACORE_INVENTORY_SWAP_SELF_TEST") == "1" \
			or OS.get_environment("ACORE_EQUIPMENT_SWAP_SELF_TEST") == "1":
		_finish_swap_self_test(ok, result, self_test_kind)
		return
	if ok:
		call_deferred("_load_inventory")


func _run_equipment_probe() -> void:
	_run_swap_probe(15, 26, "Unequip", "equipment")


func _section_for_slot(index: int) -> String:
	if index < 19:
		return "equipment"
	if index < 23:
		return "bag"
	return "backpack"


func _short_guid(value: String) -> String:
	if value.length() <= 8:
		return value
	return value.substr(value.length() - 6)


func _money_text(copper: int) -> String:
	var gold := copper / 10000
	var silver := (copper % 10000) / 100
	var remaining_copper := copper % 100
	return "%dg %ds %dc" % [gold, silver, remaining_copper]


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_INVENTORY_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("INVENTORY_SELF_TEST_OK slots=%s populated=%s details=%s names=%s coinage=%s" % [
			str(result.get("slot_count", 0)),
			str(result.get("populated_count", 0)),
			str(result.get("item_detail_count", 0)),
			str(result.get("item_template_count", 0)),
			str(result.get("coinage", 0)),
		])
		get_tree().quit(0)
	else:
		push_error("INVENTORY_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)


func _finish_swap_self_test(ok: bool, result: Dictionary, self_test_kind: String = "inventory") -> void:
	if mutation_self_test_finished:
		return
	mutation_self_test_finished = true

	if ok:
		var marker := "INVENTORY_SWAP_SELF_TEST_OK"
		if self_test_kind == "equipment":
			marker = "EQUIPMENT_SWAP_SELF_TEST_OK"
		print("%s source=%s destination=%s" % [
			marker,
			str(result.get("source_slot", 23)),
			str(result.get("destination_slot", 25)),
		])
		get_tree().quit(0)
	else:
		var marker := "INVENTORY_SWAP_SELF_TEST_FAILED"
		if self_test_kind == "equipment":
			marker = "EQUIPMENT_SWAP_SELF_TEST_FAILED"
		push_error(marker + ": " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
