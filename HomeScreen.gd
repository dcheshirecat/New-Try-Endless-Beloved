# HomeScreen.gd
# The player's personal altar — home screen between scenes
extends Control

@onready var avatar_display = $AvatarDisplay
@onready var player_name_label = $PlayerNameLabel
@onready var candle_particles = $CandleParticles
@onready var deck_button = $DeckButton
@onready var journal_button = $JournalButton
@onready var continue_button = $ContinueButton
@onready var settings_button = $SettingsButton
@onready var affinity_hints = $AffinityHints
@onready var cycle_indicator = $CycleIndicator
@onready var ambient_overlay = $AmbientOverlay

# Character portrait hints (subtle glow showing who's thinking of you)
@onready var angel_hint = $AffinityHints/AngelHint
@onready var oracle_hint = $AffinityHints/OracleHint
@onready var apprentice_hint = $AffinityHints/ApprenticeHint

var _candle_flicker_time: float = 0.0

func _ready() -> void:
	AudioManager.play_music("liminal")
	_setup_ui()
	_animate_entrance()

func _setup_ui() -> void:
	# Player name
	player_name_label.text = GameState.player_name if GameState.player_name != "" else "The Unnamed"

	# Cycle indicator (only show from cycle 2+)
	if GameState.cycle_number > 1:
		cycle_indicator.visible = true
		cycle_indicator.text = "Cycle %d" % GameState.cycle_number
	else:
		cycle_indicator.visible = false

	# Update avatar
	_update_avatar()

	# Affinity hints — subtle glows based on affinity
	_update_affinity_hints()

	# Continue button — show chapter info
	if GameState.current_chapter > 0:
		continue_button.text = "Continue\nChapter %d" % GameState.current_chapter
	else:
		continue_button.text = "Begin"

func _update_avatar() -> void:
	# Avatar customisation — applies selected options
	# Each option maps to a region in the avatar sprite sheet
	var av = GameState.player_avatar
	if avatar_display.has_method("apply_customisation"):
		avatar_display.apply_customisation(av)

func _update_affinity_hints() -> void:
	# Subtle visual hint: character portrait glows if affinity > 30
	_set_hint_visibility(angel_hint, GameState.affinity.get("angel", 0))
	_set_hint_visibility(oracle_hint, GameState.affinity.get("oracle", 0))
	_set_hint_visibility(apprentice_hint, GameState.affinity.get("apprentice", 0))

func _set_hint_visibility(hint: Control, affinity_score: int) -> void:
	if affinity_score <= 0:
		hint.visible = false
		return
	hint.visible = true
	var alpha = clamp(float(affinity_score) / 100.0, 0.1, 0.8)
	hint.modulate.a = alpha

func _animate_entrance() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.2)

func _process(delta: float) -> void:
	_candle_flicker_time += delta
	# Subtle ambient breathing effect on the overlay
	var flicker = sin(_candle_flicker_time * 1.3) * 0.02 + sin(_candle_flicker_time * 2.7) * 0.01
	ambient_overlay.modulate.a = 0.15 + flicker

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_continue_button_pressed() -> void:
	AudioManager.play_sfx("menu_select")
	if GameState.current_chapter == 0:
		SceneManager.go_to("character_setup.tscn")
	else:
		SceneManager.go_to("liminal_tower.tscn")

func _on_deck_button_pressed() -> void:
	AudioManager.play_sfx("card_shuffle")
	SceneManager.go_to("card_archive.tscn")

func _on_journal_button_pressed() -> void:
	AudioManager.play_sfx("page_turn")
	SceneManager.go_to("journal.tscn")

func _on_settings_button_pressed() -> void:
	AudioManager.play_sfx("menu_select")
	$SettingsPanel.visible = true

func _on_avatar_button_pressed() -> void:
	AudioManager.play_sfx("menu_select")
	SceneManager.go_to("avatar_customise.tscn")
