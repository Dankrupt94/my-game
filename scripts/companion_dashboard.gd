extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const AZEROTHCORE_ROOT := "/run/media/doodbro/New 1tb/AzerothCore"
const AZEROTHCORE_SOURCE := "/run/media/doodbro/New 1tb/AzerothCore/source"
const AZEROTHCORE_BUILD := "/home/doodbro/azeroth-build"
const AZEROTHCORE_RUN := "/run/media/doodbro/New 1tb/AzerothCore/run"
const WOTLK_CLIENT := "/run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK"
const BUNDLE_CLIENT := "/run/media/doodbro/New 1tb/AzerothCore/client"
const BRIDGE_BASE_URL := "http://127.0.0.1:8765"
const BRIDGE_TOKEN_PATH := "res://local_runtime/host-bridge-token.txt"
const SANDBOX_SCENE := "res://scenes/gameplay_sandbox.tscn"
const MULTIPLAYER_SCENE := "res://scenes/multiplayer_sandbox.tscn"
const ENTER_WORLD_SCENE := "res://scenes/enter_world_view.tscn"
const MOVEMENT_SCENE := "res://scenes/movement_reconciliation_view.tscn"
const OBJECT_VISIBILITY_SCENE := "res://scenes/object_visibility_view.tscn"
const INTERACTION_COMBAT_SCENE := "res://scenes/interaction_combat_view.tscn"
const CHAT_SCENE := "res://scenes/stage16_chat_view.tscn"
const SPELLBOOK_SCENE := "res://scenes/stage16_spellbook_view.tscn"
const ACTION_BAR_SCENE := "res://scenes/stage16_action_bar_view.tscn"
const SPELL_CAST_SCENE := "res://scenes/stage16_spell_cast_view.tscn"
const SETTINGS_SCENE := "res://scenes/settings_view.tscn"
const MINIMAP_SCENE := "res://scenes/minimap_view.tscn"
const UI_CUSTOMIZER_SCENE := "res://scenes/ui_customizer_view.tscn"
const MAILBOX_SCENE := "res://scenes/mailbox_view.tscn"
const GUILD_SCENE := "res://scenes/guild_view.tscn"
const AUCTION_HOUSE_SCENE := "res://scenes/auction_house_view.tscn"
const QUEST_SCENE := "res://scenes/quest_view.tscn"
const QUESTGIVER_SCENE := "res://scenes/questgiver_view.tscn"
const GROUP_SCENE := "res://scenes/group_view.tscn"
const AURA_SCENE := "res://scenes/aura_view.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/character_select_view.tscn"
const GAME_LOGIN_SCENE := "res://scenes/game_login_view.tscn"
const TOOLTIP_SCENE := "res://scenes/tooltip_view.tscn"
const DEATH_RESPAWN_SCENE := "res://scenes/death_respawn_view.tscn"
const TRADE_SCENE := "res://scenes/trade_view.tscn"
const VENDOR_SCENE := "res://scenes/stage17_vendor_view.tscn"
const LOCAL_REPORTS := "res://local_reports"
const LOGS_DIR := "/run/media/doodbro/New 1tb/AzerothCore/logs"
const DATA_VIEWS := ["summary", "accounts", "characters", "online", "creatures", "items", "quests", "spells"]

var command_actions := {}
var status_labels := {}
var output_log: TextEdit
var data_view_selector: OptionButton
var data_search_input: LineEdit
var data_limit_input: SpinBox
var data_results: TextEdit
var bridge_available := false
var pending_restart := false
var protocol_thread: Thread
var protocol_bridge: RefCounted


func _ready() -> void:
	_register_command_actions()
	_build_dashboard()
	_run_action("status")


func _exit_tree() -> void:
	if protocol_thread != null and protocol_thread.is_started():
		protocol_thread.wait_to_finish()


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
		"data_browser": {
			"label": "Browse Data",
			"handler": Callable(self, "_action_data_browser"),
		},
		"open_sandbox": {
			"label": "Open Sandbox",
			"handler": Callable(self, "_action_open_sandbox"),
		},
		"open_multiplayer": {
			"label": "Open Multiplayer",
			"handler": Callable(self, "_action_open_multiplayer"),
		},
		"open_enter_world": {
			"label": "Enter World",
			"handler": Callable(self, "_action_open_enter_world"),
		},
		"open_movement": {
			"label": "Move Test",
			"handler": Callable(self, "_action_open_movement"),
		},
		"open_object_visibility": {
			"label": "Objects",
			"handler": Callable(self, "_action_open_object_visibility"),
		},
		"open_interaction_combat": {
			"label": "Interact",
			"handler": Callable(self, "_action_open_interaction_combat"),
		},
		"open_chat": {
			"label": "Chat",
			"handler": Callable(self, "_action_open_chat"),
		},
		"open_spellbook": {
			"label": "Spellbook",
			"handler": Callable(self, "_action_open_spellbook"),
		},
		"open_action_bar": {
			"label": "Action Bar",
			"handler": Callable(self, "_action_open_action_bar"),
		},
		"open_spell_cast": {
			"label": "Cast Spell",
			"handler": Callable(self, "_action_open_spell_cast"),
		},
		"protocol_character_flow": {
			"label": "Check Protocol",
			"handler": Callable(self, "_action_protocol_character_flow"),
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
		"open_settings": {
			"label": "Settings",
			"handler": Callable(self, "_action_open_settings"),
		},
		"open_minimap": {
			"label": "Minimap",
			"handler": Callable(self, "_action_open_minimap"),
		},
		"open_ui_customizer": {
			"label": "UI Customizer",
			"handler": Callable(self, "_action_open_ui_customizer"),
		},
		"open_mailbox": {
			"label": "Mailbox",
			"handler": Callable(self, "_action_open_mailbox"),
		},
		"open_guild": {
			"label": "Guild",
			"handler": Callable(self, "_action_open_guild"),
		},
		"open_vendor": {
			"label": "Vendor",
			"handler": Callable(self, "_action_open_vendor"),
		},
		"open_auction_house": {
			"label": "Auction House",
			"handler": Callable(self, "_action_open_auction_house"),
		},
		"open_quest": {
			"label": "Quest Log",
			"handler": Callable(self, "_action_open_quest"),
		},
		"open_questgiver": {
			"label": "Questgiver",
			"handler": Callable(self, "_action_open_questgiver"),
		},
		"open_group": {
			"label": "Party/Group",
			"handler": Callable(self, "_action_open_group"),
		},
		"open_auras": {
			"label": "Auras",
			"handler": Callable(self, "_action_open_auras"),
		},
		"open_character_select": {
			"label": "Char Selection",
			"handler": Callable(self, "_action_open_character_select"),
		},
		"open_game_login": {
			"label": "Play Game",
			"handler": Callable(self, "_action_open_game_login"),
		},
		"open_tooltips": {
			"label": "Item Tooltips",
			"handler": Callable(self, "_action_open_tooltips"),
		},
		"open_death_respawn": {
			"label": "Death/Respawn",
			"handler": Callable(self, "_action_open_death_respawn"),
		},
		"open_trade": {
			"label": "Trade Window",
			"handler": Callable(self, "_action_open_trade"),
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
	actions.add_child(_action_button("data_browser"))
	actions.add_child(_action_button("open_sandbox"))
	actions.add_child(_action_button("open_multiplayer"))
	actions.add_child(_action_button("open_enter_world"))
	actions.add_child(_action_button("open_movement"))
	actions.add_child(_action_button("open_object_visibility"))
	actions.add_child(_action_button("open_interaction_combat"))
	actions.add_child(_action_button("open_chat"))
	actions.add_child(_action_button("open_spellbook"))
	actions.add_child(_action_button("open_action_bar"))
	actions.add_child(_action_button("open_spell_cast"))
	actions.add_child(_action_button("open_settings"))
	actions.add_child(_action_button("open_minimap"))
	actions.add_child(_action_button("open_ui_customizer"))
	actions.add_child(_action_button("open_mailbox"))
	actions.add_child(_action_button("open_guild"))
	actions.add_child(_action_button("open_vendor"))
	actions.add_child(_action_button("open_auction_house"))
	actions.add_child(_action_button("open_quest"))
	actions.add_child(_action_button("open_questgiver"))
	actions.add_child(_action_button("open_group"))
	actions.add_child(_action_button("open_auras"))
	actions.add_child(_action_button("open_character_select"))
	actions.add_child(_action_button("open_game_login"))
	actions.add_child(_action_button("open_tooltips"))
	actions.add_child(_action_button("open_death_respawn"))
	actions.add_child(_action_button("open_trade"))
	actions.add_child(_action_button("protocol_character_flow"))
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

	main_stack.add_child(_section_title("Read-Only Data Browser"))
	var data_controls := HBoxContainer.new()
	data_controls.add_theme_constant_override("separation", 8)
	main_stack.add_child(data_controls)

	data_view_selector = OptionButton.new()
	data_view_selector.custom_minimum_size = Vector2(150, 38)
	for view in DATA_VIEWS:
		data_view_selector.add_item(view.capitalize())
	data_controls.add_child(data_view_selector)

	data_search_input = LineEdit.new()
	data_search_input.placeholder_text = "Search creatures, items, quests, spells"
	data_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_controls.add_child(data_search_input)

	data_limit_input = SpinBox.new()
	data_limit_input.min_value = 1
	data_limit_input.max_value = 100
	data_limit_input.step = 1
	data_limit_input.value = 25
	data_limit_input.custom_minimum_size = Vector2(90, 38)
	data_controls.add_child(data_limit_input)

	data_controls.add_child(_action_button("data_browser"))

	data_results = TextEdit.new()
	data_results.editable = false
	data_results.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	data_results.custom_minimum_size = Vector2(0, 210)
	data_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(data_results)

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
	side_stack.add_child(_status_row("protocol_character_flow", "Protocol flow"))
	side_stack.add_child(_status_row("docker_mysql", "Docker MySQL"))
	side_stack.add_child(_status_row("auth_binary", "Auth binary"))
	side_stack.add_child(_status_row("world_binary", "World binary"))
	side_stack.add_child(_status_row("runtime_data", "Runtime data"))
	side_stack.add_child(_status_row("wow_exe", "Bundle Wow.exe"))

	side_stack.add_child(_section_title("Data Snapshot"))
	side_stack.add_child(_status_row("data_realm", "Realm"))
	side_stack.add_child(_status_row("data_accounts", "Accounts"))
	side_stack.add_child(_status_row("data_characters", "Characters"))
	side_stack.add_child(_status_row("data_online", "Online"))
	side_stack.add_child(_status_row("data_creatures", "Creatures"))
	side_stack.add_child(_status_row("data_items", "Items"))
	side_stack.add_child(_status_row("data_quests", "Quests"))
	side_stack.add_child(_status_row("data_spells", "Spells"))

	side_stack.add_child(_section_title("Project Rules"))
	side_stack.add_child(_status_row("asset_policy", "Asset policy"))
	_set_status("asset_policy", "Local only", true)
	side_stack.add_child(_body_text("Dashboard actions go through the localhost host bridge. Reports, tokens, logs, and runtime files stay local and ignored by Git."))


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
	_append_log("Checking host bridge...")
	_bridge_get("/health", "Bridge health", Callable(self, "_on_health_response"), 8, false)


func _on_health_response(payload: Dictionary, response_code: int, request_ok: bool) -> void:
	bridge_available = request_ok
	_set_status("bridge", "Online" if bridge_available else "Offline", bridge_available)
	if not bridge_available:
		_append_log("Host bridge is offline. Start the project with the normal launcher or run scripts/start_host_bridge.sh, then refresh status.")
		return

	_bridge_get("/status", "Bridge status", Callable(self, "_on_status_response"), 35)


func _on_status_response(payload: Dictionary, response_code: int, request_ok: bool) -> void:
	if not request_ok:
		return

	var report: Dictionary = payload.get("report", {})
	_apply_status_report(report)
	_refresh_data_summary(false)


func _action_start_stack() -> void:
	_bridge_post("/start", "Bridge start", Callable(self, "_on_stack_control_response"), 260)


func _action_stop_stack() -> void:
	_bridge_post("/stop", "Bridge stop", Callable(self, "_on_stack_control_response"), 260)


func _action_restart_stack() -> void:
	pending_restart = true
	_append_log("Restart stack: bridge stop then bridge start.")
	_bridge_post("/stop", "Bridge stop for restart", Callable(self, "_on_restart_stop_response"), 260)


func _on_restart_stop_response(payload: Dictionary, response_code: int, request_ok: bool) -> void:
	if not request_ok:
		pending_restart = false
		_action_refresh_status()
		return

	_bridge_post("/start", "Bridge start for restart", Callable(self, "_on_stack_control_response"), 260)


func _on_stack_control_response(payload: Dictionary, response_code: int, request_ok: bool) -> void:
	pending_restart = false
	_action_refresh_status()


func _action_data_browser() -> void:
	if data_view_selector == null:
		_refresh_data_summary(true)
		return

	var index := data_view_selector.selected
	if index < 0 or index >= DATA_VIEWS.size():
		index = 0
	var view := str(DATA_VIEWS[index])
	var search := data_search_input.text.strip_edges() if data_search_input != null else ""
	var limit := int(data_limit_input.value) if data_limit_input != null else 25
	_refresh_data_view(view, search, limit, true)


func _refresh_data_summary(log_result: bool) -> void:
	if not bridge_available:
		_append_log("Read-only data browser needs the host bridge to be online.")
		return

	_bridge_get("/data?view=summary&search=&limit=25", "Bridge data summary", Callable(self, "_on_data_response"), 35, log_result)


func _refresh_data_view(view: String, search: String, limit: int, log_result: bool) -> void:
	if not bridge_available:
		_append_log("Read-only data browser needs the host bridge to be online.")
		return

	var path := "/data?view=" + view.uri_encode() + "&search=" + search.uri_encode() + "&limit=" + str(limit)
	_bridge_get(path, "Bridge data " + view, Callable(self, "_on_data_response"), 35, log_result)


func _on_data_response(payload: Dictionary, response_code: int, request_ok: bool) -> void:
	if not request_ok:
		return

	var report: Dictionary = payload.get("report", {})
	_apply_data_report(report)


func _action_open_logs() -> void:
	OS.shell_open(LOGS_DIR)
	_append_log("Opened logs folder: " + LOGS_DIR)


func _action_open_reports() -> void:
	var reports_path := ProjectSettings.globalize_path(LOCAL_REPORTS)
	OS.shell_open(reports_path)
	_append_log("Opened local reports folder: " + reports_path)


func _action_open_sandbox() -> void:
	var error := get_tree().change_scene_to_file(SANDBOX_SCENE)
	if error != OK:
		_append_log("Could not open sandbox scene. Error code: " + str(error))


func _action_open_multiplayer() -> void:
	var error := get_tree().change_scene_to_file(MULTIPLAYER_SCENE)
	if error != OK:
		_append_log("Could not open multiplayer scene. Error code: " + str(error))


func _action_open_enter_world() -> void:
	var error := get_tree().change_scene_to_file(ENTER_WORLD_SCENE)
	if error != OK:
		_append_log("Could not open enter-world scene. Error code: " + str(error))


func _action_open_movement() -> void:
	var error := get_tree().change_scene_to_file(MOVEMENT_SCENE)
	if error != OK:
		_append_log("Could not open movement scene. Error code: " + str(error))


func _action_open_object_visibility() -> void:
	var error := get_tree().change_scene_to_file(OBJECT_VISIBILITY_SCENE)
	if error != OK:
		_append_log("Could not open object visibility scene. Error code: " + str(error))


func _action_open_interaction_combat() -> void:
	var error := get_tree().change_scene_to_file(INTERACTION_COMBAT_SCENE)
	if error != OK:
		_append_log("Could not open interaction scene. Error code: " + str(error))


func _action_open_chat() -> void:
	var error := get_tree().change_scene_to_file(CHAT_SCENE)
	if error != OK:
		_append_log("Could not open chat scene. Error code: " + str(error))


func _action_open_spellbook() -> void:
	var error := get_tree().change_scene_to_file(SPELLBOOK_SCENE)
	if error != OK:
		_append_log("Could not open spellbook scene. Error code: " + str(error))


func _action_open_action_bar() -> void:
	var error := get_tree().change_scene_to_file(ACTION_BAR_SCENE)
	if error != OK:
		_append_log("Could not open action-bar scene. Error code: " + str(error))


func _action_open_spell_cast() -> void:
	var error := get_tree().change_scene_to_file(SPELL_CAST_SCENE)
	if error != OK:
		_append_log("Could not open spell-cast scene. Error code: " + str(error))


func _action_open_settings() -> void:
	var error := get_tree().change_scene_to_file(SETTINGS_SCENE)
	if error != OK:
		_append_log("Could not open settings scene. Error code: " + str(error))


func _action_open_minimap() -> void:
	var error := get_tree().change_scene_to_file(MINIMAP_SCENE)
	if error != OK:
		_append_log("Could not open minimap scene. Error code: " + str(error))


func _action_open_ui_customizer() -> void:
	var error := get_tree().change_scene_to_file(UI_CUSTOMIZER_SCENE)
	if error != OK:
		_append_log("Could not open UI Customizer scene. Error code: " + str(error))


func _action_open_mailbox() -> void:
	var error := get_tree().change_scene_to_file(MAILBOX_SCENE)
	if error != OK:
		_append_log("Could not open mailbox scene. Error code: " + str(error))


func _action_open_guild() -> void:
	var error := get_tree().change_scene_to_file(GUILD_SCENE)
	if error != OK:
		_append_log("Could not open guild scene. Error code: " + str(error))


func _action_open_vendor() -> void:
	var error := get_tree().change_scene_to_file(VENDOR_SCENE)
	if error != OK:
		_append_log("Could not open vendor scene. Error code: " + str(error))


func _action_open_auction_house() -> void:
	var error := get_tree().change_scene_to_file(AUCTION_HOUSE_SCENE)
	if error != OK:
		_append_log("Could not open auction house scene. Error code: " + str(error))


func _action_open_quest() -> void:
	var error := get_tree().change_scene_to_file(QUEST_SCENE)
	if error != OK:
		_append_log("Could not open quest log scene. Error code: " + str(error))


func _action_open_questgiver() -> void:
	var error := get_tree().change_scene_to_file(QUESTGIVER_SCENE)
	if error != OK:
		_append_log("Could not open questgiver scene. Error code: " + str(error))


func _action_open_group() -> void:
	var error := get_tree().change_scene_to_file(GROUP_SCENE)
	if error != OK:
		_append_log("Could not open party/group scene. Error code: " + str(error))


func _action_open_auras() -> void:
	var error := get_tree().change_scene_to_file(AURA_SCENE)
	if error != OK:
		_append_log("Could not open auras scene. Error code: " + str(error))


func _action_open_character_select() -> void:
	var error := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	if error != OK:
		_append_log("Could not open character select scene. Error code: " + str(error))


func _action_open_game_login() -> void:
	var error := get_tree().change_scene_to_file(GAME_LOGIN_SCENE)
	if error != OK:
		_append_log("Could not open game login scene. Error code: " + str(error))


func _action_open_tooltips() -> void:
	var error := get_tree().change_scene_to_file(TOOLTIP_SCENE)
	if error != OK:
		_append_log("Could not open tooltip scene. Error code: " + str(error))


func _action_open_death_respawn() -> void:
	var error := get_tree().change_scene_to_file(DEATH_RESPAWN_SCENE)
	if error != OK:
		_append_log("Could not open death/respawn scene. Error code: " + str(error))


func _action_open_trade() -> void:
	var error := get_tree().change_scene_to_file(TRADE_SCENE)
	if error != OK:
		_append_log("Could not open trade scene. Error code: " + str(error))


func _action_launch_client() -> void:
	_bridge_post("/client/launch", "Bridge client launch", Callable(self, "_on_client_launch_response"), 30)


func _on_client_launch_response(payload: Dictionary, response_code: int, request_ok: bool) -> void:
	pass


func _action_protocol_character_flow() -> void:
	if protocol_thread != null and protocol_thread.is_started():
		_append_log("Protocol character-flow check is already running.")
		return

	protocol_bridge = ProtocolClientBridge.new()
	protocol_thread = Thread.new()
	_set_status("protocol_character_flow", "Running", true)
	_append_log("Running native protocol character-flow check...")
	var error := protocol_thread.start(Callable(self, "_run_protocol_character_flow_thread"))
	if error != OK:
		_set_status("protocol_character_flow", "Could not start", false)
		_append_log("Protocol check thread could not start. Error code: " + str(error))


func _run_protocol_character_flow_thread() -> void:
	var result: Dictionary = protocol_bridge.run_character_flow()
	call_deferred("_on_protocol_character_flow_done", result)


func _on_protocol_character_flow_done(result: Dictionary) -> void:
	if protocol_thread != null:
		protocol_thread.wait_to_finish()
		protocol_thread = null

	var ok := bool(result.get("ok", false))
	var count := int(result.get("character_count", -1))
	if ok:
		_set_status("protocol_character_flow", "Characters: " + str(count), true)
	else:
		_set_status("protocol_character_flow", "Failed", false)

	_append_log(_format_protocol_flow_result(result))


func _format_protocol_flow_result(result: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Protocol character-flow " + ("OK" if bool(result.get("ok", false)) else "failed"))
	if result.has("source"):
		lines.append("Source: " + str(result["source"]))
	lines.append("Exit code: " + str(result.get("exit_code", "?")))
	if result.has("realm_line"):
		lines.append(str(result["realm_line"]))
	if bool(result.get("world_auth_ok", false)):
		lines.append("WORLD_AUTH_OK")
	if bool(result.get("char_enum_ok", false)):
		lines.append("CHAR_ENUM_OK count=" + str(result.get("character_count", "?")))

	var characters: Array = result.get("characters", [])
	for character in characters:
		if typeof(character) == TYPE_DICTIONARY:
			lines.append(_format_protocol_character(character))
		else:
			lines.append(str(character))

	var output := str(result.get("output", "")).strip_edges()
	if not output.is_empty() and not bool(result.get("ok", false)):
		if output.length() > 1200:
			output = output.substr(0, 1200) + "\n...[output truncated]..."
		lines.append(output)
	return "\n".join(lines)


func _format_protocol_character(character: Dictionary) -> String:
	return "CHAR guid=" + str(character.get("guid", "?")) \
		+ " name=\"" + str(character.get("name", "")) + "\"" \
		+ " level=" + str(character.get("level", "?")) \
		+ " race=" + str(character.get("race", "?")) \
		+ " class=" + str(character.get("class", "?")) \
		+ " map=" + str(character.get("map", "?")) \
		+ " pos=(" + str(character.get("x", "?")) + "," + str(character.get("y", "?")) + "," + str(character.get("z", "?")) + ")"


func _apply_status_report(report: Dictionary) -> void:
	if report.is_empty():
		_append_log("Bridge status report was empty.")
		return

	var ports: Dictionary = report.get("ports", {})
	_set_port_status(ports, "mysql")
	_set_port_status(ports, "authserver")
	_set_port_status(ports, "worldserver")
	_set_port_status(ports, "ollama")

	var docker_mysql: Dictionary = report.get("docker_mysql", {})
	var docker_running := bool(docker_mysql.get("container_running", false))
	var docker_found := bool(docker_mysql.get("container_found", false))
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


func _apply_data_report(report: Dictionary) -> void:
	if report.is_empty():
		_append_log("Bridge data report was empty.")
		return

	var views: Dictionary = report.get("views", {})
	var summary: Dictionary = views.get("summary", {})
	var counts: Dictionary = summary.get("counts", {})
	_set_status("data_accounts", str(counts.get("accounts", "?")), counts.has("accounts"))
	_set_status("data_characters", str(counts.get("characters", "?")), counts.has("characters"))
	_set_status("data_online", str(counts.get("online_characters", "?")), counts.has("online_characters"))
	_set_status("data_creatures", str(counts.get("creature_templates", "?")), counts.has("creature_templates"))
	_set_status("data_items", str(counts.get("item_templates", "?")), counts.has("item_templates"))
	_set_status("data_quests", str(counts.get("quest_templates", "?")), counts.has("quest_templates"))
	_set_status("data_spells", str(counts.get("spell_dbc_rows", "?")), counts.has("spell_dbc_rows"))

	var realms: Array = summary.get("realms", [])
	if realms.is_empty():
		_set_status("data_realm", "Missing", false)
	else:
		var realm: Dictionary = realms[0]
		_set_status("data_realm", str(realm.get("name", "Unknown")) + ":" + str(realm.get("port", "?")), true)

	if data_results != null:
		data_results.text = _format_data_report(report)
		data_results.scroll_vertical = 0


func _format_data_report(report: Dictionary) -> String:
	var view := str(report.get("view", "summary"))
	var lines := PackedStringArray()
	lines.append("View: " + view)

	var search := str(report.get("search", ""))
	if not search.is_empty():
		lines.append("Search: " + search)

	var errors: Dictionary = report.get("errors", {})
	if not errors.is_empty():
		lines.append("Errors:")
		for key in errors.keys():
			lines.append("  " + str(key) + ": " + str(errors[key]))
		return "\n".join(lines)

	var views: Dictionary = report.get("views", {})
	if view == "summary":
		var summary: Dictionary = views.get("summary", {})
		var counts: Dictionary = summary.get("counts", {})
		lines.append("Counts:")
		for key in ["accounts", "characters", "online_characters", "creature_templates", "item_templates", "quest_templates", "spell_dbc_rows"]:
			lines.append("  " + key + ": " + str(counts.get(key, "?")))
		var realms: Array = summary.get("realms", [])
		if not realms.is_empty():
			lines.append("Realms:")
			for realm in realms:
				if typeof(realm) == TYPE_DICTIONARY:
					lines.append("  " + str(realm.get("name", "Unknown")) + " " + str(realm.get("address", "?")) + ":" + str(realm.get("port", "?")) + " build " + str(realm.get("gamebuild", "?")))
		return "\n".join(lines)

	var payload: Dictionary = views.get(view, {})
	var rows: Array = payload.get("rows", [])
	lines.append("Rows: " + str(rows.size()))
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			lines.append(_format_data_row(view, row))
	return "\n".join(lines)


func _format_data_row(view: String, row: Dictionary) -> String:
	match view:
		"accounts":
			return str(row.get("id", "?")) + " | " + str(row.get("username", "?")) + " | online " + str(row.get("online", "?")) + " | expansion " + str(row.get("expansion", "?"))
		"characters", "online":
			return str(row.get("guid", "?")) + " | " + str(row.get("name", "?")) + " | level " + str(row.get("level", "?")) + " | map " + str(row.get("map", "?")) + " zone " + str(row.get("zone", "?"))
		"creatures":
			return str(row.get("entry", "?")) + " | " + str(row.get("name", "?")) + " | levels " + str(row.get("minlevel", "?")) + "-" + str(row.get("maxlevel", "?")) + " | faction " + str(row.get("faction", "?"))
		"items":
			return str(row.get("entry", "?")) + " | " + str(row.get("name", "?")) + " | item level " + str(row.get("item_level", "?")) + " | required " + str(row.get("required_level", "?"))
		"quests":
			return str(row.get("id", "?")) + " | " + str(row.get("title", "?")) + " | level " + str(row.get("quest_level", "?")) + " | min " + str(row.get("min_level", "?"))
		"spells":
			return str(row.get("id", "?")) + " | " + str(row.get("name", "?")) + " | level " + str(row.get("spell_level", "?")) + " | mana " + str(row.get("mana_cost", "?"))
		_:
			return JSON.stringify(row)


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


func _bridge_get(path: String, label: String, callback: Callable, timeout: int, log_response: bool = true) -> void:
	_bridge_request(path, HTTPClient.METHOD_GET, PackedStringArray(), "", label, callback, timeout, log_response)


func _bridge_post(path: String, label: String, callback: Callable, timeout: int, log_response: bool = true) -> void:
	var token := _read_bridge_token()
	if token.is_empty():
		pending_restart = false
		_append_log("Bridge token is missing. Start or restart the host bridge, then try again.")
		return

	var headers := PackedStringArray(["X-Acore-Bridge-Token: " + token])
	_bridge_request(path, HTTPClient.METHOD_POST, headers, "", label, callback, timeout, log_response)


func _read_bridge_token() -> String:
	var token_path := ProjectSettings.globalize_path(BRIDGE_TOKEN_PATH)
	if not FileAccess.file_exists(token_path):
		return ""

	var file := FileAccess.open(token_path, FileAccess.READ)
	if file == null:
		return ""

	return file.get_as_text().strip_edges()


func _bridge_request(
	path: String,
	method: int,
	headers: PackedStringArray,
	body: String,
	label: String,
	callback: Callable,
	timeout: int,
	log_response: bool
) -> void:
	var request := HTTPRequest.new()
	request.timeout = timeout
	add_child(request)
	request.request_completed.connect(Callable(self, "_on_bridge_request_completed").bind(label, callback, request, log_response))

	var error := request.request(BRIDGE_BASE_URL + path, headers, method, body)
	if error != OK:
		request.queue_free()
		if log_response:
			_append_log(label + " could not start. Error code: " + str(error))
		if callback.is_valid():
			callback.call({}, 0, false)


func _on_bridge_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	label: String,
	callback: Callable,
	request: HTTPRequest,
	log_response: bool
) -> void:
	var body_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(body_text)
	var payload: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		payload = parsed
	elif not body_text.strip_edges().is_empty():
		payload["error"] = body_text.strip_edges()

	var request_ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 and bool(payload.get("ok", false))
	if log_response:
		_append_bridge_response(label, payload, response_code, result, request_ok)

	if callback.is_valid():
		callback.call(payload, response_code, request_ok)

	request.queue_free()


func _append_bridge_response(label: String, payload: Dictionary, response_code: int, result: int, request_ok: bool) -> void:
	var lines := PackedStringArray()
	lines.append(label + " HTTP " + str(response_code) + (" OK" if request_ok else " failed"))

	if result != HTTPRequest.RESULT_SUCCESS:
		lines.append("Transport result: " + str(result))

	if payload.has("error"):
		lines.append("Error: " + str(payload["error"]))

	var command_result: Dictionary = payload.get("result", {})
	if not command_result.is_empty():
		if command_result.has("exit_code"):
			lines.append("Exit code: " + str(command_result["exit_code"]))
		var output := str(command_result.get("output", "")).strip_edges()
		if output.length() > 4200:
			output = output.substr(0, 1000) + "\n...[output truncated]...\n" + output.substr(output.length() - 2800)
		if not output.is_empty():
			lines.append(output)

	_append_log("\n".join(lines))


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
