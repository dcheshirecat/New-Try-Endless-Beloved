# CharacterSetup.gd
# Name entry and pronoun selection — runs once at game start
extends Control

@onready var name_input = $NamePanel/NameInput
@onready var name_hint = $NamePanel/NameHint
@onready var pronoun_buttons = $PronounPanel/PronounGrid
@onready var custom_pronoun_panel = $CustomPronounPanel
@onready var subject_input = $CustomPronounPanel/SubjectInput
@onready var object_input = $CustomPronounPanel/ObjectInput
@onready var possessive_input = $CustomPronounPanel/PossessiveInput
@onready var confirm_button = $ConfirmButton
@onready var preview_text = $PreviewText

const PRONOUN_SETS: Array[Dictionary] = [
	{"label": "She / Her", "subject": "she", "object": "her", "possessive": "her"},
	{"label": "He / Him", "subject": "he", "object": "him", "possessive": "his"},
	{"label": "They / Them", "subject": "they", "object": "them", "possessive": "their"},
	{"label": "It / Its", "subject": "it", "object": "it", "possessive": "its"},
	{"label": "Custom...", "subject": "", "object": "", "possessive": ""}
]

var _selected_pronoun_index: int = 2  # Default: they/them
var _custom_mode: bool = false

func _ready() -> void:
	_build_pronoun_buttons()
	_select_pronoun(2)
	custom_pronoun_panel.visible = false
	name_input.text = ""
	name_input.placeholder_text = "Enter your name..."
	name_input.text_changed.connect(_on_name_changed)
	confirm_button.disabled = true

func _build_pronoun_buttons() -> void:
	for child in pronoun_buttons.get_children():
		child.queue_free()
	for i in PRONOUN_SETS.size():
		var set = PRONOUN_SETS[i]
		var btn = Button.new()
		btn.text = set.label
		btn.custom_minimum_size = Vector2(160, 56)
		btn.toggle_mode = true
		var capture_i = i
		btn.pressed.connect(func(): _select_pronoun(capture_i))
		pronoun_buttons.add_child(btn)

func _select_pronoun(index: int) -> void:
	_selected_pronoun_index = index
	# Update button states
	var buttons = pronoun_buttons.get_children()
	for i in buttons.size():
		if buttons[i] is Button:
			buttons[i].button_pressed = (i == index)

	if index == PRONOUN_SETS.size() - 1:
		_custom_mode = true
		custom_pronoun_panel.visible = true
	else:
		_custom_mode = false
		custom_pronoun_panel.visible = false
		var set = PRONOUN_SETS[index]
		GameState.set_pronouns(set.subject, set.object, set.possessive)
	_update_preview()
	AudioManager.play_sfx("menu_select")

func _on_name_changed(new_text: String) -> void:
	GameState.player_name = new_text.strip_edges()
	confirm_button.disabled = GameState.player_name.length() < 1
	_update_preview()

func _update_preview() -> void:
	var name = GameState.player_name if GameState.player_name != "" else "[name]"
	var they = GameState.player_pronoun_subject
	var their = GameState.player_pronoun_possessive
	preview_text.text = (
		'"%s woke in the tower. %s did not remember %s name.\nBut the cards did."'
		% [name, they.capitalize(), their]
	)

func _on_custom_pronoun_changed(_text: String) -> void:
	if _custom_mode:
		GameState.set_pronouns(
			subject_input.text.strip_edges().to_lower(),
			object_input.text.strip_edges().to_lower(),
			possessive_input.text.strip_edges().to_lower()
		)
		_update_preview()

func _on_confirm_button_pressed() -> void:
	if GameState.player_name.strip_edges().length() < 1:
		name_hint.text = "The cards need a name to remember you by."
		name_hint.visible = true
		return
	if _custom_mode:
		if subject_input.text.strip_edges() == "" or object_input.text.strip_edges() == "":
			return
	AudioManager.play_sfx("affinity_up")
	# Save and begin prologue
	GameState.current_chapter = 1
	GameState.current_scene_id = "prologue_01"
	DialogueSystem.load_chapter("chapter_01")
	SceneManager.go_to("liminal_tower.tscn")
