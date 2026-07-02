extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := ProtocolClientBridge.new()
	var parsed: Dictionary = bridge.call("_parse_quest_log_snapshot_output", "\n".join([
		"AUTH_FLOW_OK realms=1 first_realm=\"AzerothCore\" endpoint=\"127.0.0.1:8085\" realm_id=1 type=0 lock=0 flags=0x00 chars=1 timezone=1",
		"QUEST_LOG_SNAPSHOT character=\"Codexstage\" logged_in_world=1 quest_log_seen=1 player_guid=0x2ee4 slot_count=25 populated_count=1 skipped=0",
		"QUEST_LOG_SLOT slot=0 quest_id=783 state=0x8 c1=1 c2=2 c3=3 c4=4 time_left=0",
	]))
	if not bool(parsed.get("quest_log_seen", false)) or int(parsed.get("slot_count", 0)) != 25:
		push_error("QUEST_LOG_BRIDGE_SMOKE_FAILED parser snapshot mismatch")
		quit(1)
		return
	if int(parsed.get("slots", [])[0].get("quest_id", 0)) != 783:
		push_error("QUEST_LOG_BRIDGE_SMOKE_FAILED parser slot mismatch")
		quit(1)
		return

	var result: Dictionary = bridge.quest_log_snapshot("Codexstage")
	if not bool(result.get("ok", false)):
		push_error("QUEST_LOG_BRIDGE_SMOKE_FAILED " + JSON.stringify(result))
		quit(1)
		return
	if not bool(result.get("quest_log_seen", false)):
		push_error("QUEST_LOG_BRIDGE_SMOKE_FAILED quest log was not observed")
		quit(1)
		return
	if not bool(result.get("logged_in_world", false)):
		push_error("QUEST_LOG_BRIDGE_SMOKE_FAILED world login was not observed")
		quit(1)
		return
	var quest_log: Dictionary = result.get("quest_log", {})
	var slot_count := int(result.get("slot_count", quest_log.get("slot_count", 0)))
	if slot_count != 25:
		push_error("QUEST_LOG_BRIDGE_SMOKE_FAILED expected 25 quest slots, saw %d" % slot_count)
		quit(1)
		return
	print("QUEST_LOG_BRIDGE_SMOKE_OK source=%s populated=%d slots=%d" % [
		str(result.get("source", "unknown")),
		int(result.get("populated_count", quest_log.get("populated_count", 0))),
		slot_count,
	])
	quit(0)
