extends SceneTree

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := ProtocolClientBridge.new()
	var parsed: Dictionary = bridge.call("_parse_quest_reward_output", "\n".join([
		"AUTH_FLOW_OK realms=1 first_realm=\"AzerothCore\" endpoint=\"127.0.0.1:8085\" realm_id=1 type=0 lock=0 flags=0x00 chars=1 timezone=1",
		"QUEST_REWARD_PROBE character=\"Codexstage\" starter_guid=0xf130000337000001 starter_entry=823 reward_target_guid=0xf1300000c5000002 reward_target_entry=197 quest_id=783 reward_choice=0 accept_ok=1 live_reward_target_found=1 reward_target_has_position=1 visible_objects=1 approach_movement_sent=1 return_movement_sent=1 selection_sent=1 logged_in_world=1 complete_sent=1 request_reward_sent=1 request_reward_response_seen=1 choose_reward_sent=1 request_items_seen=0 offer_reward_seen=1 quest_complete_seen=1 quest_update_complete_seen=1 failure_seen=0 failure_opcode=0x0 response_opcode=0x191 failure_reason=0 quest_log_before_reward_seen=1 quest_log_after_reward_seen=1 quest_in_log_before_reward=1 quest_in_log_after_reward=0 reward_confirmed=1 before_populated=1 after_populated=0 reward_choice_count=0 reward_item_count=0 reward_money=0 reward_xp=40 skipped=0",
		"QUEST_LOG_BEFORE_REWARD_SLOT slot=0 quest_id=783 state=0x1 c1=0 c2=0 c3=0 c4=0 time_left=0",
	]))
	if not bool(parsed.get("reward_confirmed", false)):
		push_error("QUEST_REWARD_BRIDGE_SMOKE_FAILED parser did not confirm reward")
		quit(1)
		return
	if bool(parsed.get("quest_in_log_after_reward", true)):
		push_error("QUEST_REWARD_BRIDGE_SMOKE_FAILED parser still saw quest after reward")
		quit(1)
		return

	var result: Dictionary = bridge.quest_reward_probe_selector(
		"Codexstage",
		"823",
		"197",
		783,
		0,
		"Quest Starter",
		"Quest Reward Target")
	if not bool(result.get("ok", false)):
		push_error("QUEST_REWARD_BRIDGE_SMOKE_FAILED " + JSON.stringify(result))
		quit(1)
		return
	if not bool(result.get("choose_reward_sent", false)):
		push_error("QUEST_REWARD_BRIDGE_SMOKE_FAILED reward choice was not sent")
		quit(1)
		return
	if bool(result.get("quest_in_log_after_reward", true)):
		push_error("QUEST_REWARD_BRIDGE_SMOKE_FAILED quest remained in log after reward")
		quit(1)
		return
	print("QUEST_REWARD_BRIDGE_SMOKE_OK source=%s before=%d after=%d xp=%d money=%d" % [
		str(result.get("source", "unknown")),
		int(result.get("before_populated", 0)),
		int(result.get("after_populated", 0)),
		int(result.get("reward_xp", 0)),
		int(result.get("reward_money", 0)),
	])
	quit(0)
