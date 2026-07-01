extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Guild State
var guild_name := "Elite Defenders"
var player_rank := "Officer" # Ranks: "Guild Master", "Officer", "Veteran", "Member"
var guild_motd := "Raid tonight at 8 PM. Bring flasks!"
var roster := []
var selected_member_idx := -1

# UI elements
var motd_label: Label
var motd_edit: LineEdit
var edit_motd_btn: Button
var roster_container: VBoxContainer
var promote_btn: Button
var demote_btn: Button
var kick_btn: Button
var invite_input: LineEdit
var status_label: Label
var log_log: TextEdit

# Custom formatting constants
const COLOR_ONLINE := Color(0.15, 0.8, 0.15)
const COLOR_OFFLINE := Color(0.5, 0.5, 0.5)
const COLOR_BORDER := Color(0.85, 0.72, 0.45) # Gold


func _ready() -> void:
	_load_mock_data()
	_build_view()
	_update_roster_grid()
	_select_member(-1)
	
	if OS.get_environment("ACORE_GUILD_SELF_TEST") == "1":
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
	title.text = guild_name
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Roster online"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# MOTD Card Panel
	var motd_card := PanelContainer.new()
	main_stack.add_child(motd_card)

	var motd_margin := MarginContainer.new()
	motd_margin.add_theme_constant_override("margin_left", 14)
	motd_margin.add_theme_constant_override("margin_top", 10)
	motd_margin.add_theme_constant_override("margin_right", 14)
	motd_margin.add_theme_constant_override("margin_bottom", 10)
	motd_card.add_child(motd_margin)

	var motd_row := HBoxContainer.new()
	motd_row.add_theme_constant_override("separation", 12)
	motd_margin.add_child(motd_row)

	var motd_lbl_tag := Label.new()
	motd_lbl_tag.text = "MOTD:"
	motd_lbl_tag.modulate = COLOR_BORDER
	motd_row.add_child(motd_lbl_tag)

	motd_label = Label.new()
	motd_label.text = guild_motd
	motd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motd_row.add_child(motd_label)

	motd_edit = LineEdit.new()
	motd_edit.visible = false
	motd_edit.text = guild_motd
	motd_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motd_edit.text_submitted.connect(_on_motd_submitted)
	motd_row.add_child(motd_edit)

	edit_motd_btn = Button.new()
	edit_motd_btn.text = "Edit MOTD"
	edit_motd_btn.pressed.connect(_on_edit_motd_pressed)
	edit_motd_btn.disabled = not _can_edit_motd()
	motd_row.add_child(edit_motd_btn)

	# Roster Scroll Panel
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.custom_minimum_size = Vector2(0, 240)
	main_stack.add_child(roster_scroll)

	roster_container = VBoxContainer.new()
	roster_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(roster_container)

	# Selected Member Controls
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	main_stack.add_child(controls_row)

	promote_btn = Button.new()
	promote_btn.text = "Promote"
	promote_btn.custom_minimum_size = Vector2(100, 32)
	promote_btn.pressed.connect(_on_promote_pressed)
	controls_row.add_child(promote_btn)

	demote_btn = Button.new()
	demote_btn.text = "Demote"
	demote_btn.custom_minimum_size = Vector2(100, 32)
	demote_btn.pressed.connect(_on_demote_pressed)
	controls_row.add_child(demote_btn)

	kick_btn = Button.new()
	kick_btn.text = "Kick Member"
	kick_btn.custom_minimum_size = Vector2(120, 32)
	kick_btn.pressed.connect(_on_kick_pressed)
	controls_row.add_child(kick_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(spacer)

	# Invite
	var invite_lbl := Label.new()
	invite_lbl.text = "Invite Player:"
	controls_row.add_child(invite_lbl)

	invite_input = LineEdit.new()
	invite_input.placeholder_text = "Enter name..."
	invite_input.custom_minimum_size = Vector2(140, 32)
	controls_row.add_child(invite_input)

	var invite_btn := Button.new()
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


func _load_mock_data() -> void:
	roster = [
		{
			"name": "Codexstage",
			"class": "Warrior",
			"level": 80,
			"rank": "Guild Master",
			"online": true,
			"note": "Main Tank"
		},
		{
			"name": "Doodbro",
			"class": "Paladin",
			"level": 80,
			"rank": "Officer",
			"online": true,
			"note": "Officer healer"
		},
		{
			"name": "Mageguy",
			"class": "Mage",
			"level": 78,
			"rank": "Veteran",
			"online": false,
			"note": "DPS"
		},
		{
			"name": "Noobling",
			"class": "Rogue",
			"level": 14,
			"rank": "Member",
			"online": true,
			"note": "Alt"
		}
	]


func _update_roster_grid() -> void:
	for child in roster_container.get_children():
		child.queue_free()

	# Draw columns headers
	var header_panel := PanelContainer.new()
	var h_box := HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 10)
	header_panel.add_child(h_box)
	roster_container.add_child(header_panel)

	_add_header_label(h_box, "Name", 120)
	_add_header_label(h_box, "Rank", 120)
	_add_header_label(h_box, "Class", 100)
	_add_header_label(h_box, "Level", 60)
	_add_header_label(h_box, "Status", 80)
	_add_header_label(h_box, "Note", 180)

	# Populate rows
	for idx in range(roster.size()):
		var member = roster[idx]
		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(0, 36)
		row_btn.pressed.connect(_select_member.bind(idx))
		
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 10)
		row_btn.add_child(row_box)
		
		_add_cell_label(row_box, member["name"], 120)
		_add_cell_label(row_box, member["rank"], 120)
		_add_cell_label(row_box, member["class"], 100)
		_add_cell_label(row_box, str(member["level"]), 60)
		
		var status_cell := _add_cell_label(row_box, "Online" if member["online"] else "Offline", 80)
		status_cell.modulate = COLOR_ONLINE if member["online"] else COLOR_OFFLINE
		
		_add_cell_label(row_box, member["note"], 180)
		
		roster_container.add_child(row_btn)


func _add_header_label(parent: Control, text: String, width: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(width, 0)
	lbl.modulate = COLOR_BORDER
	parent.add_child(lbl)


func _add_cell_label(parent: Control, text: String, width: float) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(width, 0)
	parent.add_child(lbl)
	return lbl


func _select_member(idx: int) -> void:
	selected_member_idx = idx
	
	if idx < 0 or idx >= roster.size():
		promote_btn.disabled = true
		demote_btn.disabled = true
		kick_btn.disabled = true
		return

	var member = roster[idx]
	var can_manage = _can_manage_member(member)
	
	promote_btn.disabled = not (can_manage and member["rank"] != "Guild Master")
	demote_btn.disabled = not (can_manage and member["rank"] != "Member")
	kick_btn.disabled = not can_manage


func _can_edit_motd() -> bool:
	return player_rank == "Guild Master" or player_rank == "Officer"


func _can_manage_member(target_member: Dictionary) -> bool:
	# GM can manage everyone except themselves
	if player_rank == "Guild Master":
		return target_member["name"] != "Doodbro" # Player character name in this scenario is Doodbro (Officer)
	
	# Officers can manage Veterans and Members, but not other Officers or GMs
	if player_rank == "Officer":
		return target_member["rank"] == "Veteran" or target_member["rank"] == "Member"
		
	return false


func _on_edit_motd_pressed() -> void:
	if motd_label.visible:
		motd_label.visible = false
		motd_edit.visible = true
		motd_edit.grab_focus()
		edit_motd_btn.text = "Save"
	else:
		_save_motd(motd_edit.text)


func _on_motd_submitted(new_text: String) -> void:
	_save_motd(new_text)


func _save_motd(new_text: String) -> void:
	guild_motd = new_text.strip_edges()
	motd_label.text = guild_motd
	motd_label.visible = true
	motd_edit.visible = false
	edit_motd_btn.text = "Edit MOTD"
	_log("Guild MOTD updated: " + guild_motd)


func _on_promote_pressed() -> void:
	if selected_member_idx < 0:
		return
	var member = roster[selected_member_idx]
	var current_rank = member["rank"]
	var next_rank = ""
	
	if current_rank == "Member":
		next_rank = "Veteran"
	elif current_rank == "Veteran":
		next_rank = "Officer"
	elif current_rank == "Officer":
		next_rank = "Guild Master" # Theoretical transition
		
	if not next_rank.is_empty():
		member["rank"] = next_rank
		_log("Promoted member " + member["name"] + " to: " + next_rank)
		_update_roster_grid()
		_select_member(selected_member_idx)


func _on_demote_pressed() -> void:
	if selected_member_idx < 0:
		return
	var member = roster[selected_member_idx]
	var current_rank = member["rank"]
	var prev_rank = ""
	
	if current_rank == "Officer":
		prev_rank = "Veteran"
	elif current_rank == "Veteran":
		prev_rank = "Member"
		
	if not prev_rank.is_empty():
		member["rank"] = prev_rank
		_log("Demoted member " + member["name"] + " to: " + prev_rank)
		_update_roster_grid()
		_select_member(selected_member_idx)


func _on_kick_pressed() -> void:
	if selected_member_idx < 0:
		return
	var member = roster[selected_member_idx]
	roster.remove_at(selected_member_idx)
	_log("Kicked member " + member["name"] + " from the guild.")
	_update_roster_grid()
	_select_member(-1)


func _on_invite_pressed() -> void:
	var invite_name := invite_input.text.strip_edges()
	if invite_name.is_empty():
		_log("Error: Invite name cannot be empty.")
		return

	# Add to roster
	roster.append({
		"name": invite_name,
		"class": "Mage",
		"level": 1,
		"rank": "Member",
		"online": true,
		"note": ""
	})
	_log("Sent guild invitation to: " + invite_name)
	invite_input.text = ""
	_update_roster_grid()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("GUILD_SELF_TEST: starting verification...")

	# 1. Verify roster size is 4
	if roster.size() != 4:
		_fail_self_test("Simulated roster size mismatch")
		return

	# 2. Select Member 3 ("Noobling") at index 3 and verify rank is Member
	var noob = roster[3]
	if noob["name"] != "Noobling" or noob["rank"] != "Member":
		_fail_self_test("Target Noobling details mismatch")
		return

	# 3. Test Promotion (Member -> Veteran)
	selected_member_idx = 3
	_on_promote_pressed()
	if noob["rank"] != "Veteran":
		_fail_self_test("Member promotion to Veteran failed")
		return

	# 4. Test Demotion (Veteran -> Member)
	_on_demote_pressed()
	if noob["rank"] != "Member":
		_fail_self_test("Member demotion back to Member failed")
		return

	# 5. Test Kick Member
	_on_kick_pressed()
	if roster.size() != 3:
		_fail_self_test("Kicking member from roster failed")
		return
	for r in roster:
		if r["name"] == "Noobling":
			_fail_self_test("Kicked member Noobling was still found in roster list")
			return

	# 6. Test Invite Player
	invite_input.text = "Altcharacter"
	_on_invite_pressed()
	if roster.size() != 4:
		_fail_self_test("Invite member did not increase roster count")
		return
	if roster[3]["name"] != "Altcharacter" or roster[3]["rank"] != "Member":
		_fail_self_test("Invited member details were not correctly stored")
		return

	# 7. Test MOTD Editing
	_save_motd("New Raid times scheduled.")
	if guild_motd != "New Raid times scheduled.":
		_fail_self_test("MOTD text was not successfully mutated")
		return

	print("GUILD_SELF_TEST_OK: roster indexing, member promotion/demotion, kick/invite options, and MOTD edit checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("GUILD_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)


func _log(msg: String) -> void:
	print("[Guild] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999

