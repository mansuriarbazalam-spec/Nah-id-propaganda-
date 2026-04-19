extends Node2D

## Small spark burst on hit. Uses CPUParticles2D for compatibility.
## Self-destructs after particles finish.


func _ready() -> void:
	var particles: CPUParticles2D = $CPUParticles2D
	particles.emitting = true

	# Wait for particles to finish, then self-destruct
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	queue_free()
