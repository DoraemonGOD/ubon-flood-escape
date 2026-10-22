class_name ThrowItem
extends Node2D
## A single item flying from the player's hand to the boat along an arc.
## The node itself moves along the ground (straight line, where the shadow is);
## the Sprite child is lifted by the arc height. Separate from the player's own
## animation. Emits `landed` once — the receiver decides whether it counts.

signal landed(throw: ThrowItem)

@export var duration: float = 0.5
@export var arc_height: float = 90.0

var item: ItemData
var end_height: float = 0.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _start_height := 0.0
var _t := 0.0
var _flying := false
var _spin := 1.0

@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite


## Call after adding to the tree. Positions are world positions on the ground.
func launch(p_item: ItemData, from_ground: Vector2, start_height: float, to_ground: Vector2, p_end_height: float) -> void:
	item = p_item
	_from = from_ground
	_to = to_ground
	_start_height = start_height
	end_height = p_end_height
	_spin = 1.0 if to_ground.x >= from_ground.x else -1.0
	sprite.texture = item.icon
	if item.is_person():
		_spin = 0.0 # people climb aboard, they are not thrown
		sprite.texture = item.world_texture if item.world_texture else item.icon
		sprite.scale = Vector2(0.55, 0.55)
		duration = 0.75
	global_position = _from
	_t = 0.0
	_flying = true
	_apply()


func is_flying() -> bool:
	return _flying


func _process(delta: float) -> void:
	if not _flying:
		return
	_t = minf(_t + delta / duration, 1.0)
	_apply()
	if _t >= 1.0:
		_flying = false
		landed.emit(self)
		queue_free()


func _apply() -> void:
	global_position = _from.lerp(_to, _t)
	var height := lerpf(_start_height, end_height, _t) + arc_height * 4.0 * _t * (1.0 - _t)
	sprite.position = Vector2(0, -height)
	sprite.rotation = _t * TAU * 0.6 * _spin
	# the higher the item, the smaller and lighter its shadow
	var k := clampf(height / (arc_height + _start_height), 0.0, 1.0)
	shadow.scale = Vector2.ONE * lerpf(1.0, 0.55, k)
	shadow.modulate.a = lerpf(0.55, 0.25, k)
