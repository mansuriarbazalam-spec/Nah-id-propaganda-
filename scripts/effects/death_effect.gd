extends Node2D

## Burst of dark/red particles when an enemy dies.
## Includes a brief screen flash. Self-destructs after 1 second.


func _ready() -> void:
	var particles: CPUParticles2D = $CPUParticles2D
	particles.emitting = true

	# Trigger a brief flash via EffectsManager if available
	if EffectsManager:
		EffectsManager.screen_flash(Color(1.0, 0.9, 0.8), 0.08)

	# Self-destruct after 1 second
	await get_tree().create_timer(1.0).timeout
	queue_free()
