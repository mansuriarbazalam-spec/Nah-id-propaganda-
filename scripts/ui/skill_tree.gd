extends CanvasLayer

## Skill tree UI — shows three columns (Combat, Sanity, Shield)
## with unlockable skill buttons. Opened from the pause menu or checkpoints.

@onready var bg: ColorRect = $Background
@onready var title_label: Label = $Background/MainVBox/TitleLabel
@onready var points_label: Label = $Background/MainVBox/PointsLabel
@onready var combat_column: VBoxContainer = $Background/MainVBox/ColumnsHBox/CombatColumn
@onready var sanity_column: VBoxContainer = $Background/MainVBox/ColumnsHBox/SanityColumn
@onready var shield_column: VBoxContainer = $Background/MainVBox/ColumnsHBox/ShieldColumn
@onready var description_label: Label = $Background/MainVBox/DescriptionPanel/DescriptionLabel
@onready var unlock_button: Button = $Background/MainVBox/ButtonsHBox/UnlockButton
@onready var back_button: Button = $Background/MainVBox/ButtonsHBox/BackButton

var _selected_skill_id: String = ""
var _skill_buttons: Dictionary = {}  # skill_id -> Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	unlock_button.pressed.connect(_on_unlock_pressed)
	back_button.pressed.connect(_on_back_pressed)

	SkillTreeManager.skill_unlocked.connect(_on_skill_unlocked)
	SkillTreeManager.skill_points_changed.connect(_on_skill_points_changed)

	_build_skill_buttons()
	_refresh_all()

	visible = false


## Show the skill tree UI.
func open() -> void:
	visible = true
	_selected_skill_id = ""
	_refresh_all()
	get_tree().paused = true
	back_button.grab_focus()


## Hide the skill tree UI.
func close() -> void:
	visible = false
	get_tree().paused = false


func _build_skill_buttons() -> void:
	# Clear existing buttons
	_clear_column(combat_column)
	_clear_column(sanity_column)
	_clear_column(shield_column)
	_skill_buttons.clear()

	for skill_id in SkillTreeManager.skills:
		var skill: Dictionary = SkillTreeManager.skills[skill_id]
		var btn := Button.new()
		btn.text = "%s (%d)" % [skill["name"], skill["cost"]]
		btn.custom_minimum_size = Vector2(130, 18)
		btn.add_theme_font_size_override("font_size", 7)
		btn.pressed.connect(_on_skill_button_pressed.bind(skill_id))

		match skill["category"]:
			"combat":
				combat_column.add_child(btn)
			"sanity":
				sanity_column.add_child(btn)
			"shield":
				shield_column.add_child(btn)

		_skill_buttons[skill_id] = btn


func _clear_column(column: VBoxContainer) -> void:
	# Keep the header label (first child) if it exists
	var children := column.get_children()
	for i in range(children.size()):
		var child := children[i]
		if child is Label:
			continue  # Keep column header
		child.queue_free()


func _refresh_all() -> void:
	_update_points_display()
	_update_all_buttons()
	_update_description()
	_update_unlock_button()


func _update_points_display() -> void:
	points_label.text = "Skill Points: %d" % SkillTreeManager.skill_points


func _update_all_buttons() -> void:
	for skill_id in _skill_buttons:
		var btn: Button = _skill_buttons[skill_id]
		var skill: Dictionary = SkillTreeManager.skills[skill_id]

		if skill["unlocked"]:
			# Unlocked — highlight green
			btn.modulate = Color(0.4, 1.0, 0.4)
			btn.disabled = false
		elif SkillTreeManager.can_unlock(skill_id):
			# Can unlock — glow bright
			btn.modulate = Color(1.0, 1.0, 0.6)
			btn.disabled = false
		else:
			# Locked — greyed out
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = false  # Still selectable to see description


func _update_description() -> void:
	if _selected_skill_id == "" or not SkillTreeManager.skills.has(_selected_skill_id):
		description_label.text = "Select a skill to see its description."
		return

	var skill: Dictionary = SkillTreeManager.skills[_selected_skill_id]
	var status := ""
	if skill["unlocked"]:
		status = " [UNLOCKED]"
	elif SkillTreeManager.can_unlock(_selected_skill_id):
		status = " [AVAILABLE]"
	else:
		status = " [LOCKED]"

	var req_text := ""
	if skill.has("requires"):
		var req_name: String = SkillTreeManager.skills[skill["requires"]]["name"]
		req_text = "\nRequires: %s" % req_name

	description_label.text = "%s%s\n%s\nCost: %d point(s)%s" % [
		skill["name"], status, skill["description"], skill["cost"], req_text
	]


func _update_unlock_button() -> void:
	if _selected_skill_id == "":
		unlock_button.disabled = true
		unlock_button.text = "Unlock"
		return

	var skill: Dictionary = SkillTreeManager.skills[_selected_skill_id]
	if skill["unlocked"]:
		unlock_button.disabled = true
		unlock_button.text = "Unlocked"
	elif SkillTreeManager.can_unlock(_selected_skill_id):
		unlock_button.disabled = false
		unlock_button.text = "Unlock (%d)" % skill["cost"]
	else:
		unlock_button.disabled = true
		unlock_button.text = "Locked"


# -- Signal handlers ----------------------------------------------------------

func _on_skill_button_pressed(skill_id: String) -> void:
	_selected_skill_id = skill_id
	_update_description()
	_update_unlock_button()


func _on_unlock_pressed() -> void:
	if _selected_skill_id == "":
		return

	var success := SkillTreeManager.unlock_skill(_selected_skill_id)
	if success:
		_refresh_all()


func _on_back_pressed() -> void:
	close()


func _on_skill_unlocked(_skill_id: String) -> void:
	_refresh_all()


func _on_skill_points_changed(_points: int) -> void:
	_refresh_all()
