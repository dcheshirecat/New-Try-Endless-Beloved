# CardMemoryGame.gd
# Minigame: Match pairs of tarot cards — earns Oracle affinity
extends MinigameBase

const GRID_COLS: int = 4
const GRID_ROWS: int = 4
const TOTAL_PAIRS: int = (GRID_COLS * GRID_ROWS) / 2

@onready var grid_container = $GridContainer
@onready var timer_label = $HUD/TimerLabel
@onready var pairs_label = $HUD/PairsLabel
@onready var moves_label = $HUD/MovesLabel

var _cards: Array = []        # All card nodes
var _flipped: Array = []      # Currently face-up (max 2)
var _matched: Array = []      # Matched card ids
var _moves: int = 0
var _pairs_found: int = 0
var _time_elapsed: float = 0.0
var _can_flip: bool = true
var _game_active: bool = false

# Card IDs to use (subset of major arcana for variety)
const POOL = [
	"fool","magician","high_priestess","empress",
	"emperor","hierophant","lovers","chariot",
	"strength","hermit","wheel","justice",
	"hanged_man","death","temperance","devil",
	"tower","star","moon","sun","judgement","world"
]

func _setup() -> void:
	minigame_id = "card_memory"
	minigame_title = "The Memory of Cards"
	max_score = 1000
	affinity_rewards = { "oracle": 8 }
	_build_grid()
	_game_active = true

func _build_grid() -> void:
	# Pick random pairs
	var pool_copy = POOL.duplicate()
	pool_copy.shuffle()
	var selected = pool_copy.slice(0, TOTAL_PAIRS)
	var card_ids = selected + selected  # duplicate for pairs
	card_ids.shuffle()

	grid_container.columns = GRID_COLS

	for i in card_ids.size():
		var card = _make_card(card_ids[i], i)
		grid_container.add_child(card)
		_cards.append(card)

func _make_card(card_id: String, index: int) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(140, 200)

	var btn = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.name = "CardButton"

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.04, 0.2)
	style.border_color = Color(0.5, 0.3, 0.8, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var front_texture = TextureRect.new()
	front_texture.name = "FrontTexture"
	front_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	front_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	front_texture.visible = false
	var card_path = "res://images/cards/%s.png" % card_id
	if ResourceLoader.exists(card_path):
		front_texture.texture = load(card_path)

	var back_texture = TextureRect.new()
	back_texture.name = "BackTexture"
	back_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var back_path = "res://images/cards/back.png"
	if ResourceLoader.exists(back_path):
		back_texture.texture = load(back_path)

	container.add_child(btn)
	container.add_child(front_texture)
	container.add_child(back_texture)

	container.set_meta("card_id", card_id)
	container.set_meta("index", index)
	container.set_meta("is_flipped", false)
	container.set_meta("is_matched", false)

	var capture_container = container
	btn.pressed.connect(func(): _on_card_pressed(capture_container))

	return container

func _process(delta: float) -> void:
	if not _game_active:
		return
	_time_elapsed += delta
	timer_label.text = "%.1f s" % _time_elapsed
	pairs_label.text = "%d / %d pairs" % [_pairs_found, TOTAL_PAIRS]
	moves_label.text = "%d moves" % _moves

func _on_card_pressed(card: Control) -> void:
	if not _can_flip:
		return
	if card.get_meta("is_flipped") or card.get_meta("is_matched"):
		return
	if _flipped.size() >= 2:
		return

	_flip_card_up(card)
	_flipped.append(card)
	AudioManager.play_sfx("card_flip")

	if _flipped.size() == 2:
		_moves += 1
		_can_flip = false
		await get_tree().create_timer(0.8).timeout
		_check_match()

func _flip_card_up(card: Control) -> void:
	card.set_meta("is_flipped", true)
	card.get_node("FrontTexture").visible = true
	card.get_node("BackTexture").visible = false
	# Flip animation
	var tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, 0.1)
	tween.tween_callback(func(): card.get_node("FrontTexture").visible = true; card.get_node("BackTexture").visible = false)
	tween.tween_property(card, "scale:x", 1.0, 0.1)

func _flip_card_down(card: Control) -> void:
	card.set_meta("is_flipped", false)
	var tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, 0.1)
	tween.tween_callback(func(): card.get_node("FrontTexture").visible = false; card.get_node("BackTexture").visible = true)
	tween.tween_property(card, "scale:x", 1.0, 0.1)

func _check_match() -> void:
	var a = _flipped[0]
	var b = _flipped[1]
	if a.get_meta("card_id") == b.get_meta("card_id"):
		# Match!
		a.set_meta("is_matched", true)
		b.set_meta("is_matched", true)
		_matched.append(a.get_meta("card_id"))
		_pairs_found += 1
		AudioManager.play_sfx("affinity_up")
		# Glow matched cards
		for card in [a, b]:
			var tween = create_tween()
			tween.tween_property(card, "modulate", Color(1.4, 1.2, 1.6), 0.3)
		if _pairs_found >= TOTAL_PAIRS:
			_game_active = false
			_calculate_score()
	else:
		# No match — flip back
		_flip_card_down(a)
		_flip_card_down(b)
		AudioManager.play_sfx("menu_back")
	_flipped.clear()
	_can_flip = true

func _calculate_score() -> void:
	# Score based on time and moves
	var time_bonus = max(0, 500 - int(_time_elapsed * 5))
	var move_bonus = max(0, 500 - (_moves - TOTAL_PAIRS) * 20)
	var final_score = clamp(time_bonus + move_bonus, 0, max_score)
	_on_complete(final_score)
