extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := ProtocolClientBridge.new()
	var parsed: Dictionary = bridge.call("_parse_quest_abandon_output", "\n".join([
		"AUTH_FLOW_OK realms=1 first_realm=\"AzerothCore\" endpoint=\"127.0.0.1:8085\" realm_id=1 type=0 lock=0 flags=0x00 chars=1 timezone=1",
		"QUEST_ABANDON_PROBE character=\"Codexstage\" target_guid=0xf130003370000001 target_entry=823 quest_id=783 quest_log_slot=0 accept_ok=1 accepted_confirmed=1 already_in_log=0 quest_log_slot_found=1 logged_in_world=1 remove_sent=1 quest_log_before_remove_seen=1 quest_log_after_remove_seen=1 quest_in_log_before_remove=1 quest_in_log_after_remove=0 abandon_confirmed=1 before_populated=1 after_populated=0 skipped=0",
		"QUEST_LOG_BEFORE_REMOVE_SLOT slot=0 quest_id=783 state=0x8 c1=0 c2=0 c3=0 c4=0 time_left=0",
	]))
	if not bool(parsed.get("abandon_confirmed", false)):
		push_error("QUEST_ABANDON_BRIDGE_SMOKE_FAILED parser did not confirm abandon")
		quit(1)
		return
	if int(parsed.get("quest_log_slot", -1)) != 0:
		push_error("QUEST_ABANDON_BRIDGE_SMOKE_FAILED parser slot mismatch")
		quit(1)
		return

	var result: Dictionary = bridge.quest_abandon_probe_selector("Codexstage", "823", 783, "Quest Giver")
	if not bool(result.get("ok", false)):
		push_error("QUEST_ABANDON_BRIDGE_SMOKE_FAILED " + JSON.stringify(result))
		quit(1)
		return
	if not bool(result.get("remove_sent", false)):
		push_error("QUEST_ABANDON_BRIDGE_SMOKE_FAILED remove was not sent")
		quit(1)
		return
	if bool(result.get("quest_in_log_after_remove", true)):
		push_error("QUEST_ABANDON_BRIDGE_SMOKE_FAILED quest remained in log after remove")
		quit(1)
		return
	print("QUEST_ABANDON_BRIDGE_SMOKE_OK source=%s slot=%d before=%d after=%d" % [
		str(result.get("source", "unknown")),
		int(result.get("quest_log_slot", -1)),
		int(result.get("before_populated", 0)),
		int(result.get("after_populated", 0)),
	])
	quit(0)
