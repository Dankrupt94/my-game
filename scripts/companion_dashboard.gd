extends Control

const AZEROTHCORE_ROOT := "/run/media/doodbro/New 1tb/AzerothCore"
const AZEROTHCORE_SOURCE := "/run/media/doodbro/New 1tb/AzerothCore/source"
const AZEROTHCORE_BUILD := "/home/doodbro/azeroth-build"
const AZEROTHCORE_RUN := "/run/media/doodbro/New 1tb/AzerothCore/run"
const WOTLK_CLIENT := "/run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK"

func _ready() -> void:
	_build_dashboard()

func _build_dashboard() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.09, 0.11)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)

	var main_panel := _panel()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(main_panel)

	var main_stack := VBoxContainer.new()
	main_stack.add_theme_constant_override("separation", 14)
	main_panel.add_child(main_stack)

	var title := Label.new()
	title.text = "AzerothCore Godot Companion"
	title.add_theme_font_size_override("font_size", 30)
	main_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Local companion shell for the AzerothCore server, build folder, and WotLK client paths."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_stack.add_child(subtitle)

	main_stack.add_child(_section_title("Local Paths"))
	main_stack.add_child(_path_row("AzerothCore bundle", AZEROTHCORE_ROOT))
	main_stack.add_child(_path_row("Source checkout", AZEROTHCORE_SOURCE))
	main_stack.add_child(_path_row("Linux build", AZEROTHCORE_BUILD))
	main_stack.add_child(_path_row("Run output", AZEROTHCORE_RUN))
	main_stack.add_child(_path_row("WotLK client", WOTLK_CLIENT))

	main_stack.add_child(_section_title("Current Direction"))
	main_stack.add_child(_body_text("This project is now the Godot-side companion workspace for local AzerothCore experiments and tooling."))

	var side_panel := _panel()
	side_panel.custom_minimum_size = Vector2(330, 0)
	columns.add_child(side_panel)

	var side_stack := VBoxContainer.new()
	side_stack.add_theme_constant_override("separation", 12)
	side_panel.add_child(side_stack)

	side_stack.add_child(_section_title("Quick Checks"))
	side_stack.add_child(_status_row("Client realmlist", "127.0.0.1"))
	side_stack.add_child(_status_row("Server source branch", "Playerbot"))
	side_stack.add_child(_status_row("Godot project", "4.7"))
	side_stack.add_child(_status_row("Asset policy", "No copied client assets"))

	side_stack.add_child(_section_title("Next Build Step"))
	side_stack.add_child(_body_text("Add controls here for server status, start/stop helpers, account setup, client launch, and safe local diagnostics."))

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.15)
	style.border_color = Color(0.32, 0.42, 0.47)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 18)
	style.set_content_margin(SIDE_TOP, 16)
	style.set_content_margin(SIDE_RIGHT, 18)
	style.set_content_margin(SIDE_BOTTOM, 16)
	return style

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label

func _body_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _path_row(name: String, path: String) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.text = name
	row.add_child(label)

	var value := LineEdit.new()
	value.text = path
	value.editable = false
	value.selecting_enabled = true
	row.add_child(value)

	return row

func _status_row(name: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	return row
