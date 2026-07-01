extends Control

const DASHBOARD_SCENE := "res://main.tscn"

var status_label: Label
var source_label: Label
var greeting_label: Label
var quest_list: ItemList
var quest_title_label: Label
var quest_detail_label: Label
var accept_button: Button
var selected_quest: Dictionary = {}


func _ready() -> void:
	_build_view()
	_render_empty_state()
	if OS.get_environment("ACORE_QUESTGIVER_UI_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.066, 0.066)
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

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)

	var title := Label.new()
	title.text = "Questgiver"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "UI ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	source_label = Label.new()
	source_label.text = "Waiting for questgiver list data."
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(source_label)

	greeting_label = Label.new()
	greeting_label.text = "Greeting: none"
	greeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(greeting_label)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.custom_minimum_size = Vector2(0, 360)
	stack.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	var list_label := Label.new()
	list_label.text = "Available Quests"
	left.add_child(list_label)

	quest_list = ItemList.new()
	quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_list.item_selected.connect(_on_quest_selected)
	left.add_child(quest_list)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 16)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_right", 12)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	split.add_child(detail_margin)

	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail_stack)

	quest_title_label = Label.new()
	quest_title_label.text = "Select a quest"
	quest_title_label.add_theme_font_size_override("font_size", 22)
	quest_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_stack.add_child(quest_title_label)

	quest_detail_label = Label.new()
	quest_detail_label.text = ""
	quest_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(quest_detail_label)

	accept_button = Button.new()
	accept_button.text = "Accept Selected"
	accept_button.custom_minimum_size = Vector2(150, 36)
	accept_button.disabled = true
	accept_button.pressed.connect(_on_accept_pressed)
	detail_stack.add_child(accept_button)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	stack.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var back_button := Button.new()
	back_button.text = "Back to Dashboard"
	back_button.custom_minimum_size = Vector2(160, 38)
	back_button.pressed.connect(_on_back_pressed)
	footer.add_child(back_button)


func _render_empty_state() -> void:
	selected_quest = {}
	quest_list.clear()
	quest_list.add_item("No questgiver list loaded")
	quest_list.set_item_disabled(0, true)
	quest_title_label.text = "Select a quest"
	quest_detail_label.text = "Open this panel from a live questgiver once the protocol lane provides the list response."
	accept_button.disabled = true


func render_questgiver_list(result: Dictionary) -> void:
	var quests: Array = _quest_rows(result)
	quest_list.clear()
	selected_quest = {}

	var questgiver_guid := str(result.get("questgiver_guid", "unknown"))
	var quest_count := int(result.get("quest_count", quests.size()))
	source_label.text = "Questgiver %s returned %s quest row(s)." % [
		questgiver_guid,
		str(quest_count),
	]
	greeting_label.text = "Greeting: " + str(result.get("greeting", ""))
	status_label.text = "Ready" if quests.size() > 0 else "Empty"

	if quests.is_empty():
		_render_empty_state()
		source_label.text = "Questgiver %s returned no quest rows." % questgiver_guid
		return

	for quest in quests:
		var index := quest_list.add_item(_quest_row_text(quest))
		quest_list.set_item_metadata(index, quest)

	quest_list.select(0)
	_apply_quest(quests[0])


func _quest_rows(result: Dictionary) -> Array:
	var rows: Array = []
	var raw_rows = result.get("quests", [])
	if typeof(raw_rows) != TYPE_ARRAY:
		return rows

	for raw in raw_rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var quest: Dictionary = raw.duplicate(true)
		quest["quest_id"] = int(quest.get("quest_id", quest.get("id", 0)))
		quest["quest_icon"] = int(quest.get("quest_icon", quest.get("icon", 0)))
		quest["quest_level"] = int(quest.get("quest_level", quest.get("level", 0)))
		quest["quest_flags"] = int(quest.get("quest_flags", quest.get("flags", 0)))
		quest["repeatable"] = int(quest.get("repeatable", 0))
		quest["title"] = str(quest.get("title", "Quest " + str(quest["quest_id"])))
		rows.append(quest)
	return rows


func _quest_row_text(quest: Dictionary) -> String:
	var repeat_text := "repeatable" if int(quest.get("repeatable", 0)) != 0 else "once"
	return "#%s - %s - level %s - %s" % [
		str(quest.get("quest_id", 0)),
		str(quest.get("title", "")),
		str(quest.get("quest_level", 0)),
		repeat_text,
	]


func _on_quest_selected(index: int) -> void:
	if index < 0 or index >= quest_list.item_count:
		return
	var metadata = quest_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return
	_apply_quest(metadata)


func _apply_quest(quest: Dictionary) -> void:
	selected_quest = quest.duplicate(true)
	quest_title_label.text = str(selected_quest.get("title", "Quest"))
	var repeat_text := "yes" if int(selected_quest.get("repeatable", 0)) != 0 else "no"
	quest_detail_label.text = "Quest id: %s\nIcon: %s\nLevel: %s\nFlags: %s\nRepeatable: %s\n\nAccept is disabled until the live protocol lane exposes the quest accept call." % [
		str(selected_quest.get("quest_id", 0)),
		str(selected_quest.get("quest_icon", 0)),
		str(selected_quest.get("quest_level", 0)),
		str(selected_quest.get("quest_flags", 0)),
		repeat_text,
	]
	accept_button.disabled = true


func _on_accept_pressed() -> void:
	status_label.text = "Quest accept is waiting for live protocol wiring."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _run_self_test() -> void:
	var synthetic_result := {
		"questgiver_guid": "0xf130000001000001",
		"greeting": "Choose a task.",
		"emote_delay": 1,
		"emote_type": 2,
		"quest_count": 2,
		"quests": [
			{
				"quest_id": 7101,
				"quest_icon": 2,
				"quest_level": 8,
				"quest_flags": 0,
				"repeatable": 0,
				"title": "Supply Run",
			},
			{
				"quest_id": 7102,
				"quest_icon": 4,
				"quest_level": 10,
				"quest_flags": 8,
				"repeatable": 1,
				"title": "Field Report",
			},
		],
	}
	render_questgiver_list(synthetic_result)

	var first_ok := quest_list.item_count == 2 \
		and int(selected_quest.get("quest_id", 0)) == 7101 \
		and quest_detail_label.text.find("Repeatable: no") != -1 \
		and accept_button.disabled
	quest_list.select(1)
	_on_quest_selected(1)
	var second_ok := int(selected_quest.get("quest_id", 0)) == 7102 \
		and quest_detail_label.text.find("Repeatable: yes") != -1 \
		and source_label.text.find("2 quest row") != -1 \
		and greeting_label.text.find("Choose a task.") != -1

	if first_ok and second_ok:
		print("QUESTGIVER_UI_SELF_TEST_OK rows=%s selected=%s greeting=\"%s\"" % [
			str(quest_list.item_count),
			str(selected_quest.get("quest_id", 0)),
			greeting_label.text,
		])
		get_tree().quit(0)
		return

	push_error("QUESTGIVER_UI_SELF_TEST_FAILED first_ok=%s second_ok=%s" % [
		str(first_ok),
		str(second_ok),
	])
	get_tree().quit(1)
