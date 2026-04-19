extends Node2D

## Visual feedback when the Clarity Shield blocks an attack.
## Blue/cyan particle ripple expanding outward. Self-destructs.


func _ready() -> void:
	var particles: CPUParticles2D = $CPUParticles2D
	particles.emitting = true

	# Wait for particles to finish, then self-destruct
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	queue_free()
