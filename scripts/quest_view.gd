extends Control

const DASHBOARD_SCENE := "res://main.tscn"
const LiveQuestLogPanel = preload("res://scripts/live_quest_log_panel.gd")

# Player state
var player_gold := 12000 # 1 gold 20 silver in copper
var player_xp := 5000
var player_inventory := []

# Quest lists
var available_quests := []
var active_quests := []
var completed_quests := []

var selected_npc_idx := -1
var selected_log_idx := -1
var selected_reward_idx := -1

# UI references
var tab_container: TabContainer
var available_list: ItemList
var npc_detail_title: Label
var npc_detail_body: TextEdit
var npc_detail_objectives: Label
var npc_detail_rewards: Label
var accept_btn: Button

var active_list: ItemList
var log_detail_title: Label
var log_detail_body: TextEdit
var log_detail_progress: Label
var progress_btn: Button
var reward_option: OptionButton
var complete_btn: Button
var live_quest_log_panel: VBoxContainer

var stats_label: Label
var status_label: Label
var log_log: TextEdit

# Custom formatting constants
const COLOR_BORDER := Color(0.85, 0.72, 0.45) # Gold
const COLOR_GREEN := Color(0.15, 0.8, 0.15)


func _ready() -> void:
	_load_mock_data()
	_build_view()
	_update_available_list()
	_update_active_list()
	_update_stats_label()
	_select_npc_quest(-1)
	_select_log_quest(-1)

	if OS.get_environment("ACORE_QUEST_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.08, 0.09)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var main_stack := VBoxContainer.new()
	main_stack.add_theme_constant_override("separation", 14)
	margin.add_child(main_stack)

	# Header
	var header := HBoxContainer.new()
	main_stack.add_child(header)

	var title := Label.new()
	title.text = "Quest Log"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	stats_label = Label.new()
	stats_label.text = "XP: 5000 | Gold: 1g 20s"
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.modulate = COLOR_BORDER
	header.add_child(stats_label)

	status_label = Label.new()
	status_label.text = "Quest logs active"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(0, 360)
	main_stack.add_child(tab_container)

	_build_npc_tab()
	_build_log_tab()
	_build_slot_snapshot_tab()
	_refresh_live_quest_log_panel()

	# Log Console
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 80)
	main_stack.add_child(log_log)

	# Bottom Actions Row
	var actions_row := HBoxContainer.new()
	main_stack.add_child(actions_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.custom_minimum_size = Vector2(160, 38)
	back_btn.pressed.connect(_on_back_pressed)
	actions_row.add_child(back_btn)


func _build_npc_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "NPC Gossip Available"
	tab_container.add_child(tab)

	var h_split := HSplitContainer.new()
	tab.add_child(h_split)

	# Left: Quest list
	var left_side := VBoxContainer.new()
	left_side.custom_minimum_size = Vector2(240, 0)
	h_split.add_child(left_side)

	var select_lbl := Label.new()
	select_lbl.text = "Available Quests:"
	select_lbl.modulate = COLOR_BORDER
	left_side.add_child(select_lbl)

	available_list = ItemList.new()
	available_list.item_selected.connect(_on_npc_quest_selected)
	left_side.add_child(available_list)

	# Right: Details
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	h_split.add_child(right_margin)

	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 10)
	right_margin.add_child(detail_stack)

	npc_detail_title = Label.new()
	npc_detail_title.text = "Select a Quest"
	npc_detail_title.add_theme_font_size_override("font_size", 20)
	detail_stack.add_child(npc_detail_title)

	npc_detail_body = TextEdit.new()
	npc_detail_body.editable = false
	npc_detail_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	npc_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(npc_detail_body)

	npc_detail_objectives = Label.new()
	npc_detail_objectives.text = "Objectives:"
	npc_detail_objectives.modulate = COLOR_BORDER
	detail_stack.add_child(npc_detail_objectives)

	npc_detail_rewards = Label.new()
	npc_detail_rewards.text = "Rewards:"
	npc_detail_rewards.modulate = COLOR_BORDER
	detail_stack.add_child(npc_detail_rewards)

	accept_btn = Button.new()
	accept_btn.text = "Accept Quest"
	accept_btn.custom_minimum_size = Vector2(140, 32)
	accept_btn.pressed.connect(_on_accept_pressed)
	accept_btn.disabled = true
	detail_stack.add_child(accept_btn)


func _build_log_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Active Log Tracker"
	tab_container.add_child(tab)

	var h_split := HSplitContainer.new()
	tab.add_child(h_split)

	# Left: Active Quest list
	var left_side := VBoxContainer.new()
	left_side.custom_minimum_size = Vector2(240, 0)
	h_split.add_child(left_side)

	var log_lbl := Label.new()
	log_lbl.text = "Active Quests:"
	log_lbl.modulate = COLOR_BORDER
	left_side.add_child(log_lbl)

	active_list = ItemList.new()
	active_list.item_selected.connect(_on_log_quest_selected)
	left_side.add_child(active_list)

	# Right: Details & progress
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	h_split.add_child(right_margin)

	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 10)
	right_margin.add_child(detail_stack)

	log_detail_title = Label.new()
	log_detail_title.text = "Select an Active Quest"
	log_detail_title.add_theme_font_size_override("font_size", 20)
	detail_stack.add_child(log_detail_title)

	log_detail_body = TextEdit.new()
	log_detail_body.editable = false
	log_detail_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(log_detail_body)

	log_detail_progress = Label.new()
	log_detail_progress.text = "Objectives Progress:"
	log_detail_progress.modulate = COLOR_BORDER
	detail_stack.add_child(log_detail_progress)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	detail_stack.add_child(action_row)

	progress_btn = Button.new()
	progress_btn.text = "Simulate Progress"
	progress_btn.custom_minimum_size = Vector2(160, 32)
	progress_btn.pressed.connect(_on_simulate_progress_pressed)
	progress_btn.disabled = true
	action_row.add_child(progress_btn)

	reward_option = OptionButton.new()
	reward_option.custom_minimum_size = Vector2(160, 32)
	reward_option.item_selected.connect(_on_reward_item_selected)
	action_row.add_child(reward_option)

	complete_btn = Button.new()
	complete_btn.text = "Complete Quest"
	complete_btn.custom_minimum_size = Vector2(140, 32)
	complete_btn.pressed.connect(_on_complete_pressed)
	complete_btn.disabled = true
	action_row.add_child(complete_btn)


func _build_slot_snapshot_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Quest Slot Snapshot"
	tab_container.add_child(tab)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	tab.add_child(margin)

	live_quest_log_panel = LiveQuestLogPanel.new()
	margin.add_child(live_quest_log_panel)


func _load_mock_data() -> void:
	available_quests = [
		{
			"id": 101,
			"title": "The Lost Canteen",
			"description": "Find Innkeeper Farley's lost canteen. He thinks he dropped it near the river. Search the shores and bring it back.",
			"objectives": [
				{
					"text": "Farley's Canteen recovered",
					"current": 0,
					"required": 1
				}
			],
			"xp": 800,
			"gold": 1200, # 12 silver
			"choices": ["Goldshire Canteen", "Goldshire Mug"]
		},
		{
			"id": 102,
			"title": "Cloth Supplies",
			"description": "The Goldshire guards need Linen Cloth to bind their wounds. Collect 5 pieces of Linen Cloth from nearby bandits.",
			"objectives": [
				{
					"text": "Linen Cloth collected",
					"current": 2,
					"required": 5
				}
			],
			"xp": 1200,
			"gold": 3000, # 30 silver
			"choices": []
		}
	]


func _update_available_list() -> void:
	available_list.clear()
	for quest in available_quests:
		available_list.add_item(quest["title"])


func _update_active_list() -> void:
	active_list.clear()
	for quest in active_quests:
		var text := str(quest["title"])
		if _is_quest_complete(quest):
			text += " (Complete)"
		active_list.add_item(text)
	_refresh_live_quest_log_panel()


func _update_stats_label() -> void:
	var gold_part = player_gold / 10000
	var silver_part = (player_gold % 10000) / 100
	stats_label.text = "XP: %d | Gold: %dg %ds" % [player_xp, gold_part, silver_part]


func _on_npc_quest_selected(idx: int) -> void:
	_select_npc_quest(idx)


func _on_log_quest_selected(idx: int) -> void:
	_select_log_quest(idx)


func _select_npc_quest(idx: int) -> void:
	selected_npc_idx = idx
	if idx < 0 or idx >= available_quests.size():
		npc_detail_title.text = "Select a Quest"
		npc_detail_body.text = ""
		npc_detail_objectives.text = "Objectives:"
		npc_detail_rewards.text = "Rewards:"
		accept_btn.disabled = true
		return

	var quest = available_quests[idx]
	npc_detail_title.text = quest["title"]
	npc_detail_body.text = quest["description"]

	# Compile objectives text
	var obj_txt := "Objectives:\n"
	for obj in quest["objectives"]:
		obj_txt += " - %s (%d/%d)\n" % [obj["text"], obj["current"], obj["required"]]
	npc_detail_objectives.text = obj_txt

	# Compile rewards text
	var rew_txt := "Rewards:\n - XP: %d\n - Money: %dg %ds\n" % [quest["xp"], int(quest["gold"]) / 10000, (int(quest["gold"]) % 10000) / 100]
	var choices: Array = quest["choices"]
	if choices.size() > 0:
		rew_txt += " - Choice of: " + ", ".join(choices)
	npc_detail_rewards.text = rew_txt

	accept_btn.disabled = false


func _select_log_quest(idx: int) -> void:
	selected_log_idx = idx
	if idx < 0 or idx >= active_quests.size():
		log_detail_title.text = "Select an Active Quest"
		log_detail_body.text = ""
		log_detail_progress.text = "Objectives Progress:"
		progress_btn.disabled = true
		reward_option.visible = false
		complete_btn.disabled = true
		return

	var quest = active_quests[idx]
	log_detail_title.text = quest["title"]
	log_detail_body.text = quest["description"]

	# Compile progress
	var progress_txt := "Objectives Progress:\n"
	for obj in quest["objectives"]:
		var line := " - %s: %d/%d" % [obj["text"], obj["current"], obj["required"]]
		if obj["current"] >= obj["required"]:
			line += " (Done)"
		progress_txt += line + "\n"
	log_detail_progress.text = progress_txt

	progress_btn.disabled = _is_quest_complete(quest)

	# Choices setup
	var choices: Array = quest["choices"]
	if choices.size() > 0:
		reward_option.visible = true
		reward_option.clear()
		reward_option.add_item("(Select Reward)")
		for choice in choices:
			reward_option.add_item(choice)
		selected_reward_idx = -1
	else:
		reward_option.visible = false
		selected_reward_idx = 0 # No choice needed, automatically claim

	_check_complete_readiness(quest)


func _on_reward_item_selected(idx: int) -> void:
	selected_reward_idx = idx - 1 # offset index 0 (Select Reward)
	if selected_log_idx >= 0:
		_check_complete_readiness(active_quests[selected_log_idx])


func _check_complete_readiness(quest: Dictionary) -> void:
	var met := _is_quest_complete(quest)
	var choice_valid := selected_reward_idx >= 0
	complete_btn.disabled = not (met and choice_valid)


func _is_quest_complete(quest: Dictionary) -> bool:
	for obj in quest["objectives"]:
		if obj["current"] < obj["required"]:
			return false
	return true


func _refresh_live_quest_log_panel() -> void:
	if live_quest_log_panel == null:
		return
	var focus_quest_id := 0
	if selected_log_idx >= 0 and selected_log_idx < active_quests.size():
		focus_quest_id = int(active_quests[selected_log_idx]["id"])
	elif not active_quests.is_empty():
		focus_quest_id = int(active_quests[0]["id"])
	live_quest_log_panel.load_from_snapshot(_active_quests_to_slot_snapshot(), focus_quest_id, "UI quest slots")


func _active_quests_to_slot_snapshot() -> Dictionary:
	var slots := []
	var slot_index := 0
	for quest in active_quests:
		var counters := [0, 0, 0, 0]
		var objectives: Array = quest.get("objectives", [])
		for objective_idx in range(min(objectives.size(), counters.size())):
			counters[objective_idx] = int(objectives[objective_idx].get("current", 0))
		slots.append({
			"slot": slot_index,
			"quest_id": int(quest["id"]),
			"state": 0x8 if _is_quest_complete(quest) else 0x0,
			"counter_1": counters[0],
			"counter_2": counters[1],
			"counter_3": counters[2],
			"counter_4": counters[3],
			"time_left": 0,
			"populated": true,
		})
		slot_index += 1
	return {
		"seen": true,
		"populated_count": slots.size(),
		"slots": slots,
	}


func _on_accept_pressed() -> void:
	if selected_npc_idx < 0:
		return
	var quest = available_quests[selected_npc_idx]
	available_quests.remove_at(selected_npc_idx)
	active_quests.append(quest)
	
	_log("Quest accepted: " + quest["title"])
	_select_npc_quest(-1)
	_update_available_list()
	_update_active_list()
	_refresh_live_quest_log_panel()


func _on_simulate_progress_pressed() -> void:
	if selected_log_idx < 0:
		return
	var quest = active_quests[selected_log_idx]
	for obj in quest["objectives"]:
		if obj["current"] < obj["required"]:
			obj["current"] += 1
			_log("Progress on %s: %d/%d" % [quest["title"], obj["current"], obj["required"]])
			break

	_select_log_quest(selected_log_idx)
	_update_active_list()
	_refresh_live_quest_log_panel()


func _on_complete_pressed() -> void:
	if selected_log_idx < 0:
		return
	var quest = active_quests[selected_log_idx]
	
	# Give rewards
	player_gold += int(quest["gold"])
	player_xp += int(quest["xp"])
	
	var choices: Array = quest["choices"]
	if choices.size() > 0 and selected_reward_idx >= 0:
		var item_reward = choices[selected_reward_idx]
		player_inventory.append(item_reward)
		_log("Quest completed: %s. Claimed item reward: %s." % [quest["title"], item_reward])
	else:
		_log("Quest completed: %s." % quest["title"])

	_log("Claimed: %d XP and %dg %ds." % [quest["xp"], int(quest["gold"]) / 10000, (int(quest["gold"]) % 10000) / 100])
	
	completed_quests.append(quest["id"])
	active_quests.remove_at(selected_log_idx)

	_select_log_quest(-1)
	_update_active_list()
	_update_stats_label()
	_refresh_live_quest_log_panel()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[Quest] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("QUEST_SELF_TEST: starting verification...")

	# 1. Verify available listings
	if available_quests.size() != 2:
		_fail_self_test("Simulated available quests size mismatch")
		return

	# 2. Accept Quest 101 (The Lost Canteen)
	selected_npc_idx = 0
	_on_accept_pressed()
	if active_quests.size() != 1:
		_fail_self_test("Quest acceptance failed to add to active log list")
		return
	if live_quest_log_panel.get_active_count() != 1:
		_fail_self_test("Quest slot snapshot did not show accepted quest")
		return
	if available_quests.size() != 1:
		_fail_self_test("Quest acceptance failed to remove from available list")
		return

	# 3. Choose in active log
	selected_log_idx = 0
	var active_q = active_quests[0]
	if active_q["id"] != 101 or active_q["objectives"][0]["current"] != 0:
		_fail_self_test("Active quest details mismatch")
		return

	# 4. Try completing immediately (should be disabled)
	if not complete_btn.disabled:
		_fail_self_test("Complete button should be disabled for uncompleted objectives")
		return

	# 5. Simulate progress
	_on_simulate_progress_pressed()
	if active_q["objectives"][0]["current"] != 1:
		_fail_self_test("Objective progress simulation failed")
		return
	if live_quest_log_panel.get_selected_quest_id() != 101:
		_fail_self_test("Quest slot snapshot lost selected quest")
		return
	if not _is_quest_complete(active_q):
		_fail_self_test("Quest objectives should be marked met")
		return

	# 6. Try completing without selecting choice (should fail)
	if not complete_btn.disabled:
		_fail_self_test("Complete button should remain disabled before choosing reward item")
		return

	# 7. Select Choice 0 (Goldshire Canteen)
	selected_reward_idx = 0
	_check_complete_readiness(active_q)
	if complete_btn.disabled:
		_fail_self_test("Complete button should be active after objectives met and reward selected")
		return

	# 8. Complete Quest
	var start_gold := player_gold
	var start_xp := player_xp
	_on_complete_pressed()

	if player_gold != start_gold + 1200:
		_fail_self_test("Reward gold payout arithmetic failed")
		return
	if player_xp != start_xp + 800:
		_fail_self_test("Reward XP payout arithmetic failed")
		return
	if not player_inventory.has("Goldshire Canteen"):
		_fail_self_test("Claimed item reward was not found in player inventory")
		return
	if active_quests.size() != 0:
		_fail_self_test("Quest log was not cleared after completion")
		return
	if live_quest_log_panel.get_active_count() != 0:
		_fail_self_test("Quest slot snapshot was not cleared after completion")
		return

	print("QUEST_SELF_TEST_OK: available NPC gossip loading, active log tracking, progress simulation, and item reward selection complete checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("QUEST_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
