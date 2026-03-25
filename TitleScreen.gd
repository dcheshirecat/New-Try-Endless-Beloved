# TitleScreen.gd
extends Control

@onready var title_label = $TitleLabel
@onready var subtitle_label = $SubtitleLabel
@onready var new_game_btn = $MenuButtons/NewGameButton
@onready var load_game_btn = $MenuButtons/LoadGameButton
@onready var settings_btn = $MenuButtons/SettingsButton
@onready var card_particles = $CardParticles
@onready var bg_overlay = $BackgroundOverlay

var _pulse_time: float = 0.0

func _ready() -> void:
	AudioManager.play_music("title")
	_animate_entrance()
	# Disable load if no saves
	var has_save = false
	for slot in GameState.MAX_SLOTS:
		if GameState.get_save_metadata(slot).get("exists", false):
			has_save = true
			break
	load_game_btn.disabled = not has_save

func _process(delta: float) -> void:
	_pulse_time += delta
	subtitle_label.modulate.a = 0.6 + 0.4 * sin(_pulse_time * 0.8)

func _animate_entrance() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)
	tween.tween_interval(0.5)
	tween.tween_property(subtitle_label, "modulate:a", 0.6, 1.5)

func _on_new_game_button_pressed() -> void:
	AudioManager.play_sfx("menu_select")
	# Randomise character variants for this playthrough
	GameState.randomise_character_variants()
	SceneManager.go_to("avatar_customise.tscn")

func _on_load_game_button_pressed() -> void:
	AudioManager.play_sfx("menu_select")
	SceneManager.go_to("load_screen.tscn")

func _on_settings_button_pressed() -> void:
	AudioManager.play_sfx("menu_select")
	$SettingsPanel.visible = true
