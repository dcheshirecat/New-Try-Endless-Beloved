# AvatarCustomise.gd
# Player avatar customisation — runs at game start and from home screen
extends Control

# Customisation categories
const SKIN_TONES: Array[Color] = [
	Color(1.0, 0.87, 0.74),   # Light
	Color(0.95, 0.75, 0.57),  # Light-medium
	Color(0.85, 0.62, 0.40),  # Medium
	Color(0.67, 0.45, 0.27),  # Medium-dark
	Color(0.45, 0.28, 0.15),  # Dark
	Color(0.25, 0.15, 0.08),  # Deep
]

const HAIR_STYLES: int = 8   # Number of hair style options
const HAIR_COLORS: Array[Color] = [
	Color(0.1, 0.07, 0.05),   # Black
	Color(0.3, 0.18, 0.08),   # Dark brown
	Color(0.55, 0.35, 0.15),  # Brown
	Color(0.75, 0.55, 0.25),  # Auburn
	Color(0.9, 0.75, 0.35),   # Blonde
	Color(0.85, 0.85, 0.85),  # Silver/white
	Color(0.7, 0.15, 0.15),   # Red
	Color(0.4, 0.2, 0.7),     # Purple
	Color(0.15, 0.4, 0.7),    # Blue
]

const EYE_COLORS: Array[Color] = [
	Color(0.25, 0.18, 0.1),   # Brown
	Color(0.35, 0.45, 0.25),  # Green
	Color(0.3, 0.4, 0.55),    # Blue
	Color(0.5, 0.35, 0.15),   # Hazel
	Color(0.55, 0.55, 0.55),  # Grey
	Color(0.4, 0.15, 0.5),    # Violet
	Color(0.6, 0.25, 0.1),    # Amber
]

const OUTFITS: int = 6
const ACCESSORIES: int = 8  # Rings, earrings, markings, etc.

@onready var avatar_preview = $AvatarPreview
@onready var skin_grid = $Options/SkinToneGrid
@onready var hair_style_grid = $Options/HairStyleGrid
@onready var hair_color_grid = $Options/HairColorGrid
@onready var eye_color_grid = $Options/EyeColorGrid
@onready var outfit_grid = $Options/OutfitGrid
@onready var accessory_grid = $Options/AccessoryGrid
@onready var confirm_button = $ConfirmButton
@onready var category_tabs = $CategoryTabs

var _current_avatar: Dictionary = {}
var _is_first_setup: bool = false

func _ready() -> void:
	_current_avatar = GameState.player_avatar.duplicate()
	_is_first_setup = GameState.current_chapter == 0
	_build_options()
	_refresh_preview()
	if _is_first_setup:
		confirm_button.text = "This is me"
	else:
		confirm_button.text = "Save changes"

func _build_options() -> void:
	_build_color_grid(skin_grid, SKIN_TONES, "skin_tone")
	_build_number_grid(hair_style_grid, HAIR_STYLES, "hair_style", "res://images/ui/hair_")
	_build_color_grid(hair_color_grid, HAIR_COLORS, "hair_color")
	_build_color_grid(eye_color_grid, EYE_COLORS, "eye_color")
	_build_number_grid(outfit_grid, OUTFITS, "outfit", "res://images/ui/outfit_")
	_build_number_grid(accessory_grid, ACCESSORIES, "accessory", "res://images/ui/accessory_")

func _build_color_grid(grid: GridContainer, colors: Array, key: String) -> void:
	for child in grid.get_children():
		child.queue_free()
	for i in colors.size():
		var btn = ColorRect.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.color = colors[i]
		# Highlight selected
		if _current_avatar.get(key, 0) == i:
			var border = Panel.new()
			border.custom_minimum_size = Vector2(52, 52)
			btn.add_child(border)
		var capture_i = i
		var capture_key = key
		btn.gui_input.connect(func(event):
			if event is InputEventScreenTouch and event.pressed:
				_current_avatar[capture_key] = capture_i
				_build_options()
				_refresh_preview()
				AudioManager.play_sfx("menu_select")
		)
		grid.add_child(btn)

func _build_number_grid(grid: GridContainer, count: int, key: String, icon_prefix: String) -> void:
	for child in grid.get_children():
		child.queue_free()
	for i in count:
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 80)
		var path = icon_prefix + str(i) + ".png"
		if ResourceLoader.exists(path):
			btn.texture_normal = load(path)
		if _current_avatar.get(key, 0) == i:
			btn.modulate = Color(1.4, 1.2, 1.6)  # purple tint = selected
		var capture_i = i
		var capture_key = key
		btn.pressed.connect(func():
			_current_avatar[capture_key] = capture_i
			_build_options()
			_refresh_preview()
			AudioManager.play_sfx("menu_select")
		)
		grid.add_child(btn)

func _refresh_preview() -> void:
	if avatar_preview.has_method("apply_customisation"):
		avatar_preview.apply_customisation(_current_avatar)

func _on_confirm_button_pressed() -> void:
	GameState.player_avatar = _current_avatar.duplicate()
	AudioManager.play_sfx("affinity_up")
	if _is_first_setup:
		SceneManager.go_to("pronoun_select.tscn")
	else:
		SceneManager.go_to("home_screen.tscn")

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx("menu_back")
	if not _is_first_setup:
		SceneManager.go_to("home_screen.tscn")
