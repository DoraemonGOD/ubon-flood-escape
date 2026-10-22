extends Node
## Autoload "GameState": which phase the game is in and scene switching.
## The bag contents live in the "Inventory" autoload.

enum Phase { MENU, SCAVENGING, SUMMARY, SURVIVAL }

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const SCAVENGING_SCENE := "res://scenes/scavenging/scavenging.tscn"
const SUMMARY_SCENE := "res://scenes/summary/summary.tscn"
const INTRO_SCENE := "res://scenes/cutscene/intro_cutscene.tscn"
## First Part 2 scene. The summary's "ออกเดินทาง (Part 2)" button enables itself when this exists.
const PART_2_SCENE := "res://scenes/part2/survival.tscn"

var phase: Phase = Phase.MENU
## Result of the last scavenging run, read by the summary screen.
var last_time_left: float = 0.0
var last_duration: float = 0.0
## Items still in the player's hands when time ran out (never reached the boat).
var last_undelivered: int = 0
## True once a scavenging run ended — Part 2 then trusts the Inventory as real Part 1 data.
var part1_completed: bool = false
## Family members (SurvivorData ids) who reached the boat in Part 1 / who were left in the house.
var rescued_family: Array[StringName] = []
var left_behind: Array[StringName] = []
## Old count-based hook (0 = use the list above). Kept for tools/tests.
var survivors_from_part1: int = 0


## New run from Part 1. show_intro = play the TV-news cutscene first (main menu "เริ่มเกม").
func start_new_game(show_intro: bool = false) -> void:
	get_tree().paused = false
	Inventory.reset()
	BoatCargo.reset()
	SurvivalState.reset()
	last_time_left = 0.0
	last_undelivered = 0
	part1_completed = false
	rescued_family.clear()
	left_behind.clear()
	if show_intro:
		phase = Phase.MENU
		get_tree().change_scene_to_file(INTRO_SCENE)
	else:
		begin_scavenging()


## Called when the intro cutscene ends (or is skipped).
func begin_scavenging() -> void:
	get_tree().paused = false
	phase = Phase.SCAVENGING
	get_tree().change_scene_to_file(SCAVENGING_SCENE)


func finish_scavenging(time_left: float, duration: float, undelivered: int = 0) -> void:
	get_tree().paused = false
	last_undelivered = undelivered
	part1_completed = true
	rescued_family.clear()
	left_behind.clear()
	for member in ItemDatabase.get_family():
		if Inventory.get_item_count(member.id) > 0:
			rescued_family.append(member.survivor_id)
		else:
			left_behind.append(member.survivor_id)
	last_time_left = time_left
	last_duration = duration
	phase = Phase.SUMMARY
	get_tree().change_scene_to_file(SUMMARY_SCENE)


func go_to_main_menu() -> void:
	get_tree().paused = false
	phase = Phase.MENU
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func has_part_2() -> bool:
	return not PART_2_SCENE.is_empty() and ResourceLoader.exists(PART_2_SCENE)


## Part 2 entry point after the summary. Inventory is NOT reset: it is the boat's supplies.
func go_to_part_2() -> void:
	if not has_part_2():
		push_warning("Part 2 scene is not set yet (GameState.PART_2_SCENE).")
		return
	get_tree().paused = false
	# People ride along as survivors, not as cargo: free their boat slots first.
	for member in ItemDatabase.get_family():
		Inventory.remove_item(member.id, Inventory.get_item_count(member.id))
	SurvivalState.reset()
	if survivors_from_part1 > 0:
		SurvivalState.start_from_part1(survivors_from_part1)
	else:
		SurvivalState.start_with_family(rescued_family)
	phase = Phase.SURVIVAL
	get_tree().change_scene_to_file(PART_2_SCENE)


## Test entry (main menu button): Part 2 with default sample data, no Part 1 needed.
func start_part_2_test() -> void:
	get_tree().paused = false
	Inventory.reset()
	BoatCargo.reset()
	part1_completed = false
	SurvivalState.reset()
	SurvivalState.start_with_default_data()
	phase = Phase.SURVIVAL
	get_tree().change_scene_to_file(PART_2_SCENE)


static func format_time(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]
