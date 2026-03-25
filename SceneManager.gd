# SceneManager.gd
# Autoload singleton — handles all scene transitions with fade
extends Node

const FADE_DURATION: float = 0.5

var _overlay: ColorRect
var _is_transitioning: bool = false

signal transition_complete

func _ready() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 100
	get_tree().root.call_deferred("add_child", _overlay)

func go_to(scene_path: String, data: Dictionary = {}) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = get_tree().create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	# Pass data to the new scene if it has a receive_data method
	var new_scene = get_tree().current_scene
	if new_scene and new_scene.has_method("receive_data"):
		new_scene.receive_data(data)
	var tween2 = get_tree().create_tween()
	tween2.tween_property(_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween2.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_complete.emit()

func fade_to_black(duration: float = FADE_DURATION) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, duration)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await tween.finished

func fade_from_black(duration: float = FADE_DURATION) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	await tween.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
