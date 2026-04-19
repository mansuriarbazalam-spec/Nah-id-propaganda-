extends Node

## Handles saving and loading game data to/from user://savegame.json.

const SAVE_PATH: String = "user://savegame.json"

# Default save data structure
var _default_save_data: Dictionary = {
	"current_level": "",
	"checkpoint_id": "",
	"sanity": 100.0,
	"skill_tree_state": {},
	"unlocked_abilities": [],
	"completed_levels": [],
}


func _ready() -> void:
	pass


## Save the current game state to disk.
func save_game() -> void:
	var save_data := _build_save_data()
	_write_save_file(save_data)


## Save at a specific checkpoint.
func save_at_checkpoint(checkpoint_id: String) -> void:
	var save_data := _build_save_data()
	save_data["checkpoint_id"] = checkpoint_id
	_write_save_file(save_data)


## Load the saved game and restore state. Returns true on success.
func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: Failed to parse save file.")
		return false

	var save_data: Dictionary = json.data
	_apply_save_data(save_data)
	return true


## Check if a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


## Build a dictionary of the current game state.
func _build_save_data() -> Dictionary:
	var save_data := _default_save_data.duplicate(true)
	save_data["current_level"] = GameManager.current_level
	save_data["sanity"] = SanityManager.current_sanity
	save_data["completed_levels"] = GameManager.completed_levels.duplicate()

	# Save skill tree data if SkillTreeManager is available
	var stm = get_node_or_null("/root/SkillTreeManager")
	if stm:
		if stm.has_method("get_save_data"):
			save_data["skill_tree_state"] = stm.get_save_data()
		elif "unlocked_skills" in stm:
			save_data["skill_tree_state"] = stm.unlocked_skills
		if "unlocked_abilities" in stm:
			save_data["unlocked_abilities"] = stm.unlocked_abilities

	return save_data


## Write save data dictionary to the save file.
func _write_save_file(save_data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()


## Apply loaded save data to game systems.
func _apply_save_data(save_data: Dictionary) -> void:
	# Restore sanity
	if save_data.has("sanity"):
		SanityManager.current_sanity = save_data["sanity"]
		SanityManager.sanity_changed.emit(SanityManager.current_sanity, SanityManager.max_sanity)

	# Restore completed levels
	if save_data.has("completed_levels"):
		GameManager.completed_levels.clear()
		for level in save_data["completed_levels"]:
			GameManager.completed_levels.append(level)

	# Restore skill tree data if SkillTreeManager is available
	var stm = get_node_or_null("/root/SkillTreeManager")
	if stm:
		if save_data.has("skill_tree_state") and stm.has_method("load_save_data"):
			stm.load_save_data(save_data["skill_tree_state"])
		elif save_data.has("skill_tree_state") and "unlocked_skills" in stm:
			stm.unlocked_skills = save_data["skill_tree_state"]
		if save_data.has("unlocked_abilities") and "unlocked_abilities" in stm:
			stm.unlocked_abilities = save_data["unlocked_abilities"]

	# Change to the saved level
	if save_data.has("current_level") and save_data["current_level"] != "":
		GameManager.change_level(save_data["current_level"])
