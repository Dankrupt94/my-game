extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Player state
var player_gold := 500000 # 50 gold in copper (1 gold = 100 silver = 10000 copper)
var player_inventory := ["Linen Cloth", "Malachite"]

# Mailbox states
var inbox_mail := []
var selected_mail_index := -1
var selected_item_attachment_index := -1

# UI references
var tab_container: TabContainer
var mail_list_container: VBoxContainer
var detail_subject: Label
var detail_sender: Label
var detail_body: TextEdit
var detail_money_btn: Button
var detail_items_btn: Button
var detail_delete_btn: Button

var send_to_input: LineEdit
var send_subject_input: LineEdit
var send_body_input: TextEdit
var send_gold_input: SpinBox
var send_item_option: OptionButton
var postage_label: Label

var status_label: Label
var log_log: TextEdit


func _ready() -> void:
	_load_mock_data()
	_build_view()
	_update_inbox_list()
	_select_mail(0)
	
	if OS.get_environment("ACORE_MAIL_SELF_TEST") == "1":
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
	title.text = "Mailbox System"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Inbox active"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(0, 360)
	main_stack.add_child(tab_container)

	_build_inbox_tab()
	_build_send_mail_tab()

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


func _build_inbox_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Inbox"
	tab_container.add_child(tab)

	var h_split := HSplitContainer.new()
	tab.add_child(h_split)

	# Left panel: Scrollable list of letters
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_split.add_child(scroll)

	mail_list_container = VBoxContainer.new()
	mail_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(mail_list_container)

	# Right panel: Mail details viewer
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 16)
	detail_margin.add_theme_constant_override("margin_top", 16)
	detail_margin.add_theme_constant_override("margin_right", 16)
	detail_margin.add_theme_constant_override("margin_bottom", 16)
	h_split.add_child(detail_margin)

	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail_stack)

	detail_subject = Label.new()
	detail_subject.text = "Subject: (No Mail Selected)"
	detail_subject.add_theme_font_size_override("font_size", 20)
	detail_stack.add_child(detail_subject)

	detail_sender = Label.new()
	detail_sender.text = "From: System"
	detail_sender.modulate = Color(0.85, 0.72, 0.45)
	detail_stack.add_child(detail_sender)

	detail_body = TextEdit.new()
	detail_body.editable = false
	detail_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(detail_body)

	# Attachments Row
	var attachments_row := HBoxContainer.new()
	attachments_row.add_theme_constant_override("separation", 12)
	detail_stack.add_child(attachments_row)

	detail_money_btn = Button.new()
	detail_money_btn.text = "Collect Money (0g)"
	detail_money_btn.pressed.connect(_on_collect_money_pressed)
	attachments_row.add_child(detail_money_btn)

	detail_items_btn = Button.new()
	detail_items_btn.text = "Collect Items"
	detail_items_btn.pressed.connect(_on_collect_items_pressed)
	attachments_row.add_child(detail_items_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attachments_row.add_child(spacer)

	detail_delete_btn = Button.new()
	detail_delete_btn.text = "Delete Mail"
	detail_delete_btn.pressed.connect(_on_delete_pressed)
	attachments_row.add_child(detail_delete_btn)


func _build_send_mail_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Send Mail"
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

	# To
	var to_lbl := Label.new()
	to_lbl.text = "Send To:"
	grid.add_child(to_lbl)

	send_to_input = LineEdit.new()
	send_to_input.placeholder_text = "Character name..."
	send_to_input.custom_minimum_size = Vector2(240, 32)
	grid.add_child(send_to_input)

	# Subject
	var sub_lbl := Label.new()
	sub_lbl.text = "Subject:"
	grid.add_child(sub_lbl)

	send_subject_input = LineEdit.new()
	send_subject_input.placeholder_text = "Enter subject..."
	grid.add_child(send_subject_input)

	# Body
	var body_lbl := Label.new()
	body_lbl.text = "Message:"
	grid.add_child(body_lbl)

	send_body_input = TextEdit.new()
	send_body_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	send_body_input.custom_minimum_size = Vector2(0, 100)
	send_body_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(send_body_input)

	# Attached Money
	var gold_lbl := Label.new()
	gold_lbl.text = "Attach Gold (c):"
	grid.add_child(gold_lbl)

	send_gold_input = SpinBox.new()
	send_gold_input.min_value = 0
	send_gold_input.max_value = 1000000
	send_gold_input.step = 100 # silver ticks
	grid.add_child(send_gold_input)

	# Attached Item Dropdown
	var item_lbl := Label.new()
	item_lbl.text = "Attach Item:"
	grid.add_child(item_lbl)

	send_item_option = OptionButton.new()
	grid.add_child(send_item_option)

	# Postage Fee Info row
	postage_label = Label.new()
	postage_label.text = "Postage Cost: 30 Copper"
	postage_label.modulate = Color(0.85, 0.72, 0.45)
	grid.add_child(postage_label)

	var send_btn := Button.new()
	send_btn.text = "Send Mail"
	send_btn.custom_minimum_size = Vector2(140, 32)
	send_btn.pressed.connect(_on_send_pressed)
	grid.add_child(send_btn)


func _load_mock_data() -> void:
	inbox_mail = [
		{
			"sender": "Innkeeper Farley",
			"subject": "Welcome to Goldshire",
			"body": "Welcome traveler! Enclosed is your starting Goldshire Canteen and some pocket money to help buy training.",
			"gold": 5000, # 50 silver
			"items": ["Goldshire Canteen"],
			"days_left": 29
		},
		{
			"sender": "Auction House",
			"subject": "Auction Won: Bronze Tube",
			"body": "Congratulations, you won the bidding auction for Bronze Tube. Enclosed is your purchased component.",
			"gold": 0,
			"items": ["Bronze Tube"],
			"days_left": 28
		},
		{
			"sender": "Grand Mages Guild",
			"subject": "Spell Reagents",
			"body": "Enclosed are the spell components you ordered. Good luck in your experiments.",
			"gold": 0,
			"items": ["Rune of Teleportation", "Light Feather"],
			"days_left": 25
		}
	]


func _update_inbox_list() -> void:
	for child in mail_list_container.get_children():
		child.queue_free()

	for idx in range(inbox_mail.size()):
		var mail = inbox_mail[idx]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(_select_mail.bind(idx))
		
		var text := "%s\n[Sub: %s]" % [mail["sender"], mail["subject"]]
		if mail["gold"] > 0 or mail["items"].size() > 0:
			text += " (Gift)"
		btn.text = text
		mail_list_container.add_child(btn)


func _select_mail(idx: int) -> void:
	if idx < 0 or idx >= inbox_mail.size():
		selected_mail_index = -1
		detail_subject.text = "Subject: (No Mail Selected)"
		detail_sender.text = "From: System"
		detail_body.text = ""
		detail_money_btn.text = "Collect Money (0g)"
		detail_money_btn.disabled = true
		detail_items_btn.text = "Collect Items (0)"
		detail_items_btn.disabled = true
		detail_delete_btn.disabled = true
		return

	selected_mail_index = idx
	var mail = inbox_mail[idx]
	detail_subject.text = "Subject: " + mail["subject"]
	detail_sender.text = "From: " + mail["sender"] + " (" + str(mail["days_left"]) + " days remaining)"
	detail_body.text = mail["body"]

	# Gold attachment Button text
	var gold_val: int = mail["gold"]
	if gold_val > 0:
		var gold_part = gold_val / 10000
		var silver_part = (gold_val % 10000) / 100
		detail_money_btn.text = "Collect Money (%dg %ds)" % [gold_part, silver_part]
		detail_money_btn.disabled = false
	else:
		detail_money_btn.text = "Collect Money (0g)"
		detail_money_btn.disabled = true

	# Items attachment Button text
	var items: Array = mail["items"]
	if items.size() > 0:
		detail_items_btn.text = "Collect Items (" + str(items.size()) + ")"
		detail_items_btn.disabled = false
	else:
		detail_items_btn.text = "Collect Items (0)"
		detail_items_btn.disabled = true
		
	detail_delete_btn.disabled = false
	
	_update_inventory_options()


func _update_inventory_options() -> void:
	if send_item_option == null:
		return
	send_item_option.clear()
	send_item_option.add_item("(None)")
	for item in player_inventory:
		send_item_option.add_item(item)


func _on_collect_money_pressed() -> void:
	if selected_mail_index < 0:
		return
	var mail = inbox_mail[selected_mail_index]
	var amount: int = mail["gold"]
	if amount > 0:
		player_gold += amount
		mail["gold"] = 0
		_log("Collected gold from mail: %d copper added to bag." % amount)
		_select_mail(selected_mail_index)


func _on_collect_items_pressed() -> void:
	if selected_mail_index < 0:
		return
	var mail = inbox_mail[selected_mail_index]
	var items: Array = mail["items"]
	if items.size() > 0:
		for item in items:
			player_inventory.append(item)
			_log("Collected item from mail: " + item)
		mail["items"] = []
		_select_mail(selected_mail_index)


func _on_delete_pressed() -> void:
	if selected_mail_index < 0:
		return
	inbox_mail.remove_at(selected_mail_index)
	_log("Deleted mail letter.")
	_update_inbox_list()
	if inbox_mail.size() > 0:
		_select_mail(0)
	else:
		_select_mail(-1)


func _on_send_pressed() -> void:
	var recipient := send_to_input.text.strip_edges()
	var subject := send_subject_input.text.strip_edges()
	var body := send_body_input.text.strip_edges()
	var attached_gold := int(send_gold_input.value)
	var attached_item_idx := send_item_option.selected

	if recipient.is_empty():
		_log("Error: Recipient name cannot be empty.")
		return
	if subject.is_empty():
		subject = "No Subject"

	# Calculate postage
	var postage := 30 # base postage fee in copper
	var has_item := attached_item_idx > 0 # index 0 is None
	if has_item:
		postage += 30 # postage increase for items

	var total_cost := attached_gold + postage
	if player_gold < total_cost:
		_log("Error: Insufficient funds. Total cost required: %d copper (You have: %d)." % [total_cost, player_gold])
		return

	# Deduct cost
	player_gold -= total_cost
	_log("Mail sent successfully to: " + recipient)
	_log("Deducted %d copper (Gold: %d, Postage: %d)." % [total_cost, attached_gold, postage])

	# Remove item from inventory if attached
	if has_item:
		var item_name := send_item_option.get_item_text(attached_item_idx)
		player_inventory.erase(item_name)
		_log("Sent attached item: " + item_name)

	# Reset compose fields
	send_to_input.text = ""
	send_subject_input.text = ""
	send_body_input.text = ""
	send_gold_input.value = 0
	_update_inventory_options()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[Mailbox] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("MAIL_SELF_TEST: starting verification...")

	# 1. Verify inbox list loading
	if inbox_mail.size() != 3:
		_fail_self_test("Simulated inbox letters count mismatch")
		return

	# 2. Select Farley's letter and verify contents
	var farley_mail = inbox_mail[0]
	if farley_mail["sender"] != "Innkeeper Farley" or farley_mail["gold"] != 5000:
		_fail_self_test("Inbox Farley's letter contents mismatch")
		return

	# 3. Test Collect Gold
	var starting_gold := player_gold
	_on_collect_money_pressed()
	if player_gold != starting_gold + 5000:
		_fail_self_test("Collect gold arithmetic failed")
		return
	if farley_mail["gold"] != 0:
		_fail_self_test("Mail gold was not zeroed out after collection")
		return

	# 4. Test Collect Items
	var starting_inv_count := player_inventory.size()
	_on_collect_items_pressed()
	if player_inventory.size() != starting_inv_count + 1:
		_fail_self_test("Collect items count mismatch")
		return
	if not player_inventory.has("Goldshire Canteen"):
		_fail_self_test("Collected item Goldshire Canteen was not found in inventory")
		return
	if farley_mail["items"].size() != 0:
		_fail_self_test("Mail item list was not cleared after collection")
		return

	# 5. Test Compose Mail & Postage validation
	send_to_input.text = "TargetPlayer"
	send_subject_input.text = "Self-Test Attached Item"
	send_gold_input.value = 1000 # attach 10 silver
	_update_inventory_options()
	
	# Select "Malachite" to attach (which should be at index 2, since index 0 is None, index 1 is Linen Cloth)
	var malachite_idx := -1
	for idx in range(send_item_option.item_count):
		if send_item_option.get_item_text(idx) == "Malachite":
			malachite_idx = idx
			break
	if malachite_idx == -1:
		_fail_self_test("Malachite was not found in compose item options")
		return
	send_item_option.selected = malachite_idx

	# Total Cost: 1000 (attached gold) + 60 (postage: 30 base + 30 item) = 1060 copper
	var gold_before_send := player_gold
	_on_send_pressed()
	
	if player_gold != gold_before_send - 1060:
		_fail_self_test("Postage and attached gold deduction calculation failed")
		return
	if player_inventory.has("Malachite"):
		_fail_self_test("Attached item Malachite was not removed from inventory list after sending")
		return

	print("MAIL_SELF_TEST_OK: inbox parsing, attachment collection math, and compose postage validation checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("MAIL_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
