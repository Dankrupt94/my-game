extends Control
## Stage 17 quest turn-in / reward view. Opens a live quest ender through the
## protocol bridge, requests the completion screen (non-mutating
## CMSG_QUESTGIVER_COMPLETE_QUEST), and shows whether the server answered with a
## reward offer (SMSG_QUESTGIVER_OFFER_REWARD) or a "not finished" request-items
## screen. The quest is accepted to make the request meaningful and then
## abandoned to restore the log; the irreversible turn-in
## (CMSG_QUESTGIVER_CHOOSE_REWARD) is never sent from this view. Reward item ids
## only; no title/reward text. Claude native/protocol lane.
## See docs/ui-parity-worklog.md.

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const DEFAULT_TARGET_ENTRY := "823"
const DEFAULT_QUEST_ID := 6
const DASHBOARD_SCENE := "res://main.tscn"

var target_input: LineEdit
var quest_input: LineEdit
var status_label: Label
var detail_list: VBoxContainer
var log_log: TextEdit


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_QUESTGIVER_REWARD_SELF_TEST") == "1":
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
	title.text = "Quest Turn-in / Reward (Stage 17)"
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var lbl := Label.new()
	lbl.text = "Ender entry:"
	row.add_child(lbl)

	target_input = LineEdit.new()
	target_input.text = DEFAULT_TARGET_ENTRY
	target_input.custom_minimum_size = Vector2(100, 0)
	row.add_child(target_input)

	var qlbl := Label.new()
	qlbl.text = "Quest id:"
	row.add_child(qlbl)

	quest_input = LineEdit.new()
	quest_input.text = str(DEFAULT_QUEST_ID)
	quest_input.custom_minimum_size = Vector2(100, 0)
	row.add_child(quest_input)

	var reward_btn := Button.new()
	reward_btn.text = "Request Reward"
	reward_btn.pressed.connect(_on_reward_pressed)
	row.add_child(reward_btn)

	status_label = Label.new()
	status_label.text = "Idle"
	status_label.modulate = Color(0.6, 0.7, 0.8)
	row.add_child(status_label)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(detail_scroll)

	detail_list = VBoxContainer.new()
	detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_list)

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


func _on_reward_pressed() -> void:
	var entry := target_input.text.strip_edges()
	var quest_id := int(quest_input.text.strip_edges())
	if entry.is_empty() or quest_id <= 0:
		_log("Enter a quest-ender entry id and a quest id.")
		return
	status_label.text = "Requesting..."
	_log("Requesting completion screen for quest %d from ender %s..." % [quest_id, entry])
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_reward_probe_selector(TEST_CHARACTER_NAME, entry, quest_id, "Quest Ender")
	_render_result(result)


func _render_result(result: Dictionary) -> void:
	for child in detail_list.get_children():
		child.queue_free()
	var offer := bool(result.get("offer_reward_seen", false))
	var request_items := bool(result.get("request_items_seen", false))
	var invalid := bool(result.get("quest_invalid_seen", false))
	var screen := "Reward offer" if offer else ("Not finished (request items)" if request_items else ("Invalid / not takeable" if invalid else "No response"))
	status_label.text = screen
	_log("completion screen=%s reward_items=%d choice=%d money=%d xp=%d" % [
		screen,
		int(result.get("reward_item_count", 0)),
		int(result.get("reward_choice_count", 0)),
		int(result.get("money_reward", 0)),
		int(result.get("xp_reward", 0)),
	])
	var rows := [
		"Quest id: %d" % int(result.get("quest_id", 0)),
		"Live ender found: %s" % str(result.get("live_target_found", false)),
		"Completion screen: %s" % screen,
		"Money reward: %d" % int(result.get("money_reward", 0)),
		"XP reward: %d" % int(result.get("xp_reward", 0)),
		"Reward spell: %d" % int(result.get("reward_spell", 0)),
		"Quest log restored: %s" % str(result.get("quest_removed_after_remove", false)),
	]
	for text in rows:
		var line := Label.new()
		line.text = text
		detail_list.add_child(line)
	for item in result.get("reward_items", []):
		var line := Label.new()
		line.text = "Reward item #%d x%d" % [int(item.get("item_id", 0)), int(item.get("item_count", 0))]
		detail_list.add_child(line)
	for item in result.get("reward_choice_items", []):
		var line := Label.new()
		line.text = "Choice item #%d x%d" % [int(item.get("item_id", 0)), int(item.get("item_count", 0))]
		detail_list.add_child(line)


func _log(msg: String) -> void:
	print("[QuestReward] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


func _run_self_test() -> void:
	print("QUESTGIVER_REWARD_SELF_TEST: starting verification...")
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_reward_probe_selector(TEST_CHARACTER_NAME, DEFAULT_TARGET_ENTRY, DEFAULT_QUEST_ID, "Quest Ender")
	var offer := bool(result.get("offer_reward_seen", false))
	var request_items := bool(result.get("request_items_seen", false))
	var invalid := bool(result.get("quest_invalid_seen", false))
	var classified := offer or request_items or invalid
	print("QUESTGIVER_REWARD_SELF_TEST_READY target_entry=%s quest_id=%d live_target_found=%s offer=%s request_items=%s invalid=%s opcode=0x%x" % [
		DEFAULT_TARGET_ENTRY,
		DEFAULT_QUEST_ID,
		str(result.get("live_target_found", false)),
		str(offer),
		str(request_items),
		str(invalid),
		int(result.get("response_opcode", 0)),
	])
	# The turn-in request round trip reached the ender and got a definitive,
	# correctly-classified server response through the native extension path.
	if bool(result.get("live_target_found", false)) and bool(result.get("accept_sent", false)) and classified:
		print("QUESTGIVER_REWARD_SELF_TEST_OK offer=%s request_items=%s invalid=%s" % [str(offer), str(request_items), str(invalid)])
		get_tree().quit(0)
		return
	push_error("QUESTGIVER_REWARD_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)
