extends Node

## Manages the player's skill tree — upgrades earned by defeating bosses
## and completing special objectives.

signal skill_unlocked(skill_id: String)
signal skill_points_changed(points: int)

var skill_points: int = 0

# Multipliers applied by skills (used by player and other systems)
var melee_damage_multiplier: float = 1.0
var ranged_damage_multiplier: float = 1.0
var attack_cooldown_multiplier: float = 1.0
var damage_resist_multiplier: float = 1.0

var skills: Dictionary = {
	# Combat tree
	"melee_damage_1": {
		"name": "Sharper Blade",
		"description": "Melee damage +25%",
		"cost": 1,
		"unlocked": false,
		"category": "combat",
	},
	"melee_damage_2": {
		"name": "Deadly Edge",
		"description": "Melee damage +50%",
		"cost": 2,
		"unlocked": false,
		"category": "combat",
		"requires": "melee_damage_1",
	},
	"ranged_damage_1": {
		"name": "Focused Shot",
		"description": "Ranged damage +25%",
		"cost": 1,
		"unlocked": false,
		"category": "combat",
	},
	"ranged_damage_2": {
		"name": "Piercing Truth",
		"description": "Ranged damage +50%",
		"cost": 2,
		"unlocked": false,
		"category": "combat",
		"requires": "ranged_damage_1",
	},
	"attack_speed": {
		"name": "Quick Reflexes",
		"description": "Attack cooldown -20%",
		"cost": 2,
		"unlocked": false,
		"category": "combat",
	},

	# Sanity tree
	"max_sanity_1": {
		"name": "Strong Mind",
		"description": "Max sanity +25",
		"cost": 1,
		"unlocked": false,
		"category": "sanity",
	},
	"max_sanity_2": {
		"name": "Iron Will",
		"description": "Max sanity +50",
		"cost": 2,
		"unlocked": false,
		"category": "sanity",
		"requires": "max_sanity_1",
	},
	"sanity_regen": {
		"name": "Mental Recovery",
		"description": "Passive sanity regen",
		"cost": 2,
		"unlocked": false,
		"category": "sanity",
	},
	"damage_resist": {
		"name": "Thick Skin",
		"description": "Propaganda damage -20%",
		"cost": 2,
		"unlocked": false,
		"category": "sanity",
	},

	# Shield tree
	"shield_capacity_1": {
		"name": "Expanded Shield",
		"description": "Shield energy +30%",
		"cost": 1,
		"unlocked": false,
		"category": "shield",
	},
	"shield_capacity_2": {
		"name": "Fortress of Truth",
		"description": "Shield energy +60%",
		"cost": 2,
		"unlocked": false,
		"category": "shield",
		"requires": "shield_capacity_1",
	},
	"shield_recharge": {
		"name": "Quick Clarity",
		"description": "Shield recharge +50%",
		"cost": 1,
		"unlocked": false,
		"category": "shield",
	},
	"shield_absorption": {
		"name": "Propaganda Absorber",
		"description": "Upgrade shield absorption tier",
		"cost": 3,
		"unlocked": false,
		"category": "shield",
	},
}


func _ready() -> void:
	pass


## Add skill points (e.g. from defeating a boss).
func add_skill_points(amount: int) -> void:
	skill_points += amount
	skill_points_changed.emit(skill_points)


## Check if a skill can be unlocked (has points, prereqs met, not already unlocked).
func can_unlock(skill_id: String) -> bool:
	if not skills.has(skill_id):
		return false

	var skill: Dictionary = skills[skill_id]

	# Already unlocked
	if skill["unlocked"]:
		return false

	# Not enough points
	if skill_points < skill["cost"]:
		return false

	# Check prerequisite
	if skill.has("requires"):
		var req_id: String = skill["requires"]
		if not skills.has(req_id) or not skills[req_id]["unlocked"]:
			return false

	return true


## Unlock a skill and apply its effect immediately. Returns true on success.
func unlock_skill(skill_id: String) -> bool:
	if not can_unlock(skill_id):
		return false

	var skill: Dictionary = skills[skill_id]
	skill_points -= skill["cost"]
	skill["unlocked"] = true

	_apply_skill_effect(skill_id)

	skill_unlocked.emit(skill_id)
	skill_points_changed.emit(skill_points)
	return true


## Re-apply all unlocked skills. Call this after loading a save.
func apply_all_skills() -> void:
	# Reset multipliers to defaults before re-applying
	melee_damage_multiplier = 1.0
	ranged_damage_multiplier = 1.0
	attack_cooldown_multiplier = 1.0
	damage_resist_multiplier = 1.0

	for skill_id in skills:
		if skills[skill_id]["unlocked"]:
			_apply_skill_effect(skill_id)


## Apply the effect of a single skill.
func _apply_skill_effect(skill_id: String) -> void:
	match skill_id:
		"melee_damage_1":
			melee_damage_multiplier = 1.25
		"melee_damage_2":
			melee_damage_multiplier = 1.5
		"ranged_damage_1":
			ranged_damage_multiplier = 1.25
		"ranged_damage_2":
			ranged_damage_multiplier = 1.5
		"attack_speed":
			attack_cooldown_multiplier = 0.8
		"max_sanity_1":
			SanityManager.max_sanity = 125.0
			SanityManager.sanity_changed.emit(SanityManager.current_sanity, SanityManager.max_sanity)
		"max_sanity_2":
			SanityManager.max_sanity = 150.0
			SanityManager.sanity_changed.emit(SanityManager.current_sanity, SanityManager.max_sanity)
		"sanity_regen":
			SanityManager.sanity_regen_rate = 1.5
		"damage_resist":
			damage_resist_multiplier = 0.8
		"shield_capacity_1":
			_apply_shield_capacity(30.0)
		"shield_capacity_2":
			_apply_shield_capacity(60.0)
		"shield_recharge":
			_apply_shield_recharge_bonus()
		"shield_absorption":
			_apply_shield_absorption_upgrade()


## Apply shield energy capacity bonus to the player's clarity shield.
func _apply_shield_capacity(bonus: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		var shield := player.get_node_or_null("ClarityShield")
		if shield and "max_energy_bonus" in shield:
			shield.max_energy_bonus = bonus


## Apply shield recharge rate bonus.
func _apply_shield_recharge_bonus() -> void:
	# The clarity shield script reads BASE_RECHARGE_RATE as a const,
	# so we store a flag the shield can check, or directly modify
	# the shield instance at runtime.
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		var shield := player.get_node_or_null("ClarityShield")
		if shield and shield.has_method("get_energy_ratio"):
			# Set a metadata tag that the shield can read
			shield.set_meta("recharge_bonus", 1.5)


## Upgrade the shield's absorption tier.
func _apply_shield_absorption_upgrade() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		var shield := player.get_node_or_null("ClarityShield")
		if shield and shield.has_method("upgrade"):
			shield.upgrade()


## Get save data for the skill tree.
func get_save_data() -> Dictionary:
	var unlocked_skills: Dictionary = {}
	for skill_id in skills:
		unlocked_skills[skill_id] = skills[skill_id]["unlocked"]

	return {
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills,
	}


## Load save data and restore skill tree state.
func load_save_data(data: Dictionary) -> void:
	if data.has("skill_points"):
		skill_points = int(data["skill_points"])
		skill_points_changed.emit(skill_points)

	if data.has("unlocked_skills"):
		var unlocked: Dictionary = data["unlocked_skills"]
		for skill_id in unlocked:
			if skills.has(skill_id):
				skills[skill_id]["unlocked"] = unlocked[skill_id]

	apply_all_skills()
