# LiminalTower.gd
# The main gameplay location — navigable tower rooms, dialogue, exploration
extends Control

@onready var background = $Background
@onready var parallax_bg = $ParallaxBackground
@onready var character_layer = $CharacterLayer
@onready var dialogue_box = $DialogueBox
@onready var nav_buttons = $NavButtons
@onready var room_name_label = $RoomNameLabel
@onready var ambient_particles = $AmbientParticles
@onready var tap_zone = $TapZone
@onready var menu_button = $MenuButton
@onready var affinity_flash = $AffinityFlash

# Room definitions
const ROOMS: Dictionary = {
	"entrance": {
		"name": "The Entrance Hall",
		"bg": "res://images/backgrounds/tower_entrance.png",
		"music": "liminal",
		"connections": ["library", "garden"],
		"characters": []
	},
	"library": {
		"name": "The Oracle's Library",
		"bg": "res://images/backgrounds/tower_library.png",
		"music": "oracle_theme",
		"connections": ["entrance", "observatory"],
		"characters": ["oracle"]
	},
	"garden": {
		"name": "The Hanging Garden",
		"bg": "res://images/backgrounds/tower_garden.png",
		"music": "apprentice_theme",
		"connections": ["entrance", "crypt"],
		"characters": ["apprentice"]
	},
	"observatory": {
		"name": "The Observatory",
		"bg": "res://images/backgrounds/tower_observatory.png",
		"music": "liminal",
		"connections": ["library", "threshold"],
		"characters": []
	},
	"crypt": {
		"name": "The Crypt",
		"bg": "res://images/backgrounds/tower_crypt.png",
		"music": "tension",
		"connections": ["garden"],
		"characters": ["angel"]
	},
	"threshold": {
		"name": "The Threshold",
		"bg": "res://images/backgrounds/tower_threshold.png",
		"music": "ending",
		"connections": ["observatory"],
		"characters": ["angel", "oracle", "apprentice"]
	}
}

var _current_room: String = "entrance"
var _touch_start: Vector2 = Vector2.ZERO
var _is_in_dialogue: bool = false

func _ready() -> void:
	GameState.affinity_changed.connect(_on_affinity_changed)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DialogueSystem.flag_trigger.connect(_on_flag_trigger)
	tap_zone.gui_input.connect(_on_tap_zone_input)
	_enter_room("entrance")
	_start_current_scene()

func _start_current_scene() -> void:
	var scene_id = GameState.current_scene_id
	if scene_id != "" and DialogueSystem._dialogue_data.has(scene_id):
		_is_in_dialogue = true
		dialogue_box.visible = true
		DialogueSystem.start_node(scene_id)
	else:
		dialogue_box.visible = false

func _enter_room(room_id: String) -> void:
	if not ROOMS.has(room_id):
		return
	_current_room = room_id
	var room = ROOMS[room_id]
	room_name_label.text = room.name
	# Background
	var bg_path = room.get("bg", "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		background.texture = load(bg_path)
	# Music
	AudioManager.play_music(room.get("music", "liminal"))
	# Navigation
	_update_nav_buttons(room.connections)
	# Characters
	_update_characters(room.get("characters", []))
	# Ambient
	ambient_particles.emitting = true

func _update_nav_buttons(connections: Array) -> void:
	for child in nav_buttons.get_children():
		child.queue_free()
	for room_id in connections:
		if not ROOMS.has(room_id):
			continue
		# Check if room is accessible based on chapter
		if not _is_room_accessible(room_id):
			continue
		var btn = Button.new()
		btn.text = "→ " + ROOMS[room_id].name
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var capture_id = room_id
		btn.pressed.connect(func():
			AudioManager.play_sfx("menu_select")
			SceneManager.fade_to_black(0.3)
			await SceneManager.fade_to_black
			_enter_room(capture_id)
			SceneManager.fade_from_black(0.3)
		)
		nav_buttons.add_child(btn)

func _is_room_accessible(room_id: String) -> bool:
	# Threshold only in Act III
	if room_id == "threshold" and GameState.current_chapter < 8:
		return false
	# Crypt only after meeting Oracle
	if room_id == "crypt" and not GameState.has_flag("met_oracle"):
		return false
	return true

func _update_characters(character_ids: Array) -> void:
	for child in character_layer.get_children():
		child.queue_free()
	for char_id in character_ids:
		var tier = GameState.get_affinity_tier(char_id)
		var variant = GameState.character_variants.get(char_id, "nonbinary")
		var portrait_path = "res://images/characters/%s_%s_%s.png" % [char_id, variant, _get_default_expression(char_id, tier)]
		var char_sprite = TextureRect.new()
		char_sprite.custom_minimum_size = Vector2(300, 600)
		char_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(portrait_path):
			char_sprite.texture = load(portrait_path)
		char_sprite.set_meta("character_id", char_id)
		# Tap to interact
		char_sprite.gui_input.connect(func(event):
			if event is InputEventScreenTouch and event.pressed:
				_interact_with_character(char_id)
		)
		character_layer.add_child(char_sprite)

func _get_default_expression(char_id: String, tier: String) -> String:
	match tier:
		"guarded":   return "neutral"
		"opening":   return "thoughtful"
		"intimate":  return "happy"
		"beloved":   return "loving"
	return "neutral"

func _interact_with_character(char_id: String) -> void:
	if _is_in_dialogue:
		return
	# Load character-specific scene node based on chapter + affinity
	var chapter = GameState.current_chapter
	var tier = GameState.get_affinity_tier(char_id)
	var node_id = "ch%d_%s_%s_idle" % [chapter, char_id, tier]
	if DialogueSystem._dialogue_data.has(node_id):
		_is_in_dialogue = true
		dialogue_box.visible = true
		DialogueSystem.start_node(node_id)
	else:
		# Fallback: generic greeting
		var fallback = "ch%d_%s_idle" % [chapter, char_id]
		if DialogueSystem._dialogue_data.has(fallback):
			_is_in_dialogue = true
			dialogue_box.visible = true
			DialogueSystem.start_node(fallback)

func _on_tap_zone_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _is_in_dialogue:
			dialogue_box.handle_tap()

func _on_dialogue_ended(next_scene: String) -> void:
	_is_in_dialogue = false
	dialogue_box.visible = false
	# Save progress
	GameState.current_scene_id = ""
	GameState.save_game()
	if next_scene != "" and next_scene != "liminal_tower":
		SceneManager.go_to("%s.tscn" % next_scene)

func _on_flag_trigger(flag_name: String, value: Variant) -> void:
	if flag_name == "__card_draw_requested__":
		var data = value as Dictionary
		GameState.save_game()
		SceneManager.go_to("card_draw.tscn", data)

func _on_affinity_changed(character_id: String, new_value: int) -> void:
	# Brief flash indicating affinity change
	affinity_flash.visible = true
	var char_name = GameState.get_character_name(character_id)
	affinity_flash.text = char_name
	var tween = create_tween()
	tween.tween_property(affinity_flash, "modulate:a", 1.0, 0.1)
	tween.tween_interval(0.8)
	tween.tween_property(affinity_flash, "modulate:a", 0.0, 0.4)

func _on_menu_button_pressed() -> void:
	$PauseMenu.visible = true

func _on_home_button_pressed() -> void:
	GameState.save_game()
	SceneManager.go_to("home_screen.tscn")
