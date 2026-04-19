extends Control

## Game Over screen — shown when the player's sanity is fully depleted.

@onready var retry_button: Button = %RetryButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	retry_button.pressed.connect(_on_retry_pressed)
	quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)

	GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.GAME_OVER:
		_show()
	else:
		_hide()


func _show() -> void:
	visible = true
	retry_button.grab_focus()


func _hide() -> void:
	visible = false


func _on_retry_pressed() -> void:
	GameManager.restart_level()


func _on_quit_to_menu_pressed() -> void:
	GameManager.return_to_menu()
