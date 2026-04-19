extends CanvasLayer

## Simple dialogue box for NPC conversations and boss taunts.
## Shows text with a typewriter effect at the bottom of the screen.
##
## Usage:
##   var dlg = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
##   add_child(dlg)
##   dlg.show_dialogue("Old Man", "The propaganda never sleeps...")
##   await dlg.dialogue_finished

signal dialogue_finished

const CHAR_DELAY: float = 0.03  # seconds per character

@onready var panel: PanelContainer = %DialoguePanel
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel

var _full_text: String = ""
var _visible_chars: int = 0
var _typing: bool = false
var _char_timer: float = 0.0
var _dialogue_queue: Array = []  # Array of {speaker, text}
var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false


func _process(delta: float) -> void:
	if not _typing:
		return

	_char_timer += delta
	while _char_timer >= CHAR_DELAY and _visible_chars < _full_text.length():
		_visible_chars += 1
		text_label.visible_characters = _visible_chars
		_char_timer -= CHAR_DELAY

	if _visible_chars >= _full_text.length():
		_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	var advance := false
	if event.is_action_pressed("interact"):
		advance = true
	elif event.is_action_pressed("attack_melee"):
		advance = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		advance = true

	if advance:
		get_viewport().set_input_as_handled()
		if _typing:
			# Skip to end of current text
			_visible_chars = _full_text.length()
			text_label.visible_characters = _visible_chars
			_typing = false
		else:
			_advance_dialogue()


## Show a single line of dialogue.
func show_dialogue(speaker: String, text: String) -> void:
	_dialogue_queue.clear()
	_dialogue_queue.append({"speaker": speaker, "text": text})
	_start_next_dialogue()


## Show a sequence of dialogue lines.
## Each element should be a Dictionary with "speaker" and "text" keys.
func show_dialogue_sequence(dialogues: Array) -> void:
	_dialogue_queue.clear()
	for d in dialogues:
		_dialogue_queue.append(d)
	_start_next_dialogue()


func _start_next_dialogue() -> void:
	if _dialogue_queue.is_empty():
		_close()
		return

	var entry: Dictionary = _dialogue_queue.pop_front()
	_active = true
	panel.visible = true

	speaker_label.text = entry.get("speaker", "")
	_full_text = entry.get("text", "")
	text_label.text = _full_text
	_visible_chars = 0
	text_label.visible_characters = 0
	_typing = true
	_char_timer = 0.0


func _advance_dialogue() -> void:
	if _dialogue_queue.is_empty():
		_close()
	else:
		_start_next_dialogue()


func _close() -> void:
	_active = false
	_typing = false
	panel.visible = false
	dialogue_finished.emit()
