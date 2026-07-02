extends Node

var host := "127.0.0.1"
var port := "3724"
var account := ""
var password := ""
var authenticated := false
var characters: Array = []
var selected_character: Dictionary = {}
var last_login_result: Dictionary = {}
var last_enter_world_result: Dictionary = {}


func set_connection(next_host: String, next_port: String, next_account: String, next_password: String) -> void:
	host = next_host.strip_edges()
	port = next_port.strip_edges()
	account = next_account.strip_edges()
	password = next_password


func set_roster(result: Dictionary, normalized_characters: Array) -> void:
	last_login_result = result.duplicate(true)
	characters = normalized_characters.duplicate(true)
	authenticated = bool(result.get("ok", false))
	selected_character = {}


func set_selected_character(character: Dictionary) -> void:
	selected_character = character.duplicate(true)


func set_enter_world_result(result: Dictionary) -> void:
	last_enter_world_result = result.duplicate(true)


func clear_runtime_secret() -> void:
	password = ""
