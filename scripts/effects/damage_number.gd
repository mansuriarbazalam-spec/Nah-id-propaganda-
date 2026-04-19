extends Node2D

## Floating damage/heal number that pops up, floats upward, and fades out.
## Set `value` and `color` before adding to the scene tree.
## White = damage to enemies, Red = sanity damage to player, Green = healing.

var value: float = 0.0
var color: Color = Color.WHITE
var float_speed: float = 40.0
var fade_duration: float = 0.8


func _ready() -> void:
	var label: Label = $Label
	label.text = str(int(absf(value)))
	label.modulate = color

	# Slight random horizontal offset for variety
	position.x += randf_range(-6.0, 6.0)

	# Animate float-up and fade-out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)
