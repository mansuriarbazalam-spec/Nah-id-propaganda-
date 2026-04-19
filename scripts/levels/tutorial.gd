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
	_setup_torch_animations()


func _setup_torch_animations() -> void:
	# Build a shared SpriteFrames resource for the flickering-torch animation
	# and attach it to every AnimatedSprite2D under Decorations whose name
	# starts with "Torch".
	var torch_tex: Texture2D = load("res://assets/props/torch_sheet.png")
	if torch_tex == null:
		return
	var sf := SpriteFrames.new()
	sf.add_animation("flicker")
	sf.set_animation_speed("flicker", 12.0)
	sf.set_animation_loop("flicker", true)
	# 96x64 sheet → 6 horizontal frames of 16x64
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = torch_tex
		at.region = Rect2(i * 16, 0, 16, 64)
		sf.add_frame("flicker", at)

	var decor := get_node_or_null("Decorations")
	if decor == null:
		return
	for child in decor.get_children():
		if child is AnimatedSprite2D and child.name.begins_with("Torch"):
			child.sprite_frames = sf
			child.play("flicker")


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
