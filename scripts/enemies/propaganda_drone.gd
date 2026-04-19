extends CharacterBody2D

## A flying propaganda drone that patrols horizontally and drops propaganda bombs
## when it detects the player. No gravity — hovers with a bobbing motion.

signal enemy_died(enemy: Node2D)

enum DroneState { PATROL, CHASE, ATTACK, HURT, DEAD }

@export var health: float = 30.0
@export var damage: float = 10.0
@export var speed: float = 80.0
@export var detection_range: float = 150.0
@export var bomb_drop_interval: float = 2.0
@export var patrol_distance: float = 100.0
@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 3.0

const BOMB_SCENE_PATH: String = "res://scenes/enemies/propaganda_bomb.tscn"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_state: DroneState = DroneState.PATROL
var facing_direction: int = 1
var player_ref: CharacterBody2D = null
var _spawn_position: Vector2 = Vector2.ZERO
var _patrol_going_right: bool = true
var _bob_time: float = 0.0
var _hurt_flash_timer: float = 0.0
var _attack_timer: float = 0.0
var _bomb_scene: PackedScene = null
var _current_anim: String = ""
var knockback_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_spawn_position = global_position
	add_to_group("enemies")
	_bomb_scene = load(BOMB_SCENE_PATH) as PackedScene
	_find_player()

	# Hook up pixel-art animations
	if is_instance_valid(animated_sprite):
		animated_sprite.sprite_frames = _build_sprite_frames()
		_play_anim("idle")


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_strip(sf, "idle", preload("res://assets/sprites/enemies/fire_skull.png"), 8, 96, 112, 10.0, true)
	return sf


func _add_strip(sf: SpriteFrames, anim: String, tex: Texture2D, count: int, fw: int, fh: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, at)


func _play_anim(anim: String) -> void:
	if not is_instance_valid(animated_sprite):
		return
	if _current_anim == anim:
		return
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim):
		return
	_current_anim = anim
	animated_sprite.play(anim)


func _physics_process(delta: float) -> void:
	if current_state == DroneState.DEAD:
		return

	_find_player()
	_bob_time += delta * bob_speed
	_update_hurt_flash(delta)
	_update_knockback(delta)

	match current_state:
		DroneState.PATROL:
			_state_patrol(delta)
		DroneState.CHASE:
			_state_chase(delta)
		DroneState.ATTACK:
			_state_attack(delta)
		DroneState.HURT:
			_state_hurt(delta)

	# Apply bobbing offset
	velocity.y = sin(_bob_time) * bob_amplitude * 10.0

	move_and_slide()


func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		modulate = Color(2.0, 0.5, 0.5) if fmod(_hurt_flash_timer, 0.1) > 0.05 else Color.WHITE
		if _hurt_flash_timer <= 0.0:
			modulate = Color.WHITE


func _update_knockback(delta: float) -> void:
	if knockback_velocity.length() > 5.0:
		velocity += knockback_velocity * delta * 5.0
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 6.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO


# ── State: PATROL ────────────────────────────────────────────────────
func _state_patrol(_delta: float) -> void:
	if _can_detect_player():
		current_state = DroneState.CHASE
		return

	# Patrol between two horizontal points
	var target_x: float
	if _patrol_going_right:
		target_x = _spawn_position.x + patrol_distance
	else:
		target_x = _spawn_position.x - patrol_distance

	var dir: float = sign(target_x - global_position.x)
	velocity.x = dir * speed * 0.5
	facing_direction = int(dir) if dir != 0 else facing_direction

	if abs(global_position.x - target_x) < 5.0:
		_patrol_going_right = not _patrol_going_right

	_update_visual_facing()


# ── State: CHASE ─────────────────────────────────────────────────────
func _state_chase(_delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.is_dead:
		current_state = DroneState.PATROL
		return

	var dist := global_position.distance_to(player_ref.global_position)

	if dist > detection_range * 1.5:
		current_state = DroneState.PATROL
		return

	# Move horizontally toward player, staying above them
	var dir: float = sign(player_ref.global_position.x - global_position.x)
	facing_direction = int(dir) if dir != 0 else facing_direction
	velocity.x = dir * speed * 0.7

	# Try to stay above the player
	var target_y := player_ref.global_position.y - 60.0
	var y_diff := target_y - global_position.y
	velocity.y += y_diff * 2.0

	_update_visual_facing()

	# Check if we're in a good position to attack
	if abs(global_position.x - player_ref.global_position.x) < 40.0 and global_position.y < player_ref.global_position.y:
		current_state = DroneState.ATTACK
		_attack_timer = 0.5  # Small delay before first bomb


# ── State: ATTACK ────────────────────────────────────────────────────
func _state_attack(delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.is_dead:
		current_state = DroneState.PATROL
		return

	# Hover above the player
	velocity.x = move_toward(velocity.x, 0.0, speed * delta)

	var dist := global_position.distance_to(player_ref.global_position)
	if dist > detection_range * 1.2:
		current_state = DroneState.CHASE
		return

	# Drop bombs on a timer
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_drop_bomb()
		_attack_timer = bomb_drop_interval


# ── State: HURT ──────────────────────────────────────────────────────
func _state_hurt(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, speed * 0.1)
	if _hurt_flash_timer <= 0.0:
		if _can_detect_player():
			current_state = DroneState.CHASE
		else:
			current_state = DroneState.PATROL


# ── Combat ───────────────────────────────────────────────────────────
func _drop_bomb() -> void:
	if _bomb_scene == null:
		return

	var bomb := _bomb_scene.instantiate()
	bomb.global_position = global_position + Vector2(0, 8)
	get_tree().current_scene.add_child(bomb)


func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	if current_state == DroneState.DEAD:
		return

	health -= amount
	_hurt_flash_timer = 0.25
	current_state = DroneState.HURT

	# Knockback
	if source_pos != Vector2.ZERO:
		var kb_dir := (global_position - source_pos).normalized()
		knockback_velocity = kb_dir * 120.0
	else:
		knockback_velocity = Vector2(-facing_direction * 100.0, -30.0)

	if health <= 0.0:
		die()


func die() -> void:
	current_state = DroneState.DEAD
	velocity = Vector2.ZERO
	enemy_died.emit(self)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_property(self, "position:y", position.y + 20.0, 0.4)
	tween.tween_callback(queue_free)


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
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as CharacterBody2D


func _update_visual_facing() -> void:
	if is_instance_valid(animated_sprite) and facing_direction != 0:
		animated_sprite.flip_h = facing_direction < 0
