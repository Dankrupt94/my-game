extends Control

const AZEROTHCORE_ROOT := "/run/media/doodbro/New 1tb/AzerothCore"
const AZEROTHCORE_SOURCE := "/run/media/doodbro/New 1tb/AzerothCore/source"
const AZEROTHCORE_BUILD := "/home/doodbro/azeroth-build"
const AZEROTHCORE_RUN := "/run/media/doodbro/New 1tb/AzerothCore/run"
const WOTLK_CLIENT := "/run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK"
const BUNDLE_CLIENT := "/run/media/doodbro/New 1tb/AzerothCore/client"
const START_SCRIPT := "/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh"
const STOP_SCRIPT := "/run/media/doodbro/New 1tb/AzerothCore/scripts/stop.sh"
const STATUS_TOOL := "res://tools/audit_server_stack.py"
const BRIDGE_CLIENT := "res://tools/bridge_client.py"
const STATUS_REPORT := "res://local_reports/server-stack-audit.json"
const LOCAL_REPORTS := "res://local_reports"
const LOGS_DIR := "/run/media/doodbro/New 1tb/AzerothCore/logs"

var command_actions := {}
var status_labels := {}
var output_log: TextEdit
var start_stop_blocked := false
var bridge_available := false


func _ready() -> void:
	_register_command_actions()
	_build_dashboard()
	_run_action("status")


func _register_command_actions() -> void:
	command_actions = {
		"status": {
			"label": "Refresh Status",
			"handler": Callable(self, "_action_refresh_status"),
		},
		"start_stack": {
			"label": "Start Stack",
			"handler": Callable(self, "_action_start_stack"),
		},
		"stop_stack": {
			"label": "Stop Stack",
			"handler": Callable(self, "_action_stop_stack"),
		},
		"restart_stack": {
			"label": "Restart Stack",
			"handler": Callable(self, "_action_restart_stack"),
		},
		"open_logs": {
			"label": "Open Logs",
			"handler": Callable(self, "_action_open_logs"),
		},
		"open_reports": {
			"label": "Open Reports",
			"handler": Callable(self, "_action_open_reports"),
		},
		"launch_client": {
			"label": "Launch Client",
			"handler": Callable(self, "_action_launch_client"),
		},
	}


func _build_dashboard() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.09, 0.11)
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

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	var main_panel := _panel()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(main_panel)

	var main_stack := VBoxContainer.new()
	main_stack.add_theme_constant_override("separation", 12)
	main_panel.add_child(main_stack)

	var title := Label.new()
	title.text = "AzerothCore Godot Companion"
	title.add_theme_font_size_override("font_size", 28)
	main_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Local control panel for the AzerothCore server stack, tooling reports, and WotLK client path."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_stack.add_child(subtitle)

	main_stack.add_child(_section_title("Actions"))
	var actions := GridContainer.new()
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	main_stack.add_child(actions)

	actions.add_child(_action_button("status"))
	actions.add_child(_action_button("start_stack"))
	actions.add_child(_action_button("stop_stack"))
	actions.add_child(_action_button("restart_stack"))
	actions.add_child(_action_button("open_logs"))
	actions.add_child(_action_button("open_reports"))
	actions.add_child(_action_button("launch_client"))

	main_stack.add_child(_section_title("Local Paths"))
	main_stack.add_child(_path_row("AzerothCore bundle", AZEROTHCORE_ROOT))
	main_stack.add_child(_path_row("Source checkout", AZEROTHCORE_SOURCE))
	main_stack.add_child(_path_row("Linux build", AZEROTHCORE_BUILD))
	main_stack.add_child(_path_row("Run output", AZEROTHCORE_RUN))
	main_stack.add_child(_path_row("Bundle client", BUNDLE_CLIENT))
	main_stack.add_child(_path_row("Original client", WOTLK_CLIENT))

	main_stack.add_child(_section_title("Command Output"))
	output_log = TextEdit.new()
	output_log.editable = false
	output_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output_log.custom_minimum_size = Vector2(0, 190)
	output_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(output_log)

	var side_panel := _panel()
	side_panel.custom_minimum_size = Vector2(360, 0)
	columns.add_child(side_panel)

	var side_stack := VBoxContainer.new()
	side_stack.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_stack)

	side_stack.add_child(_section_title("Runtime Status"))
	side_stack.add_child(_status_row("bridge", "Host bridge"))
	side_stack.add_child(_status_row("mysql", "MySQL"))
	side_stack.add_child(_status_row("authserver", "Authserver"))
	side_stack.add_child(_status_row("worldserver", "Worldserver"))
	side_stack.add_child(_status_row("ollama", "Ollama"))
	side_stack.add_child(_status_row("docker_mysql", "Docker MySQL"))
	side_stack.add_child(_status_row("auth_binary", "Auth binary"))
	side_stack.add_child(_status_row("world_binary", "World binary"))
	side_stack.add_child(_status_row("runtime_data", "Runtime data"))
	side_stack.add_child(_status_row("wow_exe", "Bundle Wow.exe"))

	side_stack.add_child(_section_title("Project Rules"))
	side_stack.add_child(_status_row("asset_policy", "Asset policy"))
	_set_status("asset_policy", "Local only", true)
	side_stack.add_child(_body_text("Reports are generated under local_reports/ and ignored by Git. Start and stop actions use the existing AzerothCore scripts."))


func _run_action(action_id: String) -> void:
	var action: Dictionary = command_actions.get(action_id, {})
	if action.is_empty():
		_append_log("Unknown action: " + action_id)
		return

	var label := str(action.get("label", action_id))
	_append_log("Action: " + label)

	var handler: Callable = action.get("handler", Callable())
	if not handler.is_valid():
		_append_log("Action has no handler: " + action_id)
		return

	handler.call()


func _action_refresh_status() -> void:
	_append_log("Refreshing local server-stack status...")
	var health := _run_bridge_action("health", 8)
	bridge_available = int(health["exit_code"]) == 0
	_set_status("bridge", "Online" if bridge_available else "Offline", bridge_available)

	if bridge_available:
		var bridge_status := _run_bridge_action("status", 35)
		_append_command_result("Bridge status", bridge_status)
	else:
		var tool_path := ProjectSettings.globalize_path(STATUS_TOOL)
		var result := _run_command("/usr/bin/python3", [tool_path])
		_append_command_result("Direct status", result)
	_load_status_report()


func _action_start_stack() -> void:
	_run_stack_script(START_SCRIPT, "Start stack")


func _action_stop_stack() -> void:
	_run_stack_script(STOP_SCRIPT, "Stop stack")


func _action_restart_stack() -> void:
	_append_log("Restart stack: stop then start.")
	_run_stack_script(STOP_SCRIPT, "Stop stack")
	_run_stack_script(START_SCRIPT, "Start stack")


func _run_stack_script(script_path: String, label: String) -> void:
	if bridge_available:
		var bridge_action := "start" if script_path == START_SCRIPT else "stop"
		var bridge_result := _run_bridge_action(bridge_action, 260)
		_append_command_result("Bridge " + bridge_action, bridge_result)
		_run_action("status")
		return

	if start_stop_blocked:
		_append_log("Start/stop from Snap Godot is blocked because Docker is not visible inside the app sandbox. Use the host script directly for now; the next bridge step will fix this.")
		return

	if not FileAccess.file_exists(script_path):
		_append_log(label + " script missing: " + script_path)
		return

	_append_log("Running: " + label)
	var result := _run_command("/usr/bin/env", ["bash", script_path])
	_append_log(result["output"])
	_append_log(label + " exit code: " + str(result["exit_code"]))
	_run_action("status")


func _action_open_logs() -> void:
	OS.shell_open(LOGS_DIR)
	_append_log("Opened logs folder: " + LOGS_DIR)


func _action_open_reports() -> void:
	var reports_path := ProjectSettings.globalize_path(LOCAL_REPORTS)
	OS.shell_open(reports_path)
	_append_log("Opened local reports folder: " + reports_path)


func _action_launch_client() -> void:
	var wow_path := BUNDLE_CLIENT + "/Wow.exe"
	if not FileAccess.file_exists(wow_path):
		_append_log("Bundle Wow.exe not found at: " + wow_path)
		return

	if not _command_exists("wine"):
		_append_log("Wine is not installed yet, so the Windows client cannot be launched from this Linux dashboard.")
		return

	var pid := OS.create_process("/usr/bin/env", PackedStringArray(["wine", wow_path]), false)
	if pid <= 0:
		_append_log("Client launch failed.")
	else:
		_append_log("Client launch started with process id: " + str(pid))


func _load_status_report() -> void:
	var report_path := ProjectSettings.globalize_path(STATUS_REPORT)
	if not FileAccess.file_exists(report_path):
		_append_log("Status report not found yet: " + report_path)
		return

	var file := FileAccess.open(report_path, FileAccess.READ)
	if file == null:
		_append_log("Could not open status report: " + report_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_append_log("Status report JSON could not be parsed.")
		return

	var report: Dictionary = parsed
	var ports: Dictionary = report.get("ports", {})
	_set_port_status(ports, "mysql")
	_set_port_status(ports, "authserver")
	_set_port_status(ports, "worldserver")
	_set_port_status(ports, "ollama")

	var docker_mysql: Dictionary = report.get("docker_mysql", {})
	var runtime_environment: Dictionary = report.get("runtime_environment", {})
	var docker_running := bool(docker_mysql.get("container_running", false))
	var docker_found := bool(docker_mysql.get("container_found", false))
	var docker_present := bool(docker_mysql.get("docker_present", false))
	var inside_snap := bool(runtime_environment.get("inside_snap", false))
	start_stop_blocked = (not bridge_available) and inside_snap and not docker_present
	if start_stop_blocked:
		_set_status("docker_mysql", "Snap blocked", false)
	else:
		_set_status("docker_mysql", "Running" if docker_running else ("Stopped" if docker_found else "Not found"), docker_running)

	var binaries: Dictionary = report.get("binaries", {})
	_set_path_status(binaries, "authserver", "auth_binary")
	_set_path_status(binaries, "worldserver", "world_binary")

	var data: Dictionary = report.get("data", {})
	var data_file_counts: Dictionary = report.get("data_file_counts", {})
	var runtime_data_ready := bool(report.get("runtime_data_ready", false))
	_set_data_status(data, data_file_counts, runtime_data_ready)

	var clients: Dictionary = report.get("client_candidates", {})
	_set_path_status(clients, "Wow.exe", "wow_exe")


func _set_port_status(ports: Dictionary, name: String) -> void:
	var info: Dictionary = ports.get(name, {})
	var listening := bool(info.get("listening", false))
	_set_status(name, "Listening" if listening else "Not listening", listening)


func _set_path_status(section: Dictionary, name: String, label_key: String) -> void:
	var info: Dictionary = section.get(name, {})
	var exists := bool(info.get("exists", false))
	var executable := bool(info.get("executable", false))
	var value := "Executable" if executable else ("Found" if exists else "Missing")
	_set_status(label_key, value, exists)


func _set_data_status(data: Dictionary, data_file_counts: Dictionary, runtime_data_ready: bool) -> void:
	var required := ["maps_dir", "dbc_dir", "vmaps_dir", "mmaps_dir"]
	var missing := PackedStringArray()
	for key in required:
		var info: Dictionary = data.get(key, {})
		if not bool(info.get("exists", false)):
			missing.append(key.replace("_dir", "").replace("_", " "))

	if not data_file_counts.is_empty():
		if int(data_file_counts.get("maps_files", 0)) <= 0:
			missing.append("maps files")
		if int(data_file_counts.get("dbc_files", 0)) <= 0:
			missing.append("DBC files")
		var vmap_count := int(data_file_counts.get("vmap_tree_files", 0)) + int(data_file_counts.get("vmap_tile_files", 0))
		if vmap_count <= 0:
			missing.append("VMap files")
		var mmap_count := int(data_file_counts.get("mmap_files", 0)) + int(data_file_counts.get("mmtile_files", 0))
		if mmap_count <= 0:
			missing.append("MMap files")

	if missing.is_empty():
		_set_status("runtime_data", "Ready", runtime_data_ready or data_file_counts.is_empty())
	else:
		_set_status("runtime_data", "Missing " + ", ".join(missing), false)


func _command_exists(command: String) -> bool:
	var result := _run_command("/usr/bin/env", ["bash", "-lc", "command -v " + command])
	return int(result["exit_code"]) == 0


func _run_bridge_action(action: String, timeout: int) -> Dictionary:
	var client_path := ProjectSettings.globalize_path(BRIDGE_CLIENT)
	return _run_command("/usr/bin/python3", [client_path, action, "--compact", "--timeout", str(timeout)])


func _run_command(executable: String, args: Array) -> Dictionary:
	var output := []
	var packed_args := PackedStringArray()
	for arg in args:
		packed_args.append(str(arg))

	var exit_code := OS.execute(executable, packed_args, output, true, false)
	var text := ""
	for chunk in output:
		text += str(chunk)
	if text.strip_edges().is_empty():
		text = "(no output)"

	return {
		"exit_code": exit_code,
		"output": text.strip_edges(),
	}


func _append_command_result(label: String, result: Dictionary) -> void:
	var output := str(result["output"])
	if output.length() > 4200:
		output = output.substr(0, 1000) + "\n...[output truncated]...\n" + output.substr(output.length() - 2800)
	_append_log(label + " exit code: " + str(result["exit_code"]) + "\n" + output)


func _append_log(text: String) -> void:
	if output_log == null:
		return
	var stamp := Time.get_datetime_string_from_system(false, true)
	output_log.text += "[" + stamp + "] " + text.strip_edges() + "\n"
	output_log.scroll_vertical = output_log.get_line_count()


func _set_status(key: String, value: String, ok: bool) -> void:
	if not status_labels.has(key):
		return
	var label: Label = status_labels[key]
	label.text = value
	var color := Color(0.45, 0.84, 0.58) if ok else Color(0.95, 0.61, 0.42)
	label.add_theme_color_override("font_color", color)


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


func _action_button(action_id: String) -> Button:
	var action: Dictionary = command_actions.get(action_id, {})
	var label := str(action.get("label", action_id))
	return _button(label, Callable(self, "_run_action").bind(action_id))


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
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


func _status_row(key: String, name: String) -> HBoxContainer:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "Unknown"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(value_label)
	status_labels[key] = value_label

	return row
