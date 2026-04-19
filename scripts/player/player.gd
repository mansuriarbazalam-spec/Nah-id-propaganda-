extends CharacterBody2D

## Player character controller.
## Handles movement, jumping (with coyote time & jump buffering),
## melee/ranged combat, hurt/knockback, and death.

# ── Movement constants ──────────────────────────────────────────────
const SPEED: float = 120.0
const JUMP_VELOCITY: float = -280.0
const GRAVITY: float = 800.0
const FRICTION: float = 0.85
const AIR_FRICTION: float = 0.95
const ACCELERATION: float = 600.0
const COYOTE_TIME: float = 0.1
const JUMP_BUFFER: float = 0.1
const VARIABLE_JUMP_MULTIPLIER: float = 0.4  # gravity multiplier when jump released early

# ── Combat constants ────────────────────────────────────────────────
const MELEE_DAMAGE: float = 20.0
const RANGED_DAMAGE: float = 10.0
const MELEE_COOLDOWN: float = 0.4
const RANGED_COOLDOWN: float = 0.6
const KNOCKBACK_FORCE: float = 200.0
const HURT_INVINCIBILITY: float = 0.8  # seconds of i-frames after being hit

# ── Preloads ────────────────────────────────────────────────────────
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")

# ── Node references ─────────────────────────────────────────────────
@onready var sprite: ColorRect = $PlayerVisual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var melee_attack_area: Area2D = $MeleeAttackArea
@onready var hurt_box: Area2D = $HurtBox
@onready var clarity_shield: Area2D = $ClarityShield
@onready var ranged_spawn: Marker2D = $RangedAttackSpawn
@onready var camera: Camera2D = $Camera2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var attack_cooldown: Timer = $AttackCooldown

# ── State ───────────────────────────────────────────────────────────
var facing_direction: int = 1  # 1 = right, -1 = left
var can_coyote_jump: bool = false
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false
var is_dead: bool = false
var is_hurt: bool = false
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var was_on_floor: bool = false

# ── Combat cooldown state ───────────────────────────────────────────
var can_melee: bool = true
var can_ranged: bool = true
var melee_cooldown_timer: float = 0.0
var ranged_cooldown_timer: float = 0.0

# ── Animation state ─────────────────────────────────────────────────
var current_anim: String = ""


func _ready() -> void:
	add_to_group("player")

	# Connect coyote timer
	coyote_timer.wait_time = COYOTE_TIME
	coyote_timer.one_shot = true
	coyote_timer.timeout.connect(_on_coyote_timer_timeout)

	# Melee attack area starts disabled
	_set_melee_hitbox_active(false)

	# Connect HurtBox
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	hurt_box.body_entered.connect(_on_hurt_box_body_entered)

	# Connect to SanityManager death signal if available
	if Engine.has_singleton("SanityManager") or has_node("/root/SanityManager"):
		var sm = get_node_or_null("/root/SanityManager")
		if sm and sm.has_signal("sanity_depleted"):
			sm.sanity_depleted.connect(_on_sanity_depleted)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	_handle_gravity(delta)
	_handle_horizontal_movement(delta)
	_handle_jump()
	_handle_combat()
	_apply_knockback(delta)
	_update_facing()
	_update_animation()

	# Track floor state for coyote time
	var on_floor_before_move := is_on_floor()
	move_and_slide()
	_handle_coyote_time(on_floor_before_move)


# ── Timers ──────────────────────────────────────────────────────────
func _update_timers(delta: float) -> void:
	# Jump buffer countdown
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	# Melee cooldown
	if not can_melee:
		melee_cooldown_timer -= delta
		if melee_cooldown_timer <= 0.0:
			can_melee = true

	# Ranged cooldown
	if not can_ranged:
		ranged_cooldown_timer -= delta
		if ranged_cooldown_timer <= 0.0:
			can_ranged = true

	# Invincibility countdown
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false
			# Restore full visibility
			sprite.modulate.a = 1.0
		else:
			# Flash effect during i-frames
			sprite.modulate.a = 0.4 if fmod(invincibility_timer, 0.15) < 0.075 else 1.0


# ── Gravity ─────────────────────────────────────────────────────────
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		var grav := GRAVITY
		# Variable jump height: if the player released jump while ascending,
		# apply stronger gravity so the jump is cut short.
		if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			grav *= (1.0 / VARIABLE_JUMP_MULTIPLIER)
		velocity.y += grav * delta
	else:
		# Consume jump buffer when we land
		if jump_buffer_timer > 0.0:
			_do_jump()


# ── Horizontal Movement ────────────────────────────────────────────
func _handle_horizontal_movement(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	if is_attacking:
		# Slow down during attacks but don't stop instantly
		velocity.x *= 0.9
		return

	if input_dir != 0.0:
		# Accelerate toward desired speed
		velocity.x = move_toward(velocity.x, input_dir * SPEED, ACCELERATION * delta)
	else:
		# Apply friction
		if is_on_floor():
			velocity.x *= FRICTION
		else:
			velocity.x *= AIR_FRICTION

		# Snap to zero when very slow
		if abs(velocity.x) < 5.0:
			velocity.x = 0.0


# ── Jump ────────────────────────────────────────────────────────────
func _handle_jump() -> void:
	if is_attacking:
		return

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			_do_jump()
		elif can_coyote_jump:
			_do_jump()
			can_coyote_jump = false
		else:
			# Buffer the jump for when we land
			jump_buffer_timer = JUMP_BUFFER


func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer_timer = 0.0
	can_coyote_jump = false


func _handle_coyote_time(was_on_floor_before: bool) -> void:
	if was_on_floor_before and not is_on_floor() and velocity.y >= 0.0:
		# We just walked off an edge (not jumped) — start coyote time
		can_coyote_jump = true
		coyote_timer.start()


func _on_coyote_timer_timeout() -> void:
	can_coyote_jump = false


# ── Combat ──────────────────────────────────────────────────────────
func _handle_combat() -> void:
	if is_attacking or is_hurt:
		return

	if Input.is_action_just_pressed("attack_melee") and can_melee:
		_do_melee_attack()
	elif Input.is_action_just_pressed("attack_ranged") and can_ranged:
		_do_ranged_attack()


func _do_melee_attack() -> void:
	is_attacking = true
	can_melee = false
	melee_cooldown_timer = MELEE_COOLDOWN
	_play_animation("attack_melee")

	# Enable the melee hitbox briefly
	_set_melee_hitbox_active(true)

	# Deal damage to any overlapping enemies
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		_apply_melee_damage()

	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self):
		_set_melee_hitbox_active(false)
		is_attacking = false


func _apply_melee_damage() -> void:
	var dmg := MELEE_DAMAGE * SkillTreeManager.melee_damage_multiplier
	var bodies := melee_attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(dmg, global_position)

	var areas := melee_attack_area.get_overlapping_areas()
	for area in areas:
		if area.has_method("take_damage"):
			area.take_damage(dmg, global_position)


func _do_ranged_attack() -> void:
	is_attacking = true
	can_ranged = false
	ranged_cooldown_timer = RANGED_COOLDOWN
	_play_animation("attack_ranged")

	# Spawn projectile after a short wind-up
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		_spawn_projectile()

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		is_attacking = false


func _spawn_projectile() -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	proj.direction = Vector2(facing_direction, 0)
	proj.damage = RANGED_DAMAGE * SkillTreeManager.ranged_damage_multiplier
	proj.global_position = ranged_spawn.global_position
	get_tree().current_scene.add_child(proj)


func _set_melee_hitbox_active(active: bool) -> void:
	var melee_shape := melee_attack_area.get_node_or_null("MeleeShape")
	if melee_shape:
		melee_shape.disabled = not active
	melee_attack_area.monitoring = active


# ── Facing ──────────────────────────────────────────────────────────
func _update_facing() -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir != 0.0 and not is_attacking:
		facing_direction = 1 if input_dir > 0.0 else -1

	# Flip visuals and hitboxes
	sprite.scale.x = abs(sprite.scale.x) * facing_direction

	# Move melee area to face direction
	melee_attack_area.position.x = abs(melee_attack_area.position.x) * facing_direction
	ranged_spawn.position.x = abs(ranged_spawn.position.x) * facing_direction


# ── Damage / Hurt ───────────────────────────────────────────────────
func take_damage(amount: float, source_position: Vector2 = global_position) -> void:
	if is_dead or is_invincible:
		return

	# Check if clarity shield is absorbing damage
	if clarity_shield and clarity_shield.has_method("is_shield_active") and clarity_shield.is_shield_active():
		var reduced: float = clarity_shield.absorb_damage(amount)
		amount = reduced
		if amount <= 0.0:
			return

	# Apply sanity damage via SanityManager
	var sm = get_node_or_null("/root/SanityManager")
	if sm and sm.has_method("take_sanity_damage"):
		sm.take_sanity_damage(amount)

	# Knockback
	var kb_dir := (global_position - source_position).normalized()
	if kb_dir == Vector2.ZERO:
		kb_dir = Vector2(facing_direction, -0.5).normalized()
	knockback_velocity = kb_dir * KNOCKBACK_FORCE

	# Hurt state
	is_hurt = true
	is_attacking = false
	is_invincible = true
	invincibility_timer = HURT_INVINCIBILITY
	_play_animation("hurt")

	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		is_hurt = false


func _apply_knockback(delta: float) -> void:
	if knockback_velocity.length() > 5.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO


func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Hit by enemy projectile or hazard area
	if area.has_method("get_damage"):
		take_damage(area.get_damage(), area.global_position)
	elif area.is_in_group("enemy_attack"):
		take_damage(10.0, area.global_position)


func _on_hurt_box_body_entered(body: Node2D) -> void:
	# Contact damage from enemy bodies
	if body.is_in_group("enemies") and body.has_method("get_contact_damage"):
		take_damage(body.get_contact_damage(), body.global_position)


# ── Death ───────────────────────────────────────────────────────────
func _on_sanity_depleted() -> void:
	if is_dead:
		return
	die()


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	_play_animation("death")

	# Disable collisions
	collision_shape.set_deferred("disabled", true)
	hurt_box.set_deferred("monitoring", false)

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self):
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("game_over"):
			gm.game_over()


# ── Animation ───────────────────────────────────────────────────────
func _play_animation(anim_name: String) -> void:
	if current_anim == anim_name:
		return
	current_anim = anim_name
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _update_animation() -> void:
	if is_dead or is_hurt or is_attacking:
		return

	if not is_on_floor():
		if velocity.y < 0.0:
			_play_animation("jump")
		else:
			_play_animation("fall")
	elif abs(velocity.x) > 10.0:
		_play_animation("run")
	else:
		_play_animation("idle")
