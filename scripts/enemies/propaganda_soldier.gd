extends EnemyBase

## Ground patrol enemy — a propaganda soldier that walks back and forth,
## charges the player on detection, performs melee attacks, and occasionally
## throws propaganda bombs.

@export var melee_damage: float = 10.0
@export var charge_speed_multiplier: float = 1.5
@export var bomb_throw_chance: float = 0.25
@export var bomb_throw_cooldown: float = 4.0

const BOMB_SCENE_PATH: String = "res://scenes/enemies/propaganda_bomb.tscn"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _bomb_scene: PackedScene = null
var _bomb_throw_timer: float = 0.0
var _current_anim: String = ""


func _ready() -> void:
	super._ready()
	health = 50.0
	damage = melee_damage
	speed = 50.0
	_bomb_scene = load(BOMB_SCENE_PATH) as PackedScene
	_bomb_throw_timer = bomb_throw_cooldown

	# Hook up pixel-art animations
	if is_instance_valid(animated_sprite):
		animated_sprite.sprite_frames = _build_sprite_frames()
		_play_anim("idle")


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_strip(sf, "idle", preload("res://assets/sprites/enemies/demon_idle.png"), 6, 160, 144, 6.0, true)
	_add_strip(sf, "attack", preload("res://assets/sprites/enemies/demon_attack.png"), 14, 188, 192, 14.0, false)
	# Reuse idle for hurt/patrol/chase (no dedicated frames)
	_add_strip(sf, "hurt", preload("res://assets/sprites/enemies/demon_idle.png"), 6, 160, 144, 6.0, true)
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


func _update_visual_facing() -> void:
	if is_instance_valid(animated_sprite) and facing_direction != 0:
		animated_sprite.flip_h = facing_direction < 0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if current_state == State.DEAD:
		return

	# Bomb throw timer
	_bomb_throw_timer -= delta

	# Occasionally throw a bomb while chasing
	if current_state == State.CHASE and _bomb_throw_timer <= 0.0:
		if randf() < bomb_throw_chance:
			_throw_bomb()
			_bomb_throw_timer = bomb_throw_cooldown

	# Drive animation state
	if current_state == State.ATTACK:
		_play_anim("attack")
	else:
		_play_anim("idle")


## Override the chase state to use charge speed.
func _state_chase(_delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.is_dead:
		_enter_patrol()
		return

	var dist := global_position.distance_to(player_ref.global_position)

	if dist > detection_range * 1.5:
		_enter_patrol()
		return

	if dist < 30.0 and _attack_cooldown <= 0.0:
		_enter_attack()
		return

	# Charge toward player at faster speed
	var dir: float = sign(player_ref.global_position.x - global_position.x)
	facing_direction = int(dir) if dir != 0 else facing_direction
	velocity.x = dir * speed * charge_speed_multiplier

	_update_visual_facing()


## Override attack to use melee damage.
func perform_attack() -> void:
	_attack_cooldown = 1.2
	velocity.x = 0.0

	# Small lunge toward player
	velocity.x = facing_direction * speed * 0.5

	# Deal damage after a windup
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	# Check if player is still in melee range
	if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) < 40.0:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(melee_damage, global_position)

	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self) and current_state == State.ATTACK:
		_enter_chase()


func _throw_bomb() -> void:
	if _bomb_scene == null or not is_instance_valid(player_ref):
		return

	var bomb := _bomb_scene.instantiate()
	bomb.global_position = global_position + Vector2(facing_direction * 8, -10)

	# Give the bomb an arc velocity toward the player
	var dir_to_player := (player_ref.global_position - global_position).normalized()
	bomb.initial_velocity = Vector2(dir_to_player.x * 120.0, -150.0)

	get_tree().current_scene.add_child(bomb)
	_bomb_throw_timer = bomb_throw_cooldown
