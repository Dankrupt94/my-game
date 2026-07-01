extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")
const TEST_CHARACTER_NAME := "Codexstage"


func _init() -> void:
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.move_heartbeat(TEST_CHARACTER_NAME, 0.20, 0.0, 0.0)
	var summary := {
		"ok": bool(result.get("ok", false)),
		"source": str(result.get("source", "")),
		"movement_sent": bool(result.get("movement_sent", false)),
		"live_position_accepted": bool(result.get("live_position_accepted", false)),
		"saved_position_changed": bool(result.get("saved_position_changed", false)),
		"drift": float(result.get("drift", 999.0)),
		"live_drift": float(result.get("live_drift", result.get("drift", 999.0))),
		"saved_drift": float(result.get("saved_drift", 999.0)),
	}
	if result.has("error"):
		summary["error"] = str(result["error"])
	print(JSON.stringify(summary))
	quit(0 if bool(result.get("ok", false)) else 1)
