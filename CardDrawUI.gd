# CardDrawUI.gd
# The tarot card draw scene — handles shuffle animation, draw, and orientation
extends Control

enum DrawState { IDLE, SHUFFLING, DRAWING, REVEALING, ORIENTING, COMPLETE }

@onready var deck_sprite = $DeckSprite
@onready var card_front = $CardFront
@onready var card_back = $CardBack
@onready var card_name_label = $CardInfo/CardName
@onready var card_meaning_label = $CardInfo/CardMeaning
@onready var card_note_label = $CardInfo/CardNote
@onready var swipe_hint = $SwipeHint
@onready var glow_effect = $GlowEffect
@onready var particles = $CardParticles
@onready var orientation_label = $OrientationLabel
@onready var confirm_button = $ConfirmButton

var _state: DrawState = DrawState.IDLE
var _current_card: Dictionary = {}
var _is_reversed: bool = false
var _forced_card_id: String = ""
var _next_node: String = ""

# Touch tracking
var _touch_start: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false
const SWIPE_THRESHOLD: float = 80.0
const TAP_MAX_DISTANCE: float = 20.0
const TAP_MAX_TIME: float = 0.3

# Card flip animation
var _flip_progress: float = 0.0
var _is_flipping: bool = false

signal draw_complete(card_data: Dictionary, is_reversed: bool)

func _ready() -> void:
	card_front.visible = false
	card_back.visible = true
	swipe_hint.visible = false
	confirm_button.visible = false
	card_name_label.visible = false
	card_meaning_label.visible = false
	_state = DrawState.IDLE
	AudioManager.play_music("reading")
	_animate_idle_deck()

func receive_data(data: Dictionary) -> void:
	_forced_card_id = data.get("forced", "")
	_next_node = data.get("next", "")

# ── Touch handling ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
			_is_touching = true
		else:
			if _is_touching:
				var delta = event.position - _touch_start
				var elapsed = Time.get_ticks_msec() / 1000.0 - _touch_start_time
				_handle_release(delta, elapsed)
			_is_touching = false

func _handle_release(delta: Vector2, elapsed: float) -> void:
	var dist = delta.length()

	# Tap
	if dist < TAP_MAX_DISTANCE and elapsed < TAP_MAX_TIME:
		_handle_tap()
		return

	# Swipe
	if dist >= SWIPE_THRESHOLD:
		var angle = atan2(delta.y, delta.x)
		if abs(delta.x) > abs(delta.y):
			if delta.x > 0:
				_handle_swipe_right()
			else:
				_handle_swipe_left()
		else:
			if delta.y < 0:
				_handle_swipe_up()
			else:
				_handle_swipe_down()

func _handle_tap() -> void:
	match _state:
		DrawState.IDLE:
			_start_draw()
		DrawState.REVEALING:
			# Skip to full reveal
			_complete_reveal()
		DrawState.COMPLETE:
			_confirm_draw()

func _handle_swipe_left() -> void:
	if _state == DrawState.IDLE:
		_shuffle_animation()
	elif _state == DrawState.ORIENTING:
		# Cancel orientation
		pass

func _handle_swipe_right() -> void:
	if _state == DrawState.IDLE:
		_shuffle_animation()

func _handle_swipe_up() -> void:
	if _state == DrawState.ORIENTING:
		_set_orientation(false)  # Upright

func _handle_swipe_down() -> void:
	if _state == DrawState.ORIENTING:
		_set_orientation(true)  # Reversed

# ── Animations ────────────────────────────────────────────────────────────────

func _animate_idle_deck() -> void:
	# Gentle floating animation on the deck
	var tween = create_tween().set_loops()
	tween.tween_property(deck_sprite, "position:y", deck_sprite.position.y - 8, 1.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(deck_sprite, "position:y", deck_sprite.position.y, 1.2).set_ease(Tween.EASE_IN_OUT)

func _shuffle_animation() -> void:
	if _state != DrawState.IDLE:
		return
	_state = DrawState.SHUFFLING
	AudioManager.play_sfx("card_shuffle")
	var tween = create_tween()
	# Rapid small rotations to simulate shuffle
	for i in 6:
		var dir = 1 if i % 2 == 0 else -1
		tween.tween_property(deck_sprite, "rotation", deg_to_rad(dir * 8), 0.06)
	tween.tween_property(deck_sprite, "rotation", 0.0, 0.1)
	await tween.finished
	_state = DrawState.IDLE
	swipe_hint.text = "Tap to draw"
	swipe_hint.visible = true

func _start_draw() -> void:
	_state = DrawState.DRAWING
	swipe_hint.visible = false
	AudioManager.play_sfx("card_flip")

	# Draw from manager
	_current_card = CardManager.draw_card(_forced_card_id)
	if _current_card.is_empty():
		push_error("No card drawn")
		return

	# Animate card rising from deck
	card_back.position = deck_sprite.position
	card_back.visible = true
	var tween = create_tween()
	tween.tween_property(card_back, "position:y", deck_sprite.position.y - 200, 0.4).set_ease(Tween.EASE_OUT)
	await tween.finished

	_state = DrawState.REVEALING
	_animate_card_flip()

func _animate_card_flip() -> void:
	_is_flipping = true
	var tween = create_tween()
	# Scale X to 0 (fold)
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	await tween.finished
	# Switch to front
	card_back.visible = false
	card_front.visible = true
	_load_card_texture()
	# Scale X back to 1 (unfold)
	card_front.scale.x = 0.0
	var tween2 = create_tween()
	tween2.tween_property(card_front, "scale:x", 1.0, 0.2)
	await tween2.finished
	_is_flipping = false
	_begin_reveal()

func _load_card_texture() -> void:
	var card_path = "res://images/cards/" + _current_card.get("id", "back") + ".png"
	if ResourceLoader.exists(card_path):
		card_front.texture = load(card_path)
	else:
		# Placeholder: generate a simple card visual
		card_front.texture = null

func _begin_reveal() -> void:
	# Show glow
	glow_effect.visible = true
	particles.emitting = true

	# Reveal card name with typewriter
	card_name_label.visible = true
	card_name_label.text = ""
	var full_name = _current_card.get("name", "")
	var tween = create_tween()
	for i in full_name.length():
		tween.tween_callback(func(): card_name_label.text = full_name.substr(0, card_name_label.text.length() + 1))
		tween.tween_interval(0.05)
	await tween.finished

	# Show orientation choice
	_state = DrawState.ORIENTING
	swipe_hint.text = "Swipe UP for upright\nSwipe DOWN for reversed"
	swipe_hint.visible = true
	orientation_label.visible = true

func _complete_reveal() -> void:
	card_name_label.text = _current_card.get("name", "")
	_state = DrawState.ORIENTING
	swipe_hint.text = "Swipe UP for upright\nSwipe DOWN for reversed"
	swipe_hint.visible = true

func _set_orientation(reversed: bool) -> void:
	_is_reversed = reversed
	_state = DrawState.COMPLETE
	swipe_hint.visible = false
	orientation_label.visible = false

	# Flip card if reversed
	if reversed:
		var tween = create_tween()
		tween.tween_property(card_front, "rotation", deg_to_rad(180), 0.3)

	# Show meaning
	var meaning_key = "reversed" if reversed else "upright"
	var meaning = _current_card.get(meaning_key, "")
	card_meaning_label.visible = true
	card_meaning_label.text = ("↓ REVERSED — " if reversed else "↑ UPRIGHT — ") + meaning

	# Story note
	var note = _current_card.get("story_note", "")
	if note != "":
		card_note_label.visible = true
		card_note_label.text = note

	confirm_button.visible = true
	AudioManager.play_sfx("affinity_up")

func _confirm_draw() -> void:
	if _state != DrawState.COMPLETE:
		return
	draw_complete.emit(_current_card, _is_reversed)
	# Return to dialogue
	if _next_node != "":
		DialogueSystem.start_node(_next_node)
	SceneManager.go_to("liminal_tower.tscn")

func _on_confirm_button_pressed() -> void:
	_confirm_draw()
