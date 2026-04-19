extends Control

## Settings menu with audio, display, and controls sections.
## Saves/loads settings to user://settings.json.

signal settings_closed

const SETTINGS_PATH: String = "user://settings.json"

var settings: Dictionary = {
	"master_volume": 80,
	"music_volume": 70,
	"sfx_volume": 100,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": true,
}

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var vsync_toggle: CheckButton = %VSyncToggle
@onready var screen_shake_toggle: CheckButton = %ScreenShakeToggle
@onready var back_button: Button = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_ui_from_settings()
	_apply_settings()

	# Connect signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	screen_shake_toggle.toggled.connect(_on_screen_shake_toggled)
	back_button.pressed.connect(_on_back_pressed)


func _apply_ui_from_settings() -> void:
	master_slider.value = settings["master_volume"]
	music_slider.value = settings["music_volume"]
	sfx_slider.value = settings["sfx_volume"]
	master_value_label.text = str(int(settings["master_volume"]))
	music_value_label.text = str(int(settings["music_volume"]))
	sfx_value_label.text = str(int(settings["sfx_volume"]))
	fullscreen_toggle.button_pressed = settings["fullscreen"]
	vsync_toggle.button_pressed = settings["vsync"]
	screen_shake_toggle.button_pressed = settings["screen_shake"]


func _apply_settings() -> void:
	# Audio buses: Master=0, Music=1, SFX=2
	_set_bus_volume(0, settings["master_volume"])
	_set_bus_volume(1, settings["music_volume"])
	_set_bus_volume(2, settings["sfx_volume"])

	# Display
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if settings["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _set_bus_volume(bus_index: int, value: float) -> void:
	if bus_index >= AudioServer.bus_count:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		var db: float = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(bus_index, db)


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error == OK and json.data is Dictionary:
		var loaded: Dictionary = json.data
		for key in settings.keys():
			if loaded.has(key):
				settings[key] = loaded[key]


func _on_master_volume_changed(value: float) -> void:
	settings["master_volume"] = value
	master_value_label.text = str(int(value))
	_apply_settings()
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	settings["music_volume"] = value
	music_value_label.text = str(int(value))
	_apply_settings()
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	settings["sfx_volume"] = value
	sfx_value_label.text = str(int(value))
	_apply_settings()
	_save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
	settings["fullscreen"] = pressed
	_apply_settings()
	_save_settings()


func _on_vsync_toggled(pressed: bool) -> void:
	settings["vsync"] = pressed
	_apply_settings()
	_save_settings()


func _on_screen_shake_toggled(pressed: bool) -> void:
	settings["screen_shake"] = pressed
	_save_settings()


func _on_back_pressed() -> void:
	settings_closed.emit()
	queue_free()
