class_name SurvivalRules
extends Resource
## Every balancing number of the survival phase in one place
## (res://resources/part2/survival_rules.tres). Change difficulty here.

@export_group("Needs")
## Days without water before the person dies.
@export var thirst_death_days: int = 6
@export var thirst_warning_days: int = 2
## Days without food before the person dies.
@export var hunger_death_days: int = 9
@export var hunger_warning_days: int = 3
## Sick / injured for this many days without medicine -> dies.
@export var sick_death_days: int = 5
@export var injured_death_days: int = 8
## Chance per night to get better alone (only if they had water that day).
@export_range(0.0, 1.0) var natural_recovery_chance: float = 0.15
## Chance per rainy night without shelter that someone falls sick.
@export_range(0.0, 1.0) var rain_sickness_chance: float = 0.12

@export_group("Devices")
@export var flashlight_start_charge: int = 3
@export var radio_start_charge: int = 2
## Charge gained from one battery.
@export var battery_charge: int = 3

@export_group("Expedition")
@export var expedition_days: int = 2
## Base chances (percent): find supplies / nothing / injured / lost.
@export var expedition_find: int = 55
@export var expedition_nothing: int = 20
@export var expedition_injured: int = 15
@export var expedition_lost: int = 10
## Item id -> weight for what is found.
@export var loot_table: Dictionary = {"water": 30, "canned_food": 30, "medicine": 14, "batteries": 16, "rope": 5, "flashlight": 5}

@export_group("Days")
## Chance a day has no event.
@export_range(0.0, 1.0) var quiet_day_chance: float = 0.2
## The water recedes on this day: the family can paddle to the evacuation centre.
@export var final_day: int = 30
## Radio broadcasts needed to learn how the rescue boats search.
@export var broadcasts_for_signal: int = 4

@export_group("Voyage minigame")
## A voyage can be made every N days (day 3, 6, 9 ...).
@export var voyage_every: int = 3
## Things that float by in one voyage.
@export var voyage_spawns: int = 10
## Chance a spawn is an obstacle instead of an item.
@export_range(0.0, 1.0) var voyage_obstacle_chance: float = 0.3
## Seconds to press the right key once the prompt shows (rope adds voyage_rope_bonus).
@export var voyage_window: float = 1.1
@export var voyage_rope_bonus: float = 0.35

@export_group("Radio")
## One broadcast per listen, in order; the last one repeats.
## Hearing `broadcasts_for_signal` of them teaches you to signal rescue boats with light.
@export_multiline var radio_news: Array[String] = []
