extends CharacterBody2D
class_name BossBase

## Base class for all bosses in the game.
## Bosses have phases, unique attack patterns, and health bars.
## They do NOT extend EnemyBase because boss behavior is fundamentally different.

signal boss_health_changed(current: float, max_val: float)
signal boss_defeated
signal boss_phase_changed(phase: int)

enum BossState {
	INTRO,
	IDLE,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	SPECIAL,
	HURT,
	PHASE_TRANSITION,
	DEFEATED,
}

@export var boss_name: String = "Boss"
@export var max_health: float = 300.0
@export var contact_damage: float = 15.0
@export var gravity: float = 800.0
@export var move_speed: float = 80.0
@export var knockback_strength: float = 80.0

var current_health: float = 0.0
var is_defeated: bool = false
var current_phase: int = 1
var current_state: BossState = BossState.INTRO
var player_ref: CharacterBody2D = null
var facing_direction: int = -1
var knockback_velocity: Vector2 = Vector2.ZERO
var _hurt_flash_timer: float = 0.0
var _invincible: bool = false


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("bosses")
	_find_player()


func _physics_process(delta: float) -> void:
	if current_state == BossState.DEFEATED:
		return

	_find_player()
	_apply_gravity(delta)
	_update_knockback(delta)
	_update_hurt_flash(delta)
	_face_player()
	_boss_process(delta)
	move_and_slide()


## Override in subclasses for boss-specific per-frame logic.
func _boss_process(_delta: float) -> void:
	pass


# -- Gravity -----------------------------------------------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


# -- Knockback ---------------------------------------------------------------
func _update_knockback(delta: float) -> void:
	if knockback_velocity.length() > 5.0:
		velocity.x += knockback_velocity.x
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO


# -- Hurt flash --------------------------------------------------------------
func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		modulate = Color(2.0, 0.5, 0.5) if fmod(_hurt_flash_timer, 0.12) > 0.06 else Color.WHITE
		if _hurt_flash_timer <= 0.0:
			modulate = Color.WHITE


# -- Facing ------------------------------------------------------------------
func _face_player() -> void:
	if not is_instance_valid(player_ref):
		return
	if current_state in [BossState.HURT, BossState.DEFEATED, BossState.PHASE_TRANSITION]:
		return
	var dir: float = sign(player_ref.global_position.x - global_position.x)
	if dir != 0:
		facing_direction = int(dir)
	_update_visual_facing()


func _update_visual_facing() -> void:
	if facing_direction != 0:
		var sx := absf(scale.x) * facing_direction
		scale.x = sx


# -- Combat ------------------------------------------------------------------

## Called when the boss takes damage. source_pos is the position of the attacker.
func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_defeated or _invincible:
		return

	current_health -= amount
	current_health = maxf(current_health, 0.0)
	_hurt_flash_timer = 0.3
	boss_health_changed.emit(current_health, max_health)

	# Knockback away from source
	if source_pos != Vector2.ZERO:
		var kb_dir := (global_position - source_pos).normalized()
		knockback_velocity = kb_dir * knockback_strength
	else:
		knockback_velocity = Vector2(-facing_direction * knockback_strength, -30.0)

	if current_health <= 0.0:
		die()
	elif current_phase == 1 and get_health_ratio() <= 0.5:
		_start_phase_transition(2)


## Kill this boss.
func die() -> void:
	if is_defeated:
		return
	is_defeated = true
	current_state = BossState.DEFEATED
	velocity = Vector2.ZERO
	_invincible = true
	_on_defeated()
	boss_defeated.emit()


## Override for custom defeat behavior.
func _on_defeated() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)


## Returns contact damage value.
func get_contact_damage() -> float:
	return contact_damage


## Returns health as a 0-1 ratio.
func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


## Start the boss fight (called externally or from _ready).
func start_fight() -> void:
	current_state = BossState.INTRO
	_on_fight_start()


## Override for custom intro behavior.
func _on_fight_start() -> void:
	pass


## Begin phase transition. Override _on_phase_transition for custom behavior.
func _start_phase_transition(new_phase: int) -> void:
	current_state = BossState.PHASE_TRANSITION
	_invincible = true
	velocity = Vector2.ZERO
	_on_phase_transition(new_phase)


## Override for custom phase transition behavior.
func _on_phase_transition(new_phase: int) -> void:
	current_phase = new_phase
	_invincible = false
	boss_phase_changed.emit(current_phase)
	current_state = BossState.IDLE


# -- Player detection --------------------------------------------------------
func _find_player() -> void:
	if is_instance_valid(player_ref):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as CharacterBody2D
