extends Node
## Autoload "SurvivalState": the survival phase of Part 2 — one journal page per day.
##
## Each day the player:
##   1. reads the journal (what happened last night)            -> journal
##   2. decides who gets water / food / medicine                -> set_ration()
##   3. answers today's event (some answers need an item)       -> choose()
##   4. may send someone on an expedition with gear             -> plan_expedition()
##   5. ends the day                                            -> end_day()
## end_day() applies everything, writes tomorrow's journal and picks tomorrow's event.
##
## Data ownership: supplies live ONLY in the "Inventory" autoload (what reached the boat
## in Part 1). Everything else lives here. UI reads, never stores.

signal state_changed
signal day_started(day: int)
signal game_ended(ending: StringName)

enum Weather { CLEAR, LIGHT_RAIN, HEAVY_RAIN, STORM }

const WEATHER_NAMES := {
	Weather.CLEAR: "CLEAR", Weather.LIGHT_RAIN: "LIGHT RAIN",
	Weather.HEAVY_RAIN: "HEAVY RAIN", Weather.STORM: "STORM",
}
const WEATHER_TH := {
	Weather.CLEAR: "ฟ้าเปิด", Weather.LIGHT_RAIN: "ฝนปรอย",
	Weather.HEAVY_RAIN: "ฝนตกหนัก", Weather.STORM: "พายุ",
}
const ROSTER: Array[SurvivorData] = [
	preload("res://resources/part2/survivors/player.tres"),
	preload("res://resources/part2/survivors/mother.tres"),
	preload("res://resources/part2/survivors/sister.tres"),
	preload("res://resources/part2/survivors/grandpa.tres"),
]
const RULES: SurvivalRules = preload("res://resources/part2/survival_rules.tres")
const EVENTS_DIR := "res://resources/part2/events/"
const LOCATIONS_DIR := "res://resources/part2/locations/"
const START_LOCATION := &"village"
## Ending id -> title. Conditions are written on the events that set them (see the game doc).
const ENDINGS := {
	&"rescued_signal": "เรือกู้ภัยเห็นแสงไฟ",
	&"rescued_registered": "ชื่อในบัญชีผู้ประสบภัย",
	&"rescued_boat": "เรือกู้ภัยที่แล่นผ่าน",
	&"rescued_air": "เฮลิคอปเตอร์กู้ภัย",
	&"temple_shelter": "เรือของวัด",
	&"army_evac": "รถอพยพบนสะพาน",
	&"reached_center": "น้ำลด — ถึงศูนย์อพยพ",
	&"all_dead": "ไม่มีใครรอด",
}
## The background's time of day (same values as EventData.TimeOfDay).
enum TimeOfDay { DAWN, DAY, DUSK, NIGHT }
const FINAL_EVENT := &"water_recedes"
const DEVICES: Array[StringName] = [&"flashlight", &"radio"]
## Items that can be taken on an expedition (they leave the boat until the person returns).
const EXPEDITION_GEAR: Array[StringName] = [&"flashlight", &"rope"]
const DEFAULT_SURVIVOR_COUNT := 2
const BOAT_HOLD_SLOTS := 16
## Used ONLY when there is no Part 1 data (scene opened directly / test button).
const DEFAULT_SUPPLIES: Array[Dictionary] = [
	{"id": "water", "count": 3},
	{"id": "canned_food", "count": 3},
	{"id": "medicine", "count": 1},
	{"id": "flashlight", "count": 1},
	{"id": "batteries", "count": 2},
	{"id": "rope", "count": 1},
	{"id": "radio", "count": 1},
]

var rules: SurvivalRules = RULES
var events: Array[EventData] = []
var locations: Dictionary = {} ## id -> LocationData

var is_started := false
var used_default_data := false
var day := 1
var weather: Weather = Weather.HEAVY_RAIN
var survivors: Array[SurvivorData] = []
## Story flags -> day they were set, e.g. {"registered": 4}
var flags: Dictionary = {}
var ending: StringName = &""
var shelter_nights := 0
var location: StringName = START_LOCATION
var time_of_day: TimeOfDay = TimeOfDay.NIGHT
## Destination picked for today's voyage ("" = staying). The minigame runs before the night.
var voyage_destination: StringName = &""
## Day of the last voyage made.
var last_voyage_day := 0
## Power left in devices (uses). A battery is inserted automatically when it runs out.
var charge := {&"flashlight": 0, &"radio": 0}
var broadcasts_heard := 0

## --- today's page
var journal: Array[String] = []
var current_event: EventData
var current_subject: SurvivorData
var chosen_choice := -1
var radio_used_today := false
## survivor id -> {"water": bool, "food": bool, "medicine": bool}
var rations: Dictionary = {}
## {"member": SurvivorData, "gear": Array[StringName]} — leaves tonight
var expedition_plan: Dictionary = {}
## {"member": SurvivorData, "gear": Array[StringName], "return_day": int} — currently out
var expedition: Dictionary = {}
## [{"day": 3, "event": &"storm", "choice": 1, "outcome": &"storm_tied"}]
var history: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()
## Testing hooks: force the next picked outcome index / tomorrow's event id.
var force_outcome := -1
var force_event: StringName = &""

var _used_events: Dictionary = {}
var _voyage_lines: Array[String] = []
## Who is on the boat besides the player (SurvivorData ids), kept for restart_survival().
var _member_ids: Array[StringName] = []
var _start_snapshot: Array[Dictionary] = []


func _ready() -> void:
	_load_events()
	for file in DirAccess.get_files_at(LOCATIONS_DIR):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var loc := load(LOCATIONS_DIR + file) as LocationData
			if loc:
				locations[loc.id] = loc


func _load_events() -> void:
	events.clear()
	for file in DirAccess.get_files_at(EVENTS_DIR):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var ev := load(EVENTS_DIR + file) as EventData
			if ev:
				events.append(ev)


func get_event(id: StringName) -> EventData:
	for ev in events:
		if ev.id == id:
			return ev
	return null


# =================================================================== start / reset
## Clears all Part 2 progress (does not touch the Inventory).
func reset() -> void:
	is_started = false
	used_default_data = false
	survivors.clear()
	flags.clear()
	ending = &""
	location = START_LOCATION
	voyage_destination = &""
	journal.clear()
	history.clear()
	current_event = null
	expedition.clear()
	expedition_plan.clear()
	rations.clear()
	_used_events.clear()
	force_outcome = -1
	force_event = &""
	state_changed.emit()


## Starts with whatever Part 1 put on the boat (may be empty). survivor_count <= 0 = default.
func start_from_part1(survivor_count: int = 0) -> void:
	var count := survivor_count if survivor_count > 0 else DEFAULT_SURVIVOR_COUNT
	var ids: Array[StringName] = []
	for i in range(1, mini(count, ROSTER.size())):
		ids.append(ROSTER[i].id)
	start_with_family(ids)


## Starts with Part 1's supplies and exactly the family members who reached the boat
## (the player is always there). An empty list = the player alone.
func start_with_family(member_ids: Array[StringName]) -> void:
	used_default_data = false
	Inventory.max_slots = maxi(Inventory.max_slots, BOAT_HOLD_SLOTS)
	_begin(member_ids)


## Starts with sample supplies (no Part 1 run needed).
func start_with_default_data() -> void:
	Inventory.configure(BOAT_HOLD_SLOTS)
	Inventory.load_save_data(DEFAULT_SUPPLIES)
	used_default_data = true
	_begin([ROSTER[1].id] as Array[StringName])


## Called by the survival scene: makes sure there is data to show.
func ensure_started() -> void:
	if is_started:
		return
	if GameState.part1_completed and GameState.survivors_from_part1 > 0:
		start_from_part1(GameState.survivors_from_part1)
	elif GameState.part1_completed:
		start_with_family(GameState.rescued_family)
	else:
		start_with_default_data()


## Tries again from day 1 with the same people and supplies Part 2 started with.
func restart_survival() -> void:
	Inventory.load_save_data(_start_snapshot)
	_begin(_member_ids.duplicate())


func _begin(member_ids: Array[StringName]) -> void:
	_member_ids = member_ids
	_start_snapshot = Inventory.to_save_data()
	day = 1
	weather = Weather.HEAVY_RAIN
	flags.clear()
	ending = &""
	shelter_nights = 0
	broadcasts_heard = 0
	location = START_LOCATION
	voyage_destination = &""
	last_voyage_day = 0
	history.clear()
	expedition.clear()
	_used_events.clear()
	survivors.clear()
	for i in ROSTER.size():
		if i == 0 or _member_ids.has(ROSTER[i].id):
			survivors.append(ROSTER[i].duplicate())
	for device in DEVICES:
		charge[device] = _start_charge(device) if Inventory.get_item_count(device) > 0 else 0
	is_started = true
	_start_day(["วันแรกบนเรือ ฝนยังตกหนัก ทุกคนเปียกโชกและเงียบงัน", "เราต้องประคองเสบียงที่มีให้อยู่ได้นานที่สุด จนกว่าจะมีคนมาช่วย"])


# ======================================================================== queries
func get_alive() -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	for s in survivors:
		if s.is_alive():
			result.append(s)
	return result


func get_present() -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	for s in survivors:
		if s.is_present():
			result.append(s)
	return result


func get_survivor_count() -> int:
	return get_alive().size()


func get_survivor(id: StringName) -> SurvivorData:
	for s in survivors:
		if s.id == id:
			return s
	return null


func get_weather_name() -> String:
	return WEATHER_NAMES[weather]


func get_weather_th() -> String:
	return WEATHER_TH[weather]


func get_supply_count(id: StringName) -> int:
	return Inventory.get_item_count(id)


## [{"item": ItemData, "count": int}, ...] — only items you have, in ItemDatabase order.
func get_supplies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in ItemDatabase.get_all_items():
		var count := Inventory.get_item_count(item.id)
		if count > 0:
			result.append({"item": item, "count": count})
	return result


func get_food() -> int:
	return _count_category(&"food")


func get_water() -> int:
	return _count_category(&"water")


func _count_category(category: StringName) -> int:
	var total := 0
	for entry in get_supplies():
		if entry.item.category == category:
			total += entry.count
	return total


func is_finished() -> bool:
	return ending != &""


func get_location() -> LocationData:
	return locations.get(location)


func get_ending_title(id: StringName = ending) -> String:
	return ENDINGS.get(id, String(id))


## 0 = normal level, 1 = peak. Rises to the peak around day 9, stays, then falls to 0 on the final day.
func get_water_level() -> float:
	var peak_start := 9.0
	var peak_end := 15.0
	if day <= peak_start:
		return lerpf(0.55, 1.0, (day - 1) / (peak_start - 1))
	if day <= peak_end:
		return 1.0
	return clampf(1.0 - (day - peak_end) / float(rules.final_day - peak_end), 0.0, 1.0)


# ===================================================================== voyage
## A voyage is possible every rules.voyage_every days.
func is_voyage_day() -> bool:
	return day % rules.voyage_every == 0 and not is_finished()


## ...and only when nobody is out exploring (they would be left behind).
func can_voyage() -> bool:
	return is_voyage_day() and expedition.is_empty() and expedition_plan.is_empty() and last_voyage_day != day and not get_present().is_empty()


func next_voyage_day() -> int:
	return (day / rules.voyage_every + 1) * rules.voyage_every


func voyage_options() -> Array[LocationData]:
	var result: Array[LocationData] = []
	for id in locations:
		if id != location:
			result.append(locations[id])
	return result


## Pick where to paddle today ("" = stay). The minigame plays when the day ends.
func plan_voyage(destination: StringName) -> bool:
	if destination == &"":
		voyage_destination = &""
		state_changed.emit()
		return true
	if not can_voyage() or not locations.has(destination) or destination == location:
		return false
	voyage_destination = destination
	state_changed.emit()
	return true


## Minigame: an item was grabbed from the water.
func voyage_collect(id: StringName) -> void:
	_change_supply(id, 1)
	state_changed.emit()


## Minigame: the boat hit an obstacle. Returns what happened (for the result screen).
func voyage_hit() -> String:
	if rng.randf() < 0.5 and not get_supplies().is_empty():
		var lost := _lose_random_supplies(1)
		state_changed.emit()
		return "ของตกน้ำ: " + ", ".join(lost)
	var s := _random_present()
	if s == null:
		return ""
	_set_condition(s, SurvivorData.Condition.INJURED)
	state_changed.emit()
	return "%s บาดเจ็บ" % s.display_name


## Called after the minigame: the boat arrives at the destination.
func complete_voyage(collected: PackedStringArray, hits: PackedStringArray) -> void:
	if voyage_destination == &"":
		return
	var dest: LocationData = locations[voyage_destination]
	location = voyage_destination
	voyage_destination = &""
	last_voyage_day = day
	var line := "เราพายเรือมาถึง%s" % dest.name_th
	if not collected.is_empty():
		line += " ระหว่างทางเก็บได้: " + ", ".join(collected)
	_voyage_lines.append(line)
	for h in hits:
		if h != "":
			_voyage_lines.append("ระหว่างทางเรือชนสิ่งกีดขวาง — " + h)
	state_changed.emit()


# ==================================================================== devices
func is_device(id: StringName) -> bool:
	return DEVICES.has(id)


## True if the item is on the boat and (for devices) has power or a spare battery.
func can_use_item(id: StringName) -> bool:
	if id == &"":
		return true
	if Inventory.get_item_count(id) <= 0:
		return false
	if is_device(id):
		return charge[id] > 0 or Inventory.get_item_count(&"batteries") > _reserved(&"batteries")
	return Inventory.get_item_count(id) > _reserved(id)


## Uses one charge of a device, inserting a battery if needed. Returns false if impossible.
func use_device(id: StringName, notes: Array[String] = []) -> bool:
	if Inventory.get_item_count(id) <= 0:
		return false
	if charge[id] <= 0:
		if Inventory.remove_item(&"batteries", 1) == 0:
			return false
		charge[id] += rules.battery_charge
		notes.append("ใส่ถ่านก้อนใหม่ให้%s" % ItemDatabase.get_item(id).name_th)
	charge[id] -= 1
	return true


func _start_charge(id: StringName) -> int:
	return rules.flashlight_start_charge if id == &"flashlight" else rules.radio_start_charge


# ================================================================ today's choices
## Water/food/medicine for one person tonight. Returns false if it can't be given.
func set_ration(survivor: SurvivorData, kind: String, on: bool) -> bool:
	if survivor == null or not survivor.is_present() or is_finished():
		return false
	var entry: Dictionary = rations.get(survivor.id, {"water": false, "food": false, "medicine": false})
	if on and not entry[kind]:
		if kind == "medicine" and not survivor.needs_medicine():
			return false
		if available(_ration_item(kind)) <= 0:
			return false
	entry[kind] = on
	rations[survivor.id] = entry
	state_changed.emit()
	return true


func get_ration(survivor: SurvivorData, kind: String) -> bool:
	return rations.get(survivor.id, {}).get(kind, false)


## Units of an item still free after tonight's planned rations and event choice.
func available(id: StringName) -> int:
	return Inventory.get_item_count(id) - _reserved(id)


func _reserved(id: StringName) -> int:
	var n := 0
	for entry in rations.values():
		for kind in entry:
			if entry[kind] and _ration_item(kind) == id:
				n += 1
	if current_event and chosen_choice >= 0:
		var c := current_event.choices[chosen_choice]
		if c.consumes_item and c.required_item == id:
			n += 1
	return n


func _ration_item(kind: String) -> StringName:
	match kind:
		"water":
			return &"water"
		"food":
			return &"canned_food"
	return &"medicine"


func can_choose(index: int) -> bool:
	if current_event == null or index < 0 or index >= current_event.choices.size() or is_finished():
		return false
	var c := current_event.choices[index]
	if c.required_survivor != &"":
		var who := get_survivor(c.required_survivor)
		if who == null or not who.is_present() or who.condition != SurvivorData.Condition.HEALTHY:
			return false
	if c.required_flag != "" and not flags.has(c.required_flag):
		return false
	if c.required_item == &"" or index == chosen_choice:
		return true
	if c.consumes_item:
		return available(c.required_item) > 0
	return can_use_item(c.required_item)


func choose(index: int) -> bool:
	if not can_choose(index):
		return false
	chosen_choice = index
	state_changed.emit()
	return true


## Who can go out: present, healthy, not too thirsty/hungry, and not the last one on board.
func can_send_on_expedition(survivor: SurvivorData) -> bool:
	return survivor != null and survivor.is_present() and survivor.condition == SurvivorData.Condition.HEALTHY \
		and survivor.thirst_days < rules.thirst_death_days - 2 and survivor.hunger_days < rules.hunger_death_days - 3 \
		and expedition.is_empty() and get_present().size() >= 2 and not is_finished() and voyage_destination == &""


## member = null cancels. Gear = items taken along (flashlight / rope).
func plan_expedition(member: SurvivorData, gear: Array[StringName] = []) -> bool:
	if member == null:
		expedition_plan.clear()
		state_changed.emit()
		return true
	if not can_send_on_expedition(member):
		return false
	var taken: Array[StringName] = []
	for g in gear:
		if EXPEDITION_GEAR.has(g) and Inventory.get_item_count(g) > 0:
			taken.append(g)
	expedition_plan = {"member": member, "gear": taken}
	state_changed.emit()
	return true


func can_listen_radio() -> bool:
	return not radio_used_today and can_use_item(&"radio") and not is_finished()


## Listens to today's broadcast right away. Returns the text ("" if impossible).
func listen_radio() -> String:
	if not can_listen_radio():
		return ""
	var notes: Array[String] = []
	use_device(&"radio", notes)
	radio_used_today = true
	var news := rules.radio_news
	var text := news[mini(broadcasts_heard, news.size() - 1)] if not news.is_empty() else ""
	broadcasts_heard += 1
	var lines: Array[String] = notes.duplicate()
	lines.append("วิทยุ: " + text)
	if broadcasts_heard >= rules.broadcasts_for_signal and not flags.has("knows_signal"):
		flags["knows_signal"] = day
		lines.append("ถ้าได้ยินเรือกู้ภัยตอนกลางคืน เราต้องส่งสัญญาณไฟให้เขาเห็น!")
	journal.append_array(lines)
	state_changed.emit()
	return "\n".join(lines)


# ======================================================================= end day
## Applies tonight: rations, event, expedition, health, weather. Then starts tomorrow.
func end_day() -> void:
	if not is_started or is_finished():
		return
	var lines: Array[String] = []
	lines.append_array(_voyage_lines)
	_voyage_lines.clear()
	voyage_destination = &""
	_apply_rations(lines)
	_resolve_event(lines)
	_progress_expedition(lines)
	_depart_expedition(lines)
	_night_health(lines)
	shelter_nights = maxi(shelter_nights - 1, 0)
	_change_weather()
	if ending == &"" and get_alive().is_empty():
		ending = &"all_dead"
	if ending != &"":
		journal = lines
		state_changed.emit()
		game_ended.emit(ending)
		return
	day += 1
	_start_day(lines)


func _start_day(lines: Array[String]) -> void:
	_voyage_lines.clear()
	voyage_destination = &""
	rations.clear()
	chosen_choice = -1
	expedition_plan.clear()
	radio_used_today = false
	journal = lines
	journal.append_array(_status_lines())
	_pick_event()
	day_started.emit(day)
	state_changed.emit()


func _apply_rations(lines: Array[String]) -> void:
	for s in get_present():
		var r: Dictionary = rations.get(s.id, {})
		if r.get("water", false) and Inventory.remove_item(&"water", 1) == 1:
			s.thirst_days = 0
		else:
			s.thirst_days += 1
		if r.get("food", false) and Inventory.remove_item(&"canned_food", 1) == 1:
			s.hunger_days = 0
		else:
			s.hunger_days += 1
		if r.get("medicine", false) and s.needs_medicine() and Inventory.remove_item(&"medicine", 1) == 1:
			s.condition = SurvivorData.Condition.HEALTHY
			s.condition_days = 0
			lines.append("%s ทานยาแล้ว อาการดีขึ้นมาก" % s.display_name)


func _resolve_event(lines: Array[String]) -> void:
	if current_event == null:
		return
	var index := chosen_choice
	if not can_choose(index):
		index = current_event.default_choice if can_choose(current_event.default_choice) else 0
	var c := current_event.choices[index]
	if c.required_item != &"":
		if c.consumes_item:
			Inventory.remove_item(c.required_item, 1) # traded / used up (devices too)
		elif is_device(c.required_item):
			use_device(c.required_item, lines)
	var outcome := _pick_outcome(c)
	if outcome == null:
		return
	history.append({"day": day, "event": current_event.id, "choice": index, "outcome": outcome.id})
	_apply_outcome(outcome, lines)


func _pick_outcome(c: EventChoice) -> ChoiceOutcome:
	if c.outcomes.is_empty():
		return null
	if force_outcome >= 0:
		var forced := c.outcomes[clampi(force_outcome, 0, c.outcomes.size() - 1)]
		force_outcome = -1
		return forced
	var total := 0
	for o in c.outcomes:
		total += maxi(o.weight, 0)
	var roll := rng.randi_range(1, maxi(total, 1))
	for o in c.outcomes:
		roll -= maxi(o.weight, 0)
		if roll <= 0:
			return o
	return c.outcomes.back()


func _apply_outcome(o: ChoiceOutcome, lines: Array[String]) -> void:
	var target: SurvivorData = null
	match o.condition_target:
		ChoiceOutcome.Target.SUBJECT:
			target = current_subject if current_subject and current_subject.is_alive() else null
		ChoiceOutcome.Target.RANDOM:
			target = _random_present()
	var all_targets: Array[SurvivorData] = []
	if o.condition_target == ChoiceOutcome.Target.ALL:
		all_targets = get_present()
	elif target:
		all_targets.append(target)
	for t in all_targets:
		_set_condition(t, o.condition)
	for line in o.journal_lines:
		lines.append(_format(line, target))
	for id in o.supply_changes:
		_change_supply(StringName(id), int(o.supply_changes[id]))
	if o.lose_random_supplies > 0:
		var lost := _lose_random_supplies(o.lose_random_supplies)
		if not lost.is_empty():
			lines.append("ของที่เสียไป: " + ", ".join(lost))
	for s in get_present():
		s.hunger_days = maxi(s.hunger_days + o.extra_hunger_days, 0)
	shelter_nights = maxi(shelter_nights, o.shelter_nights)
	for f in o.set_flags:
		flags[f] = day
	if o.ending != &"":
		ending = o.ending


func _set_condition(s: SurvivorData, condition: SurvivorData.Condition) -> void:
	if s == null or not s.is_alive():
		return
	if s.condition != condition:
		s.condition_days = 0
	s.condition = condition


func _change_supply(id: StringName, delta: int) -> void:
	var item := ItemDatabase.get_item(id)
	if item == null or delta == 0:
		return
	if delta > 0:
		if is_device(id) and Inventory.get_item_count(id) == 0:
			charge[id] = _start_charge(id)
		Inventory.add_item(item, delta)
	else:
		Inventory.remove_item(id, -delta)


## Removes random single units; returns their Thai names.
func _lose_random_supplies(count: int) -> PackedStringArray:
	var names: PackedStringArray = []
	for i in count:
		var pool: Array[ItemData] = []
		for entry in get_supplies():
			pool.append(entry.item)
		if pool.is_empty():
			break
		var item := pool[rng.randi_range(0, pool.size() - 1)]
		Inventory.remove_item(item.id, 1)
		names.append(item.name_th)
	return names


func _depart_expedition(lines: Array[String]) -> void:
	if expedition_plan.is_empty() or not expedition.is_empty():
		return
	var member: SurvivorData = expedition_plan.member
	if not can_send_on_expedition(member):
		return
	var gear: Array[StringName] = []
	for g: StringName in expedition_plan.gear:
		if Inventory.remove_item(g, 1) == 1:
			gear.append(g)
	member.away = true
	expedition = {"member": member, "gear": gear, "return_day": day + rules.expedition_days}
	var gear_text := ""
	if not gear.is_empty():
		var names: PackedStringArray = []
		for g in gear:
			names.append(ItemDatabase.get_item(g).name_th)
		gear_text = " พร้อม" + " และ".join(names)
	lines.append("%s เกาะห่วงยางว่ายออกไปสำรวจบ้านแถวนี้%s" % [member.display_name, gear_text])


func _progress_expedition(lines: Array[String]) -> void:
	if expedition.is_empty() or day + 1 < expedition.return_day:
		return
	var member: SurvivorData = expedition.member
	var gear: Array[StringName] = expedition.gear
	var weights := [rules.expedition_find, rules.expedition_nothing, rules.expedition_injured, rules.expedition_lost]
	if gear.has(&"flashlight"):
		weights[0] += 15
		weights[1] = maxi(weights[1] - 15, 0)
	if gear.has(&"rope"):
		weights[2] += weights[3] / 2
		weights[3] = 0
	var result := force_outcome if force_outcome >= 0 else _weighted_index(weights)
	force_outcome = -1
	expedition.clear()
	member.away = false
	var lost_gear: Array[StringName] = []
	match result:
		0:
			var found := _roll_loot(rng.randi_range(1, 3) + (1 if gear.has(&"flashlight") else 0))
			lines.append("%s กลับมาแล้ว! พร้อมของที่หาได้: %s" % [member.display_name, ", ".join(found)])
		1:
			lines.append("%s กลับมามือเปล่า บ้านแถวนั้นถูกน้ำท่วมจนไม่เหลืออะไร" % member.display_name)
		2:
			_set_condition(member, SurvivorData.Condition.INJURED)
			var found := _roll_loot(1)
			lines.append("%s กลับมาพร้อมแผลที่ขา แต่ก็ยังหิ้ว%sกลับมาได้" % [member.display_name, found[0] if not found.is_empty() else "ของ"])
			for g in gear:
				if rng.randf() < 0.3:
					lost_gear.append(g)
		_:
			member.away = true
			member.condition = SurvivorData.Condition.DEAD
			lines.append("%s ไม่กลับมาอีกเลย... เรารอจนมืดค่ำ" % member.display_name)
			lost_gear = gear.duplicate()
	for g in gear:
		if lost_gear.has(g):
			if result != 3:
				lines.append("%sหายไประหว่างทาง" % ItemDatabase.get_item(g).name_th)
		else:
			Inventory.add_item(ItemDatabase.get_item(g), 1)


func _roll_loot(count: int) -> PackedStringArray:
	var ids: Array = rules.loot_table.keys()
	var weights: Array = rules.loot_table.values()
	var names: PackedStringArray = []
	for i in count:
		var id := StringName(ids[_weighted_index(weights)])
		_change_supply(id, 1)
		names.append(ItemDatabase.get_item(id).name_th)
	return names


func _weighted_index(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += maxi(int(w), 0)
	var roll := rng.randi_range(1, maxi(total, 1))
	for i in weights.size():
		roll -= maxi(int(weights[i]), 0)
		if roll <= 0:
			return i
	return weights.size() - 1


func _night_health(lines: Array[String]) -> void:
	var rainy := weather == Weather.HEAVY_RAIN or weather == Weather.STORM
	if rainy and shelter_nights == 0 and rng.randf() < rules.rain_sickness_chance:
		var healthy := get_present().filter(func(s: SurvivorData) -> bool: return s.condition == SurvivorData.Condition.HEALTHY)
		if not healthy.is_empty():
			var s: SurvivorData = healthy[rng.randi_range(0, healthy.size() - 1)]
			_set_condition(s, SurvivorData.Condition.SICK)
			lines.append("%s ตากฝนทั้งคืนจนเริ่มไม่สบาย" % s.display_name)
	for s in get_present():
		if s.needs_medicine():
			s.condition_days += 1
			var limit := rules.sick_death_days if s.condition == SurvivorData.Condition.SICK else rules.injured_death_days
			if s.thirst_days == 0 and rng.randf() < rules.natural_recovery_chance:
				s.condition = SurvivorData.Condition.HEALTHY
				s.condition_days = 0
				lines.append("%s อาการดีขึ้นเองแล้ว" % s.display_name)
			elif s.condition_days >= limit:
				_die(s, "อาการทรุดหนักและจากไปในคืนนั้น", lines)
				continue
		if s.thirst_days >= rules.thirst_death_days:
			_die(s, "ขาดน้ำจนหมดแรงและจากไปในคืนนั้น", lines)
		elif s.hunger_days >= rules.hunger_death_days:
			_die(s, "อดอาหารมานานเกินไป และจากไปในคืนนั้น", lines)


func _die(s: SurvivorData, reason: String, lines: Array[String]) -> void:
	s.condition = SurvivorData.Condition.DEAD
	lines.append("%s %s" % [s.display_name, reason])


func _change_weather() -> void:
	var late := day >= 10
	var r := rng.randf()
	match weather:
		Weather.STORM:
			weather = Weather.HEAVY_RAIN
		Weather.HEAVY_RAIN:
			weather = Weather.STORM if r < 0.15 and not late else (Weather.LIGHT_RAIN if r > (0.5 if late else 0.7) else Weather.HEAVY_RAIN)
		Weather.LIGHT_RAIN:
			weather = Weather.HEAVY_RAIN if r < (0.15 if late else 0.35) else (Weather.CLEAR if r > 0.6 else Weather.LIGHT_RAIN)
		Weather.CLEAR:
			weather = Weather.LIGHT_RAIN if r < (0.15 if late else 0.4) else Weather.CLEAR


func _pick_event() -> void:
	current_event = null
	current_subject = null
	time_of_day = [TimeOfDay.DAWN, TimeOfDay.DAY, TimeOfDay.DUSK][day % 3] as TimeOfDay
	var picked: EventData = null
	if force_event != &"":
		picked = get_event(force_event)
		force_event = &""
	elif day >= rules.final_day:
		picked = get_event(FINAL_EVENT)
	elif day == 1 or rng.randf() >= rules.quiet_day_chance:
		var pool: Array[EventData] = []
		var weights: Array = []
		for ev in events:
			if _event_allowed(ev):
				pool.append(ev)
				weights.append(ev.weight)
		if not pool.is_empty():
			picked = pool[_weighted_index(weights)]
	if picked == null:
		return
	if picked.has_subject:
		current_subject = _random_present()
		if current_subject == null:
			return
	current_event = picked
	_used_events[picked.id] = true
	if picked.time_of_day != EventData.TimeOfDay.AUTO:
		time_of_day = picked.time_of_day as TimeOfDay


func _event_allowed(ev: EventData) -> bool:
	if ev.id == FINAL_EVENT or ev.weight <= 0 or day < ev.min_day or day > ev.max_day:
		return false
	if ev.once and _used_events.has(ev.id):
		return false
	if not ev.locations.is_empty() and not ev.locations.has(String(location)):
		return false
	for f in ev.required_flags:
		if not flags.has(f):
			return false
	for f in ev.blocked_flags:
		if flags.has(f):
			return false
	return true


func _random_present() -> SurvivorData:
	var present := get_present()
	return present[rng.randi_range(0, present.size() - 1)] if not present.is_empty() else null


# ======================================================================== text
func _status_lines() -> Array[String]:
	var lines: Array[String] = []
	for s in survivors:
		if not s.is_alive():
			continue
		if s.away:
			lines.append("%s ยังออกไปสำรวจ ยังไม่กลับมา" % s.display_name)
			continue
		var parts := describe_status(s)
		if not parts.is_empty():
			lines.append("%s: %s" % [s.display_name, ", ".join(parts)])
	return lines


## Short Thai status words for one person ("กระหายน้ำมาก", "ป่วย"...).
func describe_status(s: SurvivorData) -> PackedStringArray:
	var parts: PackedStringArray = []
	if not s.is_alive():
		parts.append("เสียชีวิตแล้ว")
		return parts
	if s.away:
		parts.append("ออกไปสำรวจ")
	if s.thirst_days >= rules.thirst_death_days - 1:
		parts.append("ขาดน้ำอย่างหนัก")
	elif s.thirst_days >= rules.thirst_warning_days:
		parts.append("กระหายน้ำ")
	if s.hunger_days >= rules.hunger_death_days - 2:
		parts.append("หิวจนตาลาย")
	elif s.hunger_days >= rules.hunger_warning_days:
		parts.append("หิว")
	if s.condition == SurvivorData.Condition.SICK:
		parts.append("ป่วย")
	elif s.condition == SurvivorData.Condition.INJURED:
		parts.append("บาดเจ็บ")
	return parts


## Icon ids for the boat / journal: thirst, hunger, sick, injured.
func status_icons(s: SurvivorData) -> Array[StringName]:
	var icons: Array[StringName] = []
	if s.thirst_days >= rules.thirst_warning_days:
		icons.append(&"thirst")
	if s.hunger_days >= rules.hunger_warning_days:
		icons.append(&"hunger")
	if s.condition == SurvivorData.Condition.SICK:
		icons.append(&"sick")
	elif s.condition == SurvivorData.Condition.INJURED:
		icons.append(&"injured")
	return icons


func get_event_title() -> String:
	return _format(current_event.title, null) if current_event else ""


func get_event_text() -> String:
	return _format(current_event.text, null) if current_event else ""


func _format(text: String, target: SurvivorData) -> String:
	return text.format({
		"subject": current_subject.display_name if current_subject else "",
		"target": target.display_name if target else "ใครบางคน",
		"player": survivors[0].display_name if not survivors.is_empty() else "",
	})
