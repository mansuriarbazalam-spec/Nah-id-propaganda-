extends CanvasLayer

## In-game HUD displaying sanity bar, shield cooldown, weapon indicator, and boss bar.

@onready var sanity_bar: ProgressBar = %SanityBar
@onready var sanity_label: Label = %SanityLabel
@onready var shield_indicator: Label = %ShieldIndicator
@onready var ability_label: Label = %AbilityLabel
@onready var boss_bar_container: Control = %BossBarContainer
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_name_label: Label = %BossNameLabel

# Sanity bar color thresholds (gothic palette)
const COLOR_HIGH := Color(0.85, 0.78, 0.55)   # Bone cream — healthy
const COLOR_MEDIUM := Color(0.85, 0.48, 0.12) # Amber — caution
const COLOR_LOW := Color(0.75, 0.10, 0.08)    # Blood red — danger
const MEDIUM_THRESHOLD: float = 50.0
const LOW_THRESHOLD: float = 25.0


func _ready() -> void:
	# Connect to SanityManager signals
	SanityManager.sanity_changed.connect(_on_sanity_changed)
	SanityManager.sanity_low.connect(_on_sanity_low)

	# Initialize display
	_update_sanity_display(SanityManager.current_sanity, SanityManager.max_sanity)

	# Hide boss bar by default
	boss_bar_container.visible = false

	# Set initial shield state
	_update_shield_display()

	# Set initial ability display
	ability_label.text = "Melee"


func _process(_delta: float) -> void:
	_update_shield_display()


func _on_sanity_changed(new_value: float, max_value: float) -> void:
	_update_sanity_display(new_value, max_value)


func _on_sanity_low() -> void:
	# Could trigger screen effects, vignette, etc.
	pass


func _update_sanity_display(current: float, maximum: float) -> void:
	sanity_bar.max_value = maximum
	sanity_bar.value = current
	sanity_label.text = str(int(current)) + " / " + str(int(maximum))

	# Update bar color based on sanity level
	var bar_style := sanity_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if bar_style:
		if current <= LOW_THRESHOLD:
			bar_style.bg_color = COLOR_LOW
		elif current <= MEDIUM_THRESHOLD:
			bar_style.bg_color = COLOR_MEDIUM
		else:
			bar_style.bg_color = COLOR_HIGH


func _update_shield_display() -> void:
	if SanityManager.is_shielded:
		shield_indicator.text = "SHIELD: ACTIVE"
		shield_indicator.modulate = Color(0.3, 0.7, 1.0)
	else:
		shield_indicator.text = "SHIELD: READY"
		shield_indicator.modulate = Color(0.6, 0.6, 0.6)


## Show the boss health bar with a given name and max influence.
func show_boss_bar(boss_name: String, max_influence: float) -> void:
	boss_bar_container.visible = true
	boss_name_label.text = boss_name
	boss_bar.max_value = max_influence
	boss_bar.value = max_influence


## Update the boss bar value.
func update_boss_bar(current_influence: float) -> void:
	boss_bar.value = current_influence
	if current_influence <= 0.0:
		hide_boss_bar()


## Hide the boss health bar.
func hide_boss_bar() -> void:
	boss_bar_container.visible = false


## Set the current ability/weapon name displayed.
func set_current_ability(ability_name: String) -> void:
	ability_label.text = ability_name
