extends Control

const DASHBOARD_SCENE := "res://main.tscn"
const TRADE_SLOTS := 7  # 6 item slots + 1 "will not be traded" slot per side
const COLOR_GOLD := Color(0.85, 0.72, 0.45)

# Trade state
var trade_active := false
var my_accepted := false
var their_accepted := false
var my_items := []  # Array of item dicts in my offer slots
var their_items := []  # Array of item dicts in their offer slots
var my_gold := 0
var their_gold := 0
var trade_partner := "TargetPlayer"

# Inventory simulation
var player_inventory := [
	{"name": "Linen Cloth", "stack": 20, "quality": 1},
	{"name": "Copper Bar", "stack": 10, "quality": 1},
	{"name": "Minor Healing Potion", "stack": 5, "quality": 1},
	{"name": "Green Iron Helm", "stack": 1, "quality": 2},
	{"name": "Wool Cloth", "stack": 15, "quality": 1},
]
var player_gold := 5000  # 50 silver

# UI references
var status_label: Label
var my_slots_list: ItemList
var their_slots_list: ItemList
var my_gold_input: SpinBox
var their_gold_label: Label
var my_accept_btn: Button
var cancel_btn: Button
var inv_list: ItemList
var add_btn: Button
var remove_btn: Button
var log_log: TextEdit


func _ready() -> void:
	for i in range(TRADE_SLOTS):
		my_items.append(null)
		their_items.append(null)
	_build_view()
	_update_ui()
	if OS.get_environment("ACORE_TRADE_SELF_TEST") == "1":
		call_deferred("_run_self_test")


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
	main_stack.add_theme_constant_override("separation", 12)
	margin.add_child(main_stack)

	# Header
	var header := HBoxContainer.new()
	main_stack.add_child(header)
	var title := Label.new()
	title.text = "Trade Window"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var hsp := Control.new()
	hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hsp)
	status_label = Label.new()
	status_label.text = "No active trade"
	header.add_child(status_label)

	# Trade panels side-by-side
	var trade_row := HBoxContainer.new()
	trade_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trade_row.add_theme_constant_override("separation", 24)
	main_stack.add_child(trade_row)

	# My offer panel
	var my_card := _build_trade_card("Your Offer")
	trade_row.add_child(my_card)

	var my_content := my_card.get_child(0).get_child(0) as VBoxContainer

	my_slots_list = ItemList.new()
	my_slots_list.custom_minimum_size = Vector2(0, 160)
	my_content.add_child(my_slots_list)

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	my_content.add_child(gold_row)
	var g_lbl := Label.new()
	g_lbl.text = "Gold (copper):"
	g_lbl.modulate = COLOR_GOLD
	gold_row.add_child(g_lbl)
	my_gold_input = SpinBox.new()
	my_gold_input.min_value = 0
	my_gold_input.max_value = 999999
	my_gold_input.value = 0
	my_gold_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_gold_input.value_changed.connect(_on_my_gold_changed)
	gold_row.add_child(my_gold_input)

	# Their offer panel
	var their_card := _build_trade_card(trade_partner + "'s Offer")
	trade_row.add_child(their_card)

	var their_content := their_card.get_child(0).get_child(0) as VBoxContainer

	their_slots_list = ItemList.new()
	their_slots_list.custom_minimum_size = Vector2(0, 160)
	their_content.add_child(their_slots_list)

	var tg_row := HBoxContainer.new()
	tg_row.add_theme_constant_override("separation", 8)
	their_content.add_child(tg_row)
	var tg_lbl := Label.new()
	tg_lbl.text = "Gold offered:"
	tg_lbl.modulate = COLOR_GOLD
	tg_row.add_child(tg_lbl)
	their_gold_label = Label.new()
	their_gold_label.text = "0 copper"
	tg_row.add_child(their_gold_label)

	# Inventory panel (right)
	var inv_card := _build_trade_card("Your Inventory")
	trade_row.add_child(inv_card)

	var inv_content := inv_card.get_child(0).get_child(0) as VBoxContainer

	inv_list = ItemList.new()
	inv_list.custom_minimum_size = Vector2(0, 160)
	inv_content.add_child(inv_list)

	var inv_btns := HBoxContainer.new()
	inv_btns.add_theme_constant_override("separation", 8)
	inv_content.add_child(inv_btns)

	add_btn = Button.new()
	add_btn.text = "Add to Trade"
	add_btn.pressed.connect(_on_add_item)
	inv_btns.add_child(add_btn)

	remove_btn = Button.new()
	remove_btn.text = "Remove from Trade"
	remove_btn.pressed.connect(_on_remove_item)
	inv_btns.add_child(remove_btn)

	# Action buttons
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	main_stack.add_child(action_row)

	var start_btn := Button.new()
	start_btn.text = "Start Trade (Sim)"
	start_btn.pressed.connect(_on_start_trade)
	action_row.add_child(start_btn)

	my_accept_btn = Button.new()
	my_accept_btn.text = "Accept Trade"
	my_accept_btn.pressed.connect(_on_accept_trade)
	my_accept_btn.disabled = true
	action_row.add_child(my_accept_btn)

	var sim_accept_btn := Button.new()
	sim_accept_btn.text = "Sim Partner Accept"
	sim_accept_btn.pressed.connect(_on_sim_partner_accept)
	action_row.add_child(sim_accept_btn)

	cancel_btn = Button.new()
	cancel_btn.text = "Cancel Trade"
	cancel_btn.pressed.connect(_on_cancel_trade)
	cancel_btn.disabled = true
	action_row.add_child(cancel_btn)

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


func _build_trade_card(card_title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_top", 12)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(card_margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card_margin.add_child(stack)

	var lbl := Label.new()
	lbl.text = card_title
	lbl.modulate = COLOR_GOLD
	stack.add_child(lbl)

	return card


func _update_ui() -> void:
	# My slots
	my_slots_list.clear()
	for i in range(TRADE_SLOTS):
		if my_items[i] != null:
			var item = my_items[i]
			my_slots_list.add_item("Slot %d: %s x%d" % [i + 1, str(item["name"]), int(item["stack"])])
		else:
			my_slots_list.add_item("Slot %d: (empty)" % [i + 1])

	# Their slots
	their_slots_list.clear()
	for i in range(TRADE_SLOTS):
		if their_items[i] != null:
			var item = their_items[i]
			their_slots_list.add_item("Slot %d: %s x%d" % [i + 1, str(item["name"]), int(item["stack"])])
		else:
			their_slots_list.add_item("Slot %d: (empty)" % [i + 1])

	their_gold_label.text = "%d copper" % their_gold

	# Inventory
	inv_list.clear()
	for item in player_inventory:
		inv_list.add_item("%s x%d" % [str(item["name"]), int(item["stack"])])

	# Buttons
	my_accept_btn.disabled = not trade_active
	cancel_btn.disabled = not trade_active

	if trade_active:
		status_label.text = "Trading with " + trade_partner
		if my_accepted and their_accepted:
			status_label.text = "Trade complete!"
	else:
		status_label.text = "No active trade"


func _on_start_trade() -> void:
	trade_active = true
	my_accepted = false
	their_accepted = false
	for i in range(TRADE_SLOTS):
		my_items[i] = null
		their_items[i] = null
	my_gold = 0
	their_gold = 0
	my_gold_input.value = 0
	_log("Trade started with " + trade_partner + ".")
	_update_ui()


func _on_add_item() -> void:
	if not trade_active:
		_log("No trade active.")
		return
	var sel = inv_list.get_selected_items()
	if sel.is_empty():
		_log("Select an inventory item first.")
		return
	var inv_idx = sel[0]
	# Find first empty trade slot
	var slot = -1
	for i in range(TRADE_SLOTS):
		if my_items[i] == null:
			slot = i
			break
	if slot == -1:
		_log("All trade slots are full.")
		return

	my_items[slot] = player_inventory[inv_idx].duplicate()
	player_inventory.remove_at(inv_idx)
	my_accepted = false  # Reset acceptance when items change
	their_accepted = false
	_log("Added " + str(my_items[slot]["name"]) + " to trade slot " + str(slot + 1) + ".")
	_update_ui()


func _on_remove_item() -> void:
	if not trade_active:
		_log("No trade active.")
		return
	var sel = my_slots_list.get_selected_items()
	if sel.is_empty():
		_log("Select a trade slot to remove.")
		return
	var slot_idx = sel[0]
	if my_items[slot_idx] == null:
		_log("Slot is already empty.")
		return

	var item = my_items[slot_idx]
	player_inventory.append(item)
	my_items[slot_idx] = null
	my_accepted = false
	their_accepted = false
	_log("Removed " + str(item["name"]) + " from trade slot " + str(slot_idx + 1) + ".")
	_update_ui()


func _on_my_gold_changed(value: float) -> void:
	my_gold = int(value)
	my_accepted = false
	their_accepted = false


func _on_accept_trade() -> void:
	if not trade_active:
		return
	if my_gold > player_gold:
		_log("Error: You don't have enough gold.")
		return
	my_accepted = true
	_log("You accepted the trade.")
	_check_trade_completion()
	_update_ui()


func _on_sim_partner_accept() -> void:
	if not trade_active:
		_log("No trade active.")
		return
	their_accepted = true
	_log(trade_partner + " accepted the trade.")
	_check_trade_completion()
	_update_ui()


func _check_trade_completion() -> void:
	if my_accepted and their_accepted:
		# Execute trade
		player_gold -= my_gold
		player_gold += their_gold
		for i in range(TRADE_SLOTS):
			if their_items[i] != null:
				player_inventory.append(their_items[i])
		_log("Trade completed! Gold: %d copper. Inventory items: %d." % [player_gold, player_inventory.size()])
		trade_active = false
		my_accepted = false
		their_accepted = false
		_update_ui()


func _on_cancel_trade() -> void:
	if not trade_active:
		return
	# Return items to inventory
	for i in range(TRADE_SLOTS):
		if my_items[i] != null:
			player_inventory.append(my_items[i])
			my_items[i] = null
	trade_active = false
	my_accepted = false
	their_accepted = false
	_log("Trade cancelled. Items returned to inventory.")
	_update_ui()


func _log(msg: String) -> void:
	print("[Trade] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Self-test
func _run_self_test() -> void:
	print("TRADE_SELF_TEST: starting verification...")

	# 1. Start trade
	_on_start_trade()
	if not trade_active:
		_fail("Trade should be active")
		return

	# 2. Add item to trade (simulate selection)
	inv_list.select(0)
	var initial_inv_size = player_inventory.size()
	_on_add_item()
	if player_inventory.size() != initial_inv_size - 1:
		_fail("Inventory should shrink by 1 after adding item to trade")
		return
	if my_items[0] == null:
		_fail("Trade slot 0 should have item")
		return

	# 3. Set gold
	my_gold_input.value = 100
	my_gold = 100

	# 4. Simulate partner offer
	their_items[0] = {"name": "Rugged Leather", "stack": 8, "quality": 1}
	their_gold = 200
	_update_ui()

	# 5. Both accept
	_on_accept_trade()
	if not my_accepted:
		_fail("Should be accepted after clicking accept")
		return

	_on_sim_partner_accept()
	# Trade should complete
	if trade_active:
		_fail("Trade should be inactive after both accept")
		return

	# 6. Verify gold and inventory
	if player_gold != 5000 - 100 + 200:
		_fail("Gold should be 5100 after trade, got " + str(player_gold))
		return

	# Check we received their item
	var found_leather := false
	for item in player_inventory:
		if str(item["name"]) == "Rugged Leather":
			found_leather = true
			break
	if not found_leather:
		_fail("Should have received Rugged Leather from trade partner")
		return

	# 7. Start new trade and cancel
	_on_start_trade()
	inv_list.select(0)
	_on_add_item()
	var pre_cancel_size = player_inventory.size()
	_on_cancel_trade()
	if trade_active:
		_fail("Trade should be inactive after cancel")
		return
	if player_inventory.size() != pre_cancel_size + 1:
		_fail("Items should return to inventory after cancel")
		return

	print("TRADE_SELF_TEST_OK: trade start, item add/remove, gold exchange, dual acceptance completion, inventory transfer, and cancel-with-return all verified.")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("TRADE_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
