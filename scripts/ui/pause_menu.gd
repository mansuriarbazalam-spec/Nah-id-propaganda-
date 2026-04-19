extends Control

## Pause menu overlay — shown when the game is paused.

@onready var resume_button: Button = %ResumeButton
@onready var skill_tree_button: Button = %SkillTreeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton

const SKILL_TREE_SCENE: String = "res://scenes/ui/skill_tree.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/settings_menu.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)

	GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PAUSED:
		_show()
	else:
		_hide()


func _show() -> void:
	visible = true
	resume_button.grab_focus()


func _hide() -> void:
	visible = false


func _on_resume_pressed() -> void:
	GameManager.resume_game()


func _on_skill_tree_pressed() -> void:
	var skill_tree_scene: PackedScene = load(SKILL_TREE_SCENE)
	if skill_tree_scene:
		var skill_tree := skill_tree_scene.instantiate()
		add_child(skill_tree)


func _on_settings_pressed() -> void:
	var settings_scene: PackedScene = load(SETTINGS_SCENE)
	if settings_scene:
		var settings_menu := settings_scene.instantiate()
		add_child(settings_menu)


func _on_quit_to_menu_pressed() -> void:
	GameManager.return_to_menu()
