extends Area2D

## Propaganda bomb projectile dropped by drones or thrown by soldiers.
## Falls with gravity, deals sanity damage on player contact, and explodes on
## world contact. Self-destructs after a timeout.

@export var sanity_damage: float = 15.0
@export var gravity: float = 400.0
@export var lifetime: float = 5.0
@export var splash_radius: float = 24.0
@export var initial_velocity: Vector2 = Vector2.ZERO

var _velocity: Vector2 = Vector2.ZERO
var _lifetime_timer: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	_velocity = initial_velocity
	_lifetime_timer = lifetime

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	# Apply gravity
	_velocity.y += gravity * delta

	# Move
	position += _velocity * delta

	# Lifetime check
	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if _exploded:
		return

	if body.is_in_group("player"):
		# Direct hit on player — go through player's damage system (respects shield)
		_deal_damage_to_node(body)
		_explode()
	elif body is StaticBody2D or body is TileMapLayer:
		# Hit the world
		_explode()


func _on_area_entered(area: Area2D) -> void:
	if _exploded:
		return

	# Check if we hit the player's hurt box
	if area.get_parent() and area.get_parent().is_in_group("player"):
		# Damage is handled by the player's HurtBox detecting this bomb via get_damage().
		# Just explode here to avoid double-damage.
		_explode()


func _deal_damage_to_node(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(sanity_damage, global_position)
	else:
		SanityManager.take_sanity_damage(sanity_damage)


func get_damage() -> float:
	return sanity_damage


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	# Splash damage check — find players in splash radius
	var space_state := get_world_2d().direct_space_state
	if space_state:
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p):
				var dist := global_position.distance_to(p.global_position)
				if dist <= splash_radius and dist > 5.0:
					# Reduced splash damage based on distance
					var splash_mult := 1.0 - (dist / splash_radius)
					var splash_dmg := sanity_damage * splash_mult * 0.5
					if p.has_method("take_damage"):
						p.take_damage(splash_dmg, global_position)
					else:
						SanityManager.take_sanity_damage(splash_dmg)

	# Visual explosion effect: flash and expand then vanish
	var visual := get_node_or_null("BombVisual")
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector2(3.0, 3.0), 0.15)
		tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
	else:
		queue_free()
