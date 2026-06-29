extends CanvasLayer

var _health_bar: ProgressBar
var _resolve_bar: ProgressBar
var _target_label: Label
var _target_bar: ProgressBar
var _quest_label: Label
var _prompt_label: Label
var _feedback_label: Label
var _feedback_timer: Timer

func _ready() -> void:
	_build_hud()

func set_stats(health: int, max_health: int, resolve: int, max_resolve: int) -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_bar.tooltip_text = "Health: %d/%d" % [health, max_health]
	_resolve_bar.max_value = max_resolve
	_resolve_bar.value = resolve
	_resolve_bar.tooltip_text = "Resolve: %d/%d" % [resolve, max_resolve]

func set_target(target_name: String, health: int, max_health: int) -> void:
	if _target_label == null:
		return

	_target_label.text = target_name
	_target_bar.max_value = max_health
	_target_bar.value = health
	_target_bar.visible = true

func clear_target() -> void:
	if _target_label == null:
		return

	_target_label.text = "No target"
	_target_bar.visible = false

func set_quest(quest_state: String, dummy_defeated: bool) -> void:
	if _quest_label == null:
		return

	match quest_state:
		"not_started":
			_quest_label.text = "Available Quest\nFirst Strike at Frostbound\nTalk to Scout Mira."
		"accepted":
			if dummy_defeated:
				_quest_label.text = "First Strike at Frostbound\nReturn to Scout Mira."
			else:
				_quest_label.text = "First Strike at Frostbound\nDefeat the training dummy."
		"ready_to_turn_in":
			_quest_label.text = "First Strike at Frostbound\nReturn to Scout Mira."
		"completed":
			_quest_label.text = "Quest Complete\nFirst Strike at Frostbound"
		_:
			_quest_label.text = ""

func set_prompt(prompt_text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = prompt_text

func show_feedback(message: String) -> void:
	if _feedback_label == null:
		return

	_feedback_label.text = message
	_feedback_label.visible = true
	_feedback_timer.start()

func _hide_feedback() -> void:
	_feedback_label.visible = false

func _build_hud() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var player_panel := PanelContainer.new()
	player_panel.position = Vector2(18.0, 18.0)
	player_panel.size = Vector2(318.0, 112.0)
	player_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.05, 0.07, 0.72)))
	root.add_child(player_panel)

	var player_stack := VBoxContainer.new()
	player_stack.add_theme_constant_override("separation", 8)
	player_panel.add_child(player_stack)

	var name_label := Label.new()
	name_label.text = "Frostbound Initiate"
	player_stack.add_child(name_label)

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(280.0, 22.0)
	_health_bar.show_percentage = false
	player_stack.add_child(_health_bar)

	_resolve_bar = ProgressBar.new()
	_resolve_bar.custom_minimum_size = Vector2(280.0, 18.0)
	_resolve_bar.show_percentage = false
	player_stack.add_child(_resolve_bar)

	var target_panel := PanelContainer.new()
	target_panel.anchor_left = 0.5
	target_panel.anchor_right = 0.5
	target_panel.offset_left = -180.0
	target_panel.offset_right = 180.0
	target_panel.offset_top = 18.0
	target_panel.offset_bottom = 96.0
	target_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.04, 0.04, 0.76)))
	root.add_child(target_panel)

	var target_stack := VBoxContainer.new()
	target_stack.add_theme_constant_override("separation", 8)
	target_panel.add_child(target_stack)

	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_stack.add_child(_target_label)

	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(320.0, 20.0)
	_target_bar.show_percentage = false
	target_stack.add_child(_target_bar)

	var quest_panel := PanelContainer.new()
	quest_panel.anchor_left = 1.0
	quest_panel.anchor_right = 1.0
	quest_panel.offset_left = -334.0
	quest_panel.offset_right = -18.0
	quest_panel.offset_top = 18.0
	quest_panel.offset_bottom = 154.0
	quest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.06, 0.08, 0.72)))
	root.add_child(quest_panel)

	_quest_label = Label.new()
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_panel.add_child(_quest_label)

	var hotbar := HBoxContainer.new()
	hotbar.anchor_left = 0.5
	hotbar.anchor_right = 0.5
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	hotbar.offset_left = -230.0
	hotbar.offset_right = 230.0
	hotbar.offset_top = -86.0
	hotbar.offset_bottom = -24.0
	hotbar.add_theme_constant_override("separation", 10)
	root.add_child(hotbar)

	hotbar.add_child(_hotbar_button("1", "Strike"))
	hotbar.add_child(_hotbar_button("2", "Frost"))
	hotbar.add_child(_hotbar_button("3", "Mend"))

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -390.0
	_prompt_label.offset_right = 390.0
	_prompt_label.offset_top = -126.0
	_prompt_label.offset_bottom = -98.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt_label)

	_feedback_label = Label.new()
	_feedback_label.anchor_left = 0.5
	_feedback_label.anchor_right = 0.5
	_feedback_label.offset_left = -360.0
	_feedback_label.offset_right = 360.0
	_feedback_label.offset_top = 118.0
	_feedback_label.offset_bottom = 156.0
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.visible = false
	root.add_child(_feedback_label)

	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = 3.0
	_feedback_timer.timeout.connect(_hide_feedback)
	add_child(_feedback_timer)

func _hotbar_button(key_text: String, ability_text: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [key_text, ability_text]
	button.custom_minimum_size = Vector2(140.0, 62.0)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.62, 0.72, 0.82, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 12.0)
	style.set_content_margin(SIDE_TOP, 10.0)
	style.set_content_margin(SIDE_RIGHT, 12.0)
	style.set_content_margin(SIDE_BOTTOM, 10.0)
	return style
