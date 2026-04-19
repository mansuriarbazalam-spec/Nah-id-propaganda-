extends Node

## Central audio manager handling music, SFX, UI sounds, and ambient audio.
## Add as autoload: AudioManager
##
## Uses AudioServer buses: Master, Music, SFX, UI, Ambient
## Creates buses at runtime if they don't exist.
## SFX pool of 8 players supports overlapping sound effects.
## Gracefully handles missing audio resources.

var music_player: AudioStreamPlayer = null
var ambient_player: AudioStreamPlayer = null
var sfx_pool: Array[AudioStreamPlayer] = []
var ui_sfx_player: AudioStreamPlayer = null

const SFX_POOL_SIZE: int = 8

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
var ambient_volume: float = 0.7

# Bus indices — cached after setup
var _music_bus_idx: int = -1
var _sfx_bus_idx: int = -1
var _ui_bus_idx: int = -1
var _ambient_bus_idx: int = -1

# Currently playing music path for avoiding duplicate play calls
var _current_music_path: String = ""

# Fade tween references
var _music_fade_tween: Tween = null


func _ready() -> void:
	_setup_audio_buses()
	_create_players()
	_apply_all_volumes()


# --- Audio Bus Setup ---

func _setup_audio_buses() -> void:
	# Ensure required buses exist. Master (index 0) always exists.
	_music_bus_idx = _ensure_bus_exists("Music")
	_sfx_bus_idx = _ensure_bus_exists("SFX")
	_ui_bus_idx = _ensure_bus_exists("UI")
	_ambient_bus_idx = _ensure_bus_exists("Ambient")


func _ensure_bus_exists(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		# Create the bus and route it to Master
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


# --- Player Creation ---

func _create_players() -> void:
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)

	# UI SFX player
	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.name = "UISFXPlayer"
	ui_sfx_player.bus = "UI"
	add_child(ui_sfx_player)

	# SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		add_child(player)
		sfx_pool.append(player)


# --- Music ---

func play_music(stream_path: String, fade_in: float = 1.0) -> void:
	if stream_path == _current_music_path and music_player.playing:
		return  # Already playing this track

	if not ResourceLoader.exists(stream_path):
		push_warning("AudioManager: Music file not found: %s" % stream_path)
		return

	var stream := load(stream_path) as AudioStream
	if not stream:
		push_warning("AudioManager: Failed to load music: %s" % stream_path)
		return

	_current_music_path = stream_path

	# If music is already playing, crossfade
	if music_player.playing:
		if _music_fade_tween and _music_fade_tween.is_valid():
			_music_fade_tween.kill()

		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(music_player, "volume_db", -80.0, 0.3)
		_music_fade_tween.tween_callback(func():
			music_player.stop()
			music_player.stream = stream
			music_player.volume_db = -80.0
			music_player.play()
			var fade_tween := create_tween()
			fade_tween.tween_property(music_player, "volume_db", _linear_to_db(music_volume), fade_in)
		)
	else:
		music_player.stream = stream
		if fade_in > 0.0:
			music_player.volume_db = -80.0
			music_player.play()
			if _music_fade_tween and _music_fade_tween.is_valid():
				_music_fade_tween.kill()
			_music_fade_tween = create_tween()
			_music_fade_tween.tween_property(music_player, "volume_db", _linear_to_db(music_volume), fade_in)
		else:
			music_player.volume_db = _linear_to_db(music_volume)
			music_player.play()


func stop_music(fade_out: float = 1.0) -> void:
	if not music_player.playing:
		return

	_current_music_path = ""

	if fade_out > 0.0:
		if _music_fade_tween and _music_fade_tween.is_valid():
			_music_fade_tween.kill()
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(music_player, "volume_db", -80.0, fade_out)
		_music_fade_tween.tween_callback(music_player.stop)
	else:
		music_player.stop()


# --- SFX ---

func play_sfx(stream_path: String, volume_db: float = 0.0) -> void:
	if not ResourceLoader.exists(stream_path):
		push_warning("AudioManager: SFX file not found: %s" % stream_path)
		return

	var stream := load(stream_path) as AudioStream
	if not stream:
		push_warning("AudioManager: Failed to load SFX: %s" % stream_path)
		return

	# Find an available player in the pool (one that isn't currently playing)
	var player := _get_available_sfx_player()
	if player:
		player.stream = stream
		player.volume_db = volume_db
		player.play()


func _get_available_sfx_player() -> AudioStreamPlayer:
	# First pass: find a player that isn't playing
	for player in sfx_pool:
		if not player.playing:
			return player

	# All busy — steal the oldest one (first in the pool, which started earliest)
	# A simple heuristic: return the one with the most playback progress
	var oldest_player: AudioStreamPlayer = sfx_pool[0]
	var most_progress: float = 0.0
	for player in sfx_pool:
		if player.get_playback_position() > most_progress:
			most_progress = player.get_playback_position()
			oldest_player = player

	oldest_player.stop()
	return oldest_player


# --- UI Sound ---

func play_ui_sound(stream_path: String) -> void:
	if not ResourceLoader.exists(stream_path):
		push_warning("AudioManager: UI sound file not found: %s" % stream_path)
		return

	var stream := load(stream_path) as AudioStream
	if not stream:
		push_warning("AudioManager: Failed to load UI sound: %s" % stream_path)
		return

	ui_sfx_player.stream = stream
	ui_sfx_player.volume_db = _linear_to_db(ui_volume)
	ui_sfx_player.play()


# --- Ambient ---

func play_ambient(stream_path: String, fade_in: float = 2.0) -> void:
	if not ResourceLoader.exists(stream_path):
		push_warning("AudioManager: Ambient file not found: %s" % stream_path)
		return

	var stream := load(stream_path) as AudioStream
	if not stream:
		push_warning("AudioManager: Failed to load ambient: %s" % stream_path)
		return

	ambient_player.stream = stream

	if fade_in > 0.0:
		ambient_player.volume_db = -80.0
		ambient_player.play()
		var tween := create_tween()
		tween.tween_property(ambient_player, "volume_db", _linear_to_db(ambient_volume), fade_in)
	else:
		ambient_player.volume_db = _linear_to_db(ambient_volume)
		ambient_player.play()


func stop_ambient(fade_out: float = 2.0) -> void:
	if not ambient_player.playing:
		return

	if fade_out > 0.0:
		var tween := create_tween()
		tween.tween_property(ambient_player, "volume_db", -80.0, fade_out)
		tween.tween_callback(ambient_player.stop)
	else:
		ambient_player.stop()


# --- Volume Controls ---

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, _linear_to_db(master_volume))


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	if _music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_music_bus_idx, _linear_to_db(music_volume))
	# Also update the current music player if playing
	if music_player and music_player.playing:
		# Don't override if a fade tween is running
		if not (_music_fade_tween and _music_fade_tween.is_valid()):
			music_player.volume_db = _linear_to_db(music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	if _sfx_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_sfx_bus_idx, _linear_to_db(sfx_volume))


func set_ui_volume(value: float) -> void:
	ui_volume = clampf(value, 0.0, 1.0)
	if _ui_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_ui_bus_idx, _linear_to_db(ui_volume))


func set_ambient_volume(value: float) -> void:
	ambient_volume = clampf(value, 0.0, 1.0)
	if _ambient_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_ambient_bus_idx, _linear_to_db(ambient_volume))


func _apply_all_volumes() -> void:
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_ui_volume(ui_volume)
	set_ambient_volume(ambient_volume)


# --- Utility ---

func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
