extends Node3D

const PORT := 19107
const MAX_CLIENTS := 8
const NPC_MAX_HEALTH := 100

var mode := "standalone"
var client_name := "LocalPlayer"
var expected_players := 2
var peer: ENetMultiplayerPeer
var players := {}
var player_nodes := {}
var event_log: Array[String] = []
var npc_health := NPC_MAX_HEALTH
var status_label: Label
var npc_label: Label
var player_list_label: Label
var self_test_client := false
var self_test_server := false
var self_test_attack_sent := false
var self_test_ok := false
var client_self_test_finishing := false
var server_self_test_finishing := false
var local_time := 0.0


func _ready() -> void:
	_build_world()
	_build_ui()
	mode = OS.get_environment("ACORE_MP_MODE").strip_edges()
	if mode.is_empty():
		mode = "standalone"
	client_name = OS.get_environment("ACORE_MP_CLIENT_NAME").strip_edges()
	if client_name.is_empty():
		client_name = "LocalPlayer"
	expected_players = max(1, int(OS.get_environment("ACORE_MP_EXPECTED_PLAYERS") if not OS.get_environment("ACORE_MP_EXPECTED_PLAYERS").is_empty() else "2"))
	self_test_client = OS.get_environment("ACORE_MP_CLIENT_SELF_TEST") == "1"
	self_test_server = OS.get_environment("ACORE_MP_SERVER_SELF_TEST") == "1"

	match mode:
		"server":
			_start_server()
		"client":
			_start_client()
		_:
			_start_standalone()


func _process(delta: float) -> void:
	local_time += delta
	if mode == "client" and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var offset := Vector3(sin(local_time) * 2.0, 0, cos(local_time) * 2.0)
		rpc_id(1, "_server_player_state", offset, "training_echo", "move")
		if self_test_client and not self_test_attack_sent and local_time > 0.8:
			self_test_attack_sent = true
			rpc_id(1, "_server_attack", "training_echo", 7)


func _exit_tree() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()


func _build_world() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.5
	add_child(light)

	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(18, 0.2, 18)
	floor_mesh.mesh = box
	floor_mesh.material_override = _material(Color(0.16, 0.20, 0.24))
	add_child(floor_mesh)

	var npc := MeshInstance3D.new()
	var npc_mesh := CapsuleMesh.new()
	npc_mesh.radius = 0.55
	npc_mesh.height = 1.8
	npc.mesh = npc_mesh
	npc.position = Vector3(0, 1.0, -3.5)
	npc.material_override = _material(Color(0.90, 0.28, 0.22))
	add_child(npc)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 7, 10)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	layer.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	status_label = _label()
	stack.add_child(status_label)
	npc_label = _label()
	stack.add_child(npc_label)
	player_list_label = _label()
	stack.add_child(player_list_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)

	var dashboard_button := Button.new()
	dashboard_button.text = "Dashboard"
	dashboard_button.custom_minimum_size = Vector2(140, 40)
	dashboard_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://main.tscn"))
	stack.add_child(dashboard_button)


func _start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		push_error("MULTIPLAYER_SERVER_FAILED: " + str(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	players[1] = {"name": "ServerHost", "position": Vector3.ZERO, "target": "training_echo", "state": "idle"}
	_log_event("server started")
	print("MULTIPLAYER_SERVER_READY")
	_update_ui()


func _start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", PORT)
	if error != OK:
		push_error("MULTIPLAYER_CLIENT_FAILED: " + str(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_log_event("client connecting")
	_update_ui()


func _start_standalone() -> void:
	players[1] = {"name": "Standalone", "position": Vector3.ZERO, "target": "training_echo", "state": "idle"}
	_log_event("standalone preview")
	_apply_snapshot(players, npc_health, event_log)


func _on_peer_connected(id: int) -> void:
	players[id] = {"name": "Peer " + str(id), "position": Vector3.ZERO, "target": "", "state": "idle"}
	_log_event("peer connected " + str(id))
	_sync_snapshot()


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	_log_event("peer disconnected " + str(id))
	if self_test_server:
		return
	_sync_snapshot()


func _on_connected_to_server() -> void:
	rpc_id(1, "_server_register", client_name)
	_log_event("connected")
	_update_ui()


func _on_connection_failed() -> void:
	push_error("MULTIPLAYER_CLIENT_FAILED: connection failed")
	if self_test_client:
		get_tree().quit(1)


func _on_server_disconnected() -> void:
	_log_event("server disconnected")
	if self_test_client and not self_test_ok:
		get_tree().quit(1)


@rpc("any_peer", "reliable")
func _server_register(name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = {"name": name, "position": Vector3.ZERO, "target": "training_echo", "state": "idle"}
	_log_event(name + " joined")
	_sync_snapshot()


@rpc("any_peer", "unreliable")
func _server_player_state(position: Vector3, target: String, state: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		players[sender] = {"name": "Peer " + str(sender), "position": Vector3.ZERO, "target": target, "state": state}
	players[sender]["position"] = position
	players[sender]["target"] = target
	players[sender]["state"] = state
	_sync_snapshot()


@rpc("any_peer", "reliable")
func _server_attack(target: String, amount: int) -> void:
	if not multiplayer.is_server() or target != "training_echo":
		return
	var sender := multiplayer.get_remote_sender_id()
	npc_health = max(0, npc_health - amount)
	_log_event(str(players.get(sender, {}).get("name", "Peer")) + " hit training_echo")
	_sync_snapshot()


func _sync_snapshot() -> void:
	_apply_snapshot(players, npc_health, event_log)
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc("_client_snapshot", players, npc_health, event_log)
	_maybe_finish_server_self_test()


@rpc("authority", "reliable")
func _client_snapshot(snapshot: Dictionary, shared_npc_health: int, events: Array) -> void:
	_apply_snapshot(snapshot, shared_npc_health, events)


func _apply_snapshot(snapshot: Dictionary, shared_npc_health: int, events: Array) -> void:
	players = snapshot.duplicate(true)
	npc_health = shared_npc_health
	event_log.clear()
	for event in events:
		event_log.append(str(event))
	_update_player_nodes()
	_update_ui()
	_maybe_finish_client_self_test()


func _update_player_nodes() -> void:
	for id in player_nodes.keys():
		if not players.has(id):
			player_nodes[id].queue_free()
			player_nodes.erase(id)
	for id in players.keys():
		if not player_nodes.has(id):
			player_nodes[id] = _create_player_node(int(id))
		var info: Dictionary = players[id]
		player_nodes[id].position = info.get("position", Vector3.ZERO)


func _create_player_node(id: int) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.6
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0.9, 0)
	mesh_instance.material_override = _material(Color(0.22 + float(id % 4) * 0.15, 0.58, 0.92))
	add_child(mesh_instance)
	return mesh_instance


func _update_ui() -> void:
	if status_label == null:
		return
	status_label.text = "Mode: " + mode + " | Players: " + str(players.size())
	npc_label.text = "Shared NPC Health: " + str(npc_health)
	var names := PackedStringArray()
	for id in players.keys():
		var info: Dictionary = players[id]
		names.append(str(info.get("name", "Peer " + str(id))) + " " + str(info.get("state", "idle")))
	player_list_label.text = "Peers: " + ", ".join(names)


func _maybe_finish_client_self_test() -> void:
	if not self_test_client or self_test_ok or client_self_test_finishing:
		return
	if players.size() >= expected_players and npc_health < NPC_MAX_HEALTH:
		self_test_ok = true
		client_self_test_finishing = true
		print("MULTIPLAYER_CLIENT_SELF_TEST_OK " + client_name)
		_finish_client_self_test()


func _finish_client_self_test() -> void:
	await get_tree().create_timer(0.75).timeout
	get_tree().quit(0)


func _maybe_finish_server_self_test() -> void:
	if not self_test_server or server_self_test_finishing:
		return
	if players.size() >= expected_players + 1 and npc_health < NPC_MAX_HEALTH:
		server_self_test_finishing = true
		print("MULTIPLAYER_SERVER_SELF_TEST_OK")
		_finish_server_self_test()


func _finish_server_self_test() -> void:
	await get_tree().create_timer(0.75).timeout
	get_tree().quit(0)


func _log_event(message: String) -> void:
	event_log.append(message)
	if event_log.size() > 8:
		event_log.pop_front()


func _label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	return label


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
