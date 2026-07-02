extends Control
## Stage 17 quest turn-in view. Hands a completed quest in to its ender through
## the protocol bridge: requests the reward screen (SMSG_QUESTGIVER_OFFER_REWARD),
## chooses a reward (CMSG_QUESTGIVER_CHOOSE_REWARD), and confirms the server
## completed it (SMSG_QUESTGIVER_QUEST_COMPLETE + quest-log slot cleared).
##
## This is the irreversible turn-in step, so the headless self-test drives the
## disposable-state fixture (tools/prepare_quest_turnin_fixture.py): it marks the
## quest complete, turns it in, then resets the character to a clean slate. The
## quest id / slot / reward item ids are numeric only; no title/reward text.
## Claude native/protocol lane. See docs/ui-parity-worklog.md.

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const DEFAULT_ENDER_ENTRY := "197"
const DEFAULT_QUEST_ID := 783
const DASHBOARD_SCENE := "res://main.tscn"

var target_input: LineEdit
var quest_input: LineEdit
var status_label: Label
var detail_list: VBoxContainer
var log_log: TextEdit


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_QUESTGIVER_TURNIN_SELF_TEST") == "1":
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
	title.text = "Quest Turn-in (Stage 17)"
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var lbl := Label.new()
	lbl.text = "Ender entry:"
	row.add_child(lbl)

	target_input = LineEdit.new()
	target_input.text = DEFAULT_ENDER_ENTRY
	target_input.custom_minimum_size = Vector2(100, 0)
	row.add_child(target_input)

	var qlbl := Label.new()
	qlbl.text = "Quest id:"
	row.add_child(qlbl)

	quest_input = LineEdit.new()
	quest_input.text = str(DEFAULT_QUEST_ID)
	quest_input.custom_minimum_size = Vector2(100, 0)
	row.add_child(quest_input)

	var turnin_btn := Button.new()
	turnin_btn.text = "Turn In"
	turnin_btn.pressed.connect(_on_turnin_pressed)
	row.add_child(turnin_btn)

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

	var note := Label.new()
	note.text = "Turn-in is irreversible; the quest must already be complete in the log."
	note.modulate = Color(0.7, 0.6, 0.5)
	col.add_child(note)

	var back := Button.new()
	back.text = "Back to Dashboard"
	back.pressed.connect(_on_back_pressed)
	col.add_child(back)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _on_turnin_pressed() -> void:
	var entry := target_input.text.strip_edges()
	var quest_id := int(quest_input.text.strip_edges())
	if entry.is_empty() or quest_id <= 0:
		_log("Enter a quest-ender entry id and a quest id.")
		return
	status_label.text = "Turning in..."
	_log("Turning in quest %d at ender %s..." % [quest_id, entry])
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_turnin_probe_selector(TEST_CHARACTER_NAME, entry, quest_id, 0, "Quest Ender")
	_render_result(result)


func _render_result(result: Dictionary) -> void:
	for child in detail_list.get_children():
		child.queue_free()
	var ok := bool(result.get("ok", false))
	status_label.text = "Turn-in complete" if ok else "Turn-in not completed"
	_log("offer=%s chose=%s complete=%s cleared=%s ok=%s" % [
		str(result.get("offer_reward_seen", false)),
		str(result.get("choose_reward_sent", false)),
		str(result.get("quest_complete_seen", false)),
		str(result.get("quest_removed_from_log", false)),
		str(ok),
	])
	var rows := [
		"Quest id: %d" % int(result.get("quest_id", 0)),
		"Live ender found: %s" % str(result.get("live_target_found", false)),
		"Quest complete in log before: %s" % str(result.get("quest_in_log_before", false)),
		"Reward offer shown: %s" % str(result.get("offer_reward_seen", false)),
		"Reward chosen: %s" % str(result.get("choose_reward_sent", false)),
		"Server confirmed complete: %s" % str(result.get("quest_complete_seen", false)),
		"Cleared from log: %s" % str(result.get("quest_removed_from_log", false)),
		"Completion XP: %d" % int(result.get("complete_xp", 0)),
		"Completion money: %d" % int(result.get("complete_money", 0)),
	]
	for text in rows:
		var line := Label.new()
		line.text = text
		detail_list.add_child(line)


func _log(msg: String) -> void:
	print("[QuestTurnin] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


func _run_self_test() -> void:
	# The quest must already be COMPLETE in the offline character's log; run
	# `python3 tools/prepare_quest_turnin_fixture.py` first and `--reset` after
	# (the fixture needs the mysql client, which Godot's confined runtime lacks).
	# This mirrors the ACORE_TRAINER_BUY_SUCCESS_SELF_TEST fixture flow.
	print("QUESTGIVER_TURNIN_SELF_TEST: starting verification...")
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_turnin_probe_selector(TEST_CHARACTER_NAME, DEFAULT_ENDER_ENTRY, DEFAULT_QUEST_ID, 0, "Quest Ender")
	var ok := bool(result.get("live_target_found", false)) \
		and bool(result.get("offer_reward_seen", false)) \
		and bool(result.get("choose_reward_sent", false)) \
		and bool(result.get("quest_complete_seen", false)) \
		and bool(result.get("quest_removed_from_log", false))
	print("QUESTGIVER_TURNIN_SELF_TEST_READY live_target_found=%s offer=%s chose=%s complete=%s cleared=%s xp=%s" % [
		str(result.get("live_target_found", false)),
		str(result.get("offer_reward_seen", false)),
		str(result.get("choose_reward_sent", false)),
		str(result.get("quest_complete_seen", false)),
		str(result.get("quest_removed_from_log", false)),
		str(result.get("complete_xp", 0)),
	])
	if ok:
		print("QUESTGIVER_TURNIN_SELF_TEST_OK quest_id=%s xp=%s" % [str(result.get("quest_id", 0)), str(result.get("complete_xp", 0))])
		get_tree().quit(0)
		return
	push_error("QUESTGIVER_TURNIN_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)
