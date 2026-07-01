extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Aura State
var active_auras := []

# UI references
var buffs_container: HFlowContainer
var debuffs_container: HFlowContainer
var status_label: Label
var log_log: TextEdit
var tick_timer: Timer

# Custom formatting constants
const COLOR_BORDER := Color(0.85, 0.72, 0.45) # Gold
const COLOR_BUFF := Color(0.12, 0.62, 0.16)
const COLOR_DEBUFF := Color(0.72, 0.12, 0.16)


func _ready() -> void:
	_build_view()
	_update_displays()

	# Start active countdown timer
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_timer_timeout)
	add_child(tick_timer)

	if OS.get_environment("ACORE_AURAS_SELF_TEST") == "1":
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

	# Header
	var header := HBoxContainer.new()
	main_stack.add_child(header)

	var title := Label.new()
	title.text = "Auras & Effects"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "No active auras"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# Buffs panel
	var buffs_card := PanelContainer.new()
	buffs_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(buffs_card)

	var buffs_margin := MarginContainer.new()
	buffs_margin.add_theme_constant_override("margin_left", 12)
	buffs_margin.add_theme_constant_override("margin_top", 10)
	buffs_margin.add_theme_constant_override("margin_right", 12)
	buffs_margin.add_theme_constant_override("margin_bottom", 10)
	buffs_card.add_child(buffs_margin)

	var buffs_stack := VBoxContainer.new()
	buffs_stack.add_theme_constant_override("separation", 8)
	buffs_margin.add_child(buffs_stack)

	var buffs_lbl := Label.new()
	buffs_lbl.text = "Active Buffs (Click to dismiss):"
	buffs_lbl.modulate = Color(0.4, 0.8, 0.4)
	buffs_stack.add_child(buffs_lbl)

	buffs_container = HFlowContainer.new()
	buffs_container.add_theme_constant_override("h_separation", 10)
	buffs_container.add_theme_constant_override("v_separation", 10)
	buffs_stack.add_child(buffs_container)

	# Debuffs panel
	var debuffs_card := PanelContainer.new()
	debuffs_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(debuffs_card)

	var debuffs_margin := MarginContainer.new()
	debuffs_margin.add_theme_constant_override("margin_left", 12)
	debuffs_margin.add_theme_constant_override("margin_top", 10)
	debuffs_margin.add_theme_constant_override("margin_right", 12)
	debuffs_margin.add_theme_constant_override("margin_bottom", 10)
	debuffs_card.add_child(debuffs_margin)

	var debuffs_stack := VBoxContainer.new()
	debuffs_stack.add_theme_constant_override("separation", 8)
	debuffs_margin.add_child(debuffs_stack)

	var debuffs_lbl := Label.new()
	debuffs_lbl.text = "Active Debuffs (Cannot be dismissed):"
	debuffs_lbl.modulate = Color(0.9, 0.3, 0.3)
	debuffs_stack.add_child(debuffs_lbl)

	debuffs_container = HFlowContainer.new()
	debuffs_container.add_theme_constant_override("h_separation", 10)
	debuffs_container.add_theme_constant_override("v_separation", 10)
	debuffs_stack.add_child(debuffs_container)

	# Control Buttons Row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	main_stack.add_child(btn_row)

	var add_buff_1 := Button.new()
	add_buff_1.text = "Add Might Buff"
	add_buff_1.pressed.connect(_on_apply_might_pressed)
	btn_row.add_child(add_buff_1)

	var add_buff_2 := Button.new()
	add_buff_2.text = "Add Shield Buff"
	add_buff_2.pressed.connect(_on_apply_shield_pressed)
	btn_row.add_child(add_buff_2)

	var add_debuff_1 := Button.new()
	add_debuff_1.text = "Add Pain Debuff"
	add_debuff_1.pressed.connect(_on_apply_pain_pressed)
	btn_row.add_child(add_debuff_1)

	var add_debuff_2 := Button.new()
	add_debuff_2.text = "Add Rend Debuff"
	add_debuff_2.pressed.connect(_on_apply_rend_pressed)
	btn_row.add_child(add_debuff_2)

	# Log Console
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 80)
	main_stack.add_child(log_log)

	# Bottom Actions Row
	var actions_row := HBoxContainer.new()
	main_stack.add_child(actions_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.custom_minimum_size = Vector2(160, 38)
	back_btn.pressed.connect(_on_back_pressed)
	actions_row.add_child(back_btn)


func _on_timer_timeout() -> void:
	_tick_auras(1.0)


func _tick_auras(seconds: float) -> void:
	var expired_idx := []
	for idx in range(active_auras.size() - 1, -1, -1):
		var aura = active_auras[idx]
		aura["duration"] -= seconds
		if aura["duration"] <= 0:
			_log("Aura expired: " + aura["name"])
			active_auras.remove_at(idx)
			
	_update_displays()


func _apply_aura(id: int, name: String, type: String, duration: float, stacks: int, color: Color) -> void:
	# Check if aura already exists, refresh if so
	for aura in active_auras:
		if aura["id"] == id:
			aura["duration"] = duration
			aura["stacks"] = stacks
			_log("Refreshed aura: " + name)
			_update_displays()
			return

	active_auras.append({
		"id": id,
		"name": name,
		"type": type,
		"duration": duration,
		"stacks": stacks,
		"color": color
	})
	_log("Applied aura: " + name + " (" + type + ")")
	_update_displays()


func _update_displays() -> void:
	for child in buffs_container.get_children():
		child.queue_free()
	for child in debuffs_container.get_children():
		child.queue_free()

	var buff_count := 0
	var debuff_count := 0

	for idx in range(active_auras.size()):
		var aura = active_auras[idx]
		var frame := Button.new()
		frame.custom_minimum_size = Vector2(110, 48)
		frame.pressed.connect(_on_aura_pressed.bind(idx))

		var style := StyleBoxFlat.new()
		style.bg_color = aura["color"]
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = COLOR_BORDER
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		frame.add_theme_stylebox_override("normal", style)

		var stack := VBoxContainer.new()
		stack.anchor_right = 1.0
		stack.anchor_bottom = 1.0
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		frame.add_child(stack)

		var name_lbl := Label.new()
		name_lbl.text = aura["name"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(name_lbl)

		var dur_lbl := Label.new()
		dur_lbl.text = "%ds" % int(aura["duration"])
		if aura["stacks"] > 1:
			dur_lbl.text += " (x%d)" % aura["stacks"]
		dur_lbl.add_theme_font_size_override("font_size", 11)
		dur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(dur_lbl)

		if aura["type"] == "Buff":
			buffs_container.add_child(frame)
			buff_count += 1
		else:
			debuffs_container.add_child(frame)
			debuff_count += 1

	status_label.text = "Buffs: %d | Debuffs: %d" % [buff_count, debuff_count]


func _on_aura_pressed(idx: int) -> void:
	if idx < 0 or idx >= active_auras.size():
		return
	
	var aura = active_auras[idx]
	_on_try_cancel_aura(aura, idx)


func _on_try_cancel_aura(aura: Dictionary, idx: int) -> bool:
	if aura["type"] == "Buff":
		_log("Dismissed buff: " + aura["name"])
		active_auras.remove_at(idx)
		_update_displays()
		return true
	else:
		_log("Error: Cannot manually dismiss debuff: " + aura["name"])
		return false


func _on_apply_might_pressed() -> void:
	_apply_aura(1001, "Might", "Buff", 300.0, 1, COLOR_BUFF)


func _on_apply_shield_pressed() -> void:
	_apply_aura(1002, "Shield", "Buff", 30.0, 1, Color(0.12, 0.45, 0.65))


func _on_apply_pain_pressed() -> void:
	_apply_aura(2001, "Pain", "Debuff", 18.0, 1, COLOR_DEBUFF)


func _on_apply_rend_pressed() -> void:
	_apply_aura(2002, "Rend", "Debuff", 15.0, 2, Color(0.65, 0.25, 0.12))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[Aura] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("AURAS_SELF_TEST: starting verification...")

	# 1. Verify initially 0 auras
	if active_auras.size() != 0:
		_fail_self_test("Active auras list should start empty")
		return

	# 2. Apply Blessing of Might (300s duration)
	_apply_aura(1001, "Might", "Buff", 300.0, 1, COLOR_BUFF)
	if active_auras.size() != 1 or active_auras[0]["name"] != "Might":
		_fail_self_test("Might buff was not applied successfully")
		return

	# 3. Apply Shadow Word: Pain (3s duration)
	_apply_aura(2001, "Pain", "Debuff", 3.0, 1, COLOR_DEBUFF)
	if active_auras.size() != 2 or active_auras[1]["name"] != "Pain":
		_fail_self_test("Pain debuff was not applied successfully")
		return

	# 4. Try to cancel Pain debuff (should fail)
	var cancelled_debuff = _on_try_cancel_aura(active_auras[1], 1)
	if cancelled_debuff:
		_fail_self_test("Debuffs should not be manually dismissable by the player")
		return
	if active_auras.size() != 2:
		_fail_self_test("Debuff cancellation attempt incorrectly removed the aura")
		return

	# 5. Cancel Might buff (should succeed)
	var cancelled_buff = _on_try_cancel_aura(active_auras[0], 0)
	if not cancelled_buff:
		_fail_self_test("Buff cancellation failed")
		return
	if active_auras.size() != 1 or active_auras[0]["name"] != "Pain":
		_fail_self_test("Buff cancellation did not correctly remove the buff aura")
		return

	# 6. Simulate duration ticking down (2 seconds)
	_tick_auras(2.0)
	if active_auras.size() != 1 or active_auras[0]["duration"] != 1.0:
		_fail_self_test("Aura duration decrement tick failed")
		return

	# 7. Simulate final duration tick (1 second) -> Auto-expiry
	_tick_auras(1.0)
	if active_auras.size() != 0:
		_fail_self_test("Debuff failed to auto-expire and clear from lists after duration reached 0")
		return

	print("AURAS_SELF_TEST_OK: auras buff click cancellation, debuff click locking constraints, duration counting ticks, and auto-expiry checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("AURAS_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
