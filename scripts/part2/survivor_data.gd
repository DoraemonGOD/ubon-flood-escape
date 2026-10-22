class_name SurvivorData
extends Resource
## One person on the boat. The .tres files in res://resources/part2/survivors/
## are templates; SurvivalState works on duplicate() copies, so values that change
## during play (thirst, sickness...) never modify the files.

enum Condition { HEALTHY, SICK, INJURED, DEAD }

@export var id: StringName
@export var display_name: String
## Short description used in text ("แม่ของคุณ").
@export var role_text: String
## idle (2 frames, loops) and look (1 frame) animations.
@export var sprite_frames: SpriteFrames

@export_group("Runtime (changes during play)")
@export var condition: Condition = Condition.HEALTHY
## Days in a row without water / food. Reset to 0 when given a ration.
@export var thirst_days: int = 0
@export var hunger_days: int = 0
## Days spent sick / injured (for death and recovery rules).
@export var condition_days: int = 0
## True while out on an expedition.
@export var away: bool = false


func is_alive() -> bool:
	return condition != Condition.DEAD


## On the boat and alive (can eat, drink, be shown).
func is_present() -> bool:
	return is_alive() and not away


func needs_medicine() -> bool:
	return condition == Condition.SICK or condition == Condition.INJURED
