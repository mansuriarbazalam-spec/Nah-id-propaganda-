extends Area2D

## Player ranged projectile.
## Travels in a straight line, damages enemies on contact, and
## destroys itself after hitting something or exceeding its lifetime.

# ── Constants ───────────────────────────────────────────────────────
const SPEED: float = 250.0
const MAX_LIFETIME: float = 1.5   # seconds before auto-destroy
const MAX_RANGE: float = 300.0    # pixels before auto-destroy

# ── Runtime state ───────────────────────────────────────────────────
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var _distance_traveled: float = 0.0
var _lifetime: float = 0.0

@onready var visual: ColorRect = $ProjectileVisual
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Connect detection signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Flip visual if going left
	if direction.x < 0.0:
		visual.scale.x = -1.0


func _physics_process(delta: float) -> void:
	var movement := direction.normalized() * SPEED * delta
	global_position += movement
	_distance_traveled += movement.length()
	_lifetime += delta

	if _distance_traveled >= MAX_RANGE or _lifetime >= MAX_LIFETIME:
		_destroy()


func _on_body_entered(body: Node2D) -> void:
	# Hit a wall/world tile
	if body.collision_layer & 1:  # Layer 1 = World
		_destroy()
		return

	# Hit an enemy
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	_destroy()


func _on_area_entered(area: Area2D) -> void:
	# Hit an enemy hurtbox area
	if area.is_in_group("enemy_hurtbox") and area.has_method("take_damage"):
		area.take_damage(damage, global_position)
		_destroy()


func get_damage() -> float:
	return damage


func _destroy() -> void:
	# Disable collision immediately to prevent double-hits
	set_deferred("monitoring", false)
	collision.set_deferred("disabled", true)

	# Quick fade out
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.05)
	tween.tween_callback(queue_free)
