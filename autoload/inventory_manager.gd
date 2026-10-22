extends Node
## Autoload "Inventory": the player's bag. Lives across scene changes, so the
## summary screen (and Part 2) read the same data the scavenging scene filled.

signal item_collected(item: ItemData, amount: int)
signal inventory_changed
## reason is &"no_slot" or &"too_heavy"
signal add_failed(item: ItemData, reason: StringName)

const DEFAULT_SLOTS := 8

var max_slots: int = DEFAULT_SLOTS
## 0 = no weight limit (weight is still tracked and shown).
var max_weight: float = 0.0

var _slots: Array[InventoryStack] = []


## Empties the bag and applies a new capacity. Called when a new run starts.
func configure(slots: int, weight_limit: float = 0.0) -> void:
	max_slots = maxi(slots, 1)
	max_weight = maxf(weight_limit, 0.0)
	reset()


func reset() -> void:
	_slots.clear()
	inventory_changed.emit()


func get_slots() -> Array[InventoryStack]:
	return _slots.duplicate()


## Slots in use (a family member's stack counts as 2).
func get_used_slot_count() -> int:
	var used := 0
	for stack in _slots:
		used += stack.item.slot_size
	return used


func get_free_slot_count() -> int:
	return max_slots - get_used_slot_count()


func is_full() -> bool:
	return get_used_slot_count() >= max_slots


func get_total_weight() -> float:
	var total := 0.0
	for stack in _slots:
		total += stack.get_weight()
	return total


func get_item_count(id: StringName) -> int:
	var total := 0
	for stack in _slots:
		if stack.item.id == id:
			total += stack.count
	return total


func get_total_item_count() -> int:
	var total := 0
	for stack in _slots:
		total += stack.count
	return total


## How many of `amount` would fit right now (slots, stack limits and weight).
func how_many_fit(item: ItemData, amount: int) -> int:
	var fit := (get_free_slot_count() / item.slot_size) * item.max_stack
	for stack in _slots:
		if stack.item.id == item.id:
			fit += stack.space_left()
	if max_weight > 0.0 and item.weight > 0.0:
		fit = mini(fit, floori((max_weight - get_total_weight() + 0.0001) / item.weight))
	return clampi(fit, 0, amount)


## Adds up to `amount` and returns how many were actually added (0 = bag full).
func add_item(item: ItemData, amount: int = 1) -> int:
	if item == null or amount <= 0:
		return 0
	var to_add := how_many_fit(item, amount)
	if to_add <= 0:
		add_failed.emit(item, _fail_reason(item))
		return 0
	var remaining := to_add
	for stack in _slots:
		if remaining == 0:
			break
		if stack.item.id == item.id and stack.space_left() > 0:
			var n := mini(stack.space_left(), remaining)
			stack.count += n
			remaining -= n
	while remaining > 0:
		var n := mini(item.max_stack, remaining)
		_slots.append(InventoryStack.new(item, n))
		remaining -= n
	item_collected.emit(item, to_add)
	inventory_changed.emit()
	return to_add


## Removes up to `amount`, newest stacks first. Returns how many were removed. (Part 2: using items.)
func remove_item(id: StringName, amount: int = 1) -> int:
	var removed := 0
	for i in range(_slots.size() - 1, -1, -1):
		if removed == amount:
			break
		var stack := _slots[i]
		if stack.item.id != id:
			continue
		var n := mini(stack.count, amount - removed)
		stack.count -= n
		removed += n
		if stack.count == 0:
			_slots.remove_at(i)
	if removed > 0:
		inventory_changed.emit()
	return removed


## Plain data for saving or handing to Part 2: [{"id": "water", "count": 2}, ...]
func to_save_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for stack in _slots:
		data.append(stack.to_dict())
	return data


func load_save_data(data: Array) -> void:
	_slots.clear()
	for entry in data:
		var item := ItemDatabase.get_item(StringName(entry.get("id", "")))
		if item != null and int(entry.get("count", 0)) > 0:
			_slots.append(InventoryStack.new(item, int(entry["count"])))
	inventory_changed.emit()


func _fail_reason(item: ItemData) -> StringName:
	if max_weight > 0.0 and get_total_weight() + item.weight > max_weight + 0.0001:
		return &"too_heavy"
	return &"no_slot"
