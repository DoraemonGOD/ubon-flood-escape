class_name TouchControls
extends CanvasLayer
## On-screen controls for phones/tablets in Part 1 (added by the scavenging level when
## Platform.is_mobile()): a floating stick on the left, "หยิบ" (interact) and "โยน" (throw)
## on the right, and a pause button. TouchScreenButtons send the same input actions as
## the keyboard, and they handle several fingers at once.

const BUTTON := preload("res://assets/ui/touch_button.svg")
const BUTTON_PRESSED := preload("res://assets/ui/touch_button_pressed.svg")

var stick: VirtualStick
var interact_button: TouchScreenButton
var throw_button: TouchScreenButton
var pause_button: TouchScreenButton


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	stick = preload("res://scenes/ui/virtual_stick.tscn").instantiate()
	add_child(stick)
	interact_button = _button(BUTTON, BUTTON_PRESSED, &"interact", "หยิบ", 30)
	throw_button = _button(BUTTON, BUTTON_PRESSED, &"throw", "โยน", 30)
	throw_button.scale = Vector2(0.82, 0.82)
	pause_button = _button(preload("res://assets/ui/touch_pause.svg"), preload("res://assets/ui/touch_pause_pressed.svg"), &"pause", "", 0)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	# hidden under the pause menu (its own buttons are tapped instead)
	var show := not get_tree().paused
	if visible != show:
		visible = show
		if not show:
			stick.release()


func _button(normal: Texture2D, pressed: Texture2D, action: StringName, text: String, font_size: int) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = normal
	b.texture_pressed = pressed
	b.action = action
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	add_child(b)
	if text != "":
		var label := Label.new()
		label.text = text
		label.size = normal.get_size()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", Color("efe2bf"))
		label.add_theme_color_override(&"font_outline_color", Color("1a1714"))
		label.add_theme_constant_override(&"outline_size", 8)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(label)
	return b


## Places everything against the screen edges (the visible area grows on wide phones).
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	stick.set_home(Vector2(200, view.y - 190))
	interact_button.position = Vector2(view.x - 190, view.y - 250) - BUTTON.get_size() * 0.5
	throw_button.position = Vector2(view.x - 350, view.y - 130) - BUTTON.get_size() * 0.41
	pause_button.position = Vector2(view.x - 330, 26)
