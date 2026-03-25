# AudioManager.gd
# Autoload singleton — manages music and SFX with crossfading
extends Node

const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const FADE_TIME: float = 1.5

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

# SFX paths
const SFX = {
	"card_draw":    "res://audio/sfx/card_draw.ogg",
	"card_flip":    "res://audio/sfx/card_flip.ogg",
	"card_shuffle": "res://audio/sfx/card_shuffle.ogg",
	"dialogue_blip":"res://audio/sfx/dialogue_blip.ogg",
	"page_turn":    "res://audio/sfx/page_turn.ogg",
	"affinity_up":  "res://audio/sfx/affinity_up.ogg",
	"menu_select":  "res://audio/sfx/menu_select.ogg",
	"menu_back":    "res://audio/sfx/menu_back.ogg",
	"candle":       "res://audio/sfx/candle.ogg",
}

# Music paths
const MUSIC = {
	"title":        "res://audio/music/title_theme.ogg",
	"liminal":      "res://audio/music/liminal_ambient.ogg",
	"angel_theme":  "res://audio/music/angel_theme.ogg",
	"oracle_theme": "res://audio/music/oracle_theme.ogg",
	"apprentice_theme": "res://audio/music/apprentice_theme.ogg",
	"reading":      "res://audio/music/reading_ambient.ogg",
	"tension":      "res://audio/music/tension.ogg",
	"ending":       "res://audio/music/ending.ogg",
}

func _ready() -> void:
	_music_player_a = _make_music_player()
	_music_player_b = _make_music_player()
	_active_player = _music_player_a
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)

func _make_music_player() -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = MUSIC_BUS
	p.volume_db = 0.0
	add_child(p)
	return p

func play_music(key: String, loop: bool = true) -> void:
	if not MUSIC.has(key):
		push_warning("Unknown music key: " + key)
		return
	var path = MUSIC[key]
	if not ResourceLoader.exists(path):
		return  # Placeholder — asset not yet added
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	var next = _music_player_b if _active_player == _music_player_a else _music_player_a
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(_active_player, "volume_db", -80.0, FADE_TIME)
	tween.tween_property(next, "volume_db", 0.0, FADE_TIME)
	await tween.finished
	_active_player.stop()
	_active_player = next

func stop_music() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(_active_player, "volume_db", -80.0, FADE_TIME)
	await tween.finished
	_active_player.stop()

func play_sfx(key: String) -> void:
	if not SFX.has(key):
		return
	var path = SFX[key]
	if not ResourceLoader.exists(path):
		return  # Placeholder
	var stream = load(path)
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All players busy — use first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()

func set_music_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(MUSIC_BUS),
		linear_to_db(value)
	)

func set_sfx_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(SFX_BUS),
		linear_to_db(value)
	)
