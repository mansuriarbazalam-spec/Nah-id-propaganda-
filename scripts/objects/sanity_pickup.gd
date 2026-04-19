extends Area2D

## Collectible orb that restores the player's sanity when touched.
## Floats up and down with a gentle bob animation.

@export var sanity_amount: float = 10.0

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU  # random start phase so pickups don't bob in sync

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta * 3.0
	position.y = _base_y + sin(_time) * 3.0


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collect()


func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	if area.is_in_group("player"):
		_collect()


func _collect() -> void:
	_collected = true

	SanityManager.heal_sanity(sanity_amount)

	# Quick flash/scale effect
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
