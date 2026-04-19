extends CharacterBody2D
class_name EnemyBase

## Base class for all enemies in the game.
## Provides health, damage, patrol/chase AI, knockback, and death logic.

signal enemy_died(enemy: EnemyBase)

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

@export var health: float = 50.0
@export var damage: float = 10.0
@export var speed: float = 60.0
@export var detection_range: float = 150.0
@export var gravity: float = 800.0
@export var knockback_strength: float = 150.0

@export var patrol_point_a: Vector2 = Vector2(-80, 0)
@export var patrol_point_b: Vector2 = Vector2(80, 0)

var current_state: State = State.IDLE
var facing_direction: int = 1
var knockback_velocity: Vector2 = Vector2.ZERO
var player_ref: CharacterBody2D = null
var _spawn_position: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_going_to_b: bool = true
var _hurt_flash_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _idle_timer: float = 0.0
var _idle_wait_time: float = 1.5


func _ready() -> void:
	_spawn_position = global_position
	_patrol_target = _spawn_position + patrol_point_b
	add_to_group("enemies")
	_find_player()


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	_find_player()
	_apply_gravity(delta)
	_update_knockback(delta)
	_update_hurt_flash(delta)
	_update_attack_cooldown(delta)

	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_state_hurt(delta)

	move_and_slide()


# ── Gravity ──────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


# ── Knockback ────────────────────────────────────────────────────────
func _update_knockback(delta: float) -> void:
	if knockback_velocity.length() > 5.0:
		velocity.x += knockback_velocity.x
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO


func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		# Flash white-red
		modulate = Color(2.0, 0.5, 0.5) if fmod(_hurt_flash_timer, 0.12) > 0.06 else Color.WHITE
		if _hurt_flash_timer <= 0.0:
			modulate = Color.WHITE


func _update_attack_cooldown(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta


# ── State: IDLE ──────────────────────────────────────────────────────
func _state_idle(delta: float) -> void:
	velocity.x = 0.0
	_idle_timer -= delta

	if _can_detect_player():
		_enter_chase()
		return

	if _idle_timer <= 0.0:
		_enter_patrol()


# ── State: PATROL ────────────────────────────────────────────────────
func _state_patrol(_delta: float) -> void:
	if _can_detect_player():
		_enter_chase()
		return

	var dir_to_target: float = sign(_patrol_target.x - global_position.x)
	if dir_to_target == 0:
		dir_to_target = 1

	facing_direction = int(dir_to_target)
	velocity.x = dir_to_target * speed * 0.5

	_update_visual_facing()

	# Check if we reached the patrol target
	if abs(global_position.x - _patrol_target.x) < 8.0:
		_patrol_going_to_b = not _patrol_going_to_b
		if _patrol_going_to_b:
			_patrol_target = _spawn_position + patrol_point_b
		else:
			_patrol_target = _spawn_position + patrol_point_a
		_enter_idle()

	# Turn around at walls
	if is_on_wall():
		_patrol_going_to_b = not _patrol_going_to_b
		if _patrol_going_to_b:
			_patrol_target = _spawn_position + patrol_point_b
		else:
			_patrol_target = _spawn_position + patrol_point_a
		_enter_idle()


# ── State: CHASE ─────────────────────────────────────────────────────
func _state_chase(_delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.is_dead:
		_enter_patrol()
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Lost the player
	if dist > detection_range * 1.5:
		_enter_patrol()
		return

	# Close enough to attack
	if dist < 30.0 and _attack_cooldown <= 0.0:
		_enter_attack()
		return

	# Move toward player
	var dir: float = sign(player_ref.global_position.x - global_position.x)
	facing_direction = int(dir) if dir != 0 else facing_direction
	velocity.x = dir * speed

	_update_visual_facing()


# ── State: ATTACK ────────────────────────────────────────────────────
func _state_attack(_delta: float) -> void:
	velocity.x = 0.0
	# Attack logic is handled by perform_attack which transitions back


# ── State: HURT ──────────────────────────────────────────────────────
func _state_hurt(_delta: float) -> void:
	# Hurt state lasts as long as the flash
	if _hurt_flash_timer <= 0.0:
		if _can_detect_player():
			_enter_chase()
		else:
			_enter_patrol()


# ── State transitions ────────────────────────────────────────────────
func _enter_idle() -> void:
	current_state = State.IDLE
	_idle_timer = _idle_wait_time
	velocity.x = 0.0


func _enter_patrol() -> void:
	current_state = State.PATROL


func _enter_chase() -> void:
	current_state = State.CHASE


func _enter_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0
	perform_attack()


func _enter_hurt() -> void:
	current_state = State.HURT


# ── Combat ───────────────────────────────────────────────────────────
## Override this in subclasses for custom attack behavior.
func perform_attack() -> void:
	_attack_cooldown = 1.0
	# Deal damage to player if in range
	if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) < 35.0:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(damage, global_position)

	# Return to chase after a short delay
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self) and current_state == State.ATTACK:
		_enter_chase()


## Called when this enemy takes damage. source_pos is the position of the attacker.
func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return

	health -= amount
	_hurt_flash_timer = 0.3
	_enter_hurt()

	# Knockback away from source
	if source_pos != Vector2.ZERO:
		var kb_dir := (global_position - source_pos).normalized()
		knockback_velocity = kb_dir * knockback_strength
	else:
		knockback_velocity = Vector2(-facing_direction * knockback_strength, -50.0)

	if health <= 0.0:
		die()


## Kill this enemy.
func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	enemy_died.emit(self)

	# Death visual: fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## Returns contact damage value (used by player's hurt box detection).
func get_contact_damage() -> float:
	return damage


# ── Detection ────────────────────────────────────────────────────────
func _can_detect_player() -> bool:
	if not is_instance_valid(player_ref):
		return false
	if player_ref.is_dead:
		return false
	return global_position.distance_to(player_ref.global_position) <= detection_range


func _find_player() -> void:
	if is_instance_valid(player_ref):
		return
	# Search for the player node
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as CharacterBody2D


func _update_visual_facing() -> void:
	# Flip the entire node's scale for visual facing
	if facing_direction != 0:
		var sx := absf(scale.x) * facing_direction
		scale.x = sx
