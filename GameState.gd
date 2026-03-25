# GameState.gd
# Autoload singleton — manages all persistent game data
extends Node

# ── Player ────────────────────────────────────────────────────────────────────
var player_name: String = ""
var player_pronoun_subject: String = "they"   # they/she/he
var player_pronoun_object: String = "them"    # them/her/him
var player_pronoun_possessive: String = "their" # their/her/his
var player_avatar: Dictionary = {
	"skin_tone": 0,
	"hair_style": 0,
	"hair_color": 0,
	"eye_color": 0,
	"outfit": 0,
	"accessory": 0
}

# ── Story Progress ────────────────────────────────────────────────────────────
var current_chapter: int = 0
var current_scene_id: String = "prologue_01"
var cycle_number: int = 1
var completed_endings: Array[String] = []
var story_flags: Dictionary = {}  # tracks all story decisions

# ── Affinity ──────────────────────────────────────────────────────────────────
# Each character has a score 0-100
var affinity: Dictionary = {
	"angel":      0,   # Amira / Anael / Semir
	"oracle":     0,   # Hope / Sol / Emery
	"apprentice": 0    # Cara / Jacob / Hollow
}

# ── Character Gender Variants ─────────────────────────────────────────────────
# Randomised per playthrough, can be overridden
var character_variants: Dictionary = {
	"angel":      "feminine",   # feminine / masculine / nonbinary
	"oracle":     "masculine",
	"apprentice": "nonbinary"
}

# Character name lookup based on variant
const CHARACTER_NAMES: Dictionary = {
	"angel":      {"feminine": "Amira",  "masculine": "Anael",  "nonbinary": "Semir"},
	"oracle":     {"feminine": "Hope",   "masculine": "Sol",    "nonbinary": "Emery"},
	"apprentice": {"feminine": "Cara",   "masculine": "Jacob",  "nonbinary": "Hollow"}
}

# ── Tarot ─────────────────────────────────────────────────────────────────────
var cards_drawn: Array[String] = []          # history of all drawn cards
var cards_unlocked: Array[String] = []       # cards available in archive
var judgement_appearances: int = 0           # tracks The Judgement special card

# ── Save Slots ────────────────────────────────────────────────────────────────
const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 3
var current_slot: int = 0

# ── Signals ───────────────────────────────────────────────────────────────────
signal affinity_changed(character_id: String, new_value: int)
signal chapter_changed(new_chapter: int)
signal flag_set(flag_name: String, value: Variant)
signal cycle_started(cycle_num: int)

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	DirAccess.make_dir_absolute(SAVE_DIR)

# ── Name helpers ──────────────────────────────────────────────────────────────

func get_character_name(character_id: String) -> String:
	var variant = character_variants.get(character_id, "nonbinary")
	return CHARACTER_NAMES[character_id][variant]

func get_all_character_names() -> Dictionary:
	return {
		"angel":      get_character_name("angel"),
		"oracle":     get_character_name("oracle"),
		"apprentice": get_character_name("apprentice")
	}

# ── Affinity ──────────────────────────────────────────────────────────────────

func change_affinity(character_id: String, delta: int) -> void:
	if not affinity.has(character_id):
		push_warning("Unknown character_id: " + character_id)
		return
	affinity[character_id] = clamp(affinity[character_id] + delta, 0, 100)
	affinity_changed.emit(character_id, affinity[character_id])

func get_affinity_tier(character_id: String) -> String:
	var score = affinity.get(character_id, 0)
	if score <= 30:   return "guarded"
	if score <= 60:   return "opening"
	if score <= 80:   return "intimate"
	return "beloved"

# ── Story flags ───────────────────────────────────────────────────────────────

func set_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value
	flag_set.emit(flag_name, value)

func get_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_name, default_value)

func has_flag(flag_name: String) -> bool:
	return story_flags.has(flag_name) and story_flags[flag_name] != false

# ── Tarot ─────────────────────────────────────────────────────────────────────

func record_card_draw(card_id: String) -> void:
	cards_drawn.append(card_id)
	if not cards_unlocked.has(card_id):
		cards_unlocked.append(card_id)
	if card_id == "judgement" or card_id == "judgement_reversed":
		judgement_appearances += 1

# ── Pronouns ──────────────────────────────────────────────────────────────────

func set_pronouns(subject: String, object: String, possessive: String) -> void:
	player_pronoun_subject = subject
	player_pronoun_object = object
	player_pronoun_possessive = possessive

# Replaces {they}, {them}, {their}, {name} tokens in dialogue strings
func parse_dialogue(text: String) -> String:
	text = text.replace("{they}", player_pronoun_subject)
	text = text.replace("{them}", player_pronoun_object)
	text = text.replace("{their}", player_pronoun_possessive)
	text = text.replace("{name}", player_name)
	text = text.replace("{angel}", get_character_name("angel"))
	text = text.replace("{oracle}", get_character_name("oracle"))
	text = text.replace("{apprentice}", get_character_name("apprentice"))
	return text

# ── Randomise character variants ──────────────────────────────────────────────

func randomise_character_variants() -> void:
	var options = ["feminine", "masculine", "nonbinary"]
	for key in character_variants.keys():
		character_variants[key] = options[randi() % options.size()]

# ── Save / Load ───────────────────────────────────────────────────────────────

func save_game(slot: int = current_slot) -> bool:
	var save_data = {
		"player_name": player_name,
		"player_pronoun_subject": player_pronoun_subject,
		"player_pronoun_object": player_pronoun_object,
		"player_pronoun_possessive": player_pronoun_possessive,
		"player_avatar": player_avatar,
		"current_chapter": current_chapter,
		"current_scene_id": current_scene_id,
		"cycle_number": cycle_number,
		"completed_endings": completed_endings,
		"story_flags": story_flags,
		"affinity": affinity,
		"character_variants": character_variants,
		"cards_drawn": cards_drawn,
		"cards_unlocked": cards_unlocked,
		"judgement_appearances": judgement_appearances,
		"save_timestamp": Time.get_datetime_string_from_system()
	}
	var path = SAVE_DIR + "slot_%d.json" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Could not open save file: " + path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_game(slot: int = current_slot) -> bool:
	var path = SAVE_DIR + "slot_%d.json" % slot
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	var err = json.parse(file.read_as_text())
	file.close()
	if err != OK:
		push_error("Failed to parse save file")
		return false
	var data = json.get_data()
	player_name              = data.get("player_name", "")
	player_pronoun_subject   = data.get("player_pronoun_subject", "they")
	player_pronoun_object    = data.get("player_pronoun_object", "them")
	player_pronoun_possessive= data.get("player_pronoun_possessive", "their")
	player_avatar            = data.get("player_avatar", player_avatar)
	current_chapter          = data.get("current_chapter", 0)
	current_scene_id         = data.get("current_scene_id", "prologue_01")
	cycle_number             = data.get("cycle_number", 1)
	completed_endings        = data.get("completed_endings", [])
	story_flags              = data.get("story_flags", {})
	affinity                 = data.get("affinity", affinity)
	character_variants       = data.get("character_variants", character_variants)
	cards_drawn              = data.get("cards_drawn", [])
	cards_unlocked           = data.get("cards_unlocked", [])
	judgement_appearances    = data.get("judgement_appearances", 0)
	current_slot = slot
	return true

func get_save_metadata(slot: int) -> Dictionary:
	var path = SAVE_DIR + "slot_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	var err = json.parse(file.read_as_text())
	file.close()
	if err != OK:
		return {}
	var data = json.get_data()
	return {
		"player_name":    data.get("player_name", "Unknown"),
		"chapter":        data.get("current_chapter", 0),
		"cycle":          data.get("cycle_number", 1),
		"timestamp":      data.get("save_timestamp", ""),
		"exists":         true
	}

func delete_save(slot: int) -> void:
	var path = SAVE_DIR + "slot_%d.json" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ── New cycle ─────────────────────────────────────────────────────────────────

func start_new_cycle() -> void:
	cycle_number += 1
	current_chapter = 0
	current_scene_id = "prologue_01"
	# Affinity resets but cycle memory persists via flags
	for key in affinity.keys():
		affinity[key] = 0
	cards_drawn.clear()
	# Preserve: completed_endings, story_flags, cards_unlocked
	cycle_started.emit(cycle_number)
