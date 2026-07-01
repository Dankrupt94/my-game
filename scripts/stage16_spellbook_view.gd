extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"

var status_label: Label
var spell_list: TextEdit
var self_test_finished := false


func _ready() -> void:
	_build_view()
	call_deferred("_load_spellbook")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.075)
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
	title.text = "Spellbook"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Loading"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	spell_list = TextEdit.new()
	spell_list.editable = false
	spell_list.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	spell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spell_list.custom_minimum_size = Vector2(0, 520)
	stack.add_child(spell_list)


func _load_spellbook() -> void:
	var bridge := ProtocolClientBridge.new()
	var result := bridge.spellbook(TEST_CHARACTER_NAME)
	if not bool(result.get("ok", false)):
		status_label.text = "Failed"
		spell_list.text = str(result.get("error", result.get("output", "Unknown failure")))
		_finish_self_test(false, result)
		return

	var spells: Array = result.get("spells", [])
	status_label.text = "Spells: " + str(result.get("spell_count", spells.size()))
	var lines := PackedStringArray()
	lines.append("Character: " + TEST_CHARACTER_NAME)
	lines.append("Initial spells: " + str(result.get("initial_spells_seen", false)))
	lines.append("Cooldowns: " + str(result.get("cooldown_count", 0)))
	lines.append("")

	var shown := 0
	for spell in spells:
		if typeof(spell) != TYPE_DICTIONARY:
			continue
		lines.append("Spell " + str(spell.get("id", "?")) + "  slot " + str(spell.get("slot", "0")))
		shown += 1
		if shown >= 80:
			break
	spell_list.text = "\n".join(lines)
	print("SPELLBOOK_VIEW_READY spells=%s cooldowns=%s" % [
		str(result.get("spell_count", spells.size())),
		str(result.get("cooldown_count", 0)),
	])
	_finish_self_test(true, result)


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_SPELLBOOK_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("SPELLBOOK_SELF_TEST_OK spells=%s cooldowns=%s" % [
			str(result.get("spell_count", 0)),
			str(result.get("cooldown_count", 0)),
		])
		get_tree().quit(0)
	else:
		push_error("SPELLBOOK_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
