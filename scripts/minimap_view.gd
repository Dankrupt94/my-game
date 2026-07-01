extends Control

const DASHBOARD_SCENE := "res://main.tscn"

# Radar properties
const RADAR_RADIUS := 110.0
const RADAR_CENTER := Vector2(200, 200)

var player_pos := Vector3(0, 0, 0)
var player_rot := 0.0 # orientation in radians (0 = North/East)
var zoom_level := 1.0 # 1.0 = standard, 2.0 = zoomed in, 0.5 = zoomed out
var tracking_filter := "All"

var zone_name := "Elwynn Forest"
var subzone_name := "Goldshire"

var object_manager_ref: RefCounted = null
var status_label: Label
var zone_label: Label
var coords_label: Label
var filter_option: OptionButton
var radar_canvas: Control

# Custom drawing colors
const COLOR_BG := Color(0.04, 0.06, 0.08, 0.85)
const COLOR_BORDER := Color(0.85, 0.72, 0.45) # Gold
const COLOR_GRID := Color(0.2, 0.25, 0.3, 0.4)
const COLOR_PLAYER := Color(0.1, 0.6, 1.0)
const COLOR_HOSTILE := Color(0.9, 0.15, 0.15)
const COLOR_NEUTRAL := Color(0.9, 0.8, 0.15)
const COLOR_FRIENDLY := Color(0.15, 0.8, 0.15)
const COLOR_GAMEOBJECT := Color(0.15, 0.5, 0.9)


func _ready() -> void:
	_build_view()
	_load_mock_data()
	
	if OS.get_environment("ACORE_MINIMAP_SELF_TEST") == "1":
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

	var h_split := HBoxContainer.new()
	h_split.add_theme_constant_override("separation", 24)
	margin.add_child(h_split)

	# Left Panel: Radar viewport container
	var radar_container := Control.new()
	radar_container.custom_minimum_size = Vector2(400, 400)
	h_split.add_child(radar_container)
	
	# Radar drawing node
	radar_canvas = Control.new()
	radar_canvas.name = "RadarCanvas"
	radar_canvas.custom_minimum_size = Vector2(400, 400)
	radar_canvas.draw.connect(_on_radar_draw)
	radar_container.add_child(radar_canvas)

	# Right Panel: Stats, controls and logs
	var controls_panel := VBoxContainer.new()
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_panel.add_theme_constant_override("separation", 16)
	h_split.add_child(controls_panel)

	# Headers
	var header := VBoxContainer.new()
	controls_panel.add_child(header)

	var title := Label.new()
	title.text = "Minimap & Navigation"
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Radar engine active"
	status_label.modulate = Color(0.6, 0.7, 0.8)
	header.add_child(status_label)

	# Zone info card
	var card := PanelContainer.new()
	controls_panel.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 14)
	card_margin.add_theme_constant_override("margin_top", 12)
	card_margin.add_theme_constant_override("margin_right", 14)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(card_margin)

	var card_stack := VBoxContainer.new()
	card_stack.add_theme_constant_override("separation", 6)
	card_margin.add_child(card_stack)

	zone_label = Label.new()
	zone_label.text = zone_name + " - " + subzone_name
	zone_label.add_theme_font_size_override("font_size", 20)
	card_stack.add_child(zone_label)

	coords_label = Label.new()
	coords_label.text = "Coordinates: (0.00, 0.00, 0.00)"
	coords_label.modulate = COLOR_BORDER
	card_stack.add_child(coords_label)

	# Controls row
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 12)
	controls_panel.add_child(controls_row)

	# Zoom
	var zoom_lbl := Label.new()
	zoom_lbl.text = "Zoom:"
	controls_row.add_child(zoom_lbl)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(36, 32)
	zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
	controls_row.add_child(zoom_in_btn)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(36, 32)
	zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
	controls_row.add_child(zoom_out_btn)

	# Filter dropdown
	var filter_lbl := Label.new()
	filter_lbl.text = "Track:"
	controls_row.add_child(filter_lbl)

	filter_option = OptionButton.new()
	filter_option.add_item("All")
	filter_option.add_item("Monsters")
	filter_option.add_item("NPCs")
	filter_option.add_item("GameObjects")
	filter_option.custom_minimum_size = Vector2(140, 32)
	filter_option.item_selected.connect(_on_filter_selected)
	controls_row.add_child(filter_option)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_panel.add_child(spacer)

	# Actions
	var actions_row := HBoxContainer.new()
	controls_panel.add_child(actions_row)

	var back_btn := Button.new()
	back_btn.text = "Back to Dashboard"
	back_btn.custom_minimum_size = Vector2(160, 38)
	back_btn.pressed.connect(_on_back_pressed)
	actions_row.add_child(back_btn)


func _load_mock_data() -> void:
	# Build static simulated visible entities in case object manager is empty
	object_manager_ref = RefCounted.new()
	object_manager_ref.set_script(preload("res://scripts/client_object_manager.gd"))
	
	player_pos = Vector3(-9000.0, 100.0, 50.0)
	player_rot = -1.2 # ~68 degrees rotation
	
	# Add mock entities relative to player position
	object_manager_ref.upsert_object({
		"guid": "creature-1",
		"kind": "unit",
		"name": "Kobold Vermin",
		"x": player_pos.x + 30.0,
		"y": player_pos.y + 10.0,
		"health": 80,
		"max_health": 80,
		"reaction": "hostile"
	})
	
	object_manager_ref.upsert_object({
		"guid": "creature-2",
		"kind": "unit",
		"name": "Marshal Dughan",
		"x": player_pos.x - 20.0,
		"y": player_pos.y + 40.0,
		"health": 12000,
		"max_health": 12000,
		"reaction": "friendly"
	})

	object_manager_ref.upsert_object({
		"guid": "gameobject-1",
		"kind": "gameobject",
		"name": "Copper Vein",
		"x": player_pos.x + 5.0,
		"y": player_pos.y - 15.0,
		"health": 1,
		"max_health": 1
	})


func _on_zoom_in_pressed() -> void:
	zoom_level = clamp(zoom_level * 1.5, 0.25, 4.0)
	status_label.text = "Zoom adjusted: " + str(snapped(zoom_level, 0.01)) + "x"
	if radar_canvas != null:
		radar_canvas.queue_redraw()


func _on_zoom_out_pressed() -> void:
	zoom_level = clamp(zoom_level / 1.5, 0.25, 4.0)
	status_label.text = "Zoom adjusted: " + str(snapped(zoom_level, 0.01)) + "x"
	if radar_canvas != null:
		radar_canvas.queue_redraw()


func _on_filter_selected(idx: int) -> void:
	tracking_filter = filter_option.get_item_text(idx)
	status_label.text = "Tracking filter: " + tracking_filter
	if radar_canvas != null:
		radar_canvas.queue_redraw()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _on_radar_draw() -> void:
	var canvas := radar_canvas
	
	# Draw radar face circular background
	canvas.draw_circle(RADAR_CENTER, RADAR_RADIUS, COLOR_BG)
	canvas.draw_circle(RADAR_CENTER, RADAR_RADIUS, COLOR_BORDER, false, 2.0)

	# Draw concentric range circles (grid lines)
	canvas.draw_circle(RADAR_CENTER, RADAR_RADIUS * 0.33, COLOR_GRID, false, 1.0)
	canvas.draw_circle(RADAR_CENTER, RADAR_RADIUS * 0.66, COLOR_GRID, false, 1.0)

	# Draw cardinal cross lines
	canvas.draw_line(RADAR_CENTER - Vector2(RADAR_RADIUS, 0), RADAR_CENTER + Vector2(RADAR_RADIUS, 0), COLOR_GRID, 1.0)
	canvas.draw_line(RADAR_CENTER - Vector2(0, RADAR_RADIUS), RADAR_CENTER + Vector2(0, RADAR_RADIUS), COLOR_GRID, 1.0)

	# Draw cardinal labels (N, S, E, W)
	var font := get_theme_font("font")
	var font_size := 12
	canvas.draw_string(font, RADAR_CENTER + Vector2(-5, -RADAR_RADIUS + 14), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_BORDER)
	canvas.draw_string(font, RADAR_CENTER + Vector2(-5, RADAR_RADIUS - 4), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_BORDER)
	canvas.draw_string(font, RADAR_CENTER + Vector2(RADAR_RADIUS - 12, 4), "E", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_BORDER)
	canvas.draw_string(font, RADAR_CENTER + Vector2(-RADAR_RADIUS + 4, 4), "W", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_BORDER)

	# Render entities
	if object_manager_ref != null:
		coords_label.text = "Coordinates: (%.2f, %.2f, %.2f)" % [player_pos.x, player_pos.y, player_pos.z]
		var entities = object_manager_ref.all_objects()
		for entity in entities:
			_draw_entity_on_radar(canvas, entity)

	# Draw player marker (centered arrow facing straight up because we rotate the map relative to player_rot)
	var arrow_vertices := PackedVector2Array([
		RADAR_CENTER + Vector2(0, -10), # Tip
		RADAR_CENTER + Vector2(6, 6),   # Bottom Right
		RADAR_CENTER + Vector2(0, 2),   # Center inset
		RADAR_CENTER + Vector2(-6, 6)   # Bottom Left
	])
	canvas.draw_polygon(arrow_vertices, PackedColorArray([COLOR_PLAYER]))
	canvas.draw_polyline(arrow_vertices, COLOR_BORDER, 1.0)


func _draw_entity_on_radar(canvas: Control, entity: Dictionary) -> void:
	var kind := str(entity.get("kind", ""))
	var reaction := str(entity.get("reaction", "neutral"))
	
	# Apply filter checks
	if tracking_filter == "Monsters" and (kind != "unit" or reaction != "hostile"):
		return
	if tracking_filter == "NPCs" and (kind != "unit" or reaction == "hostile"):
		return
	if tracking_filter == "GameObjects" and kind != "gameobject":
		return

	var ex := float(entity.get("x", 0.0))
	var ey := float(entity.get("y", 0.0))

	# Translate world offsets to radar space
	# In WoW: +X is North (up), +Y is West (left).
	var dx := ex - player_pos.x
	var dy := ey - player_pos.y

	# Calculate distance
	var dist := sqrt(dx*dx + dy*dy)
	
	# Calculate angle relative to player's facing direction
	# player_rot is the angle of facing in radians
	var entity_angle := atan2(dy, dx)
	var relative_angle := entity_angle - player_rot - PI/2.0

	# Calculate pixel distance based on zoom level (base scale: 2.0 pixels per yard at zoom_level 1.0)
	var pixel_distance := dist * 2.0 * zoom_level
	
	# Clamp inside the radar circle border
	if pixel_distance > RADAR_RADIUS - 4:
		# Optionally hide or clip. Let's not render dots out of bounds.
		return

	# Calculate final pixel offset coordinate
	var offset := Vector2(cos(relative_angle), sin(relative_angle)) * pixel_distance
	var dot_center := RADAR_CENTER + offset

	# Determine color
	var color := COLOR_NEUTRAL
	if kind == "gameobject":
		color = COLOR_GAMEOBJECT
	elif reaction == "hostile":
		color = COLOR_HOSTILE
	elif reaction == "friendly":
		color = COLOR_FRIENDLY

	canvas.draw_circle(dot_center, 5.0, color)
	canvas.draw_circle(dot_center, 5.0, Color.BLACK, false, 1.0)


# Math verification translation function for the self-test
func get_radar_pixel_offset(ex: float, ey: float) -> Vector2:
	var dx := ex - player_pos.x
	var dy := ey - player_pos.y
	var dist := sqrt(dx*dx + dy*dy)
	
	var entity_angle := atan2(dy, dx)
	var relative_angle := entity_angle - player_rot - PI/2.0
	var pixel_distance := dist * 2.0 * zoom_level
	
	return Vector2(cos(relative_angle), sin(relative_angle)) * pixel_distance


# Headless Self-Test Runner
func _run_self_test() -> void:
	print("MINIMAP_SELF_TEST: starting verification...")
	
	# 1. Verify rotation and offset translations
	# Place an entity 30 yards directly North of the player (ex = player_pos.x + 30)
	# Player is facing straight North (player_rot = 0)
	player_pos = Vector3(100.0, 200.0, 0.0)
	player_rot = 0.0 # Facing North
	zoom_level = 1.0
	
	# In WoW coords: North is +X. Let's place creature at (130, 200)
	var offset := get_radar_pixel_offset(130.0, 200.0)
	
	# If player is facing North, a creature directly North must appear directly UP on the radar screen
	# UP means offset.y should be negative and offset.x should be zero
	print("MINIMAP_SELF_TEST: offset North (faced North) = ", offset)
	if abs(offset.x) > 0.01 or offset.y >= 0:
		_fail_self_test("Coordinate offset alignment failure for facing North")
		return
	
	# Verify distance matches scale: 30 yards * 2 pixels/yard = 60 pixels
	if abs(abs(offset.y) - 60.0) > 0.1:
		_fail_self_test("Minimap pixel offset distance scale mismatch")
		return

	# 2. Verify zoom scaling
	zoom_level = 2.0 # Zoom in by 2.0
	var offset_zoomed := get_radar_pixel_offset(130.0, 200.0)
	print("MINIMAP_SELF_TEST: offset North (zoomed 2.0) = ", offset_zoomed)
	if abs(abs(offset_zoomed.y) - 120.0) > 0.1:
		_fail_self_test("Zoom scaling was not correctly applied to coordinate distance")
		return

	# 3. Verify rotation translation
	player_rot = -PI / 2.0 # Rotated 90 degrees left (West)
	var offset_rotated := get_radar_pixel_offset(130.0, 200.0)
	# If creature is directly North, and player rotates 90 degrees left, the creature must appear to the RIGHT on the radar
	# RIGHT means offset.x is positive, offset.y is zero
	print("MINIMAP_SELF_TEST: offset North (faced West) = ", offset_rotated)
	if offset_rotated.x <= 0 or abs(offset_rotated.y) > 0.1:
		_fail_self_test("Rotational coordinate translation failed")
		return

	print("MINIMAP_SELF_TEST_OK: radar coordinates offset, distance scale, and rotational translations passed.")
	get_tree().quit(0)


func _fail_self_test(reason: String) -> void:
	push_error("MINIMAP_SELF_TEST_FAILED: " + reason)
	get_tree().quit(1)
