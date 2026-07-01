extends RefCounted

const HELPER_PATH := "res://native/protocol_client/build/acore_protocol_client"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/protocol-test-account.env"
const NATIVE_CLIENT_CLASS := "AcoreProtocolClient"


func run_character_flow(host: String = "127.0.0.1", port: String = "3724") -> Dictionary:
	var native_result := _run_native_character_flow(host, port)
	if not native_result.is_empty():
		return native_result

	var helper := ProjectSettings.globalize_path(HELPER_PATH)
	var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if not FileAccess.file_exists(helper):
		return _failure("Native protocol helper is not built yet: " + helper)
	if not FileAccess.file_exists(env_file):
		return _failure("Local protocol account file is missing: " + env_file)

	var command := "set -a; . " + _shell_quote(env_file) + "; set +a; " \
		+ _shell_quote(helper) + " --character-flow " + _shell_quote(host) + " " + _shell_quote(port) + " \"$ACORE_PROTOCOL_ACCOUNT\""
	var output: Array = []
	var exit_code := OS.execute("/usr/bin/env", PackedStringArray(["bash", "-lc", command]), output, true, false)
	var text := "\n".join(output)
	var parsed := _parse_character_flow_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("auth_flow_ok", false)) \
		and bool(parsed.get("world_auth_ok", false)) and bool(parsed.get("char_enum_ok", false))
	return parsed


func run_self_test() -> Dictionary:
	var helper := ProjectSettings.globalize_path(HELPER_PATH)
	if not FileAccess.file_exists(helper):
		return _failure("Native protocol helper is not built yet: " + helper)

	var output: Array = []
	var exit_code := OS.execute(helper, PackedStringArray(["--self-test"]), output, true, false)
	var text := "\n".join(output)
	return {
		"ok": exit_code == 0 and text.contains("WORLD_PACKET_SELF_TEST_OK"),
		"exit_code": exit_code,
		"output": text.strip_edges(),
		"source": "helper process",
	}


func _run_native_character_flow(host: String, port: String) -> Dictionary:
	if not ClassDB.class_exists(NATIVE_CLIENT_CLASS):
		return {}

	var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if not FileAccess.file_exists(env_file):
		return _failure("Local protocol account file is missing: " + env_file)

	var account_data := _read_protocol_account_file(env_file)
	var account := str(account_data.get("ACORE_PROTOCOL_ACCOUNT", ""))
	var password := str(account_data.get("ACORE_PROTOCOL_PASSWORD", ""))
	if account.is_empty() or password.is_empty():
		return _failure("Local protocol account file is missing ACORE_PROTOCOL_ACCOUNT or ACORE_PROTOCOL_PASSWORD")

	var client: Object = ClassDB.instantiate(NATIVE_CLIENT_CLASS)
	if client == null:
		return _failure("Could not instantiate " + NATIVE_CLIENT_CLASS)

	var self_test = client.call("self_test")
	if typeof(self_test) != TYPE_DICTIONARY or not bool(self_test.get("ok", false)):
		return _failure("Native Godot protocol client self-test failed")

	var result = client.call("character_flow", host, port, account, password)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	if parsed.has("realm") and typeof(parsed["realm"]) == TYPE_DICTIONARY:
		parsed["realm_line"] = _format_realm_line(parsed["realm"])
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _read_protocol_account_file(path: String) -> Dictionary:
	var values := {}
	var text := FileAccess.get_file_as_string(path)
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var equals_index := line.find("=")
		if equals_index <= 0:
			continue
		var key := line.substr(0, equals_index).strip_edges()
		var value := line.substr(equals_index + 1).strip_edges()
		values[key] = _unquote_env_value(value)
	return values


func _unquote_env_value(value: String) -> String:
	if value.length() >= 2:
		var first := value.substr(0, 1)
		var last := value.substr(value.length() - 1, 1)
		if (first == "\"" and last == "\"") or (first == "'" and last == "'"):
			return value.substr(1, value.length() - 2)
	return value


func _format_realm_line(realm: Dictionary) -> String:
	return "AUTH_FLOW_OK realms=1 first_realm=\"" + str(realm.get("name", "")) + "\"" \
		+ " endpoint=\"" + str(realm.get("endpoint", "")) + "\"" \
		+ " realm_id=" + str(realm.get("realm_id", "?")) \
		+ " type=" + str(realm.get("type", "?")) \
		+ " lock=" + str(realm.get("lock", "?")) \
		+ " flags=0x" + _byte_hex(int(realm.get("flags", 0))) \
		+ " chars=" + str(realm.get("character_count", "?")) \
		+ " timezone=" + str(realm.get("timezone", "?"))


func _byte_hex(value: int) -> String:
	var text := "%02x" % [value & 0xFF]
	return text


func _redacted_result(result: Dictionary) -> Dictionary:
	var redacted := result.duplicate(true)
	redacted.erase("output")
	return redacted


func _parse_character_flow_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"world_auth_ok": false,
		"char_enum_ok": false,
		"character_count": -1,
		"characters": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line == "WORLD_AUTH_OK":
			result["world_auth_ok"] = true
		elif line.begins_with("CHAR_ENUM_OK"):
			result["char_enum_ok"] = true
			result["character_count"] = _extract_count(line)
		elif line.begins_with("CHAR "):
			result["characters"].append(line)
	return result


func _extract_count(line: String) -> int:
	var marker := "count="
	var start := line.find(marker)
	if start == -1:
		return -1
	var value := line.substr(start + marker.length()).strip_edges()
	return int(value)


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"exit_code": -1,
		"output": message,
		"error": message,
	}


func _shell_quote(value: String) -> String:
	return "'" + value.replace("'", "'\"'\"'") + "'"
