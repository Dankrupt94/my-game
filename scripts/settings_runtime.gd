extends RefCounted

const SETTINGS_FILE_PATH := "user://settings.cfg"
const SETTINGS_SELF_TEST_FILE_PATH := "user://settings-self-test.cfg"

const DEFAULT_SETTINGS := {
	"video": {
		"resolution": "1280x720",
		"fullscreen": false,
		"vsync": true
	},
	"audio": {
		"volume_master": 0.8,
		"volume_music": 0.6,
		"volume_sfx": 0.7,
		"volume_ambience": 0.5
	},
	"gameplay": {
		"auto_loot": true,
		"quest_tracker": true,
		"detailed_tooltips": true
	},
	"keybindings": {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"camera_left": KEY_Q,
		"camera_right": KEY_E,
		"target_next": KEY_TAB,
		"attack_primary": KEY_1,
		"interact": KEY_F,
		"reset_sandbox": KEY_R,
		"jump": KEY_SPACE
	}
}


static func default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate(true)


static func settings_file_exists(path: String = SETTINGS_FILE_PATH) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


static func load_settings(path: String = SETTINGS_FILE_PATH) -> Dictionary:
	var loaded := default_settings()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return loaded

	for section in loaded.keys():
		for key in loaded[section].keys():
			if config.has_section_key(section, key):
				loaded[section][key] = config.get_value(section, key)
	return loaded


static func save_settings(settings: Dictionary, path: String = SETTINGS_FILE_PATH) -> Error:
	var config := ConfigFile.new()
	for section in settings.keys():
		for key in settings[section].keys():
			config.set_value(section, key, settings[section][key])
	return config.save(path)


static func apply_runtime_settings(settings: Dictionary) -> void:
	apply_video_settings(settings)
	apply_audio_settings(settings)
	apply_keybindings(settings)


static func apply_video_settings(settings: Dictionary) -> void:
	var video: Dictionary = settings.get("video", {})
	var fs_mode: int = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if bool(video.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(fs_mode)
	if fs_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution_to_size(str(video.get("resolution", "1280x720"))))

	var vs_mode: int = DisplayServer.VSYNC_ENABLED if bool(video.get("vsync", true)) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vs_mode)


static func apply_audio_settings(settings: Dictionary) -> void:
	var audio: Dictionary = settings.get("audio", {})
	apply_bus_volume("Master", float(audio.get("volume_master", 0.8)))
	apply_bus_volume("Music", float(audio.get("volume_music", 0.6)))
	apply_bus_volume("SFX", float(audio.get("volume_sfx", 0.7)))
	apply_bus_volume("Ambience", float(audio.get("volume_ambience", 0.5)))


static func apply_bus_volume(bus_name: String, value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	AudioServer.set_bus_mute(bus_idx, value <= 0.001)
	if value > 0.001:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


static func apply_keybindings(settings: Dictionary) -> void:
	var keybindings: Dictionary = settings.get("keybindings", {})
	for action in keybindings.keys():
		var keycode := int(keybindings[action])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)

		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


static func resolution_to_size(value: String) -> Vector2i:
	var parts := value.split("x")
	if parts.size() != 2:
		return Vector2i(1280, 720)
	var width := int(parts[0])
	var height := int(parts[1])
	if width <= 0 or height <= 0:
		return Vector2i(1280, 720)
	return Vector2i(width, height)


static func delete_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
