extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")
const TEST_CHARACTER_NAME := "Codexstage"


func _init() -> void:
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.enter_world(TEST_CHARACTER_NAME)
	var login: Dictionary = result.get("login", {})
	var update: Dictionary = result.get("update", {})
	var summary := {
		"ok": bool(result.get("ok", false)),
		"source": str(result.get("source", "")),
		"world_login_ok": bool(result.get("world_login_ok", false)),
		"login_verify_ok": bool(result.get("login_verify_ok", false)),
		"map": int(login.get("map", -1)),
		"x": float(login.get("x", 0.0)),
		"y": float(login.get("y", 0.0)),
		"z": float(login.get("z", 0.0)),
		"update_object_seen": bool(update.get("seen", result.get("update_object_seen", false))),
	}
	if result.has("error"):
		summary["error"] = str(result["error"])
	print(JSON.stringify(summary))
	quit(0 if bool(result.get("ok", false)) else 1)
