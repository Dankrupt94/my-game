extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")


func _init() -> void:
	var bridge := ProtocolClientBridge.new()
	var result: Dictionary = bridge.run_character_flow()
	var summary := {
		"ok": bool(result.get("ok", false)),
		"source": str(result.get("source", "")),
		"auth_flow_ok": bool(result.get("auth_flow_ok", false)),
		"world_auth_ok": bool(result.get("world_auth_ok", false)),
		"char_enum_ok": bool(result.get("char_enum_ok", false)),
		"character_count": int(result.get("character_count", -1)),
	}
	print(JSON.stringify(summary))
	quit(0 if bool(result.get("ok", false)) else 1)
