# DialogueBox.gd
# The main dialogue display — typewriter text, portraits, choices
extends Control

@onready var speaker_name = $SpeakerPanel/SpeakerName
@onready var dialogue_text = $TextPanel/DialogueText
@onready var portrait = $PortraitFrame/Portrait
@onready var choices_container = $ChoicesContainer
@onready var tap_indicator = $TapIndicator
@onready var text_panel = $TextPanel

var _full_text: String = ""
var _current_char: int = 0
var _typewriter_timer: float = 0.0
var _is_complete: bool = false
var _pending_choices: Array = []

# Portrait sprite regions (row per character, col per expression)
const PORTRAIT_EXPRESSIONS = {
	"neutral": 0, "happy": 1, "sad": 2, "angry": 3,
	"surprised": 4, "thoughtful": 5, "loving": 6, "fearful": 7
}

func _ready() -> void:
	DialogueSystem.line_started.connect(_on_line_started)
	DialogueSystem.choice_presented.connect(_on_choice_presented)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	_clear_choices()
	tap_indicator.visible = false

func _process(delta: float) -> void:
	if _current_char < _full_text.length():
		_typewriter_timer += delta
		var speed = DialogueSystem.get_typewriter_speed()
		if DialogueSystem.should_skip_typing():
			# Skip to end
			_current_char = _full_text.length()
			dialogue_text.text = _full_text
			_on_typewriter_complete()
			return
		while _typewriter_timer >= speed and _current_char < _full_text.length():
			_typewriter_timer -= speed
			_current_char += 1
			dialogue_text.text = _full_text.substr(0, _current_char)
			# Play blip every 3 chars
			if _current_char % 3 == 0:
				AudioManager.play_sfx("dialogue_blip")
		if _current_char >= _full_text.length():
			_on_typewriter_complete()

func _on_line_started(speaker: String, text: String, expression: String) -> void:
	_is_complete = false
	tap_indicator.visible = false
	_clear_choices()

	# Speaker name
	if speaker == "":
		speaker_name.text = ""
		speaker_name.get_parent().visible = false
	else:
		speaker_name.get_parent().visible = true
		# Map speaker ID to display name
		match speaker:
			"angel":
				speaker_name.text = GameState.get_character_name("angel")
			"oracle":
				speaker_name.text = GameState.get_character_name("oracle")
			"apprentice":
				speaker_name.text = GameState.get_character_name("apprentice")
			"narrator":
				speaker_name.text = ""
				speaker_name.get_parent().visible = false
			_:
				speaker_name.text = speaker

	# Portrait
	_update_portrait(speaker, expression)

	# Start typewriter
	_full_text = text
	_current_char = 0
	_typewriter_timer = 0.0
	dialogue_text.text = ""

func _update_portrait(speaker: String, expression: String) -> void:
	if speaker == "" or speaker == "narrator":
		portrait.get_parent().visible = false
		return
	portrait.get_parent().visible = true
	var portrait_path = "res://images/characters/%s_%s_%s.png" % [
		speaker,
		GameState.character_variants.get(speaker, "nonbinary"),
		expression
	]
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	# Subtle entrance animation
	portrait.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(portrait, "modulate:a", 1.0, 0.3)

func _on_typewriter_complete() -> void:
	_is_complete = true
	tap_indicator.visible = true
	DialogueSystem.on_typewriter_complete()
	# Animate tap indicator
	var tween = create_tween().set_loops()
	tween.tween_property(tap_indicator, "modulate:a", 0.3, 0.6)
	tween.tween_property(tap_indicator, "modulate:a", 1.0, 0.6)

func _on_choice_presented(choices: Array) -> void:
	_pending_choices = choices
	_clear_choices()
	tap_indicator.visible = false
	for i in choices.size():
		var btn = _make_choice_button(choices[i].text, i)
		choices_container.add_child(btn)
	choices_container.visible = true

func _make_choice_button(text: String, index: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 72)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.25, 0.85)
	style.border_color = Color(0.5, 0.3, 0.8, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = style.duplicate()
	style_hover.bg_color = Color(0.25, 0.1, 0.4, 0.95)
	style_hover.border_color = Color(0.8, 0.6, 1.0, 0.9)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)

	btn.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	btn.add_theme_font_size_override("font_size", 24)

	var capture_index = index
	btn.pressed.connect(func():
		_on_choice_selected(capture_index)
	)
	return btn

func _on_choice_selected(index: int) -> void:
	_clear_choices()
	DialogueSystem.make_choice(index, _pending_choices)

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.visible = false

func _on_dialogue_ended(_next_scene: String) -> void:
	tap_indicator.visible = false

# Called by parent scene on tap
func handle_tap() -> void:
	if choices_container.visible:
		return  # Let choices handle it
	DialogueSystem.request_advance()
