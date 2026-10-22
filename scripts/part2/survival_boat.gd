class_name SurvivalBoat
extends Node2D
## The family's boat in Part 2. Draw order inside the boat:
##   Back (floor, bench, lamp pole) -> Survivors -> Supplies -> Front (hull, front rim)
## so people and goods look like they sit INSIDE the boat.
## Positions come from the Marker2D children of SurvivorSlots / SupplySlots — move
## them in the editor to rearrange. Contents always come from SurvivalState/Inventory.
## (Named SurvivalBoat because Part 1 already has a class called Boat.)

const SURVIVOR_SCENE := preload("res://scenes/part2/survivor.tscn")
## Max copies of one item drawn on the deck (the panel shows the exact count).
const MAX_ICONS_PER_ITEM := 3

@export var rock_angle: float = 0.022
@export var rock_speed: float = 0.7
@export var bob_height: float = 4.0

var _time := 0.0
var _base_y := 0.0

@onready var hull: Node2D = $Hull
@onready var survivor_slots: Node2D = $Hull/SurvivorSlots
@onready var supply_slots: Node2D = $Hull/SupplySlots
@onready var survivors_root: Node2D = $Hull/Survivors
@onready var supplies_root: Node2D = $Hull/Supplies
@onready var flashlight_beam: PointLight2D = $Hull/FlashlightBeam


func _ready() -> void:
	_base_y = hull.position.y
	Inventory.inventory_changed.connect(refresh_supplies)
	SurvivalState.state_changed.connect(refresh_survivors)


func _process(delta: float) -> void:
	_time += delta
	hull.rotation = sin(_time * rock_speed) * rock_angle
	hull.position.y = _base_y + sin(_time * rock_speed * 1.6) * bob_height


func refresh() -> void:
	refresh_survivors()
	refresh_supplies()


func refresh_survivors() -> void:
	var slots := survivor_slots.get_children()
	var people := SurvivalState.get_present()
	# reuse existing nodes when the same people are on board (keeps their animation)
	if survivors_root.get_child_count() == mini(people.size(), slots.size()):
		var same := true
		for i in survivors_root.get_child_count():
			same = same and (survivors_root.get_child(i) as Survivor).data.id == people[i].id
		if same:
			for child in survivors_root.get_children():
				(child as Survivor).update_status()
			return
	for child in survivors_root.get_children():
		survivors_root.remove_child(child)
		child.queue_free()
	for i in mini(people.size(), slots.size()):
		var s: Survivor = SURVIVOR_SCENE.instantiate()
		s.data = people[i]
		s.position = (slots[i] as Node2D).position
		survivors_root.add_child(s)


func refresh_supplies() -> void:
	for child in supplies_root.get_children():
		supplies_root.remove_child(child)
		child.queue_free()
	flashlight_beam.visible = false
	var slots := supply_slots.get_children()
	var entries := SurvivalState.get_supplies()
	for i in mini(entries.size(), slots.size()):
		var item: ItemData = entries[i].item
		var base := (slots[i] as Node2D).position
		for k in mini(entries[i].count, MAX_ICONS_PER_ITEM):
			var icon := Sprite2D.new()
			icon.texture = item.icon
			icon.scale = Vector2(0.66, 0.66)
			icon.centered = false
			icon.offset = Vector2(-32, -58) # icon bottom rests on the slot point
			icon.position = base + Vector2(k * 9.0 - 6.0, -k * 6.0)
			icon.rotation = (k - 1) * 0.12
			supplies_root.add_child(icon)
		if item.id == &"flashlight":
			flashlight_beam.position = base + Vector2(10, -16)
			flashlight_beam.visible = true


func get_survivor_nodes() -> Array[Survivor]:
	var result: Array[Survivor] = []
	for child in survivors_root.get_children():
		if not child.is_queued_for_deletion():
			result.append(child)
	return result


func get_supply_icon_count() -> int:
	var n := 0
	for child in supplies_root.get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n
