class_name House
extends Node2D
## Root of a scavenging map (scenes/scavenging/house.tscn).
## A new map only needs this script, a "PlayerSpawn" Marker2D and Y-sorted content.
##
## Shuffled layout: every new game, randomize_layout() moves each supply pickup to a
## random free Marker2D under ItemSpots and each family member to a random Marker2D
## under FamilySpots. A marker's "elevation" metadata is the height of the surface
## there (0 = floor). Add or move markers in the editor to change where things can be.

## Camera limits in world pixels (left, top, width, height).
@export var camera_limits: Rect2 = Rect2(-300, -320, 2140, 1360)

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var item_spots: Node2D = $ItemSpots
@onready var family_spots: Node2D = $FamilySpots


func get_player_spawn() -> Vector2:
	return player_spawn.global_position


func get_pickups() -> Array[ItemPickup]:
	var result: Array[ItemPickup] = []
	for node in get_tree().get_nodes_in_group(&"item_pickups"):
		if is_ancestor_of(node):
			result.append(node)
	return result


## Puts supplies and family members in random places (each spot used once).
func randomize_layout(rng: RandomNumberGenerator) -> void:
	var supply_spots := _shuffled(item_spots.get_children(), rng)
	var seats := _shuffled(family_spots.get_children(), rng)
	for pickup in get_pickups():
		var pool := seats if pickup.item and pickup.item.is_person() else supply_spots
		if pool.is_empty():
			continue
		var spot: Node2D = pool.pop_back()
		pickup.position = spot.position
		pickup.elevation = float(spot.get_meta("elevation", 0.0))


func _shuffled(nodes: Array[Node], rng: RandomNumberGenerator) -> Array[Node]:
	var result := nodes.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result
