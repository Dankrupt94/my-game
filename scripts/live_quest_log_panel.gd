extends VBoxContainer
## Numeric live quest-log panel backed by server-owned quest-log slot data.

var status_label: Label
var quest_list: ItemList
var detail_rows: VBoxContainer
var active_slots: Array = []
var selected_quest_id := 0
var built := false


func _ready() -> void:
	_build_panel()


func load_from_snapshot(snapshot: Dictionary, focus_quest_id: int = 0, source_label: String = "Quest log") -> void:
	var slots: Array = snapshot.get("slots", [])
	var seen := bool(snapshot.get("seen", false))
	var populated_count := int(snapshot.get("populated_count", slots.size()))
	load_from_slots(slots, seen, populated_count, focus_quest_id, source_label)


func load_from_slots(slots: Array, seen: bool = true, populated_count: int = -1, focus_quest_id: int = 0, source_label: String = "Quest log") -> void:
	_build_panel()
	active_slots.clear()
	for raw_slot in slots:
		if typeof(raw_slot) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = raw_slot
		if int(slot.get("quest_id", 0)) <= 0:
			continue
		active_slots.append(slot.duplicate(true))

	if populated_count < 0:
		populated_count = active_slots.size()

	quest_list.clear()
	for slot in active_slots:
		quest_list.add_item("Quest #%d  slot %d" % [
			int(slot.get("quest_id", 0)),
			int(slot.get("slot", 0)),
		])

	status_label.text = "%s: %s, %d active slot(s)" % [
		source_label,
		"observed" if seen else "not observed",
		populated_count,
	]

	if active_slots.is_empty():
		selected_quest_id = 0
		_render_empty_state(seen)
		return

	var select_idx := 0
	for idx in range(active_slots.size()):
		if int(active_slots[idx].get("quest_id", 0)) == focus_quest_id:
			select_idx = idx
			break
	quest_list.select(select_idx)
	_render_slot_detail(select_idx)


func get_active_count() -> int:
	return active_slots.size()


func get_selected_quest_id() -> int:
	return selected_quest_id


func get_summary_text() -> String:
	return status_label.text if status_label != null else ""


func _build_panel() -> void:
	if built:
		return
	built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Live Quest Log"
	title.modulate = Color(0.75, 0.82, 0.92)
	add_child(title)

	status_label = Label.new()
	status_label.text = "No quest-log snapshot loaded"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(260, 0)
	add_child(status_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	add_child(body)

	quest_list = ItemList.new()
	quest_list.custom_minimum_size = Vector2(170, 220)
	quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_list.item_selected.connect(_on_slot_selected)
	body.add_child(quest_list)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_scroll)

	detail_rows = VBoxContainer.new()
	detail_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_rows.add_theme_constant_override("separation", 5)
	detail_scroll.add_child(detail_rows)
	_render_empty_state(false)


func _on_slot_selected(index: int) -> void:
	_render_slot_detail(index)


func _render_empty_state(seen: bool) -> void:
	_clear_detail_rows()
	_add_detail_line("No active quest slots observed." if seen else "Quest log not observed yet.")
	_add_detail_line("Accepting a quest will refresh this panel from server-owned state.")


func _render_slot_detail(index: int) -> void:
	_clear_detail_rows()
	if index < 0 or index >= active_slots.size():
		selected_quest_id = 0
		_render_empty_state(true)
		return

	var slot: Dictionary = active_slots[index]
	selected_quest_id = int(slot.get("quest_id", 0))
	var counters := [
		int(slot.get("counter_1", 0)),
		int(slot.get("counter_2", 0)),
		int(slot.get("counter_3", 0)),
		int(slot.get("counter_4", 0)),
	]

	_add_detail_line("Quest #%d" % selected_quest_id, Color(0.92, 0.9, 0.7))
	_add_detail_line("Slot %d" % int(slot.get("slot", 0)))
	_add_detail_line("State flags 0x%x" % int(slot.get("state", 0)))
	_add_detail_line("Counters %d / %d / %d / %d" % counters)
	_add_detail_line("Timer %d" % int(slot.get("time_left", 0)))

	var tracker := "Tracker rows:"
	for counter_idx in range(counters.size()):
		tracker += "\n  Objective %d: %d" % [counter_idx + 1, counters[counter_idx]]
	_add_detail_line(tracker)


func _add_detail_line(text: String, color: Color = Color(0.86, 0.88, 0.9)) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_rows.add_child(label)


func _clear_detail_rows() -> void:
	for child in detail_rows.get_children():
		detail_rows.remove_child(child)
		child.queue_free()
