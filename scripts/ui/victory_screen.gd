extends Control

## Victory screen shown after defeating the first boss (end of demo).
## Text fades in sequence, then buttons appear.

@onready var victory_label: Label = %VictoryLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var mind_clear_label: Label = %MindClearLabel
@onready var demo_complete_label: Label = %DemoCompleteLabel
@onready var continue_message_label: Label = %ContinueMessageLabel
@onready var return_to_menu_button: Button = %ReturnToMenuButton
@onready var quit_button: Button = %QuitButton
@onready var button_container: VBoxContainer = %ButtonContainer

const FADE_DURATION: float = 1.0
const FADE_DELAY: float = 0.8


func _ready() -> void:
	# Ensure game is unpaused
	get_tree().paused = false

	# Hide everything initially for the fade-in sequence
	victory_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	mind_clear_label.modulate.a = 0.0
	demo_complete_label.modulate.a = 0.0
	continue_message_label.modulate.a = 0.0
	button_container.modulate.a = 0.0

	# Connect buttons
	return_to_menu_button.pressed.connect(_on_return_to_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Start the fade-in sequence
	_play_fade_sequence()


func _play_fade_sequence() -> void:
	var tween := create_tween()

	# Victory title fades in first
	tween.tween_property(victory_label, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(FADE_DELAY)

	# Subtitle
	tween.tween_property(subtitle_label, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(FADE_DELAY)

	# Mind clear message
	tween.tween_property(mind_clear_label, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(FADE_DELAY)

	# Demo complete
	tween.tween_property(demo_complete_label, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(FADE_DELAY)

	# Continue message
	tween.tween_property(continue_message_label, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(FADE_DELAY)

	# Buttons fade in last
	tween.tween_property(button_container, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(func(): return_to_menu_button.grab_focus())


func _on_return_to_menu_pressed() -> void:
	GameManager.return_to_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
