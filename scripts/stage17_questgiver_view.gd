extends Control
## Stage 17 quest-giver view. Opens a live quest-giver interaction through the
## protocol bridge and lists the quests the NPC offers the current character,
## whether the server answers with SMSG_QUESTGIVER_QUEST_LIST or gossip-embedded
## quests (SMSG_GOSSIP_MESSAGE). Quest ids/levels/flags only; no title text.
## Claude native/protocol lane. See docs/ui-parity-worklog.md.

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const DEFAULT_TARGET_ENTRY := "823"
const DASHBOARD_SCENE := "res://main.tscn"

var target_input: LineEdit
var status_label: Label
var quest_list: VBoxContainer
var log_log: TextEdit


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_QUESTGIVER_LIST_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _build_view() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Quest Giver (Stage 17)"
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var lbl := Label.new()
	lbl.text = "Target entry:"
	row.add_child(lbl)

	target_input = LineEdit.new()
	target_input.text = DEFAULT_TARGET_ENTRY
	target_input.custom_minimum_size = Vector2(120, 0)
	row.add_child(target_input)

	var query_btn := Button.new()
	query_btn.text = "Query Quests"
	query_btn.pressed.connect(_on_query_pressed)
	row.add_child(query_btn)

	status_label = Label.new()
	status_label.text = "Idle"
	status_label.modulate = Color(0.6, 0.7, 0.8)
	row.add_child(status_label)

	var quest_scroll := ScrollContainer.new()
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(quest_scroll)

	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_scroll.add_child(quest_list)

	log_log = TextEdit.new()
	log_log.editable = false
	log_log.custom_minimum_size = Vector2(0, 90)
	col.add_child(log_log)

	var back := Button.new()
	back.text = "Back to Dashboard"
	back.pressed.connect(_on_back_pressed)
	col.add_child(back)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _on_query_pressed() -> void:
	var entry := target_input.text.strip_edges()
	if entry.is_empty():
		_log("Enter a target entry id.")
		return
	status_label.text = "Querying..."
	_log("Querying quest giver entry %s..." % entry)
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_list_probe_selector(TEST_CHARACTER_NAME, entry, "Quest Giver")
	_render_result(result)


func _render_result(result: Dictionary) -> void:
	for child in quest_list.get_children():
		child.queue_free()
	var ok := bool(result.get("ok", false))
	var count := int(result.get("quest_count", 0))
	var opcode := int(result.get("response_opcode", 0))
	status_label.text = ("Found %d quest(s)" % count) if ok else "No quests / failed"
	_log("Response opcode=0x%x quest_count=%d ok=%s" % [opcode, count, str(ok)])
	var quests: Array = result.get("quests", [])
	for q in quests:
		var line := Label.new()
		line.text = "Quest #%d  (level %d, flags 0x%x)" % [
			int(q.get("quest_id", 0)),
			int(q.get("quest_level", 0)),
			int(q.get("quest_flags", 0)),
		]
		quest_list.add_child(line)
	if quests.is_empty():
		var none := Label.new()
		none.text = "This quest giver offered no quests to the current character."
		none.modulate = Color(0.7, 0.7, 0.7)
		quest_list.add_child(none)


func _log(msg: String) -> void:
	print("[QuestGiver] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


func _run_self_test() -> void:
	print("QUESTGIVER_LIST_SELF_TEST: starting verification...")
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_list_probe_selector(TEST_CHARACTER_NAME, DEFAULT_TARGET_ENTRY, "Quest Giver")
	var count := int(result.get("quest_count", 0))
	var opcode := int(result.get("response_opcode", 0))
	print("QUESTGIVER_LIST_SELF_TEST_READY target_entry=%s live_target_found=%s quest_list_response_seen=%s gossip_fallback_seen=%s quest_count=%s opcode=0x%x" % [
		DEFAULT_TARGET_ENTRY,
		str(result.get("live_target_found", false)),
		str(result.get("quest_list_response_seen", false)),
		str(result.get("gossip_fallback_seen", false)),
		str(count),
		opcode,
	])
	if bool(result.get("ok", false)) and count > 0:
		print("QUESTGIVER_LIST_SELF_TEST_OK quest_count=%s response_opcode=0x%x" % [str(count), opcode])
		get_tree().quit(0)
		return
	push_error("QUESTGIVER_LIST_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)
