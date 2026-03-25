# DialogueSystem.gd
# Autoload singleton — parses and delivers story dialogue from JSON
extends Node

const STORY_DIR: String = "res://story/"
const TYPEWRITER_SPEED: float = 0.03  # seconds per character
const FAST_TYPEWRITER_SPEED: float = 0.005

var _current_dialogue: Dictionary = {}
var _current_node_id: String = ""
var _dialogue_data: Dictionary = {}
var _is_typing: bool = false
var _skip_requested: bool = false
var _typewriter_speed: float = TYPEWRITER_SPEED

# ── Signals ───────────────────────────────────────────────────────────────────
signal dialogue_started(node_id: String)
signal line_started(speaker: String, text: String, portrait: String)
signal line_complete
signal choice_presented(choices: Array)
signal choice_made(choice_index: int)
signal dialogue_ended(next_node: String)
signal affinity_trigger(character_id: String, delta: int)
signal flag_trigger(flag_name: String, value: Variant)

# ─────────────────────────────────────────────────────────────────────────────

func load_chapter(chapter_id: String) -> bool:
	var path = STORY_DIR + chapter_id + ".json"
	if not FileAccess.file_exists(path):
		push_error("Chapter file not found: " + path)
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.read_as_text())
	file.close()
	if err != OK:
		push_error("Failed to parse chapter: " + chapter_id)
		return false
	_dialogue_data = json.get_data()
	return true

func start_node(node_id: String) -> void:
	if not _dialogue_data.has(node_id):
		push_error("Node not found: " + node_id)
		return
	_current_node_id = node_id
	_current_dialogue = _dialogue_data[node_id]
	dialogue_started.emit(node_id)
	_process_node()

func _process_node() -> void:
	var node = _current_dialogue
	var node_type = node.get("type", "line")

	match node_type:
		"line":
			_deliver_line(node)
		"choice":
			_present_choices(node)
		"branch":
			_evaluate_branch(node)
		"affinity":
			_apply_affinity(node)
			_advance_to(node.get("next", ""))
		"flag":
			_apply_flag(node)
			_advance_to(node.get("next", ""))
		"card_draw":
			_trigger_card_draw(node)
		"end":
			dialogue_ended.emit(node.get("next_scene", ""))

func _deliver_line(node: Dictionary) -> void:
	var speaker = node.get("speaker", "")
	var raw_text = node.get("text", "")
	var text = GameState.parse_dialogue(raw_text)
	var portrait = node.get("portrait", "neutral")
	var music_cue = node.get("music", "")
	var sfx_cue = node.get("sfx", "")

	if music_cue != "":
		AudioManager.play_music(music_cue)
	if sfx_cue != "":
		AudioManager.play_sfx(sfx_cue)

	line_started.emit(speaker, text, portrait)
	_is_typing = true
	_skip_requested = false

func request_advance() -> void:
	if _is_typing:
		_skip_requested = true
		return
	# Move to next node
	var next = _current_dialogue.get("next", "")
	_advance_to(next)

func on_typewriter_complete() -> void:
	_is_typing = false
	line_complete.emit()
	# Check for auto-advance
	if _current_dialogue.get("auto_advance", false):
		var delay = _current_dialogue.get("delay", 1.5)
		await get_tree().create_timer(delay).timeout
		request_advance()

func _present_choices(node: Dictionary) -> void:
	var raw_choices = node.get("choices", [])
	var available_choices: Array = []
	for choice in raw_choices:
		# Check if this choice has a condition
		var condition = choice.get("condition", "")
		if condition == "" or _evaluate_condition(condition):
			available_choices.append({
				"text": GameState.parse_dialogue(choice.get("text", "")),
				"next": choice.get("next", ""),
				"affinity": choice.get("affinity", {}),
				"flags": choice.get("flags", {})
			})
	choice_presented.emit(available_choices)

func make_choice(choice_index: int, choices: Array) -> void:
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice = choices[choice_index]
	choice_made.emit(choice_index)
	# Apply affinity changes
	for char_id in choice.get("affinity", {}).keys():
		var delta = choice["affinity"][char_id]
		GameState.change_affinity(char_id, delta)
		affinity_trigger.emit(char_id, delta)
	# Apply flags
	for flag_name in choice.get("flags", {}).keys():
		GameState.set_flag(flag_name, choice["flags"][flag_name])
	AudioManager.play_sfx("menu_select")
	_advance_to(choice.get("next", ""))

func _evaluate_branch(node: Dictionary) -> void:
	var branches = node.get("branches", [])
	for branch in branches:
		var condition = branch.get("condition", "")
		if condition == "" or _evaluate_condition(condition):
			_advance_to(branch.get("next", ""))
			return
	# Fallback
	_advance_to(node.get("default", ""))

func _evaluate_condition(condition: String) -> bool:
	# Simple condition evaluator
	# Format: "flag:flag_name", "affinity:char_id:min", "chapter:N", "cycle:N"
	var parts = condition.split(":")
	match parts[0]:
		"flag":
			return GameState.has_flag(parts[1])
		"affinity":
			var char_id = parts[1]
			var min_val = int(parts[2])
			return GameState.affinity.get(char_id, 0) >= min_val
		"chapter":
			return GameState.current_chapter >= int(parts[1])
		"cycle":
			return GameState.cycle_number >= int(parts[1])
		"tier":
			return GameState.get_affinity_tier(parts[1]) == parts[2]
		"not_flag":
			return not GameState.has_flag(parts[1])
	return false

func _apply_affinity(node: Dictionary) -> void:
	var changes = node.get("changes", {})
	for char_id in changes.keys():
		GameState.change_affinity(char_id, changes[char_id])
		affinity_trigger.emit(char_id, changes[char_id])

func _apply_flag(node: Dictionary) -> void:
	var flag_name = node.get("name", "")
	var value = node.get("value", true)
	if flag_name != "":
		GameState.set_flag(flag_name, value)
		flag_trigger.emit(flag_name, value)

func _trigger_card_draw(node: Dictionary) -> void:
	var forced_id = node.get("forced_card", "")
	# Signal the UI to open the card draw scene
	# The card draw scene will call back when complete
	flag_trigger.emit("__card_draw_requested__", {
		"forced": forced_id,
		"next": node.get("next", "")
	})

func _advance_to(node_id: String) -> void:
	if node_id == "" or node_id == "END":
		dialogue_ended.emit("")
		return
	if not _dialogue_data.has(node_id):
		push_error("Cannot advance to unknown node: " + node_id)
		return
	_current_node_id = node_id
	_current_dialogue = _dialogue_data[node_id]
	_process_node()

func should_skip_typing() -> bool:
	return _skip_requested

func set_fast_mode(fast: bool) -> void:
	_typewriter_speed = FAST_TYPEWRITER_SPEED if fast else TYPEWRITER_SPEED

func get_typewriter_speed() -> float:
	return _typewriter_speed
