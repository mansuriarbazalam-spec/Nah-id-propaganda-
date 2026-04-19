extends EnemyBase

## Ground patrol enemy — a propaganda soldier that walks back and forth,
## charges the player on detection, performs melee attacks, and occasionally
## throws propaganda bombs.

@export var melee_damage: float = 10.0
@export var charge_speed_multiplier: float = 1.5
@export var bomb_throw_chance: float = 0.25
@export var bomb_throw_cooldown: float = 4.0

const BOMB_SCENE_PATH: String = "res://scenes/enemies/propaganda_bomb.tscn"

var _bomb_scene: PackedScene = null
var _bomb_throw_timer: float = 0.0


func _ready() -> void:
	super._ready()
	health = 50.0
	damage = melee_damage
	speed = 50.0
	_bomb_scene = load(BOMB_SCENE_PATH) as PackedScene
	_bomb_throw_timer = bomb_throw_cooldown


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
