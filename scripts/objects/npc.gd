extends StaticBody2D

## Brainwashed citizen NPC that can be deprogrammed by the player.
## Starts brainwashed, spouting propaganda slogans. Player holds interact (E) to deprogram.
## Once freed, the NPC changes appearance and restores some sanity.

enum NPCState { BRAINWASHED, DEPROGRAMMING, FREE }

@export var sanity_reward: float = 15.0
@export var deprogram_time: float = 3.0

const PROPAGANDA_SLOGANS: Array[String] = [
	"THE SUPREME LEADER LOVES YOU",
	"FREEDOM IS OVERRATED",
	"REPORT YOUR NEIGHBORS",
	"IGNORANCE IS STRENGTH",
	"CONSUME. OBEY. REPEAT.",
	"QUESTIONING IS A CRIME",
	"THE LEADER KNOWS BEST",
	"DOUBT IS A DISEASE",
	"COMPLIANCE IS HAPPINESS",
	"INDIVIDUALITY IS WEAKNESS",
]

var current_state: NPCState = NPCState.BRAINWASHED
var _player_in_range: bool = false
var _deprogram_progress: float = 0.0
var _slogan_timer: float = 0.0
var _slogan_interval: float = 3.0


func _ready() -> void:
	var interact_zone := get_node_or_null("InteractZone")
	if interact_zone and interact_zone is Area2D:
		interact_zone.body_entered.connect(_on_interact_zone_body_entered)
		interact_zone.body_exited.connect(_on_interact_zone_body_exited)

	_update_slogan()

	# Hide progress bar initially
	var progress_bar := get_node_or_null("ProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.visible = false
		progress_bar.max_value = deprogram_time
		progress_bar.value = 0.0


func _physics_process(delta: float) -> void:
	match current_state:
		NPCState.BRAINWASHED:
			_state_brainwashed(delta)
		NPCState.DEPROGRAMMING:
			_state_deprogramming(delta)
		NPCState.FREE:
			pass


func _state_brainwashed(delta: float) -> void:
	# Cycle through propaganda slogans
	_slogan_timer -= delta
	if _slogan_timer <= 0.0:
		_update_slogan()
		_slogan_timer = _slogan_interval

	# Check if player starts interacting
	if _player_in_range and Input.is_action_pressed("interact"):
		_start_deprogramming()


func _state_deprogramming(delta: float) -> void:
	if not _player_in_range or not Input.is_action_pressed("interact"):
		# Player stopped or left — cancel deprogramming
		_cancel_deprogramming()
		return

	_deprogram_progress += delta

	# Update progress bar
	var progress_bar := get_node_or_null("ProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.value = _deprogram_progress

	# Update slogan to show confusion
	var slogan_label := get_node_or_null("SloganLabel")
	if slogan_label and slogan_label is Label:
		var ratio := _deprogram_progress / deprogram_time
		if ratio < 0.33:
			slogan_label.text = "W-what are you doing...?"
		elif ratio < 0.66:
			slogan_label.text = "I... I can't think..."
		else:
			slogan_label.text = "The truth... I see it!"

	if _deprogram_progress >= deprogram_time:
		_complete_deprogramming()


func _start_deprogramming() -> void:
	current_state = NPCState.DEPROGRAMMING
	_deprogram_progress = 0.0

	var progress_bar := get_node_or_null("ProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.visible = true
		progress_bar.value = 0.0


func _cancel_deprogramming() -> void:
	current_state = NPCState.BRAINWASHED
	_deprogram_progress = 0.0

	var progress_bar := get_node_or_null("ProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.visible = false
		progress_bar.value = 0.0

	_update_slogan()


func _complete_deprogramming() -> void:
	current_state = NPCState.FREE
	_deprogram_progress = deprogram_time

	# Hide progress bar
	var progress_bar := get_node_or_null("ProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.visible = false

	# Reward player
	SanityManager.heal_sanity(sanity_reward)

	# Change NPC appearance — turn from grey/red to green/friendly
	var body_visual := get_node_or_null("BodyVisual")
	if body_visual and body_visual is ColorRect:
		var tween := create_tween()
		tween.tween_property(body_visual, "color", Color(0.3, 0.7, 0.4), 0.5)

	# Update slogan to thank the player
	var slogan_label := get_node_or_null("SloganLabel")
	if slogan_label and slogan_label is Label:
		slogan_label.text = "Thank you... I'm free!"
		slogan_label.modulate = Color(0.3, 1.0, 0.5)

	# After a moment, change to an idle message
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self) and slogan_label:
		slogan_label.text = "Stay free, friend."


func _update_slogan() -> void:
	var slogan_label := get_node_or_null("SloganLabel")
	if slogan_label and slogan_label is Label:
		var idx := randi() % PROPAGANDA_SLOGANS.size()
		slogan_label.text = PROPAGANDA_SLOGANS[idx]


func _on_interact_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

		# Show interact prompt if still brainwashed
		if current_state == NPCState.BRAINWASHED:
			var prompt := get_node_or_null("InteractPrompt")
			if prompt and prompt is Label:
				prompt.visible = true


func _on_interact_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false

		# Hide interact prompt
		var prompt := get_node_or_null("InteractPrompt")
		if prompt and prompt is Label:
			prompt.visible = false

		# Cancel deprogramming if in progress
		if current_state == NPCState.DEPROGRAMMING:
			_cancel_deprogramming()
