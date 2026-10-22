class_name ChoiceOutcome
extends Resource
## One possible result of an EventChoice. Its text is written into the NEXT
## day's journal (like reading what happened overnight).

enum Target { NONE, SUBJECT, RANDOM, ALL }

@export var id: StringName
## Relative chance among the outcomes of one choice.
@export_range(0, 100) var weight: int = 1
## Journal lines for tomorrow. Placeholders: {subject}, {player}.
@export_multiline var journal_lines: Array[String] = []

@export_group("Effects")
## Item id -> change, e.g. {"water": 2, "canned_food": -1}.
@export var supply_changes: Dictionary = {}
## Lose this many random supply units (swept overboard, stolen...).
@export var lose_random_supplies: int = 0
## Who gets `condition` (SUBJECT = the person the event is about).
@export var condition_target: Target = Target.NONE
@export var condition: SurvivorData.Condition = SurvivorData.Condition.HEALTHY
## Everyone present goes this many extra days without food (hard night...).
@export var extra_hunger_days: int = 0
## Nights protected from rain sickness.
@export var shelter_nights: int = 0
## Story flags to set, e.g. "registered", "knows_signal".
@export var set_flags: PackedStringArray = []
## "" = game goes on. "rescued" / "reached_center" end Part 2.
@export var ending: StringName = &""
