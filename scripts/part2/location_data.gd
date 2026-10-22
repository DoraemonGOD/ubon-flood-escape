class_name LocationData
extends Resource
## A place the boat can drift to on a voyage (every few days).
## Files: res://resources/part2/locations/*.tres

@export var id: StringName
@export var name_th: String
## Shown when choosing where to paddle next.
@export_multiline var description: String
## What floats by during the voyage minigame here: item id -> weight.
@export var loot_table: Dictionary = {}
## Obstacle sprites used in the voyage minigame (paths).
@export var obstacles: PackedStringArray = []
