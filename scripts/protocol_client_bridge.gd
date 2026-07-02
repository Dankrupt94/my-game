extends RefCounted

const HELPER_PATH := "res://native/protocol_client/build/acore_protocol_client"
const COMPAT_HELPER_PATH := "res://native/protocol_client/build-compat/acore_protocol_client"
const LOCAL_ACCOUNT_ENV := "res://local_runtime/protocol-test-account.env"
const NATIVE_CLIENT_CLASS := "AcoreProtocolClient"


func run_character_flow(host: String = "127.0.0.1", port: String = "3724", account: String = "", password: String = "") -> Dictionary:
	var native_result := _run_native_character_flow(host, port, account, password)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
	if not FileAccess.file_exists(helper):
		return _failure("Native protocol helper is not built yet: " + helper)

	var credentials := _resolve_credentials(account, password)
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


func enter_world(character_name: String = "", host: String = "127.0.0.1", port: String = "3724", account: String = "", password: String = "") -> Dictionary:
	var native_result := _run_native_enter_world(character_name, host, port, account, password)
	if not native_result.is_empty():
		return native_result

	var helper := _helper_path()
	if not FileAccess.file_exists(helper):
		return _failure("Native protocol helper is not built yet: " + helper)

	var credentials := _resolve_credentials(account, password)
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


func visible_targets_snapshot(character_name: String = "Codexstage", host: String = "127.0.0.1", port: String = "3724") -> Dictionary:
	var native_result := _run_native_visible_targets_snapshot(character_name, host, port)
	if not native_result.is_empty():
		return native_result
	return enter_world(character_name, host, port)


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


func trainer_list_probe(
	character_name: String = "Codexstage",
	target_entry: int = 911,
	target_name: String = "Nearby Trainer",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return trainer_list_probe_selector(character_name, str(target_entry), target_name, host, port)


func trainer_list_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "911",
	target_name: String = "Nearby Trainer",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_trainer_list_probe_selector(character_name, target_selector, target_name, host, port)
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
			"--trainer-list",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_trainer_list_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("trainer_list_response_seen", false)) \
		and int(parsed.get("spell_count", 0)) > 0
	return parsed


func questgiver_list_probe(
	character_name: String = "Codexstage",
	target_entry: int = 823,
	target_name: String = "Nearby Quest Giver",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return questgiver_list_probe_selector(character_name, str(target_entry), target_name, host, port)


func questgiver_list_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "823",
	target_name: String = "Nearby Quest Giver",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_questgiver_list_probe_selector(character_name, target_selector, target_name, host, port)
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
			"--questgiver-list",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_questgiver_list_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and int(parsed.get("quest_count", 0)) > 0
	return parsed


func questgiver_accept_probe(
	character_name: String = "Codexstage",
	target_entry: int = 823,
	quest_id: int = 783,
	target_name: String = "Nearby Quest Giver",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return questgiver_accept_probe_selector(character_name, str(target_entry), quest_id, target_name, host, port)


func questgiver_accept_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "823",
	quest_id: int = 783,
	target_name: String = "Nearby Quest Giver",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_questgiver_accept_probe_selector(character_name, target_selector, quest_id, target_name, host, port)
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
			"--questgiver-accept",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			str(quest_id),
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_questgiver_accept_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 \
		and bool(parsed.get("quest_in_log_after_accept", false)) \
		and bool(parsed.get("quest_removed_after_remove", false))
	return parsed


func trainer_buy_spell_probe(
	character_name: String = "Codexstage",
	target_entry: int = 911,
	target_name: String = "Nearby Trainer",
	spell_id: int = 6673,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return trainer_buy_spell_probe_selector(character_name, str(target_entry), target_name, spell_id, host, port)


func trainer_buy_spell_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "911",
	target_name: String = "Nearby Trainer",
	spell_id: int = 6673,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_trainer_buy_spell_probe_selector(character_name, target_selector, target_name, spell_id, host, port)
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
			"--trainer-buy",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
			str(spell_id),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_trainer_buy_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("buy_response_seen", false))
	return parsed


func vendor_list_probe(
	character_name: String = "Codexstage",
	target_entry: int = 1213,
	target_name: String = "Nearby Vendor",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return vendor_list_probe_selector(character_name, str(target_entry), target_name, host, port)


func vendor_list_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "1213",
	target_name: String = "Nearby Vendor",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_vendor_list_probe_selector(character_name, target_selector, target_name, host, port)
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
			"--vendor-list",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_vendor_list_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("vendor_list_response_seen", false)) \
		and int(parsed.get("item_count", 0)) > 0
	return parsed


func vendor_buy_sell_probe(
	character_name: String = "Codexstage",
	target_entry: int = 1213,
	target_name: String = "Nearby Vendor",
	vendor_slot: int = 8,
	item_id: int = 17184,
	count: int = 1,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return vendor_buy_sell_probe_selector(character_name, str(target_entry), target_name, vendor_slot, item_id, count, host, port)


func vendor_buy_sell_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "1213",
	target_name: String = "Nearby Vendor",
	vendor_slot: int = 8,
	item_id: int = 17184,
	count: int = 1,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_vendor_buy_sell_probe_selector(
		character_name,
		target_selector,
		target_name,
		vendor_slot,
		item_id,
		count,
		host,
		port)
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
			"--vendor-buy-sell",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
			str(vendor_slot),
			str(item_id),
			str(count),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_vendor_buy_sell_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("roundtrip_confirmed", false))
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
	parsed["ok"] = exit_code == 0 and bool(parsed.get("attacker_state_update_seen", false))
	return parsed


func loot_open_probe(
	character_name: String = "Codexstage",
	target_entry: int = 38,
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return loot_open_probe_selector(character_name, str(target_entry), target_name, host, port)


func loot_open_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "38",
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_loot_open_probe_selector(character_name, target_selector, target_name, host, port)
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
			"--loot-open-probe",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_loot_open_probe_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("loot_open_sent", false)) \
		and (bool(parsed.get("loot_response_seen", false)) or bool(parsed.get("loot_release_response_seen", false)))
	return parsed


func corpse_loot_probe(
	character_name: String = "Codexstage",
	target_entry: int = 299,
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return corpse_loot_probe_selector(character_name, str(target_entry), target_name, host, port)


func corpse_loot_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "299",
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_corpse_loot_probe_selector(character_name, target_selector, target_name, host, port)
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
			"--corpse-loot-probe",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_corpse_loot_probe_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	var money_ok := int(parsed.get("gold", 0)) == 0 or bool(parsed.get("loot_money_notify_seen", false))
	var item_ok := int(parsed.get("item_count", 0)) == 0 or int(parsed.get("loot_item_removed_count", 0)) > 0
	parsed["ok"] = exit_code == 0 and bool(parsed.get("target_dead_seen", false)) \
		and bool(parsed.get("loot_response_seen", false)) and not bool(parsed.get("loot_error", false)) \
		and money_ok and item_ok and bool(parsed.get("loot_release_response_seen", false))
	return parsed


func loot_inventory_handoff_probe(
	character_name: String = "Codexstage",
	target_entry: int = 299,
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	return loot_inventory_handoff_probe_selector(character_name, str(target_entry), target_name, host, port)


func loot_inventory_handoff_probe_selector(
	character_name: String = "Codexstage",
	target_selector: String = "299",
	target_name: String = "Nearby Creature",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_loot_inventory_handoff_probe_selector(character_name, target_selector, target_name, host, port)
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
			"--loot-inventory-handoff",
			host,
			port,
			str(credentials["account"]),
			character_name,
			target_selector,
			target_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_loot_inventory_handoff_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("handoff_confirmed", false))
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


func inventory_snapshot(
	character_name: String = "Codexstage",
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_inventory_snapshot(character_name, host, port)
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
			"--inventory-snapshot",
			host,
			port,
			str(credentials["account"]),
			character_name,
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_inventory_snapshot_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("inventory_seen", false)) \
		and int(parsed.get("slot_count", 0)) == 39
	return parsed


func swap_inventory_slots(
	character_name: String = "Codexstage",
	source_slot: int = 23,
	destination_slot: int = 25,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_swap_inventory_slots(character_name, source_slot, destination_slot, host, port)
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
			"--swap-inventory-slots",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(source_slot),
			str(destination_slot),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_inventory_swap_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("swap_confirmed", false)) \
		and bool(parsed.get("restore_confirmed", false))
	return parsed


func split_inventory_stack(
	character_name: String = "Codexstage",
	source_slot: int = 23,
	destination_slot: int = 25,
	split_count: int = 1,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_split_inventory_stack(character_name, source_slot, destination_slot, split_count, host, port)
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
			"--split-inventory-stack",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(source_slot),
			str(destination_slot),
			str(split_count),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_inventory_split_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("split_confirmed", false)) \
		and bool(parsed.get("merge_confirmed", false))
	return parsed


func set_action_button(
	character_name: String = "Codexstage",
	button: int = 0,
	action: int = 78,
	action_type: int = 0,
	host: String = "127.0.0.1",
	port: String = "3724") -> Dictionary:
	var native_result := _run_native_set_action_button(character_name, button, action, action_type, host, port)
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
			"--set-action-button",
			host,
			port,
			str(credentials["account"]),
			character_name,
			str(button),
			str(action),
			str(action_type),
		]),
		str(credentials["password"]),
		output)
	var text := "\n".join(output)
	var parsed := _parse_set_action_button_output(text)
	parsed["exit_code"] = exit_code
	parsed["output"] = text.strip_edges()
	parsed["source"] = "helper process"
	parsed["ok"] = exit_code == 0 and bool(parsed.get("set_confirmed", false)) \
		and bool(parsed.get("restore_confirmed", false))
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


func _run_native_character_flow(host: String, port: String, account_override: String = "", password_override: String = "") -> Dictionary:
	if not ClassDB.class_exists(NATIVE_CLIENT_CLASS):
		return {}

	var account := account_override.strip_edges()
	var password := password_override
	if account.is_empty() or password.is_empty():
		var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
		if not FileAccess.file_exists(env_file):
			return _failure("Local protocol account file is missing: " + env_file)
		var account_data := _read_protocol_account_file(env_file)
		account = str(account_data.get("ACORE_PROTOCOL_ACCOUNT", ""))
		password = str(account_data.get("ACORE_PROTOCOL_PASSWORD", ""))
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


func _run_native_enter_world(character_name: String, host: String, port: String, account_override: String = "", password_override: String = "") -> Dictionary:
	var credentials := _load_native_credentials(account_override, password_override)
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


func _run_native_visible_targets_snapshot(character_name: String, host: String, port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("visible_targets_snapshot"):
		return {}

	var result = client.call(
		"visible_targets_snapshot",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected visible-target result")

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


func _run_native_trainer_list_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	return _run_native_trainer_list_probe_selector(character_name, str(target_entry), target_name, host, port)


func _run_native_questgiver_list_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("questgiver_list_probe_selector"):
		return {}

	var result = client.call(
		"questgiver_list_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected questgiver result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_questgiver_accept_probe_selector(
	character_name: String,
	target_selector: String,
	quest_id: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("questgiver_accept_probe_selector"):
		return {}

	var result = client.call(
		"questgiver_accept_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		quest_id,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected questgiver accept result")

	var accept_parsed: Dictionary = result
	accept_parsed["source"] = "Godot native extension"
	accept_parsed["exit_code"] = 0 if bool(accept_parsed.get("ok", false)) else 1
	accept_parsed["output"] = JSON.stringify(_redacted_result(accept_parsed))
	return accept_parsed


func _run_native_trainer_list_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("trainer_list_probe_selector"):
		return {}

	var result = client.call(
		"trainer_list_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected trainer result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_trainer_buy_spell_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	spell_id: int,
	host: String,
	port: String) -> Dictionary:
	return _run_native_trainer_buy_spell_probe_selector(character_name, str(target_entry), target_name, spell_id, host, port)


func _run_native_trainer_buy_spell_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	spell_id: int,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("trainer_buy_spell_probe_selector"):
		return {}

	var result = client.call(
		"trainer_buy_spell_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name,
		spell_id)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected trainer buy result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_vendor_list_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	return _run_native_vendor_list_probe_selector(character_name, str(target_entry), target_name, host, port)


func _run_native_vendor_list_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("vendor_list_probe_selector"):
		return {}

	var result = client.call(
		"vendor_list_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected vendor result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_vendor_buy_sell_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	vendor_slot: int,
	item_id: int,
	count: int,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("vendor_buy_sell_probe_selector"):
		return {}

	var result = client.call(
		"vendor_buy_sell_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name,
		vendor_slot,
		item_id,
		count)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected vendor buy/sell result")

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


func _run_native_loot_open_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	return _run_native_loot_open_probe_selector(character_name, str(target_entry), target_name, host, port)


func _run_native_loot_open_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("loot_open_probe_selector"):
		return {}

	var result = client.call(
		"loot_open_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected loot result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_corpse_loot_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	return _run_native_corpse_loot_probe_selector(character_name, str(target_entry), target_name, host, port)


func _run_native_corpse_loot_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("corpse_loot_probe_selector"):
		return {}

	var result = client.call(
		"corpse_loot_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected corpse loot result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_loot_inventory_handoff_probe(
	character_name: String,
	target_entry: int,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	return _run_native_loot_inventory_handoff_probe_selector(character_name, str(target_entry), target_name, host, port)


func _run_native_loot_inventory_handoff_probe_selector(
	character_name: String,
	target_selector: String,
	target_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("loot_inventory_handoff_probe_selector"):
		return {}

	var result = client.call(
		"loot_inventory_handoff_probe_selector",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		target_selector,
		target_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected loot inventory result")

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


func _run_native_inventory_snapshot(
	character_name: String,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("inventory_snapshot"):
		return {}

	var result = client.call(
		"inventory_snapshot",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected inventory result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_swap_inventory_slots(
	character_name: String,
	source_slot: int,
	destination_slot: int,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("swap_inventory_slots"):
		return {}

	var result = client.call(
		"swap_inventory_slots",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		source_slot,
		destination_slot)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected inventory swap result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_split_inventory_stack(
	character_name: String,
	source_slot: int,
	destination_slot: int,
	split_count: int,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("split_inventory_stack"):
		return {}

	var result = client.call(
		"split_inventory_stack",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		source_slot,
		destination_slot,
		split_count)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected inventory split result")

	var parsed: Dictionary = result
	parsed["source"] = "Godot native extension"
	parsed["exit_code"] = 0 if bool(parsed.get("ok", false)) else 1
	parsed["output"] = JSON.stringify(_redacted_result(parsed))
	return parsed


func _run_native_set_action_button(
	character_name: String,
	button: int,
	action: int,
	action_type: int,
	host: String,
	port: String) -> Dictionary:
	var credentials := _load_native_credentials()
	if not credentials.get("available", false):
		return credentials.get("result", {})

	var client: Object = credentials["client"]
	if not client.has_method("set_action_button"):
		return {}

	var result = client.call(
		"set_action_button",
		host,
		port,
		credentials["account"],
		credentials["password"],
		character_name,
		button,
		action,
		action_type)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure("Native Godot protocol client returned an unexpected set-action-button result")

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


func _load_native_credentials(account_override: String = "", password_override: String = "") -> Dictionary:
	if not ClassDB.class_exists(NATIVE_CLIENT_CLASS):
		return {"available": false, "result": {}}

	var account := account_override.strip_edges()
	var password := password_override
	if account.is_empty() or password.is_empty():
		var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
		if not FileAccess.file_exists(env_file):
			return {"available": false, "result": _failure("Local protocol account file is missing: " + env_file)}
		var account_data := _read_protocol_account_file(env_file)
		account = str(account_data.get("ACORE_PROTOCOL_ACCOUNT", ""))
		password = str(account_data.get("ACORE_PROTOCOL_PASSWORD", ""))
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


func _resolve_credentials(account: String, password: String) -> Dictionary:
	# Prefer explicit credentials (e.g. typed at the login screen). Fall back to
	# the local protocol account file when either is empty, preserving the
	# original file-driven behavior for all existing callers.
	if account.strip_edges() != "" and password != "":
		return {"ok": true, "account": account.strip_edges(), "password": password}
	var env_file := ProjectSettings.globalize_path(LOCAL_ACCOUNT_ENV)
	if not FileAccess.file_exists(env_file):
		return _failure("Local protocol account file is missing: " + env_file)
	return _load_protocol_credentials(env_file)


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
	var helper := ProjectSettings.globalize_path(HELPER_PATH)
	return helper


func _execute_helper_with_password(helper: String, args: PackedStringArray, password: String, output: Array) -> int:
	var previous_library_path := OS.get_environment("LD_LIBRARY_PATH")
	OS.set_environment("ACORE_PROTOCOL_PASSWORD", password)
	OS.set_environment("LD_LIBRARY_PATH", "")
	var exit_code := OS.execute(helper, args, output, true, false)
	OS.set_environment("ACORE_PROTOCOL_PASSWORD", "")
	OS.set_environment("LD_LIBRARY_PATH", previous_library_path)
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
	redacted.erase("visible_objects")
	redacted.erase("skipped_opcodes")
	redacted.erase("inventory_before")
	redacted.erase("inventory_after")
	redacted.erase("inventory_after_buy")
	redacted.erase("inventory_after_sell")
	if typeof(redacted.get("items", null)) == TYPE_ARRAY:
		var items: Array = redacted["items"]
		if items.size() > 8:
			redacted["items"] = items.slice(0, 8)
			redacted["truncated_item_count"] = items.size() - 8
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
		"update": {"visible_objects": [], "visible_object_count": 0},
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
			result["update"] = {
				"seen": result["update_object_seen"],
				"compressed": _extract_int_field(line, "compressed=") == 1,
				"block_count": _extract_int_field(line, "blocks="),
				"visible_parse_complete": _extract_int_field(line, "visible_parse_complete=") == 1,
				"visible_object_count": _extract_int_field(line, "visible_objects="),
				"visible_objects": result["update"].get("visible_objects", []),
			}
		elif line.begins_with("VISIBLE_OBJECT"):
			var position := _parse_vector_field(line, "pos=(")
			var object := {
				"guid": _extract_token_after(line, "guid="),
				"entry": _extract_int_field(line, "entry="),
				"object_type": _extract_int_field(line, "type="),
				"has_position": _extract_int_field(line, "has_position=") == 1,
				"x": float(position.get("x", 0.0)),
				"y": float(position.get("y", 0.0)),
				"z": float(position.get("z", 0.0)),
			}
			var update: Dictionary = result["update"]
			var visible_objects: Array = update.get("visible_objects", [])
			visible_objects.append(object)
			update["visible_objects"] = visible_objects
			update["visible_object_count"] = visible_objects.size()
			result["update"] = update
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


func _parse_questgiver_list_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"questgiver_hello_sent": false,
		"quest_list_response_seen": false,
		"gossip_fallback_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"response_opcode": 0,
		"gossip_menu_id": 0,
		"quest_count": 0,
		"quests": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("QUESTGIVER_LIST_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["questgiver_hello_sent"] = _extract_int_field(line, "questgiver_hello_sent=") == 1
			result["quest_list_response_seen"] = _extract_int_field(line, "quest_list_response_seen=") == 1
			result["gossip_fallback_seen"] = _extract_int_field(line, "gossip_fallback_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["gossip_menu_id"] = _extract_int_field(line, "gossip_menu_id=")
			var quest_list_count := _extract_int_field(line, "quest_count=")
			var gossip_quest_count := _extract_int_field(line, "gossip_quest_count=")
			result["quest_count"] = quest_list_count if quest_list_count > 0 else gossip_quest_count
		elif line.begins_with("QUESTGIVER_QUEST") or line.begins_with("GOSSIP_QUEST"):
			result["quests"].append({
				"quest_id": _extract_int_field(line, "quest_id="),
				"quest_icon": _extract_int_field(line, "icon="),
				"quest_level": _extract_int_field(line, "level="),
				"quest_flags": _extract_int_field(line, "flags="),
				"repeatable": _extract_int_field(line, "repeatable="),
			})
	return result


func _parse_questgiver_accept_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"questgiver_hello_sent": false,
		"accept_sent": false,
		"quest_in_log_after_accept": false,
		"accepted_slot": -1,
		"remove_sent": false,
		"quest_removed_after_remove": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"quest_id": 0,
		"accept_response_opcode": 0,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("QUESTGIVER_ACCEPT_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["quest_id"] = _extract_int_field(line, "quest_id=")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["questgiver_hello_sent"] = _extract_int_field(line, "questgiver_hello_sent=") == 1
			result["accept_sent"] = _extract_int_field(line, "accept_sent=") == 1
			result["quest_in_log_after_accept"] = _extract_int_field(line, "quest_in_log_after_accept=") == 1
			result["accepted_slot"] = _extract_int_field(line, "accepted_slot=")
			result["remove_sent"] = _extract_int_field(line, "remove_sent=") == 1
			result["quest_removed_after_remove"] = _extract_int_field(line, "quest_removed_after_remove=") == 1
			result["accept_response_opcode"] = _extract_hex_field(line, "accept_response_opcode=0x")
	return result


func _parse_trainer_list_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"trainer_list_sent": false,
		"trainer_list_response_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"response_opcode": 0,
		"trainer_type": 0,
		"spell_count": 0,
		"greeting": "",
		"spells": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("TRAINER_LIST_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["trainer_list_sent"] = _extract_int_field(line, "trainer_list_sent=") == 1
			result["trainer_list_response_seen"] = _extract_int_field(line, "trainer_list_response_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["trainer_type"] = _extract_int_field(line, "trainer_type=")
			result["spell_count"] = _extract_int_field(line, "spell_count=")
			result["greeting"] = _extract_quoted_field(line, "greeting=\"")
		elif line.begins_with("TRAINER_SPELL"):
			result["spells"].append({
				"spell_id": _extract_int_field(line, "spell_id="),
				"usable": _extract_int_field(line, "usable="),
				"money_cost": _extract_int_field(line, "money_cost="),
				"req_level": _extract_int_field(line, "req_level="),
				"req_skill_line": _extract_int_field(line, "req_skill_line="),
				"req_skill_rank": _extract_int_field(line, "req_skill_rank="),
				"req_ability_1": _extract_int_field(line, "req_ability_1="),
				"req_ability_2": _extract_int_field(line, "req_ability_2="),
				"req_ability_3": _extract_int_field(line, "req_ability_3="),
			})
	result["trainer_list"] = {
		"parsed": result["trainer_list_response_seen"],
		"trainer_guid": result["target_guid"],
		"trainer_type": result["trainer_type"],
		"spell_count": result["spell_count"],
		"greeting": result["greeting"],
		"spells": result["spells"],
	}
	return result


func _parse_trainer_buy_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"trainer_list_sent": false,
		"trainer_list_response_seen": false,
		"buy_spell_sent": false,
		"buy_response_seen": false,
		"buy_succeeded": false,
		"buy_failed": false,
		"failure_reason": 0,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"spell_id": 0,
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"response_opcode": 0,
		"spell_count": 0,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("TRAINER_BUY_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["spell_id"] = _extract_int_field(line, "spell_id=")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["trainer_list_sent"] = _extract_int_field(line, "trainer_list_sent=") == 1
			result["trainer_list_response_seen"] = _extract_int_field(line, "trainer_list_response_seen=") == 1
			result["spell_count"] = _extract_int_field(line, "spell_count=")
			result["buy_spell_sent"] = _extract_int_field(line, "buy_spell_sent=") == 1
			result["buy_response_seen"] = _extract_int_field(line, "buy_response_seen=") == 1
			result["buy_succeeded"] = _extract_int_field(line, "buy_succeeded=") == 1
			result["buy_failed"] = _extract_int_field(line, "buy_failed=") == 1
			result["failure_reason"] = _extract_int_field(line, "failure_reason=")
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
	result["buy_response"] = {
		"parsed": result["buy_response_seen"],
		"trainer_guid": result["target_guid"],
		"spell_id": result["spell_id"],
		"failure_reason": result["failure_reason"],
		"succeeded": result["buy_succeeded"],
		"failed": result["buy_failed"],
	}
	return result


func _parse_vendor_list_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"vendor_list_sent": false,
		"vendor_list_response_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"response_opcode": 0,
		"item_count": 0,
		"error_code": 0,
		"items": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("VENDOR_LIST_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["vendor_list_sent"] = _extract_int_field(line, "vendor_list_sent=") == 1
			result["vendor_list_response_seen"] = _extract_int_field(line, "vendor_list_response_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["item_count"] = _extract_int_field(line, "item_count=")
			result["error_code"] = _extract_int_field(line, "error_code=")
		elif line.begins_with("VENDOR_ITEM"):
			result["items"].append({
				"vendor_slot": _extract_int_field(line, "vendor_slot="),
				"item_id": _extract_int_field(line, "item_id="),
				"display_id": _extract_int_field(line, "display_id="),
				"left_in_stock": _extract_int_field(line, "left_in_stock="),
				"buy_price": _extract_int_field(line, "buy_price="),
				"max_durability": _extract_int_field(line, "max_durability="),
				"buy_count": _extract_int_field(line, "buy_count="),
				"extended_cost": _extract_int_field(line, "extended_cost="),
			})
	result["vendor_list"] = {
		"parsed": result["vendor_list_response_seen"],
		"vendor_guid": result["target_guid"],
		"item_count": result["item_count"],
		"error_code": result["error_code"],
		"items": result["items"],
	}
	return result


func _parse_vendor_buy_sell_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"vendor_list_sent": false,
		"vendor_list_response_seen": false,
		"inventory_before_seen": false,
		"inventory_after_buy_seen": false,
		"inventory_after_sell_seen": false,
		"buy_sent": false,
		"buy_response_seen": false,
		"buy_succeeded": false,
		"buy_failed": false,
		"bought_item_found": false,
		"sell_sent": false,
		"sell_error_seen": false,
		"sell_confirmed": false,
		"roundtrip_confirmed": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"vendor_slot": 0,
		"item_id": 0,
		"count": 0,
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"item_count": 0,
		"buy_response_opcode": 0,
		"buy_failure_reason": 0,
		"bought_slot": 0,
		"bought_guid": "0x0",
		"sell_error_reason": 0,
		"before_coinage": 0,
		"after_buy_coinage": 0,
		"after_sell_coinage": 0,
		"buy_coinage_delta": 0,
		"sell_coinage_delta": 0,
		"roundtrip_coinage_delta": 0,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("VENDOR_BUY_SELL_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["vendor_slot"] = _extract_int_field(line, "vendor_slot=")
			result["item_id"] = _extract_int_field(line, "item_id=")
			result["count"] = _extract_int_field(line, "count=")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["vendor_list_sent"] = _extract_int_field(line, "vendor_list_sent=") == 1
			result["vendor_list_response_seen"] = _extract_int_field(line, "vendor_list_response_seen=") == 1
			result["inventory_before_seen"] = _extract_int_field(line, "inventory_before_seen=") == 1
			result["inventory_after_buy_seen"] = _extract_int_field(line, "inventory_after_buy_seen=") == 1
			result["inventory_after_sell_seen"] = _extract_int_field(line, "inventory_after_sell_seen=") == 1
			result["buy_sent"] = _extract_int_field(line, "buy_sent=") == 1
			result["buy_response_seen"] = _extract_int_field(line, "buy_response_seen=") == 1
			result["buy_succeeded"] = _extract_int_field(line, "buy_succeeded=") == 1
			result["buy_failed"] = _extract_int_field(line, "buy_failed=") == 1
			result["buy_response_opcode"] = _extract_hex_field(line, "buy_response_opcode=0x")
			result["buy_failure_reason"] = _extract_int_field(line, "buy_failure_reason=")
			result["bought_item_found"] = _extract_int_field(line, "bought_item_found=") == 1
			result["bought_slot"] = _extract_int_field(line, "bought_slot=")
			result["bought_guid"] = _extract_token_after(line, "bought_guid=")
			result["sell_sent"] = _extract_int_field(line, "sell_sent=") == 1
			result["sell_error_seen"] = _extract_int_field(line, "sell_error_seen=") == 1
			result["sell_error_reason"] = _extract_int_field(line, "sell_error_reason=")
			result["sell_confirmed"] = _extract_int_field(line, "sell_confirmed=") == 1
			result["roundtrip_confirmed"] = _extract_int_field(line, "roundtrip_confirmed=") == 1
			result["before_coinage"] = _extract_int_field(line, "before_coinage=")
			result["after_buy_coinage"] = _extract_int_field(line, "after_buy_coinage=")
			result["after_sell_coinage"] = _extract_int_field(line, "after_sell_coinage=")
			result["buy_coinage_delta"] = _extract_int_field(line, "buy_coinage_delta=")
			result["sell_coinage_delta"] = _extract_int_field(line, "sell_coinage_delta=")
			result["roundtrip_coinage_delta"] = _extract_int_field(line, "roundtrip_coinage_delta=")
	result["vendor_list"] = {
		"parsed": result["vendor_list_response_seen"],
		"vendor_guid": result["target_guid"],
		"item_count": result["item_count"],
	}
	result["inventory_before"] = {
		"seen": result["inventory_before_seen"],
		"coinage": result["before_coinage"],
	}
	result["inventory_after_buy"] = {
		"seen": result["inventory_after_buy_seen"],
		"coinage": result["after_buy_coinage"],
	}
	result["inventory_after_sell"] = {
		"seen": result["inventory_after_sell_seen"],
		"coinage": result["after_sell_coinage"],
	}
	result["buy_response"] = {
		"parsed": result["buy_response_seen"],
		"vendor_guid": result["target_guid"],
		"vendor_slot": result["vendor_slot"],
		"item_id": result["item_id"],
		"count": result["count"],
		"failure_reason": result["buy_failure_reason"],
		"succeeded": result["buy_succeeded"],
		"failed": result["buy_failed"],
	}
	result["sell_error"] = {
		"parsed": result["sell_error_seen"],
		"vendor_guid": result["target_guid"],
		"item_guid": result["bought_guid"],
		"reason": result["sell_error_reason"],
	}
	return result


func _parse_combat_probe_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"attack_sent": false,
		"combat_response_seen": false,
		"attacker_state_update_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"response_opcode": 0,
		"hit_info": 0,
		"total_damage": 0,
		"overkill": 0,
		"sub_damage_count": 0,
		"target_state": 0,
		"blocked_amount": 0,
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
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["attack_sent"] = _extract_int_field(line, "attack_sent=") == 1
			result["combat_response_seen"] = _extract_int_field(line, "combat_response_seen=") == 1
			result["attacker_state_update_seen"] = _extract_int_field(line, "attacker_state_update_seen=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["hit_info"] = _extract_hex_field(line, "hit_info=0x")
			result["total_damage"] = _extract_int_field(line, "total_damage=")
			result["overkill"] = _extract_int_field(line, "overkill=")
			result["sub_damage_count"] = _extract_int_field(line, "sub_damage_count=")
			result["target_state"] = _extract_int_field(line, "target_state=")
			result["blocked_amount"] = _extract_int_field(line, "blocked_amount=")
	result["attacker_state_update"] = {
		"parsed": result["attacker_state_update_seen"],
		"hit_info": result["hit_info"],
		"total_damage": result["total_damage"],
		"overkill": result["overkill"],
		"sub_damage_count": result["sub_damage_count"],
		"target_state": result["target_state"],
		"blocked_amount": result["blocked_amount"],
	}
	return result


func _parse_loot_open_probe_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"loot_open_sent": false,
		"loot_response_seen": false,
		"loot_release_sent": false,
		"loot_release_response_seen": false,
		"loot_release_success": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"target_has_position": false,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"visible_object_count": 0,
		"response_opcode": 0,
		"loot_parsed": false,
		"loot_error": false,
		"loot_error_code": 0,
		"loot_type": 0,
		"gold": 0,
		"item_count": 0,
		"items": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("LOOT_OPEN_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["loot_open_sent"] = _extract_int_field(line, "loot_open_sent=") == 1
			result["loot_response_seen"] = _extract_int_field(line, "loot_response_seen=") == 1
			result["loot_release_sent"] = _extract_int_field(line, "loot_release_sent=") == 1
			result["loot_release_response_seen"] = _extract_int_field(line, "loot_release_response_seen=") == 1
			result["loot_release_success"] = _extract_int_field(line, "loot_release_success=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["loot_parsed"] = _extract_int_field(line, "loot_parsed=") == 1
			result["loot_error"] = _extract_int_field(line, "loot_error=") == 1
			result["loot_error_code"] = _extract_int_field(line, "loot_error_code=")
			result["loot_type"] = _extract_int_field(line, "loot_type=")
			result["gold"] = _extract_int_field(line, "gold=")
			result["item_count"] = _extract_int_field(line, "item_count=")
		elif line.begins_with("LOOT_ITEM"):
			result["items"].append({
				"slot": _extract_int_field(line, "slot="),
				"item_id": _extract_int_field(line, "item_id="),
				"count": _extract_int_field(line, "count="),
				"display_id": _extract_int_field(line, "display_id="),
				"random_suffix": _extract_int_field(line, "random_suffix="),
				"random_property_id": _extract_int_field(line, "random_property_id="),
				"slot_type": _extract_int_field(line, "slot_type="),
			})
	result["loot"] = {
		"parsed": result["loot_parsed"],
		"error": result["loot_error"],
		"error_code": result["loot_error_code"],
		"loot_type": result["loot_type"],
		"gold": result["gold"],
		"item_count": result["item_count"],
		"items": result["items"],
	}
	return result


func _parse_corpse_loot_probe_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"selection_sent": false,
		"attack_sent": false,
		"attack_stop_sent": false,
		"target_dead_seen": false,
		"target_lootable_seen": false,
		"target_guid": "0x0",
		"target_entry": 0,
		"target_name": "",
		"target_has_position": false,
		"target_health_seen": false,
		"target_health": 0,
		"target_max_health_seen": false,
		"target_max_health": 0,
		"target_dynamic_flags_seen": false,
		"target_dynamic_flags": 0,
		"approach_movement_sent": false,
		"return_movement_sent": false,
		"attacker_state_updates": 0,
		"total_damage": 0,
		"visible_object_count": 0,
		"response_opcode": 0,
		"loot_open_sent": false,
		"loot_response_seen": false,
		"loot_money_sent": false,
		"loot_money_notify_seen": false,
		"loot_money_amount": 0,
		"loot_item_pickup_sent_count": 0,
		"loot_item_removed_count": 0,
		"loot_release_sent": false,
		"loot_release_response_seen": false,
		"loot_release_success": false,
		"loot_parsed": false,
		"loot_error": false,
		"loot_error_code": 0,
		"loot_type": 0,
		"gold": 0,
		"item_count": 0,
		"items": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("CORPSE_LOOT_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["target_health_seen"] = _extract_int_field(line, "target_health_seen=") == 1
			result["target_health"] = _extract_int_field(line, "target_health=")
			result["target_max_health_seen"] = _extract_int_field(line, "target_max_health_seen=") == 1
			result["target_max_health"] = _extract_int_field(line, "target_max_health=")
			result["target_dynamic_flags_seen"] = _extract_int_field(line, "target_dynamic_flags_seen=") == 1
			result["target_dynamic_flags"] = _extract_hex_field(line, "target_dynamic_flags=0x")
			result["target_dead_seen"] = _extract_int_field(line, "target_dead_seen=") == 1
			result["target_lootable_seen"] = _extract_int_field(line, "target_lootable_seen=") == 1
			result["visible_object_count"] = _extract_int_field(line, "visible_objects=")
			result["approach_movement_sent"] = _extract_int_field(line, "approach_movement_sent=") == 1
			result["return_movement_sent"] = _extract_int_field(line, "return_movement_sent=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["attack_sent"] = _extract_int_field(line, "attack_sent=") == 1
			result["attack_stop_sent"] = _extract_int_field(line, "attack_stop_sent=") == 1
			result["attacker_state_updates"] = _extract_int_field(line, "attacker_state_updates=")
			result["total_damage"] = _extract_int_field(line, "total_damage=")
			result["loot_open_sent"] = _extract_int_field(line, "loot_open_sent=") == 1
			result["loot_response_seen"] = _extract_int_field(line, "loot_response_seen=") == 1
			result["loot_money_sent"] = _extract_int_field(line, "loot_money_sent=") == 1
			result["loot_money_notify_seen"] = _extract_int_field(line, "loot_money_notify_seen=") == 1
			result["loot_money_amount"] = _extract_int_field(line, "loot_money_amount=")
			result["loot_item_pickup_sent_count"] = _extract_int_field(line, "loot_item_pickup_sent_count=")
			result["loot_item_removed_count"] = _extract_int_field(line, "loot_item_removed_count=")
			result["loot_release_sent"] = _extract_int_field(line, "loot_release_sent=") == 1
			result["loot_release_response_seen"] = _extract_int_field(line, "loot_release_response_seen=") == 1
			result["loot_release_success"] = _extract_int_field(line, "loot_release_success=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["loot_parsed"] = _extract_int_field(line, "loot_parsed=") == 1
			result["loot_error"] = _extract_int_field(line, "loot_error=") == 1
			result["loot_error_code"] = _extract_int_field(line, "loot_error_code=")
			result["loot_type"] = _extract_int_field(line, "loot_type=")
			result["gold"] = _extract_int_field(line, "gold=")
			result["item_count"] = _extract_int_field(line, "item_count=")
		elif line.begins_with("CORPSE_LOOT_ITEM"):
			result["items"].append({
				"slot": _extract_int_field(line, "slot="),
				"item_id": _extract_int_field(line, "item_id="),
				"count": _extract_int_field(line, "count="),
				"display_id": _extract_int_field(line, "display_id="),
				"random_suffix": _extract_int_field(line, "random_suffix="),
				"random_property_id": _extract_int_field(line, "random_property_id="),
				"slot_type": _extract_int_field(line, "slot_type="),
			})
	result["loot"] = {
		"parsed": result["loot_parsed"],
		"error": result["loot_error"],
		"error_code": result["loot_error_code"],
		"loot_type": result["loot_type"],
		"gold": result["gold"],
		"item_count": result["item_count"],
		"items": result["items"],
	}
	return result


func _parse_loot_inventory_handoff_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"live_target_found": false,
		"target_has_position": false,
		"target_health_seen": false,
		"target_health": 0,
		"target_max_health_seen": false,
		"target_max_health": 0,
		"target_dynamic_flags_seen": false,
		"target_dynamic_flags": 0,
		"target_dead_seen": false,
		"target_lootable_seen": false,
		"selection_sent": false,
		"attack_sent": false,
		"attack_stop_sent": false,
		"attacker_state_updates": 0,
		"total_damage": 0,
		"loot_open_sent": false,
		"loot_response_seen": false,
		"loot_error": false,
		"loot_item_pickup_sent_count": 0,
		"loot_item_removed_count": 0,
		"loot_release_sent": false,
		"loot_release_response_seen": false,
		"loot_release_success": false,
		"response_opcode": 0,
		"item_count": 0,
		"gold": 0,
		"inventory_before_seen": false,
		"inventory_after_seen": false,
		"before_populated": 0,
		"after_populated": 0,
		"before_coinage": 0,
		"after_coinage": 0,
		"coinage_delta": 0,
		"changed_slot_count": 0,
		"added_slot_count": 0,
		"removed_slot_count": 0,
		"stack_changed_slot_count": 0,
		"handoff_confirmed": false,
		"changed_slots": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("LOOT_INVENTORY_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["target_guid"] = _extract_token_after(line, "target_guid=")
			result["target_entry"] = _extract_int_field(line, "target_entry=")
			result["target_name"] = _extract_quoted_field(line, "target_name=\"")
			result["live_target_found"] = _extract_int_field(line, "live_target_found=") == 1
			result["target_has_position"] = _extract_int_field(line, "target_has_position=") == 1
			result["target_health_seen"] = _extract_int_field(line, "target_health_seen=") == 1
			result["target_health"] = _extract_int_field(line, "target_health=")
			result["target_max_health_seen"] = _extract_int_field(line, "target_max_health_seen=") == 1
			result["target_max_health"] = _extract_int_field(line, "target_max_health=")
			result["target_dynamic_flags_seen"] = _extract_int_field(line, "target_dynamic_flags_seen=") == 1
			result["target_dynamic_flags"] = _extract_hex_field(line, "target_dynamic_flags=0x")
			result["target_dead_seen"] = _extract_int_field(line, "target_dead_seen=") == 1
			result["target_lootable_seen"] = _extract_int_field(line, "target_lootable_seen=") == 1
			result["selection_sent"] = _extract_int_field(line, "selection_sent=") == 1
			result["attack_sent"] = _extract_int_field(line, "attack_sent=") == 1
			result["attack_stop_sent"] = _extract_int_field(line, "attack_stop_sent=") == 1
			result["attacker_state_updates"] = _extract_int_field(line, "attacker_state_updates=")
			result["total_damage"] = _extract_int_field(line, "total_damage=")
			result["loot_open_sent"] = _extract_int_field(line, "loot_open_sent=") == 1
			result["loot_response_seen"] = _extract_int_field(line, "loot_response_seen=") == 1
			result["loot_error"] = _extract_int_field(line, "loot_error=") == 1
			result["loot_item_pickup_sent_count"] = _extract_int_field(line, "loot_item_pickup_sent_count=")
			result["loot_item_removed_count"] = _extract_int_field(line, "loot_item_removed_count=")
			result["loot_release_sent"] = _extract_int_field(line, "loot_release_sent=") == 1
			result["loot_release_response_seen"] = _extract_int_field(line, "loot_release_response_seen=") == 1
			result["loot_release_success"] = _extract_int_field(line, "loot_release_success=") == 1
			result["response_opcode"] = _extract_hex_field(line, "response_opcode=0x")
			result["item_count"] = _extract_int_field(line, "item_count=")
			result["gold"] = _extract_int_field(line, "gold=")
			result["inventory_before_seen"] = _extract_int_field(line, "inventory_before_seen=") == 1
			result["inventory_after_seen"] = _extract_int_field(line, "inventory_after_seen=") == 1
			result["before_populated"] = _extract_int_field(line, "before_populated=")
			result["after_populated"] = _extract_int_field(line, "after_populated=")
			result["before_coinage"] = _extract_int_field(line, "before_coinage=")
			result["after_coinage"] = _extract_int_field(line, "after_coinage=")
			result["coinage_delta"] = _extract_int_field(line, "coinage_delta=")
			result["changed_slot_count"] = _extract_int_field(line, "changed_slots=")
			result["added_slot_count"] = _extract_int_field(line, "added_slots=")
			result["removed_slot_count"] = _extract_int_field(line, "removed_slots=")
			result["stack_changed_slot_count"] = _extract_int_field(line, "stack_changed_slots=")
			result["handoff_confirmed"] = _extract_int_field(line, "handoff_confirmed=") == 1
		elif line.begins_with("LOOT_INVENTORY_CHANGED_SLOT"):
			result["changed_slots"].append({
				"slot": _extract_int_field(line, "slot="),
				"section": _extract_token_after(line, "section="),
				"populated": _extract_int_field(line, "populated=") == 1,
				"item_guid": _extract_token_after(line, "item_guid="),
				"item_entry": _extract_int_field(line, "item_entry="),
				"stack_count": _extract_int_field(line, "stack_count="),
				"item_detail_seen": _extract_int_field(line, "item_detail_seen=") == 1,
				"item_template_seen": _extract_int_field(line, "item_template_seen=") == 1,
				"item_name": _extract_quoted_field(line, "item_name=\""),
			})
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


func _parse_inventory_snapshot_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"inventory_seen": false,
		"logged_in_world": false,
		"player_guid": "0x0",
		"coinage_seen": false,
		"coinage": 0,
		"slot_count": 0,
		"populated_count": 0,
		"item_detail_count": 0,
		"item_template_count": 0,
		"slots": [],
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("INVENTORY_SNAPSHOT"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["inventory_seen"] = _extract_int_field(line, "inventory_seen=") == 1
			result["logged_in_world"] = _extract_int_field(line, "logged_in_world=") == 1
			result["player_guid"] = _extract_token_after(line, "player_guid=")
			result["coinage_seen"] = _extract_int_field(line, "coinage_seen=") == 1
			result["coinage"] = _extract_int_field(line, "coinage=")
			result["slot_count"] = _extract_int_field(line, "slot_count=")
			result["populated_count"] = _extract_int_field(line, "populated_count=")
			result["item_detail_count"] = _extract_int_field(line, "item_detail_count=")
			result["item_template_count"] = _extract_int_field(line, "item_template_count=")
		elif line.begins_with("INVENTORY_SLOT"):
			result["slots"].append({
				"slot": _extract_int_field(line, "slot="),
				"section": _extract_token_after(line, "section="),
				"field_seen": _extract_int_field(line, "field_seen=") == 1,
				"populated": _extract_int_field(line, "populated=") == 1,
				"item_guid": _extract_token_after(line, "item_guid="),
				"item_entry": _extract_int_field(line, "item_entry="),
				"stack_count": _extract_int_field(line, "stack_count="),
				"durability": _extract_int_field(line, "durability="),
				"max_durability": _extract_int_field(line, "max_durability="),
				"item_detail_seen": _extract_int_field(line, "item_detail_seen=") == 1,
				"item_template_seen": _extract_int_field(line, "item_template_seen=") == 1,
				"item_name": _extract_quoted_field(line, "item_name=\""),
			})
	result["inventory"] = {
		"seen": result["inventory_seen"],
		"player_guid": result["player_guid"],
		"coinage_seen": result["coinage_seen"],
		"coinage": result["coinage"],
		"slot_count": result["slot_count"],
		"populated_count": result["populated_count"],
		"item_detail_count": result["item_detail_count"],
		"item_template_count": result["item_template_count"],
		"slots": result["slots"],
	}
	return result


func _parse_inventory_swap_slot(line: String, prefix: String, slot_index: int) -> Dictionary:
	return {
		"slot": slot_index,
		"populated": _extract_int_field(line, prefix + "_populated=") == 1,
		"item_guid": _extract_token_after(line, prefix + "_guid="),
		"item_entry": _extract_int_field(line, prefix + "_entry="),
		"stack_count": _extract_int_field(line, prefix + "_stack="),
		"item_name": _extract_quoted_field(line, prefix + "_name=\""),
	}


func _parse_inventory_swap_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"source_slot": 0,
		"destination_slot": 0,
		"before_seen": false,
		"swap_sent": false,
		"swap_confirmed": false,
		"restore_sent": false,
		"restore_confirmed": false,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("INVENTORY_SWAP_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["source_slot"] = _extract_int_field(line, "source_slot=")
			result["destination_slot"] = _extract_int_field(line, "destination_slot=")
			result["before_seen"] = _extract_int_field(line, "before_seen=") == 1
			result["swap_sent"] = _extract_int_field(line, "swap_sent=") == 1
			result["swap_confirmed"] = _extract_int_field(line, "swap_confirmed=") == 1
			result["restore_sent"] = _extract_int_field(line, "restore_sent=") == 1
			result["restore_confirmed"] = _extract_int_field(line, "restore_confirmed=") == 1
			result["source_before"] = _parse_inventory_swap_slot(line, "source_before", result["source_slot"])
			result["destination_before"] = _parse_inventory_swap_slot(line, "destination_before", result["destination_slot"])
			result["source_after_swap"] = _parse_inventory_swap_slot(line, "source_after_swap", result["source_slot"])
			result["destination_after_swap"] = _parse_inventory_swap_slot(line, "destination_after_swap", result["destination_slot"])
			result["source_after_restore"] = _parse_inventory_swap_slot(line, "source_after_restore", result["source_slot"])
			result["destination_after_restore"] = _parse_inventory_swap_slot(line, "destination_after_restore", result["destination_slot"])
	return result


func _parse_inventory_split_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"source_slot": 0,
		"destination_slot": 0,
		"split_count": 0,
		"before_seen": false,
		"split_sent": false,
		"split_confirmed": false,
		"merge_sent": false,
		"merge_confirmed": false,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("INVENTORY_SPLIT_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["source_slot"] = _extract_int_field(line, "source_slot=")
			result["destination_slot"] = _extract_int_field(line, "destination_slot=")
			result["split_count"] = _extract_int_field(line, "split_count=")
			result["before_seen"] = _extract_int_field(line, "before_seen=") == 1
			result["split_sent"] = _extract_int_field(line, "split_sent=") == 1
			result["split_confirmed"] = _extract_int_field(line, "split_confirmed=") == 1
			result["merge_sent"] = _extract_int_field(line, "merge_sent=") == 1
			result["merge_confirmed"] = _extract_int_field(line, "merge_confirmed=") == 1
			result["source_before"] = _parse_inventory_swap_slot(line, "source_before", result["source_slot"])
			result["destination_before"] = _parse_inventory_swap_slot(line, "destination_before", result["destination_slot"])
			result["source_after_split"] = _parse_inventory_swap_slot(line, "source_after_split", result["source_slot"])
			result["destination_after_split"] = _parse_inventory_swap_slot(line, "destination_after_split", result["destination_slot"])
			result["source_after_merge"] = _parse_inventory_swap_slot(line, "source_after_merge", result["source_slot"])
			result["destination_after_merge"] = _parse_inventory_swap_slot(line, "destination_after_merge", result["destination_slot"])
	return result


func _parse_set_action_button_output(output: String) -> Dictionary:
	var result := {
		"auth_flow_ok": false,
		"button": 0,
		"action": 0,
		"type": 0,
		"before_seen": false,
		"original_populated": false,
		"original_action": 0,
		"original_type": 0,
		"original_packed": 0,
		"set_sent": false,
		"set_confirmed": false,
		"after_set_populated": false,
		"after_set_action": 0,
		"after_set_type": 0,
		"after_set_packed": 0,
		"restore_sent": false,
		"restore_confirmed": false,
		"after_restore_populated": false,
		"after_restore_action": 0,
		"after_restore_type": 0,
		"after_restore_packed": 0,
	}
	for raw_line in output.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("AUTH_FLOW_OK"):
			result["auth_flow_ok"] = true
			result["realm_line"] = line
		elif line.begins_with("SET_ACTION_BUTTON_PROBE"):
			result["character_name"] = _extract_quoted_field(line, "character=\"")
			result["button"] = _extract_int_field(line, "button=")
			result["action"] = _extract_int_field(line, "action=")
			result["type"] = _extract_int_field(line, "type=")
			result["before_seen"] = _extract_int_field(line, "before_seen=") == 1
			result["original_populated"] = _extract_int_field(line, "original_populated=") == 1
			result["original_action"] = _extract_int_field(line, "original_action=")
			result["original_type"] = _extract_int_field(line, "original_type=")
			result["original_packed"] = _extract_hex_field(line, "original_packed=0x")
			result["set_sent"] = _extract_int_field(line, "set_sent=") == 1
			result["set_confirmed"] = _extract_int_field(line, "set_confirmed=") == 1
			result["after_set_populated"] = _extract_int_field(line, "after_set_populated=") == 1
			result["after_set_action"] = _extract_int_field(line, "after_set_action=")
			result["after_set_type"] = _extract_int_field(line, "after_set_type=")
			result["after_set_packed"] = _extract_hex_field(line, "after_set_packed=0x")
			result["restore_sent"] = _extract_int_field(line, "restore_sent=") == 1
			result["restore_confirmed"] = _extract_int_field(line, "restore_confirmed=") == 1
			result["after_restore_populated"] = _extract_int_field(line, "after_restore_populated=") == 1
			result["after_restore_action"] = _extract_int_field(line, "after_restore_action=")
			result["after_restore_type"] = _extract_int_field(line, "after_restore_type=")
			result["after_restore_packed"] = _extract_hex_field(line, "after_restore_packed=0x")

	result["original"] = {
		"button": result["button"],
		"action": result["original_action"],
		"type": result["original_type"],
		"packed": result["original_packed"],
		"populated": result["original_populated"],
	}
	result["after_set"] = {
		"button": result["button"],
		"action": result["after_set_action"],
		"type": result["after_set_type"],
		"packed": result["after_set_packed"],
		"populated": result["after_set_populated"],
	}
	result["after_restore"] = {
		"button": result["button"],
		"action": result["after_restore_action"],
		"type": result["after_restore_type"],
		"packed": result["after_restore_packed"],
		"populated": result["after_restore_populated"],
	}
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
