extends Control

const DASHBOARD_SCENE := "res://main.tscn"
const SETTINGS_FILE_PATH := "user://settings.cfg"
const SETTINGS_SELF_TEST_FILE_PATH := "user://settings-self-test.cfg"

var settings := {
	"video": {
		"resolution": "1280x720",
		"fullscreen": false,
		"vsync": true
	},
	"audio": {
		"volume_master": 0.8,
		"volume_music": 0.6,
		"volume_sfx": 0.7,
		"volume_ambience": 0.5
	},
	"gameplay": {
		"auto_loot": true,
		"quest_tracker": true,
		"detailed_tooltips": true
	},
	"keybindings": {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"turn_left": KEY_A,
		"turn_right": KEY_D,
		"jump": KEY_SPACE
	}
}

var tab_container: TabContainer
var res_option: OptionButton
var fullscreen_check: CheckButton
var vsync_check: CheckButton

var slider_master: HSlider
var slider_music: HSlider
var slider_sfx: HSlider
var slider_ambience: HSlider

var check_autoloot: CheckButton
var check_tracker: CheckButton
var check_tooltips: CheckButton

var rebind_buttons := {}
var active_rebind_action := ""
var status_label: Label
var log_output: TextEdit

var settings_file_path := SETTINGS_FILE_PATH


func _ready() -> void:
	if OS.get_environment("ACORE_SETTINGS_SELF_TEST") == "1":
		settings_file_path = SETTINGS_SELF_TEST_FILE_PATH
		_delete_settings_file(settings_file_path)
	_load_settings()
	_apply_all_settings()
	_build_view()
	_update_ui_controls()

	if OS.get_environment("ACORE_SETTINGS_SELF_TEST") == "1":
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

	var header := HBoxContainer.new()
	main_stack.add_child(header)

	var title := Label.new()
	title.text = "System Settings"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Configuration loaded"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(0, 360)
	main_stack.add_child(tab_container)

	_build_video_tab()
	_build_audio_tab()
	_build_gameplay_tab()
	_build_keybindings_tab()

	log_output = TextEdit.new()
	log_output.editable = false
	log_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_output.custom_minimum_size = Vector2(0, 100)
	main_stack.add_child(log_output)

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 10)
	main_stack.add_child(actions_row)

	var save_btn := Button.new()
	save_btn.text = "Save Settings"
	save_btn.custom_minimum_size = Vector2(140, 38)
	save_btn.pressed.connect(_on_save_pressed)
	actions_row.add_child(save_btn)

	var defaults_btn := Button.new()
	defaults_btn.text = "Reset Defaults"
	defaults_btn.custom_minimum_size = Vector2(140, 38)
	defaults_btn.pressed.connect(_on_defaults_pressed)
	actions_row.add_child(defaults_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.custom_minimum_size = Vector2(160, 38)
	back_btn.pressed.connect(_on_back_pressed)
	actions_row.add_child(back_btn)


func _build_video_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Video"
	tab_container.add_child(tab)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	tab.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)

	var res_lbl := Label.new()
	res_lbl.text = "Screen Resolution"
	grid.add_child(res_lbl)

	res_option = OptionButton.new()
	res_option.add_item("1280x720")
	res_option.add_item("1920x1080")
	res_option.add_item("2560x1440")
	res_option.custom_minimum_size = Vector2(160, 32)
	grid.add_child(res_option)

	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen Mode"
	grid.add_child(fs_lbl)

	fullscreen_check = CheckButton.new()
	grid.add_child(fullscreen_check)

	var vs_lbl := Label.new()
	vs_lbl.text = "Enable Vertical Sync (VSync)"
	grid.add_child(vs_lbl)

	vsync_check = CheckButton.new()
	grid.add_child(vsync_check)


func _build_audio_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Audio"
	tab_container.add_child(tab)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	tab.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)

	var m_lbl := Label.new()
	m_lbl.text = "Master Volume"
	grid.add_child(m_lbl)

	slider_master = HSlider.new()
	slider_master.min_value = 0.0
	slider_master.max_value = 1.0
	slider_master.step = 0.05
	slider_master.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slider_master)

	var mu_lbl := Label.new()
	mu_lbl.text = "Music Volume"
	grid.add_child(mu_lbl)

	slider_music = HSlider.new()
	slider_music.min_value = 0.0
	slider_music.max_value = 1.0
	slider_music.step = 0.05
	slider_music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slider_music)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "Sound Effects (SFX)"
	grid.add_child(sfx_lbl)

	slider_sfx = HSlider.new()
	slider_sfx.min_value = 0.0
	slider_sfx.max_value = 1.0
	slider_sfx.step = 0.05
	slider_sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slider_sfx)

	var amb_lbl := Label.new()
	amb_lbl.text = "Ambience Volume"
	grid.add_child(amb_lbl)

	slider_ambience = HSlider.new()
	slider_ambience.min_value = 0.0
	slider_ambience.max_value = 1.0
	slider_ambience.step = 0.05
	slider_ambience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slider_ambience)


func _build_gameplay_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Gameplay"
	tab_container.add_child(tab)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	tab.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)

	var al_lbl := Label.new()
	al_lbl.text = "Auto Loot Corpses"
	grid.add_child(al_lbl)

	check_autoloot = CheckButton.new()
	grid.add_child(check_autoloot)

	var qt_lbl := Label.new()
	qt_lbl.text = "Display HUD Quest Tracker"
	grid.add_child(qt_lbl)

	check_tracker = CheckButton.new()
	grid.add_child(check_tracker)

	var dt_lbl := Label.new()
	dt_lbl.text = "Show Detailed Item Stats Tooltips"
	grid.add_child(dt_lbl)

	check_tooltips = CheckButton.new()
	grid.add_child(check_tooltips)


func _build_keybindings_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Keybindings"
	tab_container.add_child(tab)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	tab.add_child(margin)

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var actions = settings["keybindings"].keys()
	for action in actions:
		var lbl := Label.new()
		lbl.text = action.replace("_", " ").capitalize()
		grid.add_child(lbl)

		var rebind_btn := Button.new()
		rebind_btn.custom_minimum_size = Vector2(180, 32)
		rebind_btn.pressed.connect(_on_rebind_pressed.bind(action))
		grid.add_child(rebind_btn)
		rebind_buttons[action] = rebind_btn


func _input(event: InputEvent) -> void:
	if active_rebind_action.is_empty():
		return

	if event is InputEventKey and event.is_pressed():
		var keycode: int = int(event.physical_keycode)
		if keycode == KEY_NONE:
			keycode = int(event.keycode)

		settings["keybindings"][active_rebind_action] = keycode
		_log("Action '" + active_rebind_action + "' rebound to: " + OS.get_keycode_string(keycode))
		active_rebind_action = ""
		_update_ui_controls()
		get_viewport().set_input_as_handled()


func _on_rebind_pressed(action: String) -> void:
	active_rebind_action = action
	rebind_buttons[action].text = "Press any key..."
	_log("Listening for input to bind action: " + action.capitalize())


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(settings_file_path)
	if err != OK:
		_log("No custom settings file found at " + settings_file_path + ". Using default parameters.")
		return

	for section in settings.keys():
		for key in settings[section].keys():
			if config.has_section_key(section, key):
				settings[section][key] = config.get_value(section, key)
	_log("Configuration settings loaded successfully from disk.")


func _save_settings() -> void:
	if res_option != null:
		_pull_settings_from_controls()
	_write_settings_file()


func _pull_settings_from_controls() -> void:
	var res_idx := res_option.selected
	if res_idx >= 0:
		settings["video"]["resolution"] = res_option.get_item_text(res_idx)
	settings["video"]["fullscreen"] = fullscreen_check.button_pressed
	settings["video"]["vsync"] = vsync_check.button_pressed

	settings["audio"]["volume_master"] = slider_master.value
	settings["audio"]["volume_music"] = slider_music.value
	settings["audio"]["volume_sfx"] = slider_sfx.value
	settings["audio"]["volume_ambience"] = slider_ambience.value

	settings["gameplay"]["auto_loot"] = check_autoloot.button_pressed
	settings["gameplay"]["quest_tracker"] = check_tracker.button_pressed
	settings["gameplay"]["detailed_tooltips"] = check_tooltips.button_pressed


func _write_settings_file() -> void:
	var config := ConfigFile.new()
	for section in settings.keys():
		for key in settings[section].keys():
			config.set_value(section, key, settings[section][key])

	var err := config.save(settings_file_path)
	if err == OK:
		status_label.text = "Saved successfully"
		_log("Settings saved permanently to " + settings_file_path + ".")
	else:
		status_label.text = "Save failed"
		_log("Failed to save settings file. Error: " + str(err))


func _apply_all_settings() -> void:
	var fs_mode: int = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if bool(settings["video"]["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(fs_mode)
	if fs_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(_resolution_to_size(str(settings["video"]["resolution"])))

	var vs_mode: int = DisplayServer.VSYNC_ENABLED if bool(settings["video"]["vsync"]) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vs_mode)

	_apply_bus_volume("Master", float(settings["audio"]["volume_master"]))
	_apply_bus_volume("Music", float(settings["audio"]["volume_music"]))
	_apply_bus_volume("SFX", float(settings["audio"]["volume_sfx"]))
	_apply_bus_volume("Ambience", float(settings["audio"]["volume_ambience"]))

	for action in settings["keybindings"].keys():
		var keycode: int = int(settings["keybindings"][action])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)

		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func _apply_bus_volume(bus_name: String, val: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, val <= 0.001)
		if val > 0.001:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))


func _resolution_to_size(value: String) -> Vector2i:
	var parts := value.split("x")
	if parts.size() != 2:
		return Vector2i(1280, 720)
	var width := int(parts[0])
	var height := int(parts[1])
	if width <= 0 or height <= 0:
		return Vector2i(1280, 720)
	return Vector2i(width, height)


func _update_ui_controls() -> void:
	if res_option == null:
		return

	for idx in range(res_option.item_count):
		if res_option.get_item_text(idx) == settings["video"]["resolution"]:
			res_option.selected = idx
			break
	fullscreen_check.button_pressed = settings["video"]["fullscreen"]
	vsync_check.button_pressed = settings["video"]["vsync"]

	slider_master.value = settings["audio"]["volume_master"]
	slider_music.value = settings["audio"]["volume_music"]
	slider_sfx.value = settings["audio"]["volume_sfx"]
	slider_ambience.value = settings["audio"]["volume_ambience"]

	check_autoloot.button_pressed = settings["gameplay"]["auto_loot"]
	check_tracker.button_pressed = settings["gameplay"]["quest_tracker"]
	check_tooltips.button_pressed = settings["gameplay"]["detailed_tooltips"]

	for action in rebind_buttons.keys():
		var keycode: int = int(settings["keybindings"][action])
		rebind_buttons[action].text = OS.get_keycode_string(keycode)


func _on_save_pressed() -> void:
	_save_settings()
	_apply_all_settings()


func _on_defaults_pressed() -> void:
	settings["video"] = {
		"resolution": "1280x720",
		"fullscreen": false,
		"vsync": true
	}
	settings["audio"] = {
		"volume_master": 0.8,
		"volume_music": 0.6,
		"volume_sfx": 0.7,
		"volume_ambience": 0.5
	}
	settings["gameplay"] = {
		"auto_loot": true,
		"quest_tracker": true,
		"detailed_tooltips": true
	}
	settings["keybindings"] = {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"turn_left": KEY_A,
		"turn_right": KEY_D,
		"jump": KEY_SPACE
	}
	_update_ui_controls()
	_save_settings()
	_apply_all_settings()
	_log("Restored all configuration settings to default values.")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[Settings] " + msg)
	if log_output != null:
		log_output.text += msg + "\n"
		log_output.scroll_vertical = 99999


func _run_self_test() -> void:
	print("SETTINGS_SELF_TEST: starting verification...")

	if settings["video"]["resolution"] != "1280x720":
		_fail_self_test("Default resolution mismatch")
		return

	settings["video"]["fullscreen"] = true
	settings["video"]["resolution"] = "1920x1080"
	settings["audio"]["volume_master"] = 0.45
	settings["keybindings"]["move_forward"] = KEY_UP

	_write_settings_file()

	settings["video"]["fullscreen"] = false
	settings["video"]["resolution"] = "1280x720"
	settings["audio"]["volume_master"] = 1.0
	settings["keybindings"]["move_forward"] = KEY_W

	_load_settings()

	if settings["video"]["fullscreen"] != true:
		_fail_self_test("Fullscreen flag was not successfully persisted to config file")
		return
	if settings["video"]["resolution"] != "1920x1080":
		_fail_self_test("Resolution value was not successfully persisted")
		return
	if abs(settings["audio"]["volume_master"] - 0.45) > 0.01:
		_fail_self_test("Volume Master float was not successfully persisted")
		return
	if settings["keybindings"]["move_forward"] != KEY_UP:
		_fail_self_test("Rebound Key Forward was not successfully persisted")
		return

	_apply_all_settings()
	var actions := InputMap.action_get_events("move_forward")
	if actions.is_empty():
		_fail_self_test("InputMap actions registry was empty after apply")
		return
	var matched := false
	for ev in actions:
		if ev is InputEventKey and ev.physical_keycode == KEY_UP:
			matched = true
			break
	if not matched:
		_fail_self_test("InputMap event key physical_keycode did not match KEY_UP")
		return

	_delete_settings_file(settings_file_path)
	print("SETTINGS_SELF_TEST_OK: settings load, mutate, save, reload, and InputMap bindings verification passed.")
	get_tree().quit(0)


func _delete_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _fail_self_test(reason: String) -> void:
	if settings_file_path == SETTINGS_SELF_TEST_FILE_PATH:
		_delete_settings_file(settings_file_path)
	push_error("SETTINGS_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
