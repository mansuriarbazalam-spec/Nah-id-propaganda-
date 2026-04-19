extends Node

## Manages the player's sanity system — the core "health" mechanic.
## Sanity depletion = game over. Propaganda attacks drain sanity.
## The Clarity Shield can block or reduce propaganda damage.

signal sanity_changed(new_value: float, max_value: float)
signal sanity_depleted
signal sanity_low

const LOW_SANITY_THRESHOLD: float = 25.0

var max_sanity: float = 100.0
var current_sanity: float = 100.0
var sanity_regen_rate: float = 0.0
var is_shielded: bool = false

# Shield reduces incoming damage by this multiplier (0.0 = full block)
var shield_damage_multiplier: float = 0.1

var _low_sanity_emitted: bool = false


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if sanity_regen_rate > 0.0 and current_sanity < max_sanity:
		heal_sanity(sanity_regen_rate * delta)


## Apply sanity damage. If shielded, damage is heavily reduced.
func take_sanity_damage(amount: float) -> void:
	var actual_damage := amount
	if is_shielded:
		actual_damage = amount * shield_damage_multiplier

	current_sanity = maxf(current_sanity - actual_damage, 0.0)
	sanity_changed.emit(current_sanity, max_sanity)

	if current_sanity <= 0.0:
		sanity_depleted.emit()
		GameManager.game_over()
	elif current_sanity <= LOW_SANITY_THRESHOLD and not _low_sanity_emitted:
		_low_sanity_emitted = true
		sanity_low.emit()


## Heal sanity by the given amount. Clamped to max.
func heal_sanity(amount: float) -> void:
	current_sanity = minf(current_sanity + amount, max_sanity)
	sanity_changed.emit(current_sanity, max_sanity)

	# Reset low sanity flag if healed above threshold
	if current_sanity > LOW_SANITY_THRESHOLD:
		_low_sanity_emitted = false


## Reset sanity to maximum.
func reset_sanity() -> void:
	current_sanity = max_sanity
	_low_sanity_emitted = false
	sanity_changed.emit(current_sanity, max_sanity)


## Set shielded state (Clarity Shield active/inactive).
func set_shielded(value: bool) -> void:
	is_shielded = value


## Get sanity as a normalized ratio (0.0 to 1.0).
func get_sanity_ratio() -> float:
	if max_sanity <= 0.0:
		return 0.0
	return current_sanity / max_sanity


## Check if sanity is in the low/danger zone.
func is_sanity_low() -> bool:
	return current_sanity <= LOW_SANITY_THRESHOLD
