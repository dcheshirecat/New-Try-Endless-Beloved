# Main.gd
# Entry point — decides where to route on launch
extends Node

func _ready() -> void:
	# Check for existing save
	var has_save = false
	for slot in GameState.MAX_SLOTS:
		var meta = GameState.get_save_metadata(slot)
		if meta.get("exists", false):
			has_save = true
			break

	if has_save:
		SceneManager.go_to("load_screen.tscn")
	else:
		SceneManager.go_to("title_screen.tscn")
