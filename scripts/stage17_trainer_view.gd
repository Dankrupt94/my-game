extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const TRAINER_TARGET_ENTRY := 911
const TRAINER_TARGET_NAME := "Nearby Trainer"
const SMSG_TRAINER_LIST := 0x1B1

var status_label: Label
var target_label: Label
var trainer_label: Label
var target_entry_input: SpinBox
var target_name_input: LineEdit
var spell_list: ItemList


func _ready() -> void:
	_build_view()
	call_deferred("_run_trainer_list_probe")


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
	target_row.add_child(target_entry_input)

	target_name_input = LineEdit.new()
	target_name_input.text = TRAINER_TARGET_NAME
	target_name_input.custom_minimum_size = Vector2(210, 34)
	target_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_child(target_name_input)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.custom_minimum_size = Vector2(96, 34)
	refresh_button.pressed.connect(_run_trainer_list_probe)
	target_row.add_child(refresh_button)

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
	var result := bridge.trainer_list_probe(TEST_CHARACTER_NAME, _target_entry(), _target_name())
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


func _target_entry() -> int:
	if target_entry_input == null:
		return TRAINER_TARGET_ENTRY
	return int(target_entry_input.value)


func _target_name() -> String:
	if target_name_input == null:
		return TRAINER_TARGET_NAME
	var value := target_name_input.text.strip_edges()
	return TRAINER_TARGET_NAME if value.is_empty() else value


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
		var row := "Spell %s  cost %s  level %s  usable %s" % [
			str(spell.get("spell_id", 0)),
			_money_text(int(spell.get("money_cost", 0))),
			str(spell.get("req_level", 0)),
			str(spell.get("usable", 0)),
		]
		var skill_line := int(spell.get("req_skill_line", 0))
		var skill_rank := int(spell.get("req_skill_rank", 0))
		if skill_line > 0 or skill_rank > 0:
			row += "  skill %s/%s" % [str(skill_line), str(skill_rank)]
		spell_list.add_item(row)


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


func _failure_summary(prefix: String, result: Dictionary) -> String:
	var source := str(result.get("source", "unknown source"))
	var output := str(result.get("output", "")).strip_edges()
	if output.length() > 420:
		output = output.substr(0, 420) + "..."
	if output.is_empty():
		return "%s via %s." % [prefix, source]
	return "%s via %s: %s" % [prefix, source, output]


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
