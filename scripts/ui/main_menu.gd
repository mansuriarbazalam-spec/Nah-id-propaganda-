extends Control

## Main menu screen with New Game, Continue, Settings, and Quit buttons.

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

# Path to the first level / tutorial
const TUTORIAL_LEVEL: String = "res://scenes/levels/tutorial.tscn"
const CREDITS_SCENE: String = "res://scenes/ui/credits.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/settings_menu.tscn"


func _ready() -> void:
	# Ensure game is unpaused when returning to menu
	get_tree().paused = false

	# Disable Continue button if there is no save file
	continue_button.disabled = not SaveManager.has_save()
	if continue_button.disabled:
		continue_button.tooltip_text = "No saved game found"

	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Give focus to New Game button for keyboard/gamepad navigation
	new_game_button.grab_focus()

	# Kick off dark ambient music under the menu
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ambient"):
		am.play_ambient("res://assets/audio/music/dark_ambient_loop.ogg", 3.0)


func _on_new_game_pressed() -> void:
	# Delete any existing save to start fresh
	SaveManager.delete_save()
	SanityManager.reset_sanity()
	GameManager.completed_levels.clear()
	GameManager.change_level(TUTORIAL_LEVEL)


func _on_continue_pressed() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()


func _on_settings_pressed() -> void:
	var settings_scene: PackedScene = load(SETTINGS_SCENE)
	if settings_scene:
		var settings_menu := settings_scene.instantiate()
		settings_menu.settings_closed.connect(func(): new_game_button.grab_focus())
		add_child(settings_menu)


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
