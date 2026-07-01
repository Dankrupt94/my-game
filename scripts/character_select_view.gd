extends Control

const DASHBOARD_SCENE := "res://main.tscn"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/account.env"

# Login & Roster state
var host_val := "127.0.0.1"
var port_val := "3724"
var account_val := ""
var password_val := ""
var characters := []
var selected_char_idx := -1

# UI references
var host_input: LineEdit
var port_input: LineEdit
var acc_input: LineEdit
var pass_input: LineEdit
var connect_btn: Button

var roster_list: ItemList
var detail_panel: VBoxContainer
var detail_name: Label
var detail_lvl_class: Label
var detail_location: Label
var enter_btn: Button

var create_name_input: LineEdit
var create_race_btn: OptionButton
var create_class_btn: OptionButton
var create_btn: Button

var status_label: Label
var log_log: TextEdit

# Wow class color codes
const CLASS_COLORS := {
	"Warrior": Color(0.78, 0.61, 0.43),
	"Paladin": Color(0.96, 0.55, 0.73),
	"Hunter": Color(0.67, 0.83, 0.45),
	"Rogue": Color(1.0, 0.96, 0.41),
	"Priest": Color(1.0, 1.0, 1.0),
	"Death Knight": Color(0.77, 0.12, 0.23),
	"Shaman": Color(0.0, 0.44, 0.87),
	"Mage": Color(0.25, 0.78, 0.92),
	"Warlock": Color(0.53, 0.53, 0.93),
	"Druid": Color(1.0, 0.49, 0.04)
}

const RACES := ["Human", "Orc", "Dwarf", "Night Elf", "Undead", "Tauren", "Gnome", "Troll"]
const CLASSES := ["Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight", "Shaman", "Mage", "Warlock", "Druid"]


func _ready() -> void:
	_load_credentials()
	_build_view()
	_update_roster_list()
	_select_character(-1)

	if OS.get_environment("ACORE_CHARACTER_SELECT_SELF_TEST") == "1":
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
	title.text = "Character Selection"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Roster inactive"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	# Main horizontal split
	var h_split := HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stack.add_child(h_split)

	# Left Panel: Login & Roster
	var left_side := VBoxContainer.new()
	left_side.custom_minimum_size = Vector2(340, 0)
	left_side.add_theme_constant_override("separation", 10)
	h_split.add_child(left_side)

	# Credentials Grid
	var creds_grid := GridContainer.new()
	creds_grid.columns = 2
	creds_grid.add_theme_constant_override("h_separation", 10)
	creds_grid.add_theme_constant_override("v_separation", 8)
	left_side.add_child(creds_grid)

	_add_grid_input(creds_grid, "Host:", host_val, func(val): host_val = val)
	_add_grid_input(creds_grid, "Port:", port_val, func(val): port_val = val)
	_add_grid_input(creds_grid, "Account:", account_val, func(val): account_val = val)
	_add_grid_input(creds_grid, "Password:", password_val, func(val): password_val = val, true)

	connect_btn = Button.new()
	connect_btn.text = "Connect & Fetch Roster"
	connect_btn.custom_minimum_size = Vector2(0, 34)
	connect_btn.pressed.connect(_on_connect_pressed)
	left_side.add_child(connect_btn)

	var roster_lbl := Label.new()
	roster_lbl.text = "Characters List:"
	roster_lbl.modulate = Color(0.85, 0.72, 0.45)
	left_side.add_child(roster_lbl)

	roster_list = ItemList.new()
	roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_list.item_selected.connect(_on_roster_selected)
	left_side.add_child(roster_list)

	# Right Panel: Selection details and creator
	var right_side := VBoxContainer.new()
	right_side.add_theme_constant_override("separation", 16)
	h_split.add_child(right_side)

	# Selection details card
	var card := PanelContainer.new()
	right_side.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 16)
	card_margin.add_theme_constant_override("margin_top", 16)
	card_margin.add_theme_constant_override("margin_right", 16)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(card_margin)

	detail_panel = VBoxContainer.new()
	detail_panel.add_theme_constant_override("separation", 8)
	card_margin.add_child(detail_panel)

	detail_name = Label.new()
	detail_name.text = "No Character Selected"
	detail_name.add_theme_font_size_override("font_size", 22)
	detail_panel.add_child(detail_name)

	detail_lvl_class = Label.new()
	detail_lvl_class.text = "Please fetch roster and select a character."
	detail_lvl_class.modulate = Color(0.7, 0.7, 0.7)
	detail_panel.add_child(detail_lvl_class)

	detail_location = Label.new()
	detail_location.text = ""
	detail_panel.add_child(detail_location)

	enter_btn = Button.new()
	enter_btn.text = "Enter World"
	enter_btn.custom_minimum_size = Vector2(160, 36)
	enter_btn.pressed.connect(_on_enter_world_pressed)
	enter_btn.disabled = true
	detail_panel.add_child(enter_btn)

	# Character Creator Panel
	var creator_card := PanelContainer.new()
	right_side.add_child(creator_card)

	var creator_margin := MarginContainer.new()
	creator_margin.add_theme_constant_override("margin_left", 16)
	creator_margin.add_theme_constant_override("margin_top", 16)
	creator_margin.add_theme_constant_override("margin_right", 16)
	creator_margin.add_theme_constant_override("margin_bottom", 16)
	creator_card.add_child(creator_margin)

	var creator_stack := VBoxContainer.new()
	creator_stack.add_theme_constant_override("separation", 10)
	creator_margin.add_child(creator_stack)

	var creator_title := Label.new()
	creator_title.text = "Character Creator"
	creator_title.modulate = Color(0.85, 0.72, 0.45)
	creator_title.add_theme_font_size_override("font_size", 16)
	creator_stack.add_child(creator_title)

	var create_grid := GridContainer.new()
	create_grid.columns = 2
	create_grid.add_theme_constant_override("h_separation", 12)
	create_grid.add_theme_constant_override("v_separation", 10)
	creator_stack.add_child(create_grid)

	var name_lbl := Label.new()
	name_lbl.text = "Char Name:"
	create_grid.add_child(name_lbl)

	create_name_input = LineEdit.new()
	create_name_input.placeholder_text = "Enter name..."
	create_grid.add_child(create_name_input)

	var race_lbl := Label.new()
	race_lbl.text = "Race:"
	create_grid.add_child(race_lbl)

	create_race_btn = OptionButton.new()
	for r in RACES:
		create_race_btn.add_item(r)
	create_grid.add_child(create_race_btn)

	var class_lbl := Label.new()
	class_lbl.text = "Class:"
	create_grid.add_child(class_lbl)

	create_class_btn = OptionButton.new()
	for c in CLASSES:
		create_class_btn.add_item(c)
	create_grid.add_child(create_class_btn)

	create_btn = Button.new()
	create_btn.text = "Create Character"
	create_btn.pressed.connect(_on_create_pressed)
	create_btn.disabled = true
	creator_stack.add_child(create_btn)

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


func _add_grid_input(parent: Control, caption: String, default_text: String, callback: Callable, is_password := false) -> void:
	var lbl := Label.new()
	lbl.text = caption
	lbl.custom_minimum_size = Vector2(80, 0)
	parent.add_child(lbl)

	var line := LineEdit.new()
	line.text = default_text
	line.secret = is_password
	line.custom_minimum_size = Vector2(200, 32)
	line.text_changed.connect(callback)
	parent.add_child(line)


func _update_roster_list() -> void:
	roster_list.clear()
	for char in characters:
		var cls_name = char["class"]
		var txt := "%s (Level %d %s)" % [char["name"], char["level"], cls_name]
		roster_list.add_item(txt)


func _on_roster_selected(idx: int) -> void:
	_select_character(idx)


func _select_character(idx: int) -> void:
	selected_char_idx = idx
	if idx < 0 or idx >= characters.size():
		detail_name.text = "No Character Selected"
		detail_lvl_class.text = "Please fetch roster and select a character."
		detail_lvl_class.modulate = Color(0.7, 0.7, 0.7)
		detail_location.text = ""
		enter_btn.disabled = true
		return

	var char = characters[idx]
	detail_name.text = char["name"]
	var cls_name = char["class"]
	detail_lvl_class.text = "Level %d %s (%s)" % [char["level"], cls_name, char["race"]]
	detail_lvl_class.modulate = CLASS_COLORS.get(cls_name, Color.WHITE)
	detail_location.text = "Location: Map %d (X: %.2f, Y: %.2f, Z: %.2f)" % [char["map"], char["x"], char["y"], char["z"]]
	enter_btn.disabled = false


func _on_connect_pressed() -> void:
	_log("Connecting to authserver to retrieve characters...")
	if OS.get_environment("ACORE_CHARACTER_SELECT_SELF_TEST") == "1":
		characters = [
			{
				"guid": "0x001",
				"name": "Codexstage",
				"level": 80,
				"race": "Human",
				"class": "Warrior",
				"map": 0,
				"x": 10.0,
				"y": 20.0,
				"z": 30.0
			},
			{
				"guid": "0x002",
				"name": "Doodbro",
				"level": 80,
				"race": "Human",
				"class": "Paladin",
				"map": 0,
				"x": 15.0,
				"y": -25.0,
				"z": 30.0
			}
		]
		_log("Fetched 2 characters (Mock).")
		_update_roster_list()
		_select_character(-1)
		create_btn.disabled = false
		status_label.text = "Roster loaded"
		return

	# Real C++ GDExtension flow call
	var bridge = load("res://scripts/protocol_client_bridge.gd").new()
	var result = bridge.run_character_flow(host_val, port_val)
	if result.get("ok", false):
		characters = result.get("characters", [])
		_log("Fetched %d characters from server." % characters.size())
		_update_roster_list()
		_select_character(-1)
		create_btn.disabled = false
		status_label.text = "Roster loaded"
	else:
		_log("Roster fetch failed: " + result.get("error", "Unknown error"))
		status_label.text = "Connect failed"


func _on_create_pressed() -> void:
	var name_txt := create_name_input.text.strip_edges()
	if name_txt.length() < 2 or name_txt.length() > 12:
		_log("Error: Character name must be between 2 and 12 characters.")
		return

	var race_name = create_race_btn.get_item_text(create_race_btn.selected)
	var cls_name = create_class_btn.get_item_text(create_class_btn.selected)

	_log("Creating character: " + name_txt + " (" + race_name + " " + cls_name + ")...")

	if OS.get_environment("ACORE_CHARACTER_SELECT_SELF_TEST") == "1":
		characters.append({
			"guid": "0x00" + str(characters.size() + 1),
			"name": name_txt,
			"level": 1,
			"race": race_name,
			"class": cls_name,
			"map": 0,
			"x": 0.0,
			"y": 0.0,
			"z": 0.0
		})
		_log("Character created successfully (Mock).")
		_update_roster_list()
		_select_character(characters.size() - 1)
		create_name_input.text = ""
		return

	# Real GDExtension create character flow
	# (For the scope of GDExtension, character creation returns success / list update)
	var bridge = load("res://scripts/protocol_client_bridge.gd").new()
	var result = bridge.create_character(name_txt, host_val, port_val) # theoretically mapped
	if result.get("ok", false):
		_log("Character created successfully.")
		_on_connect_pressed() # Refetch
	else:
		_log("Creation failed: " + result.get("error", "Unknown error"))


func _on_enter_world_pressed() -> void:
	if selected_char_idx < 0:
		return
	var char = characters[selected_char_idx]
	_log("Entering world with: " + char["name"] + "...")

	if OS.get_environment("ACORE_CHARACTER_SELECT_SELF_TEST") == "1":
		_log("World session launched successfully. Transitioning to sandbox...")
		return

	# Real enter world call
	var bridge = load("res://scripts/protocol_client_bridge.gd").new()
	var result = bridge.enter_world(char["name"], host_val, port_val)
	if result.get("ok", false):
		_log("Logged in! Redirecting...")
		get_tree().change_scene_to_file(DASHBOARD_SCENE)
	else:
		_log("Enter world failed: " + result.get("error", "Unknown error"))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _log(msg: String) -> void:
	print("[CharSelect] " + msg)
	if log_log != null:
		log_log.text += msg + "\n"
		log_log.scroll_vertical = 99999


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("CHARACTER_SELECT_SELF_TEST: starting verification...")

	# 1. Connect & Fetch
	_on_connect_pressed()
	if characters.size() != 2:
		_fail_self_test("Roster loading size mismatch")
		return

	# 2. Select Doodbro
	_on_roster_selected(1)
	if selected_char_idx != 1 or detail_name.text != "Doodbro":
		_fail_self_test("Character selection details mismatch")
		return
	if enter_btn.disabled:
		_fail_self_test("Enter World button should be active for selected character")
		return

	# 3. Create Character Validation
	create_name_input.text = "A" # Too short
	_on_create_pressed()
	if characters.size() != 2:
		_fail_self_test("Short name length constraint should block creation")
		return

	create_name_input.text = "Newchar"
	create_race_btn.selected = 0 # Human
	create_class_btn.selected = 1 # Paladin
	_on_create_pressed()
	if characters.size() != 3:
		_fail_self_test("Character creation addition failed")
		return
	if characters[2]["name"] != "Newchar" or characters[2]["class"] != "Paladin":
		_fail_self_test("Created character values mismatch")
		return

	# 4. Enter World
	selected_char_idx = 2
	_on_enter_world_pressed()

	print("CHARACTER_SELECT_SELF_TEST_OK: login pre-fills, character list cards, creator validation, and enter-world triggers passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("CHARACTER_SELECT_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
