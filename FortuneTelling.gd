# FortuneTelling.gd
# Minigame: Read tarot cards for Liminal wanderers — earns Apprentice affinity
# Player draws 3 cards for an NPC and picks the interpretation
extends MinigameBase

const READINGS_PER_SESSION: int = 3

@onready var npc_label = $NPCPanel/NPCName
@onready var npc_question = $NPCPanel/NPCQuestion
@onready var cards_row = $CardsRow
@onready var interpretation_choices = $InterpretationChoices
@onready var result_label = $ResultLabel
@onready var score_label = $HUD/ScoreLabel
@onready var reading_count_label = $HUD/ReadingCountLabel

var _current_reading: int = 0
var _reading_score: int = 0
var _drawn_cards: Array[Dictionary] = []
var _current_npc: Dictionary = {}

const NPCS: Array[Dictionary] = [
	{
		"name": "The Wanderer",
		"question": "Will I ever find my way back?",
		"ideal_cards": ["star", "wheel", "fool"],
		"interpretations": [
			{"text": "The path home is not behind you. It is ahead, but changed.", "correct": true},
			{"text": "You are already lost. Accept it.", "correct": false},
			{"text": "The journey is the destination.", "correct": false},
			{"text": "Someone you love will guide you.", "correct": false}
		]
	},
	{
		"name": "The Grieving One",
		"question": "When does the pain stop?",
		"ideal_cards": ["death", "temperance", "star"],
		"interpretations": [
			{"text": "Pain transforms. It does not stop — it becomes something else.", "correct": true},
			{"text": "It stops when you decide it stops.", "correct": false},
			{"text": "There is someone waiting who can help.", "correct": false},
			{"text": "The cards cannot answer this. Some things are beyond them.", "correct": false}
		]
	},
	{
		"name": "The Doubtful One",
		"question": "Did I make the right choice?",
		"ideal_cards": ["judgement", "justice", "hermit"],
		"interpretations": [
			{"text": "The right choice was always the one you could live with.", "correct": true},
			{"text": "No. But it's too late to change it.", "correct": false},
			{"text": "Yes. The cards confirm it.", "correct": false},
			{"text": "There are no right choices here. Only true ones.", "correct": false}
		]
	},
	{
		"name": "The Hopeful One",
		"question": "Is there someone out there for me?",
		"ideal_cards": ["lovers", "empress", "two_of_cups"],
		"interpretations": [
			{"text": "Yes. But they are waiting for you to be ready.", "correct": true},
			{"text": "Love is not written in the cards. You write it yourself.", "correct": false},
			{"text": "The cards show a choice coming. Both paths have love.", "correct": false},
			{"text": "Someone close already cares more than you know.", "correct": false}
		]
	}
]

func _setup() -> void:
	minigame_id = "fortune_telling"
	minigame_title = "Voices in the Dark"
	max_score = 300
	affinity_rewards = { "apprentice": 10, "oracle": 5 }
	_start_reading()

func _start_reading() -> void:
	if _current_reading >= READINGS_PER_SESSION:
		_on_complete(_reading_score)
		return
	_drawn_cards.clear()
	_current_npc = NPCS[randi() % NPCS.size()]
	reading_count_label.text = "Reading %d / %d" % [_current_reading + 1, READINGS_PER_SESSION]
	npc_label.text = _current_npc.name
	npc_question.text = '"%s"' % _current_npc.question
	result_label.visible = false
	_clear_choices()
	_draw_three_cards()

func _draw_three_cards() -> void:
	for child in cards_row.get_children():
		child.queue_free()
	_drawn_cards.clear()

	for i in 3:
		var card = CardManager.draw_card()
		_drawn_cards.append(card)
		var card_rect = _make_card_display(card, i)
		cards_row.add_child(card_rect)
		# Staggered entrance
		card_rect.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_interval(i * 0.3)
		tween.tween_property(card_rect, "modulate:a", 1.0, 0.4)
		AudioManager.play_sfx("card_draw")

	await get_tree().create_timer(1.2).timeout
	_show_interpretations()

func _make_card_display(card: Dictionary, position: int) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(120, 180)
	var tex = TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path = "res://images/cards/%s.png" % card.get("id", "back")
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	var name_label = Label.new()
	name_label.text = card.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.add_child(tex)
	container.add_child(name_label)
	return container

func _show_interpretations() -> void:
	_clear_choices()
	# Shuffle interpretations
	var choices = _current_npc.interpretations.duplicate()
	choices.shuffle()
	for i in choices.size():
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice.text
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		var capture_correct = choice.correct
		btn.pressed.connect(func(): _on_interpretation_chosen(capture_correct, btn, choices))
		interpretation_choices.add_child(btn)

func _on_interpretation_chosen(correct: bool, chosen_btn: Button, all_choices: Array) -> void:
	# Disable all buttons
	for child in interpretation_choices.get_children():
		child.disabled = true
	if correct:
		chosen_btn.modulate = Color(0.6, 1.0, 0.6)
		_reading_score += 100
		result_label.text = "The wanderer nods. Something settles in their eyes."
		AudioManager.play_sfx("affinity_up")
	else:
		chosen_btn.modulate = Color(1.0, 0.5, 0.5)
		result_label.text = "The wanderer looks away. It wasn't quite right."
		AudioManager.play_sfx("menu_back")
	result_label.visible = true
	score_label.text = "Score: %d" % _reading_score
	_current_reading += 1
	await get_tree().create_timer(2.0).timeout
	_start_reading()

func _clear_choices() -> void:
	for child in interpretation_choices.get_children():
		child.queue_free()
