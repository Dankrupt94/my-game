extends SceneTree

const ClientObjectManager = preload("res://scripts/client_object_manager.gd")


func _init() -> void:
	var manager := ClientObjectManager.new()
	manager.apply_rows([
		{"guid": "creature-1", "kind": "creature"},
		{"guid": "gameobject-1", "kind": "gameobject"},
	])
	var summary := {
		"ok": manager.count() == 2
			and manager.count_by_kind("creature") == 1
			and manager.count_by_kind("gameobject") == 1,
		"count": manager.count(),
		"creatures": manager.count_by_kind("creature"),
		"gameobjects": manager.count_by_kind("gameobject"),
	}
	print(JSON.stringify(summary))
	quit(0 if bool(summary["ok"]) else 1)
