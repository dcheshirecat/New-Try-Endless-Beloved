# CardManager.gd
# Autoload singleton — manages the tarot deck, draws, and card data
extends Node

# ── Card Data ─────────────────────────────────────────────────────────────────
const MAJOR_ARCANA: Array[Dictionary] = [
	{
		"id": "fool",
		"name": "The Fool",
		"number": 0,
		"character": "apprentice",
		"upright": "New beginnings, innocence, spontaneity, a free spirit",
		"reversed": "Holding back, recklessness, risk-taking without preparation",
		"story_note": "The Apprentice's card. Appears most often in their route.",
		"unlock_condition": ""
	},
	{
		"id": "magician",
		"name": "The Magician",
		"number": 1,
		"character": "oracle",
		"upright": "Willpower, desire, creation, manifestation",
		"reversed": "Trickery, illusions, out of touch with reality",
		"story_note": "The Oracle's card. Drawing it reversed triggers a hidden scene.",
		"unlock_condition": ""
	},
	{
		"id": "high_priestess",
		"name": "The High Priestess",
		"number": 2,
		"character": "",
		"upright": "Intuition, sacred knowledge, divine feminine, the subconscious",
		"reversed": "Secrets, disconnected from intuition, withdrawal",
		"story_note": "Appears in cycle 2+ only. Reveals Oracle knew the player before.",
		"unlock_condition": "cycle_2"
	},
	{
		"id": "empress",
		"name": "The Empress",
		"number": 3,
		"character": "",
		"upright": "Femininity, beauty, nature, nurturing, abundance",
		"reversed": "Creative block, dependence on others",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "emperor",
		"name": "The Emperor",
		"number": 4,
		"character": "",
		"upright": "Authority, establishment, structure, a father figure",
		"reversed": "Domination, excessive control, rigidity, stubbornness",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "hierophant",
		"name": "The Hierophant",
		"number": 5,
		"character": "",
		"upright": "Spiritual wisdom, religious beliefs, conformity, tradition",
		"reversed": "Personal beliefs, freedom, challenging the status quo",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "lovers",
		"name": "The Lovers",
		"number": 6,
		"character": "",
		"upright": "Love, harmony, relationships, values alignment, choices",
		"reversed": "Self-love, disharmony, imbalance, misaligned values",
		"story_note": "Only drawable once affinity with any character reaches 61+.",
		"unlock_condition": "affinity_61"
	},
	{
		"id": "chariot",
		"name": "The Chariot",
		"number": 7,
		"character": "",
		"upright": "Control, willpower, success, action, determination",
		"reversed": "Self-discipline, opposition, lack of direction",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "strength",
		"name": "Strength",
		"number": 8,
		"character": "",
		"upright": "Strength, courage, persuasion, influence, compassion",
		"reversed": "Inner strength, self-doubt, low energy, raw emotion",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "hermit",
		"name": "The Hermit",
		"number": 9,
		"character": "",
		"upright": "Soul-searching, introspection, being alone, inner guidance",
		"reversed": "Isolation, loneliness, withdrawal",
		"story_note": "Triggers the player's past memory fragment in Act I.",
		"unlock_condition": ""
	},
	{
		"id": "wheel",
		"name": "Wheel of Fortune",
		"number": 10,
		"character": "",
		"upright": "Good luck, karma, life cycles, destiny, a turning point",
		"reversed": "Bad luck, resistance to change, breaking cycles",
		"story_note": "The Cycle card. Appears differently on repeat playthroughs.",
		"unlock_condition": ""
	},
	{
		"id": "justice",
		"name": "Justice",
		"number": 11,
		"character": "",
		"upright": "Justice, fairness, truth, cause and effect, law",
		"reversed": "Unfairness, lack of accountability, dishonesty",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "hanged_man",
		"name": "The Hanged Man",
		"number": 12,
		"character": "",
		"upright": "Pause, surrender, letting go, new perspectives",
		"reversed": "Delays, resistance, stalling, indecision",
		"story_note": "Drawing this locks the player out of one ending branch.",
		"unlock_condition": ""
	},
	{
		"id": "death",
		"name": "Death",
		"number": 13,
		"character": "",
		"upright": "Endings, change, transformation, transition",
		"reversed": "Resistance to change, personal transformation, inner purging",
		"story_note": "Cannot be drawn in Act I. Always triggers special dialogue.",
		"unlock_condition": "chapter_4"
	},
	{
		"id": "temperance",
		"name": "Temperance",
		"number": 14,
		"character": "",
		"upright": "Balance, moderation, patience, purpose, meaning",
		"reversed": "Imbalance, excess, self-healing, re-alignment",
		"story_note": "",
		"unlock_condition": ""
	},
	{
		"id": "devil",
		"name": "The Devil",
		"number": 15,
		"character": "",
		"upright": "Shadow self, attachment, addiction, restriction, sexuality",
		"reversed": "Releasing limiting beliefs, exploring dark thoughts, detachment",
		"story_note": "Unlocks a hidden scene with the Angel about what they lost.",
		"unlock_condition": "affinity_angel_40"
	},
	{
		"id": "tower",
		"name": "The Tower",
		"number": 16,
		"character": "",
		"upright": "Sudden change, upheaval, chaos, revelation, awakening",
		"reversed": "Personal transformation, fear of change, averting disaster",
		"story_note": "Mid-Act II forced draw. Cannot be reversed.",
		"unlock_condition": "chapter_5_trigger"
	},
	{
		"id": "star",
		"name": "The Star",
		"number": 17,
		"character": "",
		"upright": "Hope, faith, purpose, renewal, spirituality",
		"reversed": "Lack of faith, despair, self-trust, disconnection",
		"story_note": "Only available after the Tower draw. A moment of relief.",
		"unlock_condition": "after_tower"
	},
	{
		"id": "moon",
		"name": "The Moon",
		"number": 18,
		"character": "",
		"upright": "Illusion, fear, the subconscious, anxiety, confusion",
		"reversed": "Release of fear, repressed emotion, inner confusion",
		"story_note": "Triggers the Apprentice nightmare sequence.",
		"unlock_condition": ""
	},
	{
		"id": "sun",
		"name": "The Sun",
		"number": 19,
		"character": "",
		"upright": "Positivity, fun, warmth, success, vitality",
		"reversed": "Inner child, feeling down, overly optimistic",
		"story_note": "One of only two cards that can shift affinity down if drawn at wrong time.",
		"unlock_condition": ""
	},
	{
		"id": "judgement",
		"name": "Judgement",
		"number": 20,
		"character": "angel",
		"upright": "Judgement, rebirth, inner calling, absolution",
		"reversed": "Self-doubt, inner critic, ignoring the call",
		"story_note": "THE key card. Appears exactly 3 times. Behaviour changes each time.",
		"unlock_condition": "special"
	},
	{
		"id": "world",
		"name": "The World",
		"number": 21,
		"character": "",
		"upright": "Completion, integration, accomplishment, travel",
		"reversed": "Seeking personal closure, short-cuts, delays",
		"story_note": "Only drawable in Act III. Signals the player is close to an ending.",
		"unlock_condition": "chapter_8"
	},
]

var _deck: Array[String] = []
var _discard: Array[String] = []

# ── Signals ───────────────────────────────────────────────────────────────────
signal card_drawn(card_data: Dictionary, is_reversed: bool)
signal deck_shuffled

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	build_deck()

func build_deck() -> void:
	_deck.clear()
	_discard.clear()
	for card in MAJOR_ARCANA:
		if _is_card_available(card):
			_deck.append(card.id)
	shuffle_deck()

func _is_card_available(card: Dictionary) -> bool:
	var cond = card.get("unlock_condition", "")
	if cond == "":
		return true
	if cond == "special":
		return false  # Judgement is injected by story events
	if cond == "cycle_2":
		return GameState.cycle_number >= 2
	if cond == "chapter_4":
		return GameState.current_chapter >= 4
	if cond == "chapter_5_trigger":
		return false  # Injected by story
	if cond == "after_tower":
		return GameState.has_flag("tower_drawn")
	if cond == "chapter_8":
		return GameState.current_chapter >= 8
	if cond == "affinity_61":
		for key in GameState.affinity:
			if GameState.affinity[key] >= 61:
				return true
		return false
	if cond == "affinity_angel_40":
		return GameState.affinity.get("angel", 0) >= 40
	return true

func shuffle_deck() -> void:
	_deck.shuffle()
	deck_shuffled.emit()

func draw_card(forced_id: String = "", is_reversed: bool = false) -> Dictionary:
	var card_id: String
	if forced_id != "":
		card_id = forced_id
		_deck.erase(card_id)
	elif _deck.is_empty():
		# Reshuffle discard into deck
		_deck = _discard.duplicate()
		_discard.clear()
		_deck.shuffle()
		if _deck.is_empty():
			return {}
		card_id = _deck.pop_front()
	else:
		card_id = _deck.pop_front()

	_discard.append(card_id)
	var card_data = get_card_data(card_id)
	GameState.record_card_draw(card_id + ("_reversed" if is_reversed else ""))
	AudioManager.play_sfx("card_draw")
	card_drawn.emit(card_data, is_reversed)
	return card_data

func get_card_data(card_id: String) -> Dictionary:
	for card in MAJOR_ARCANA:
		if card.id == card_id:
			return card
	return {}

func get_all_unlocked_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card_id in GameState.cards_unlocked:
		var id = card_id.replace("_reversed", "")
		var data = get_card_data(id)
		if not data.is_empty() and not result.has(data):
			result.append(data)
	return result

func inject_judgement() -> void:
	# Force The Judgement card as the next draw
	_deck.push_front("judgement")
