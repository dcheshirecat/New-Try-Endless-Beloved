# Journal.gd
# The player's journal — tracks story progress, character notes, lore
extends Control

enum Tab { CHARACTERS, CARDS, LORE, ENDINGS }

@onready var tab_bar = $TabBar
@onready var content_panel = $ContentPanel
@onready var back_button = $BackButton

var _active_tab: Tab = Tab.CHARACTERS

func _ready() -> void:
	AudioManager.play_music("liminal")
	_build_tab_bar()
	_show_tab(Tab.CHARACTERS)

func _build_tab_bar() -> void:
	for child in tab_bar.get_children():
		child.queue_free()
	var tabs = ["Characters", "Cards", "Lore", "Endings"]
	for i in tabs.size():
		var btn = Button.new()
		btn.text = tabs[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		var capture_i = i
		btn.pressed.connect(func(): _show_tab(capture_i as Tab))
		tab_bar.add_child(btn)

func _show_tab(tab: Tab) -> void:
	_active_tab = tab
	# Update button states
	var btns = tab_bar.get_children()
	for i in btns.size():
		if btns[i] is Button:
			btns[i].button_pressed = (i == tab)
	# Clear content
	for child in content_panel.get_children():
		child.queue_free()
	match tab:
		Tab.CHARACTERS: _show_characters()
		Tab.CARDS:      _show_cards()
		Tab.LORE:       _show_lore()
		Tab.ENDINGS:    _show_endings()

func _show_characters() -> void:
	var chars = [
		{"id": "angel",      "met_flag": "met_angel"},
		{"id": "oracle",     "met_flag": "met_oracle"},
		{"id": "apprentice", "met_flag": "met_apprentice"}
	]
	for char in chars:
		var panel = _make_character_entry(char.id, char.met_flag)
		content_panel.add_child(panel)

func _make_character_entry(char_id: String, met_flag: String) -> Control:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var met = GameState.has_flag(met_flag)
	var name_label = Label.new()
	name_label.text = GameState.get_character_name(char_id) if met else "???"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	container.add_child(name_label)

	if met:
		var tier = GameState.get_affinity_tier(char_id)
		var score = GameState.affinity.get(char_id, 0)
		var tier_label = Label.new()
		tier_label.text = "Bond: %s  (%d / 100)" % [tier.capitalize(), score]
		tier_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8))
		container.add_child(tier_label)

		# Character description (unlocked by tier)
		var desc = _get_character_description(char_id, tier)
		var desc_label = Label.new()
		desc_label.text = desc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
		container.add_child(desc_label)
	else:
		var unknown_label = Label.new()
		unknown_label.text = "You have not yet met this presence."
		unknown_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5))
		container.add_child(unknown_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.2, 0.5, 0.5))
	container.add_child(sep)
	return container

func _get_character_description(char_id: String, tier: String) -> String:
	var descriptions: Dictionary = {
		"angel": {
			"guarded": "A presence that fills the room without moving. Cold, or something that has chosen to seem cold.",
			"opening": "You have seen them hesitate. It was only for a moment, but it was there.",
			"intimate": "They carry something heavy and have been carrying it for a very long time. You are beginning to understand the shape of it.",
			"beloved": "Reckoning made flesh. The fragment that remembers everything — and chose, once, not to run from it."
		},
		"oracle": {
			"guarded": "Warm. Too warm, perhaps. Their eyes are always slightly ahead of where they should be.",
			"opening": "They answered a question directly once. You remember exactly what they said.",
			"intimate": "Something was arranged before you arrived. You can feel the architecture of it. You can't decide if you mind.",
			"beloved": "Will given form. They have all the tools. What they needed was someone to choose not to use them."
		},
		"apprentice": {
			"guarded": "Young in the way that some things are young — not in years, but in encounter.",
			"opening": "They asked you a question no one else here has thought to ask.",
			"intimate": "Something underneath the openness watches. Not unkindly. Just... watches.",
			"beloved": "Innocence that chose to stay innocent, which is the rarest and most dangerous kind."
		}
	}
	return descriptions.get(char_id, {}).get(tier, "")

func _show_cards() -> void:
	var unlocked = CardManager.get_all_unlocked_cards()
	var count_label = Label.new()
	count_label.text = "%d / %d cards discovered" % [unlocked.size(), CardManager.MAJOR_ARCANA.size()]
	count_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	content_panel.add_child(count_label)

	for card in CardManager.MAJOR_ARCANA:
		var is_unlocked = GameState.cards_unlocked.has(card.id) or GameState.cards_unlocked.has(card.id + "_reversed")
		var entry = _make_card_entry(card, is_unlocked)
		content_panel.add_child(entry)

func _make_card_entry(card: Dictionary, unlocked: bool) -> Control:
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_img = TextureRect.new()
	card_img.custom_minimum_size = Vector2(60, 90)
	card_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if unlocked:
		var path = "res://images/cards/%s.png" % card.id
		if ResourceLoader.exists(path):
			card_img.texture = load(path)
	else:
		card_img.modulate = Color(0.2, 0.15, 0.3)
	container.add_child(card_img)
	var text_col = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl = Label.new()
	name_lbl.text = card.name if unlocked else "???"
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	text_col.add_child(name_lbl)
	if unlocked:
		var meaning_lbl = Label.new()
		meaning_lbl.text = card.get("upright", "")
		meaning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		meaning_lbl.add_theme_font_size_override("font_size", 18)
		meaning_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75))
		text_col.add_child(meaning_lbl)
	container.add_child(text_col)
	return container

func _show_lore() -> void:
	var lore_entries = _get_unlocked_lore()
	if lore_entries.is_empty():
		var lbl = Label.new()
		lbl.text = "No lore discovered yet.\nComplete readings and rituals to unlock fragments of the truth."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.65))
		content_panel.add_child(lbl)
		return
	for entry in lore_entries:
		var lbl = Label.new()
		lbl.text = entry
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.9))
		content_panel.add_child(lbl)
		var sep = HSeparator.new()
		sep.add_theme_color_override("color", Color(0.3, 0.2, 0.5, 0.4))
		content_panel.add_child(sep)

func _get_unlocked_lore() -> Array[String]:
	var entries: Array[String] = []
	if GameState.has_flag("lore_fracture_hint"):
		entries.append("The tower existed before the Liminal. Or perhaps the Liminal grew around the tower. The distinction may not matter.")
	if GameState.has_flag("lore_beloved_name"):
		entries.append("There was a name, once. Before the fracture. The cards remember its shape, if not its sound.")
	if GameState.has_flag("lore_three_aspects"):
		entries.append("Three fragments. Three aspects. Reckoning. Will. Innocence. What breaks a thing into three? Something that was trying to hold three contradictions at once.")
	if GameState.has_flag("minigame_ritual_spread_best"):
		entries.append("The spread reveals what the straight draw cannot: pattern. Meaning is not in a single card but in the conversation between them.")
	return entries

func _show_endings() -> void:
	var completed = GameState.completed_endings
	if completed.is_empty():
		var lbl = Label.new()
		lbl.text = "No endings reached yet.\nThe story is still unfolding."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.65))
		content_panel.add_child(lbl)
		return
	for ending_id in completed:
		var lbl = Label.new()
		lbl.text = _get_ending_title(ending_id)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		content_panel.add_child(lbl)

func _get_ending_title(ending_id: String) -> String:
	const ENDING_TITLES: Dictionary = {
		"angel_a": "Absolution",
		"angel_b": "The Weight Remains",
		"angel_c": "Reckoning Together",
		"oracle_a": "The Architect's Surrender",
		"oracle_b": "The Long Game",
		"oracle_c": "Shattered Will",
		"apprentice_a": "The First Step",
		"apprentice_b": "Stay",
		"apprentice_c": "The Empty Card",
		"true_ending": "Endless, Beloved"
	}
	return ENDING_TITLES.get(ending_id, ending_id)

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx("menu_back")
	SceneManager.go_to("home_screen.tscn")
