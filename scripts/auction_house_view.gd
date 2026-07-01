extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Player state
var player_gold := 350000 # 35 gold in copper
var player_inventory := ["Linen Cloth", "Wool Cloth", "Light Leather"]

# Auction state
var listings := []
var my_bids := []
var my_auctions := []
var selected_listing_idx := -1
var selected_sell_item_idx := -1

# UI references
var tab_container: TabContainer
var browse_list_container: VBoxContainer
var bids_list_container: VBoxContainer
var sell_list_container: ItemList
var detail_panel: VBoxContainer
var bid_btn: Button
var buyout_btn: Button

var start_bid_input: SpinBox
var buyout_input: SpinBox
var duration_option: OptionButton
var deposit_label: Label
var create_btn: Button

var gold_label: Label
var status_label: Label
var log_log: TextEdit

# Custom formatting constants
const COLOR_BORDER := Color(0.85, 0.72, 0.45) # Gold
const COLOR_UNCOMMON := Color(0.12, 0.64, 0.95) # Blue


func _ready() -> void:
	_load_mock_data()
	_build_view()
	_update_browse_list()
	_update_bids_list()
	_update_sell_list()
	_select_listing(-1)
	_update_gold_label()

	if OS.get_environment("ACORE_AUCTION_HOUSE_SELF_TEST") == "1":
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
	title.text = "Auction House"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	gold_label = Label.new()
	gold_label.text = "0g 0s 0c"
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.modulate = COLOR_BORDER
	header.add_child(gold_label)

	status_label = Label.new()
	status_label.text = "Auction listings active"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(0, 360)
	main_stack.add_child(tab_container)

	_build_browse_tab()
	_build_bids_tab()
	_build_sell_tab()

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


func _build_browse_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Browse"
	tab_container.add_child(tab)

	var h_split := HSplitContainer.new()
	tab.add_child(h_split)

	# Left sidebar categories
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(160, 0)
	h_split.add_child(sidebar)

	var categories_lbl := Label.new()
	categories_lbl.text = "Categories"
	categories_lbl.modulate = COLOR_BORDER
	sidebar.add_child(categories_lbl)

	var categories := ItemList.new()
	categories.add_item("All")
	categories.add_item("Weapons")
	categories.add_item("Armor")
	categories.add_item("Consumables")
	categories.add_item("Trade Goods")
	categories.item_selected.connect(_on_category_selected)
	sidebar.add_child(categories)

	# Right panel: Listings list and actions
	var main_area := VBoxContainer.new()
	h_split.add_child(main_area)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(600, 0)
	main_area.add_child(scroll)

	browse_list_container = VBoxContainer.new()
	browse_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(browse_list_container)

	# Action buttons row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	main_area.add_child(action_row)

	bid_btn = Button.new()
	bid_btn.text = "Place Bid"
	bid_btn.custom_minimum_size = Vector2(120, 32)
	bid_btn.pressed.connect(_on_bid_pressed)
	action_row.add_child(bid_btn)

	buyout_btn = Button.new()
	buyout_btn.text = "Buyout"
	buyout_btn.custom_minimum_size = Vector2(120, 32)
	buyout_btn.pressed.connect(_on_buyout_pressed)
	action_row.add_child(buyout_btn)


func _build_bids_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "My Bids"
	tab_container.add_child(tab)

	var scroll := ScrollContainer.new()
	tab.add_child(scroll)

	bids_list_container = VBoxContainer.new()
	bids_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bids_list_container)


func _build_sell_tab() -> void:
	var tab := PanelContainer.new()
	tab.name = "Auctions"
	tab_container.add_child(tab)

	var h_split := HSplitContainer.new()
	tab.add_child(h_split)

	# Left panel: inventory items
	var inv_stack := VBoxContainer.new()
	inv_stack.custom_minimum_size = Vector2(280, 0)
	h_split.add_child(inv_stack)

	var inv_lbl := Label.new()
	inv_lbl.text = "Select Item to Sell:"
	inv_lbl.modulate = COLOR_BORDER
	inv_stack.add_child(inv_lbl)

	sell_list_container = ItemList.new()
	sell_list_container.item_selected.connect(_on_sell_item_selected)
	inv_stack.add_child(sell_list_container)

	# Right panel: inputs
	var form_margin := MarginContainer.new()
	form_margin.add_theme_constant_override("margin_left", 16)
	form_margin.add_theme_constant_override("margin_top", 16)
	form_margin.add_theme_constant_override("margin_right", 16)
	form_margin.add_theme_constant_override("margin_bottom", 16)
	h_split.add_child(form_margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	form_margin.add_child(grid)

	# Bid Input
	var bid_lbl := Label.new()
	bid_lbl.text = "Starting Bid (c):"
	grid.add_child(bid_lbl)

	start_bid_input = SpinBox.new()
	start_bid_input.min_value = 10
	start_bid_input.max_value = 1000000
	start_bid_input.step = 10
	grid.add_child(start_bid_input)

	# Buyout Input
	var bo_lbl := Label.new()
	bo_lbl.text = "Buyout Price (c):"
	grid.add_child(bo_lbl)

	buyout_input = SpinBox.new()
	buyout_input.min_value = 10
	buyout_input.max_value = 1000000
	buyout_input.step = 10
	grid.add_child(buyout_input)

	# Duration Option
	var dur_lbl := Label.new()
	dur_lbl.text = "Duration:"
	grid.add_child(dur_lbl)

	duration_option = OptionButton.new()
	duration_option.add_item("12 Hours")
	duration_option.add_item("24 Hours")
	duration_option.add_item("48 Hours")
	duration_option.item_selected.connect(_on_duration_selected)
	grid.add_child(duration_option)

	# Deposit fee label
	deposit_label = Label.new()
	deposit_label.text = "Required Deposit: 5 Copper"
	deposit_label.modulate = COLOR_BORDER
	grid.add_child(deposit_label)

	create_btn = Button.new()
	create_btn.text = "Create Auction"
	create_btn.custom_minimum_size = Vector2(160, 32)
	create_btn.pressed.connect(_on_create_auction_pressed)
	create_btn.disabled = true
	grid.add_child(create_btn)


func _load_mock_data() -> void:
	listings = [
		{
			"name": "Solid Grinding Stone",
			"category": "Trade Goods",
			"level": 20,
			"seller": "Rockman",
			"time_left": "18h",
			"bid": 2500,
			"buyout": 3000,
			"quality": "Common"
		},
		{
			"name": "Copper Shortsword",
			"category": "Weapons",
			"level": 5,
			"seller": "Blacksmith",
			"time_left": "4h",
			"bid": 400,
			"buyout": 600,
			"quality": "Common"
		},
		{
			"name": "Heavy Linen Cloak",
			"category": "Armor",
			"level": 12,
			"seller": "Tailor",
			"time_left": "1d",
			"bid": 1200,
			"buyout": 1500,
			"quality": "Uncommon"
		},
		{
			"name": "Healing Potion",
			"category": "Consumables",
			"level": 10,
			"seller": "Alchemist",
			"time_left": "12h",
			"bid": 800,
			"buyout": 1000,
			"quality": "Common"
		}
	]


func _update_browse_list() -> void:
	for child in browse_list_container.get_children():
		child.queue_free()

	# Add columns headers
	var header_panel := PanelContainer.new()
	var h_box := HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 10)
	header_panel.add_child(h_box)
	browse_list_container.add_child(header_panel)

	_add_header_label(h_box, "Item Name", 160)
	_add_header_label(h_box, "Lvl", 40)
	_add_header_label(h_box, "Seller", 100)
	_add_header_label(h_box, "Time", 60)
	_add_header_label(h_box, "Current Bid", 100)
	_add_header_label(h_box, "Buyout Price", 100)

	for idx in range(listings.size()):
		var item = listings[idx]
		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(0, 36)
		row_btn.pressed.connect(_select_listing.bind(idx))

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 10)
		row_btn.add_child(row_box)

		var name_lbl := _add_cell_label(row_box, item["name"], 160)
		if item["quality"] == "Uncommon":
			name_lbl.modulate = COLOR_UNCOMMON
		
		_add_cell_label(row_box, str(item["level"]), 40)
		_add_cell_label(row_box, item["seller"], 100)
		_add_cell_label(row_box, item["time_left"], 60)
		
		_add_cell_label(row_box, _copper_to_string(item["bid"]), 100)
		_add_cell_label(row_box, _copper_to_string(item["buyout"]), 100)

		browse_list_container.add_child(row_btn)


func _update_bids_list() -> void:
	for child in bids_list_container.get_children():
		child.queue_free()

	for idx in range(my_bids.size()):
		var bid = my_bids[idx]
		var lbl := Label.new()
		lbl.text = "Bid active on: %s - Current Bid: %s (Status: Active)" % [bid["name"], _copper_to_string(bid["bid"])]
		bids_list_container.add_child(lbl)


func _update_sell_list() -> void:
	sell_list_container.clear()
	for item in player_inventory:
		sell_list_container.add_item(item)


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


func _copper_to_string(val: int) -> String:
	var gold = val / 10000
	var silver = (val % 10000) / 100
	var copper = val % 100
	return "%dg %ds %dc" % [gold, silver, copper]


func _update_gold_label() -> void:
	gold_label.text = _copper_to_string(player_gold)


func _select_listing(idx: int) -> void:
	selected_listing_idx = idx
	if idx < 0 or idx >= listings.size():
		bid_btn.disabled = true
		buyout_btn.disabled = true
		return

	bid_btn.disabled = false
	buyout_btn.disabled = false


func _on_category_selected(idx: int) -> void:
	# Mock filter category
	pass


func _on_sell_item_selected(idx: int) -> void:
	selected_sell_item_idx = idx
	create_btn.disabled = false
	_calculate_deposit()


func _on_duration_selected(idx: int) -> void:
	_calculate_deposit()


func _calculate_deposit() -> void:
	# Duration multiplier: 12h = 5c, 24h = 10c, 48h = 15c
	var dur_idx := duration_option.selected
	var base_deposit := 5
	if dur_idx == 1:
		base_deposit = 10
	elif dur_idx == 2:
		base_deposit = 15
		
	deposit_label.text = "Required Deposit: %d Copper" % base_deposit


func _on_bid_pressed() -> void:
	if selected_listing_idx < 0:
		return
	var item = listings[selected_listing_idx]
	var next_bid := int(item["bid"] * 1.1)
	if player_gold < next_bid:
		_log("Error: Insufficient gold to place bid.")
		return

	player_gold -= next_bid
	item["bid"] = next_bid
	my_bids.append(item)
	_log("Placed bid of %s on item: %s" % [_copper_to_string(next_bid), item["name"]])
	_update_gold_label()
	_update_browse_list()
	_update_bids_list()


func _on_buyout_pressed() -> void:
	if selected_listing_idx < 0:
		return
	var item = listings[selected_listing_idx]
	var cost := int(item["buyout"])
	if player_gold < cost:
		_log("Error: Insufficient gold to buyout item.")
		return

	player_gold -= cost
	listings.remove_at(selected_listing_idx)
	player_inventory.append(item["name"])
	_log("Bought out item: %s for %s" % [item["name"], _copper_to_string(cost)])
	_update_gold_label()
	_update_browse_list()
	_update_sell_list()
	_select_listing(-1)


func _on_create_auction_pressed() -> void:
	if selected_sell_item_idx < 0:
		return
	
	var item_name := str(player_inventory[selected_sell_item_idx])
	var bid_price := int(start_bid_input.value)
	var bo_price := int(buyout_input.value)

	# Calculate deposit
	var dur_idx := duration_option.selected
	var deposit := 5
	if dur_idx == 1:
		deposit = 10
	elif dur_idx == 2:
		deposit = 15

	if player_gold < deposit:
		_log("Error: Insufficient gold to pay listing deposit fee.")
		return

	player_gold -= deposit
	player_inventory.remove_at(selected_sell_item_idx)
	
	var new_auction := {
		"name": item_name,
		"category": "Trade Goods",
		"level": 1,
		"seller": "Doodbro",
		"time_left": "24h" if dur_idx == 1 else ("48h" if dur_idx == 2 else "12h"),
		"bid": bid_price,
		"buyout": bo_price,
		"quality": "Common"
	}
	listings.append(new_auction)
	my_auctions.append(new_auction)

	_log("Listed item for sale: %s (Starting Bid: %d, Buyout: %d)." % [item_name, bid_price, bo_price])
	
	# Clear
	start_bid_input.value = 10
	buyout_input.value = 10
	create_btn.disabled = true
	selected_sell_item_idx = -1

	_update_gold_label()
	_update_browse_list()
	_update_sell_list()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[AuctionHouse] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("AUCTION_HOUSE_SELF_TEST: starting verification...")

	# 1. Verify mock listings size is 4
	if listings.size() != 4:
		_fail_self_test("Simulated listings size mismatch")
		return

	# 2. Select listing 0 (Solid Grinding Stone) and verify buyout is 3000
	var first_item = listings[0]
	if first_item["name"] != "Solid Grinding Stone" or first_item["buyout"] != 3000:
		_fail_self_test("First listing name/buyout mismatch")
		return

	# 3. Test Buyout Solid Grinding Stone
	var gold_before_buyout := player_gold
	selected_listing_idx = 0
	_on_buyout_pressed()
	
	if player_gold != gold_before_buyout - 3000:
		_fail_self_test("Buyout gold deduction failed")
		return
	if not player_inventory.has("Solid Grinding Stone"):
		_fail_self_test("Bought item was not added to player inventory")
		return
	if listings.size() != 3:
		_fail_self_test("Listings count did not decrement after buyout")
		return

	# 4. Place Bid on new first item (Copper Shortsword, bid 400)
	# Bid should increase by 10% (next bid = 440 copper)
	var gold_before_bid := player_gold
	selected_listing_idx = 0
	_on_bid_pressed()
	
	if player_gold != gold_before_bid - 440:
		_fail_self_test("Bid placement gold deduction failed")
		return
	if listings[0]["bid"] != 440:
		_fail_self_test("Listing bid value was not updated after placing bid")
		return
	if my_bids.size() != 1:
		_fail_self_test("Bids list size did not increment")
		return

	# 5. Create Auction (Sell Wool Cloth, start bid 500, buyout 700, duration 24h)
	# Wool Cloth is at index 1 of player_inventory (Linen Cloth, Wool Cloth, Light Leather)
	# Plus Solid Grinding Stone got appended at index 3.
	# So inventory is: ["Linen Cloth", "Wool Cloth", "Light Leather", "Solid Grinding Stone"]
	# Index 1 is Wool Cloth.
	selected_sell_item_idx = 1
	start_bid_input.value = 500
	buyout_input.value = 700
	duration_option.selected = 1 # 24h = 10 copper deposit
	
	var gold_before_list := player_gold
	_on_create_auction_pressed()

	if player_gold != gold_before_list - 10:
		_fail_self_test("Listing deposit deduction failed")
		return
	if player_inventory.has("Wool Cloth"):
		_fail_self_test("Listed item Wool Cloth was not removed from player inventory")
		return
	if my_auctions.size() != 1:
		_fail_self_test("My active auctions count did not increment")
		return
	if listings.size() != 4:
		_fail_self_test("Browse listings did not increment after creation")
		return

	print("AUCTION_HOUSE_SELF_TEST_OK: listings search indexing, bidding gold deducts, buyout transfers, and sell deposit math checks passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("AUCTION_HOUSE_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
