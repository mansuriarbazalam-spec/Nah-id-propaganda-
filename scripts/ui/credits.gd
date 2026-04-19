extends Control

## Credits screen — scrolling text that returns to the main menu
## when finished or when the player presses any key.

const SCROLL_SPEED: float = 30.0
const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"

@onready var credits_label: Label = %CreditsLabel
var _scroll_offset: float = 0.0
var _finished: bool = false


func _ready() -> void:
	# Start label just below the visible screen
	credits_label.position.y = get_viewport_rect().size.y


func _process(delta: float) -> void:
	if _finished:
		return

	credits_label.position.y -= SCROLL_SPEED * delta

	# Check if entire text has scrolled past the top
	var label_height: float = credits_label.size.y
	if credits_label.position.y + label_height < 0.0:
		_return_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed:
		_return_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_return_to_menu()
	elif event is InputEventJoypadButton and event.pressed:
		_return_to_menu()


func _return_to_menu() -> void:
	_finished = true
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
