class_name VirtualStick
extends Node2D
## Floating on-screen joystick for touch screens. Put a finger anywhere in its zone
## (left part of the screen): the stick jumps there and drives the move_* actions with
## analog strength, so Input.get_vector() in the Player works unchanged.
## Pushing it to the rim also holds "run".

@export var radius: float = 86.0
## Fraction of the radius that counts as running.
@export_range(0.5, 1.0) var run_threshold: float = 0.85
## Touch zone, as fractions of the visible screen (left 45 %, below the top HUD).
@export var zone: Rect2 = Rect2(0.0, 0.25, 0.45, 0.75)

var value: Vector2 = Vector2.ZERO
var home: Vector2 = Vector2.ZERO

var _touch_index := -1
var _center := Vector2.ZERO

@onready var base: Sprite2D = $Base
@onready var knob: Sprite2D = $Knob


func _ready() -> void:
	_reset_visual()


func is_held() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _in_zone(touch.position):
			_touch_index = touch.index
			_center = touch.position
			base.position = _center
			_drag(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		_drag((event as InputEventScreenDrag).position)
		get_viewport().set_input_as_handled()


func _in_zone(pos: Vector2) -> bool:
	var view := get_viewport().get_visible_rect().size
	var rect := Rect2(zone.position * view, zone.size * view)
	return rect.has_point(pos)


func _drag(pos: Vector2) -> void:
	var offset := (pos - _center).limit_length(radius)
	knob.position = _center + offset
	value = offset / radius
	var running := value.length() >= run_threshold
	knob.modulate = Color(1.0, 0.72, 0.6) if running else Color.WHITE
	_set_action(&"move_right", value.x)
	_set_action(&"move_left", -value.x)
	_set_action(&"move_down", value.y)
	_set_action(&"move_up", -value.y)
	if running:
		Input.action_press(&"run")
	else:
		Input.action_release(&"run")


## Lets go of the stick (finger lifted, or the controls are hidden).
func release() -> void:
	_touch_index = -1
	value = Vector2.ZERO
	for action in [&"move_right", &"move_left", &"move_down", &"move_up", &"run"]:
		Input.action_release(action)
	_reset_visual()


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _reset_visual() -> void:
	if base == null:
		return
	base.position = home
	knob.position = home
	knob.modulate = Color.WHITE


func set_home(pos: Vector2) -> void:
	home = pos
	if _touch_index == -1:
		_reset_visual()


func _exit_tree() -> void:
	if _touch_index != -1:
		release()
