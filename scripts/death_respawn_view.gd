extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Death state
var is_dead := false
var is_ghost := false
var release_timer := 0.0
var release_timeout := 360.0  # 6 minutes to release
var corpse_run_timer := 0.0
var corpse_distance := 0.0
var resurrection_pending := false
var resurrection_from := ""
var durability_loss_percent := 10.0

# Player stats for simulation
var player_health := 100.0
var player_health_max := 100.0
var player_x := 0.0
var player_y := 0.0
var corpse_x := 0.0
var corpse_y := 0.0
var graveyard_x := -50.0
var graveyard_y := -50.0

# UI references
var status_label: Label
var health_bar: ProgressBar
var death_overlay: ColorRect
var death_panel: PanelContainer
var release_btn: Button
var respawn_btn: Button
var accept_rez_btn: Button
var decline_rez_btn: Button
var rez_panel: PanelContainer
var timer_label: Label
var corpse_label: Label
var info_label: Label
var log_log: TextEdit

const COLOR_GOLD := Color(0.85, 0.72, 0.45)


func _ready() -> void:
	_build_view()
	_update_state()
	if OS.get_environment("ACORE_DEATH_RESPAWN_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _process(delta: float) -> void:
	if is_dead and not is_ghost:
		release_timer += delta
		if release_timer >= release_timeout:
			_force_release()
		_update_timer_display()

	if is_ghost:
		corpse_run_timer += delta
		corpse_distance = sqrt(pow(player_x - corpse_x, 2) + pow(player_y - corpse_y, 2))
		_update_corpse_display()


func _build_view() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.09)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

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

	# Header
	var header := HBoxContainer.new()
	main_stack.add_child(header)
	var title := Label.new()
	title.text = "Death & Respawn System"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var hspacer := Control.new()
	hspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hspacer)
	status_label = Label.new()
	status_label.text = "Alive"
	status_label.modulate = Color(0.3, 1.0, 0.3)
	header.add_child(status_label)

	# Health bar row
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 12)
	main_stack.add_child(health_row)

	var hp_lbl := Label.new()
	hp_lbl.text = "Health:"
	health_row.add_child(hp_lbl)

	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.custom_minimum_size = Vector2(300, 24)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(health_bar)

	# Info labels
	info_label = Label.new()
	info_label.text = "You are alive. Take damage to test the death system."
	info_label.modulate = Color(0.7, 0.7, 0.7)
	main_stack.add_child(info_label)

	# Simulation controls
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 10)
	main_stack.add_child(ctrl_row)

	var dmg_btn := Button.new()
	dmg_btn.text = "Take 35 Damage"
	dmg_btn.pressed.connect(_on_take_damage.bind(35.0))
	ctrl_row.add_child(dmg_btn)

	var lethal_btn := Button.new()
	lethal_btn.text = "Lethal Hit"
	lethal_btn.pressed.connect(_on_take_damage.bind(999.0))
	ctrl_row.add_child(lethal_btn)

	var rez_offer_btn := Button.new()
	rez_offer_btn.text = "Offer Resurrection"
	rez_offer_btn.pressed.connect(_on_offer_resurrection)
	ctrl_row.add_child(rez_offer_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset (Full Health)"
	reset_btn.pressed.connect(_on_reset)
	ctrl_row.add_child(reset_btn)

	# Death overlay (hidden by default)
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.1, 0.0, 0.0, 0.5)
	death_overlay.anchor_right = 1.0
	death_overlay.anchor_bottom = 1.0
	death_overlay.visible = false
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_overlay)

	# Death panel
	death_panel = PanelContainer.new()
	death_panel.visible = false
	death_panel.custom_minimum_size = Vector2(400, 160)
	death_panel.anchor_left = 0.3
	death_panel.anchor_right = 0.7
	death_panel.anchor_top = 0.35
	death_panel.anchor_bottom = 0.55

	var dpanel_style := StyleBoxFlat.new()
	dpanel_style.bg_color = Color(0.08, 0.03, 0.03, 0.92)
	dpanel_style.border_width_left = 2
	dpanel_style.border_width_top = 2
	dpanel_style.border_width_right = 2
	dpanel_style.border_width_bottom = 2
	dpanel_style.border_color = Color(0.6, 0.1, 0.1)
	dpanel_style.corner_radius_top_left = 6
	dpanel_style.corner_radius_top_right = 6
	dpanel_style.corner_radius_bottom_left = 6
	dpanel_style.corner_radius_bottom_right = 6
	death_panel.add_theme_stylebox_override("panel", dpanel_style)
	add_child(death_panel)

	var dp_margin := MarginContainer.new()
	dp_margin.add_theme_constant_override("margin_left", 20)
	dp_margin.add_theme_constant_override("margin_top", 16)
	dp_margin.add_theme_constant_override("margin_right", 20)
	dp_margin.add_theme_constant_override("margin_bottom", 16)
	death_panel.add_child(dp_margin)

	var dp_stack := VBoxContainer.new()
	dp_stack.add_theme_constant_override("separation", 10)
	dp_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	dp_margin.add_child(dp_stack)

	var dead_title := Label.new()
	dead_title.text = "You have died."
	dead_title.add_theme_font_size_override("font_size", 20)
	dead_title.modulate = Color(0.9, 0.2, 0.2)
	dead_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp_stack.add_child(dead_title)

	timer_label = Label.new()
	timer_label.text = ""
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.modulate = Color(0.7, 0.7, 0.7)
	dp_stack.add_child(timer_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dp_stack.add_child(btn_row)

	release_btn = Button.new()
	release_btn.text = "Release Spirit"
	release_btn.custom_minimum_size = Vector2(140, 32)
	release_btn.pressed.connect(_on_release_spirit)
	btn_row.add_child(release_btn)

	respawn_btn = Button.new()
	respawn_btn.text = "Respawn at Corpse"
	respawn_btn.custom_minimum_size = Vector2(160, 32)
	respawn_btn.visible = false
	respawn_btn.pressed.connect(_on_respawn_corpse)
	btn_row.add_child(respawn_btn)

	# Corpse run distance label
	corpse_label = Label.new()
	corpse_label.text = ""
	corpse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corpse_label.modulate = Color(0.6, 0.8, 1.0)
	dp_stack.add_child(corpse_label)

	# Resurrection panel
	rez_panel = PanelContainer.new()
	rez_panel.visible = false
	rez_panel.custom_minimum_size = Vector2(350, 120)
	rez_panel.anchor_left = 0.3
	rez_panel.anchor_right = 0.7
	rez_panel.anchor_top = 0.6
	rez_panel.anchor_bottom = 0.72

	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.04, 0.08, 0.04, 0.92)
	rp_style.border_width_left = 2
	rp_style.border_width_top = 2
	rp_style.border_width_right = 2
	rp_style.border_width_bottom = 2
	rp_style.border_color = Color(0.2, 0.6, 0.2)
	rp_style.corner_radius_top_left = 6
	rp_style.corner_radius_top_right = 6
	rp_style.corner_radius_bottom_left = 6
	rp_style.corner_radius_bottom_right = 6
	rez_panel.add_theme_stylebox_override("panel", rp_style)
	add_child(rez_panel)

	var rp_margin := MarginContainer.new()
	rp_margin.add_theme_constant_override("margin_left", 16)
	rp_margin.add_theme_constant_override("margin_top", 12)
	rp_margin.add_theme_constant_override("margin_right", 16)
	rp_margin.add_theme_constant_override("margin_bottom", 12)
	rez_panel.add_child(rp_margin)

	var rp_stack := VBoxContainer.new()
	rp_stack.add_theme_constant_override("separation", 8)
	rp_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	rp_margin.add_child(rp_stack)

	var rez_title := Label.new()
	rez_title.text = "Resurrection offered"
	rez_title.add_theme_font_size_override("font_size", 16)
	rez_title.modulate = Color(0.3, 1.0, 0.3)
	rez_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_stack.add_child(rez_title)

	var rez_btns := HBoxContainer.new()
	rez_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	rez_btns.add_theme_constant_override("separation", 16)
	rp_stack.add_child(rez_btns)

	accept_rez_btn = Button.new()
	accept_rez_btn.text = "Accept"
	accept_rez_btn.custom_minimum_size = Vector2(100, 30)
	accept_rez_btn.pressed.connect(_on_accept_resurrection)
	rez_btns.add_child(accept_rez_btn)

	decline_rez_btn = Button.new()
	decline_rez_btn.text = "Decline"
	decline_rez_btn.custom_minimum_size = Vector2(100, 30)
	decline_rez_btn.pressed.connect(_on_decline_resurrection)
	rez_btns.add_child(decline_rez_btn)

	# Log
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 60)
	main_stack.add_child(log_log)

	# Footer
	var footer := HBoxContainer.new()
	main_stack.add_child(footer)
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fsp)
	var back := Button.new()
	back.text = "Back to Dashboard"
	back.pressed.connect(func(): get_tree().change_scene_to_file(DASHBOARD_SCENE))
	footer.add_child(back)


func _on_take_damage(amount: float) -> void:
	if is_dead:
		_log("Already dead.")
		return
	player_health -= amount
	if player_health <= 0:
		player_health = 0
		_die()
	health_bar.value = player_health
	_log("Took %.0f damage. Health: %.0f / %.0f" % [amount, player_health, player_health_max])


func _die() -> void:
	is_dead = true
	is_ghost = false
	release_timer = 0.0
	corpse_x = player_x
	corpse_y = player_y
	_log("YOU DIED. Release your spirit or wait for resurrection.")
	_update_state()


func _on_release_spirit() -> void:
	if not is_dead:
		return
	is_ghost = true
	corpse_run_timer = 0.0
	player_x = graveyard_x
	player_y = graveyard_y
	release_btn.visible = false
	respawn_btn.visible = true
	_log("Spirit released. You are now a ghost at the graveyard. Run to your corpse to respawn.")
	_update_state()


func _force_release() -> void:
	_log("Release timer expired. Auto-releasing spirit.")
	_on_release_spirit()


func _on_respawn_corpse() -> void:
	if not is_ghost:
		return
	# Respawn with durability loss and 50% health
	var durability_cost = durability_loss_percent
	player_health = player_health_max * 0.5
	is_dead = false
	is_ghost = false
	player_x = corpse_x
	player_y = corpse_y
	health_bar.value = player_health
	_log("Respawned at corpse with %.0f%% health. Durability loss: %.0f%%." % [50.0, durability_cost])
	_update_state()


func _on_offer_resurrection() -> void:
	if not is_dead:
		_log("You are not dead. Cannot offer resurrection.")
		return
	resurrection_pending = true
	resurrection_from = "Healer"
	rez_panel.visible = true
	_log("Resurrection offered by " + resurrection_from + ".")


func _on_accept_resurrection() -> void:
	if not resurrection_pending:
		return
	resurrection_pending = false
	rez_panel.visible = false
	player_health = player_health_max * 0.35
	is_dead = false
	is_ghost = false
	health_bar.value = player_health
	_log("Resurrection accepted from " + resurrection_from + ". Revived with 35%% health.")
	resurrection_from = ""
	_update_state()


func _on_decline_resurrection() -> void:
	if not resurrection_pending:
		return
	resurrection_pending = false
	rez_panel.visible = false
	_log("Resurrection declined.")


func _on_reset() -> void:
	is_dead = false
	is_ghost = false
	player_health = player_health_max
	health_bar.value = player_health
	release_timer = 0.0
	corpse_run_timer = 0.0
	resurrection_pending = false
	rez_panel.visible = false
	_log("Full reset. Health restored to maximum.")
	_update_state()


func _update_state() -> void:
	if is_ghost:
		status_label.text = "Ghost"
		status_label.modulate = Color(0.5, 0.7, 1.0)
		info_label.text = "You are a ghost. Run to your corpse to respawn, or use the respawn button."
		death_overlay.visible = true
		death_panel.visible = true
	elif is_dead:
		status_label.text = "Dead"
		status_label.modulate = Color(0.9, 0.2, 0.2)
		info_label.text = "You are dead. Release your spirit or wait for resurrection."
		death_overlay.visible = true
		death_panel.visible = true
		release_btn.visible = true
		respawn_btn.visible = false
	else:
		status_label.text = "Alive"
		status_label.modulate = Color(0.3, 1.0, 0.3)
		info_label.text = "You are alive. Take damage to test the death system."
		death_overlay.visible = false
		death_panel.visible = false


func _update_timer_display() -> void:
	var remaining = release_timeout - release_timer
	if remaining < 0:
		remaining = 0
	timer_label.text = "Auto-release in: %d:%02d" % [int(remaining) / 60, int(remaining) % 60]


func _update_corpse_display() -> void:
	corpse_label.text = "Corpse distance: %.0f yards | Ghost time: %d sec" % [corpse_distance, int(corpse_run_timer)]


func _log(msg: String) -> void:
	print("[Death] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Self-test
func _run_self_test() -> void:
	print("DEATH_RESPAWN_SELF_TEST: starting verification...")

	# 1. Take damage
	_on_take_damage(35.0)
	if player_health != 65.0:
		_fail("Health should be 65 after 35 damage, got " + str(player_health))
		return

	# 2. Lethal hit
	_on_take_damage(999.0)
	if not is_dead:
		_fail("Player should be dead after lethal hit")
		return
	if not death_panel.visible:
		_fail("Death panel should be visible")
		return

	# 3. Offer resurrection
	_on_offer_resurrection()
	if not resurrection_pending:
		_fail("Resurrection should be pending after offer")
		return

	# 4. Decline resurrection
	_on_decline_resurrection()
	if resurrection_pending:
		_fail("Resurrection should not be pending after decline")
		return

	# 5. Release spirit
	_on_release_spirit()
	if not is_ghost:
		_fail("Should be ghost after release")
		return
	if player_x != graveyard_x or player_y != graveyard_y:
		_fail("Should be at graveyard after release")
		return

	# 6. Respawn at corpse
	_on_respawn_corpse()
	if is_dead or is_ghost:
		_fail("Should be alive after respawn")
		return
	if player_health != player_health_max * 0.5:
		_fail("Health should be 50%% after corpse respawn, got " + str(player_health))
		return

	# 7. Die again and accept resurrection
	_on_take_damage(999.0)
	_on_offer_resurrection()
	_on_accept_resurrection()
	if is_dead or is_ghost:
		_fail("Should be alive after accepting resurrection")
		return
	if player_health != player_health_max * 0.35:
		_fail("Health should be 35%% after resurrection, got " + str(player_health))
		return

	print("DEATH_RESPAWN_SELF_TEST_OK: damage taking, death state, release spirit, ghost mode, corpse respawn with durability loss, resurrection offer/accept/decline all verified.")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("DEATH_RESPAWN_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
