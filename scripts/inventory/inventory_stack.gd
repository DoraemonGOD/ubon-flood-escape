class_name InventoryStack
extends RefCounted
## One occupied inventory slot: an item type and how many of it.

var item: ItemData
var count: int


func _init(p_item: ItemData, p_count: int) -> void:
	item = p_item
	count = p_count


func space_left() -> int:
	return item.max_stack - count


func get_weight() -> float:
	return item.weight * count


func to_dict() -> Dictionary:
	return {"id": String(item.id), "count": count}
