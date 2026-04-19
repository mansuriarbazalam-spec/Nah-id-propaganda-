extends Area2D

## Clarity Shield — the player's counter-propaganda defensive ability.
## Toggle on/off with the shield input. While active it absorbs
## (or reduces) propaganda damage at the cost of shield energy.
## Energy slowly recharges when the shield is inactive.

# ── Shield constants ────────────────────────────────────────────────
const BASE_MAX_ENERGY: float = 100.0
const BASE_DRAIN_RATE: float = 30.0        # energy per second while active
const BASE_RECHARGE_RATE: float = 12.0     # energy per second while inactive
const DEPLETED_COOLDOWN: float = 2.0       # seconds before recharge after full depletion
const RECHARGE_DELAY: float = 0.5          # seconds after deactivation before recharging

# Shield absorption tiers: fraction of propaganda damage blocked
const ABSORPTION_BASE: float = 0.5
const ABSORPTION_UPGRADED: float = 0.75
const ABSORPTION_MAX: float = 1.0

# ── Exports (upgradeable from game systems) ─────────────────────────
@export var shield_level: int = 0          # 0 = base, 1 = upgraded, 2 = max
@export var max_energy_bonus: float = 0.0  # flat bonus to max energy

# ── Node references ─────────────────────────────────────────────────
@onready var shield_visual: ColorRect = $ShieldVisual
@onready var shield_shape: CollisionShape2D = $ShieldShape

# ── State ───────────────────────────────────────────────────────────
var shield_active: bool = false
var shield_energy: float = BASE_MAX_ENERGY
var depleted: bool = false
var depleted_cooldown_timer: float = 0.0
var recharge_delay_timer: float = 0.0


func _ready() -> void:
	shield_energy = _get_max_energy()
	_deactivate_shield()


func _process(delta: float) -> void:
	_handle_input()
	_handle_drain(delta)
	_handle_recharge(delta)
	_update_visual()


# ── Input handling ──────────────────────────────────────────────────
func _handle_input() -> void:
	if Input.is_action_just_pressed("shield"):
		if shield_active:
			_deactivate_shield()
		elif not depleted and shield_energy > 0.0:
			_activate_shield()


# ── Activate / Deactivate ──────────────────────────────────────────
func _activate_shield() -> void:
	shield_active = true
	shield_shape.disabled = false
	monitoring = true
	shield_visual.visible = true

	# Tell SanityManager the player is shielded
	var sm = get_node_or_null("/root/SanityManager")
	if sm and sm.has_method("set_shielded"):
		sm.set_shielded(true)


func _deactivate_shield() -> void:
	shield_active = false
	shield_shape.disabled = true
	monitoring = false
	shield_visual.visible = false
	recharge_delay_timer = RECHARGE_DELAY

	var sm = get_node_or_null("/root/SanityManager")
	if sm and sm.has_method("set_shielded"):
		sm.set_shielded(false)


# ── Drain while active ─────────────────────────────────────────────
func _handle_drain(delta: float) -> void:
	if not shield_active:
		return

	shield_energy -= BASE_DRAIN_RATE * delta
	if shield_energy <= 0.0:
		shield_energy = 0.0
		depleted = true
		depleted_cooldown_timer = DEPLETED_COOLDOWN
		_deactivate_shield()


# ── Recharge while inactive ────────────────────────────────────────
func _handle_recharge(delta: float) -> void:
	if shield_active:
		return

	# Depleted cooldown
	if depleted:
		depleted_cooldown_timer -= delta
		if depleted_cooldown_timer <= 0.0:
			depleted = false
		return

	# Short delay after manual deactivation before recharging
	if recharge_delay_timer > 0.0:
		recharge_delay_timer -= delta
		return

	var max_e := _get_max_energy()
	if shield_energy < max_e:
		shield_energy += BASE_RECHARGE_RATE * delta
		shield_energy = min(shield_energy, max_e)


# ── Damage absorption ──────────────────────────────────────────────

## Returns true when the shield is currently blocking.
func is_shield_active() -> bool:
	return shield_active and shield_energy > 0.0


## Absorb incoming damage. Returns the remaining (unblocked) damage.
func absorb_damage(incoming: float) -> float:
	if not is_shield_active():
		return incoming

	var absorption := _get_absorption_rate()
	var blocked := incoming * absorption
	var passed := incoming - blocked

	# Absorbing damage also costs energy (half the blocked amount)
	shield_energy -= blocked * 0.5
	if shield_energy <= 0.0:
		shield_energy = 0.0
		depleted = true
		depleted_cooldown_timer = DEPLETED_COOLDOWN
		_deactivate_shield()

	return passed


# ── Helpers ─────────────────────────────────────────────────────────

func _get_max_energy() -> float:
	return BASE_MAX_ENERGY + max_energy_bonus


func _get_absorption_rate() -> float:
	match shield_level:
		0:
			return ABSORPTION_BASE
		1:
			return ABSORPTION_UPGRADED
		2:
			return ABSORPTION_MAX
		_:
			return ABSORPTION_BASE


## Get current energy as a 0-1 ratio (useful for UI).
func get_energy_ratio() -> float:
	return shield_energy / _get_max_energy()


## Upgrade the shield to the next tier. Returns true if upgraded.
func upgrade() -> bool:
	if shield_level < 2:
		shield_level += 1
		return true
	return false


# ── Visual feedback ─────────────────────────────────────────────────
func _update_visual() -> void:
	if not shield_visual:
		return

	if shield_active:
		# Pulse alpha based on remaining energy
		var ratio := get_energy_ratio()
		var pulse := 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		shield_visual.color = Color(0.3, 0.6, 1.0, (ratio * 0.4) + pulse)
	# Shield visual is hidden when not active (handled in _deactivate_shield)
