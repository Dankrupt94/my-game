extends SceneTree

const LiveQuestLogPanel = preload("res://scripts/live_quest_log_panel.gd")


func _initialize() -> void:
	var root := Control.new()
	root.name = "LiveQuestLogPanelSmokeRoot"
	root.size = Vector2(900, 500)
	root.add_child(_build_panel())
	get_root().add_child(root)
	call_deferred("_run")


func _build_panel() -> VBoxContainer:
	var panel: VBoxContainer = LiveQuestLogPanel.new()
	panel.name = "LiveQuestLogPanel"
	panel.load_from_snapshot({
		"seen": true,
		"populated_count": 2,
		"slots": [
			{
				"slot": 0,
				"quest_id": 783,
				"state": 0x8,
				"counter_1": 1,
				"counter_2": 0,
				"counter_3": 0,
				"counter_4": 0,
				"time_left": 0,
			},
			{
				"slot": 4,
				"quest_id": 999,
				"state": 0x2,
				"counter_1": 0,
				"counter_2": 2,
				"counter_3": 0,
				"counter_4": 0,
				"time_left": 30,
			},
		],
	}, 999, "Smoke")
	return panel


func _run() -> void:
	var panel := get_root().find_child("LiveQuestLogPanel", true, false)
	if panel == null:
		push_error("LIVE_QUEST_LOG_PANEL_SMOKE_FAILED missing panel")
		quit(1)
		return
	if panel.get_active_count() != 2:
		push_error("LIVE_QUEST_LOG_PANEL_SMOKE_FAILED active count mismatch")
		quit(1)
		return
	if panel.get_selected_quest_id() != 999:
		push_error("LIVE_QUEST_LOG_PANEL_SMOKE_FAILED selected quest mismatch")
		quit(1)
		return
	if not panel.get_summary_text().contains("2 active"):
		push_error("LIVE_QUEST_LOG_PANEL_SMOKE_FAILED summary mismatch")
		quit(1)
		return
	print("LIVE_QUEST_LOG_PANEL_SMOKE_OK active=%d selected=%d" % [
		panel.get_active_count(),
		panel.get_selected_quest_id(),
	])
	quit(0)
