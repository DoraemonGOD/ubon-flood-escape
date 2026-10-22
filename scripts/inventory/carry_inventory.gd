class_name CarryInventory
extends Node
## What the player is holding in their arms right now (max MAX_CARRY_ITEMS units).
## Kept separate from the permanent "Inventory" autoload on purpose: nothing here
## counts as saved until it lands on the boat and BoatCargo confirms the delivery.
## Lives as a child of the Player, so it is recreated (empty) every new run.

signal carry_inventory_changed
signal item_picked_up(item: ItemData)

const MAX_CARRY_ITEMS := 3


## One carried unit. `item` keeps id, names, category (type) and icon (sprite).
class CarriedItem extends RefCounted:
	var item: ItemData
	## True while the item is flying towards the boat (released, not yet confirmed).
	var in_flight := false

	func _init(p_item: ItemData) -> void:
		item = p_item


var _items: Array[CarriedItem] = []


## Hand space in use (a family member takes 2 of the 3).
func count() -> int:
	var units := 0
	for entry in _items:
		units += entry.item.slot_size
	return units


## Number of separate things held (a person = 1).
func item_count() -> int:
	return _items.size()


func is_full() -> bool:
	return count() >= MAX_CARRY_ITEMS


func can_add(item: ItemData) -> bool:
	return item != null and count() + item.slot_size <= MAX_CARRY_ITEMS


func is_empty() -> bool:
	return _items.is_empty()


func get_items() -> Array[CarriedItem]:
	return _items.duplicate()


## ItemData of every carried unit that is still in the hands (not in flight).
func get_held_item_data() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for entry in _items:
		if not entry.in_flight:
			result.append(entry.item)
	return result


func has_throwable() -> bool:
	for entry in _items:
		if not entry.in_flight:
			return true
	return false


## Adds one unit. Returns false (and changes nothing) when the hands are full.
func add(item: ItemData) -> bool:
	if not can_add(item):
		return false
	_items.append(CarriedItem.new(item))
	item_picked_up.emit(item)
	carry_inventory_changed.emit()
	return true


## Marks the next held unit as thrown. It stays in the list until confirmed or cancelled.
func begin_throw() -> CarriedItem:
	for entry in _items:
		if not entry.in_flight:
			entry.in_flight = true
			carry_inventory_changed.emit()
			return entry
	return null


## The thrown unit reached the boat and BoatCargo accepted it: remove it for good.
func confirm_thrown(entry: CarriedItem) -> void:
	if _items.has(entry):
		_items.erase(entry)
		carry_inventory_changed.emit()


## The throw failed: the unit goes back into the hands, nothing is lost.
func cancel_throw(entry: CarriedItem) -> void:
	if _items.has(entry) and entry.in_flight:
		entry.in_flight = false
		carry_inventory_changed.emit()


func clear() -> void:
	_items.clear()
	carry_inventory_changed.emit()
