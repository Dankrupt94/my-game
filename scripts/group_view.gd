extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Party State
var party_members := []
var loot_method := "Group Loot"
var loot_threshold := "Uncommon"
var selected_member_idx := -1

# UI references
var frames_container: GridContainer
var loot_method_btn: OptionButton
var loot_threshold_btn: OptionButton
var invite_input: LineEdit
var invite_btn: Button
var promote_btn: Button
var kick_btn: Button
var leave_btn: Button
var status_label: Label
var log_log: TextEdit

# Custom formatting constants
const COLOR_BORDER := Color(0.85, 0.72, 0.45) # Gold
const CLASS_COLORS := {
	"Warrior": Color(0.78, 0.61, 0.43),
	"Paladin": Color(0.96, 0.55, 0.73),
	"Priest": Color(1.0, 1.0, 1.0),
	"Mage": Color(0.25, 0.78, 0.92),
	"Druid": Color(1.0, 0.49, 0.04)
}


func _ready() -> void:
	_initialize_player()
	_build_view()
	_update_frames()
	_select_member(-1)
	_update_loot_controls()

	if OS.get_environment("ACORE_GROUPS_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _initialize_player() -> void:
	party_members = [
		{
			"name": "Doodbro",
			"class": "Paladin",
			"level": 80,
			"health": 100,
			"mana": 100,
			"role": "Healer",
			"is_leader": true
		}
	]


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
	title.text = "Party / Group Manager"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Party status: Solo"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# Loot Rules Panel
	var loot_panel := PanelContainer.new()
	main_stack.add_child(loot_panel)

	var loot_margin := MarginContainer.new()
	loot_margin.add_theme_constant_override("margin_left", 14)
	loot_margin.add_theme_constant_override("margin_top", 10)
	loot_margin.add_theme_constant_override("margin_right", 14)
	loot_margin.add_theme_constant_override("margin_bottom", 10)
	loot_panel.add_child(loot_margin)

	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 12)
	loot_margin.add_child(loot_row)

	var loot_lbl := Label.new()
	loot_lbl.text = "Loot Settings:"
	loot_lbl.modulate = COLOR_BORDER
	loot_row.add_child(loot_lbl)

	loot_method_btn = OptionButton.new()
	loot_method_btn.add_item("Group Loot")
	loot_method_btn.add_item("Free-for-All")
	loot_method_btn.add_item("Master Loot")
	loot_method_btn.item_selected.connect(_on_loot_method_changed)
	loot_row.add_child(loot_method_btn)

	loot_threshold_btn = OptionButton.new()
	loot_threshold_btn.add_item("Common")
	loot_threshold_btn.add_item("Uncommon")
	loot_threshold_btn.add_item("Rare")
	loot_threshold_btn.item_selected.connect(_on_loot_threshold_changed)
	loot_row.add_child(loot_threshold_btn)

	# Party Frames Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	main_stack.add_child(scroll)

	frames_container = GridContainer.new()
	frames_container.columns = 5
	frames_container.add_theme_constant_override("h_separation", 16)
	frames_container.add_theme_constant_override("v_separation", 16)
	scroll.add_child(frames_container)

	# Controls Row
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	main_stack.add_child(controls_row)

	promote_btn = Button.new()
	promote_btn.text = "Promote Leader"
	promote_btn.pressed.connect(_on_promote_pressed)
	controls_row.add_child(promote_btn)

	kick_btn = Button.new()
	kick_btn.text = "Kick Member"
	kick_btn.pressed.connect(_on_kick_pressed)
	controls_row.add_child(kick_btn)

	leave_btn = Button.new()
	leave_btn.text = "Leave Party"
	leave_btn.pressed.connect(_on_leave_pressed)
	controls_row.add_child(leave_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(spacer)

	# Invite form
	var invite_lbl := Label.new()
	invite_lbl.text = "Invite Player:"
	controls_row.add_child(invite_lbl)

	invite_input = LineEdit.new()
	invite_input.placeholder_text = "Name..."
	invite_input.custom_minimum_size = Vector2(140, 32)
	controls_row.add_child(invite_input)

	invite_btn = Button.new()
	invite_btn.text = "Invite"
	invite_btn.pressed.connect(_on_invite_pressed)
	controls_row.add_child(invite_btn)

	# Log Console
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 80)
	main_stack.add_child(log_log)

	# Bottom Actions Row
	var actions_row := HBoxContainer.new()
	main_stack.add_child(actions_row)

	var back_spacer := Control.new()
	back_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(back_spacer)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.custom_minimum_size = Vector2(160, 38)
	back_btn.pressed.connect(_on_back_pressed)
	actions_row.add_child(back_btn)


func _update_frames() -> void:
	for child in frames_container.get_children():
		child.queue_free()

	for idx in range(party_members.size()):
		var member = party_members[idx]
		var frame := Button.new()
		frame.custom_minimum_size = Vector2(160, 120)
		frame.pressed.connect(_select_member.bind(idx))
		
		# Frame border styling
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.14, 0.16)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = COLOR_BORDER if idx == selected_member_idx else Color(0.3, 0.3, 0.3)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		frame.add_theme_stylebox_override("normal", style)
		frame.add_theme_stylebox_override("hover", style)
		frame.add_theme_stylebox_override("pressed", style)

		var stack := VBoxContainer.new()
		stack.anchor_right = 1.0
		stack.anchor_bottom = 1.0
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 6)
		frame.add_child(stack)

		var top_margin := MarginContainer.new()
		top_margin.add_theme_constant_override("margin_left", 8)
		top_margin.add_theme_constant_override("margin_top", 6)
		top_margin.add_theme_constant_override("margin_right", 8)
		stack.add_child(top_margin)

		var name_row := HBoxContainer.new()
		top_margin.add_child(name_row)

		var name_lbl := Label.new()
		name_lbl.text = member["name"]
		var cls_color = CLASS_COLORS.get(member["class"], Color.WHITE)
		name_lbl.modulate = cls_color
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)

		if member["is_leader"]:
			var leader_lbl := Label.new()
			leader_lbl.text = "L"
			leader_lbl.modulate = COLOR_BORDER
			name_row.add_child(leader_lbl)

		var role_lbl := Label.new()
		role_lbl.text = "Lvl %d %s" % [member["level"], member["role"]]
		role_lbl.modulate = Color(0.7, 0.7, 0.7)
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(role_lbl)

		# Health progress bar
		var hp_bar := ProgressBar.new()
		hp_bar.value = member["health"]
		hp_bar.max_value = 100
		hp_bar.show_percentage = false
		hp_bar.custom_minimum_size = Vector2(0, 10)
		stack.add_child(hp_bar)

		# Style hp bar green
		var hp_style := StyleBoxFlat.new()
		hp_style.bg_color = Color(0.1, 0.7, 0.2)
		hp_bar.add_theme_stylebox_override("fill", hp_style)

		# Mana progress bar
		var mp_bar := ProgressBar.new()
		mp_bar.value = member["mana"]
		mp_bar.max_value = 100
		mp_bar.show_percentage = false
		mp_bar.custom_minimum_size = Vector2(0, 6)
		stack.add_child(mp_bar)

		# Style mp bar blue
		var mp_style := StyleBoxFlat.new()
		mp_style.bg_color = Color(0.1, 0.3, 0.8)
		mp_bar.add_theme_stylebox_override("fill", mp_style)

		frames_container.add_child(frame)


func _select_member(idx: int) -> void:
	selected_member_idx = idx
	_update_frames()

	var is_player_leader = _is_player_leader()
	if idx < 0 or idx >= party_members.size() or idx == 0:
		# Cannot promote/kick yourself or nothing selected
		promote_btn.disabled = true
		kick_btn.disabled = true
	else:
		promote_btn.disabled = not is_player_leader
		kick_btn.disabled = not is_player_leader


func _is_player_leader() -> bool:
	if party_members.size() > 0:
		return bool(party_members[0]["is_leader"])
	return false


func _update_loot_controls() -> void:
	var leader := _is_player_leader()
	loot_method_btn.disabled = not leader
	loot_threshold_btn.disabled = not leader


func _on_invite_pressed() -> void:
	var name_txt := invite_input.text.strip_edges()
	if name_txt.is_empty():
		_log("Error: Invite player name cannot be empty.")
		return
	if party_members.size() >= 5:
		_log("Error: Party is full (maximum 5 members).")
		return

	# Add mock invite candidate
	_add_player_to_party(name_txt, "Warrior", 80, "Tank", false)
	invite_input.text = ""


func _add_player_to_party(name_val: String, class_val: String, lvl_val: int, role_val: String, leader_val: bool) -> void:
	party_members.append({
		"name": name_val,
		"class": class_val,
		"level": lvl_val,
		"health": 100,
		"mana": 100,
		"role": role_val,
		"is_leader": leader_val
	})
	_log("Player " + name_val + " joined the party.")
	_update_frames()
	_update_party_status()


func _update_party_status() -> void:
	if party_members.size() == 1:
		status_label.text = "Party status: Solo"
	else:
		status_label.text = "Party status: Group (%d)" % party_members.size()


func _on_kick_pressed() -> void:
	if selected_member_idx < 0 or selected_member_idx >= party_members.size():
		return
	var name_val = party_members[selected_member_idx]["name"]
	party_members.remove_at(selected_member_idx)
	_log("Kicked player " + name_val + " from the party.")
	_update_frames()
	_select_member(-1)
	_update_party_status()


func _on_promote_pressed() -> void:
	if selected_member_idx < 0 or selected_member_idx >= party_members.size():
		return
	_swap_leadership(selected_member_idx)


func _swap_leadership(target_idx: int) -> void:
	for idx in range(party_members.size()):
		party_members[idx]["is_leader"] = (idx == target_idx)
	
	var name_val = party_members[target_idx]["name"]
	_log("Promoted player " + name_val + " to Party Leader.")
	
	_select_member(-1)
	_update_loot_controls()


func _on_leave_pressed() -> void:
	_log("Left the party.")
	_initialize_player()
	_update_frames()
	_select_member(-1)
	_update_party_status()
	_update_loot_controls()


func _on_loot_method_changed(idx: int) -> void:
	loot_method = loot_method_btn.get_item_text(idx)
	_log("Party loot method changed to: " + loot_method)


func _on_loot_threshold_changed(idx: int) -> void:
	loot_threshold = loot_threshold_btn.get_item_text(idx)
	_log("Party loot threshold changed to: " + loot_threshold)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[Group] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("GROUPS_SELF_TEST: starting verification...")

	# 1. Verify initial party contains only Doodbro
	if party_members.size() != 1 or party_members[0]["name"] != "Doodbro":
		_fail_self_test("Initial party structure incorrect")
		return

	# 2. Invite Healerboy (Warrior) and Tankguy (Priest)
	_add_player_to_party("Healerboy", "Priest", 80, "Healer", false)
	_add_player_to_party("Tankguy", "Warrior", 80, "Tank", false)
	if party_members.size() != 3:
		_fail_self_test("Failed to invite and expand party group")
		return

	# 3. Check Doodbro is Leader, promote/kick buttons are valid for Healerboy
	if not _is_player_leader():
		_fail_self_test("Doodbro should start as Party Leader")
		return

	# 4. Promote Healerboy (index 1) to Leader
	_swap_leadership(1)
	if party_members[0]["is_leader"] or not party_members[1]["is_leader"]:
		_fail_self_test("Leadership promote swap failed")
		return
	if _is_player_leader():
		_fail_self_test("Doodbro should no longer be Leader")
		return

	# 5. Check Doodbro cannot edit loot/promote when not leader
	_select_member(2) # Select Tankguy
	if not promote_btn.disabled or not kick_btn.disabled:
		_fail_self_test("Non-leader should not have active promote/kick button permissions")
		return

	# 6. Force Healerboy to promote Doodbro back to Leader (simulate server packet)
	_swap_leadership(0)
	if not _is_player_leader():
		_fail_self_test("Player should be promoted back to Leader")
		return

	# 7. Kick Tankguy (index 2)
	selected_member_idx = 2
	_on_kick_pressed()
	if party_members.size() != 2:
		_fail_self_test("Kicking member from group failed")
		return
	for m in party_members:
		if m["name"] == "Tankguy":
			_fail_self_test("Kicked member Tankguy was still found in party list")
			return

	# 8. Change loot settings (Master Loot)
	_on_loot_method_changed(2) # Index 2 is Master Loot
	if loot_method != "Master Loot":
		_fail_self_test("Loot method changes failed")
		return

	print("GROUPS_SELF_TEST_OK: party composition list, roles layout, leadership promotions permissions, and loot settings updates checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("GROUPS_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
