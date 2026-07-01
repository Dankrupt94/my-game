extends SceneTree


func _init() -> void:
	if not ClassDB.class_exists("AcoreProtocolClient"):
		print("ACORE_PROTOCOL_EXTENSION_MISSING")
		quit(1)
		return

	var client: Object = ClassDB.instantiate("AcoreProtocolClient")
	if client == null:
		print("ACORE_PROTOCOL_EXTENSION_INSTANTIATE_FAILED")
		quit(1)
		return

	var result: Dictionary = client.self_test()
	print(JSON.stringify(result))
	if not bool(result.get("ok", false)):
		quit(1)
		return

	var account := OS.get_environment("ACORE_PROTOCOL_ACCOUNT")
	var password := OS.get_environment("ACORE_PROTOCOL_PASSWORD")
	if account.is_empty() or password.is_empty():
		print("CHARACTER_FLOW_SKIPPED missing ACORE_PROTOCOL_ACCOUNT or ACORE_PROTOCOL_PASSWORD")
		quit(0)
		return

	var host := OS.get_environment("ACORE_PROTOCOL_HOST")
	if host.is_empty():
		host = "127.0.0.1"
	var port := OS.get_environment("ACORE_PROTOCOL_PORT")
	if port.is_empty():
		port = "3724"

	var flow: Dictionary = client.character_flow(host, port, account, password)
	print(JSON.stringify(flow))
	quit(0 if bool(flow.get("ok", false)) else 1)
