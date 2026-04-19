extends Area2D

## Checkpoint save/respawn point.
## When the player enters, it activates, restores some sanity,
## saves the game, and changes appearance.

@export var checkpoint_id: String = "checkpoint_01"
@export var sanity_restore: float = 30.0

var is_activated: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	if not body.is_in_group("player"):
		return

	activate()


func activate() -> void:
	if is_activated:
		return

	is_activated = true

	# Restore sanity
	SanityManager.heal_sanity(sanity_restore)

	# Save the game at this checkpoint
	SaveManager.save_at_checkpoint(checkpoint_id)

	# Visual change — turn from grey to glowing cyan
	var pillar := get_node_or_null("PillarVisual")
	if pillar and pillar is ColorRect:
		var tween := create_tween()
		tween.tween_property(pillar, "color", Color(0.2, 0.8, 1.0, 1.0), 0.5)

	var label := get_node_or_null("SaveLabel")
	if label and label is Label:
		label.text = "SAVED"
		label.modulate = Color(0.2, 1.0, 0.5)
