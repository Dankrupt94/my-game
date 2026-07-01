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

	var credentials := _load_protocol_credentials(env_file)
	if not bool(credentials.get("ok", false)):
		return credentials

	var output: Array = []
	var exit_code := _execute_helper_with_password(
		helper,
		PackedStringArray(["--character-flow", host, port, str(credentials["account"])]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_character_flow_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("auth_flow_ok", false)) \
		and bool(parsed.get("world_auth_ok", false)) and bool(parsed.get("char_enum_ok", false))
	return parsed


func create_test_character(name: String = "Codexstage", host: String = "127.0.0.1", port: String = "3724") -> Dictionary:
	var native_result := _run_native_create_character(name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := ProjectSettings.globalize_path(HELPER_PATH)
	var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if not FileAccess.file_exists(helper):
		return _failure("Native protocol helper is not built yet: " + helper)
	if not FileAccess.file_exists(env_file):
		return _failure("Local protocol account file is missing: " + env_file)

	var credentials := _load_protocol_credentials(env_file)
	if not bool(credentials.get("ok", false)):
		return credentials

	var output: Array = []
	var exit_code := _execute_helper_with_password(
		helper,
		PackedStringArray(["--create-character", host, port, str(credentials["account"]), name]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_create_character_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("char_create_ok", false))
	return parsed


func enter_world(character_name: String = "", host: String = "127.0.0.1", port: String = "3724") -> Dictionary:
	var native_result := _run_native_enter_world(character_name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := ProjectSettings.globalize_path(HELPER_PATH)
	var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if not FileAccess.file_exists(helper):
		return _failure("Native protocol helper is not built yet: " + helper)
	if not FileAccess.file_exists(env_file):
		return _failure("Local protocol account file is missing: " + env_file)

	var credentials := _load_protocol_credentials(env_file)
	if not bool(credentials.get("ok", false)):
		return credentials

	var args := PackedStringArray(["--enter-world", host, port, str(credentials["account"])])
	if not character_name.is_empty():
		args.append(character_name)
	var output: Array = []
	var exit_code := _execute_helper_with_password(helper, args, str(credentials["password"]), output)
	var text := "\n".join(output)
	var parsed := _parse_enter_world_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("world_login_ok", false)) \
		and bool(parsed.get("login_verify_ok", false))
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


func _run_native_create_character(name: String, host: String, port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("create_character"):
		return {}

	var result = client.call(
		"create_character",
		host,
		port,
		credentials["account"],
		credentials["password"],
		name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected create-character result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_enter_world(character_name: String, host: String, port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("enter_world"):
		return {}

	var result = client.call(
		"enter_world",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected enter-world result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _load_native_credentials() -> Dictionary:
	if not ClassDB.class_exists(NATIVE_CLIENT_CLASS):
		return {"available": false, "result": {}}

	var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if not FileAccess.file_exists(env_file):
		return {"available": false, "result": _failure("Local protocol account file is missing: " + env_file)}

	var account_data := _read_protocol_account_file(env_file)
	var account := str(account_data.get("ACORE_PROTOCOL_ACCOUNT", ""))
	var password := str(account_data.get("ACORE_PROTOCOL_PASSWORD", ""))
	if account.is_empty() or password.is_empty():
		return {"available": false, "result": _failure("Local protocol account file is missing ACORE_PROTOCOL_ACCOUNT or ACORE_PROTOCOL_PASSWORD")}

	var client: Object = ClassDB.instantiate(NATIVE_CLIENT_CLASS)
	if client == null:
		return {"available": false, "result": _failure("Could not instantiate " + NATIVE_CLIENT_CLASS)}

	var self_test = client.call("self_test")
	if typeof(self_test) != TYPE_DICTIONARY or not bool(self_test.get("ok", false)):
		return {"available": false, "result": _failure("Native Godot protocol client self-test failed")}

	return {
		"available": true,
		"client": client,
		"account": account,
		"password": password,
	}


func _load_protocol_credentials(env_file: String) -> Dictionary:
	var account_data := _read_protocol_account_file(env_file)
	var account := str(account_data.get("ACORE_PROTOCOL_ACCOUNT", ""))
	var password := str(account_data.get("ACORE_PROTOCOL_PASSWORD", ""))
	if account.is_empty() or password.is_empty():
		return _failure("Local protocol account file is missing ACORE_PROTOCOL_ACCOUNT or ACORE_PROTOCOL_PASSWORD")
	return {
		"ok": true,
		"account": account,
		"password": password,
	}


func _execute_helper_with_password(helper: String, args: PackedStringArray, password: String, output: Array) -> int:
	OS.set_environment("ACORE_PROTOCOL_PASSWORD", password)
	var exit_code := OS.execute(helper, args, output, true, false)
	OS.set_environment("ACORE_PROTOCOL_PASSWORD", "")
	return exit_code


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


func _parse_create_character_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"char_create_ok": false,
		"character_count": -1,
		"characters": [],
		"response": -1,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("CHAR_CREATE_"):
			result["char_create_ok"] = line.begins_with("CHAR_CREATE_OK")
			result["response"] = _extract_hex_field(line, "response=0x")
		elif line.begins_with("CHAR_ENUM_OK"):
			result["character_count"] = _extract_count(line)
		elif line.begins_with("CHAR "):
			result["characters"].append(line)
	return result


func _parse_enter_world_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"world_login_ok": false,
		"login_verify_ok": false,
		"update_object_seen": false,
		"login": {},
		"character_line": "",
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("WORLD_LOGIN_OK"):
			result["world_login_ok"] = true
			result["character_line"] = line
			result["character_name"] = _extract_quoted_field(line, "name=\"")
		elif line.begins_with("LOGIN_VERIFY_WORLD_OK"):
			result["login_verify_ok"] = true
			result["login"] = _parse_login_verify_line(line)
		elif line.begins_with("UPDATE_OBJECT_"):
			result["update_object_seen"] = line.begins_with("UPDATE_OBJECT_SEEN")
			result["update_line"] = line
	return result


func _extract_count(line: String) -> int:
	var marker := "count="
	var start := line.find(marker)
	if start == -1:
		return -1
	var value := line.substr(start + marker.length()).strip_edges()
	return int(value)


func _extract_hex_field(line: String, marker: String) -> int:
	var start := line.find(marker)
	if start == -1:
		return -1
	var tail := line.substr(start + marker.length()).strip_edges()
	var end := tail.find(" ")
	if end != -1:
		tail = tail.substr(0, end)
	return tail.hex_to_int()


func _extract_quoted_field(line: String, marker: String) -> String:
	var start := line.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


func _parse_login_verify_line(line: String) -> Dictionary:
	var login := {
		"map": _extract_int_field(line, "map="),
		"x": 0.0,
		"y": 0.0,
		"z": 0.0,
		"orientation": _extract_float_field(line, "orientation="),
	}
	var pos_text := _extract_between(line, "pos=(", ")")
	var parts := pos_text.split(",")
	if parts.size() == 3:
		login["x"] = float(parts[0])
		login["y"] = float(parts[1])
		login["z"] = float(parts[2])
	return login


func _extract_int_field(line: String, marker: String) -> int:
	return int(_extract_token_after(line, marker))


func _extract_float_field(line: String, marker: String) -> float:
	return float(_extract_token_after(line, marker))


func _extract_token_after(line: String, marker: String) -> String:
	var start := line.find(marker)
	if start == -1:
		return "0"
	var tail := line.substr(start + marker.length()).strip_edges()
	var end := tail.find(" ")
	if end != -1:
		return tail.substr(0, end)
	return tail


func _extract_between(line: String, prefix: String, suffix: String) -> String:
	var start := line.find(prefix)
	if start == -1:
		return ""
	start += prefix.length()
	var end := line.find(suffix, start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"exit_code": -1,
		"output": message,
		"error": message,
	}
