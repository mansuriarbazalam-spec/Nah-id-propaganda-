extends Node2D
class_name LevelBase

## Base script for all levels.
## Handles player spawning, camera limits, level exit, and HUD setup.

@export var level_name: String = "Level"
@export var next_level_path: String = ""
@export var player_scene_path: String = "res://scenes/player/player.tscn"
@export var hud_scene_path: String = "res://scenes/ui/hud.tscn"
@export var parallax_scene_path: String = "res://scenes/levels/parallax_city.tscn"
@export var post_process_scene_path: String = "res://scenes/effects/post_process.tscn"
@export var ambient_music_path: String = "res://assets/audio/music/dark_ambient_loop.ogg"

var player: CharacterBody2D = null
var hud: CanvasLayer = null

var _player_scene: PackedScene = null
var _hud_scene: PackedScene = null
var _parallax_scene: PackedScene = null


func _ready() -> void:
	# Load scenes
	if ResourceLoader.exists(player_scene_path):
		_player_scene = load(player_scene_path)
	if ResourceLoader.exists(hud_scene_path):
		_hud_scene = load(hud_scene_path)
	if ResourceLoader.exists(parallax_scene_path):
		_parallax_scene = load(parallax_scene_path)

	_setup_parallax()
	_spawn_player()
	_setup_hud()
	_setup_camera_limits()
	_setup_post_process()
	_setup_ambience()
	_connect_level_exit()
	_on_level_ready()


# ── Post-processing (vignette / grain / color grading) ──────────────
func _setup_post_process() -> void:
	if not ResourceLoader.exists(post_process_scene_path):
		return
	var pp_scene: PackedScene = load(post_process_scene_path)
	var pp := pp_scene.instantiate()
	add_child(pp)


# ── Ambient music ───────────────────────────────────────────────────
func _setup_ambience() -> void:
	if ambient_music_path == "":
		return
	if not ResourceLoader.exists(ambient_music_path):
		return
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ambient"):
		am.play_ambient(ambient_music_path, 2.5)


## Override in subclasses for level-specific setup.
func _on_level_ready() -> void:
	pass


# ── Parallax Background ─────────────────────────────────────────────
func _setup_parallax() -> void:
	if _parallax_scene == null:
		return

	var parallax_instance := _parallax_scene.instantiate()
	# Add at index 0 so it renders behind everything else
	add_child(parallax_instance)
	move_child(parallax_instance, 0)


# ── Player Spawning ──────────────────────────────────────────────────
func _spawn_player() -> void:
	if _player_scene == null:
		push_warning("LevelBase: Player scene not found at: " + player_scene_path)
		return

	player = _player_scene.instantiate() as CharacterBody2D

	# Find spawn position
	var spawn_marker := get_node_or_null("PlayerSpawn")
	if spawn_marker and spawn_marker is Marker2D:
		player.global_position = spawn_marker.global_position
	else:
		player.global_position = Vector2(50, 200)

	add_child(player)

	# Reset sanity to full at the start of each level
	SanityManager.reset_sanity()


# ── HUD ──────────────────────────────────────────────────────────────
func _setup_hud() -> void:
	if _hud_scene == null:
		return

	hud = _hud_scene.instantiate() as CanvasLayer
	add_child(hud)


# ── Camera Limits ────────────────────────────────────────────────────
func _setup_camera_limits() -> void:
	if not is_instance_valid(player):
		return

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	# Look for camera limit markers
	var limit_min := get_node_or_null("CameraLimitMin") as Marker2D
	var limit_max := get_node_or_null("CameraLimitMax") as Marker2D

	if limit_min:
		camera.limit_left = int(limit_min.global_position.x)
		camera.limit_top = int(limit_min.global_position.y)

	if limit_max:
		camera.limit_right = int(limit_max.global_position.x)
		camera.limit_bottom = int(limit_max.global_position.y)


# ── Level Exit ───────────────────────────────────────────────────────
func _connect_level_exit() -> void:
	var exit := get_node_or_null("LevelExit")
	if exit and exit is Area2D:
		exit.body_entered.connect(_on_level_exit_body_entered)


func _on_level_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_complete_level()


func _complete_level() -> void:
	GameManager.complete_level(scene_file_path)

	if next_level_path != "":
		GameManager.change_level(next_level_path)
	else:
		# No next level — return to menu or show completion
		GameManager.return_to_menu()
