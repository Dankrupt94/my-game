extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const CHARACTER_NAME := "Codexstage"
const OBJECT_TYPE_UNIT := 3


func _init() -> void:
	var bridge := ProtocolClientBridge.new()
	var result := bridge.visible_targets_snapshot(CHARACTER_NAME)
	if not bool(result.get("ok", false)):
		push_error("TARGET_REPORT_FAILED: " + str(result.get("error", result)))
		quit(1)
		return

	var login: Dictionary = result.get("login", {})
	var update: Dictionary = result.get("update", {})
	var objects: Array = []
	if typeof(update.get("visible_objects", [])) == TYPE_ARRAY and not update.get("visible_objects", []).is_empty():
		objects = update.get("visible_objects", [])
	elif typeof(result.get("visible_objects", [])) == TYPE_ARRAY:
		objects = result.get("visible_objects", [])

	var rows: Array = []
	var seen := {}
	for object in objects:
		if typeof(object) != TYPE_DICTIONARY:
			continue
		var guid := str(object.get("guid", "")).strip_edges()
		if guid.is_empty() or seen.has(guid):
			continue
		seen[guid] = true
		if int(object.get("object_type", object.get("type", 0))) != OBJECT_TYPE_UNIT:
			continue
		if not bool(object.get("has_position", false)):
			continue
		var row: Dictionary = object.duplicate(true)
		row["distance"] = _distance_from_login(login, object)
		rows.append(row)

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _target_sort_score(a) < _target_sort_score(b))

	print("TARGET_REPORT_OK count=%s" % [str(rows.size())])
	for index in range(min(rows.size(), 30)):
		var row: Dictionary = rows[index]
		print("TARGET_REPORT_ROW index=%s score=%.3f guid=%s entry=%s distance=%.2f health=%s/%s unit_flags=0x%s dynamic_flags=0x%s" % [
			str(index),
			_target_sort_score(row),
			str(row.get("guid", "")),
			str(row.get("entry", 0)),
			float(row.get("distance", 0.0)),
			str(row.get("health", 0)) if bool(row.get("health_seen", false)) else "?",
			str(row.get("max_health", 0)) if bool(row.get("max_health_seen", false)) else "?",
			"%x" % [int(row.get("unit_flags", 0))],
			"%x" % [int(row.get("dynamic_flags", 0))],
		])
	quit(0)


func _target_sort_score(target: Dictionary) -> float:
	var score := float(target.get("distance", 999999.0))
	if not bool(target.get("health_seen", false)):
		score += 5000.0
	elif int(target.get("health", 0)) <= 0:
		score += 10000.0
	if bool(target.get("max_health_seen", false)):
		score += float(target.get("max_health", 0)) * 0.05
	return score


func _distance_from_login(login: Dictionary, object: Dictionary) -> float:
	if login.is_empty():
		return 0.0
	var dx := float(object.get("x", 0.0)) - float(login.get("x", 0.0))
	var dy := float(object.get("y", 0.0)) - float(login.get("y", 0.0))
	var dz := float(object.get("z", 0.0)) - float(login.get("z", 0.0))
	return sqrt(dx * dx + dy * dy + dz * dz)
