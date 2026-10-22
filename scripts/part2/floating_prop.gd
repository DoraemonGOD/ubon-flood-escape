class_name FloatingProp
extends Sprite2D
## Debris on the water: bobs up and down, tilts, and drifts slowly sideways,
## wrapping around the screen.

@export var bob_height: float = 3.0
@export var bob_speed: float = 1.2
@export var drift_speed: float = 6.0
@export var wrap_left: float = -80.0
@export var wrap_right: float = 1360.0

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	rotation = sin(_time * bob_speed * 0.7) * 0.08
	position.x += drift_speed * delta
	if position.x > wrap_right:
		position.x = wrap_left
	elif position.x < wrap_left:
		position.x = wrap_right
