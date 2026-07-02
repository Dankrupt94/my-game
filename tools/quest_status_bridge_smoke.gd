extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := ProtocolClientBridge.new()
	var parsed: Dictionary = bridge.call("_parse_questgiver_status_output", "\n".join([
		"AUTH_FLOW_OK realms=1 first_realm=\"AzerothCore\" endpoint=\"127.0.0.1:8085\" realm_id=1 type=0 lock=0 flags=0x00 chars=1 timezone=1",
		"QUESTGIVER_STATUS_PROBE character=\"Codexstage\" target_guid=0xf130000337000001 target_entry=823 live_target_found=1 target_has_position=1 visible_objects=1 logged_in_world=1 status_query_sent=1 status_response_seen=1 response_opcode=0x183 status=8 skipped=0",
	]))
	if not bool(parsed.get("status_response_seen", false)):
		push_error("QUEST_STATUS_BRIDGE_SMOKE_FAILED parser did not see status response")
		quit(1)
		return
	if int(parsed.get("response_opcode", 0)) != 0x183:
		push_error("QUEST_STATUS_BRIDGE_SMOKE_FAILED parser opcode mismatch")
		quit(1)
		return

	var result: Dictionary = bridge.questgiver_status_probe_selector("Codexstage", "823", "Quest Giver")
	if not bool(result.get("ok", false)):
		push_error("QUEST_STATUS_BRIDGE_SMOKE_FAILED " + JSON.stringify(result))
		quit(1)
		return
	var status := int(result.get("status", -1))
	if status < 0 or status > 10:
		push_error("QUEST_STATUS_BRIDGE_SMOKE_FAILED unexpected status %d" % status)
		quit(1)
		return
	print("QUEST_STATUS_BRIDGE_SMOKE_OK source=%s status=%d opcode=0x%x" % [
		str(result.get("source", "unknown")),
		status,
		int(result.get("response_opcode", 0)),
	])
	quit(0)
