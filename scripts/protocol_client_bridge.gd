extends RefCounted

const HELPER_PATH := "res://native/protocol_client/build/acore_protocol_client"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/protocol-test-account.env"


func run_character_flow(host: String = "127.0.0.1", port: String = "3724") -> Dictionary:
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
	}


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
