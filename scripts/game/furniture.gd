@tool
class_name Furniture
extends StaticBody2D
## Any prop in the house (bed, fridge, rug, ...). One scene for all of them:
## set the texture and the footprint (collision box on the floor) in the Inspector.
## The node's position is the front-bottom centre of the object, which is what
## Y-sorting uses, so the player walks behind tall furniture correctly.

## All art is drawn with its front-bottom edge this many pixels above the image bottom.
const BASE_PAD := 6.0

@export var texture: Texture2D:
	set(value):
		texture = value
		_refresh()
## Width and depth of the blocking area on the floor, in pixels.
@export var footprint: Vector2 = Vector2(64, 32):
	set(value):
		footprint = value
		_refresh()
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_refresh()
## Turn off for flat decorations the player can walk over (rugs, mats).
@export var has_collision: bool = true:
	set(value):
		has_collision = value
		_refresh()

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	sprite.texture = texture
	sprite.centered = false
	sprite.flip_h = flip_h
	if texture:
		var size := texture.get_size()
		sprite.offset = Vector2(-size.x * 0.5, -size.y + BASE_PAD)
	var rect := collision.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		collision.shape = rect
	rect.size = footprint
	collision.position = Vector2(0, -footprint.y * 0.5)
	collision.disabled = not has_collision
