@tool
class_name ItemPickup
extends Area2D
## An item lying in the level. One scene (item_pickup.tscn) for every item type:
## pick the ItemData in the Inspector, set quantity and elevation, done.
## The node's position is the floor point under the item (used for Y-sorting and
## reach); `elevation` lifts the sprite onto a table or shelf.

signal collected(pickup: ItemPickup, amount: int)

## Art is drawn with its bottom edge 8 px above the image bottom (icons and seated people alike).
const ART_BASE_PAD := 8.0

@export var item: ItemData:
	set(value):
		item = value
		_refresh()
@export_range(1, 99) var quantity: int = 1
## Height of the surface the item rests on, in pixels above this node's position.
@export_range(0.0, 200.0, 1.0, "suffix:px") var elevation: float = 0.0:
	set(value):
		elevation = value
		_refresh()

var _collected := false
var _reserved := false
var _highlighted := false
var _glow_tween: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var glow: Sprite2D = $Glow
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		return
	add_to_group(&"item_pickups")
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(glow, "modulate:a", 0.85, 0.8).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(glow, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)


func can_be_collected() -> bool:
	return not _collected and not _reserved and item != null and quantity > 0 and monitorable


## Locks this pickup for one player's pickup animation, so nothing else can grab it
## meanwhile (no double pickups from repeated key presses or signals).
func reserve() -> bool:
	if not can_be_collected():
		return false
	_reserved = true
	set_highlighted(false)
	return true


## The pickup animation was cancelled before the grab: the item stays as it was.
func release_reservation() -> void:
	_reserved = false


## Removes one unit (called at the grab keyframe after the CarryInventory accepted it).
func take_one() -> bool:
	_reserved = false
	if _collected or quantity <= 0:
		return false
	quantity -= 1
	collected.emit(self, 1)
	if quantity <= 0:
		_collected = true
		set_highlighted(false)
		set_deferred("monitorable", false)
		_play_collect_animation()
	else:
		_play_refuse_animation()
	return true


## Legacy direct pickup (Part 1): moves the whole pickup into the Inventory autoload.
## The player now uses reserve()/take_one() through the CarryInventory instead.
func try_collect() -> bool:
	if not can_be_collected():
		return false
	var added := Inventory.add_item(item, quantity)
	if added <= 0:
		_play_refuse_animation()
		return false
	quantity -= added
	collected.emit(self, added)
	if quantity <= 0:
		_collected = true
		set_highlighted(false)
		set_deferred("monitorable", false)
		_play_collect_animation()
	else:
		_play_refuse_animation()
	return true


## Stops this pickup from being collected (used when the time runs out).
func disable() -> void:
	set_deferred("monitorable", false)
	set_highlighted(false)


func set_highlighted(value: bool) -> void:
	if _highlighted == value or not is_node_ready():
		return
	_highlighted = value
	var target := Vector2.ONE * item.world_scale * (1.15 if value else 1.0) if item else Vector2.ONE
	create_tween().tween_property(sprite, "scale", target, 0.12)
	sprite.modulate = Color(1.15, 1.1, 0.95) if value else Color.WHITE


func get_prompt_anchor() -> Vector2:
	## World-space point just above the item, for the "press E" prompt.
	return global_position + Vector2(0, -elevation - _art_bottom() * 2.0 * _icon_scale() - 8.0)


func _icon_scale() -> float:
	return item.world_scale if item else 1.0


func _world_texture() -> Texture2D:
	if item == null:
		return null
	return item.world_texture if item.world_texture else item.icon


## Distance from the sprite's centre to where it touches the surface.
func _art_bottom() -> float:
	var tex := _world_texture()
	return tex.get_height() * 0.5 - ART_BASE_PAD if tex else 24.0


func _refresh() -> void:
	if not is_node_ready():
		return
	sprite.texture = _world_texture()
	sprite.scale = Vector2.ONE * _icon_scale()
	sprite.position = Vector2(0, -elevation - _art_bottom() * _icon_scale())
	glow.position = Vector2(0, -elevation - 4.0)


func _play_collect_animation() -> void:
	if _glow_tween:
		_glow_tween.kill()
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "position:y", sprite.position.y - 40.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", sprite.scale * 1.3, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.08)
	tween.chain().tween_callback(queue_free)


func _play_refuse_animation() -> void:
	var x := sprite.position.x
	var tween := create_tween()
	for offset in [-5.0, 5.0, -3.0, 0.0]:
		tween.tween_property(sprite, "position:x", x + offset, 0.04)
