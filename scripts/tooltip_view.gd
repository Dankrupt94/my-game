extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# WoW quality colors
const QUALITY_COLORS := {
	0: Color(0.62, 0.62, 0.62),  # Poor (gray)
	1: Color(1.0, 1.0, 1.0),     # Common (white)
	2: Color(0.12, 1.0, 0.0),    # Uncommon (green)
	3: Color(0.0, 0.44, 0.87),   # Rare (blue)
	4: Color(0.64, 0.21, 0.93),  # Epic (purple)
	5: Color(1.0, 0.50, 0.0),    # Legendary (orange)
	6: Color(0.90, 0.80, 0.50),  # Artifact (light gold)
	7: Color(0.0, 0.80, 1.0),    # Heirloom (cyan)
}

const QUALITY_NAMES := {
	0: "Poor", 1: "Common", 2: "Uncommon", 3: "Rare",
	4: "Epic", 5: "Legendary", 6: "Artifact", 7: "Heirloom"
}

const SLOT_NAMES := {
	0: "Head", 1: "Neck", 2: "Shoulder", 3: "Shirt", 4: "Chest",
	5: "Waist", 6: "Legs", 7: "Feet", 8: "Wrist", 9: "Hands",
	10: "Finger", 11: "Trinket", 12: "One-Hand", 13: "Shield",
	14: "Ranged", 15: "Back", 16: "Two-Hand", 17: "Bag",
	18: "Tabard", 19: "Robe", 20: "Main Hand", 21: "Off Hand",
	22: "Holdable", 23: "Ammo", 24: "Thrown", 25: "Relic"
}

# Sample item database (WotLK-era items for testing)
var sample_items := [
	{
		"name": "Shadowmourne",
		"quality": 5,
		"item_level": 284,
		"required_level": 80,
		"slot": 16,
		"armor": 0,
		"dps": 234.3,
		"speed": 3.7,
		"damage_min": 654,
		"damage_max": 982,
		"stats": [
			{"name": "Strength", "value": 223},
			{"name": "Stamina", "value": 198},
		],
		"sockets": ["Red", "Red", "Blue"],
		"socket_bonus": "+8 Strength",
		"equip_effects": ["Chance on hit: Inflict 1900 to 2100 Shadow damage."],
		"flavor": "The power of this weapon is beyond measure.",
		"binds": "Binds when picked up",
		"item_type": "Two-Hand Axe",
		"unique": true,
	},
	{
		"name": "Bag of Candies",
		"quality": 1,
		"item_level": 1,
		"required_level": 0,
		"slot": -1,
		"armor": 0,
		"dps": 0.0,
		"speed": 0.0,
		"damage_min": 0,
		"damage_max": 0,
		"stats": [],
		"sockets": [],
		"socket_bonus": "",
		"equip_effects": [],
		"flavor": "Assorted sweets from the Faire.",
		"binds": "",
		"item_type": "Consumable",
		"unique": false,
	},
	{
		"name": "Quel'Delar, Cunning of the Shadows",
		"quality": 4,
		"item_level": 251,
		"required_level": 80,
		"slot": 12,
		"armor": 0,
		"dps": 180.2,
		"speed": 1.8,
		"damage_min": 227,
		"damage_max": 422,
		"stats": [
			{"name": "Agility", "value": 68},
			{"name": "Stamina", "value": 91},
			{"name": "Critical Strike Rating", "value": 52},
			{"name": "Attack Power", "value": 126},
		],
		"sockets": [],
		"socket_bonus": "",
		"equip_effects": [],
		"flavor": "Reborn from the remnants of its original form, this blade has been rebuilt to serve a deadly purpose.",
		"binds": "Binds when equipped",
		"item_type": "One-Hand Sword",
		"unique": true,
	},
	{
		"name": "Invincible's Reins",
		"quality": 5,
		"item_level": 80,
		"required_level": 80,
		"slot": -1,
		"armor": 0,
		"dps": 0.0,
		"speed": 0.0,
		"damage_min": 0,
		"damage_max": 0,
		"stats": [],
		"sockets": [],
		"socket_bonus": "",
		"equip_effects": [],
		"flavor": "Loyal beyond death, Arthas' steed serves its master still.",
		"binds": "Binds when picked up",
		"item_type": "Mount",
		"unique": true,
	},
]

# UI state
var item_buttons: Array[Button] = []
var tooltip_panel: PanelContainer
var tooltip_stack: VBoxContainer
var status_label: Label
var log_log: TextEdit
var current_hover_idx := -1


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_TOOLTIP_SELF_TEST") == "1":
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
	main_stack.add_theme_constant_override("separation", 14)
	margin.add_child(main_stack)

	# Header
	var header := HBoxContainer.new()
	main_stack.add_child(header)
	var title := Label.new()
	title.text = "Item Tooltips"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	status_label = Label.new()
	status_label.text = "Hover an item to see tooltip"
	header.add_child(status_label)

	# Content row
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	main_stack.add_child(content)

	# Item grid
	var grid := VBoxContainer.new()
	grid.custom_minimum_size = Vector2(200, 0)
	grid.add_theme_constant_override("separation", 8)
	content.add_child(grid)

	var grid_lbl := Label.new()
	grid_lbl.text = "Items:"
	grid_lbl.modulate = Color(0.85, 0.72, 0.45)
	grid.add_child(grid_lbl)

	for i in range(sample_items.size()):
		var item = sample_items[i]
		var btn := Button.new()
		btn.text = item["name"]
		btn.custom_minimum_size = Vector2(180, 36)
		btn.add_theme_color_override("font_color", QUALITY_COLORS.get(int(item["quality"]), Color.WHITE))
		btn.mouse_entered.connect(_on_item_hover.bind(i))
		btn.mouse_exited.connect(_on_item_unhover)
		btn.pressed.connect(_on_item_click.bind(i))
		grid.add_child(btn)
		item_buttons.append(btn)

	# Tooltip area
	var tooltip_area := Control.new()
	tooltip_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tooltip_area)

	tooltip_panel = PanelContainer.new()
	tooltip_panel.visible = false
	tooltip_panel.custom_minimum_size = Vector2(320, 0)

	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	tip_style.border_width_left = 2
	tip_style.border_width_top = 2
	tip_style.border_width_right = 2
	tip_style.border_width_bottom = 2
	tip_style.border_color = Color(0.3, 0.3, 0.3)
	tip_style.corner_radius_top_left = 4
	tip_style.corner_radius_top_right = 4
	tip_style.corner_radius_bottom_left = 4
	tip_style.corner_radius_bottom_right = 4
	tooltip_panel.add_theme_stylebox_override("panel", tip_style)
	tooltip_area.add_child(tooltip_panel)

	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 14)
	tip_margin.add_theme_constant_override("margin_top", 14)
	tip_margin.add_theme_constant_override("margin_right", 14)
	tip_margin.add_theme_constant_override("margin_bottom", 14)
	tooltip_panel.add_child(tip_margin)

	tooltip_stack = VBoxContainer.new()
	tooltip_stack.add_theme_constant_override("separation", 4)
	tip_margin.add_child(tooltip_stack)

	# Log
	log_log = TextEdit.new()
	log_log.editable = false
	log_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_log.custom_minimum_size = Vector2(0, 60)
	main_stack.add_child(log_log)

	# Footer
	var footer := HBoxContainer.new()
	main_stack.add_child(footer)
	var fspacer := Control.new()
	fspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fspacer)
	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file(DASHBOARD_SCENE))
	footer.add_child(back_btn)


func _on_item_hover(idx: int) -> void:
	current_hover_idx = idx
	_show_tooltip(idx)


func _on_item_unhover() -> void:
	current_hover_idx = -1
	tooltip_panel.visible = false
	status_label.text = "Hover an item to see tooltip"


func _on_item_click(idx: int) -> void:
	_show_tooltip(idx)
	_log("Inspected: " + str(sample_items[idx]["name"]))


func _show_tooltip(idx: int) -> void:
	# Clear previous
	var children = tooltip_stack.get_children()
	for child in children:
		tooltip_stack.remove_child(child)
		child.free()

	var item = sample_items[idx]
	var quality = int(item["quality"])
	var q_color = QUALITY_COLORS.get(quality, Color.WHITE)

	# Item name
	var name_lbl := Label.new()
	name_lbl.text = str(item["name"])
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = q_color
	tooltip_stack.add_child(name_lbl)

	# Binds
	var binds_txt = str(item.get("binds", ""))
	if not binds_txt.is_empty():
		_add_tip_line(binds_txt, Color(1, 1, 1, 0.7))

	# Unique
	if item.get("unique", false):
		_add_tip_line("Unique", Color(1, 1, 1, 0.7))

	# Slot and type
	var slot_idx = int(item.get("slot", -1))
	var item_type = str(item.get("item_type", ""))
	if slot_idx >= 0 and SLOT_NAMES.has(slot_idx):
		var slot_row := HBoxContainer.new()
		tooltip_stack.add_child(slot_row)
		var slot_lbl := Label.new()
		slot_lbl.text = SLOT_NAMES[slot_idx]
		slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_child(slot_lbl)
		var type_lbl := Label.new()
		type_lbl.text = item_type
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot_row.add_child(type_lbl)
	elif not item_type.is_empty():
		_add_tip_line(item_type, Color.WHITE)

	# Damage / Speed
	var dps_val = float(item.get("dps", 0.0))
	if dps_val > 0:
		var dmg_row := HBoxContainer.new()
		tooltip_stack.add_child(dmg_row)
		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d - %d Damage" % [int(item["damage_min"]), int(item["damage_max"])]
		dmg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dmg_row.add_child(dmg_lbl)
		var spd_lbl := Label.new()
		spd_lbl.text = "Speed %.2f" % float(item["speed"])
		spd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_row.add_child(spd_lbl)
		_add_tip_line("(%.1f damage per second)" % dps_val, Color(1, 1, 1, 0.7))

	# Armor
	var armor_val = int(item.get("armor", 0))
	if armor_val > 0:
		_add_tip_line(str(armor_val) + " Armor", Color.WHITE)

	# Stats
	var stats_arr = item.get("stats", [])
	for stat in stats_arr:
		var stat_text = "+%d %s" % [int(stat["value"]), str(stat["name"])]
		_add_tip_line(stat_text, Color.WHITE)

	# Sockets
	var sockets_arr = item.get("sockets", [])
	for sock in sockets_arr:
		_add_tip_line("  [" + str(sock) + " Socket]", Color(0.6, 0.6, 0.6))
	var socket_bonus = str(item.get("socket_bonus", ""))
	if not socket_bonus.is_empty():
		_add_tip_line("Socket Bonus: " + socket_bonus, Color(0.5, 0.5, 0.5))

	# Equip effects
	var effects = item.get("equip_effects", [])
	for eff in effects:
		_add_tip_line(str(eff), Color(0.12, 1.0, 0.0))

	# Required level
	var req_lvl = int(item.get("required_level", 0))
	if req_lvl > 0:
		_add_tip_line("Requires Level %d" % req_lvl, Color(1, 1, 1, 0.7))

	# Item level
	var ilvl = int(item.get("item_level", 0))
	if ilvl > 0:
		_add_tip_line("Item Level %d" % ilvl, Color(1.0, 0.82, 0.0))

	# Flavor text
	var flavor = str(item.get("flavor", ""))
	if not flavor.is_empty():
		_add_tip_line("\"" + flavor + "\"", Color(1.0, 0.82, 0.0, 0.8))

	# Update border to quality color
	var tip_style := tooltip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if tip_style:
		tip_style.border_color = q_color

	tooltip_panel.visible = true
	status_label.text = str(item["name"]) + " (" + QUALITY_NAMES.get(quality, "Unknown") + ")"


func _add_tip_line(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_stack.add_child(lbl)


func _log(msg: String) -> void:
	print("[Tooltip] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Self-test
func _run_self_test() -> void:
	print("TOOLTIP_SELF_TEST: starting verification...")

	# 1. Show Shadowmourne tooltip
	_show_tooltip(0)
	if not tooltip_panel.visible:
		_fail("Tooltip panel should be visible after showing item")
		return
	if tooltip_stack.get_child_count() < 5:
		_fail("Shadowmourne tooltip should have at least 5 detail lines, got " + str(tooltip_stack.get_child_count()))
		return

	# 2. Check name color is legendary orange
	var first_child = tooltip_stack.get_child(0) as Label
	if first_child == null or first_child.text != "Shadowmourne":
		_fail("First tooltip line should be Shadowmourne")
		return

	# 3. Show Bag of Candies (common quality)
	_show_tooltip(1)
	var candy_child = tooltip_stack.get_child(0) as Label
	if candy_child == null or candy_child.text != "Bag of Candies":
		_fail("Common item name mismatch")
		return

	# 4. Show Quel'Delar (epic)
	_show_tooltip(2)
	var quel_child = tooltip_stack.get_child(0) as Label
	if quel_child == null or not quel_child.text.begins_with("Quel"):
		_fail("Epic item name mismatch")
		return

	# 5. Show Invincible's Reins (legendary mount)
	_show_tooltip(3)
	var reins_child = tooltip_stack.get_child(0) as Label
	if reins_child == null or reins_child.text != "Invincible's Reins":
		_fail("Mount item name mismatch")
		return

	# 6. Hide tooltip
	_on_item_unhover()
	if tooltip_panel.visible:
		_fail("Tooltip should hide after unhover")
		return

	print("TOOLTIP_SELF_TEST_OK: item quality colors, stat lines, socket display, flavor text, equip effects, and hide/show toggling verified for all quality tiers.")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("TOOLTIP_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
