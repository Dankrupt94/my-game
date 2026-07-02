extends Node3D

const SettingsRuntime = preload("res://scripts/settings_runtime.gd")

const DASHBOARD_SCENE := "res://main.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/character_select_view.tscn"

const WORLD_TO_GODOT_SCALE := 0.02
const GRID_EXTENT := 220
const GRID_STEP := 20
const MARKER_MOVE_SPEED := 14.0
const WORLD_SESSION_LAYOUT_FILE_PATH := "user://world-session-layout.cfg"
const WORLD_SESSION_LAYOUT_SELF_TEST_FILE_PATH := "user://world-session-layout-self-test.cfg"
const PANEL_DEFAULT_POSITION := Vector2(18.0, 156.0)
const PANEL_DEFAULT_SIZE := Vector2(560.0, 380.0)
const PANEL_MIN_SIZE := Vector2(360.0, 180.0)
const PANEL_MAX_SIZE := Vector2(900.0, 620.0)
const PANEL_DRAG_GRID := 10.0
const PANEL_NAMES := [
	"chat",
	"character",
	"spells",
	"actions",
	"targets",
	"auras",
	"quests",
	"loot",
	"vendor",
	"trainer",
	"social",
	"mail",
	"map",
	"options",
	"inventory"
]
const PANEL_TITLES := {
	"actions": "Actions",
	"auras": "Auras",
	"character": "Character",
	"chat": "Chat",
	"inventory": "Bags",
	"loot": "Loot",
	"mail": "Mail",
	"map": "Map",
	"options": "Options",
	"quests": "Quests",
	"social": "Social",
	"spells": "Spells",
	"targets": "Targets",
	"trainer": "Trainer",
	"vendor": "Vendor",
}
const ACTION_BAR_DISPLAY_COUNT := 12
const ACTION_BAR_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
const EQUIPMENT_SLOT_COUNT := 19
const INFINITE_STOCK := 0xFFFFFFFF
const QUEST_LOG_SLOT_COUNT := 25
const INVENTORY_SLOT_NAMES := [
	"Head",
	"Neck",
	"Shoulder",
	"Shirt",
	"Chest",
	"Waist",
	"Legs",
	"Feet",
	"Wrist",
	"Hands",
	"Finger 1",
	"Finger 2",
	"Trinket 1",
	"Trinket 2",
	"Back",
	"Main Hand",
	"Off Hand",
	"Ranged",
	"Tabard",
	"Bag 1",
	"Bag 2",
	"Bag 3",
	"Bag 4",
	"Backpack 1",
	"Backpack 2",
	"Backpack 3",
	"Backpack 4",
	"Backpack 5",
	"Backpack 6",
	"Backpack 7",
	"Backpack 8",
	"Backpack 9",
	"Backpack 10",
	"Backpack 11",
	"Backpack 12",
	"Backpack 13",
	"Backpack 14",
	"Backpack 15",
	"Backpack 16",
]

var player_marker: CharacterBody3D
var target_marker: MeshInstance3D
var camera: Camera3D
var status_label: Label
var detail_label: Label
var target_label: Label
var target_frame_body: VBoxContainer
var quest_label: Label
var session_label: Label
var quest_tracker_body: VBoxContainer
var panel_overlay: Control
var panel_shell: PanelContainer
var panel_title_label: Label
var panel_body: VBoxContainer
var session_panels := {}
var action_buttons: Array[Button] = []
var shortcut_slots: Array[Button] = []

var layout_file_path := WORLD_SESSION_LAYOUT_FILE_PATH
var camera_yaw := 0.0
var marker_velocity := Vector3.ZERO
var authoritative_marker_position := Vector3.ZERO
var session_map_id := 0
var session_wow_position := Vector3.ZERO
var session_orientation := 0.0
var session_character_profile: Dictionary = {}
var visible_object_count := 0
var visible_objects: Array = []
var session_chat_rows: Array = []
var session_spell_rows: Array = []
var session_action_slots: Array = []
var session_unit_status_snapshot: Dictionary = {}
var session_loot_snapshot: Dictionary = {}
var session_vendor_snapshot: Dictionary = {}
var session_trainer_snapshot: Dictionary = {}
var session_social_snapshot: Dictionary = {}
var session_mail_snapshot: Dictionary = {}
var session_inventory_slots: Array = []
var session_coinage := -1
var selected_target_index := -1
var target_was_pressed := false
var attack_was_pressed := false
var interact_was_pressed := false
var reset_was_pressed := false
var jump_was_pressed := false
var active_panel_name := ""
var panel_dragging_name := ""
var panel_drag_offset := Vector2.ZERO
var panel_resizing_name := ""
var panel_resize_start_mouse := Vector2.ZERO
var panel_resize_start_size := Vector2.ZERO
var session_quest_slots: Array = []


func _ready() -> void:
	if OS.get_environment("ACORE_WORLD_SESSION_LAYOUT_SELF_TEST") == "1":
		layout_file_path = WORLD_SESSION_LAYOUT_SELF_TEST_FILE_PATH
		_delete_layout_file(layout_file_path)
	_apply_saved_keybindings()
	_build_world()
	_build_hud()
	_apply_session_context()
	if OS.get_environment("ACORE_WORLD_SESSION_LAYOUT_SELF_TEST") == "1":
		call_deferred("_run_layout_self_test")
	elif OS.get_environment("ACORE_WORLD_SESSION_KEYBIND_SELF_TEST") == "1":
		call_deferred("_run_keybind_settings_self_test")
	elif OS.get_environment("ACORE_WORLD_SESSION_SELF_TEST") == "1":
		call_deferred("_run_self_test")


func _physics_process(delta: float) -> void:
	_update_camera_input(delta)
	_update_marker_movement(delta)
	_update_key_actions()
	_update_camera()


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.72, 0.80)
	environment.ambient_light_energy = 0.85
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 36, 0)
	sun.light_energy = 1.7
	add_child(sun)

	_add_grid()
	_add_axis_label("X", Vector3(GRID_EXTENT + 14, 0, 0), Color(0.9, 0.18, 0.16))
	_add_axis_label("Y", Vector3(0, 0, -GRID_EXTENT - 14), Color(0.16, 0.62, 0.96))

	player_marker = CharacterBody3D.new()
	player_marker.name = "SessionPlayerMarker"
	add_child(player_marker)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 1.8
	capsule_shape.height = 6.0
	collision.shape = capsule_shape
	player_marker.add_child(collision)

	var marker_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.8
	capsule.height = 6.0
	marker_mesh.mesh = capsule
	marker_mesh.material_override = _material(Color(0.95, 0.73, 0.24))
	player_marker.add_child(marker_mesh)

	var label := Label3D.new()
	label.name = "CharacterLabel"
	label.position = Vector3(0, 5.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 20
	label.modulate = Color(0.96, 0.97, 0.92)
	player_marker.add_child(label)

	target_marker = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 3.1
	ring.bottom_radius = 3.1
	ring.height = 0.08
	target_marker.mesh = ring
	target_marker.material_override = _material(Color(0.24, 0.76, 0.95, 0.48))
	target_marker.position = Vector3(0, 0.04, 0)
	add_child(target_marker)

	camera = Camera3D.new()
	camera.fov = 58
	camera.current = true
	add_child(camera)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := MarginContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 14)
	layer.add_child(root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	root.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	layout.add_child(top_row)

	var health := _bar("Health", 100.0)
	health.value = 100.0
	top_row.add_child(health)
	var power := _bar("Power", 100.0)
	power.value = 100.0
	top_row.add_child(power)
	var target := _bar("Target", 100.0)
	target.value = 0.0
	top_row.add_child(target)

	status_label = _hud_label()
	layout.add_child(status_label)
	detail_label = _hud_label()
	layout.add_child(detail_label)
	target_label = _hud_label()
	layout.add_child(target_label)
	_build_target_frame(layout)
	quest_label = _hud_label()
	layout.add_child(quest_label)
	_build_quest_tracker(layout)
	session_label = _hud_label()
	layout.add_child(session_label)

	_build_panel_shell(layer)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var shortcut_grid := GridContainer.new()
	shortcut_grid.columns = 12
	shortcut_grid.add_theme_constant_override("h_separation", 6)
	shortcut_grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(shortcut_grid)
	_build_shortcut_slots(shortcut_grid)

	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 8)
	layout.add_child(nav_bar)

	_add_panel_button(nav_bar, "Chat", "chat")
	_add_panel_button(nav_bar, "Character", "character")
	_add_panel_button(nav_bar, "Spells", "spells")
	_add_panel_button(nav_bar, "Actions", "actions")
	_add_panel_button(nav_bar, "Targets", "targets")
	_add_panel_button(nav_bar, "Auras", "auras")
	_add_panel_button(nav_bar, "Quests", "quests")
	_add_panel_button(nav_bar, "Loot", "loot")
	_add_panel_button(nav_bar, "Vendor", "vendor")
	_add_panel_button(nav_bar, "Trainer", "trainer")
	_add_panel_button(nav_bar, "Social", "social")
	_add_panel_button(nav_bar, "Mail", "mail")
	_add_panel_button(nav_bar, "Map", "map")
	_add_panel_button(nav_bar, "Bags", "inventory")
	_add_panel_button(nav_bar, "Options", "options")
	_add_scene_button(nav_bar, "Roster", CHARACTER_SELECT_SCENE)
	_add_scene_button(nav_bar, "Dashboard", DASHBOARD_SCENE)


func _build_quest_tracker(parent: Control) -> void:
	var tracker := PanelContainer.new()
	tracker.name = "QuestTrackerHud"
	tracker.custom_minimum_size = Vector2(340.0, 92.0)
	var tracker_style := StyleBoxFlat.new()
	tracker_style.bg_color = Color(0.035, 0.043, 0.048, 0.78)
	tracker_style.border_color = Color(0.24, 0.30, 0.32, 0.85)
	tracker_style.set_border_width_all(1)
	tracker_style.corner_radius_top_left = 5
	tracker_style.corner_radius_top_right = 5
	tracker_style.corner_radius_bottom_left = 5
	tracker_style.corner_radius_bottom_right = 5
	tracker.add_theme_stylebox_override("panel", tracker_style)
	parent.add_child(tracker)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	tracker.add_child(margin)

	quest_tracker_body = VBoxContainer.new()
	quest_tracker_body.add_theme_constant_override("separation", 4)
	margin.add_child(quest_tracker_body)


func _build_target_frame(parent: Control) -> void:
	var frame := PanelContainer.new()
	frame.name = "TargetFrameHud"
	frame.custom_minimum_size = Vector2(340.0, 70.0)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.040, 0.044, 0.052, 0.76)
	frame_style.border_color = Color(0.30, 0.34, 0.40, 0.82)
	frame_style.set_border_width_all(1)
	frame_style.corner_radius_top_left = 5
	frame_style.corner_radius_top_right = 5
	frame_style.corner_radius_bottom_left = 5
	frame_style.corner_radius_bottom_right = 5
	frame.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)

	target_frame_body = VBoxContainer.new()
	target_frame_body.add_theme_constant_override("separation", 4)
	margin.add_child(target_frame_body)


func _refresh_target_frame() -> void:
	if target_frame_body == null:
		return
	_clear_children(target_frame_body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	target_frame_body.add_child(header)

	var title := _panel_label("Target", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var open_button := Button.new()
	open_button.text = "Open"
	open_button.tooltip_text = "Open Targets"
	open_button.custom_minimum_size = Vector2(72.0, 28.0)
	open_button.pressed.connect(_show_session_panel.bind("targets"))
	header.add_child(open_button)

	if visible_object_count <= 0:
		target_frame_body.add_child(_panel_label("No visible-object snapshot yet.", 12))
		return
	if selected_target_index < 0:
		target_frame_body.add_child(
			_panel_label("Visible: %s | selected: none" % str(visible_object_count), 12)
		)
		return

	var target := _visible_object_at(selected_target_index)
	var target_status := _normalize_unit_status(target, "Target")
	target_frame_body.add_child(
		_panel_label(
			(
				"Selected %s of %s | %s"
				% [
					str(selected_target_index + 1),
					str(visible_object_count),
					_target_summary(target, selected_target_index),
				]
			),
			12
		)
	)
	if not target_status.is_empty():
		target_frame_body.add_child(_panel_label(_unit_status_short_line(target_status), 12))
		var aura_count := _unit_aura_count(target_status)
		if aura_count > 0:
			target_frame_body.add_child(_panel_label("Auras: " + str(aura_count), 12))


func _refresh_quest_tracker() -> void:
	if quest_tracker_body == null:
		return
	_clear_children(quest_tracker_body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	quest_tracker_body.add_child(header)

	var title := _panel_label("Quest Tracker", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var open_button := Button.new()
	open_button.text = "Open"
	open_button.tooltip_text = "Open Quests"
	open_button.custom_minimum_size = Vector2(72.0, 28.0)
	open_button.pressed.connect(_show_session_panel.bind("quests"))
	header.add_child(open_button)

	var active_slots := _quest_active_slots()
	if session_quest_slots.is_empty():
		quest_tracker_body.add_child(_panel_label("Waiting for quest-log snapshot.", 12))
		return
	if active_slots.is_empty():
		quest_tracker_body.add_child(_panel_label("No active quest ids in snapshot.", 12))
		return

	var rendered := 0
	for slot in active_slots:
		if rendered >= 4:
			break
		quest_tracker_body.add_child(_quest_tracker_row(slot))
		rendered += 1
	if active_slots.size() > rendered:
		quest_tracker_body.add_child(
			_panel_label(
				(
					"+%s more active quest slot%s"
					% [
						str(active_slots.size() - rendered),
						"" if active_slots.size() - rendered == 1 else "s",
					]
				),
				12
			)
		)


func _quest_tracker_row(slot: Dictionary) -> Label:
	var text := (
		"Slot %s | %s"
		% [
			str(slot.get("slot", "?")),
			_quest_slot_state(slot),
		]
	)
	return _panel_label(text, 12)


func _apply_session_context() -> void:
	var context := _session_context()
	if context == null:
		_apply_session_data({}, {}, "No active session context.")
		return
	var character: Dictionary = context.selected_character
	var enter_result: Dictionary = context.last_enter_world_result
	_apply_session_data(character, enter_result, "Session loaded from login flow.")


func _apply_session_data(
	character: Dictionary, enter_result: Dictionary, source_text: String
) -> void:
	var login: Dictionary = enter_result.get("login", {})
	var update: Dictionary = enter_result.get("update", {})
	var character_name := str(character.get("name", enter_result.get("character_name", "Unknown")))
	var map_id := int(login.get("map", character.get("map", 0)))
	var wow_x := float(login.get("x", character.get("x", 0.0)))
	var wow_y := float(login.get("y", character.get("y", 0.0)))
	var wow_z := float(login.get("z", character.get("z", 0.0)))
	session_map_id = map_id
	session_wow_position = Vector3(wow_x, wow_y, wow_z)
	session_orientation = float(login.get("orientation", character.get("orientation", 0.0)))
	session_character_profile = _character_profile(
		character, enter_result, character_name, map_id, wow_x, wow_y, wow_z
	)
	var marker_position := _godot_position(wow_x, wow_y, wow_z)

	player_marker.position = marker_position
	authoritative_marker_position = marker_position
	target_marker.position = Vector3(marker_position.x, 0.04, marker_position.z)
	var name_label := player_marker.get_node_or_null("CharacterLabel")
	if name_label is Label3D:
		name_label.text = "%s\nmap %s" % [character_name, str(map_id)]

	status_label.text = "World Session"
	detail_label.text = (
		"%s Level %s %s on map %s at %.2f, %.2f, %.2f."
		% [
			character_name,
			str(character.get("level", "?")),
			str(character.get("class", "")),
			str(map_id),
			wow_x,
			wow_y,
			wow_z,
		]
	)
	visible_object_count = int(update.get("visible_object_count", 0))
	visible_objects = _extract_visible_objects(character, enter_result)
	if not visible_objects.is_empty():
		visible_object_count = max(visible_object_count, visible_objects.size())
	session_chat_rows = _extract_chat_rows(character, enter_result)
	session_spell_rows = _extract_spell_rows(character, enter_result)
	session_action_slots = _extract_action_slots(character, enter_result)
	session_unit_status_snapshot = _extract_unit_status_snapshot(character, enter_result)
	session_loot_snapshot = _extract_loot_snapshot(character, enter_result)
	session_vendor_snapshot = _extract_vendor_snapshot(character, enter_result)
	session_trainer_snapshot = _extract_trainer_snapshot(character, enter_result)
	session_social_snapshot = _extract_social_snapshot(character, enter_result)
	session_mail_snapshot = _extract_mail_snapshot(character, enter_result)
	session_inventory_slots = _extract_inventory_slots(character, enter_result)
	session_coinage = _extract_coinage(character, enter_result)
	session_quest_slots = _extract_quest_slots(character, enter_result)
	selected_target_index = -1
	_refresh_shortcut_slots()
	_refresh_target_label()
	var active_quest_count := _quest_active_count()
	if active_quest_count > 0:
		quest_label.text = (
			"Quest tracker: %s active quest slot%s."
			% [
				str(active_quest_count),
				"" if active_quest_count == 1 else "s",
			]
		)
	else:
		quest_label.text = "Quest tracker: waiting for live quest-log integration."
	_refresh_quest_tracker()
	session_label.text = source_text
	_update_camera()


func _character_profile(
	character: Dictionary,
	enter_result: Dictionary,
	character_name: String,
	map_id: int,
	wow_x: float,
	wow_y: float,
	wow_z: float
) -> Dictionary:
	return {
		"name": character_name,
		"level": character.get("level", enter_result.get("level", "?")),
		"race": character.get("race", enter_result.get("race", "")),
		"class": character.get("class", enter_result.get("class", "")),
		"gender": character.get("gender", enter_result.get("gender", "")),
		"guid": character.get("guid", enter_result.get("guid", "")),
		"zone": character.get("zone", enter_result.get("zone", "")),
		"map": map_id,
		"x": wow_x,
		"y": wow_y,
		"z": wow_z,
		"orientation": session_orientation,
	}


func _extract_visible_objects(character: Dictionary, enter_result: Dictionary) -> Array:
	var candidates: Array = [
		character.get("visible_objects", []),
		character.get("objects", []),
		enter_result.get("visible_objects", []),
		enter_result.get("objects", []),
	]
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("visible_objects", []))
		candidates.append(update.get("objects", []))

	for candidate in candidates:
		if candidate is Array and not candidate.is_empty():
			return _normalize_visible_objects(candidate)
		if candidate is Dictionary:
			var rows = candidate.get("rows", candidate.get("objects", []))
			if rows is Array and not rows.is_empty():
				return _normalize_visible_objects(rows)
	return []


func _normalize_visible_objects(raw_objects: Array) -> Array:
	var rows: Array = []
	for index in range(raw_objects.size()):
		var raw_object = raw_objects[index]
		if not raw_object is Dictionary:
			continue
		var row: Dictionary = raw_object.duplicate(true)
		if not row.has("index"):
			row["index"] = index
		if not row.has("guid") and row.has("object_guid"):
			row["guid"] = row.get("object_guid")
		if not row.has("entry"):
			for key in ["entry_id", "object_entry", "id"]:
				if row.has(key):
					row["entry"] = int(row.get(key, 0))
					break
		rows.append(row)
	return rows


func _extract_unit_status_snapshot(character: Dictionary, enter_result: Dictionary) -> Dictionary:
	var update = enter_result.get("update", {})
	var player_sources: Array = [
		character,
		character.get("unit_status", {}),
		character.get("player_status", {}),
		character.get("auras", {}),
		enter_result.get("player", {}),
		enter_result.get("player_status", {}),
		enter_result.get("unit_status", {}).get("player", {})
		if enter_result.get("unit_status", {}) is Dictionary
		else {},
	]
	var target_sources: Array = [
		enter_result.get("target", {}),
		enter_result.get("target_status", {}),
		enter_result.get("unit_status", {}).get("target", {})
		if enter_result.get("unit_status", {}) is Dictionary
		else {},
	]
	if update is Dictionary:
		player_sources.append(update.get("player", {}))
		player_sources.append(update.get("player_status", {}))
		target_sources.append(update.get("target", {}))
		target_sources.append(update.get("target_status", {}))
		if update.get("unit_status", {}) is Dictionary:
			player_sources.append(update.get("unit_status", {}).get("player", {}))
			target_sources.append(update.get("unit_status", {}).get("target", {}))

	var player_status := _first_unit_status(player_sources, "Player")
	var target_status := _first_unit_status(target_sources, "Target")
	return {
		"player": player_status,
		"target": target_status,
		"has_unit_status": not player_status.is_empty() or not target_status.is_empty(),
	}


func _first_unit_status(sources: Array, fallback_name: String) -> Dictionary:
	for source in sources:
		if not source is Dictionary or source.is_empty():
			continue
		var status := _normalize_unit_status(source, fallback_name)
		if bool(status.get("has_unit_data", false)):
			return status
	return {}


func _normalize_unit_status(raw_status: Dictionary, fallback_name: String) -> Dictionary:
	var auras := _collect_unit_auras(raw_status)
	var cooldowns := _normalize_cooldown_rows(
		_unit_raw_rows(raw_status, ["cooldowns", "spell_cooldowns"])
	)
	var health := _unit_int_value(raw_status, ["health", "hp", "current_health"], -1)
	var max_health := _unit_int_value(raw_status, ["max_health", "health_max", "max_hp"], -1)
	var power := _unit_int_value(raw_status, ["power", "mana", "rage", "energy"], -1)
	var max_power := _unit_int_value(raw_status, ["max_power", "power_max", "max_mana"], -1)
	var has_unit_data := (
		_looks_like_unit_status(raw_status)
		or not auras.is_empty()
		or not cooldowns.is_empty()
	)
	if not has_unit_data:
		return {}
	return {
		"has_unit_data": has_unit_data,
		"name": _unit_name(raw_status, fallback_name),
		"guid": raw_status.get("guid", raw_status.get("unit_guid", "")),
		"level": raw_status.get("level", raw_status.get("unit_level", "")),
		"class": raw_status.get("class", raw_status.get("unit_class", "")),
		"reaction": raw_status.get("reaction", raw_status.get("faction_reaction", "")),
		"faction": raw_status.get("faction", raw_status.get("faction_template", "")),
		"health": health,
		"max_health": max_health,
		"power": power,
		"max_power": max_power,
		"power_type": raw_status.get("power_type", raw_status.get("power_kind", "")),
		"auras": auras,
		"cooldowns": cooldowns,
	}


func _looks_like_unit_status(raw_status: Dictionary) -> bool:
	for key in [
		"health",
		"hp",
		"current_health",
		"max_health",
		"max_hp",
		"power",
		"max_power",
		"mana",
		"max_mana",
		"rage",
		"energy",
		"auras",
		"buffs",
		"debuffs",
		"cooldowns",
		"spell_cooldowns",
		"reaction",
		"faction",
	]:
		if raw_status.has(key):
			return true
	return false


func _collect_unit_auras(raw_status: Dictionary) -> Array:
	var auras: Array = []
	for aura in _normalize_aura_rows(_unit_raw_rows(raw_status, ["auras"]), "aura"):
		auras.append(aura)
	for aura in _normalize_aura_rows(_unit_raw_rows(raw_status, ["buffs"]), "buff"):
		auras.append(aura)
	for aura in _normalize_aura_rows(_unit_raw_rows(raw_status, ["debuffs"]), "debuff"):
		auras.append(aura)
	return auras


func _unit_raw_rows(snapshot: Dictionary, keys: Array) -> Array:
	for key in keys:
		var value: Variant = snapshot.get(key, [])
		if value is Array:
			return value
		if value is Dictionary:
			for row_key in ["rows", "entries", "auras", "buffs", "debuffs", "cooldowns"]:
				if value.has(row_key) and value.get(row_key) is Array:
					return value.get(row_key)
	return []


func _normalize_aura_rows(raw_rows: Array, default_kind: String) -> Array:
	var rows: Array = []
	for index in range(raw_rows.size()):
		var raw_row = raw_rows[index]
		var row: Dictionary = {}
		if raw_row is Dictionary:
			row = raw_row.duplicate(true)
		elif raw_row is String:
			row = {"name": raw_row}
		else:
			continue
		if not row.has("spell_id"):
			row["spell_id"] = _unit_int_value(row, ["id", "spell", "spell_entry"], 0)
		if not row.has("name"):
			var spell_id := int(row.get("spell_id", 0))
			row["name"] = "spell " + str(spell_id) if spell_id > 0 else "aura"
		if not row.has("kind"):
			row["kind"] = _aura_kind(row, default_kind)
		if not row.has("stacks"):
			row["stacks"] = _unit_int_value(row, ["stack_count", "charges", "count"], 0)
		if not row.has("duration_ms"):
			row["duration_ms"] = _unit_int_value(row, ["duration", "duration_left_ms"], 0)
		if not row.has("remaining_ms"):
			row["remaining_ms"] = _unit_int_value(row, ["remaining", "time_left_ms"], 0)
		if not row.has("index"):
			row["index"] = index
		rows.append(row)
	return rows


func _normalize_cooldown_rows(raw_rows: Array) -> Array:
	var rows: Array = []
	for index in range(raw_rows.size()):
		var raw_row = raw_rows[index]
		if not raw_row is Dictionary:
			continue
		var row: Dictionary = raw_row.duplicate(true)
		if not row.has("spell_id"):
			row["spell_id"] = _unit_int_value(row, ["id", "spell", "spell_entry"], 0)
		if not row.has("remaining_ms"):
			row["remaining_ms"] = _unit_int_value(row, ["remaining", "time_left_ms"], 0)
		if not row.has("duration_ms"):
			row["duration_ms"] = _unit_int_value(row, ["duration", "duration_left_ms"], 0)
		if not row.has("index"):
			row["index"] = index
		rows.append(row)
	return rows


func _unit_name(raw_status: Dictionary, fallback_name: String) -> String:
	for key in ["name", "unit_name", "character_name", "target_name"]:
		var value := str(raw_status.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return fallback_name


func _unit_int_value(row: Dictionary, keys: Array, fallback: int = 0) -> int:
	for key in keys:
		if row.has(key):
			return int(row.get(key, fallback))
	return fallback


func _aura_kind(row: Dictionary, default_kind: String) -> String:
	var kind := str(row.get("type", row.get("kind", ""))).strip_edges().to_lower()
	if not kind.is_empty():
		return kind
	if bool(row.get("is_buff", row.get("helpful", false))):
		return "buff"
	if bool(row.get("is_debuff", row.get("harmful", false))):
		return "debuff"
	return default_kind if not default_kind.is_empty() else "aura"


func _extract_chat_rows(character: Dictionary, enter_result: Dictionary) -> Array:
	var candidates: Array = [
		character.get("chat", {}),
		character.get("chat_log", {}),
		character.get("messages", []),
		enter_result.get("chat", {}),
		enter_result.get("chat_log", {}),
		enter_result.get("messages", []),
	]
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("chat", {}))
		candidates.append(update.get("chat_log", {}))
		candidates.append(update.get("messages", []))

	for candidate in candidates:
		var raw_rows = []
		if candidate is Dictionary:
			raw_rows = candidate.get(
				"messages", candidate.get("rows", candidate.get("chat_rows", []))
			)
		elif candidate is Array:
			raw_rows = candidate
		if raw_rows is Array and not raw_rows.is_empty():
			var normalized := _normalize_chat_rows(raw_rows)
			if not normalized.is_empty():
				return normalized
	return []


func _normalize_chat_rows(raw_rows: Array) -> Array:
	var rows: Array = []
	for index in range(raw_rows.size()):
		var raw_row = raw_rows[index]
		var row: Dictionary = {}
		if raw_row is Dictionary:
			row = raw_row.duplicate(true)
		elif raw_row is String:
			row = {"message": raw_row}
		else:
			continue
		if not row.has("message"):
			for key in ["received_message", "text", "body", "line"]:
				if row.has(key):
					row["message"] = str(row.get(key, ""))
					break
		var message := str(row.get("message", "")).strip_edges()
		if message.is_empty():
			continue
		row["message"] = message
		if not row.has("index"):
			row["index"] = index
		if not row.has("mode"):
			for key in ["channel", "chat_type", "type"]:
				if row.has(key):
					row["mode"] = str(row.get(key, ""))
					break
		rows.append(row)
	return rows


func _extract_spell_rows(character: Dictionary, enter_result: Dictionary) -> Array:
	var candidates: Array = [
		character.get("spellbook", {}),
		character.get("initial_spells", {}),
		character.get("known_spells", {}),
		character.get("spells", []),
		enter_result.get("spellbook", {}),
		enter_result.get("initial_spells", {}),
		enter_result.get("known_spells", {}),
		enter_result.get("spells", []),
	]
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("spellbook", {}))
		candidates.append(update.get("initial_spells", {}))
		candidates.append(update.get("known_spells", {}))
		candidates.append(update.get("spells", []))

	for candidate in candidates:
		var raw_rows = []
		if candidate is Dictionary:
			raw_rows = candidate.get(
				"spells", candidate.get("rows", candidate.get("spell_rows", []))
			)
		elif candidate is Array:
			raw_rows = candidate
		if raw_rows is Array and not raw_rows.is_empty():
			var normalized := _normalize_spell_rows(raw_rows)
			if not normalized.is_empty():
				return normalized
	return []


func _normalize_spell_rows(raw_rows: Array) -> Array:
	var rows: Array = []
	for index in range(raw_rows.size()):
		var raw_row = raw_rows[index]
		var row: Dictionary = {}
		if raw_row is Dictionary:
			row = raw_row.duplicate(true)
		elif raw_row is int or raw_row is float:
			row = {"id": int(raw_row)}
		elif raw_row is String and raw_row.is_valid_int():
			row = {"id": int(raw_row)}
		else:
			continue
		if not row.has("id"):
			for key in ["spell_id", "spell", "entry", "spell_entry"]:
				if row.has(key):
					row["id"] = int(row.get(key, 0))
					break
		if int(row.get("id", 0)) <= 0:
			continue
		if not row.has("slot"):
			if row.has("slot_index"):
				row["slot"] = int(row.get("slot_index", index))
			elif row.has("index"):
				row["slot"] = int(row.get("index", index))
			else:
				row["slot"] = index
		rows.append(row)
	return rows


func _extract_action_slots(character: Dictionary, enter_result: Dictionary) -> Array:
	var candidates: Array = [
		character.get("action_buttons", {}),
		character.get("action_bar", {}),
		character.get("action_slots", []),
		enter_result.get("action_buttons", {}),
		enter_result.get("action_bar", {}),
		enter_result.get("action_slots", []),
		enter_result.get("buttons", []),
	]
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("action_buttons", {}))
		candidates.append(update.get("action_bar", {}))
		candidates.append(update.get("action_slots", []))

	for candidate in candidates:
		var raw_slots = []
		if candidate is Dictionary:
			raw_slots = candidate.get("buttons", candidate.get("slots", []))
		elif candidate is Array:
			raw_slots = candidate
		if raw_slots is Array and not raw_slots.is_empty():
			var normalized := _normalize_action_slots(raw_slots)
			if not normalized.is_empty():
				return normalized
	return []


func _normalize_action_slots(raw_slots: Array) -> Array:
	var slots: Array = []
	for raw_slot in raw_slots:
		if not raw_slot is Dictionary:
			continue
		var slot: Dictionary = raw_slot.duplicate(true)
		if not slot.has("button"):
			if slot.has("slot"):
				slot["button"] = int(slot.get("slot", -1))
			elif slot.has("index"):
				slot["button"] = int(slot.get("index", -1))
		if not slot.has("action") and slot.has("action_id"):
			slot["action"] = int(slot.get("action_id", 0))
		if not slot.has("type") and slot.has("action_type"):
			slot["type"] = int(slot.get("action_type", 0))
		if not slot.has("populated"):
			slot["populated"] = int(slot.get("action", 0)) > 0 or int(slot.get("type", -1)) >= 0
		slots.append(slot)
	return slots


func _extract_loot_snapshot(character: Dictionary, enter_result: Dictionary) -> Dictionary:
	var candidates: Array = [
		character.get("loot", {}),
		character.get("loot_window", {}),
		character.get("loot_response", {}),
		enter_result.get("loot", {}),
		enter_result.get("loot_window", {}),
		enter_result.get("loot_response", {}),
	]
	if _looks_like_loot_snapshot(character):
		candidates.append(character)
	if _looks_like_loot_snapshot(enter_result):
		candidates.append(enter_result)
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("loot", {}))
		candidates.append(update.get("loot_window", {}))
		candidates.append(update.get("loot_response", {}))
		if _looks_like_loot_snapshot(update):
			candidates.append(update)

	for candidate in candidates:
		if not candidate is Dictionary or candidate.is_empty():
			continue
		var snapshot := _normalize_loot_snapshot(candidate)
		if bool(snapshot.get("has_loot_data", false)):
			return snapshot
	return {}


func _looks_like_loot_snapshot(snapshot: Dictionary) -> bool:
	for key in [
		"loot_response_seen",
		"loot_release_response_seen",
		"loot_error",
		"gold",
		"loot_money",
		"loot_items",
		"items",
		"changed_slots",
		"loot_item_removed_count",
	]:
		if snapshot.has(key):
			return true
	return false


func _normalize_loot_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var raw_items = raw_snapshot.get(
		"items", raw_snapshot.get("loot_items", raw_snapshot.get("rows", []))
	)
	var items := _normalize_loot_items(raw_items if raw_items is Array else [])
	var raw_changed = raw_snapshot.get("changed_slots", raw_snapshot.get("inventory_changes", []))
	var changed_slots := _normalize_inventory_slots(raw_changed if raw_changed is Array else [])
	var money := -1
	for key in ["gold", "loot_money", "money", "coinage", "copper"]:
		if raw_snapshot.has(key):
			money = int(raw_snapshot.get(key, -1))
			break

	var status := "Loot snapshot: waiting for live loot response."
	if bool(raw_snapshot.get("loot_response_seen", false)):
		if bool(raw_snapshot.get("loot_error", false)):
			status = "Server denied loot: error " + str(raw_snapshot.get("loot_error_code", 0))
		else:
			status = "Loot window: open"
	elif bool(raw_snapshot.get("loot_release_response_seen", false)):
		status = "Loot window: closed by server"
	elif not items.is_empty() or not changed_slots.is_empty() or money >= 0:
		status = "Loot snapshot"

	var has_loot_data := (
		_looks_like_loot_snapshot(raw_snapshot)
		or not items.is_empty()
		or not changed_slots.is_empty()
		or money >= 0
	)
	return {
		"has_loot_data": has_loot_data,
		"status": status,
		"money": money,
		"items": items,
		"changed_slots": changed_slots,
		"target_guid": raw_snapshot.get("target_guid", raw_snapshot.get("guid", "")),
		"target_entry": raw_snapshot.get("target_entry", raw_snapshot.get("entry", 0)),
		"response_opcode": raw_snapshot.get("response_opcode", 0),
		"removed_count": raw_snapshot.get("loot_item_removed_count", 0),
	}


func _normalize_loot_items(raw_items: Array) -> Array:
	var items: Array = []
	for index in range(raw_items.size()):
		var raw_item = raw_items[index]
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item.duplicate(true)
		if not item.has("slot"):
			if item.has("loot_slot"):
				item["slot"] = int(item.get("loot_slot", index))
			elif item.has("index"):
				item["slot"] = int(item.get("index", index))
			else:
				item["slot"] = index
		if not item.has("item_id") and item.has("item_entry"):
			item["item_id"] = int(item.get("item_entry", 0))
		if not item.has("count") and item.has("stack_count"):
			item["count"] = int(item.get("stack_count", 0))
		if not item.has("count"):
			item["count"] = 1 if int(item.get("item_id", 0)) > 0 else 0
		items.append(item)
	return items


func _extract_vendor_snapshot(character: Dictionary, enter_result: Dictionary) -> Dictionary:
	var candidates: Array = [
		character.get("vendor", {}),
		character.get("vendor_list", {}),
		character.get("vendor_window", {}),
		enter_result.get("vendor", {}),
		enter_result.get("vendor_list", {}),
		enter_result.get("vendor_window", {}),
	]
	if _looks_like_vendor_snapshot(character):
		candidates.append(character)
	if _looks_like_vendor_snapshot(enter_result):
		candidates.append(enter_result)
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("vendor", {}))
		candidates.append(update.get("vendor_list", {}))
		candidates.append(update.get("vendor_window", {}))
		if _looks_like_vendor_snapshot(update):
			candidates.append(update)

	for candidate in candidates:
		if not candidate is Dictionary or candidate.is_empty():
			continue
		var snapshot := _normalize_vendor_snapshot(candidate)
		if bool(snapshot.get("has_vendor_data", false)):
			return snapshot
	return {}


func _looks_like_vendor_snapshot(snapshot: Dictionary) -> bool:
	for key in [
		"vendor_list_response_seen",
		"vendor_list",
		"vendor_items",
		"vendor_slot",
		"buy_response_seen",
		"roundtrip_confirmed",
		"bought_slot",
		"buy_coinage_delta",
	]:
		if snapshot.has(key):
			return true
	return false


func _normalize_vendor_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var nested = raw_snapshot.get("vendor_list", {})
	var raw_items = raw_snapshot.get("items", raw_snapshot.get("vendor_items", []))
	if raw_items is Array and raw_items.is_empty() and nested is Dictionary:
		raw_items = nested.get("items", [])
	var items: Array = _normalize_vendor_items(raw_items if raw_items is Array else [])
	var transaction: Dictionary = _normalize_vendor_transaction(raw_snapshot)
	var item_count := int(raw_snapshot.get("item_count", items.size()))
	if item_count == 0 and nested is Dictionary:
		item_count = int(nested.get("item_count", items.size()))
	var response_seen: bool = bool(
		raw_snapshot.get(
			"vendor_list_response_seen",
			(
				nested.get("parsed", not items.is_empty())
				if nested is Dictionary
				else not items.is_empty()
			)
		)
	)
	var has_vendor_data: bool = (
		_looks_like_vendor_snapshot(raw_snapshot)
		or response_seen
		or not items.is_empty()
		or not transaction.is_empty()
	)
	var target_guid: String = str(
		raw_snapshot.get("target_guid", raw_snapshot.get("vendor_guid", ""))
	)
	if str(target_guid).strip_edges().is_empty() and nested is Dictionary:
		target_guid = str(nested.get("vendor_guid", ""))
	return {
		"has_vendor_data": has_vendor_data,
		"response_seen": response_seen,
		"target_guid": target_guid,
		"target_entry": raw_snapshot.get("target_entry", raw_snapshot.get("entry", 0)),
		"target_name": raw_snapshot.get("target_name", raw_snapshot.get("name", "")),
		"response_opcode": raw_snapshot.get("response_opcode", 0),
		"item_count": item_count,
		"error_code": raw_snapshot.get("error_code", raw_snapshot.get("buy_failure_reason", 0)),
		"items": items,
		"transaction": transaction,
	}


func _normalize_vendor_items(raw_items: Array) -> Array:
	var items: Array = []
	for index in range(raw_items.size()):
		var raw_item = raw_items[index]
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item.duplicate(true)
		if not item.has("vendor_slot"):
			if item.has("slot"):
				item["vendor_slot"] = int(item.get("slot", index))
			elif item.has("index"):
				item["vendor_slot"] = int(item.get("index", index))
			else:
				item["vendor_slot"] = index
		if not item.has("item_id") and item.has("item_entry"):
			item["item_id"] = int(item.get("item_entry", 0))
		if not item.has("buy_price"):
			item["buy_price"] = int(item.get("price", 0))
		if not item.has("buy_count"):
			item["buy_count"] = int(item.get("count", 1))
		if not item.has("left_in_stock"):
			item["left_in_stock"] = int(item.get("stock", INFINITE_STOCK))
		items.append(item)
	return items


func _normalize_vendor_transaction(raw_snapshot: Dictionary) -> Dictionary:
	var transaction_keys := [
		"buy_response_seen",
		"buy_succeeded",
		"buy_failed",
		"sell_confirmed",
		"roundtrip_confirmed",
		"bought_slot",
		"buy_coinage_delta",
		"roundtrip_coinage_delta",
	]
	var has_transaction := false
	for key in transaction_keys:
		if raw_snapshot.has(key):
			has_transaction = true
			break
	if not has_transaction:
		return {}
	return {
		"buy_response_seen": raw_snapshot.get("buy_response_seen", false),
		"buy_succeeded": raw_snapshot.get("buy_succeeded", false),
		"buy_failed": raw_snapshot.get("buy_failed", false),
		"sell_confirmed": raw_snapshot.get("sell_confirmed", false),
		"roundtrip_confirmed": raw_snapshot.get("roundtrip_confirmed", false),
		"bought_slot": raw_snapshot.get("bought_slot", 0),
		"before_coinage": raw_snapshot.get("before_coinage", 0),
		"after_buy_coinage": raw_snapshot.get("after_buy_coinage", 0),
		"after_sell_coinage": raw_snapshot.get("after_sell_coinage", 0),
		"buy_coinage_delta": raw_snapshot.get("buy_coinage_delta", 0),
		"sell_coinage_delta": raw_snapshot.get("sell_coinage_delta", 0),
		"roundtrip_coinage_delta": raw_snapshot.get("roundtrip_coinage_delta", 0),
		"bought_slot_before": raw_snapshot.get("bought_slot_before", {}),
		"bought_slot_after_buy": raw_snapshot.get("bought_slot_after_buy", {}),
		"bought_slot_after_sell": raw_snapshot.get("bought_slot_after_sell", {}),
	}


func _extract_trainer_snapshot(character: Dictionary, enter_result: Dictionary) -> Dictionary:
	var candidates: Array = [
		character.get("trainer", {}),
		character.get("trainer_list", {}),
		character.get("trainer_window", {}),
		enter_result.get("trainer", {}),
		enter_result.get("trainer_list", {}),
		enter_result.get("trainer_window", {}),
	]
	if _looks_like_trainer_snapshot(character):
		candidates.append(character)
	if _looks_like_trainer_snapshot(enter_result):
		candidates.append(enter_result)
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("trainer", {}))
		candidates.append(update.get("trainer_list", {}))
		candidates.append(update.get("trainer_window", {}))
		if _looks_like_trainer_snapshot(update):
			candidates.append(update)

	for candidate in candidates:
		if not candidate is Dictionary or candidate.is_empty():
			continue
		var snapshot := _normalize_trainer_snapshot(candidate)
		if bool(snapshot.get("has_trainer_data", false)):
			return snapshot
	return {}


func _looks_like_trainer_snapshot(snapshot: Dictionary) -> bool:
	for key in [
		"trainer_list_response_seen",
		"trainer_list",
		"trainer_spells",
		"trainer_type",
		"spell_count",
		"buy_response_seen",
		"failure_reason",
		"spell_known_after",
		"coinage_delta",
	]:
		if snapshot.has(key):
			return true
	return false


func _normalize_trainer_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var nested = raw_snapshot.get("trainer_list", {})
	var raw_spells = raw_snapshot.get("spells", raw_snapshot.get("trainer_spells", []))
	if raw_spells is Array and raw_spells.is_empty() and nested is Dictionary:
		raw_spells = nested.get("spells", [])
	var spells: Array = _normalize_trainer_spells(raw_spells if raw_spells is Array else [])
	var learn_result: Dictionary = _normalize_trainer_learn_result(raw_snapshot)
	var spell_count := int(raw_snapshot.get("spell_count", spells.size()))
	if spell_count == 0 and nested is Dictionary:
		spell_count = int(nested.get("spell_count", spells.size()))
	var response_seen: bool = bool(
		raw_snapshot.get(
			"trainer_list_response_seen",
			(
				nested.get("parsed", not spells.is_empty())
				if nested is Dictionary
				else not spells.is_empty()
			)
		)
	)
	var has_trainer_data: bool = (
		_looks_like_trainer_snapshot(raw_snapshot)
		or response_seen
		or not spells.is_empty()
		or not learn_result.is_empty()
	)
	var target_guid: String = str(
		raw_snapshot.get("target_guid", raw_snapshot.get("trainer_guid", ""))
	)
	if target_guid.strip_edges().is_empty() and nested is Dictionary:
		target_guid = str(nested.get("trainer_guid", ""))
	return {
		"has_trainer_data": has_trainer_data,
		"response_seen": response_seen,
		"target_guid": target_guid,
		"target_entry": raw_snapshot.get("target_entry", raw_snapshot.get("entry", 0)),
		"target_name": raw_snapshot.get("target_name", raw_snapshot.get("name", "")),
		"response_opcode": raw_snapshot.get("response_opcode", 0),
		"trainer_type":
		raw_snapshot.get(
			"trainer_type", nested.get("trainer_type", 0) if nested is Dictionary else 0
		),
		"greeting": raw_snapshot.get("greeting", ""),
		"spell_count": spell_count,
		"spells": spells,
		"learn_result": learn_result,
	}


func _normalize_trainer_spells(raw_spells: Array) -> Array:
	var spells: Array = []
	for index in range(raw_spells.size()):
		var raw_spell = raw_spells[index]
		if not raw_spell is Dictionary:
			continue
		var spell: Dictionary = raw_spell.duplicate(true)
		if not spell.has("spell_id"):
			for key in ["id", "spell", "spell_entry"]:
				if spell.has(key):
					spell["spell_id"] = int(spell.get(key, 0))
					break
		if int(spell.get("spell_id", 0)) <= 0:
			continue
		if not spell.has("index"):
			spell["index"] = index
		if not spell.has("money_cost"):
			spell["money_cost"] = int(spell.get("cost", 0))
		if not spell.has("usable"):
			spell["usable"] = int(spell.get("state", 0))
		spells.append(spell)
	return spells


func _normalize_trainer_learn_result(raw_snapshot: Dictionary) -> Dictionary:
	var learn_keys := [
		"buy_response_seen",
		"buy_succeeded",
		"buy_failed",
		"failure_reason",
		"spell_known_before",
		"spell_known_after",
		"coinage_delta",
	]
	var has_learn_result := false
	for key in learn_keys:
		if raw_snapshot.has(key):
			has_learn_result = true
			break
	if not has_learn_result:
		return {}
	return {
		"buy_response_seen": raw_snapshot.get("buy_response_seen", false),
		"buy_succeeded": raw_snapshot.get("buy_succeeded", false),
		"buy_failed": raw_snapshot.get("buy_failed", false),
		"failure_reason": raw_snapshot.get("failure_reason", 0),
		"spell_id": raw_snapshot.get("spell_id", 0),
		"spell_known_before": raw_snapshot.get("spell_known_before", false),
		"spell_known_after": raw_snapshot.get("spell_known_after", false),
		"before_coinage": raw_snapshot.get("before_coinage", 0),
		"after_coinage": raw_snapshot.get("after_coinage", 0),
		"coinage_delta": raw_snapshot.get("coinage_delta", 0),
		"response_opcode": raw_snapshot.get("response_opcode", 0),
	}


func _extract_social_snapshot(character: Dictionary, enter_result: Dictionary) -> Dictionary:
	var candidates: Array = [
		character.get("social", {}),
		character.get("friends", {}),
		character.get("party", {}),
		character.get("group", {}),
		character.get("guild", {}),
		enter_result.get("social", {}),
		enter_result.get("friends", {}),
		enter_result.get("party", {}),
		enter_result.get("group", {}),
		enter_result.get("guild", {}),
	]
	if _looks_like_social_snapshot(character):
		candidates.append(character)
	if _looks_like_social_snapshot(enter_result):
		candidates.append(enter_result)
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("social", {}))
		candidates.append(update.get("friends", {}))
		candidates.append(update.get("party", {}))
		candidates.append(update.get("group", {}))
		candidates.append(update.get("guild", {}))
		if _looks_like_social_snapshot(update):
			candidates.append(update)

	for candidate in candidates:
		if not candidate is Dictionary or candidate.is_empty():
			continue
		var snapshot := _normalize_social_snapshot(candidate)
		if bool(snapshot.get("has_social_data", false)):
			return snapshot
	return {}


func _looks_like_social_snapshot(snapshot: Dictionary) -> bool:
	for key in [
		"friends",
		"friend_rows",
		"ignore",
		"ignore_rows",
		"party",
		"group",
		"party_members",
		"group_members",
		"guild",
		"guild_members",
		"invites",
		"pending_invites",
	]:
		if snapshot.has(key):
			return true
	return false


func _normalize_social_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var friends_raw = _social_raw_rows(raw_snapshot, ["friends", "friend_rows"], "friends")
	var ignore_raw = _social_raw_rows(raw_snapshot, ["ignore", "ignore_rows", "ignored"], "ignore")
	var party_raw = _social_raw_rows(
		raw_snapshot, ["party_members", "group_members", "members"], "party"
	)
	var guild_raw = _social_raw_rows(raw_snapshot, ["guild_members", "members"], "guild")
	var invites_raw = _social_raw_rows(raw_snapshot, ["invites", "pending_invites"], "invites")
	var friends: Array = _normalize_social_rows(friends_raw, "friend")
	var ignores: Array = _normalize_social_rows(ignore_raw, "ignore")
	var party: Array = _normalize_social_rows(party_raw, "party")
	var guild: Array = _normalize_social_rows(guild_raw, "guild")
	var invites: Array = _normalize_social_rows(invites_raw, "invite")
	var has_social_data: bool = (
		_looks_like_social_snapshot(raw_snapshot)
		or not friends.is_empty()
		or not ignores.is_empty()
		or not party.is_empty()
		or not guild.is_empty()
		or not invites.is_empty()
	)
	return {
		"has_social_data": has_social_data,
		"friends": friends,
		"ignore": ignores,
		"party": party,
		"guild": guild,
		"invites": invites,
		"guild_name": _social_group_name(raw_snapshot, "guild", "guild_name"),
		"party_leader": _social_group_name(raw_snapshot, "party", "leader"),
	}


func _social_raw_rows(snapshot: Dictionary, keys: Array, nested_key: String) -> Array:
	for key in keys:
		var value: Variant = snapshot.get(key, null)
		if value is Array:
			return value
		if value is Dictionary:
			for row_key in ["rows", "members", "entries", nested_key]:
				if not value.has(row_key):
					continue
				var rows: Variant = value.get(row_key, [])
				if rows is Array:
					return rows
	var nested: Variant = snapshot.get(nested_key, {})
	if nested is Dictionary:
		for row_key in ["rows", "members", "entries"]:
			if not nested.has(row_key):
				continue
			var rows: Variant = nested.get(row_key, [])
			if rows is Array:
				return rows
	return []


func _normalize_social_rows(raw_rows: Array, row_kind: String) -> Array:
	var rows: Array = []
	for index in range(raw_rows.size()):
		var raw_row = raw_rows[index]
		var row: Dictionary = {}
		if raw_row is Dictionary:
			row = raw_row.duplicate(true)
		elif raw_row is String:
			row = {"name": raw_row}
		else:
			continue
		var name := _social_row_name(row)
		if name.is_empty():
			continue
		row["name"] = name
		row["kind"] = row_kind
		if not row.has("index"):
			row["index"] = index
		rows.append(row)
	return rows


func _social_row_name(row: Dictionary) -> String:
	for key in ["name", "character_name", "player", "member", "account", "guid"]:
		var value := str(row.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _social_group_name(snapshot: Dictionary, key: String, field: String) -> String:
	var nested: Variant = snapshot.get(key, {})
	if nested is Dictionary:
		var nested_value := str(nested.get(field, "")).strip_edges()
		if not nested_value.is_empty():
			return nested_value
	return str(snapshot.get(field, "")).strip_edges()


func _extract_mail_snapshot(character: Dictionary, enter_result: Dictionary) -> Dictionary:
	var candidates: Array = [
		character.get("mail", {}),
		character.get("mailbox", {}),
		character.get("mail_list", {}),
		enter_result.get("mail", {}),
		enter_result.get("mailbox", {}),
		enter_result.get("mail_list", {}),
	]
	if _looks_like_mail_snapshot(character):
		candidates.append(character)
	if _looks_like_mail_snapshot(enter_result):
		candidates.append(enter_result)
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("mail", {}))
		candidates.append(update.get("mailbox", {}))
		candidates.append(update.get("mail_list", {}))
		if _looks_like_mail_snapshot(update):
			candidates.append(update)

	for candidate in candidates:
		if not candidate is Dictionary or candidate.is_empty():
			continue
		var snapshot := _normalize_mail_snapshot(candidate)
		if bool(snapshot.get("has_mail_data", false)):
			return snapshot
	return {}


func _looks_like_mail_snapshot(snapshot: Dictionary) -> bool:
	for key in [
		"mail",
		"mailbox",
		"mail_list",
		"mail_rows",
		"messages",
		"attachments",
		"money",
		"cod",
		"unread_count",
		"mail_count",
	]:
		if snapshot.has(key):
			return true
	return false


func _normalize_mail_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var source := raw_snapshot
	for nested_key in ["mail", "mailbox", "mail_list"]:
		var nested: Variant = raw_snapshot.get(nested_key, {})
		if nested is Dictionary and _looks_like_mail_snapshot(nested):
			source = nested
			break
	var raw_rows = source.get(
		"messages", source.get("mail_rows", source.get("rows", source.get("items", [])))
	)
	var messages := _normalize_mail_rows(raw_rows if raw_rows is Array else [])
	var unread_count := int(source.get("unread_count", -1))
	if unread_count < 0:
		unread_count = 0
		for message in messages:
			if message is Dictionary and not bool(message.get("read", false)):
				unread_count += 1
	var message_count := int(source.get("mail_count", source.get("message_count", messages.size())))
	var money_total := 0
	var cod_total := 0
	for message in messages:
		if message is Dictionary:
			money_total += int(message.get("money", 0))
			cod_total += int(message.get("cod", 0))
	var has_mail_data := _looks_like_mail_snapshot(source) or not messages.is_empty()
	return {
		"has_mail_data": has_mail_data,
		"messages": messages,
		"message_count": message_count,
		"unread_count": unread_count,
		"money_total": money_total,
		"cod_total": cod_total,
		"mailbox_guid": source.get("mailbox_guid", source.get("guid", "")),
		"response_opcode": source.get("response_opcode", 0),
	}


func _normalize_mail_rows(raw_rows: Array) -> Array:
	var rows: Array = []
	for index in range(raw_rows.size()):
		var raw_row = raw_rows[index]
		var row: Dictionary = {}
		if raw_row is Dictionary:
			row = raw_row.duplicate(true)
		elif raw_row is String:
			row = {"subject": raw_row}
		else:
			continue
		if not row.has("id"):
			row["id"] = _mail_value(row, ["mail_id", "message_id", "mailbox_id", "guid"], index)
		if not row.has("sender"):
			row["sender"] = _mail_value(row, ["from", "sender_name", "sender_guid"], "Unknown")
		if not row.has("subject"):
			row["subject"] = _mail_value(
				row, ["title", "headline"], "Mail " + str(row.get("id", index))
			)
		if not row.has("body_preview"):
			var body_text := str(_mail_value(row, ["preview", "body", "text"], "")).strip_edges()
			row["body_preview"] = body_text.left(96)
		if not row.has("money"):
			row["money"] = int(_mail_value(row, ["cash", "copper", "coinage"], 0))
		if not row.has("cod"):
			row["cod"] = int(_mail_value(row, ["cod_amount", "cash_on_delivery"], 0))
		if not row.has("read"):
			if row.has("unread"):
				row["read"] = not bool(row.get("unread", false))
			else:
				row["read"] = bool(row.get("is_read", false))
		if not row.has("expire_time"):
			row["expire_time"] = _mail_value(row, ["expires", "expiration", "expire"], "")
		var raw_attachments = _mail_value(row, ["attachments", "items", "attachment_items"], [])
		row["attachments"] = _normalize_mail_attachments(
			raw_attachments if raw_attachments is Array else []
		)
		rows.append(row)
	return rows


func _normalize_mail_attachments(raw_attachments: Array) -> Array:
	var attachments: Array = []
	for index in range(raw_attachments.size()):
		var raw_attachment = raw_attachments[index]
		var attachment: Dictionary = {}
		if raw_attachment is Dictionary:
			attachment = raw_attachment.duplicate(true)
		elif raw_attachment is String:
			attachment = {"name": raw_attachment}
		else:
			continue
		if not attachment.has("slot"):
			attachment["slot"] = int(attachment.get("index", index))
		if not attachment.has("item_id"):
			attachment["item_id"] = int(_mail_value(attachment, ["item_entry", "entry", "id"], 0))
		if not attachment.has("count"):
			attachment["count"] = int(_mail_value(attachment, ["stack_count", "quantity"], 1))
		if not attachment.has("name"):
			var item_id := int(attachment.get("item_id", 0))
			attachment["name"] = "item " + str(item_id) if item_id > 0 else "attachment"
		attachments.append(attachment)
	return attachments


func _mail_value(row: Dictionary, keys: Array, fallback: Variant = null) -> Variant:
	for key in keys:
		if row.has(key):
			return row.get(key)
	return fallback


func _extract_inventory_slots(character: Dictionary, enter_result: Dictionary) -> Array:
	var candidates := [
		character.get("inventory", {}),
		enter_result.get("inventory", {}),
		enter_result.get("inventory_after", {}),
		enter_result.get("inventory_snapshot", {}),
		enter_result.get("after_inventory", {}),
		(
			enter_result.get("update", {}).get("inventory", {})
			if enter_result.get("update", {}) is Dictionary
			else {}
		),
		enter_result.get("slots", []),
	]
	for candidate in candidates:
		if candidate is Dictionary:
			var slots = candidate.get("slots", [])
			if slots is Array and not slots.is_empty():
				return _normalize_inventory_slots(slots)
		elif candidate is Array and not candidate.is_empty():
			return _normalize_inventory_slots(candidate)
	return []


func _extract_coinage(character: Dictionary, enter_result: Dictionary) -> int:
	var candidates := [
		character,
		enter_result,
		character.get("inventory", {}),
		enter_result.get("inventory", {}),
		enter_result.get("inventory_after", {}),
		enter_result.get("inventory_snapshot", {}),
		enter_result.get("after_inventory", {}),
	]
	for candidate in candidates:
		if not candidate is Dictionary:
			continue
		for key in ["coinage", "money", "copper"]:
			if candidate.has(key):
				return int(candidate.get(key, -1))
	return -1


func _extract_quest_slots(character: Dictionary, enter_result: Dictionary) -> Array:
	var candidates: Array = [
		character.get("quest_log", {}),
		character.get("quest_log_snapshot", {}),
		character.get("quests", {}),
		enter_result.get("quest_log", {}),
		enter_result.get("quest_log_snapshot", {}),
		enter_result.get("quest_slots", []),
	]
	var update = enter_result.get("update", {})
	if update is Dictionary:
		candidates.append(update.get("quest_log", {}))
		candidates.append(update.get("quest_log_snapshot", {}))
		candidates.append(update.get("quest_slots", []))

	for candidate in candidates:
		var raw_slots = []
		if candidate is Dictionary:
			raw_slots = candidate.get("slots", candidate.get("quest_slots", []))
		elif candidate is Array:
			raw_slots = candidate
		if raw_slots is Array and not raw_slots.is_empty():
			var normalized := _normalize_quest_slots(raw_slots)
			if not normalized.is_empty():
				return normalized
	return []


func _normalize_quest_slots(raw_slots: Array) -> Array:
	var slots: Array = []
	for raw_slot in raw_slots:
		if not raw_slot is Dictionary:
			continue
		if not _looks_like_quest_slot(raw_slot):
			continue
		var slot: Dictionary = raw_slot.duplicate(true)
		if not slot.has("slot"):
			if slot.has("slot_index"):
				slot["slot"] = int(slot.get("slot_index", -1))
			elif slot.has("index"):
				slot["slot"] = int(slot.get("index", -1))
		if not slot.has("quest_id"):
			for key in ["quest", "quest_entry", "entry", "id"]:
				if slot.has(key):
					slot["quest_id"] = int(slot.get(key, 0))
					break
		if not slot.has("quest_id"):
			slot["quest_id"] = 0
		if not slot.has("active"):
			slot["active"] = int(slot.get("quest_id", 0)) > 0
		slots.append(slot)
	return slots


func _looks_like_quest_slot(slot: Dictionary) -> bool:
	for key in [
		"quest_id",
		"quest",
		"quest_entry",
		"state_flags",
		"status_flags",
		"timer",
		"time_left",
		"objective_1",
		"objective_2",
		"objective_3",
		"objective_4",
		"counter_1",
		"counter_2",
		"counter_3",
		"counter_4",
		"objectives",
	]:
		if slot.has(key):
			return true
	return false


func _normalize_inventory_slots(raw_slots: Array) -> Array:
	var slots: Array = []
	for raw_slot in raw_slots:
		if not raw_slot is Dictionary:
			continue
		var slot: Dictionary = raw_slot.duplicate(true)
		if not slot.has("slot") and slot.has("slot_index"):
			slot["slot"] = int(slot.get("slot_index", -1))
		if not slot.has("populated"):
			var item_name := str(slot.get("item_name", "")).strip_edges()
			var item_guid := str(slot.get("item_guid", "0x0")).strip_edges()
			slot["populated"] = (
				not item_name.is_empty()
				or int(slot.get("item_entry", 0)) > 0
				or (not item_guid.is_empty() and item_guid != "0x0" and item_guid != "0")
			)
		slots.append(slot)
	return slots


func _update_camera_input(delta: float) -> void:
	if Input.is_action_pressed("camera_left"):
		camera_yaw += 1.8 * delta
	if Input.is_action_pressed("camera_right"):
		camera_yaw -= 1.8 * delta


func _update_marker_movement(_delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input.z += 1.0
	if Input.is_action_pressed("move_left"):
		input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input.x += 1.0

	var direction := Vector3.ZERO
	if input.length() > 0.0:
		var basis := Basis(Vector3.UP, camera_yaw)
		direction = (basis * input).normalized()
	marker_velocity.x = direction.x * MARKER_MOVE_SPEED
	marker_velocity.z = direction.z * MARKER_MOVE_SPEED
	player_marker.velocity = marker_velocity
	player_marker.move_and_slide()
	_sync_target_marker()


func _update_key_actions() -> void:
	var target_pressed := Input.is_action_pressed("target_next")
	if target_pressed and not target_was_pressed:
		_select_next_target()
	target_was_pressed = target_pressed

	var attack_pressed := Input.is_action_pressed("attack_primary")
	if attack_pressed and not attack_was_pressed:
		_queue_primary_action()
	attack_was_pressed = attack_pressed

	var interact_pressed := Input.is_action_pressed("interact")
	if interact_pressed and not interact_was_pressed:
		_queue_interact()
	interact_was_pressed = interact_pressed

	var reset_pressed := Input.is_action_pressed("reset_sandbox")
	if reset_pressed and not reset_was_pressed:
		_reset_marker_to_session()
	reset_was_pressed = reset_pressed

	var jump_pressed := Input.is_action_pressed("jump")
	if jump_pressed and not jump_was_pressed:
		_queue_jump()
	jump_was_pressed = jump_pressed


func _select_next_target() -> void:
	if visible_object_count <= 0:
		selected_target_index = -1
		status_label.text = "Targeting is waiting for a live visible-object snapshot."
		_refresh_target_label()
		return

	selected_target_index = (selected_target_index + 1) % visible_object_count
	status_label.text = "Target selected from the latest world-session snapshot."
	_refresh_target_label()


func _select_target_index(index: int) -> void:
	if index < 0 or index >= visible_object_count:
		selected_target_index = -1
		status_label.text = "Target selection cleared."
	else:
		selected_target_index = index
		status_label.text = "Target selected from the visible-object snapshot."
	_refresh_target_label()


func _queue_primary_action() -> void:
	if selected_target_index < 0:
		status_label.text = (
			"Primary action queued; select a visible target when live targeting is attached."
		)
		return
	status_label.text = (
		"Primary action queued for target %s; combat execution waits for the persistent live session."
		% str(selected_target_index + 1)
	)


func _queue_interact() -> void:
	if selected_target_index < 0:
		quest_label.text = "Interaction queued; live NPC/gameobject selection is not attached yet."
		return
	quest_label.text = (
		"Interaction queued for target %s; NPC panels will attach here after the live click bridge lands."
		% str(selected_target_index + 1)
	)


func _reset_marker_to_session() -> void:
	player_marker.position = authoritative_marker_position
	player_marker.velocity = Vector3.ZERO
	marker_velocity = Vector3.ZERO
	_sync_target_marker()
	status_label.text = "Marker returned to the last server-reported position."
	_update_camera()


func _queue_jump() -> void:
	status_label.text = (
		"Jump input received; server-synchronized vertical movement remains a live-session task."
	)


func _refresh_target_label() -> void:
	if visible_object_count <= 0:
		target_label.text = "Visible objects: 0. Target cycling is waiting for the live object stream."
		_refresh_target_frame()
		return
	if selected_target_index < 0:
		target_label.text = (
			"Visible objects: %s. Press the saved target key to cycle the snapshot."
			% str(visible_object_count)
		)
		_refresh_target_frame()
		return
	var target := _visible_object_at(selected_target_index)
	target_label.text = (
		"Target %s of %s selected: %s."
		% [
			str(selected_target_index + 1),
			str(visible_object_count),
			_target_summary(target, selected_target_index),
		]
	)
	_refresh_target_frame()


func _sync_target_marker() -> void:
	target_marker.position = Vector3(player_marker.position.x, 0.04, player_marker.position.z)


func _update_camera() -> void:
	if camera == null or player_marker == null:
		return
	var offset := Vector3(0, 24, 44).rotated(Vector3.UP, camera_yaw)
	camera.position = player_marker.position + offset
	camera.look_at(player_marker.position + Vector3(0, 3.0, 0), Vector3.UP)


func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-GRID_EXTENT, GRID_EXTENT + 1, GRID_STEP):
		var strong := i == 0
		mesh.surface_set_color(Color(0.46, 0.50, 0.54) if strong else Color(0.24, 0.29, 0.32))
		mesh.surface_add_vertex(Vector3(i, 0, -GRID_EXTENT))
		mesh.surface_add_vertex(Vector3(i, 0, GRID_EXTENT))
		mesh.surface_add_vertex(Vector3(-GRID_EXTENT, 0, i))
		mesh.surface_add_vertex(Vector3(GRID_EXTENT, 0, i))

	mesh.surface_set_color(Color(0.9, 0.18, 0.16))
	mesh.surface_add_vertex(Vector3(-GRID_EXTENT, 0.06, 0))
	mesh.surface_add_vertex(Vector3(GRID_EXTENT, 0.06, 0))
	mesh.surface_set_color(Color(0.16, 0.62, 0.96))
	mesh.surface_add_vertex(Vector3(0, 0.08, -GRID_EXTENT))
	mesh.surface_add_vertex(Vector3(0, 0.08, GRID_EXTENT))
	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	grid.material_override = material
	add_child(grid)


func _add_axis_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _bar(label_text: String, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, 18)
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	bar.tooltip_text = label_text
	return bar


func _hud_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.92, 0.95, 0.94)
	return label


func _build_panel_shell(parent: CanvasLayer) -> void:
	panel_overlay = Control.new()
	panel_overlay.name = "SessionPanelOverlay"
	panel_overlay.anchor_right = 1.0
	panel_overlay.anchor_bottom = 1.0
	panel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel_overlay)

	for i in range(PANEL_NAMES.size()):
		_create_session_panel(PANEL_NAMES[i], i)
	_load_panel_layout()
	_activate_panel("chat")


func _create_session_panel(panel_name: String, index: int) -> void:
	var shell := PanelContainer.new()
	shell.name = "SessionPanel" + panel_name.capitalize()
	shell.visible = false
	shell.custom_minimum_size = PANEL_MIN_SIZE
	shell.size = PANEL_DEFAULT_SIZE
	shell.position = _default_panel_position(panel_name)
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.052, 0.058, 0.88)
	panel_style.border_color = Color(0.28, 0.34, 0.36, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	shell.add_theme_stylebox_override("panel", panel_style)
	panel_overlay.add_child(shell)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	shell.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_panel_header_gui_input.bind(panel_name))
	stack.add_child(header)

	var title_label := _panel_label(_panel_title(panel_name), 17)
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.gui_input.connect(_on_panel_header_gui_input.bind(panel_name))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(Callable(self, "_hide_session_panel").bind(panel_name))
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 80.0)
	stack.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	stack.add_child(footer)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	var resize_button := Button.new()
	resize_button.text = "Resize"
	resize_button.tooltip_text = "Drag to resize"
	resize_button.custom_minimum_size = Vector2(78, 28)
	resize_button.mouse_filter = Control.MOUSE_FILTER_STOP
	resize_button.gui_input.connect(_on_panel_resize_gui_input.bind(panel_name))
	footer.add_child(resize_button)

	session_panels[panel_name] = {
		"shell": shell,
		"title": title_label,
		"body": body,
		"scroll": scroll,
		"resize": resize_button,
		"index": index,
	}


func _activate_panel(panel_name: String) -> bool:
	var info: Dictionary = session_panels.get(panel_name, {})
	if info.is_empty():
		return false
	panel_shell = info.get("shell", null)
	panel_title_label = info.get("title", null)
	panel_body = info.get("body", null)
	active_panel_name = panel_name
	return panel_shell != null and panel_title_label != null and panel_body != null


func _panel_shell(panel_name: String) -> PanelContainer:
	var info: Dictionary = session_panels.get(panel_name, {})
	if info.is_empty():
		return null
	return info.get("shell", null)


func _panel_title(panel_name: String) -> String:
	return str(PANEL_TITLES.get(panel_name, "Session Panel"))


func _default_panel_position(panel_name: String) -> Vector2:
	var index := PANEL_NAMES.find(panel_name)
	if index < 0:
		index = 0
	return PANEL_DEFAULT_POSITION + Vector2(index * 34.0, index * 28.0)


func _layout_section(panel_name: String) -> String:
	return "SessionPanel:" + panel_name


func _build_shortcut_slots(parent: Control) -> void:
	shortcut_slots.clear()
	_add_shortcut_slot(parent, "1", "Primary", Callable(self, "_queue_primary_action"))
	_add_shortcut_slot(parent, "2", "Interact", Callable(self, "_queue_interact"))
	_add_shortcut_slot(parent, "3", "Target", Callable(self, "_select_next_target"))
	_add_shortcut_slot(parent, "4", "Spells", Callable(self, "_show_session_panel").bind("spells"))
	_add_shortcut_slot(
		parent, "5", "Actions", Callable(self, "_show_session_panel").bind("actions")
	)
	_add_shortcut_slot(parent, "6", "Quests", Callable(self, "_show_session_panel").bind("quests"))
	_add_shortcut_slot(parent, "7", "Chat", Callable(self, "_show_session_panel").bind("chat"))
	_add_shortcut_slot(
		parent, "8", "Options", Callable(self, "_show_session_panel").bind("options")
	)
	_add_shortcut_slot(parent, "9", "Reset", Callable(self, "_reset_marker_to_session"))
	_add_shortcut_slot(parent, "0", "Jump", Callable(self, "_queue_jump"))
	_add_shortcut_slot(parent, "-", "Bag", Callable(self, "_show_session_panel").bind("inventory"))
	_add_shortcut_slot(parent, "=", "Map", Callable(self, "_show_session_panel").bind("map"))


func _add_shortcut_slot(
	parent: Control, key_text: String, label_text: String, action: Callable
) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [key_text, label_text]
	button.tooltip_text = label_text
	button.custom_minimum_size = Vector2(72, 50)
	button.pressed.connect(action)
	parent.add_child(button)
	shortcut_slots.append(button)


func _refresh_shortcut_slots() -> void:
	for index in range(shortcut_slots.size()):
		var button := shortcut_slots[index]
		if index < ACTION_BAR_DISPLAY_COUNT:
			var slot := _action_slot_at(index)
			if not slot.is_empty():
				var key_text: String = (
					ACTION_BAR_KEYS[index] if index < ACTION_BAR_KEYS.size() else str(index)
				)
				button.text = "%s\n%s" % [key_text, _action_slot_label(slot)]
			button.tooltip_text = _action_slot_detail(slot)


func _add_panel_button(parent: Control, label_text: String, panel_name: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104, 36)
	button.pressed.connect(func(): _show_session_panel(panel_name))
	parent.add_child(button)
	action_buttons.append(button)


func _add_scene_button(parent: Control, label_text: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104, 36)
	button.pressed.connect(func(): _open_scene(scene_path))
	parent.add_child(button)
	action_buttons.append(button)


func _show_session_panel(panel_name: String) -> void:
	if not _activate_panel(panel_name):
		return
	_clear_panel_body()
	panel_shell.visible = true
	panel_shell.move_to_front()
	match panel_name:
		"chat":
			_build_chat_panel()
		"character":
			_build_character_panel()
		"spells":
			_build_spells_panel()
		"actions":
			_build_actions_panel()
		"targets":
			_build_targets_panel()
		"auras":
			_build_auras_panel()
		"quests":
			_build_quests_panel()
		"loot":
			_build_loot_panel()
		"vendor":
			_build_vendor_panel()
		"trainer":
			_build_trainer_panel()
		"social":
			_build_social_panel()
		"mail":
			_build_mail_panel()
		"map":
			_build_map_panel()
		"inventory":
			_build_inventory_panel()
		"options":
			_build_options_panel()
		_:
			panel_title_label.text = "Session Panel"
			panel_body.add_child(_panel_label("No panel is registered for " + panel_name + ".", 14))
	_set_panel_size(panel_name, panel_shell.size)
	_set_panel_position(panel_name, panel_shell.position)


func _hide_session_panel(panel_name: String = "") -> void:
	var target_name := active_panel_name if panel_name.is_empty() else panel_name
	var shell := _panel_shell(target_name)
	if shell != null:
		shell.visible = false


func _on_panel_header_gui_input(event: InputEvent, panel_name: String) -> void:
	var shell := _panel_shell(panel_name)
	if shell == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			panel_dragging_name = panel_name
			panel_drag_offset = shell.get_global_mouse_position() - shell.global_position
			shell.z_index = 50
			_activate_panel(panel_name)
			shell.move_to_front()
		elif panel_dragging_name == panel_name:
			panel_dragging_name = ""
			shell.z_index = 0
			_set_panel_position(panel_name, shell.position, true)
			_save_panel_layout()
	elif event is InputEventMouseMotion and panel_dragging_name == panel_name:
		var next_position := shell.get_global_mouse_position() - panel_drag_offset
		_set_panel_position(panel_name, next_position)


func _on_panel_resize_gui_input(event: InputEvent, panel_name: String) -> void:
	var shell := _panel_shell(panel_name)
	if shell == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			panel_resizing_name = panel_name
			panel_resize_start_mouse = shell.get_global_mouse_position()
			panel_resize_start_size = shell.size
			shell.z_index = 50
			_activate_panel(panel_name)
			shell.move_to_front()
		elif panel_resizing_name == panel_name:
			panel_resizing_name = ""
			shell.z_index = 0
			_set_panel_size(panel_name, shell.size, true)
			_set_panel_position(panel_name, shell.position)
			_save_panel_layout()
	elif event is InputEventMouseMotion and panel_resizing_name == panel_name:
		var delta := shell.get_global_mouse_position() - panel_resize_start_mouse
		_set_panel_size(panel_name, panel_resize_start_size + delta)
		_set_panel_position(panel_name, shell.position)


func _set_panel_position(
	panel_name: String, next_position: Vector2, snap_to_grid: bool = false
) -> void:
	var shell := _panel_shell(panel_name)
	if shell == null:
		return
	var target := next_position
	if snap_to_grid:
		target = Vector2(snapped(target.x, PANEL_DRAG_GRID), snapped(target.y, PANEL_DRAG_GRID))
	shell.position = _clamp_panel_position(panel_name, target)


func _set_panel_size(panel_name: String, next_size: Vector2, snap_to_grid: bool = false) -> void:
	var shell := _panel_shell(panel_name)
	if shell == null:
		return
	var target := next_size
	if snap_to_grid:
		target = Vector2(snapped(target.x, PANEL_DRAG_GRID), snapped(target.y, PANEL_DRAG_GRID))
	shell.size = _clamp_panel_size(panel_name, target)


func _clamp_panel_position(panel_name: String, next_position: Vector2) -> Vector2:
	var viewport_size := _layout_viewport_size()
	var panel_size := _panel_layout_size(panel_name)
	var max_x: float = max(0.0, viewport_size.x - panel_size.x - 12.0)
	var max_y: float = max(0.0, viewport_size.y - panel_size.y - 12.0)
	return Vector2(clamp(next_position.x, 0.0, max_x), clamp(next_position.y, 0.0, max_y))


func _clamp_panel_size(panel_name: String, next_size: Vector2) -> Vector2:
	var shell := _panel_shell(panel_name)
	var position := shell.position if shell != null else Vector2.ZERO
	var viewport_size := _layout_viewport_size()
	var max_width: float = min(
		PANEL_MAX_SIZE.x, max(PANEL_MIN_SIZE.x, viewport_size.x - position.x - 12.0)
	)
	var max_height: float = min(
		PANEL_MAX_SIZE.y, max(PANEL_MIN_SIZE.y, viewport_size.y - position.y - 12.0)
	)
	return Vector2(
		clamp(next_size.x, PANEL_MIN_SIZE.x, max_width),
		clamp(next_size.y, PANEL_MIN_SIZE.y, max_height)
	)


func _layout_viewport_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < PANEL_MIN_SIZE.x + 120.0 or viewport_size.y < PANEL_MIN_SIZE.y + 120.0:
		return Vector2(1280.0, 720.0)
	return viewport_size


func _panel_layout_size(panel_name: String) -> Vector2:
	var shell := _panel_shell(panel_name)
	if shell != null and shell.size.x > 0.0 and shell.size.y > 0.0:
		return shell.size
	return PANEL_DEFAULT_SIZE


func _save_panel_layout() -> Error:
	var config := ConfigFile.new()
	for panel_name in PANEL_NAMES:
		var shell := _panel_shell(panel_name)
		if shell == null:
			continue
		var section := _layout_section(panel_name)
		config.set_value(section, "position", shell.position)
		config.set_value(section, "size", shell.size)
	var error := config.save(layout_file_path)
	if error == OK:
		session_label.text = "HUD layout saved."
	else:
		session_label.text = "HUD layout save failed."
	return error


func _load_panel_layout() -> void:
	var config := ConfigFile.new()
	if config.load(layout_file_path) != OK:
		for panel_name in PANEL_NAMES:
			_set_panel_position(panel_name, _default_panel_position(panel_name))
		return

	for panel_name in PANEL_NAMES:
		var shell := _panel_shell(panel_name)
		if shell == null:
			continue
		var section := _layout_section(panel_name)
		if config.has_section_key(section, "size"):
			var stored_size = config.get_value(section, "size")
			if typeof(stored_size) == TYPE_VECTOR2:
				_set_panel_size(panel_name, stored_size)
		if config.has_section_key(section, "position"):
			var stored_position = config.get_value(section, "position")
			if typeof(stored_position) == TYPE_VECTOR2:
				_set_panel_position(panel_name, stored_position)
		else:
			_set_panel_position(panel_name, _default_panel_position(panel_name))


func _reset_panel_layout() -> void:
	_delete_layout_file(layout_file_path)
	for panel_name in PANEL_NAMES:
		var shell := _panel_shell(panel_name)
		if shell != null:
			shell.size = PANEL_DEFAULT_SIZE
		_set_panel_position(panel_name, _default_panel_position(panel_name))
	session_label.text = "HUD layout reset."


func _delete_layout_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _clear_panel_body() -> void:
	_clear_children(panel_body)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _build_character_panel() -> void:
	panel_title_label.text = "Character"
	var rows: Array[String] = [
		"Name: " + str(session_character_profile.get("name", "Unknown")),
		_character_level_line(),
		"Map: " + str(session_character_profile.get("map", session_map_id)),
		(
			"Position: %.2f, %.2f, %.2f"
			% [
				float(session_character_profile.get("x", session_wow_position.x)),
				float(session_character_profile.get("y", session_wow_position.y)),
				float(session_character_profile.get("z", session_wow_position.z)),
			]
		),
		(
			"Orientation: %.3f"
			% float(session_character_profile.get("orientation", session_orientation))
		),
	]
	var race_text := str(session_character_profile.get("race", "")).strip_edges()
	if not race_text.is_empty():
		rows.insert(2, "Race: " + race_text)
	var zone_text := str(session_character_profile.get("zone", "")).strip_edges()
	if not zone_text.is_empty():
		rows.append("Zone: " + zone_text)
	if session_coinage >= 0:
		rows.append("Money: " + _money_text(session_coinage))
	for row in rows:
		panel_body.add_child(_panel_label(row, 13))

	panel_body.add_child(_panel_label("Equipment", 14))
	if session_inventory_slots.is_empty():
		panel_body.add_child(_panel_label("Equipment snapshot: waiting for session data.", 13))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel_body.add_child(grid)

	for index in range(EQUIPMENT_SLOT_COUNT):
		var slot := _inventory_slot_at(index)
		grid.add_child(_inventory_slot_button(slot, index))


func _character_level_line() -> String:
	var level_text := str(session_character_profile.get("level", "?")).strip_edges()
	var class_text := str(session_character_profile.get("class", "")).strip_edges()
	if class_text.is_empty():
		return "Level " + level_text
	return "Level %s %s" % [level_text, class_text]


func _build_chat_panel() -> void:
	panel_title_label.text = "Chat"
	if session_chat_rows.is_empty():
		panel_body.add_child(_panel_label("Chat log: waiting for live session messages.", 13))
	else:
		panel_body.add_child(_panel_label("Chat rows: " + str(session_chat_rows.size()), 13))
		for index in range(min(session_chat_rows.size(), 40)):
			var row = session_chat_rows[index]
			if row is Dictionary:
				panel_body.add_child(_panel_label(_chat_row_text(row), 13))
		if session_chat_rows.size() > 40:
			panel_body.add_child(
				_panel_label("+%s more chat rows" % str(session_chat_rows.size() - 40), 13)
			)

	panel_body.add_child(_panel_label("Say", 13))
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	panel_body.add_child(input_row)

	var input := LineEdit.new()
	input.placeholder_text = "Message"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(input)

	var send_button := Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(86, 32)
	send_button.pressed.connect(func(): _queue_chat_line(input.text))
	input.text_submitted.connect(func(message: String): _queue_chat_line(message))
	input_row.add_child(send_button)

	panel_body.add_child(_panel_label("Channel state: local queue.", 13))


func _chat_row_text(row: Dictionary) -> String:
	var mode := str(row.get("mode", row.get("channel", "Say"))).strip_edges()
	if mode.is_empty():
		mode = "Say"
	var sender := (
		str(row.get("sender", row.get("sender_name", row.get("from", row.get("sender_guid", "")))))
		. strip_edges()
	)
	var message := str(row.get("message", "")).strip_edges()
	if sender.is_empty():
		return "[%s] %s" % [mode, message]
	return "[%s] %s: %s" % [mode, sender, message]


func _build_spells_panel() -> void:
	panel_title_label.text = "Spells"
	panel_body.add_child(
		_panel_label("Active inputs: primary action, target next, interact, and jump.", 13)
	)
	if session_spell_rows.is_empty():
		panel_body.add_child(_panel_label("Known spells: waiting for session spellbook rows.", 13))
		panel_body.add_child(
			_panel_label(
				(
					"The spellbook stays in the gameplay HUD while the live session "
					+ "feeds spell snapshots and cast results."
				),
				13
			)
		)
		return

	panel_body.add_child(_panel_label("Known spells: " + str(session_spell_rows.size()), 13))
	for index in range(min(session_spell_rows.size(), 80)):
		var row = session_spell_rows[index]
		if row is Dictionary:
			panel_body.add_child(_spell_row_button(row, index))
	if session_spell_rows.size() > 80:
		panel_body.add_child(
			_panel_label("+%s more spell rows" % str(session_spell_rows.size() - 80), 13)
		)


func _spell_row_button(row: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.text = _spell_row_title(row, index)
	button.tooltip_text = _spell_row_detail(row, index)
	button.custom_minimum_size = Vector2(220.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_spell_row.bind(row, index))
	return button


func _show_spell_row(row: Dictionary, index: int) -> void:
	var detail := _spell_row_detail(row, index)
	session_label.text = detail
	status_label.text = "Spell row selected: " + _spell_row_title(row, index).replace("\n", " | ")


func _spell_row_title(row: Dictionary, index: int) -> String:
	var display_name := str(row.get("display_name", row.get("name", ""))).strip_edges()
	var id_text := "Spell ID " + str(row.get("id", row.get("spell_id", 0)))
	var slot_text := "slot " + str(row.get("slot", index))
	if display_name.is_empty():
		return id_text + "\n" + slot_text
	return display_name + "\n" + id_text + " | " + slot_text


func _spell_row_detail(row: Dictionary, index: int) -> String:
	var parts: Array[String] = [
		"spell " + str(row.get("id", row.get("spell_id", 0))),
		"slot " + str(row.get("slot", index)),
	]
	for key in ["flags", "active", "passive", "disabled", "cooldown", "category_cooldown"]:
		if row.has(key):
			parts.append(key + " " + str(row.get(key)))
	return " | ".join(parts)


func _build_actions_panel() -> void:
	panel_title_label.text = "Actions"
	var rows := [
		"Target: " + ("none" if selected_target_index < 0 else str(selected_target_index + 1)),
		"Visible objects: " + str(visible_object_count),
		"Action slots loaded: " + str(_action_populated_count()),
		"Primary: queued in HUD.",
		"Interact: queued in HUD.",
		"Reset: returns the marker to the last server-reported position.",
	]
	for row in rows:
		panel_body.add_child(_panel_label(row, 13))
	if session_action_slots.is_empty():
		panel_body.add_child(_panel_label("Action slot rows: waiting for session data.", 13))
		return
	for index in range(ACTION_BAR_DISPLAY_COUNT):
		var slot := _action_slot_at(index)
		if slot.is_empty():
			continue
		panel_body.add_child(_panel_label(_action_slot_detail(slot), 13))


func _action_slot_at(slot_index: int) -> Dictionary:
	for slot in session_action_slots:
		if slot is Dictionary and int(slot.get("button", -1)) == slot_index:
			return slot
	return {}


func _action_populated_count() -> int:
	var count := 0
	for slot in session_action_slots:
		if slot is Dictionary and bool(slot.get("populated", true)):
			count += 1
	return count


func _action_slot_label(slot: Dictionary) -> String:
	if slot.is_empty() or not bool(slot.get("populated", true)):
		return "empty"
	return _action_type_name(int(slot.get("type", 0))) + " " + str(slot.get("action", 0))


func _action_slot_detail(slot: Dictionary) -> String:
	return (
		"slot %s | %s | action %s | packed %s"
		% [
			str(slot.get("button", "?")),
			_action_type_name(int(slot.get("type", 0))),
			str(slot.get("action", 0)),
			str(slot.get("packed", "")),
		]
	)


func _action_type_name(action_type: int) -> String:
	match action_type:
		0:
			return "spell"
		64:
			return "macro"
		65:
			return "item"
		66:
			return "equipment"
		128:
			return "companion"
		_:
			return "type " + str(action_type)


func _build_targets_panel() -> void:
	panel_title_label.text = "Targets"
	panel_body.add_child(_panel_label("Visible objects: " + str(visible_object_count), 13))
	if selected_target_index >= 0:
		panel_body.add_child(
			_panel_label(
				(
					"Selected: "
					+ _target_summary(
						_visible_object_at(selected_target_index), selected_target_index
					)
				),
				13
			)
		)
	else:
		panel_body.add_child(_panel_label("Selected: none", 13))

	if visible_objects.is_empty():
		panel_body.add_child(
			_panel_label(
				"Detailed target rows are waiting for the persistent session snapshot.", 13
			)
		)
		return

	for index in range(min(visible_objects.size(), 16)):
		panel_body.add_child(_target_row_button(visible_objects[index], index))
	if visible_objects.size() > 16:
		panel_body.add_child(
			_panel_label("+%s more visible object rows" % str(visible_objects.size() - 16), 13)
		)


func _target_row_button(target: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.text = "%s. %s" % [str(index + 1), _target_summary(target, index)]
	button.tooltip_text = _target_detail(target, index)
	button.custom_minimum_size = Vector2(260.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_target_index.bind(index))
	if index == selected_target_index:
		button.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	return button


func _visible_object_at(index: int) -> Dictionary:
	if index >= 0 and index < visible_objects.size() and visible_objects[index] is Dictionary:
		return visible_objects[index]
	return {"index": index}


func _target_summary(target: Dictionary, index: int) -> String:
	var object_type := str(target.get("type", target.get("object_type", "object"))).strip_edges()
	if object_type.is_empty():
		object_type = "object"
	var entry := int(target.get("entry", 0))
	var guid := str(target.get("guid", ""))
	var label := object_type
	if entry > 0:
		label += " entry " + str(entry)
	elif not guid.is_empty():
		label += " " + _short_guid(guid)
	else:
		label += " " + str(index + 1)
	if target.has("distance"):
		label += " | %.1fm" % float(target.get("distance", 0.0))
	return label


func _target_detail(target: Dictionary, index: int) -> String:
	var parts: Array[String] = [
		"index " + str(index + 1),
		"type " + str(target.get("type", target.get("object_type", "object"))),
		"entry " + str(target.get("entry", 0)),
		"guid " + str(target.get("guid", "")),
	]
	if target.has("distance"):
		parts.append("distance %.2f" % float(target.get("distance", 0.0)))
	var position_text := _target_position_text(target)
	if not position_text.is_empty():
		parts.append(position_text)
	return " | ".join(parts)


func _target_position_text(target: Dictionary) -> String:
	if target.has("x") and target.has("y") and target.has("z"):
		return (
			"pos %.2f, %.2f, %.2f"
			% [
				float(target.get("x", 0.0)),
				float(target.get("y", 0.0)),
				float(target.get("z", 0.0)),
			]
		)
	var position = target.get("position", {})
	if position is Dictionary and position.has("x") and position.has("y") and position.has("z"):
		return (
			"pos %.2f, %.2f, %.2f"
			% [
				float(position.get("x", 0.0)),
				float(position.get("y", 0.0)),
				float(position.get("z", 0.0)),
			]
		)
	return ""


func _build_auras_panel() -> void:
	panel_title_label.text = "Auras"
	var player_status: Dictionary = session_unit_status_snapshot.get("player", {})
	var target_status := _selected_target_unit_status()
	if player_status.is_empty() and target_status.is_empty():
		panel_body.add_child(_panel_label("Auras window: waiting for unit status data.", 13))
		panel_body.add_child(
			_panel_label(
				"Live aura, health, power, and cooldown updates remain in the live-session lane.",
				13
			)
		)
		return

	if not player_status.is_empty():
		_add_unit_status_section("Player Status", player_status)
	if not target_status.is_empty():
		_add_unit_status_section("Target Status", target_status)
	panel_body.add_child(_panel_label("Aura actions: waiting for live session controls.", 13))


func _selected_target_unit_status() -> Dictionary:
	var target_snapshot: Dictionary = session_unit_status_snapshot.get("target", {})
	if selected_target_index < 0:
		return target_snapshot
	var target := _visible_object_at(selected_target_index).duplicate(true)
	if target_snapshot is Dictionary:
		for key in target_snapshot.keys():
			if not target.has(key) or str(target.get(key, "")).strip_edges().is_empty():
				target[key] = target_snapshot.get(key)
	return _normalize_unit_status(target, "Target")


func _add_unit_status_section(title: String, status: Dictionary) -> void:
	panel_body.add_child(_panel_label(title, 14))
	panel_body.add_child(_panel_label(_unit_status_summary(status), 13))
	var auras: Array = status.get("auras", [])
	panel_body.add_child(
		_panel_label(
			(
				"Auras: %s | buffs %s | debuffs %s"
				% [
					str(auras.size()),
					str(_unit_aura_kind_count(auras, "buff")),
					str(_unit_aura_kind_count(auras, "debuff")),
				]
			),
			13
		)
	)
	for index in range(min(auras.size(), 24)):
		var aura = auras[index]
		if aura is Dictionary:
			panel_body.add_child(_aura_row_button(aura))
	if auras.size() > 24:
		panel_body.add_child(_panel_label("+%s more aura rows" % str(auras.size() - 24), 13))
	var cooldowns: Array = status.get("cooldowns", [])
	if not cooldowns.is_empty():
		panel_body.add_child(_panel_label("Cooldowns: " + str(cooldowns.size()), 14))
		for index in range(min(cooldowns.size(), 12)):
			var cooldown = cooldowns[index]
			if cooldown is Dictionary:
				panel_body.add_child(_panel_label(_cooldown_row_text(cooldown), 13))


func _unit_status_summary(status: Dictionary) -> String:
	var parts: Array[String] = [str(status.get("name", "Unit"))]
	var level_text := str(status.get("level", "")).strip_edges()
	if not level_text.is_empty():
		parts.append("level " + level_text)
	var class_text := str(status.get("class", "")).strip_edges()
	if not class_text.is_empty():
		parts.append(class_text)
	parts.append(_unit_health_text(status))
	var power_text := _unit_power_text(status)
	if not power_text.is_empty():
		parts.append(power_text)
	var reaction := str(status.get("reaction", "")).strip_edges()
	if not reaction.is_empty():
		parts.append("reaction " + reaction)
	return " | ".join(parts)


func _unit_status_short_line(status: Dictionary) -> String:
	var parts: Array[String] = [_unit_health_text(status)]
	var power_text := _unit_power_text(status)
	if not power_text.is_empty():
		parts.append(power_text)
	return " | ".join(parts)


func _unit_health_text(status: Dictionary) -> String:
	var health := int(status.get("health", -1))
	var max_health := int(status.get("max_health", -1))
	if health >= 0 and max_health > 0:
		return "Health %s/%s (%s%%)" % [
			str(health),
			str(max_health),
			str(_safe_percent(health, max_health)),
		]
	if health >= 0:
		return "Health " + str(health)
	return "Health unknown"


func _unit_power_text(status: Dictionary) -> String:
	var power := int(status.get("power", -1))
	var max_power := int(status.get("max_power", -1))
	if power < 0 and max_power < 0:
		return ""
	var power_type := str(status.get("power_type", "")).strip_edges()
	var label := "Power" if power_type.is_empty() else "Power " + power_type
	if power >= 0 and max_power > 0:
		return "%s %s/%s (%s%%)" % [
			label,
			str(power),
			str(max_power),
			str(_safe_percent(power, max_power)),
		]
	if power >= 0:
		return label + " " + str(power)
	return label


func _safe_percent(current: int, maximum: int) -> int:
	if maximum <= 0:
		return 0
	return int(round((float(current) / float(maximum)) * 100.0))


func _unit_aura_count(status: Dictionary) -> int:
	var auras: Array = status.get("auras", [])
	return auras.size()


func _unit_aura_kind_count(auras: Array, kind: String) -> int:
	var count := 0
	for aura in auras:
		if aura is Dictionary and str(aura.get("kind", "")).to_lower() == kind:
			count += 1
	return count


func _aura_row_button(aura: Dictionary) -> Button:
	var button := Button.new()
	button.text = _aura_row_text(aura)
	button.tooltip_text = _aura_row_detail(aura)
	button.custom_minimum_size = Vector2(260.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_aura_row.bind(aura))
	return button


func _show_aura_row(aura: Dictionary) -> void:
	session_label.text = _aura_row_detail(aura)
	status_label.text = "Aura row selected: " + _aura_row_text(aura).replace("\n", " | ")


func _aura_row_text(aura: Dictionary) -> String:
	var name := str(aura.get("name", "aura")).strip_edges()
	var kind := str(aura.get("kind", "aura")).strip_edges()
	var detail: Array[String] = [kind]
	var stacks := int(aura.get("stacks", 0))
	if stacks > 0:
		detail.append("stacks " + str(stacks))
	var remaining := int(aura.get("remaining_ms", 0))
	if remaining > 0:
		detail.append("remaining " + _duration_text(remaining))
	return "%s\n%s" % [name, " | ".join(detail)]


func _aura_row_detail(aura: Dictionary) -> String:
	var parts: Array[String] = [
		"spell " + str(aura.get("spell_id", 0)),
		"name " + str(aura.get("name", "aura")),
		"kind " + str(aura.get("kind", "aura")),
		"stacks " + str(aura.get("stacks", 0)),
		"duration " + _duration_text(int(aura.get("duration_ms", 0))),
		"remaining " + _duration_text(int(aura.get("remaining_ms", 0))),
	]
	var caster := str(aura.get("caster", aura.get("caster_guid", ""))).strip_edges()
	if not caster.is_empty():
		parts.append("caster " + caster)
	return " | ".join(parts)


func _cooldown_row_text(cooldown: Dictionary) -> String:
	return "Spell %s cooldown %s/%s" % [
		str(cooldown.get("spell_id", 0)),
		_duration_text(int(cooldown.get("remaining_ms", 0))),
		_duration_text(int(cooldown.get("duration_ms", 0))),
	]


func _duration_text(milliseconds: int) -> String:
	if milliseconds <= 0:
		return "ready"
	if milliseconds >= 1000:
		return "%.1fs" % (float(milliseconds) / 1000.0)
	return str(milliseconds) + "ms"


func _build_quests_panel() -> void:
	panel_title_label.text = "Quests"
	var active_slots := _quest_active_slots()
	if session_quest_slots.is_empty():
		panel_body.add_child(_panel_label("Quest log: waiting for the live world session.", 13))
		panel_body.add_child(
			_panel_label(
				(
					"The Quests shortcut stays in the gameplay HUD while "
					+ "Claude's session lane wires live snapshots."
				),
				13
			)
		)
		return

	panel_body.add_child(
		_panel_label(
			(
				"Slots observed: %s of %s  Active: %s"
				% [
					str(session_quest_slots.size()),
					str(QUEST_LOG_SLOT_COUNT),
					str(active_slots.size()),
				]
			),
			13
		)
	)

	if active_slots.is_empty():
		panel_body.add_child(
			_panel_label("No active quest ids were present in the latest session snapshot.", 13)
		)
		return

	for slot in active_slots:
		panel_body.add_child(_quest_slot_button(slot))


func _build_loot_panel() -> void:
	panel_title_label.text = "Loot"
	if session_loot_snapshot.is_empty():
		panel_body.add_child(_panel_label("Loot window: waiting for session loot data.", 13))
		panel_body.add_child(
			_panel_label(
				(
					"Target, pickup, autostore, and release actions remain in the "
					+ "persistent live-session lane."
				),
				13
			)
		)
		return

	panel_body.add_child(_panel_label(str(session_loot_snapshot.get("status", "Loot")), 13))
	var target_entry := int(session_loot_snapshot.get("target_entry", 0))
	var target_guid := str(session_loot_snapshot.get("target_guid", "")).strip_edges()
	if target_entry > 0 or not target_guid.is_empty():
		panel_body.add_child(
			_panel_label("Target: entry %s guid %s" % [str(target_entry), target_guid], 13)
		)
	var money := int(session_loot_snapshot.get("money", -1))
	if money >= 0:
		panel_body.add_child(_panel_label("Loot money: " + _money_text(money), 13))
	var opcode := int(session_loot_snapshot.get("response_opcode", 0))
	if opcode > 0:
		panel_body.add_child(_panel_label("Response opcode: 0x%03x" % opcode, 13))
	var removed_count := int(session_loot_snapshot.get("removed_count", 0))
	if removed_count > 0:
		panel_body.add_child(_panel_label("Removed item notices: " + str(removed_count), 13))

	var items: Array = session_loot_snapshot.get("items", [])
	if items.is_empty():
		panel_body.add_child(_panel_label("Loot items: no item rows in this snapshot.", 13))
	else:
		panel_body.add_child(_panel_label("Loot items: " + str(items.size()), 14))
		for index in range(min(items.size(), 24)):
			var item = items[index]
			if item is Dictionary:
				panel_body.add_child(_loot_item_button(item))

	var changed_slots: Array = session_loot_snapshot.get("changed_slots", [])
	if not changed_slots.is_empty():
		panel_body.add_child(_panel_label("Inventory changes: " + str(changed_slots.size()), 14))
		for slot in changed_slots:
			if slot is Dictionary:
				panel_body.add_child(
					_panel_label(_inventory_slot_detail(slot, int(slot.get("slot", 0))), 13)
				)

	panel_body.add_child(_panel_label("Loot actions: waiting for live session controls.", 13))


func _loot_item_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.text = _loot_item_text(item)
	button.tooltip_text = _loot_item_detail(item)
	button.custom_minimum_size = Vector2(220.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_loot_item.bind(item))
	return button


func _show_loot_item(item: Dictionary) -> void:
	session_label.text = _loot_item_detail(item)
	status_label.text = "Loot row selected: " + _loot_item_text(item).replace("\n", " | ")


func _loot_item_text(item: Dictionary) -> String:
	var item_name := str(item.get("item_name", "")).strip_edges()
	var item_id := int(item.get("item_id", 0))
	if item_name.is_empty():
		item_name = "item " + str(item_id)
	return (
		"Slot %s\n%s x%s"
		% [
			str(item.get("slot", 0)),
			item_name,
			str(item.get("count", 0)),
		]
	)


func _loot_item_detail(item: Dictionary) -> String:
	var parts: Array[String] = [
		"slot " + str(item.get("slot", 0)),
		"item " + str(item.get("item_id", 0)),
		"count " + str(item.get("count", 0)),
	]
	for key in ["quality", "display_id", "random_property_id", "suffix_factor"]:
		if item.has(key):
			parts.append(key + " " + str(item.get(key)))
	return " | ".join(parts)


func _build_vendor_panel() -> void:
	panel_title_label.text = "Vendor"
	if session_vendor_snapshot.is_empty():
		panel_body.add_child(_panel_label("Vendor window: waiting for session vendor data.", 13))
		panel_body.add_child(
			_panel_label(
				"Buy, sell, repair, and stock refresh actions remain in the live-session lane.", 13
			)
		)
		return

	var item_count := int(session_vendor_snapshot.get("item_count", 0))
	panel_body.add_child(_panel_label("Vendor items: " + str(item_count), 13))
	var target_entry := int(session_vendor_snapshot.get("target_entry", 0))
	var target_guid := str(session_vendor_snapshot.get("target_guid", "")).strip_edges()
	if target_entry > 0 or not target_guid.is_empty():
		panel_body.add_child(
			_panel_label("Target: entry %s guid %s" % [str(target_entry), target_guid], 13)
		)
	var opcode := int(session_vendor_snapshot.get("response_opcode", 0))
	if opcode > 0:
		panel_body.add_child(_panel_label("Response opcode: 0x%03x" % opcode, 13))
	var error_code := int(session_vendor_snapshot.get("error_code", 0))
	if error_code > 0:
		panel_body.add_child(_panel_label("Vendor error: " + str(error_code), 13))

	var items: Array = session_vendor_snapshot.get("items", [])
	if items.is_empty():
		panel_body.add_child(_panel_label("Vendor rows: no item rows in this snapshot.", 13))
	else:
		for index in range(min(items.size(), 36)):
			var item = items[index]
			if item is Dictionary:
				panel_body.add_child(_vendor_item_button(item))
		if items.size() > 36:
			panel_body.add_child(_panel_label("+%s more vendor rows" % str(items.size() - 36), 13))

	var transaction: Dictionary = session_vendor_snapshot.get("transaction", {})
	if not transaction.is_empty():
		panel_body.add_child(_panel_label("Transaction", 14))
		panel_body.add_child(_panel_label(_vendor_transaction_summary(transaction), 13))
		panel_body.add_child(
			_panel_label(
				(
					"Money: %s -> %s -> %s | total %s"
					% [
						_money_text(int(transaction.get("before_coinage", 0))),
						_money_text(int(transaction.get("after_buy_coinage", 0))),
						_money_text(int(transaction.get("after_sell_coinage", 0))),
						_money_delta_text(int(transaction.get("roundtrip_coinage_delta", 0))),
					]
				),
				13
			)
		)
		for key in ["bought_slot_before", "bought_slot_after_buy", "bought_slot_after_sell"]:
			var slot = transaction.get(key, {})
			if slot is Dictionary and not slot.is_empty():
				panel_body.add_child(
					_panel_label(_inventory_slot_detail(slot, int(slot.get("slot", 0))), 13)
				)

	panel_body.add_child(_panel_label("Vendor actions: waiting for live session controls.", 13))


func _vendor_item_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.text = _vendor_item_text(item)
	button.tooltip_text = _vendor_item_detail(item)
	button.custom_minimum_size = Vector2(240.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_vendor_item.bind(item))
	return button


func _show_vendor_item(item: Dictionary) -> void:
	session_label.text = _vendor_item_detail(item)
	status_label.text = "Vendor row selected: " + _vendor_item_text(item).replace("\n", " | ")


func _vendor_item_text(item: Dictionary) -> String:
	return (
		"Slot %s\nItem %s | %s each | stock %s"
		% [
			str(item.get("vendor_slot", 0)),
			str(item.get("item_id", 0)),
			_money_text(int(item.get("buy_price", 0))),
			_vendor_stock_text(int(item.get("left_in_stock", 0))),
		]
	)


func _vendor_item_detail(item: Dictionary) -> String:
	return (
		"slot %s | item %s | price %s | count %s | stock %s | durability %s | cost %s"
		% [
			str(item.get("vendor_slot", 0)),
			str(item.get("item_id", 0)),
			_money_text(int(item.get("buy_price", 0))),
			str(item.get("buy_count", 0)),
			_vendor_stock_text(int(item.get("left_in_stock", 0))),
			str(item.get("max_durability", 0)),
			str(item.get("extended_cost", 0)),
		]
	)


func _vendor_transaction_summary(transaction: Dictionary) -> String:
	return (
		"buy %s | sell %s | roundtrip %s | bought slot %s"
		% [
			str(transaction.get("buy_succeeded", false)),
			str(transaction.get("sell_confirmed", false)),
			str(transaction.get("roundtrip_confirmed", false)),
			str(transaction.get("bought_slot", 0)),
		]
	)


func _vendor_stock_text(stock: int) -> String:
	if stock < 0 or stock == INFINITE_STOCK:
		return "infinite"
	return str(stock)


func _money_delta_text(copper: int) -> String:
	if copper == 0:
		return "0c"
	var prefix := "+" if copper > 0 else "-"
	return prefix + _money_text(abs(copper))


func _build_trainer_panel() -> void:
	panel_title_label.text = "Trainer"
	if session_trainer_snapshot.is_empty():
		panel_body.add_child(_panel_label("Trainer window: waiting for session trainer data.", 13))
		panel_body.add_child(
			_panel_label("Learn-spell actions remain in the persistent live-session lane.", 13)
		)
		return

	panel_body.add_child(
		_panel_label(
			(
				"Trainer type %s | spell rows %s"
				% [
					str(session_trainer_snapshot.get("trainer_type", 0)),
					str(session_trainer_snapshot.get("spell_count", 0)),
				]
			),
			13
		)
	)
	var target_entry := int(session_trainer_snapshot.get("target_entry", 0))
	var target_guid := str(session_trainer_snapshot.get("target_guid", "")).strip_edges()
	if target_entry > 0 or not target_guid.is_empty():
		panel_body.add_child(
			_panel_label("Target: entry %s guid %s" % [str(target_entry), target_guid], 13)
		)
	var opcode := int(session_trainer_snapshot.get("response_opcode", 0))
	if opcode > 0:
		panel_body.add_child(_panel_label("Response opcode: 0x%03x" % opcode, 13))
	var greeting := str(session_trainer_snapshot.get("greeting", "")).strip_edges()
	if not greeting.is_empty():
		panel_body.add_child(_panel_label("Greeting: " + greeting, 13))

	var spells: Array = session_trainer_snapshot.get("spells", [])
	if spells.is_empty():
		panel_body.add_child(_panel_label("Trainer rows: no spell rows in this snapshot.", 13))
	else:
		for index in range(min(spells.size(), 48)):
			var spell = spells[index]
			if spell is Dictionary:
				panel_body.add_child(_trainer_spell_button(spell))
		if spells.size() > 48:
			panel_body.add_child(
				_panel_label("+%s more trainer rows" % str(spells.size() - 48), 13)
			)

	var learn_result: Dictionary = session_trainer_snapshot.get("learn_result", {})
	if not learn_result.is_empty():
		panel_body.add_child(_panel_label("Learn Result", 14))
		panel_body.add_child(_panel_label(_trainer_learn_summary(learn_result), 13))
		panel_body.add_child(
			_panel_label(
				(
					"Money: %s -> %s | delta %s"
					% [
						_money_text(int(learn_result.get("before_coinage", 0))),
						_money_text(int(learn_result.get("after_coinage", 0))),
						_money_delta_text(int(learn_result.get("coinage_delta", 0))),
					]
				),
				13
			)
		)

	panel_body.add_child(_panel_label("Trainer actions: waiting for live session controls.", 13))


func _trainer_spell_button(spell: Dictionary) -> Button:
	var button := Button.new()
	button.text = _trainer_spell_text(spell)
	button.tooltip_text = _trainer_spell_detail(spell)
	button.custom_minimum_size = Vector2(240.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_trainer_spell.bind(spell))
	if int(spell.get("usable", 0)) != 0:
		button.add_theme_color_override("font_color", Color(0.70, 0.75, 0.74))
	return button


func _show_trainer_spell(spell: Dictionary) -> void:
	session_label.text = _trainer_spell_detail(spell)
	status_label.text = "Trainer row selected: " + _trainer_spell_text(spell).replace("\n", " | ")


func _trainer_spell_text(spell: Dictionary) -> String:
	return (
		"Spell %s\n%s | %s | %s"
		% [
			str(spell.get("spell_id", 0)),
			_trainer_spell_status(int(spell.get("usable", 0))),
			_money_text(int(spell.get("money_cost", 0))),
			_trainer_spell_requirements(spell),
		]
	)


func _trainer_spell_detail(spell: Dictionary) -> String:
	return (
		"spell %s | state %s | cost %s | req %s"
		% [
			str(spell.get("spell_id", 0)),
			_trainer_spell_status(int(spell.get("usable", 0))),
			_money_text(int(spell.get("money_cost", 0))),
			_trainer_spell_requirements(spell),
		]
	)


func _trainer_spell_status(state: int) -> String:
	match state:
		0:
			return "available"
		1:
			return "unavailable"
		2:
			return "known"
		_:
			return "state " + str(state)


func _trainer_spell_requirements(spell: Dictionary) -> String:
	var parts: Array[String] = []
	var req_level := int(spell.get("req_level", 0))
	if req_level > 0:
		parts.append("level " + str(req_level))
	var skill_line := int(spell.get("req_skill_line", 0))
	var skill_rank := int(spell.get("req_skill_rank", 0))
	if skill_line > 0 or skill_rank > 0:
		parts.append("skill %s/%s" % [str(skill_line), str(skill_rank)])
	for ability_key in ["req_ability_1", "req_ability_2", "req_ability_3"]:
		var ability := int(spell.get(ability_key, 0))
		if ability > 0:
			parts.append("spell " + str(ability))
	if parts.is_empty():
		return "no extra requirements"
	return ", ".join(parts)


func _trainer_learn_summary(learn_result: Dictionary) -> String:
	var reason := int(learn_result.get("failure_reason", 0))
	if bool(learn_result.get("buy_succeeded", false)):
		return (
			"spell %s learned | known %s -> %s"
			% [
				str(learn_result.get("spell_id", 0)),
				str(learn_result.get("spell_known_before", false)),
				str(learn_result.get("spell_known_after", false)),
			]
		)
	if bool(learn_result.get("buy_failed", false)):
		return (
			"spell %s failed: %s"
			% [
				str(learn_result.get("spell_id", 0)),
				_trainer_failure_reason(reason),
			]
		)
	return "spell %s response pending" % str(learn_result.get("spell_id", 0))


func _trainer_failure_reason(reason: int) -> String:
	match reason:
		0:
			return "unavailable"
		1:
			return "not enough money"
		2:
			return "not enough skill"
		_:
			return "failure " + str(reason)


func _build_social_panel() -> void:
	panel_title_label.text = "Social"
	if session_social_snapshot.is_empty():
		panel_body.add_child(_panel_label("Social window: waiting for session social data.", 13))
		panel_body.add_child(
			_panel_label(
				"Friend, ignore, party, guild, and invite actions remain in the live-session lane.",
				13
			)
		)
		return

	var party: Array = session_social_snapshot.get("party", [])
	var friends: Array = session_social_snapshot.get("friends", [])
	var ignores: Array = session_social_snapshot.get("ignore", [])
	var guild: Array = session_social_snapshot.get("guild", [])
	var invites: Array = session_social_snapshot.get("invites", [])
	panel_body.add_child(
		_panel_label(
			(
				"Friends %s | Ignore %s | Party %s | Guild %s | Invites %s"
				% [
					str(friends.size()),
					str(ignores.size()),
					str(party.size()),
					str(guild.size()),
					str(invites.size()),
				]
			),
			13
		)
	)
	var party_leader := str(session_social_snapshot.get("party_leader", "")).strip_edges()
	if not party_leader.is_empty():
		panel_body.add_child(_panel_label("Party leader: " + party_leader, 13))
	var guild_name := str(session_social_snapshot.get("guild_name", "")).strip_edges()
	if not guild_name.is_empty():
		panel_body.add_child(_panel_label("Guild: " + guild_name, 13))

	_add_social_section("Party", party)
	_add_social_section("Friends", friends)
	_add_social_section("Ignore", ignores)
	_add_social_section("Guild", guild)
	_add_social_section("Invites", invites)
	panel_body.add_child(_panel_label("Social actions: waiting for live session controls.", 13))


func _add_social_section(title: String, rows: Array) -> void:
	panel_body.add_child(_panel_label("%s: %s" % [title, str(rows.size())], 14))
	if rows.is_empty():
		panel_body.add_child(_panel_label("No " + title.to_lower() + " rows in this snapshot.", 13))
		return
	for index in range(min(rows.size(), 24)):
		var row: Variant = rows[index]
		if row is Dictionary:
			panel_body.add_child(_social_row_button(row))
	if rows.size() > 24:
		panel_body.add_child(_panel_label("+%s more %s rows" % [str(rows.size() - 24), title], 13))


func _social_row_button(row: Dictionary) -> Button:
	var button := Button.new()
	button.text = _social_row_text(row)
	button.tooltip_text = _social_row_detail(row)
	button.custom_minimum_size = Vector2(240.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_social_row.bind(row))
	return button


func _show_social_row(row: Dictionary) -> void:
	session_label.text = _social_row_detail(row)
	status_label.text = "Social row selected: " + _social_row_text(row).replace("\n", " | ")


func _social_row_text(row: Dictionary) -> String:
	var name := str(row.get("name", "Unknown"))
	var status := _social_status_text(row)
	var detail := _social_row_summary(row)
	if detail.is_empty():
		return "%s\n%s" % [name, status]
	return "%s\n%s | %s" % [name, status, detail]


func _social_row_detail(row: Dictionary) -> String:
	var parts: Array[String] = [
		str(row.get("kind", "social")),
		"name " + str(row.get("name", "Unknown")),
		"status " + _social_status_text(row),
	]
	for key in ["level", "class", "zone", "rank", "note", "role", "guid"]:
		if row.has(key):
			parts.append(key + " " + str(row.get(key)))
	return " | ".join(parts)


func _social_status_text(row: Dictionary) -> String:
	if row.has("online"):
		return "online" if bool(row.get("online", false)) else "offline"
	var status := str(row.get("status", "")).strip_edges()
	if not status.is_empty():
		return status
	return "listed"


func _social_row_summary(row: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["level", "class", "zone", "rank", "role"]:
		if row.has(key):
			parts.append(str(row.get(key)))
	return " ".join(parts)


func _build_mail_panel() -> void:
	panel_title_label.text = "Mail"
	if session_mail_snapshot.is_empty():
		panel_body.add_child(_panel_label("Mail window: waiting for session mailbox data.", 13))
		panel_body.add_child(
			_panel_label(
				"Read, send, delete, COD, and attachment actions remain in the live-session lane.",
				13
			)
		)
		return

	var messages: Array = session_mail_snapshot.get("messages", [])
	panel_body.add_child(
		_panel_label(
			(
				"Mail rows: %s | unread %s"
				% [
					str(session_mail_snapshot.get("message_count", messages.size())),
					str(session_mail_snapshot.get("unread_count", 0)),
				]
			),
			13
		)
	)
	var mailbox_guid := str(session_mail_snapshot.get("mailbox_guid", "")).strip_edges()
	if not mailbox_guid.is_empty():
		panel_body.add_child(_panel_label("Mailbox: " + mailbox_guid, 13))
	var money_total := int(session_mail_snapshot.get("money_total", 0))
	var cod_total := int(session_mail_snapshot.get("cod_total", 0))
	if money_total > 0 or cod_total > 0:
		panel_body.add_child(
			_panel_label(
				(
					"Money attached: %s | COD total: %s"
					% [_money_text(money_total), _money_text(cod_total)]
				),
				13
			)
		)
	var opcode := int(session_mail_snapshot.get("response_opcode", 0))
	if opcode > 0:
		panel_body.add_child(_panel_label("Response opcode: 0x%03x" % opcode, 13))

	if messages.is_empty():
		panel_body.add_child(_panel_label("Mailbox rows: no messages in this snapshot.", 13))
	else:
		for index in range(min(messages.size(), 32)):
			var message = messages[index]
			if message is Dictionary:
				panel_body.add_child(_mail_row_button(message))
		if messages.size() > 32:
			panel_body.add_child(_panel_label("+%s more mail rows" % str(messages.size() - 32), 13))

	panel_body.add_child(_panel_label("Mail actions: waiting for live mailbox controls.", 13))


func _mail_row_button(row: Dictionary) -> Button:
	var button := Button.new()
	button.text = _mail_row_text(row)
	button.tooltip_text = _mail_row_detail(row)
	button.custom_minimum_size = Vector2(260.0, 50.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_mail_row.bind(row))
	return button


func _show_mail_row(row: Dictionary) -> void:
	session_label.text = _mail_row_detail(row)
	status_label.text = "Mail row selected: " + _mail_row_text(row).replace("\n", " | ")


func _mail_row_text(row: Dictionary) -> String:
	var subject := str(row.get("subject", "Mail")).strip_edges()
	if subject.is_empty():
		subject = "Mail " + str(row.get("id", ""))
	var parts: Array[String] = [
		"from " + str(row.get("sender", "Unknown")),
		_mail_read_state(row),
	]
	var attachments: Array = row.get("attachments", [])
	if not attachments.is_empty():
		parts.append("attachments " + str(attachments.size()))
	var money := int(row.get("money", 0))
	if money > 0:
		parts.append("money " + _money_text(money))
	var cod := int(row.get("cod", 0))
	if cod > 0:
		parts.append("COD " + _money_text(cod))
	return "%s\n%s" % [subject, " | ".join(parts)]


func _mail_row_detail(row: Dictionary) -> String:
	var parts: Array[String] = [
		"mail " + str(row.get("id", "")),
		"from " + str(row.get("sender", "Unknown")),
		"subject " + str(row.get("subject", "")),
		"state " + _mail_read_state(row),
	]
	var preview := str(row.get("body_preview", "")).strip_edges()
	if not preview.is_empty():
		parts.append("preview " + preview)
	var money := int(row.get("money", 0))
	if money > 0:
		parts.append("money " + _money_text(money))
	var cod := int(row.get("cod", 0))
	if cod > 0:
		parts.append("COD " + _money_text(cod))
	var expire_time := str(row.get("expire_time", "")).strip_edges()
	if not expire_time.is_empty():
		parts.append("expires " + expire_time)
	var attachments: Array = row.get("attachments", [])
	if not attachments.is_empty():
		parts.append("attachments " + _mail_attachment_summary(attachments))
	return " | ".join(parts)


func _mail_read_state(row: Dictionary) -> String:
	if row.has("returned") and bool(row.get("returned", false)):
		return "returned"
	return "read" if bool(row.get("read", false)) else "unread"


func _mail_attachment_summary(attachments: Array) -> String:
	var parts: Array[String] = []
	for index in range(min(attachments.size(), 6)):
		var attachment = attachments[index]
		if attachment is Dictionary:
			parts.append(_mail_attachment_text(attachment))
	if attachments.size() > 6:
		parts.append("+%s more" % str(attachments.size() - 6))
	return ", ".join(parts)


func _mail_attachment_text(attachment: Dictionary) -> String:
	return (
		"slot %s %s x%s"
		% [
			str(attachment.get("slot", 0)),
			str(attachment.get("name", "attachment")),
			str(attachment.get("count", 1)),
		]
	)


func _build_map_panel() -> void:
	panel_title_label.text = "Map"
	var selected_target_text := (
		"none" if selected_target_index < 0 else str(selected_target_index + 1)
	)
	var rows := [
		"Map ID: " + str(session_map_id),
		(
			"Server position: %.2f, %.2f, %.2f"
			% [session_wow_position.x, session_wow_position.y, session_wow_position.z]
		),
		(
			"Marker position: %.2f, %.2f, %.2f"
			% [player_marker.position.x, player_marker.position.y, player_marker.position.z]
		),
		"Orientation: %.3f" % session_orientation,
		"Visible objects: " + str(visible_object_count),
		"Selected target: " + selected_target_text,
	]
	for row in rows:
		panel_body.add_child(_panel_label(row, 13))


func _quest_slot_button(slot: Dictionary) -> Button:
	var button := Button.new()
	button.text = (
		"Slot %s\n%s"
		% [
			str(slot.get("slot", "?")),
			_quest_slot_state(slot),
		]
	)
	button.tooltip_text = _quest_slot_detail(slot)
	button.custom_minimum_size = Vector2(220.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_quest_slot.bind(slot))
	return button


func _show_quest_slot(slot: Dictionary) -> void:
	var detail := _quest_slot_detail(slot)
	quest_label.text = detail
	session_label.text = detail


func _quest_active_slots() -> Array:
	var slots: Array = []
	for slot in session_quest_slots:
		if slot is Dictionary and _quest_slot_is_active(slot):
			slots.append(slot)
	return slots


func _quest_slot_is_active(slot: Dictionary) -> bool:
	return bool(slot.get("active", false)) or int(slot.get("quest_id", 0)) > 0


func _quest_active_count() -> int:
	return _quest_active_slots().size()


func _quest_slot_state(slot: Dictionary) -> String:
	var quest_id := int(slot.get("quest_id", 0))
	if quest_id <= 0:
		return "Cleared"
	var objective_text := _quest_objective_text(slot)
	if objective_text.is_empty():
		return "Quest ID " + str(quest_id)
	return "Quest ID %s | %s" % [str(quest_id), objective_text]


func _quest_slot_detail(slot: Dictionary) -> String:
	var parts: Array[String] = [
		"slot " + str(slot.get("slot", "?")),
		"quest " + str(slot.get("quest_id", 0)),
	]
	for key in ["state_flags", "status_flags", "timer", "time_left"]:
		if slot.has(key):
			parts.append(key + " " + str(slot.get(key)))
	var objective_text := _quest_objective_text(slot)
	if not objective_text.is_empty():
		parts.append(objective_text)
	return " | ".join(parts)


func _quest_objective_text(slot: Dictionary) -> String:
	var values: Array[String] = []
	var objectives = slot.get("objectives", [])
	if objectives is Array and not objectives.is_empty():
		for index in range(int(min(objectives.size(), 4))):
			values.append("obj%s %s" % [str(index + 1), str(objectives[index])])
	for index in range(1, 5):
		for key in [
			"objective_" + str(index),
			"counter_" + str(index),
			"objective_count_" + str(index),
		]:
			if slot.has(key):
				values.append("obj%s %s" % [str(index), str(slot.get(key))])
				break
	return ", ".join(values)


func _build_inventory_panel() -> void:
	panel_title_label.text = "Bags"
	if session_coinage >= 0:
		panel_body.add_child(_panel_label("Money: " + _money_text(session_coinage), 13))
	else:
		panel_body.add_child(_panel_label("Money: waiting for session inventory state.", 13))

	if session_inventory_slots.is_empty():
		panel_body.add_child(
			_panel_label("Inventory snapshot: waiting for the live world session.", 13)
		)
		panel_body.add_child(
			_panel_label(
				"The Bag shortcut now opens this in-session window instead of leaving the HUD.", 13
			)
		)
		return

	panel_body.add_child(
		_panel_label(
			(
				"Slots: %s  Filled: %s"
				% [
					str(INVENTORY_SLOT_NAMES.size()),
					str(_inventory_populated_count(session_inventory_slots)),
				]
			),
			13
		)
	)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel_body.add_child(grid)

	for index in range(INVENTORY_SLOT_NAMES.size()):
		var slot := _inventory_slot_at(index)
		grid.add_child(_inventory_slot_button(slot, index))


func _inventory_slot_button(slot: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.text = _inventory_slot_name(index) + "\n" + _inventory_slot_state(slot)
	button.tooltip_text = _inventory_slot_detail(slot, index)
	button.custom_minimum_size = Vector2(122.0, 58.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_show_inventory_slot.bind(slot, index))
	if bool(slot.get("populated", false)):
		button.add_theme_color_override("font_color", Color(0.96, 0.86, 0.48))
	else:
		button.add_theme_color_override("font_color", Color(0.70, 0.75, 0.74))
	return button


func _show_inventory_slot(slot: Dictionary, index: int) -> void:
	session_label.text = _inventory_slot_detail(slot, index)


func _inventory_slot_at(index: int) -> Dictionary:
	for slot in session_inventory_slots:
		if slot is Dictionary and int(slot.get("slot", -1)) == index:
			return slot
	return {
		"slot": index,
		"field_seen": false,
		"populated": false,
		"item_guid": "0x0",
	}


func _inventory_slot_name(index: int) -> String:
	if index >= 0 and index < INVENTORY_SLOT_NAMES.size():
		return INVENTORY_SLOT_NAMES[index]
	return "Slot " + str(index)


func _inventory_slot_state(slot: Dictionary) -> String:
	if bool(slot.get("populated", false)):
		var item_name := str(slot.get("item_name", "")).strip_edges()
		var stack := int(slot.get("stack_count", 0))
		if not item_name.is_empty():
			return item_name + (" x" + str(stack) if stack > 1 else "")
		var entry := int(slot.get("item_entry", 0))
		if entry > 0:
			return "Entry " + str(entry)
		return "Item " + _short_guid(str(slot.get("item_guid", "0x0")))
	if bool(slot.get("field_seen", false)):
		return "Empty"
	return "No update"


func _inventory_slot_detail(slot: Dictionary, index: int) -> String:
	var durability := ""
	if int(slot.get("max_durability", 0)) > 0:
		durability = (
			" | durability %s/%s"
			% [
				str(slot.get("durability", 0)),
				str(slot.get("max_durability", 0)),
			]
		)
	return (
		"%s | slot %s | entry %s | stack %s | guid %s%s"
		% [
			_inventory_slot_name(index),
			str(slot.get("slot", index)),
			str(slot.get("item_entry", 0)),
			str(slot.get("stack_count", 0)),
			str(slot.get("item_guid", "0x0")),
			durability,
		]
	)


func _inventory_populated_count(slots: Array) -> int:
	var count := 0
	for slot in slots:
		if slot is Dictionary and bool(slot.get("populated", false)):
			count += 1
	return count


func _build_options_panel() -> void:
	panel_title_label.text = "Options"
	var settings := SettingsRuntime.load_settings()
	var keybindings: Dictionary = settings.get("keybindings", {})
	var key_lines := [
		"Move forward: " + _key_name(int(keybindings.get("move_forward", KEY_W))),
		"Move backward: " + _key_name(int(keybindings.get("move_backward", KEY_S))),
		"Move left: " + _key_name(int(keybindings.get("move_left", KEY_A))),
		"Move right: " + _key_name(int(keybindings.get("move_right", KEY_D))),
		(
			"Camera left/right: %s / %s"
			% [
				_key_name(int(keybindings.get("camera_left", KEY_Q))),
				_key_name(int(keybindings.get("camera_right", KEY_E))),
			]
		),
		(
			"Target/action/interact: %s / %s / %s"
			% [
				_key_name(int(keybindings.get("target_next", KEY_TAB))),
				_key_name(int(keybindings.get("attack_primary", KEY_1))),
				_key_name(int(keybindings.get("interact", KEY_F))),
			]
		),
	]
	for line in key_lines:
		panel_body.add_child(_panel_label(line, 13))

	var reset_button := Button.new()
	reset_button.text = "Reset HUD"
	reset_button.custom_minimum_size = Vector2(120, 32)
	reset_button.pressed.connect(_reset_panel_layout)
	panel_body.add_child(reset_button)


func _queue_chat_line(message: String) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		status_label.text = "Chat input is empty."
		return
	status_label.text = "Chat queued locally: " + trimmed.left(48)


func _panel_label(text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(0.91, 0.94, 0.92)
	return label


func _short_guid(guid: String) -> String:
	if guid.length() <= 8:
		return guid
	return guid.substr(guid.length() - 8, 8)


func _money_text(copper: int) -> String:
	var positive: int = int(max(0, copper))
	var gold: int = int(positive / 10000)
	var silver: int = int((positive % 10000) / 100)
	var copper_piece: int = positive % 100
	return "%sg %ss %sc" % [str(gold), str(silver), str(copper_piece)]


func _key_name(keycode: int) -> String:
	var key_name := OS.get_keycode_string(keycode)
	return key_name if not key_name.is_empty() else str(keycode)


func _open_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK and status_label != null:
		status_label.text = "Could not open " + scene_path


func _godot_position(wow_x: float, wow_y: float, wow_z: float) -> Vector3:
	return Vector3(
		wow_x * WORLD_TO_GODOT_SCALE, wow_z * WORLD_TO_GODOT_SCALE, -wow_y * WORLD_TO_GODOT_SCALE
	)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material


func _session_context() -> Node:
	return get_node_or_null("/root/SessionContext")


func _apply_saved_keybindings(path: String = SettingsRuntime.SETTINGS_FILE_PATH) -> void:
	SettingsRuntime.apply_keybindings(SettingsRuntime.load_settings(path))


func _input_action_has_key(action: String, keycode: int) -> bool:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _control_tree_text_contains(node: Node, needle: String) -> bool:
	if node is Label and node.text.find(needle) != -1:
		return true
	if node is Button and node.text.find(needle) != -1:
		return true
	for child in node.get_children():
		if _control_tree_text_contains(child, needle):
			return true
	return false


func _run_keybind_settings_self_test() -> void:
	var test_settings := SettingsRuntime.default_settings()
	test_settings["keybindings"]["move_forward"] = KEY_UP
	test_settings["keybindings"]["camera_left"] = KEY_LEFT
	test_settings["keybindings"]["target_next"] = KEY_T
	test_settings["keybindings"]["attack_primary"] = KEY_2
	test_settings["keybindings"]["interact"] = KEY_G
	test_settings["keybindings"]["reset_sandbox"] = KEY_BACKSPACE
	test_settings["keybindings"]["jump"] = KEY_SPACE
	var save_error := SettingsRuntime.save_settings(
		test_settings, SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH
	)
	if save_error != OK:
		push_error(
			"WORLD_SESSION_KEYBIND_SETTINGS_SELF_TEST_FAILED: could not save temporary settings"
		)
		get_tree().quit(1)
		return

	_apply_saved_keybindings(SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	var bindings_ok := (
		_input_action_has_key("move_forward", KEY_UP)
		and _input_action_has_key("camera_left", KEY_LEFT)
		and _input_action_has_key("target_next", KEY_T)
		and _input_action_has_key("attack_primary", KEY_2)
		and _input_action_has_key("interact", KEY_G)
		and _input_action_has_key("reset_sandbox", KEY_BACKSPACE)
		and _input_action_has_key("jump", KEY_SPACE)
	)
	SettingsRuntime.delete_settings_file(SettingsRuntime.SETTINGS_SELF_TEST_FILE_PATH)
	if not bindings_ok:
		push_error(
			"WORLD_SESSION_KEYBIND_SETTINGS_SELF_TEST_FAILED: saved bindings were not applied"
		)
		get_tree().quit(1)
		return

	print(
		(
			"WORLD_SESSION_KEYBIND_SETTINGS_SELF_TEST_OK "
			+ "move_forward=KEY_UP camera_left=KEY_LEFT target_next=KEY_T"
		)
	)
	get_tree().quit(0)


func _run_layout_self_test() -> void:
	_show_session_panel("options")
	_show_session_panel("actions")
	var options_shell := _panel_shell("options")
	var actions_shell := _panel_shell("actions")
	var options_size := _clamp_panel_size("options", Vector2(660.0, 430.0))
	var actions_size := _clamp_panel_size("actions", Vector2(620.0, 470.0))
	_set_panel_size("options", options_size)
	_set_panel_size("actions", actions_size)
	_set_panel_position("options", Vector2(267.0, 318.0), true)
	_set_panel_position("actions", Vector2(381.0, 246.0), true)
	options_size = options_shell.size
	actions_size = actions_shell.size
	var options_position := options_shell.position
	var actions_position := actions_shell.position
	var snap_ok := (
		options_position.distance_to(_default_panel_position("options")) > 0.01
		and actions_position.distance_to(_default_panel_position("actions")) > 0.01
		and options_size.distance_to(PANEL_DEFAULT_SIZE) > 0.01
		and actions_size.distance_to(PANEL_DEFAULT_SIZE) > 0.01
		and options_size.distance_to(actions_size) > 0.01
	)
	var save_ok := _save_panel_layout() == OK

	options_shell.position = Vector2.ZERO
	actions_shell.position = Vector2.ZERO
	options_shell.size = PANEL_MIN_SIZE
	actions_shell.size = PANEL_MIN_SIZE
	_load_panel_layout()
	var load_ok := (
		options_shell.position.distance_to(options_position) < 0.01
		and actions_shell.position.distance_to(actions_position) < 0.01
		and options_shell.size.distance_to(options_size) < 0.01
		and actions_shell.size.distance_to(actions_size) < 0.01
	)

	_reset_panel_layout()
	var options_reset_position := _clamp_panel_position(
		"options", _default_panel_position("options")
	)
	var actions_reset_position := _clamp_panel_position(
		"actions", _default_panel_position("actions")
	)
	var reset_ok := (
		options_shell.position.distance_to(options_reset_position) < 0.01
		and actions_shell.position.distance_to(actions_reset_position) < 0.01
		and options_shell.size.distance_to(PANEL_DEFAULT_SIZE) < 0.01
		and actions_shell.size.distance_to(PANEL_DEFAULT_SIZE) < 0.01
	)
	var cleanup_ok := not FileAccess.file_exists(ProjectSettings.globalize_path(layout_file_path))

	if snap_ok and save_ok and load_ok and reset_ok and cleanup_ok:
		var layout_message := (
			(
				"WORLD_SESSION_LAYOUT_SELF_TEST_OK "
				+ "options=(%.1f,%.1f %.1fx%.1f) "
				+ "actions=(%.1f,%.1f %.1fx%.1f) reset=true"
			)
			% [
				options_position.x,
				options_position.y,
				options_size.x,
				options_size.y,
				actions_position.x,
				actions_position.y,
				actions_size.x,
				actions_size.y,
			]
		)
		print(layout_message)
		get_tree().quit(0)
		return

	_delete_layout_file(layout_file_path)
	var layout_error := (
		(
			"WORLD_SESSION_LAYOUT_SELF_TEST_FAILED snap_ok=%s save_ok=%s "
			+ "load_ok=%s reset_ok=%s cleanup_ok=%s options_pos=%s "
			+ "options_size=%s actions_pos=%s actions_size=%s"
		)
		% [
			str(snap_ok),
			str(save_ok),
			str(load_ok),
			str(reset_ok),
			str(cleanup_ok),
			str(options_shell.position),
			str(options_shell.size),
			str(actions_shell.position),
			str(actions_shell.size),
		]
	)
	push_error(layout_error)
	get_tree().quit(1)


func _run_self_test() -> void:
	var synthetic_character := {
		"name": "Codexstage",
		"level": 80,
		"class": "Warrior",
		"map": 0,
		"x": -8949.95,
		"y": -132.49,
		"z": 83.53,
		"health": 7890,
		"max_health": 10000,
		"power": 55,
		"max_power": 100,
		"power_type": "rage",
		"auras":
		[
			{
				"spell_id": 1001,
				"name": "Local Fortitude",
				"kind": "buff",
				"stacks": 1,
				"duration_ms": 300000,
				"remaining_ms": 240000,
			},
			{
				"spell_id": 1002,
				"name": "Practice Fatigue",
				"kind": "debuff",
				"remaining_ms": 45000,
			},
		],
		"cooldowns":
		[
			{
				"spell_id": 78,
				"duration_ms": 6000,
				"remaining_ms": 2500,
			},
		],
	}
	var synthetic_result := {
		"ok": true,
		"character_name": "Codexstage",
		"login":
		{
			"map": 0,
			"x": -8949.95,
			"y": -132.49,
			"z": 83.53,
			"orientation": 0.0,
		},
		"update":
		{
			"visible_object_count": 3,
			"visible_objects":
			[
				{
					"type": "creature",
					"entry": 69,
					"guid": "0xf130000045000daa",
					"distance": 12.5,
					"x": -8942.0,
					"y": -128.0,
					"z": 83.5,
					"health": 320,
					"max_health": 500,
					"level": 5,
					"reaction": "hostile",
					"debuffs":
					[
						{
							"spell_id": 2001,
							"name": "Training Mark",
							"kind": "debuff",
							"remaining_ms": 15000,
						},
					],
				},
				{
					"type": "creature",
					"entry": 299,
					"guid": "0xf13000012b000dab",
					"distance": 18.0,
				},
				{
					"type": "gameobject",
					"entry": 55,
					"guid": "0xf110000037000001",
					"distance": 25.0,
				},
			],
		},
		"inventory":
		{
			"coinage": 123456,
			"slots":
			[
				{
					"slot": 15,
					"populated": true,
					"item_name": "Practice Blade",
					"item_guid": "0x4000000000000100",
					"item_entry": 100,
					"stack_count": 1,
					"durability": 21,
					"max_durability": 25,
				},
				{
					"slot": 23,
					"populated": true,
					"item_name": "Packed Lunch",
					"item_guid": "0x4000000000000101",
					"item_entry": 101,
					"stack_count": 3,
				},
				{
					"slot": 24,
					"field_seen": true,
					"populated": false,
					"item_guid": "0x0",
				},
			],
		},
		"chat":
		{
			"messages":
			[
				{
					"mode": "Say",
					"sender": "Codexstage",
					"message": "Session hello",
				},
				{
					"mode": "System",
					"message": "World session ready",
				},
			],
		},
		"loot":
		{
			"loot_response_seen": true,
			"target_guid": "0xf130000045000daa",
			"target_entry": 69,
			"response_opcode": 0x160,
			"gold": 42,
			"loot_item_removed_count": 1,
			"items":
			[
				{
					"slot": 0,
					"item_id": 25,
					"count": 2,
				},
				{
					"slot": 1,
					"item_entry": 117,
					"stack_count": 1,
				},
			],
			"changed_slots":
			[
				{
					"slot": 23,
					"populated": true,
					"item_name": "Looted Keepsake",
					"item_entry": 25,
					"stack_count": 2,
					"item_guid": "0x4000000000000200",
				},
			],
		},
		"vendor":
		{
			"vendor_list_response_seen": true,
			"target_guid": "0xf1300004bd000777",
			"target_entry": 1213,
			"response_opcode": 0x19F,
			"item_count": 2,
			"items":
			[
				{
					"vendor_slot": 8,
					"item_id": 17184,
					"buy_price": 32,
					"left_in_stock": INFINITE_STOCK,
					"buy_count": 1,
					"max_durability": 0,
					"extended_cost": 0,
				},
				{
					"vendor_slot": 9,
					"item_id": 17000,
					"buy_price": 120,
					"left_in_stock": 4,
					"buy_count": 1,
					"max_durability": 0,
					"extended_cost": 0,
				},
			],
			"buy_response_seen": true,
			"buy_succeeded": true,
			"sell_confirmed": true,
			"roundtrip_confirmed": true,
			"bought_slot": 34,
			"before_coinage": 9939,
			"after_buy_coinage": 9907,
			"after_sell_coinage": 9913,
			"roundtrip_coinage_delta": -26,
			"bought_slot_after_buy":
			{
				"slot": 34,
				"populated": true,
				"item_entry": 17184,
				"stack_count": 1,
				"item_guid": "0x4000000000000300",
			},
		},
		"trainer":
		{
			"trainer_list_response_seen": true,
			"target_guid": "0xf13000038f000888",
			"target_entry": 911,
			"response_opcode": 0x1B1,
			"trainer_type": 0,
			"greeting": "Train me.",
			"spell_count": 2,
			"spells":
			[
				{
					"spell_id": 6673,
					"usable": 0,
					"money_cost": 100,
					"req_level": 1,
					"req_skill_line": 0,
					"req_skill_rank": 0,
				},
				{
					"spell_id": 78,
					"usable": 2,
					"money_cost": 0,
					"req_level": 1,
				},
			],
			"buy_response_seen": true,
			"buy_succeeded": true,
			"spell_id": 6673,
			"spell_known_before": false,
			"spell_known_after": true,
			"before_coinage": 10000,
			"after_coinage": 9900,
			"coinage_delta": -100,
		},
		"social":
		{
			"friends":
			[
				{
					"name": "Localfriend",
					"online": true,
					"level": 80,
					"class": "Mage",
					"zone": "Stormwind",
				},
				{
					"name": "Offlinepal",
					"online": false,
					"level": 12,
					"class": "Priest",
				},
			],
			"ignore": ["Noisytest"],
			"party":
			{
				"leader": "Codexstage",
				"members":
				[
					{
						"name": "Codexstage",
						"online": true,
						"role": "leader",
					},
					{
						"name": "Partyhelper",
						"online": true,
						"role": "member",
					},
				],
			},
			"guild":
			{
				"guild_name": "Local Test Guild",
				"members":
				[
					{
						"name": "Guildmate",
						"online": true,
						"rank": "Officer",
					},
				],
			},
			"invites":
			[
				{
					"name": "Pendingbuddy",
					"status": "pending",
				},
			],
		},
		"mail":
		{
			"unread_count": 1,
			"messages":
			[
				{
					"mail_id": 101,
					"sender": "Postmaster",
					"subject": "Welcome bundle",
					"body_preview": "A local test message.",
					"money": 123,
					"cod": 0,
					"read": false,
					"attachments":
					[
						{
							"slot": 0,
							"item_id": 6948,
							"count": 1,
						},
					],
				},
				{
					"mail_id": 102,
					"sender": "Localfriend",
					"subject": "No attachment",
					"read": true,
					"money": 0,
					"cod": 25,
				},
			],
		},
		"action_buttons":
		{
			"buttons":
			[
				{
					"button": 0,
					"action": 78,
					"type": 0,
					"packed": 78,
					"populated": true,
				},
				{
					"button": 1,
					"action": 6603,
					"type": 0,
					"packed": 6603,
					"populated": true,
				},
				{
					"button": 2,
					"action": 6948,
					"type": 65,
					"packed": 1098907648,
					"populated": true,
				},
			],
		},
		"spellbook":
		{
			"initial_spells_seen": true,
			"spell_count": 3,
			"cooldown_count": 1,
			"spells":
			[
				{
					"slot": 0,
					"id": 78,
					"flags": 0,
				},
				{
					"slot": 1,
					"spell_id": 2457,
					"flags": 0,
				},
				{
					"slot": 2,
					"id": 6603,
					"passive": false,
				},
			],
		},
		"quest_log":
		{
			"slots":
			[
				{
					"slot": 0,
					"quest_id": 783,
					"state_flags": 8,
					"objective_1": 1,
					"objective_2": 0,
					"timer": 0,
				},
				{
					"slot": 1,
					"quest_id": 0,
				},
			],
		},
	}

	var no_target_result := synthetic_result.duplicate(true)
	no_target_result["update"]["visible_object_count"] = 0
	no_target_result["update"]["visible_objects"] = []
	_apply_session_data(
		synthetic_character, no_target_result, "Synthetic no-target world-session self-test."
	)
	_select_next_target()
	var no_target_key_ok := (
		selected_target_index == -1 and target_label.text.find("Visible objects: 0") != -1
	)
	_queue_primary_action()
	var no_target_action_ok := status_label.text.find("select a visible target") != -1
	_queue_interact()
	var no_target_interact_ok := quest_label.text.find("not attached yet") != -1

	_apply_session_data(synthetic_character, synthetic_result, "Synthetic world-session self-test.")

	_select_next_target()
	var target_key_ok := target_label.text.find("Target 1 of 3") != -1
	_queue_primary_action()
	var action_key_ok := status_label.text.find("Primary action queued for target 1") != -1
	_queue_interact()
	var interact_key_ok := quest_label.text.find("Interaction queued for target 1") != -1
	player_marker.position += Vector3(8.0, 0.0, 0.0)
	_reset_marker_to_session()
	_show_session_panel("chat")
	var chat_shell := _panel_shell("chat")
	var chat_title: Label = session_panels.get("chat", {}).get("title", null)
	var chat_body: VBoxContainer = session_panels.get("chat", {}).get("body", null)
	var chat_panel_ok := (
		chat_shell != null
		and chat_shell.visible
		and chat_title != null
		and chat_title.text == "Chat"
		and chat_body != null
		and session_chat_rows.size() == 2
		and _control_tree_text_contains(chat_body, "Chat rows: 2")
		and _control_tree_text_contains(chat_body, "Session hello")
		and _control_tree_text_contains(chat_body, "World session ready")
	)
	_show_session_panel("character")
	var character_shell := _panel_shell("character")
	var character_title: Label = session_panels.get("character", {}).get("title", null)
	var character_body: VBoxContainer = session_panels.get("character", {}).get("body", null)
	var character_grid_ok := false
	if character_body != null:
		for child in character_body.get_children():
			if child is GridContainer and child.get_child_count() == EQUIPMENT_SLOT_COUNT:
				character_grid_ok = true
				break
	var character_panel_ok := (
		character_shell != null
		and character_shell.visible
		and character_title != null
		and character_title.text == "Character"
		and character_body != null
		and _control_tree_text_contains(character_body, "Name: Codexstage")
		and _control_tree_text_contains(character_body, "Level 80 Warrior")
		and _control_tree_text_contains(character_body, "Money: 12g 34s 56c")
		and _inventory_slot_state(_inventory_slot_at(15)) == "Practice Blade"
		and character_grid_ok
	)
	_show_session_panel("actions")
	var actions_shell := _panel_shell("actions")
	var actions_title: Label = session_panels.get("actions", {}).get("title", null)
	var actions_panel_ok := (
		actions_shell != null
		and actions_shell.visible
		and actions_title != null
		and actions_title.text == "Actions"
		and _action_populated_count() == 3
		and _control_tree_text_contains(actions_shell, "action 78")
		and _control_tree_text_contains(actions_shell, "action 6948")
	)
	_show_session_panel("targets")
	var targets_shell := _panel_shell("targets")
	var targets_title: Label = session_panels.get("targets", {}).get("title", null)
	var targets_body: VBoxContainer = session_panels.get("targets", {}).get("body", null)
	var targets_panel_ok := (
		targets_shell != null
		and targets_shell.visible
		and targets_title != null
		and targets_title.text == "Targets"
		and targets_body != null
		and visible_objects.size() == 3
		and _control_tree_text_contains(targets_body, "creature entry 69")
		and _control_tree_text_contains(targets_body, "Visible objects: 3")
	)
	var target_frame_ok := (
		target_frame_body != null
		and _control_tree_text_contains(target_frame_body, "creature entry 69")
		and _control_tree_text_contains(target_frame_body, "Health 320/500 (64%)")
		and _control_tree_text_contains(target_frame_body, "Auras: 1")
		and _control_tree_text_contains(target_frame_body, "Open")
	)
	_show_session_panel("auras")
	var auras_shell := _panel_shell("auras")
	var auras_title: Label = session_panels.get("auras", {}).get("title", null)
	var auras_body: VBoxContainer = session_panels.get("auras", {}).get("body", null)
	var player_status: Dictionary = session_unit_status_snapshot.get("player", {})
	var player_auras: Array = player_status.get("auras", [])
	var player_cooldowns: Array = player_status.get("cooldowns", [])
	var selected_target_status := _selected_target_unit_status()
	var target_auras: Array = selected_target_status.get("auras", [])
	var auras_panel_ok := (
		auras_shell != null
		and auras_shell.visible
		and auras_title != null
		and auras_title.text == "Auras"
		and auras_body != null
		and player_auras.size() == 2
		and target_auras.size() == 1
		and player_cooldowns.size() == 1
		and _control_tree_text_contains(auras_body, "Player Status")
		and _control_tree_text_contains(auras_body, "Health 7890/10000 (79%)")
		and _control_tree_text_contains(auras_body, "Power rage 55/100 (55%)")
		and _control_tree_text_contains(auras_body, "Local Fortitude")
		and _control_tree_text_contains(auras_body, "Practice Fatigue")
		and _control_tree_text_contains(auras_body, "Target Status")
		and _control_tree_text_contains(auras_body, "Health 320/500 (64%)")
		and _control_tree_text_contains(auras_body, "Training Mark")
		and _control_tree_text_contains(auras_body, "Cooldowns: 1")
		and _control_tree_text_contains(auras_body, "Spell 78 cooldown 2.5s/6.0s")
	)
	_show_session_panel("spells")
	var spells_shell := _panel_shell("spells")
	var spells_title: Label = session_panels.get("spells", {}).get("title", null)
	var spells_body: VBoxContainer = session_panels.get("spells", {}).get("body", null)
	var spells_panel_ok := (
		spells_shell != null
		and spells_shell.visible
		and spells_title != null
		and spells_title.text == "Spells"
		and spells_body != null
		and session_spell_rows.size() == 3
		and _control_tree_text_contains(spells_body, "Known spells: 3")
		and _control_tree_text_contains(spells_body, "Spell ID 78")
		and _control_tree_text_contains(spells_body, "Spell ID 2457")
	)
	_show_session_panel("quests")
	var quests_shell := _panel_shell("quests")
	var quests_title: Label = session_panels.get("quests", {}).get("title", null)
	var quests_body: VBoxContainer = session_panels.get("quests", {}).get("body", null)
	var quest_button_ok := false
	if quests_body != null:
		for child in quests_body.get_children():
			if child is Button and child.text.find("Quest ID 783") != -1:
				quest_button_ok = true
				break
	var quests_panel_ok := (
		quests_shell != null
		and quests_shell.visible
		and quests_title != null
		and quests_title.text == "Quests"
		and session_quest_slots.size() == 2
		and _quest_active_count() == 1
		and quest_button_ok
	)
	var quest_tracker_ok := (
		quest_tracker_body != null
		and _control_tree_text_contains(quest_tracker_body, "Quest ID 783")
		and _control_tree_text_contains(quest_tracker_body, "obj1 1")
		and _control_tree_text_contains(quest_tracker_body, "Open")
	)
	_show_session_panel("loot")
	var loot_shell := _panel_shell("loot")
	var loot_title: Label = session_panels.get("loot", {}).get("title", null)
	var loot_body: VBoxContainer = session_panels.get("loot", {}).get("body", null)
	var loot_items: Array = session_loot_snapshot.get("items", [])
	var loot_panel_ok := (
		loot_shell != null
		and loot_shell.visible
		and loot_title != null
		and loot_title.text == "Loot"
		and loot_body != null
		and int(session_loot_snapshot.get("money", -1)) == 42
		and loot_items.size() == 2
		and _control_tree_text_contains(loot_body, "Loot money: 0g 0s 42c")
		and _control_tree_text_contains(loot_body, "Loot items: 2")
		and _control_tree_text_contains(loot_body, "item 25")
		and _control_tree_text_contains(loot_body, "Inventory changes: 1")
	)
	_show_session_panel("vendor")
	var vendor_shell := _panel_shell("vendor")
	var vendor_title: Label = session_panels.get("vendor", {}).get("title", null)
	var vendor_body: VBoxContainer = session_panels.get("vendor", {}).get("body", null)
	var vendor_items: Array = session_vendor_snapshot.get("items", [])
	var vendor_panel_ok := (
		vendor_shell != null
		and vendor_shell.visible
		and vendor_title != null
		and vendor_title.text == "Vendor"
		and vendor_body != null
		and vendor_items.size() == 2
		and _control_tree_text_contains(vendor_body, "Vendor items: 2")
		and _control_tree_text_contains(vendor_body, "Item 17184")
		and _control_tree_text_contains(vendor_body, "stock infinite")
		and _control_tree_text_contains(vendor_body, "roundtrip true")
		and _control_tree_text_contains(vendor_body, "total -0g 0s 26c")
	)
	_show_session_panel("trainer")
	var trainer_shell := _panel_shell("trainer")
	var trainer_title: Label = session_panels.get("trainer", {}).get("title", null)
	var trainer_body: VBoxContainer = session_panels.get("trainer", {}).get("body", null)
	var trainer_spells: Array = session_trainer_snapshot.get("spells", [])
	var trainer_panel_ok := (
		trainer_shell != null
		and trainer_shell.visible
		and trainer_title != null
		and trainer_title.text == "Trainer"
		and trainer_body != null
		and trainer_spells.size() == 2
		and _control_tree_text_contains(trainer_body, "Trainer type 0")
		and _control_tree_text_contains(trainer_body, "Spell 6673")
		and _control_tree_text_contains(trainer_body, "available")
		and _control_tree_text_contains(trainer_body, "spell 6673 learned")
		and _control_tree_text_contains(trainer_body, "delta -0g 1s 0c")
	)
	_show_session_panel("social")
	var social_shell := _panel_shell("social")
	var social_title: Label = session_panels.get("social", {}).get("title", null)
	var social_body: VBoxContainer = session_panels.get("social", {}).get("body", null)
	var social_friends: Array = session_social_snapshot.get("friends", [])
	var social_party: Array = session_social_snapshot.get("party", [])
	var social_guild: Array = session_social_snapshot.get("guild", [])
	var social_invites: Array = session_social_snapshot.get("invites", [])
	var social_panel_ok := (
		social_shell != null
		and social_shell.visible
		and social_title != null
		and social_title.text == "Social"
		and social_body != null
		and social_friends.size() == 2
		and social_party.size() == 2
		and social_guild.size() == 1
		and social_invites.size() == 1
		and _control_tree_text_contains(social_body, "Friends 2")
		and _control_tree_text_contains(social_body, "Party leader: Codexstage")
		and _control_tree_text_contains(social_body, "Guild: Local Test Guild")
		and _control_tree_text_contains(social_body, "Localfriend")
		and _control_tree_text_contains(social_body, "Pendingbuddy")
	)
	_show_session_panel("mail")
	var mail_shell := _panel_shell("mail")
	var mail_title: Label = session_panels.get("mail", {}).get("title", null)
	var mail_body: VBoxContainer = session_panels.get("mail", {}).get("body", null)
	var mail_messages: Array = session_mail_snapshot.get("messages", [])
	var mail_panel_ok := (
		mail_shell != null
		and mail_shell.visible
		and mail_title != null
		and mail_title.text == "Mail"
		and mail_body != null
		and mail_messages.size() == 2
		and int(session_mail_snapshot.get("unread_count", 0)) == 1
		and _control_tree_text_contains(mail_body, "Mail rows: 2")
		and _control_tree_text_contains(mail_body, "Welcome bundle")
		and _control_tree_text_contains(mail_body, "Postmaster")
		and _control_tree_text_contains(mail_body, "attachments 1")
		and _control_tree_text_contains(mail_body, "COD 0g 0s 25c")
	)
	_show_session_panel("map")
	var map_shell := _panel_shell("map")
	var map_title: Label = session_panels.get("map", {}).get("title", null)
	var map_body: VBoxContainer = session_panels.get("map", {}).get("body", null)
	var map_panel_ok := (
		map_shell != null
		and map_shell.visible
		and map_title != null
		and map_title.text == "Map"
		and map_body != null
		and _control_tree_text_contains(map_body, "Map ID: 0")
		and _control_tree_text_contains(map_body, "Server position:")
	)
	_show_session_panel("options")
	var options_shell := _panel_shell("options")
	var options_title: Label = session_panels.get("options", {}).get("title", null)
	var options_panel_ok := (
		options_shell != null
		and options_shell.visible
		and options_title != null
		and options_title.text == "Options"
	)
	_show_session_panel("inventory")
	var inventory_shell := _panel_shell("inventory")
	var inventory_title: Label = session_panels.get("inventory", {}).get("title", null)
	var inventory_body: VBoxContainer = session_panels.get("inventory", {}).get("body", null)
	var inventory_grid_ok := false
	if inventory_body != null:
		for child in inventory_body.get_children():
			if child is GridContainer and child.get_child_count() == INVENTORY_SLOT_NAMES.size():
				inventory_grid_ok = true
				break
	var inventory_panel_ok := (
		inventory_shell != null
		and inventory_shell.visible
		and inventory_title != null
		and inventory_title.text == "Bags"
		and session_inventory_slots.size() == 3
		and session_coinage == 123456
		and _inventory_slot_state(_inventory_slot_at(23)) == "Packed Lunch x3"
		and inventory_grid_ok
	)
	var multi_panel_ok := (
		chat_shell != null
		and actions_shell != null
		and inventory_shell != null
		and chat_shell != actions_shell
		and chat_shell != inventory_shell
		and chat_shell.visible
		and actions_shell.visible
		and inventory_shell.visible
	)
	for panel_name in PANEL_NAMES:
		_hide_session_panel(panel_name)

	var marker_ok := (
		player_marker != null
		and player_marker.position.distance_to(_godot_position(-8949.95, -132.49, 83.53)) < 0.01
	)
	var hud_ok := detail_label.text.find("Codexstage") != -1 and visible_object_count == 3
	var actions_ok := action_buttons.size() == 17
	var shortcut_ok := (
		shortcut_slots.size() == 12
		and shortcut_slots[0].text.find("spell 78") != -1
		and shortcut_slots[2].text.find("item 6948") != -1
	)
	var input_ok := (
		no_target_key_ok
		and no_target_action_ok
		and no_target_interact_ok
		and target_key_ok
		and action_key_ok
		and interact_key_ok
	)
	var panel_ok := (
		chat_panel_ok
		and character_panel_ok
		and actions_panel_ok
		and targets_panel_ok
		and target_frame_ok
		and auras_panel_ok
		and spells_panel_ok
		and quests_panel_ok
		and loot_panel_ok
		and vendor_panel_ok
		and trainer_panel_ok
		and social_panel_ok
		and mail_panel_ok
		and map_panel_ok
		and quest_tracker_ok
		and options_panel_ok
		and inventory_panel_ok
		and multi_panel_ok
	)
	if marker_ok and hud_ok and actions_ok and shortcut_ok and input_ok and panel_ok:
		var self_test_message := (
			(
				"WORLD_SESSION_SELF_TEST_OK character=Codexstage map=0 "
				+ "actions=%s shortcuts=%s input=true panels=true "
				+ "chat=true character_panel=true inventory=true quests=true tracker=true "
				+ "auras_panel=true "
				+ "loot_panel=true vendor_panel=true trainer_panel=true social_panel=true mail_panel=true "
				+ "map_panel=true "
				+ "targets=true action_slots=true spellbook=true "
				+ "marker=(%.2f,%.2f,%.2f)"
			)
			% [
				str(action_buttons.size()),
				str(shortcut_slots.size()),
				player_marker.position.x,
				player_marker.position.y,
				player_marker.position.z,
			]
		)
		print(self_test_message)
		get_tree().quit(0)
		return

	var self_test_error := (
		(
			"WORLD_SESSION_SELF_TEST_FAILED marker_ok=%s hud_ok=%s "
			+ "actions_ok=%s shortcut_ok=%s input_ok=%s panel_ok=%s "
			+ "inventory_panel_ok=%s quest_tracker_ok=%s map_panel_ok=%s "
			+ "targets_panel_ok=%s target_frame_ok=%s character_panel_ok=%s "
			+ "auras_panel_ok=%s "
			+ "loot_panel_ok=%s vendor_panel_ok=%s trainer_panel_ok=%s social_panel_ok=%s "
			+ "mail_panel_ok=%s social_counts=%s/%s/%s/%s mail_count=%s"
		)
		% [
			str(marker_ok),
			str(hud_ok),
			str(actions_ok),
			str(shortcut_ok),
			str(input_ok),
			str(panel_ok),
			str(inventory_panel_ok),
			str(quest_tracker_ok),
			str(map_panel_ok),
			str(targets_panel_ok),
			str(target_frame_ok),
			str(character_panel_ok),
			str(auras_panel_ok),
			str(loot_panel_ok),
			str(vendor_panel_ok),
			str(trainer_panel_ok),
			str(social_panel_ok),
			str(mail_panel_ok),
			str(social_friends.size()),
			str(social_party.size()),
			str(social_guild.size()),
			str(social_invites.size()),
			str(mail_messages.size()),
		]
	)
	push_error(self_test_error)
	get_tree().quit(1)
