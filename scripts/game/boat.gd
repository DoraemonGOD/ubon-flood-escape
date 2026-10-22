class_name Boat
extends Node2D
## BoatInteraction: the rescue boat. Sprite, hull collision, interaction zone,
## drop point and cargo pile are separate child nodes, so each can be moved in
## the editor on its own. The player can throw (Q) while inside InteractionZone.
## Keep y_sort OFF on this node so the cargo pile always draws on top of the hull.

signal player_in_range_changed(player: Player, in_range: bool)

## Landing offsets around DropPoint so thrown items don't all stack on one spot.
const DROP_SPREAD: Array[Vector2] = [
	Vector2(0, 0), Vector2(-34, -6), Vector2(34, 5), Vector2(-62, 6), Vector2(62, -5), Vector2(-14, 9),
	Vector2(18, -9), Vector2(-46, -9), Vector2(46, 9), Vector2(-80, 0), Vector2(80, 1), Vector2(2, -12),
]
const PUFF := preload("res://assets/environments/boat/dust_puff.svg")

var _next_drop := 0

@onready var sprite: Sprite2D = $Sprite
@onready var interaction_zone: Area2D = $InteractionZone
@onready var drop_point: Marker2D = $DropPoint
@onready var cargo_pile: Node2D = $CargoPile
@onready var prompt_anchor: Marker2D = $PromptAnchor


func _ready() -> void:
	add_to_group(&"boats")
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)


func get_drop_center() -> Vector2:
	return drop_point.global_position


## World position where the next thrown item should land (cycles through DROP_SPREAD).
func next_drop_position() -> Vector2:
	var cycle := _next_drop / DROP_SPREAD.size()
	var offset := DROP_SPREAD[_next_drop % DROP_SPREAD.size()] + Vector2(0, -8 * cycle)
	_next_drop += 1
	return drop_point.global_position + offset


func get_prompt_anchor() -> Vector2:
	return prompt_anchor.global_position


## Called once a thrown item was accepted by BoatCargo: leave it on the deck + impact effect.
func on_item_landed(item: ItemData, global_pos: Vector2, height: float) -> void:
	var icon := Sprite2D.new()
	icon.texture = item.icon
	icon.scale = Vector2(0.5, 0.5)
	icon.rotation = randf_range(-0.35, 0.35)
	if item.is_person() and item.world_texture:
		icon.texture = item.world_texture
		icon.scale = Vector2(0.45, 0.45)
		icon.rotation = 0.0
	cargo_pile.add_child(icon)
	icon.global_position = global_pos + Vector2(0, -height)
	var tween := icon.create_tween()
	tween.tween_property(icon, "position:y", icon.position.y - 8.0, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position:y", icon.position.y, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	_play_impact(global_pos)


func get_cargo_visual_count() -> int:
	return cargo_pile.get_child_count()


func _play_impact(global_pos: Vector2) -> void:
	for i in 3:
		var puff := Sprite2D.new()
		puff.texture = PUFF
		puff.scale = Vector2(0.4, 0.4)
		add_child(puff)
		puff.global_position = global_pos + Vector2(randf_range(-6, 6), -4)
		var dir := Vector2(randf_range(-1.0, 1.0), -0.4).normalized()
		var tween := puff.create_tween().set_parallel()
		tween.tween_property(puff, "position", puff.position + dir * 22.0, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector2(0.9, 0.9), 0.35)
		tween.tween_property(puff, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(puff.queue_free)
	# the hull dips a little under the weight
	var bob := sprite.create_tween()
	bob.tween_property(sprite, "position:y", 3.0, 0.07)
	bob.tween_property(sprite, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.set_boat_in_range(self, true)
		player_in_range_changed.emit(body, true)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.set_boat_in_range(self, false)
		player_in_range_changed.emit(body, false)
