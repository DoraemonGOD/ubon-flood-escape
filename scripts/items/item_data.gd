class_name ItemData
extends Resource
## Static definition of one item type (water, canned food, ...).
## One .tres file per item lives in res://resources/items/.
## How many of an item a pickup gives and where it sits are set on the
## ItemPickup node in the level, not here.

## Unique, never-translated id. Part 2 and save files refer to items by this id.
@export var id: StringName
@export var name_th: String
@export var name_en: String
@export_multiline var description: String
## Used both for the world sprite and the inventory icon.
@export var icon: Texture2D
## Scale of the icon when the item lies in the world.
@export_range(0.2, 2.0, 0.05) var world_scale: float = 0.75
## Kilograms. Shown in the UI; also enforced if the bag has a weight limit.
@export_range(0.0, 20.0, 0.1, "suffix:kg") var weight: float = 0.5
## How many of this item fit in one inventory slot.
@export_range(1, 99) var max_stack: int = 3
## Free-form grouping for Part 2 (water / food / medical / tool / document).
@export var category: StringName = &"supply"
## Inventory slots one unit takes (in the hands and on the boat). A family member takes 2.
@export_range(1, 4) var slot_size: int = 1
## Optional picture used while the thing is in the house (e.g. a seated person) instead of the icon.
@export var world_texture: Texture2D
## For family members: the SurvivorData id they become in Part 2 ("mother", ...).
@export var survivor_id: StringName = &""


func is_person() -> bool:
	return category == &"person"


func get_display_name() -> String:
	return name_th if not name_th.is_empty() else name_en
