class_name EventData
extends Resource

## When the event happens — also sets the background (AUTO = the day's normal rhythm).
enum TimeOfDay { AUTO = -1, DAWN, DAY, DUSK, NIGHT }
## A daily event in the journal. All events are .tres files in
## res://resources/part2/events/ and are picked automatically by SurvivalState.

@export var id: StringName
@export var title: String
## Placeholders: {subject} (random person the event is about), {player}.
@export_multiline var text: String
@export var choices: Array[EventChoice] = []
## Used when the player ends the day without choosing.
@export var default_choice: int = 0

@export_group("When can it happen")
@export var min_day: int = 1
@export var max_day: int = 99
@export_range(0, 100) var weight: int = 10
## Happens at most once per game.
@export var once: bool = true
## All of these flags must be set.
@export var required_flags: PackedStringArray = []
## None of these flags may be set.
@export var blocked_flags: PackedStringArray = []
## Picks a random person on the boat as {subject}.
@export var has_subject: bool = false
## Only at these locations (ids from res://resources/part2/locations/). Empty = anywhere.
@export var locations: PackedStringArray = []
@export var time_of_day: TimeOfDay = TimeOfDay.AUTO
