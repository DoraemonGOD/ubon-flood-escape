extends Node
## Autoload "ItemDatabase": looks up ItemData by id.
## Add a new item: create its .tres in res://resources/items/ and list it here.

const ITEMS: Array[ItemData] = [
	preload("res://resources/items/water.tres"),
	preload("res://resources/items/canned_food.tres"),
	preload("res://resources/items/medicine.tres"),
	preload("res://resources/items/flashlight.tres"),
	preload("res://resources/items/batteries.tres"),
	preload("res://resources/items/rope.tres"),
	preload("res://resources/items/radio.tres"),
	preload("res://resources/items/documents.tres"),
]

## Family members who can be brought onto the boat (not supplies: kept out of ITEMS).
const FAMILY: Array[ItemData] = [
	preload("res://resources/items/family_mother.tres"),
	preload("res://resources/items/family_sister.tres"),
	preload("res://resources/items/family_grandpa.tres"),
]

var _by_id: Dictionary = {}


func _ready() -> void:
	for item in ITEMS + FAMILY:
		assert(not _by_id.has(item.id), "Duplicate item id: %s" % item.id)
		_by_id[item.id] = item


func get_item(id: StringName) -> ItemData:
	return _by_id.get(id)


## Supplies only (water, food ...). Family members: get_family().
func get_all_items() -> Array[ItemData]:
	return ITEMS


func get_family() -> Array[ItemData]:
	return FAMILY
