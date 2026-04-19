extends Node

## Central manager for screen effects: shake, freeze, flash, sanity distortion.
## Add as autoload: EffectsManager

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _original_camera_offset: Vector2 = Vector2.ZERO
var _camera_ref: Camera2D = null

var _overlay_layer: CanvasLayer = null
var _flash_overlay: ColorRect = null
var _vignette_overlay: ColorRect = null
var _sanity_overlay: ColorRect = null

# Sanity-driven periodic shake
var _sanity_shake_timer: float = 0.0
var _sanity_shake_interval: float = 3.0  # seconds between periodic sanity shakes
var _current_sanity_ratio: float = 1.0

# Reference to the sanity distortion shader material on the overlay
var _sanity_shader_material: ShaderMaterial = null


func _ready() -> void:
	_create_overlay_layer()

	# Connect to SanityManager signals (it's loaded before us as an autoload)
	if SanityManager:
		SanityManager.sanity_changed.connect(_update_sanity_effects)
		SanityManager.sanity_depleted.connect(_on_sanity_depleted)


func _process(delta: float) -> void:
	_process_screen_shake(delta)
	_process_sanity_periodic_effects(delta)

	# Update time offset for sanity shader
	if _sanity_shader_material:
		_sanity_shader_material.set_shader_parameter("time_offset", Time.get_ticks_msec() / 1000.0)


func _create_overlay_layer() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100  # On top of everything
	add_child(_overlay_layer)

	# Sanity distortion overlay — uses the shader for wavy distortion, desaturation, etc.
	_sanity_overlay = ColorRect.new()
	_sanity_overlay.name = "SanityOverlay"
	_sanity_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_sanity_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sanity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sanity_overlay.color = Color(1, 1, 1, 1)

	# Load and apply the sanity distortion shader
	var shader_path := "res://assets/shaders/sanity_distortion.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader := load(shader_path) as Shader
		if shader:
			_sanity_shader_material = ShaderMaterial.new()
			_sanity_shader_material.shader = shader
			_sanity_shader_material.set_shader_parameter("sanity_ratio", 1.0)
			_sanity_shader_material.set_shader_parameter("time_offset", 0.0)
			_sanity_overlay.material = _sanity_shader_material

	# Start invisible (full sanity = no effect needed)
	_sanity_overlay.visible = false
	_overlay_layer.add_child(_sanity_overlay)

	# Vignette overlay — simple colored vignette driven by sanity
	_vignette_overlay = ColorRect.new()
	_vignette_overlay.name = "VignetteOverlay"
	_vignette_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_vignette_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_overlay.color = Color(0.5, 0.0, 0.1, 0.0)
	_overlay_layer.add_child(_vignette_overlay)

	# Flash overlay — for screen_flash()
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "FlashOverlay"
	_flash_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(1, 1, 1, 0)
	_overlay_layer.add_child(_flash_overlay)


# --- Screen Shake ---

func shake_camera(intensity: float = 4.0, duration: float = 0.2) -> void:
	# Only override if this shake is stronger than the current one
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_duration = duration
		_shake_timer = duration
		_find_camera()


func _find_camera() -> void:
	# Try to find the current active camera
	var viewport := get_viewport()
	if viewport:
		var camera := viewport.get_camera_2d()
		if camera and camera != _camera_ref:
			_camera_ref = camera
			_original_camera_offset = camera.offset


func _process_screen_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		return

	_shake_timer -= delta

	if not _camera_ref or not is_instance_valid(_camera_ref):
		_find_camera()
		if not _camera_ref:
			_shake_timer = 0.0
			return

	if _shake_timer > 0.0:
		# Ease out the shake intensity as time progresses
		var progress := _shake_timer / _shake_duration
		var current_intensity := _shake_intensity * progress
		var offset := Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		_camera_ref.offset = _original_camera_offset + offset
	else:
		# Shake finished — reset
		_camera_ref.offset = _original_camera_offset
		_shake_intensity = 0.0
		_shake_timer = 0.0


# --- Hit Freeze ---

func hit_freeze(duration: float = 0.05) -> void:
	Engine.time_scale = 0.01
	# Use a SceneTreeTimer that respects real time (not scaled time)
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# --- Screen Flash ---

func screen_flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	if not _flash_overlay:
		return

	_flash_overlay.color = Color(color.r, color.g, color.b, 1.0)

	var tween := create_tween()
	tween.tween_property(_flash_overlay, "color:a", 0.0, duration)


# --- Sanity Effects ---

func _update_sanity_effects(sanity: float, max_sanity: float) -> void:
	if max_sanity <= 0.0:
		_current_sanity_ratio = 0.0
	else:
		_current_sanity_ratio = sanity / max_sanity

	# Update shader parameter
	if _sanity_shader_material:
		_sanity_shader_material.set_shader_parameter("sanity_ratio", _current_sanity_ratio)

	# Show/hide the sanity overlay based on whether there's any distortion
	if _sanity_overlay:
		_sanity_overlay.visible = _current_sanity_ratio < 0.95

	# Update vignette overlay alpha based on sanity
	if _vignette_overlay:
		if _current_sanity_ratio < 0.5:
			# Map 0.5 -> 0.0 alpha, 0.0 -> 0.4 alpha
			var vignette_alpha := (0.5 - _current_sanity_ratio) * 0.8
			_vignette_overlay.color = Color(0.5, 0.0, 0.1, vignette_alpha)
		else:
			_vignette_overlay.color = Color(0.5, 0.0, 0.1, 0.0)


func _process_sanity_periodic_effects(delta: float) -> void:
	# Periodic screen shake when sanity is low
	if _current_sanity_ratio >= 0.5:
		_sanity_shake_timer = 0.0
		return

	_sanity_shake_timer += delta

	# Determine shake interval — more frequent as sanity drops
	var interval := _sanity_shake_interval
	if _current_sanity_ratio < 0.1:
		interval = 1.0  # Very frequent when nearly depleted
	elif _current_sanity_ratio < 0.25:
		interval = 2.0

	if _sanity_shake_timer >= interval:
		_sanity_shake_timer = 0.0

		# Determine shake intensity based on sanity
		var shake_power := 1.0
		if _current_sanity_ratio < 0.1:
			shake_power = 4.0
		elif _current_sanity_ratio < 0.25:
			shake_power = 2.5
		else:
			shake_power = 1.5

		shake_camera(shake_power, 0.15)


func _on_sanity_depleted() -> void:
	# Dramatic effect when sanity hits zero
	screen_flash(Color(0.6, 0.0, 0.1), 0.5)
	shake_camera(8.0, 0.5)


# --- Utility: Spawn floating damage/heal number ---

func spawn_damage_number(position: Vector2, value: float, color: Color = Color.WHITE) -> void:
	var scene_path := "res://scenes/effects/damage_number.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var instance := scene.instantiate() as Node2D
	instance.global_position = position
	instance.value = value
	instance.color = color
	# Add to the current scene tree
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(instance)


func spawn_hit_spark(position: Vector2) -> void:
	var scene_path := "res://scenes/effects/hit_spark.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var instance := scene.instantiate() as Node2D
	instance.global_position = position
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(instance)


func spawn_shield_effect(position: Vector2) -> void:
	var scene_path := "res://scenes/effects/shield_effect.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var instance := scene.instantiate() as Node2D
	instance.global_position = position
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(instance)


func spawn_death_effect(position: Vector2) -> void:
	var scene_path := "res://scenes/effects/death_effect.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var instance := scene.instantiate() as Node2D
	instance.global_position = position
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(instance)
