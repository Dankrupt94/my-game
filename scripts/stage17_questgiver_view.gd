extends Control
## Stage 17 quest-giver view. Opens a live quest-giver interaction through the
## protocol bridge and lists the quests the NPC offers the current character,
## whether the server answers with SMSG_QUESTGIVER_QUEST_LIST or gossip-embedded
## quests (SMSG_GOSSIP_MESSAGE). Quest ids/levels/flags only; no title text.
## Claude native/protocol lane. See docs/ui-parity-worklog.md.

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const DEFAULT_TARGET_ENTRY := "823"
const DEFAULT_QUEST_ID := 783
const DASHBOARD_SCENE := "res://main.tscn"

var target_input: LineEdit
var quest_id_input: LineEdit
var status_label: Label
var quest_list: VBoxContainer
var details_list: VBoxContainer
var log_log: TextEdit


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_QUESTGIVER_LIST_SELF_TEST") == "1":
		call_deferred("_run_self_test")
	elif OS.get_environment("ACORE_QUESTGIVER_DETAILS_SELF_TEST") == "1":
		call_deferred("_run_details_self_test")


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

	var quest_lbl := Label.new()
	quest_lbl.text = "Quest id:"
	row.add_child(quest_lbl)

	quest_id_input = LineEdit.new()
	quest_id_input.text = str(DEFAULT_QUEST_ID)
	quest_id_input.custom_minimum_size = Vector2(120, 0)
	row.add_child(quest_id_input)

	var details_btn := Button.new()
	details_btn.text = "Query Details"
	details_btn.pressed.connect(_on_details_pressed)
	row.add_child(details_btn)

	status_label = Label.new()
	status_label.text = "Idle"
	status_label.modulate = Color(0.6, 0.7, 0.8)
	row.add_child(status_label)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	col.add_child(content)

	var quest_col := VBoxContainer.new()
	quest_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(quest_col)

	var quest_title := Label.new()
	quest_title.text = "Offered Quests"
	quest_title.modulate = Color(0.75, 0.82, 0.92)
	quest_col.add_child(quest_title)

	var quest_scroll := ScrollContainer.new()
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_col.add_child(quest_scroll)

	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_scroll.add_child(quest_list)

	var details_col := VBoxContainer.new()
	details_col.custom_minimum_size = Vector2(360, 0)
	details_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(details_col)

	var details_title := Label.new()
	details_title.text = "Quest Details"
	details_title.modulate = Color(0.75, 0.82, 0.92)
	details_col.add_child(details_title)

	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_col.add_child(details_scroll)

	details_list = VBoxContainer.new()
	details_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details_list)

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


func _on_details_pressed() -> void:
	var entry := target_input.text.strip_edges()
	if entry.is_empty():
		_log("Enter a target entry id.")
		return
	var quest_id := quest_id_input.text.strip_edges().to_int()
	if quest_id <= 0:
		_log("Enter a quest id.")
		return
	status_label.text = "Querying details..."
	_log("Querying quest details for quest %d..." % quest_id)
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_details_probe_selector(TEST_CHARACTER_NAME, entry, quest_id, "Quest Giver")
	_render_details_result(result)


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
	if not quests.is_empty():
		quest_id_input.text = str(int(quests[0].get("quest_id", DEFAULT_QUEST_ID)))
	if quests.is_empty():
		var none := Label.new()
		none.text = "This quest giver offered no quests to the current character."
		none.modulate = Color(0.7, 0.7, 0.7)
		quest_list.add_child(none)


func _render_details_result(result: Dictionary) -> void:
	for child in details_list.get_children():
		child.queue_free()
	var ok := bool(result.get("ok", false))
	var opcode := int(result.get("response_opcode", 0))
	var query_quest_id := int(result.get("query_quest_id", quest_id_input.text.strip_edges().to_int()))
	var details_quest_id := int(result.get("details_quest_id", 0))
	var reward_item_count := int(result.get("reward_item_count", 0))
	var reward_choice_count := int(result.get("reward_choice_count", 0))
	var details: Dictionary = result.get("details", {})
	var quest_flags := int(details.get("quest_flags", result.get("quest_flags", 0)))
	var suggested_players := int(details.get("suggested_players", 0))
	var hidden_rewards := bool(details.get("hidden_rewards", false))
	status_label.text = "Details loaded" if ok else "Details failed"
	_log("Details opcode=0x%x quest_id=%d ok=%s rewards=%d choices=%d" % [
		opcode,
		details_quest_id,
		str(ok),
		reward_item_count,
		reward_choice_count,
	])
	if not ok and result.has("error"):
		_add_detail_line("Error: " + str(result["error"]), Color(1.0, 0.55, 0.55))
	_add_detail_line("Queried quest #%d" % query_quest_id)
	_add_detail_line("Detail quest #%d" % details_quest_id)
	_add_detail_line("Response opcode 0x%x" % opcode)
	_add_detail_line("Flags 0x%x, suggested players %d, hidden rewards %s" % [
		quest_flags,
		suggested_players,
		str(hidden_rewards),
	])
	_add_detail_line("Money %d, XP %d, spell %d" % [
		int(result.get("money_reward", 0)),
		int(result.get("xp_reward", 0)),
		int(result.get("reward_spell", 0)),
	])
	for line in _reward_lines(result.get("reward_items", []), "Reward"):
		_add_detail_line(line)
	for line in _reward_lines(result.get("reward_choice_items", []), "Choice"):
		_add_detail_line(line)


func _add_detail_line(text: String, color: Color = Color(0.86, 0.88, 0.9)) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	details_list.add_child(label)


func _reward_lines(items: Array, prefix: String) -> Array:
	var lines := []
	if items.is_empty():
		lines.append("%s: none" % prefix)
		return lines
	for item in items:
		lines.append("%s: item #%d x%d" % [
			prefix,
			int(item.get("item_id", 0)),
			int(item.get("count", 0)),
		])
	return lines


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


func _run_details_self_test() -> void:
	print("QUESTGIVER_DETAILS_SELF_TEST: starting verification...")
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_details_probe_selector(TEST_CHARACTER_NAME, DEFAULT_TARGET_ENTRY, DEFAULT_QUEST_ID, "Quest Giver")
	var opcode := int(result.get("response_opcode", 0))
	var details_quest_id := int(result.get("details_quest_id", 0))
	var reward_items := int(result.get("reward_item_count", 0))
	var choice_items := int(result.get("reward_choice_count", 0))
	print("QUESTGIVER_DETAILS_SELF_TEST_READY target_entry=%s quest_id=%s live_target_found=%s query_quest_sent=%s details_response_seen=%s details_quest_id=%s opcode=0x%x" % [
		DEFAULT_TARGET_ENTRY,
		str(DEFAULT_QUEST_ID),
		str(result.get("live_target_found", false)),
		str(result.get("query_quest_sent", false)),
		str(result.get("details_response_seen", false)),
		str(details_quest_id),
		opcode,
	])
	if bool(result.get("ok", false)) and bool(result.get("details_response_seen", false)) and details_quest_id == DEFAULT_QUEST_ID:
		print("QUESTGIVER_DETAILS_SELF_TEST_OK quest_id=%s response_opcode=0x%x reward_items=%s choice_items=%s" % [
			str(details_quest_id),
			opcode,
			str(reward_items),
			str(choice_items),
		])
		get_tree().quit(0)
		return
	push_error("QUESTGIVER_DETAILS_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)
