extends Node
## Autoload "BoatCargo": log of everything that was successfully thrown onto the boat
## this run. Each delivery is also committed to the permanent "Inventory" autoload,
## which now represents the supplies secured on the boat (summary + Part 2 read it).
## Only ThrowItem landings call deliver(), so nothing counts before a throw succeeds.

signal item_delivered(item: ItemData, total_delivered: int)
signal boat_cargo_changed

var total_delivered: int = 0
## id -> {"id": StringName, "type": StringName, "name": String, "quantity": int}
var _records: Dictionary = {}


func reset() -> void:
	total_delivered = 0
	_records.clear()
	boat_cargo_changed.emit()


## True if every item in `items` still fits in the boat hold.
func can_accept(items: Array[ItemData]) -> bool:
	var needed: Dictionary = {}
	var by_id: Dictionary = {}
	for item in items:
		needed[item.id] = needed.get(item.id, 0) + 1
		by_id[item.id] = item
	# Check each type against the free space, simulating the earlier types first.
	var slots_left := Inventory.get_free_slot_count()
	for id in needed:
		var item: ItemData = by_id[id]
		var n: int = needed[id]
		var room_in_stacks := 0
		for stack in Inventory.get_slots():
			if stack.item.id == id:
				room_in_stacks += stack.space_left()
		var overflow := maxi(n - room_in_stacks, 0)
		slots_left -= ceili(float(overflow) / item.max_stack) * item.slot_size
		if slots_left < 0:
			return false
	return true


## Records one delivered unit. Returns false if the boat hold refused it.
func deliver(item: ItemData) -> bool:
	if item == null or Inventory.add_item(item, 1) != 1:
		return false
	if not _records.has(item.id):
		_records[item.id] = {"id": item.id, "type": item.category, "name": item.name_th, "quantity": 0}
	_records[item.id]["quantity"] += 1
	total_delivered += 1
	item_delivered.emit(item, total_delivered)
	boat_cargo_changed.emit()
	return true


func get_quantity(id: StringName) -> int:
	return _records[id]["quantity"] if _records.has(id) else 0


## Copies of the records, in delivery order of first appearance.
func get_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _records:
		result.append(_records[id].duplicate())
	return result
