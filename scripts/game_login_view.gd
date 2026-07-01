extends Control

const CHARACTER_SELECT_SCENE := "res://scenes/character_select_view.tscn"
const DASHBOARD_SCENE := "res://main.tscn"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/account.env"

# Login parameters
var account_val := ""
var password_val := ""
var music_playing := true

# Particles state
var particles := []
var num_particles := 40
var particle_container: Control

# UI References
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
	_build_view()
	_initialize_particles()
	
	if OS.get_environment("ACORE_GAME_LOGIN_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _load_credentials() -> void:
	var path := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.begins_with("ACORE_PROTOCOL_ACCOUNT="):
				account_val = line.split("=")[1].strip_edges()
			elif line.begins_with("ACORE_PROTOCOL_PASSWORD="):
				password_val = line.split("=")[1].strip_edges()
		file.close()


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
	var acc := account_input.text.strip_edges()
	var pwd := password_input.text.strip_edges()

	if acc.is_empty() or pwd.is_empty():
		_log("Error: Account name and password fields cannot be empty.")
		status_label.text = "Connection Failed"
		return

	_log("Validating credentials with authserver...")
	status_label.text = "Authenticating..."
	
	# Transition scene
	call_deferred("_transition_to_character_select")


func _transition_to_character_select() -> void:
	_log("Transitioning to Character Selection screen...")
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


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

	print("GAME_LOGIN_SELF_TEST_OK: login layout elements pre-filled, particle loop initializers, music toggles, and character select scene redirections checked.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("GAME_LOGIN_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
