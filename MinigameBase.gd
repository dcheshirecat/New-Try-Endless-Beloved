# MinigameBase.gd
# Base class for all minigames — extend this for each minigame
# Provides: scoring, completion signals, affinity rewards, return navigation
class_name MinigameBase
extends Control

# Override in subclasses
var minigame_id: String = "base"
var minigame_title: String = "Untitled"
var is_complete: bool = false
var score: int = 0
var max_score: int = 100
var _return_scene: String = "home_screen.tscn"

# Optional affinity reward on completion
var affinity_rewards: Dictionary = {}  # { "character_id": delta }

# ── Signals ───────────────────────────────────────────────────────────────────
signal minigame_completed(score: int, max_score: int)
signal minigame_exited

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup()

# Override in subclasses
func _setup() -> void:
	pass

func _on_complete(final_score: int) -> void:
	is_complete = true
	score = final_score
	# Apply affinity rewards
	for char_id in affinity_rewards.keys():
		var reward = affinity_rewards[char_id]
		# Scale reward by score percentage
		var scaled = int(reward * (float(score) / float(max_score)))
		GameState.change_affinity(char_id, scaled)
	# Save result
	GameState.set_flag("minigame_" + minigame_id + "_best", 
		max(score, GameState.get_flag("minigame_" + minigame_id + "_best", 0))
	)
	minigame_completed.emit(score, max_score)
	_show_completion_screen()

func _show_completion_screen() -> void:
	# Show result overlay — subclasses can override for custom screen
	var overlay = preload("minigame_result.tscn").instantiate()
	overlay.setup(minigame_title, score, max_score)
	overlay.continue_pressed.connect(_on_result_continue)
	add_child(overlay)

func _on_result_continue() -> void:
	SceneManager.go_to(_return_scene)

func _on_exit_button_pressed() -> void:
	if not is_complete:
		AudioManager.play_sfx("menu_back")
		minigame_exited.emit()
		SceneManager.go_to(_return_scene)
