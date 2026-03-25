# RitualSpread.gd
# Minigame: Arrange cards into correct tarot spreads to unlock lore
# Earns Angel affinity — connected to the Judgement arc
extends MinigameBase

enum SpreadType { THREE_CARD, CELTIC_CROSS, HORSESHOE }

@onready var spread_positions = $SpreadPositions
@onready var hand_container = $HandContainer
@onready var spread_name_label = $HUD/SpreadName
@onready var instructions_label = $HUD/Instructions
@onready var lore_panel = $LorePanel
@onready var lore_text = $LorePanel/LoreText

var _current_spread: Dictionary = {}
var _hand_cards: Array = []
var _placed_cards: Dictionary = {}   # position_index -> card_id
var _drag_card: Control = null
var _drag_origin: Vector2 = Vector2.ZERO
var _active_spread_type: SpreadType = SpreadType.THREE_CARD

const SPREADS: Dictionary = {
	SpreadType.THREE_CARD: {
		"name": "The Three Truths",
		"description": "Past — Present — Future\nPlace cards left to right",
		"positions": 3,
		"position_labels": ["What Was", "What Is", "What Will Be"],
		"correct_sequences": [
			["hermit", "tower", "star"],
			["fool", "wheel", "world"],
			["death", "judgement", "star"]
		],
		"lore": "Three readings, three truths. The tower has stood at every crossroads of time. It was here before the fracture. It will be here after.",
		"affinity_reward": {"angel": 6}
	},
	SpreadType.HORSESHOE: {
		"name": "The Horseshoe",
		"description": "Seven cards, seven positions.\nArrange by meaning.",
		"positions": 7,
		"position_labels": ["Past", "Present", "Hidden", "Advice", "Others", "Hopes", "Outcome"],
		"correct_sequences": [],  # Any arrangement scores on meaning match
		"lore": "The Beloved arranged this spread on the last night. Each position held a fragment of a decision that could not be unmade. The cards remember the shape of that night.",
		"affinity_reward": {"angel": 12, "oracle": 6}
	}
}

func _setup() -> void:
	minigame_id = "ritual_spread"
	minigame_title = "The Ritual"
	max_score = 500
	affinity_rewards = {}  # Applied per spread
	_load_spread(SpreadType.THREE_CARD)

func _load_spread(spread_type: SpreadType) -> void:
	_active_spread_type = spread_type
	_current_spread = SPREADS[spread_type]
	_placed_cards.clear()
	spread_name_label.text = _current_spread.name
	instructions_label.text = _current_spread.description
	affinity_rewards = _current_spread.get("affinity_reward", {})
	_build_spread_positions()
	_deal_hand()

func _build_spread_positions() -> void:
	for child in spread_positions.get_children():
		child.queue_free()
	var count = _current_spread.positions
	var spread_width = spread_positions.size.x
	var slot_w = min(120.0, spread_width / count - 16)
	for i in count:
		var slot = _make_slot(i, slot_w)
		var x = (spread_width / count) * i + (spread_width / count - slot_w) / 2
		slot.position = Vector2(x, 20)
		spread_positions.add_child(slot)

func _make_slot(index: int, width: float) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(width, 160)
	container.set_meta("slot_index", index)
	container.set_meta("occupied", false)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.03, 0.15, 0.6)
	bg.border_color = Color(0.4, 0.2, 0.6, 0.4)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(4)

	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", bg)
	container.add_child(panel)

	var labels = _current_spread.get("position_labels", [])
	if index < labels.size():
		var lbl = Label.new()
		lbl.text = labels[index]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8))
		container.add_child(lbl)

	# Drop zone
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	return container

func _deal_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_hand_cards.clear()
	var count = _current_spread.positions
	for i in count:
		var card = CardManager.draw_card()
		var card_node = _make_draggable_card(card)
		hand_container.add_child(card_node)
		_hand_cards.append(card_node)

func _make_draggable_card(card: Dictionary) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(90, 130)
	container.set_meta("card_data", card)
	container.set_meta("in_hand", true)

	var tex = TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path = "res://images/cards/%s.png" % card.get("id", "back")
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	container.add_child(tex)

	# Touch drag
	container.gui_input.connect(func(event): _on_card_input(event, container))
	return container

func _on_card_input(event: InputEvent, card: Control) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_card = card
			_drag_origin = card.global_position
		else:
			_drop_card(event.position)

func _input(event: InputEvent) -> void:
	if _drag_card and event is InputEventScreenDrag:
		_drag_card.global_position = event.position - _drag_card.custom_minimum_size / 2

func _drop_card(drop_pos: Vector2) -> void:
	if not _drag_card:
		return
	# Find nearest empty slot
	var best_slot: Control = null
	var best_dist: float = 120.0
	for slot in spread_positions.get_children():
		if slot.get_meta("occupied", false):
			continue
		var dist = slot.global_position.distance_to(drop_pos)
		if dist < best_dist:
			best_dist = dist
			best_slot = slot

	if best_slot:
		_place_card_in_slot(_drag_card, best_slot)
	else:
		# Return to hand
		_drag_card.global_position = _drag_origin
	_drag_card = null
	_check_spread_complete()

func _place_card_in_slot(card: Control, slot: Control) -> void:
	var idx = slot.get_meta("slot_index")
	_placed_cards[idx] = card.get_meta("card_data").get("id", "")
	slot.set_meta("occupied", true)
	card.global_position = slot.global_position
	card.set_meta("in_hand", false)
	AudioManager.play_sfx("card_draw")

func _check_spread_complete() -> void:
	if _placed_cards.size() < _current_spread.positions:
		return
	# All slots filled — evaluate
	var score = _evaluate_placement()
	_show_lore()
	await get_tree().create_timer(3.0).timeout
	_on_complete(score)

func _evaluate_placement() -> int:
	var sequences = _current_spread.get("correct_sequences", [])
	if sequences.is_empty():
		# Horseshoe — score by narrative sense (simplified: always partial score)
		return int(max_score * 0.7)
	# Check if matches any correct sequence
	var placed_sequence = []
	for i in _current_spread.positions:
		placed_sequence.append(_placed_cards.get(i, ""))
	for seq in sequences:
		if placed_sequence == seq:
			return max_score
	# Partial credit — count correct positions
	var correct = 0
	for i in placed_sequence.size():
		if i < sequences[0].size() and placed_sequence[i] == sequences[0][i]:
			correct += 1
	return int(float(correct) / placed_sequence.size() * max_score)

func _show_lore() -> void:
	lore_panel.visible = true
	lore_text.text = ""
	var full_text = _current_spread.get("lore", "")
	var tween = create_tween()
	for i in full_text.length():
		tween.tween_callback(func(): lore_text.text = full_text.substr(0, lore_text.text.length() + 1))
		tween.tween_interval(0.03)
