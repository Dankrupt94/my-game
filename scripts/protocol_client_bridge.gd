extends RefCounted

const HELPER_PATH := "res://native/protocol_client/build/acore_protocol_client"
const COMPAT_HELPER_PATH := "res://native/protocol_client/build-compat/acore_protocol_client"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/protocol-test-account.env"
const NATIVE_CLIENT_CLASS := "AcoreProtocolClient"


func run_character_flow(host: String = "127.0.0.1", port: String = "3724") -> Dictionary:
	var native_result := _run_native_character_flow(host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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

	var helper := _helper_path()
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

	var helper := _helper_path()
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


func move_heartbeat(
	character_name: String = "Codexstage",
	delta_x: float = 0.05,
	delta_y: float = 0.0,
	delta_orientation: float = 0.0,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_move_heartbeat(character_name, delta_x, delta_y, delta_orientation, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--move-heartbeat",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(delta_x),
			str(delta_y),
			str(delta_orientation),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_move_heartbeat_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("live_position_accepted", false))
	return parsed


func interact_with_npc(
	character_name: String = "Codexstage",
	target_entry: int = 823,
	target_name: String = "Nearby NPC",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_interact_with_npc(character_name, target_entry, target_name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--npc-interaction",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(target_entry),
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_npc_interaction_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("gossip_response_seen", false))
	return parsed


func combat_probe(
	character_name: String = "Codexstage",
	target_entry: int = 721,
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_combat_probe(character_name, target_entry, target_name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--combat-probe",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(target_entry),
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_combat_probe_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("combat_response_seen", false))
	return parsed


func chat_say(
	character_name: String = "Codexstage",
	message: String = "Codex Stage16 chat probe",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_chat_say(character_name, message, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--chat-say",
			host,
			port,
			str(credentials["account"]),
			character_name,
			message,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_chat_say_output(text)
	parsed["message"] = message
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("echoed_message_seen", false))
	return parsed


func chat_whisper_self(
	character_name: String = "Codexstage",
	message: String = "Codex Stage16 whisper probe",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_chat_whisper_self(character_name, message, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--chat-whisper-self",
			host,
			port,
			str(credentials["account"]),
			character_name,
			message,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_chat_whisper_self_output(text)
	parsed["message"] = message
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("echoed_message_seen", false))
	return parsed


func spellbook(
	character_name: String = "Codexstage",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_spellbook(character_name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--spellbook",
			host,
			port,
			str(credentials["account"]),
			character_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_spellbook_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("initial_spells_seen", false)) \
		and int(parsed.get("spell_count", 0)) > 0
	return parsed


func action_buttons(
	character_name: String = "Codexstage",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_action_buttons(character_name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--action-buttons",
			host,
			port,
			str(credentials["account"]),
			character_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_action_buttons_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("action_buttons_seen", false)) \
		and int(parsed.get("slot_count", 0)) == 144
	return parsed


func cast_spell(
	character_name: String = "Codexstage",
	spell_id: int = 2457,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_cast_spell(character_name, spell_id, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--cast-spell",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(spell_id),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_cast_spell_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("accepted", false))
	return parsed


func cast_spell_at_target(
	character_name: String = "Codexstage",
	spell_id: int = 78,
	target_entry: int = 721,
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_cast_spell_at_target(character_name, spell_id, target_entry, target_name, host, port)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
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
		PackedStringArray([
			"--cast-spell-target",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(spell_id),
			str(target_entry),
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_targeted_cast_spell_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("accepted", false))
	return parsed


func run_self_test() -> Dictionary:
	var helper := _helper_path()
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


func _run_native_move_heartbeat(
	character_name: String,
	delta_x: float,
	delta_y: float,
	delta_orientation: float,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("move_heartbeat"):
		return {}

	var result = client.call(
		"move_heartbeat",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		delta_x,
		delta_y,
		delta_orientation)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected movement result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_interact_with_npc(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("interact_with_npc"):
		return {}

	var result = client.call(
		"interact_with_npc",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_entry,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected interaction result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_combat_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("combat_probe"):
		return {}

	var result = client.call(
		"combat_probe",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_entry,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected combat result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_chat_say(
	character_name: String,
	message: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("chat_say"):
		return {}

	var result = client.call(
		"chat_say",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		message)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected chat result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_chat_whisper_self(
	character_name: String,
	message: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("chat_whisper_self"):
		return {}

	var result = client.call(
		"chat_whisper_self",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		message)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected whisper result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_spellbook(
	character_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("spellbook"):
		return {}

	var result = client.call(
		"spellbook",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected spellbook result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_action_buttons(
	character_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("action_buttons"):
		return {}

	var result = client.call(
		"action_buttons",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected action-button result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_cast_spell(
	character_name: String,
	spell_id: int,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("cast_spell"):
		return {}

	var result = client.call(
		"cast_spell",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		spell_id)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected cast-spell result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_cast_spell_at_target(
	character_name: String,
	spell_id: int,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("cast_spell_at_target"):
		return {}

	var result = client.call(
		"cast_spell_at_target",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		spell_id,
		target_entry,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected targeted cast result")

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


func _helper_path() -> String:
	var compat_helper := ProjectSettings.globalize_path(COMPAT_HELPER_PATH)
	if FileAccess.file_exists(compat_helper):
		return compat_helper
	return ProjectSettings.globalize_path(HELPER_PATH)


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


func _parse_move_heartbeat_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"movement_sent": false,
		"live_position_accepted": false,
		"saved_position_changed": false,
		"drift": 999.0,
		"live_drift": 999.0,
		"saved_drift": 999.0,
		"before": {},
		"target": {},
		"live": {},
		"after": {},
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("MOVE_STEP_SENT"):
			result["movement_sent"] = true
			result["character_name"] = _extract_quoted_field(line, "name=\"")
			result["before"] = _parse_vector_field(line, "before=(")
			result["target"] = _parse_vector_field(line, "target=(")
			result["live"] = _parse_vector_field(line, "live=(")
			result["after"] = _parse_vector_field(line, "after=(")
			result["drift"] = _extract_float_field(line, "drift=")
			result["live_drift"] = _extract_float_field(line, "live_drift=")
			result["saved_drift"] = _extract_float_field(line, "saved_drift=")
			result["live_position_accepted"] = _extract_int_field(line, "live_position_accepted=") == 1
			result["saved_position_changed"] = _extract_int_field(line, "saved_position_changed=") == 1
	return result


func _parse_npc_interaction_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"gossip_sent": false,
		"gossip_response_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"visible_object_count": 0,
		"response_opcode": 0,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("NPC_INTERACTION_SENT"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["gossip_sent"] = _extract_int_field(line, "gossip_sent=") == 1
			result["gossip_response_seen"] = _extract_int_field(line, "gossip_response_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
	return result


func _parse_combat_probe_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"attack_sent": false,
		"combat_response_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"visible_object_count": 0,
		"response_opcode": 0,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("COMBAT_PROBE_SENT"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["attack_sent"] = _extract_int_field(line, "attack_sent=") == 1
			result["combat_response_seen"] = _extract_int_field(line, "combat_response_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
	return result


func _parse_chat_say_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"message_sent": false,
		"chat_response_seen": false,
		"echoed_message_seen": false,
		"response_opcode": 0,
		"chat_type": 0,
		"language": 0,
		"sender_guid": "0x0",
		"receiver_guid": "0x0",
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("CHAT_SAY_SENT"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["message_sent"] = _extract_int_field(line, "message_sent=") == 1
			result["chat_response_seen"] = _extract_int_field(line, "chat_response_seen=") == 1
			result["echoed_message_seen"] = _extract_int_field(line, "echoed_message_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["chat_type"] = _extract_int_field(line, "chat_type=")
			result["language"] = _extract_int_field(line, "language=")
			result["sender_guid"] = _extract_token_after(line, "sender_guid=")
			result["receiver_guid"] = _extract_token_after(line, "receiver_guid=")
	return result


func _parse_chat_whisper_self_output(output: String) -> Dictionary:
	var result := _parse_chat_say_output("")
	result["whisper_seen"] = false
	result["whisper_inform_seen"] = false
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("CHAT_WHISPER_SELF_SENT"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["message_sent"] = _extract_int_field(line, "message_sent=") == 1
			result["chat_response_seen"] = _extract_int_field(line, "chat_response_seen=") == 1
			result["whisper_seen"] = _extract_int_field(line, "whisper_seen=") == 1
			result["whisper_inform_seen"] = _extract_int_field(line, "whisper_inform_seen=") == 1
			result["echoed_message_seen"] = _extract_int_field(line, "echoed_message_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["chat_type"] = _extract_int_field(line, "chat_type=")
			result["language"] = _extract_int_field(line, "language=")
			result["sender_guid"] = _extract_token_after(line, "sender_guid=")
			result["receiver_guid"] = _extract_token_after(line, "receiver_guid=")
	return result


func _parse_spellbook_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"initial_spells_seen": false,
		"logged_in_world": false,
		"spell_count": 0,
		"cooldown_count": 0,
		"spellbook_flags": 0,
		"spells": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("SPELLBOOK_SEEN"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["initial_spells_seen"] = _extract_int_field(line, "initial_spells_seen=") == 1
			result["logged_in_world"] = _extract_int_field(line, "logged_in_world=") == 1
			result["spellbook_flags"] = _extract_int_field(line, "flags=")
			result["spell_count"] = _extract_int_field(line, "spell_count=")
			result["cooldown_count"] = _extract_int_field(line, "cooldown_count=")
		elif line.begins_with("SPELL "):
			result["spells"].append({
				"id": _extract_int_field(line, "id="),
				"slot": _extract_int_field(line, "slot="),
			})
	return result


func _parse_action_buttons_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"action_buttons_seen": false,
		"logged_in_world": false,
		"state": 0,
		"slot_count": 0,
		"populated_count": 0,
		"buttons": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("ACTION_BUTTONS_SEEN"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["action_buttons_seen"] = _extract_int_field(line, "action_buttons_seen=") == 1
			result["logged_in_world"] = _extract_int_field(line, "logged_in_world=") == 1
			result["state"] = _extract_int_field(line, "state=")
			result["slot_count"] = _extract_int_field(line, "slot_count=")
			result["populated_count"] = _extract_int_field(line, "populated_count=")
		elif line.begins_with("ACTION_BUTTON "):
			result["buttons"].append({
				"button": _extract_int_field(line, "button="),
				"action": _extract_int_field(line, "action="),
				"type": _extract_int_field(line, "type="),
				"packed": _extract_hex_field(line, "packed=0x"),
				"populated": true,
			})
	return result


func _parse_cast_spell_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"cast_sent": false,
		"logged_in_world": false,
		"response_seen": false,
		"accepted": false,
		"spell_id": 0,
		"response_opcode": 0,
		"response_spell_id": 0,
		"cast_count": 0,
		"cast_flags": 0,
		"fail_reason": 0,
		"spell_start": false,
		"spell_go": false,
		"cast_failed": false,
		"spell_failure": false,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("SPELL_CAST_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["spell_id"] = _extract_int_field(line, "spell_id=")
			result["cast_sent"] = _extract_int_field(line, "cast_sent=") == 1
			result["logged_in_world"] = _extract_int_field(line, "logged_in_world=") == 1
			result["response_seen"] = _extract_int_field(line, "response_seen=") == 1
			result["accepted"] = _extract_int_field(line, "accepted=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["response_spell_id"] = _extract_int_field(line, "response_spell_id=")
			result["cast_count"] = _extract_int_field(line, "cast_count=")
			result["cast_flags"] = _extract_hex_field(line, "cast_flags=0x")
			result["fail_reason"] = _extract_int_field(line, "fail_reason=")
			result["spell_start"] = _extract_int_field(line, "spell_start=") == 1
			result["spell_go"] = _extract_int_field(line, "spell_go=") == 1
			result["cast_failed"] = _extract_int_field(line, "cast_failed=") == 1
			result["spell_failure"] = _extract_int_field(line, "spell_failure=") == 1
	return result


func _parse_targeted_cast_spell_output(output: String) -> Dictionary:
	var result := _parse_cast_spell_output("")
	result["target_guid"] = "0x0"
	result["target_entry"] = 0
	result["target_name"] = ""
	result["live_target_found"] = false
	result["selection_sent"] = false
	result["attack_sent"] = false
	result["visible_object_count"] = 0
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("TARGETED_SPELL_CAST_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["spell_id"] = _extract_int_field(line, "spell_id=")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["attack_sent"] = _extract_int_field(line, "attack_sent=") == 1
			result["cast_sent"] = _extract_int_field(line, "cast_sent=") == 1
			result["logged_in_world"] = _extract_int_field(line, "logged_in_world=") == 1
			result["response_seen"] = _extract_int_field(line, "response_seen=") == 1
			result["accepted"] = _extract_int_field(line, "accepted=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["response_spell_id"] = _extract_int_field(line, "response_spell_id=")
			result["cast_count"] = _extract_int_field(line, "cast_count=")
			result["cast_flags"] = _extract_hex_field(line, "cast_flags=0x")
			result["fail_reason"] = _extract_int_field(line, "fail_reason=")
			result["spell_start"] = _extract_int_field(line, "spell_start=") == 1
			result["spell_go"] = _extract_int_field(line, "spell_go=") == 1
			result["cast_failed"] = _extract_int_field(line, "cast_failed=") == 1
			result["spell_failure"] = _extract_int_field(line, "spell_failure=") == 1
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


func _parse_vector_field(line: String, marker: String) -> Dictionary:
	var pos_text := _extract_between(line, marker, ")")
	var parts := pos_text.split(",")
	if parts.size() != 3:
		return {}
	return {
		"x": float(parts[0]),
		"y": float(parts[1]),
		"z": float(parts[2]),
	}


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
