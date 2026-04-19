extends LevelBase

## Tutorial level — teaches the player basic mechanics.
## Simple left-to-right layout with prompts for controls.

func _ready() -> void:
	level_name = "Tutorial"
	next_level_path = "res://scenes/levels/level_01.tscn"
	super._ready()


func _on_level_ready() -> void:
	# Tutorial-specific setup: fade in prompts sequentially or on trigger
	_setup_tutorial_triggers()


func _setup_tutorial_triggers() -> void:
	# Connect tutorial prompt trigger areas
	var prompts_node := get_node_or_null("TutorialPrompts")
	if prompts_node == null:
		return

	for child in prompts_node.get_children():
		if child is Area2D:
			child.body_entered.connect(_on_prompt_trigger_entered.bind(child))


func _on_prompt_trigger_entered(body: Node2D, trigger: Area2D) -> void:
	if not body.is_in_group("player"):
		return

	# Show the label inside this trigger area
	for child in trigger.get_children():
		if child is Label:
			child.visible = true
			# Fade out after a few seconds
			var tween := create_tween()
			tween.tween_interval(4.0)
			tween.tween_property(child, "modulate:a", 0.0, 1.0)

	# Disable the trigger so it only fires once
	trigger.set_deferred("monitoring", false)
