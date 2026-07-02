extends Control
## Stage 17 quest-accept view. Accepts an offered quest from a live quest giver
## through the protocol bridge, verifies it lands in a quest-log slot via
## server-authoritative update fields, then abandons it to restore the character
## quest log (reversible, matching the inventory/equipment swap-restore probes).
## Quest ids / slot indices only; no title text. Claude native/protocol lane.
## See docs/ui-parity-worklog.md.

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const DEFAULT_TARGET_ENTRY := "823"
const DEFAULT_QUEST_ID := 783
const DASHBOARD_SCENE := "res://main.tscn"

var target_input: LineEdit
var quest_input: LineEdit
var status_label: Label
var detail_list: VBoxContainer
var log_log: TextEdit


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_QUESTGIVER_ACCEPT_SELF_TEST") == "1":
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
	title.text = "Quest Accept + Abandon (Stage 17)"
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
	target_input.custom_minimum_size = Vector2(100, 0)
	row.add_child(target_input)

	var qlbl := Label.new()
	qlbl.text = "Quest id:"
	row.add_child(qlbl)

	quest_input = LineEdit.new()
	quest_input.text = str(DEFAULT_QUEST_ID)
	quest_input.custom_minimum_size = Vector2(100, 0)
	row.add_child(quest_input)

	var accept_btn := Button.new()
	accept_btn.text = "Accept + Abandon"
	accept_btn.pressed.connect(_on_accept_pressed)
	row.add_child(accept_btn)

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


func _on_accept_pressed() -> void:
	var entry := target_input.text.strip_edges()
	var quest_id := int(quest_input.text.strip_edges())
	if entry.is_empty() or quest_id <= 0:
		_log("Enter a target entry id and a quest id.")
		return
	status_label.text = "Accepting..."
	_log("Accepting quest %d from entry %s (then abandoning to restore)..." % [quest_id, entry])
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_accept_probe_selector(TEST_CHARACTER_NAME, entry, quest_id, "Quest Giver")
	_render_result(result)


func _render_result(result: Dictionary) -> void:
	for child in detail_list.get_children():
		child.queue_free()
	var ok := bool(result.get("ok", false))
	var accepted := bool(result.get("quest_in_log_after_accept", false))
	var removed := bool(result.get("quest_removed_after_remove", false))
	var slot := int(result.get("accepted_slot", -1))
	status_label.text = "Accept + abandon verified" if ok else "Failed / not verified"
	_log("accepted=%s slot=%d abandoned=%s ok=%s" % [str(accepted), slot, str(removed), str(ok)])
	var rows := [
		"Quest id: %d" % int(result.get("quest_id", 0)),
		"Live target found: %s" % str(result.get("live_target_found", false)),
		"Accept sent: %s" % str(result.get("accept_sent", false)),
		"Quest in log after accept: %s" % str(accepted),
		"Accepted quest-log slot: %d" % slot,
		"Abandon sent: %s" % str(result.get("remove_sent", false)),
		"Quest removed after abandon: %s" % str(removed),
	]
	for text in rows:
		var line := Label.new()
		line.text = text
		detail_list.add_child(line)


func _log(msg: String) -> void:
	print("[QuestAccept] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


func _run_self_test() -> void:
	print("QUESTGIVER_ACCEPT_SELF_TEST: starting verification...")
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.questgiver_accept_probe_selector(TEST_CHARACTER_NAME, DEFAULT_TARGET_ENTRY, DEFAULT_QUEST_ID, "Quest Giver")
	var accepted := bool(result.get("quest_in_log_after_accept", false))
	var removed := bool(result.get("quest_removed_after_remove", false))
	var slot := int(result.get("accepted_slot", -1))
	print("QUESTGIVER_ACCEPT_SELF_TEST_READY target_entry=%s quest_id=%d live_target_found=%s accepted=%s slot=%d abandoned=%s" % [
		DEFAULT_TARGET_ENTRY,
		DEFAULT_QUEST_ID,
		str(result.get("live_target_found", false)),
		str(accepted),
		slot,
		str(removed),
	])
	if bool(result.get("ok", false)) and accepted and removed:
		print("QUESTGIVER_ACCEPT_SELF_TEST_OK accepted_slot=%d abandoned=%s" % [slot, str(removed)])
		get_tree().quit(0)
		return
	push_error("QUESTGIVER_ACCEPT_SELF_TEST_FAILED " + JSON.stringify(result))
	get_tree().quit(1)
