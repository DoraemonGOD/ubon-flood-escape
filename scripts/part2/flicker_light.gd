class_name FlickerLight
extends PointLight2D
## Lamp / window light that breathes and flickers a little (never fully off,
## so nothing on screen strobes).

@export var flicker_amount: float = 0.18
@export var flicker_speed: float = 7.0

var _base_energy := 1.0
var _time := 0.0


func _ready() -> void:
	_base_energy = energy
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta
	var n := sin(_time * flicker_speed) * 0.5 + sin(_time * flicker_speed * 2.3 + 1.7) * 0.3 + sin(_time * 0.9) * 0.2
	energy = _base_energy * (1.0 + n * flicker_amount)
