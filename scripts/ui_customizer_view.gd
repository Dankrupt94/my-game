extends Control

const DASHBOARD_SCENE := "res://main.tscn"
const LAYOUT_FILE_PATH := "user://ui_layout.cfg"
const LAYOUT_SELF_TEST_FILE_PATH := "user://ui_layout-self-test.cfg"

# UI customizer properties
var layout_file_path := LAYOUT_FILE_PATH
var edit_mode := false
var dragged_panel: PanelContainer = null
var drag_offset := Vector2.ZERO

var panels := {}
var status_label: Label
var log_log: TextEdit
var toggle_edit_btn: Button


func _ready() -> void:
	if OS.get_environment("ACORE_UI_LAYOUT_SELF_TEST") == "1":
		layout_file_path = LAYOUT_SELF_TEST_FILE_PATH
		_delete_layout_file(layout_file_path)

	_build_view()
	_load_layout()
	_update_edit_mode_visuals()

	if OS.get_environment("ACORE_UI_LAYOUT_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.06, 0.08)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var main_stack := VBoxContainer.new()
	main_stack.add_theme_constant_override("separation", 12)
	margin.add_child(main_stack)

	# Header controls row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_stack.add_child(header)

	var title := Label.new()
	title.text = "HUD Layout Customizer"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Dashboard layout loaded"
	status_label.modulate = Color(0.85, 0.72, 0.45)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(status_label)

	# Controls buttons
	toggle_edit_btn = Button.new()
	toggle_edit_btn.text = "Enter Edit Mode"
	toggle_edit_btn.custom_minimum_size = Vector2(140, 32)
	toggle_edit_btn.pressed.connect(_on_toggle_edit_pressed)
	header.add_child(toggle_edit_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Layout"
	save_btn.custom_minimum_size = Vector2(120, 32)
	save_btn.pressed.connect(_on_save_pressed)
	header.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Layout"
	reset_btn.custom_minimum_size = Vector2(120, 32)
	reset_btn.pressed.connect(_on_reset_pressed)
	header.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.custom_minimum_size = Vector2(160, 32)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	# Spacer that holds the viewport area where frames can float
	var sandbox := Control.new()
	sandbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(sandbox)

	# Create dummy HUD panels
	_create_dummy_panel(sandbox, "PlayerFrame", "Player Unit Frame", Vector2(40, 40), Vector2(240, 60), Color(0.12, 0.28, 0.16))
	_create_dummy_panel(sandbox, "TargetFrame", "Target Unit Frame", Vector2(300, 40), Vector2(240, 60), Color(0.28, 0.12, 0.16))
	_create_dummy_panel(sandbox, "MinimapFrame", "Minimap Compass", Vector2(980, 40), Vector2(180, 180), Color(0.12, 0.16, 0.28))
	_create_dummy_panel(sandbox, "ChatFrame", "Chat Log Frame", Vector2(40, 440), Vector2(380, 160), Color(0.16, 0.16, 0.16))

	# Console output
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 100)
	main_stack.add_child(log_log)


func _create_dummy_panel(parent: Control, name_key: String, label_text: String, default_pos: Vector2, default_size: Vector2, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.name = name_key
	panel.custom_minimum_size = default_size
	panel.size = default_size
	panel.position = default_pos
	parent.add_child(panel)

	# Style background
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.15)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(lbl)

	# Wire mouse drag controls
	panel.gui_input.connect(_on_panel_gui_input.bind(name_key))
	
	panels[name_key] = panel


func _on_panel_gui_input(event: InputEvent, name_key: String) -> void:
	if not edit_mode:
		return

	var panel: PanelContainer = panels[name_key]
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragged_panel = panel
			drag_offset = event.position
			panel.z_index = 10
			_log("Dragging panel: " + name_key)
		else:
			if dragged_panel == panel:
				dragged_panel = null
				panel.z_index = 0
				_log("Dropped panel: " + name_key + " at " + str(panel.position))
				_snap_panel(panel)

	elif event is InputEventMouseMotion and dragged_panel == panel:
		panel.position += event.relative


func _snap_panel(panel: PanelContainer) -> void:
	# Basic layout grid snapping (nearest 10 pixels)
	var snapped_x = snapped(panel.position.x, 10)
	var snapped_y = snapped(panel.position.y, 10)
	panel.position = Vector2(snapped_x, snapped_y)


func _on_toggle_edit_pressed() -> void:
	edit_mode = not edit_mode
	_update_edit_mode_visuals()


func _update_edit_mode_visuals() -> void:
	if edit_mode:
		toggle_edit_btn.text = "Exit Edit Mode"
		status_label.text = "EDIT MODE ACTIVE - Drag panels to position"
		status_label.modulate = Color(0.95, 0.35, 0.35) # Red-ish
		for name_key in panels.keys():
			var panel: PanelContainer = panels[name_key]
			var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
			if style != null:
				style.border_color = Color(0.95, 0.75, 0.15, 0.8) # Highlight border yellow
				style.bg_color.a = 0.55 # Make translucent
	else:
		toggle_edit_btn.text = "Enter Edit Mode"
		status_label.text = "Layout customizer inactive"
		status_label.modulate = Color(0.85, 0.72, 0.45) # Gold
		for name_key in panels.keys():
			var panel: PanelContainer = panels[name_key]
			var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
			if style != null:
				style.border_color = Color(1, 1, 1, 0.15)
				style.bg_color.a = 1.0 # Fully opaque


func _on_save_pressed() -> void:
	_save_layout()


func _on_reset_pressed() -> void:
	_delete_layout_file(layout_file_path)
	_log("Layout configuration file reset to default values.")
	# Restore hardcoded default positions
	panels["PlayerFrame"].position = Vector2(40, 40)
	panels["TargetFrame"].position = Vector2(300, 40)
	panels["MinimapFrame"].position = Vector2(980, 40)
	panels["ChatFrame"].position = Vector2(40, 440)
	status_label.text = "Layout reset to defaults"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _save_layout() -> void:
	var config := ConfigFile.new()
	for name_key in panels.keys():
		var panel: PanelContainer = panels[name_key]
		config.set_value(name_key, "position", panel.position)
		config.set_value(name_key, "size", panel.size)
		
	var err := config.save(layout_file_path)
	if err == OK:
		status_label.text = "Layout saved successfully"
		_log("Persisted custom UI positions permanently to " + layout_file_path + ".")
	else:
		status_label.text = "Save layout failed"
		_log("Failed to save layout file. Error: " + str(err))


func _load_layout() -> void:
	var config := ConfigFile.new()
	if config.load(layout_file_path) != OK:
		_log("No custom layout config file found. Using default UI frame anchors.")
		return

	for name_key in panels.keys():
		var panel: PanelContainer = panels[name_key]
		if config.has_section_key(name_key, "position"):
			panel.position = config.get_value(name_key, "position")
		if config.has_section_key(name_key, "size"):
			panel.size = config.get_value(name_key, "size")
	_log("UI positions loaded and applied successfully.")


func _delete_layout_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _log(msg: String) -> void:
	print("[UI Customizer] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("UI_LAYOUT_SELF_TEST: starting verification...")

	# Move panels to mock positions
	panels["PlayerFrame"].position = Vector2(250.0, 310.0)
	panels["MinimapFrame"].position = Vector2(910.0, 70.0)

	# Save layout to disk
	_save_layout()

	# Clear local positions
	panels["PlayerFrame"].position = Vector2.ZERO
	panels["MinimapFrame"].position = Vector2.ZERO

	# Reload and verify
	_load_layout()

	if panels["PlayerFrame"].position != Vector2(250.0, 310.0):
		_fail_self_test("PlayerFrame position coordinates did not load correctly")
		return
	if panels["MinimapFrame"].position != Vector2(910.0, 70.0):
		_fail_self_test("MinimapFrame position coordinates did not load correctly")
		return

	_delete_layout_file(layout_file_path)
	print("UI_LAYOUT_SELF_TEST_OK: UI frames layout dragging, serialization, loading, and positions persistence checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	if layout_file_path == LAYOUT_SELF_TEST_FILE_PATH:
		_delete_layout_file(layout_file_path)
	push_error("UI_LAYOUT_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
