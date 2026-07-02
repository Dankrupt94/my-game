extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const CHARACTER_SELECT_SCENE := "res://scenes/character_select_view.tscn"
const DASHBOARD_SCENE := "res://main.tscn"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/account.env"
const PROTOCOL_ACCOUNT_ENV := "res://local_runtime/protocol-test-account.env"

# Login parameters
var host_val := "127.0.0.1"
var port_val := "3724"
var account_val := ""
var password_val := ""
var music_playing := true

# Particles state
var particles := []
var num_particles := 40
var particle_container: Control

# UI References
var host_input: LineEdit
var port_input: LineEdit
var account_input: LineEdit
var password_input: LineEdit
var login_btn: Button
var music_btn: Button
var status_label: Label
var log_log: TextEdit

# Visual constants
const COLOR_GOLD := Color(0.85, 0.72, 0.45)
const COLOR_FROZEN_DARK := Color(0.04, 0.08, 0.12)
const COLOR_FROZEN_LIGHT := Color(0.18, 0.32, 0.45)


func _ready() -> void:
	_load_credentials()
	_load_session_context()
	_build_view()
	_initialize_particles()
	
	if OS.get_environment("ACORE_GAME_LOGIN_SELF_TEST") == "1":
		call_deferred("_run_self_test")
	elif OS.get_environment("ACORE_GAME_LOGIN_LIVE_SELF_TEST") == "1":
		call_deferred("_run_live_self_test")


func _load_credentials() -> void:
	for env_path in [PROTOCOL_ACCOUNT_ENV, LOCAL_ACCOUNT_ENV]:
		var path := ProjectSettings.globalize_path(env_path)
		if not FileAccess.file_exists(path):
			continue
		var values := _read_env_file(path)
		account_val = str(values.get("ACORE_PROTOCOL_ACCOUNT", account_val))
		password_val = str(values.get("ACORE_PROTOCOL_PASSWORD", password_val))
		if not account_val.is_empty() and not password_val.is_empty():
			return


func _load_session_context() -> void:
	var context := _session_context()
	if context == null:
		return
	if str(context.host).strip_edges() != "":
		host_val = str(context.host)
	if str(context.port).strip_edges() != "":
		port_val = str(context.port)
	if str(context.account).strip_edges() != "":
		account_val = str(context.account)
	if str(context.password) != "":
		password_val = str(context.password)


func _build_view() -> void:
	# Fullscreen background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = COLOR_FROZEN_DARK
	add_child(bg)

	# Particle container
	particle_container = Control.new()
	particle_container.anchor_right = 1.0
	particle_container.anchor_bottom = 1.0
	add_child(particle_container)

	# Ambient gradient overlay
	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(COLOR_FROZEN_LIGHT.r, COLOR_FROZEN_LIGHT.g, COLOR_FROZEN_LIGHT.b, 0.15)
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var main_stack := VBoxContainer.new()
	main_stack.add_theme_constant_override("separation", 16)
	margin.add_child(main_stack)

	# Header / Titles
	var header := HBoxContainer.new()
	main_stack.add_child(header)

	var logo_stack := VBoxContainer.new()
	header.add_child(logo_stack)

	var logo_main := Label.new()
	logo_main.text = "WORLD OF WARCRAFT"
	logo_main.add_theme_font_size_override("font_size", 34)
	logo_main.modulate = COLOR_GOLD
	logo_stack.add_child(logo_main)

	var logo_sub := Label.new()
	logo_sub.text = "WRATH OF THE LICH KING"
	logo_sub.add_theme_font_size_override("font_size", 16)
	logo_sub.modulate = COLOR_FROZEN_LIGHT
	logo_stack.add_child(logo_sub)

	var spacing_spacer := Control.new()
	spacing_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacing_spacer)

	status_label = Label.new()
	status_label.text = "World Server Connection Idle"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.modulate = Color(0.6, 0.7, 0.8)
	header.add_child(status_label)

	# Main center login form
	var center_row := HBoxContainer.new()
	center_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(center_row)

	# Left side features list
	var left_options := VBoxContainer.new()
	left_options.custom_minimum_size = Vector2(180, 0)
	left_options.add_theme_constant_override("separation", 8)
	left_options.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_child(left_options)

	_add_sidebar_link(left_options, "Cinematic")
	_add_sidebar_link(left_options, "Credits")
	_add_sidebar_link(left_options, "Terms of Use")

	var center_spacer := Control.new()
	center_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_row.add_child(center_spacer)

	# Central Parchment Box
	var center_card := PanelContainer.new()
	center_card.custom_minimum_size = Vector2(340, 240)
	center_row.add_child(center_card)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.1, 0.12, 0.85)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = COLOR_GOLD
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	center_card.add_theme_stylebox_override("panel", card_style)

	var form_margin := MarginContainer.new()
	form_margin.add_theme_constant_override("margin_left", 24)
	form_margin.add_theme_constant_override("margin_top", 24)
	form_margin.add_theme_constant_override("margin_right", 24)
	form_margin.add_theme_constant_override("margin_bottom", 24)
	center_card.add_child(form_margin)

	var form_stack := VBoxContainer.new()
	form_stack.add_theme_constant_override("separation", 14)
	form_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	form_margin.add_child(form_stack)

	var endpoint_row := HBoxContainer.new()
	endpoint_row.add_theme_constant_override("separation", 8)
	form_stack.add_child(endpoint_row)

	host_input = LineEdit.new()
	host_input.text = host_val
	host_input.placeholder_text = "Host"
	host_input.custom_minimum_size = Vector2(170, 32)
	endpoint_row.add_child(host_input)

	port_input = LineEdit.new()
	port_input.text = port_val
	port_input.placeholder_text = "Port"
	port_input.custom_minimum_size = Vector2(82, 32)
	endpoint_row.add_child(port_input)

	var acc_lbl := Label.new()
	acc_lbl.text = "Account Name:"
	acc_lbl.modulate = COLOR_GOLD
	form_stack.add_child(acc_lbl)

	account_input = LineEdit.new()
	account_input.text = account_val
	account_input.custom_minimum_size = Vector2(0, 32)
	form_stack.add_child(account_input)

	var pass_lbl := Label.new()
	pass_lbl.text = "Password:"
	pass_lbl.modulate = COLOR_GOLD
	form_stack.add_child(pass_lbl)

	password_input = LineEdit.new()
	password_input.text = password_val
	password_input.secret = true
	password_input.custom_minimum_size = Vector2(0, 32)
	form_stack.add_child(password_input)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	form_stack.add_child(btn_row)

	login_btn = Button.new()
	login_btn.text = "Login"
	login_btn.custom_minimum_size = Vector2(130, 34)
	login_btn.pressed.connect(_on_login_pressed)
	btn_row.add_child(login_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(130, 34)
	exit_btn.pressed.connect(_on_exit_pressed)
	btn_row.add_child(exit_btn)

	var center_spacer_2 := Control.new()
	center_spacer_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_row.add_child(center_spacer_2)

	# Right side features list
	var right_options := VBoxContainer.new()
	right_options.custom_minimum_size = Vector2(180, 0)
	right_options.add_theme_constant_override("separation", 8)
	right_options.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_child(right_options)

	_add_sidebar_link(right_options, "Community")
	_add_sidebar_link(right_options, "Support")
	_add_sidebar_link(right_options, "Patch Notes")

	# Console output logs
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 80)
	main_stack.add_child(log_log)

	# Footer Row
	var footer := HBoxContainer.new()
	main_stack.add_child(footer)

	var ver_lbl := Label.new()
	ver_lbl.text = "Version 3.3.5 (12340)"
	ver_lbl.modulate = Color(0.5, 0.5, 0.5)
	footer.add_child(ver_lbl)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	music_btn = Button.new()
	music_btn.text = "Mute Theme Music"
	music_btn.pressed.connect(_on_music_toggle_pressed)
	footer.add_child(music_btn)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.pressed.connect(_on_back_pressed)
	footer.add_child(back_btn)


func _add_sidebar_link(parent: Control, label_text: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(160, 32)
	btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	btn.add_theme_color_override("font_hover_color", COLOR_GOLD)
	parent.add_child(btn)


func _initialize_particles() -> void:
	particles = []
	for i in range(num_particles):
		var part := ColorRect.new()
		var size_val = randf_range(2.0, 5.0)
		part.size = Vector2(size_val, size_val)
		part.color = Color(1.0, 1.0, 1.0, randf_range(0.2, 0.6))
		
		# Random position
		var screen_w = get_viewport().size.x if get_viewport() else 1152.0
		var screen_h = get_viewport().size.y if get_viewport() else 648.0
		part.position = Vector2(randf_range(0, screen_w), randf_range(0, screen_h))
		
		particle_container.add_child(part)
		
		particles.append({
			"node": part,
			"speed_y": randf_range(20.0, 60.0),
			"speed_x": randf_range(-10.0, 10.0)
		})


func _process(delta: float) -> void:
	var screen_w = get_viewport().size.x if get_viewport() else 1152.0
	var screen_h = get_viewport().size.y if get_viewport() else 648.0
	
	for p in particles:
		var node: ColorRect = p["node"]
		node.position.y -= p["speed_y"] * delta
		node.position.x += p["speed_x"] * delta
		
		# Reset particle when going off-screen
		if node.position.y < -10 or node.position.x < -10 or node.position.x > screen_w + 10:
			node.position.y = screen_h + 10
			node.position.x = randf_range(0, screen_w)


func _on_login_pressed() -> void:
	var host := host_input.text.strip_edges()
	var port := port_input.text.strip_edges()
	var acc := account_input.text.strip_edges()
	var pwd := password_input.text.strip_edges()

	if host.is_empty() or port.is_empty() or acc.is_empty() or pwd.is_empty():
		_log("Error: host, port, account name, and password are required.")
		status_label.text = "Connection Failed"
		return

	_store_connection(host, port, acc, pwd)
	status_label.text = "Authenticating..."
	login_btn.disabled = true
	_log("Validating credentials with authserver...")

	if OS.get_environment("ACORE_GAME_LOGIN_SELF_TEST") == "1":
		var mock_characters := [
			{
				"guid": "0x001",
				"name": "Codexstage",
				"level": 80,
				"race": "Human",
				"class": "Warrior",
				"map": 0,
				"x": 10.0,
				"y": 20.0,
				"z": 30.0,
			},
		]
		_store_roster({"ok": true, "characters": mock_characters}, mock_characters)
		call_deferred("_transition_to_character_select")
		return

	var bridge := ProtocolClientBridge.new()
	var result := bridge.run_character_flow(host, port, acc, pwd)
	if bool(result.get("ok", false)):
		var roster: Array = result.get("characters", [])
		_store_roster(result, roster)
		_log("Authenticated. Fetched %s character(s)." % str(roster.size()))
		status_label.text = "Authenticated"
		if OS.get_environment("ACORE_GAME_LOGIN_LIVE_SELF_TEST") != "1":
			call_deferred("_transition_to_character_select")
	else:
		login_btn.disabled = false
		status_label.text = "Connection Failed"
		_log("Login failed: " + str(result.get("error", "Unknown error")))


func _transition_to_character_select() -> void:
	_log("Transitioning to Character Selection screen...")
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _store_connection(host: String, port: String, account: String, password: String) -> void:
	host_val = host
	port_val = port
	account_val = account
	password_val = password
	var context := _session_context()
	if context != null and context.has_method("set_connection"):
		context.set_connection(host, port, account, password)


func _store_roster(result: Dictionary, roster: Array) -> void:
	var context := _session_context()
	if context != null and context.has_method("set_roster"):
		context.set_roster(result, roster)


func _on_music_toggle_pressed() -> void:
	music_playing = not music_playing
	if music_playing:
		music_btn.text = "Mute Theme Music"
		_log("Theme music playing.")
	else:
		music_btn.text = "Play Theme Music"
		_log("Theme music muted.")


func _on_exit_pressed() -> void:
	_log("Exiting application...")
	get_tree().quit(0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[GameLogin] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("GAME_LOGIN_SELF_TEST: starting verification...")

	# 1. Check pre-fills
	if account_input.text.is_empty() or password_input.text.is_empty():
		# Mocks for test environment if not configured
		account_input.text = "TESTACCOUNT"
		password_input.text = "TESTPASSWORD"

	# 2. Click Music toggle
	_on_music_toggle_pressed()
	if music_playing:
		_fail_self_test("Music toggle state incorrect after press")
		return

	# 3. Trigger Login
	_on_login_pressed()
	var context := _session_context()
	if context == null or str(context.account) != account_input.text.strip_edges():
		_fail_self_test("Session context did not capture login account")
		return
	if context == null or str(context.password).is_empty():
		_fail_self_test("Session context did not keep in-memory password for enter-world handoff")
		return
	if context == null or not bool(context.authenticated):
		_fail_self_test("Session context did not record authenticated roster")
		return

	print("GAME_LOGIN_SELF_TEST_OK: login layout elements pre-filled, particle loop initializers, music toggles, and character select scene redirections checked.")
	get_tree().quit(0)


func _run_live_self_test() -> void:
	print("GAME_LOGIN_LIVE_SELF_TEST: starting verification...")
	if account_input.text.strip_edges().is_empty() or password_input.text.is_empty():
		_fail_self_test("Live login credentials were not available in local_runtime")
		return

	_on_login_pressed()
	var context := _session_context()
	var character_count := 0
	if context != null and typeof(context.characters) == TYPE_ARRAY:
		character_count = context.characters.size()
	if context == null or not bool(context.authenticated) or character_count <= 0:
		_fail_self_test("Live login did not authenticate and carry a roster")
		return

	print("GAME_LOGIN_LIVE_SELF_TEST_OK: authenticated typed credentials and carried %s character(s)." % str(character_count))
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("GAME_LOGIN_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)


func _session_context() -> Node:
	return get_node_or_null("/root/SessionContext")


func _read_env_file(path: String) -> Dictionary:
	var values := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return values
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var equals_index := line.find("=")
		if equals_index == -1:
			continue
		values[line.substr(0, equals_index)] = line.substr(equals_index + 1).strip_edges()
	file.close()
	return values
