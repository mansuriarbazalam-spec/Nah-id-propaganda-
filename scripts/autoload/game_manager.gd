extends Node

## Manages overall game state, scene transitions, and level tracking.

signal level_changed(level_path: String)
signal game_state_changed(new_state: GameState)
signal level_completed(level_path: String)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, CUTSCENE }

var current_state: GameState = GameState.MENU
var current_level: String = ""
var completed_levels: Array[String] = []

# Fade transition node — created at runtime
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null

const FADE_DURATION: float = 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_fade_overlay()


func _create_fade_overlay() -> void:
	# Create a full-screen ColorRect used for fade transitions
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeOverlay"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use a CanvasLayer so it draws on top of everything
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "FadeLayer"
	canvas_layer.layer = 100
	canvas_layer.add_child(_fade_rect)
	add_child(canvas_layer)
	# Anchor full rect after it enters the tree
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()


## Transition to a new level with a fade effect.
func change_level(level_path: String) -> void:
	_fade_out_then(func():
		current_level = level_path
		get_tree().change_scene_to_file(level_path)
		_set_state(GameState.PLAYING)
		level_changed.emit(level_path)
		_fade_in()
	)


## Pause the game.
func pause_game() -> void:
	get_tree().paused = true
	_set_state(GameState.PAUSED)


## Resume the game from pause.
func resume_game() -> void:
	get_tree().paused = false
	_set_state(GameState.PLAYING)


## Trigger game over state.
func game_over() -> void:
	_set_state(GameState.GAME_OVER)
	get_tree().paused = true


## Restart the current level.
func restart_level() -> void:
	get_tree().paused = false
	if current_level != "":
		change_level(current_level)
	else:
		get_tree().reload_current_scene()
		_set_state(GameState.PLAYING)


## Mark a level as completed.
func complete_level(level_path: String) -> void:
	if level_path not in completed_levels:
		completed_levels.append(level_path)
	level_completed.emit(level_path)


## Check if a level has been completed.
func is_level_completed(level_path: String) -> bool:
	return level_path in completed_levels


## Return to main menu.
func return_to_menu() -> void:
	get_tree().paused = false
	_fade_out_then(func():
		current_level = ""
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		_set_state(GameState.MENU)
		_fade_in()
	)


func _set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)


func _fade_out_then(callback: Callable) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	_fade_tween.tween_callback(callback)


func _fade_in() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
