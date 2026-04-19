extends LevelBase

## Level 01 — first real level after the tutorial.
## More complex layout with multiple paths, mixed enemies,
## propaganda machines, and NPCs to rescue.

const BOSS_SCENE_PATH: String = "res://scenes/enemies/boss_lieutenant.tscn"
const VICTORY_SCENE_PATH: String = "res://scenes/ui/victory_screen.tscn"

var _boss_instance: CharacterBody2D = null
var _boss_spawned: bool = false


func _ready() -> void:
	level_name = "District 01 - The Broadcast Quarter"
	next_level_path = VICTORY_SCENE_PATH
	super._ready()


func _on_level_ready() -> void:
	# Level-specific setup
	_connect_boss_arena()


func _connect_boss_arena() -> void:
	var boss_trigger := get_node_or_null("BossArena/BossTrigger")
	if boss_trigger and boss_trigger is Area2D:
		boss_trigger.body_entered.connect(_on_boss_trigger_entered)


func _on_boss_trigger_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _boss_spawned:
		return

	_boss_spawned = true

	# Lock the boss arena (prevent backtracking)
	var arena_door := get_node_or_null("BossArena/ArenaDoor")
	if arena_door and arena_door is StaticBody2D:
		arena_door.visible = true
		var col := arena_door.get_node_or_null("CollisionShape2D")
		if col and col is CollisionShape2D:
			col.disabled = false

	# Disable the trigger so it only fires once
	var boss_trigger := get_node_or_null("BossArena/BossTrigger")
	if boss_trigger and boss_trigger is Area2D:
		boss_trigger.set_deferred("monitoring", false)

	# Spawn the boss
	_spawn_boss()


func _spawn_boss() -> void:
	if not ResourceLoader.exists(BOSS_SCENE_PATH):
		push_warning("Level01: Boss scene not found at: " + BOSS_SCENE_PATH)
		return

	var boss_scene: PackedScene = load(BOSS_SCENE_PATH)
	_boss_instance = boss_scene.instantiate()

	# Place the boss at the BossSpawn marker if it exists, otherwise offset from trigger
	var boss_spawn_marker := get_node_or_null("BossArena/BossSpawn")
	if boss_spawn_marker and boss_spawn_marker is Marker2D:
		_boss_instance.global_position = boss_spawn_marker.global_position
	else:
		# Fallback: place near the boss trigger area, offset to the right
		var boss_trigger := get_node_or_null("BossArena/BossTrigger")
		if boss_trigger:
			_boss_instance.global_position = boss_trigger.global_position + Vector2(80, 0)
		else:
			_boss_instance.global_position = Vector2(400, 200)

	# Add boss to the scene
	add_child(_boss_instance)

	# Connect boss signals
	_boss_instance.boss_defeated.connect(_on_boss_defeated)
	_boss_instance.boss_health_changed.connect(_on_boss_health_changed)

	# Show boss health bar on HUD
	if is_instance_valid(hud) and hud.has_method("show_boss_bar"):
		hud.show_boss_bar(_boss_instance.boss_name, _boss_instance.max_health)

	# Show boss intro via dialogue if a DialogueBox is available
	var dialogue_box := get_node_or_null("DialogueBox")
	if dialogue_box and dialogue_box.has_method("show_dialogue"):
		dialogue_box.show_dialogue("The Propaganda Lieutenant appears!")


func _on_boss_health_changed(current: float, _max_val: float) -> void:
	if is_instance_valid(hud) and hud.has_method("update_boss_bar"):
		hud.update_boss_bar(current)


func _on_boss_defeated() -> void:
	# Hide the boss health bar
	if is_instance_valid(hud) and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()

	# Unlock the arena door so the player can leave if needed
	var arena_door := get_node_or_null("BossArena/ArenaDoor")
	if arena_door and arena_door is StaticBody2D:
		arena_door.visible = false
		var col := arena_door.get_node_or_null("CollisionShape2D")
		if col and col is CollisionShape2D:
			col.disabled = true

	# Wait a moment for the boss death animation, then transition to victory
	await get_tree().create_timer(3.0).timeout

	# Complete the level and transition to the victory screen
	GameManager.complete_level(scene_file_path)
	GameManager.change_level(VICTORY_SCENE_PATH)
