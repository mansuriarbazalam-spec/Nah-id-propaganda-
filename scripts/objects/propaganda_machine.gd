extends StaticBody2D

## Destructible propaganda machine that emits ambient sanity drain.
## While active, slowly drains the sanity of any nearby player.
## Can be destroyed by player attacks.

@export var machine_health: float = 40.0
@export var drain_rate: float = 2.0  # sanity per second while in range

var _is_destroyed: bool = false
var _player_in_range: bool = false
var _hurt_flash_timer: float = 0.0


func _ready() -> void:
	var drain_zone := get_node_or_null("DrainZone")
	if drain_zone and drain_zone is Area2D:
		drain_zone.body_entered.connect(_on_drain_zone_body_entered)
		drain_zone.body_exited.connect(_on_drain_zone_body_exited)


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

	# Update hurt flash
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		modulate = Color(2.0, 0.5, 0.5) if fmod(_hurt_flash_timer, 0.1) > 0.05 else Color.WHITE
		if _hurt_flash_timer <= 0.0:
			modulate = Color.WHITE

	# Drain sanity when player is nearby
	if _player_in_range:
		SanityManager.take_sanity_damage(drain_rate * delta)

	# Visual pulse effect to show it's active
	var screen_visual := get_node_or_null("ScreenVisual")
	if screen_visual and screen_visual is ColorRect:
		var pulse := (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		screen_visual.color = Color(0.8, 0.1, 0.1).lerp(Color(0.5, 0.0, 0.3), pulse)


func _on_drain_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_drain_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func take_damage(amount: float, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if _is_destroyed:
		return

	machine_health -= amount
	_hurt_flash_timer = 0.2

	if machine_health <= 0.0:
		_destroy()


func _destroy() -> void:
	_is_destroyed = true
	_player_in_range = false

	# Give player a small sanity reward for destroying it
	SanityManager.heal_sanity(10.0)

	# Visual destruction: collapse and fade
	var body_visual := get_node_or_null("BodyVisual")
	var screen_visual := get_node_or_null("ScreenVisual")

	var tween := create_tween()
	if body_visual:
		tween.parallel().tween_property(body_visual, "modulate:a", 0.0, 0.5)
	if screen_visual:
		tween.parallel().tween_property(screen_visual, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(self, "scale:y", 0.3, 0.5)
	tween.tween_callback(_finalize_destruction)


func _finalize_destruction() -> void:
	# Disable the drain zone
	var drain_zone := get_node_or_null("DrainZone")
	if drain_zone and drain_zone is Area2D:
		drain_zone.monitoring = false

	# Disable collision so player can walk through
	var col := get_node_or_null("CollisionShape2D")
	if col and col is CollisionShape2D:
		col.set_deferred("disabled", true)
