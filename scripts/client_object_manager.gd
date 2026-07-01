extends RefCounted

var objects := {}


func clear() -> void:
	objects.clear()


func upsert_object(data: Dictionary) -> void:
	var guid := str(data.get("guid", ""))
	if guid.is_empty():
		return
	objects[guid] = data.duplicate(true)


func remove_object(guid: String) -> void:
	objects.erase(guid)


func apply_rows(rows: Array) -> void:
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			upsert_object(row)


func all_objects() -> Array:
	var values := []
	for guid in objects.keys():
		values.append(objects[guid])
	return values


func count() -> int:
	return objects.size()


func count_by_kind(kind: String) -> int:
	var total := 0
	for value in objects.values():
		if typeof(value) == TYPE_DICTIONARY and str(value.get("kind", "")) == kind:
			total += 1
	return total
