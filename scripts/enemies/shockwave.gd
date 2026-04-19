extends Area2D

## Shockwave projectile that travels along the ground.
## Used by the Propaganda Lieutenant's "Slogan Shout" attack.
## Displays propaganda text and damages the player on contact.

@export var speed: float = 120.0
@export var sanity_damage: float = 12.0
@export var max_distance: float = 300.0
@export var direction: float = 1.0  # 1 = right, -1 = left

var _distance_traveled: float = 0.0
var _destroyed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Flip visual if going left
	if direction < 0.0:
		var label := get_node_or_null("ShockwaveVisual/SloganLabel")
		if label:
			label.scale.x = -1.0


func _physics_process(delta: float) -> void:
	if _destroyed:
		return

	var movement := speed * direction * delta
	position.x += movement
	_distance_traveled += absf(movement)

	if _distance_traveled >= max_distance:
		_destroy()


func _on_body_entered(body: Node2D) -> void:
	if _destroyed:
		return

	if body.is_in_group("player"):
		_deal_damage()
		_destroy()
	elif body is StaticBody2D or body is TileMapLayer:
		# Hit a wall
		_destroy()


func _on_area_entered(area: Area2D) -> void:
	if _destroyed:
		return

	if area.get_parent() and area.get_parent().is_in_group("player"):
		_deal_damage()
		_destroy()


func _deal_damage() -> void:
	SanityManager.take_sanity_damage(sanity_damage)


func get_damage() -> float:
	return sanity_damage


func _destroy() -> void:
	if _destroyed:
		return
	_destroyed = true

	var visual := get_node_or_null("ShockwaveVisual")
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
	else:
		queue_free()
