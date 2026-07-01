extends Control

const ProtocolClientBridge = preload("res://scripts/protocol_client_bridge.gd")

const TEST_CHARACTER_NAME := "Codexstage"
const TEST_MESSAGE := "Codex Stage16 chat probe"

var status_label: Label
var chat_log: TextEdit
var message_input: LineEdit
var send_button: Button
var self_test_finished := false


func _ready() -> void:
	_build_view()
	if OS.get_environment("ACORE_CHAT_SELF_TEST") == "1":
		call_deferred("_send_self_test_message")


func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.075)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)

	var title := Label.new()
	title.text = "Chat"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	status_label = Label.new()
	status_label.text = "Ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	chat_log = TextEdit.new()
	chat_log.editable = false
	chat_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.custom_minimum_size = Vector2(0, 420)
	stack.add_child(chat_log)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	stack.add_child(input_row)

	message_input = LineEdit.new()
	message_input.text = TEST_MESSAGE
	message_input.placeholder_text = "Message"
	message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_input.text_submitted.connect(_on_message_submitted)
	input_row.add_child(message_input)

	send_button = Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(104, 38)
	send_button.pressed.connect(_on_send_pressed)
	input_row.add_child(send_button)


func _on_send_pressed() -> void:
	_send_chat_message(message_input.text.strip_edges())


func _on_message_submitted(message: String) -> void:
	_send_chat_message(message.strip_edges())


func _send_self_test_message() -> void:
	_send_chat_message(TEST_MESSAGE)


func _send_chat_message(message: String) -> void:
	if message.is_empty():
		return

	status_label.text = "Sending"
	send_button.disabled = true
	_append_log("> " + message)

	var bridge := ProtocolClientBridge.new()
	var result := bridge.chat_say(TEST_CHARACTER_NAME, message)
	if bool(result.get("ok", false)):
		var opcode := int(result.get("response_opcode", 0))
		var chat_type := int(result.get("chat_type", 0))
		var language := int(result.get("language", 0))
		status_label.text = "Echoed 0x%s" % _opcode_hex(opcode)
		_append_log("[Say] %s: %s" % [TEST_CHARACTER_NAME, str(result.get("received_message", message))])
		_finish_self_test(true, {
			"response_opcode": opcode,
			"chat_type": chat_type,
			"language": language,
		})
	else:
		status_label.text = "Failed"
		_append_log(str(result.get("error", result.get("output", "Unknown failure"))))
		_finish_self_test(false, result)

	send_button.disabled = false


func _append_log(line: String) -> void:
	if chat_log != null:
		chat_log.text += line + "\n"
		chat_log.scroll_vertical = chat_log.get_line_count()
	print(line)


func _opcode_hex(value: int) -> String:
	return "%03x" % [value & 0xFFFF]


func _finish_self_test(ok: bool, result: Dictionary) -> void:
	if OS.get_environment("ACORE_CHAT_SELF_TEST") != "1":
		return
	if self_test_finished:
		return
	self_test_finished = true

	if ok:
		print("CHAT_SELF_TEST_OK response_opcode=0x%s chat_type=%s language=%s" % [
			_opcode_hex(int(result.get("response_opcode", 0))),
			str(result.get("chat_type", "?")),
			str(result.get("language", "?")),
		])
		get_tree().quit(0)
	else:
		push_error("CHAT_SELF_TEST_FAILED: " + str(result.get("error", result.get("output", "unknown"))))
		get_tree().quit(1)
