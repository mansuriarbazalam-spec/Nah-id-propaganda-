extends BossBase

## The Propaganda Lieutenant — first boss of the game.
## A larger humanoid figure who uses broadcast blasts, decree dashes,
## slogan shouts, and (in phase 2) emergency broadcasts to overwhelm
## the player with propaganda.

const PROPAGANDA_BOMB_SCENE: PackedScene = preload("res://scenes/enemies/propaganda_bomb.tscn")
const SHOCKWAVE_SCENE: PackedScene = preload("res://scenes/enemies/shockwave.tscn")

# -- Phase 1 tuning ----------------------------------------------------------
const PHASE1_ATTACK_PAUSE: float = 2.0
const PHASE1_DASH_SPEED: float = 250.0
const PHASE1_BOMB_SPEED: float = 160.0

# -- Phase 2 tuning ----------------------------------------------------------
const PHASE2_ATTACK_PAUSE: float = 1.2
const PHASE2_DASH_SPEED: float = 350.0
const PHASE2_BOMB_SPEED: float = 200.0
const PHASE2_MOVE_SPEED_MULT: float = 1.4

# -- Node references ----------------------------------------------------------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var dialogue_label: Label = $DialogueLabel
@onready var animation_player_node: AnimationPlayer = $AnimationPlayer
@onready var contact_damage_area: Area2D = $ContactDamageArea
@onready var hurt_box: Area2D = $HurtBox

var _intro_done: bool = false
var _is_dashing: bool = false
var _dash_target: Vector2 = Vector2.ZERO
var _performing_attack: bool = false
var _available_attacks: Array = []
var _arena_center: Vector2 = Vector2.ZERO
var _current_anim: String = ""


func _ready() -> void:
	super._ready()
	boss_name = "The Propaganda Lieutenant"
	max_health = 300.0
	current_health = max_health
	contact_damage = 15.0
	move_speed = 60.0

	attack_timer.wait_time = PHASE1_ATTACK_PAUSE
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Connect contact damage area
	contact_damage_area.body_entered.connect(_on_contact_body_entered)

	# Connect hurt box so player can hit us
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)

	# Dialogue hidden initially
	dialogue_label.text = ""
	dialogue_label.visible = false

	_arena_center = global_position

	# Hook up pixel-art animations
	if is_instance_valid(animated_sprite):
		animated_sprite.sprite_frames = _build_sprite_frames()
		_play_anim("idle")

	# Start the fight
	start_fight()


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_strip(sf, "idle", preload("res://assets/sprites/enemies/nightmare_idle.png"), 4, 128, 96, 6.0, true)
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


func _boss_process(delta: float) -> void:
	match current_state:
		BossState.INTRO:
			_process_intro(delta)
		BossState.IDLE:
			_process_idle(delta)
		BossState.ATTACK_1:
			pass  # Handled by async
		BossState.ATTACK_2:
			_process_dash(delta)
		BossState.ATTACK_3:
			pass  # Handled by async
		BossState.SPECIAL:
			pass  # Handled by async
		BossState.PHASE_TRANSITION:
			pass  # Handled by async
		BossState.DEFEATED:
			velocity.x = 0.0


# -- Fight start / Intro -----------------------------------------------------

func _on_fight_start() -> void:
	current_state = BossState.INTRO
	_intro_done = false
	_arena_center = global_position


func _process_intro(_delta: float) -> void:
	if _intro_done:
		return

	_intro_done = true
	_perform_intro()


func _perform_intro() -> void:
	# Walk to center of arena (or stay in place if already there)
	velocity.x = 0.0

	# Show taunt
	_show_dialogue("YOUR COMPLIANCE IS MANDATORY!")
	await get_tree().create_timer(2.0).timeout

	if not is_instance_valid(self):
		return

	_hide_dialogue()
	current_state = BossState.IDLE
	attack_timer.start()


# -- Idle / Attack selection --------------------------------------------------

func _process_idle(_delta: float) -> void:
	if _performing_attack:
		return

	# Slowly move toward player
	if is_instance_valid(player_ref) and not player_ref.is_dead:
		var dir: float = sign(player_ref.global_position.x - global_position.x)
		var spd := move_speed
		if current_phase >= 2:
			spd *= PHASE2_MOVE_SPEED_MULT
		velocity.x = dir * spd * 0.4
	else:
		velocity.x = 0.0


func _on_attack_timer_timeout() -> void:
	if is_defeated or current_state == BossState.DEFEATED:
		return
	if current_state == BossState.PHASE_TRANSITION:
		return

	_select_and_perform_attack()


func _select_and_perform_attack() -> void:
	if _performing_attack:
		return

	# Build available attacks
	_available_attacks = [BossState.ATTACK_1, BossState.ATTACK_2, BossState.ATTACK_3]
	if current_phase >= 2:
		_available_attacks.append(BossState.SPECIAL)

	var chosen: BossState = _available_attacks[randi() % _available_attacks.size()]
	_performing_attack = true

	match chosen:
		BossState.ATTACK_1:
			_attack_broadcast_blast()
		BossState.ATTACK_2:
			_attack_decree_dash()
		BossState.ATTACK_3:
			_attack_slogan_shout()
		BossState.SPECIAL:
			_attack_emergency_broadcast()


func _finish_attack() -> void:
	_performing_attack = false
	_is_dashing = false
	if is_defeated or current_state == BossState.DEFEATED:
		return
	current_state = BossState.IDLE

	var pause_time := PHASE1_ATTACK_PAUSE if current_phase == 1 else PHASE2_ATTACK_PAUSE
	attack_timer.wait_time = pause_time
	attack_timer.start()


# -- ATTACK 1: Broadcast Blast -----------------------------------------------
# Charges up, fires 3 propaganda bombs in a spread pattern

func _attack_broadcast_blast() -> void:
	current_state = BossState.ATTACK_1
	velocity.x = 0.0

	# Charge-up visual: flash briefly
	modulate = Color(1.5, 1.0, 0.5)
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or is_defeated:
		return
	modulate = Color.WHITE

	if not is_instance_valid(player_ref):
		_finish_attack()
		return

	# Fire 3 bombs in a spread pattern
	var base_dir := (player_ref.global_position - global_position).normalized()
	var bomb_speed := PHASE1_BOMB_SPEED if current_phase == 1 else PHASE2_BOMB_SPEED
	var spread_angles := [-0.3, 0.0, 0.3]  # radians

	for angle_offset in spread_angles:
		var dir := base_dir.rotated(angle_offset)
		_spawn_bomb(dir * bomb_speed)

	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self) and not is_defeated:
		_finish_attack()


func _spawn_bomb(initial_vel: Vector2) -> void:
	var bomb := PROPAGANDA_BOMB_SCENE.instantiate()
	bomb.initial_velocity = initial_vel
	bomb.global_position = global_position + Vector2(0, -12)
	get_tree().current_scene.add_child(bomb)


# -- ATTACK 2: Decree Dash ---------------------------------------------------
# Rushes toward the player at high speed

func _attack_decree_dash() -> void:
	current_state = BossState.ATTACK_2
	velocity.x = 0.0

	# Brief telegraph
	modulate = Color(1.0, 0.6, 0.6)
	_show_dialogue("OBEY!")
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or is_defeated:
		return
	_hide_dialogue()
	modulate = Color.WHITE

	if not is_instance_valid(player_ref):
		_finish_attack()
		return

	# Start dash
	_is_dashing = true
	_dash_target = player_ref.global_position

	var dash_speed := PHASE1_DASH_SPEED if current_phase == 1 else PHASE2_DASH_SPEED
	var dir: float = sign(_dash_target.x - global_position.x)
	velocity.x = dir * dash_speed

	# Dash for a fixed duration or until hitting a wall
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self) and not is_defeated:
		_is_dashing = false
		velocity.x = 0.0
		_finish_attack()


func _process_dash(_delta: float) -> void:
	if not _is_dashing:
		return

	# Stop if we hit a wall
	if is_on_wall():
		_is_dashing = false
		velocity.x = 0.0


# -- ATTACK 3: Slogan Shout --------------------------------------------------
# Creates a shockwave that travels along the ground

func _attack_slogan_shout() -> void:
	current_state = BossState.ATTACK_3
	velocity.x = 0.0

	# Telegraph
	_show_dialogue("LISTEN AND COMPLY!")
	modulate = Color(0.8, 1.2, 0.8)
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or is_defeated:
		return
	_hide_dialogue()
	modulate = Color.WHITE

	# Spawn shockwave going toward player
	var dir: float = float(facing_direction)
	var shockwave := SHOCKWAVE_SCENE.instantiate()
	shockwave.direction = dir
	shockwave.global_position = global_position + Vector2(dir * 16.0, 6.0)
	get_tree().current_scene.add_child(shockwave)

	# Phase 2: fire a second one in the opposite direction
	if current_phase >= 2:
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(self) or is_defeated:
			return
		var shockwave2 := SHOCKWAVE_SCENE.instantiate()
		shockwave2.direction = -dir
		shockwave2.global_position = global_position + Vector2(-dir * 16.0, 6.0)
		get_tree().current_scene.add_child(shockwave2)

	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self) and not is_defeated:
		_finish_attack()


# -- SPECIAL: Emergency Broadcast (Phase 2 only) -----------------------------
# Screen flashes, propaganda bombs rain from above

func _attack_emergency_broadcast() -> void:
	current_state = BossState.SPECIAL
	velocity.x = 0.0

	# Screen flash warning
	_show_dialogue("EMERGENCY BROADCAST!")
	modulate = Color(2.0, 0.3, 0.3)
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or is_defeated:
		return
	modulate = Color.WHITE

	_hide_dialogue()

	# Rain bombs from above
	var bomb_count := randi_range(5, 7)
	for i in range(bomb_count):
		if not is_instance_valid(self) or is_defeated:
			return

		# Random X position in a wide area around the player
		var offset_x := randf_range(-120.0, 120.0)
		var spawn_pos := Vector2.ZERO
		if is_instance_valid(player_ref):
			spawn_pos = player_ref.global_position + Vector2(offset_x, -140.0)
		else:
			spawn_pos = global_position + Vector2(offset_x, -140.0)

		var bomb := PROPAGANDA_BOMB_SCENE.instantiate()
		bomb.initial_velocity = Vector2(randf_range(-20.0, 20.0), 40.0)
		bomb.global_position = spawn_pos
		get_tree().current_scene.add_child(bomb)

		await get_tree().create_timer(0.15).timeout

	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self) and not is_defeated:
		_finish_attack()


# -- Phase transition ---------------------------------------------------------

func _on_phase_transition(new_phase: int) -> void:
	_performing_attack = false
	attack_timer.stop()
	velocity.x = 0.0

	# Visual change: turn redder
	_show_dialogue("YOU THINK YOU CAN SILENCE THE TRUTH?!")
	modulate = Color(1.6, 0.4, 0.4)

	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return

	_hide_dialogue()

	# Apply visual tint for phase 2
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color(1.6, 0.6, 0.6, 1.0)

	current_phase = new_phase
	_invincible = false
	boss_phase_changed.emit(current_phase)
	modulate = Color.WHITE
	current_state = BossState.IDLE

	# Resume attacking with shorter cooldowns
	attack_timer.wait_time = PHASE2_ATTACK_PAUSE
	attack_timer.start()


# -- Defeat -------------------------------------------------------------------

func _on_defeated() -> void:
	_performing_attack = false
	attack_timer.stop()
	velocity.x = 0.0

	# Dramatic death
	_show_dialogue("THE SUPREME LEADER...\nWILL HEAR OF THIS...")

	# Screen flash
	modulate = Color(3.0, 3.0, 3.0)
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self):
		return
	modulate = Color.WHITE

	# Drop skill point
	SkillTreeManager.add_skill_points(1)

	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(self):
		return

	_hide_dialogue()

	# Fade out and remove
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)


# -- Contact damage -----------------------------------------------------------

func _on_contact_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)


# -- Hurt box (player projectiles / attacks) ----------------------------------

func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Hit by player projectile or melee area
	if area.get_parent() and area.get_parent().is_in_group("player"):
		# Melee attack area
		var player := area.get_parent()
		var dmg: float = 20.0
		if player.has_method("get") and "MELEE_DAMAGE" in player:
			dmg = player.MELEE_DAMAGE
		# Apply skill tree multiplier
		dmg *= SkillTreeManager.melee_damage_multiplier
		take_damage(dmg, player.global_position)
	elif area.has_method("get_damage"):
		# Player projectile
		var dmg: float = area.get_damage()
		dmg *= SkillTreeManager.ranged_damage_multiplier
		take_damage(dmg, area.global_position)
		if area.has_method("queue_free"):
			area.queue_free()


# -- Dialogue helpers ---------------------------------------------------------

func _show_dialogue(text: String) -> void:
	dialogue_label.text = text
	dialogue_label.visible = true


func _hide_dialogue() -> void:
	dialogue_label.text = ""
	dialogue_label.visible = false


# -- Facing override ---------------------------------------------------------
# Use flip_h on the AnimatedSprite2D instead of scaling the root
# (scaling the root would also flip collision shapes and area colliders).
func _update_visual_facing() -> void:
	if is_instance_valid(animated_sprite) and facing_direction != 0:
		animated_sprite.flip_h = facing_direction < 0
