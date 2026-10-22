extends Node
## Automated checks for Part 2 — the survival journal.
## Run:  godot --headless --path . res://tests/test_part2.tscn
## Exit code = number of failed checks (0 = all passed).

const GAME_SCENE := preload("res://scenes/part2/survival.tscn")
const SUMMARY_SCENE := preload("res://scenes/summary/summary.tscn")

var _failures := 0
var S: Node # SurvivalState shortcut


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	S = SurvivalState
	await _run()
	print("\n==== %s: %d failure(s) ====" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _run() -> void:
	print("\n[data] events and rules load")
	_check(S.events.size() == 38, "38 events loaded (%d)" % S.events.size())
	_check(S.locations.size() == 5, "5 locations loaded (%d)" % S.locations.size())
	for ev in S.events:
		_check(not ev.choices.is_empty() and ev.default_choice < ev.choices.size(), "event %s has choices" % ev.id)

	print("\n[start] no Part 1 data -> safe defaults")
	_start_default()
	_check(S.used_default_data and S.get_survivor_count() == 2, "default data, 2 survivors")
	_check(S.day == 1 and S.current_event and S.current_event.id == &"first_night", "day 1 event is first_night")
	_check(S.charge[&"flashlight"] == S.rules.flashlight_start_charge and S.charge[&"radio"] == S.rules.radio_start_charge, "devices start charged")

	print("\n[rations] water and food")
	var you: SurvivorData = S.survivors[0]
	var mom: SurvivorData = S.survivors[1]
	var water0 = S.get_supply_count(&"water")
	_check(S.set_ration(you, "water", true) and S.get_ration(you, "water"), "give water to you")
	_check(S.available(&"water") == water0 - 1, "available water drops while planned (%d)" % S.available(&"water"))
	_check(S.get_supply_count(&"water") == water0, "nothing used before the day ends")
	_check(not S.set_ration(you, "medicine", true), "medicine only for sick/injured")
	S.force_outcome = 0
	S.end_day()
	_check(S.day == 2, "day 2")
	_check(S.get_supply_count(&"water") == water0 - 1, "1 water used")
	_check(you.thirst_days == 0 and mom.thirst_days == 1, "you drank, mom thirst 1")
	_check(you.hunger_days == 1 and mom.hunger_days == 1, "nobody ate -> hunger 1")
	_check(S.rations.is_empty() and S.chosen_choice == -1, "rations cleared for the new day")
	_check(S.journal.size() > 0, "journal written for day 2")

	print("\n[rations] cannot give more than you have")
	Inventory.load_save_data([{"id": "water", "count": 1}])
	_check(S.set_ration(you, "water", true), "first water ok")
	_check(not S.set_ration(mom, "water", true), "second water refused (only 1)")

	print("\n[needs] dying of thirst")
	_start_default()
	Inventory.load_save_data([])
	for i in S.rules.thirst_death_days:
		S.force_event = &"water_recedes" if false else &""
		S.current_event = null
		S.end_day()
	_check(S.is_finished() and S.ending == &"all_dead", "everyone dies after %d days without water (ending %s)" % [S.rules.thirst_death_days, S.ending])
	_check(S.survivors.all(func(x: SurvivorData) -> bool: return not x.is_alive()), "all marked dead")

	print("\n[items] choices need the right item")
	_start_default()
	_force_today(&"voice_in_dark")
	_check(S.can_choose(1) and S.can_choose(2), "flashlight and rope choices available")
	Inventory.remove_item(&"rope", 1)
	S.state_changed.emit()
	_check(not S.can_choose(2), "rope choice locked without rope")
	_check(S.choose(1), "choose flashlight")
	var med0 = S.get_supply_count(&"medicine")
	S.end_day()
	_check(S.charge[&"flashlight"] == S.rules.flashlight_start_charge - 1, "flashlight used 1 charge")
	_check(S.get_supply_count(&"medicine") == med0 + 1, "the man gave us medicine")

	print("\n[items] medicine cures; consumable choice is used up")
	_start_default()
	_force_today(&"fever")
	var sick: SurvivorData = S.current_subject
	_check(sick != null and S.get_event_title().ends_with("ตัวร้อน"), "fever event about %s" % (sick.display_name if sick else "?"))
	var meds = S.get_supply_count(&"medicine")
	_check(S.choose(1), "give medicine")
	_check(S.available(&"medicine") == meds - 1, "medicine reserved for the choice")
	S.end_day()
	_check(S.get_supply_count(&"medicine") == meds - 1 and sick.condition == SurvivorData.Condition.HEALTHY, "medicine used, subject healthy")
	_force_today(&"fever")
	var sick2: SurvivorData = S.current_subject
	S.end_day() # default: ignore -> sick
	_check(sick2.condition == SurvivorData.Condition.SICK, "ignored fever -> sick")
	Inventory.add_item(ItemDatabase.get_item(&"medicine"), 1)
	_check(S.set_ration(sick2, "medicine", true), "medicine ration for the sick person")
	S.current_event = null
	S.end_day()
	_check(sick2.condition == SurvivorData.Condition.HEALTHY, "medicine ration cured them")

	print("\n[devices] batteries recharge automatically")
	_start_default()
	S.charge[&"flashlight"] = 0
	var bat = S.get_supply_count(&"batteries")
	_check(S.can_use_item(&"flashlight"), "flashlight usable thanks to batteries")
	_check(S.use_device(&"flashlight"), "use flashlight")
	_check(S.get_supply_count(&"batteries") == bat - 1 and S.charge[&"flashlight"] == S.rules.battery_charge - 1, "1 battery inserted")
	Inventory.load_save_data([{"id": "flashlight", "count": 1}])
	S.charge[&"flashlight"] = 0
	_check(not S.can_use_item(&"flashlight"), "dead flashlight without batteries is unusable")

	print("\n[radio] broadcasts teach the light signal")
	_start_default()
	for i in S.rules.broadcasts_for_signal:
		_check(S.can_listen_radio(), "can listen on day %d" % S.day)
		_check(S.listen_radio() != "", "broadcast %d heard" % (i + 1))
		_check(not S.can_listen_radio(), "only once per day")
		S.current_event = null
		for x in S.get_present():
			S.set_ration(x, "water", true)
		S.end_day()
	_check(S.flags.has("knows_signal"), "knows rescue boats look for light")
	_check(S.get_supply_count(&"batteries") < 2, "radio used a battery (%d left)" % S.get_supply_count(&"batteries"))

	print("\n[rescue] flashlight signal = rescued")
	_force_today(&"rescue_signal")
	_check(S.choose(2), "signal with flashlight")
	var ended: Array = []
	S.game_ended.connect(func(e: StringName) -> void: ended.append(e), CONNECT_ONE_SHOT)
	S.end_day()
	_check(S.is_finished() and S.ending == &"rescued_signal" and ended == [&"rescued_signal"], "ending: rescued_signal")
	S.end_day()
	_check(S.day == S.history.back().day, "nothing happens after the ending")

	print("\n[documents] registration -> relief + named rescue")
	_start_default()
	Inventory.add_item(ItemDatabase.get_item(&"documents"), 1)
	_force_today(&"relief_boat")
	var w = S.get_supply_count(&"water")
	S.choose(1)
	S.end_day()
	_check(S.flags.has("registered") and S.get_supply_count(&"water") == w + 3, "registered, +3 water")
	S.day = S.get_event(&"registered_rescue").min_day
	var allowed = S._event_allowed(S.get_event(&"registered_rescue"))
	_check(allowed, "registered_rescue can now appear")

	print("\n[neighbor] kindness pays back")
	_start_default()
	_force_today(&"neighbor_medicine")
	S.choose(1)
	S.end_day()
	_check(S.flags.has("helped_neighbor"), "helped neighbor")
	S.day = 7
	_check(S._event_allowed(S.get_event(&"neighbor_returns")), "neighbor_returns unlocked")

	print("\n[storm] rope protects, otherwise loss")
	_start_default()
	_force_today(&"storm")
	var total_before := _total_items()
	S.choose(1)
	S.end_day()
	_check(_total_items() == total_before, "rope: nothing lost")
	_force_today(&"storm")
	S.force_outcome = 0
	S.end_day()
	_check(_total_items() == total_before - 2, "no rope: 2 items swept away")

	print("\n[expedition] gear leaves the boat and comes back")
	_start_default()
	Inventory.add_item(ItemDatabase.get_item(&"water"), 6)
	var mom2: SurvivorData = S.survivors[1]
	_check(S.can_send_on_expedition(mom2), "mom can go")
	_check(S.plan_expedition(mom2, [&"flashlight"] as Array[StringName]), "plan with flashlight")
	S.current_event = null
	S.end_day()
	_check(mom2.away and S.get_supply_count(&"flashlight") == 0, "mom away, flashlight with her")
	_check(not S.can_send_on_expedition(S.survivors[0]), "nobody else can go meanwhile")
	var items_before := _total_items()
	S.current_event = null
	S.force_outcome = 0 # find supplies
	S.end_day()
	_check(not mom2.away and S.get_supply_count(&"flashlight") == 1, "mom back, flashlight returned")
	_check(_total_items() > items_before, "brought supplies (%d -> %d)" % [items_before, _total_items()])
	_check(S.journal[0].contains("กลับมาแล้ว"), "journal: '%s'" % S.journal[0])
	S.plan_expedition(mom2, [] as Array[StringName])
	S.current_event = null
	S.end_day()
	S.current_event = null
	S.force_outcome = 3 # lost
	S.end_day()
	_check(not mom2.is_alive() and S.get_survivor_count() == 1, "lost on expedition -> gone")

	print("\n[final day] the water recedes")
	_start_default()
	S.day = S.rules.final_day - 1
	S.current_event = null
	for x in S.get_present():
		S.set_ration(x, "water", true)
	S.end_day()
	_check(S.current_event and S.current_event.id == &"water_recedes", "final event on day %d" % S.day)
	S.end_day()
	_check(S.ending == &"reached_center", "ending: reached_center")

	print("\n[part1 data] survivors and supplies from Part 1")
	S.reset()
	Inventory.configure(12)
	Inventory.add_item(ItemDatabase.get_item(&"water"), 2)
	GameState.part1_completed = true
	GameState.survivors_from_part1 = 3
	S.ensure_started()
	_check(not S.used_default_data and S.get_survivor_count() == 3, "3 survivors from Part 1")
	_check(S.get_supply_count(&"water") == 2 and S.get_supply_count(&"radio") == 0, "only Part 1 items")
	_check(S.charge[&"radio"] == 0, "no radio -> no radio charge")
	_check(not S.can_listen_radio(), "cannot listen without radio")

	print("\n[empty] Part 1 delivered nothing")
	S.reset()
	Inventory.configure(12)
	GameState.survivors_from_part1 = 0
	GameState.rescued_family.clear()
	S.ensure_started()
	_check(S.get_supplies().is_empty() and S.get_survivor_count() == 1, "empty supplies, nobody rescued -> only the player")
	S.end_day()
	_check(S.day == 2, "a day passes without crashing")

	print("\n[time + water] background inputs")
	_start_default()
	_check(S.time_of_day == S.TimeOfDay.NIGHT, "first night is at night")
	_check(is_equal_approx(S.get_water_level(), 0.55), "water level day 1 = 0.55")
	S.day = 10
	_check(is_equal_approx(S.get_water_level(), 1.0), "water at its peak on day 10")
	S.day = S.rules.final_day
	_check(is_equal_approx(S.get_water_level(), 0.0), "water back to normal on day %d" % S.rules.final_day)
	S.day = 4
	S.force_event = &"monks_alms"
	S.location = &"temple"
	S._pick_event()
	_check(S.time_of_day == S.TimeOfDay.DAWN, "alms round happens at dawn")

	print("\n[locations] events belong to places")
	_start_default()
	S.day = 5
	_check(not S._event_allowed(S.get_event(&"monks_alms")), "no monks at the village")
	S.location = &"temple"
	_check(S._event_allowed(S.get_event(&"monks_alms")), "monks at the temple")
	_check(not S._event_allowed(S.get_event(&"army_truck")), "no army truck at the temple")
	S.location = &"highway"
	_check(S._event_allowed(S.get_event(&"army_truck")), "army truck on the highway")

	print("\n[choices] people, flags and trades")
	_start_default()
	_force_today(&"grandpa_herbs")
	_check(not S.can_choose(2), "grandpa's herb choice locked (grandpa not on board)")
	S.reset()
	Inventory.configure(16)
	GameState.part1_completed = true
	S.start_from_part1(4)
	_force_today(&"grandpa_herbs")
	_check(S.can_choose(2), "grandpa's herb choice open with 4 survivors")
	S.choose(2)
	S.end_day()
	_check(S.get_supply_count(&"medicine") == 2, "grandpa made 2 medicine")
	S.location = &"market"
	_force_today(&"rats")
	_check(not S.can_choose(3), "kitten choice locked")
	S.flags["kitten"] = S.day
	S.state_changed.emit()
	_check(S.can_choose(3), "kitten choice opens with the flag")
	_start_default()
	S.location = &"market"
	_force_today(&"merchant")
	var water_before = S.get_supply_count(&"water")
	_check(S.choose(3), "trade the radio")
	S.end_day()
	_check(S.get_supply_count(&"radio") == 0 and S.get_supply_count(&"water") == water_before + 2, "radio gone, +2 water")
	_check(not S.can_listen_radio(), "no more news")
	_start_default()
	Inventory.add_item(ItemDatabase.get_item(&"canned_food"), 1)
	for x in S.survivors:
		x.hunger_days = 4
	S.reset()
	Inventory.configure(16)
	S.start_from_part1(2)
	Inventory.add_item(ItemDatabase.get_item(&"canned_food"), 1)
	for x in S.survivors:
		x.hunger_days = 4
	_force_today(&"mother_cooking")
	_check(S.choose(1), "mother cooks")
	S.end_day()
	_check(S.survivors.all(func(x: SurvivorData) -> bool: return x.hunger_days == 0), "everyone fed (hunger back to 0)")

	print("\n[voyage] every 3 days, new place")
	_start_default()
	_check(not S.can_voyage(), "no voyage on day 1")
	S.day = 3
	S.state_changed.emit()
	_check(S.can_voyage() and S.voyage_options().size() == 4, "day 3: voyage with 4 destinations")
	_check(S.plan_voyage(&"temple"), "plan voyage to the temple")
	_check(not S.can_send_on_expedition(S.survivors[1]), "no expedition on a voyage day once planned")
	S.voyage_collect(&"water")
	S.complete_voyage(PackedStringArray(["น้ำดื่ม"]), PackedStringArray([]))
	_check(S.location == &"temple", "arrived at the temple")
	S.current_event = null
	S.end_day()
	_check(S.journal[0].begins_with("เราพายเรือมาถึงวัดกลางน้ำ"), "journal: '%s'" % S.journal[0])
	_check(not S.can_voyage() and S.next_voyage_day() == 6, "next voyage day 6")

	print("\n[voyage] minigame")
	for rate in [1.0, 0.0]:
		_start_default()
		S.day = 3
		S.plan_voyage(&"market")
		var items0 = Inventory.get_total_item_count()
		var g := GAME_SCENE.instantiate()
		g.reload_on_retry = false
		g.voyage_auto_play = rate
		add_child(g)
		await _frames(3)
		g.end_day()
		_check(g.is_voyage_running(), "voyage minigame opened (rate %.0f)" % rate)
		var v: VoyageGame = g.get_voyage()
		var obstacles := 0
		for e in v._queue:
			if e.obstacle:
				obstacles += 1
		var spawns := v._queue.size()
		var t := 0.0
		while g.is_voyage_running() and t < 60.0:
			await _seconds(0.25)
			t += 0.25
		await _seconds(2.0)
		_check(not g.is_voyage_running() and S.location == &"market", "voyage finished, now at the market")
		_check(S.day == 4, "the night passed after the voyage (day %d)" % S.day)
		if rate == 1.0:
			_check(Inventory.get_total_item_count() == items0 + spawns - obstacles, "perfect run: +%d items, no hits (%d -> %d)" % [spawns - obstacles, items0, Inventory.get_total_item_count()])
		else:
			_check(Inventory.get_total_item_count() <= items0, "missed everything: nothing gained (%d -> %d)" % [items0, Inventory.get_total_item_count()])
		g.queue_free()
		await _frames(2)

	print("\n[endings] each one needs its condition")
	_start_default()
	S.day = 10
	S.location = &"temple"
	_check(not S._event_allowed(S.get_event(&"temple_boat")), "temple boat needs merit")
	S.flags["merit"] = 3
	_check(S._event_allowed(S.get_event(&"temple_boat")), "merit + temple + day 10 -> temple boat")
	_force_today(&"temple_boat")
	S.choose(1)
	S.end_day()
	_check(S.ending == &"temple_shelter", "ending temple_shelter")
	_start_default()
	S.day = 15
	S.location = &"highway"
	_check(not S._event_allowed(S.get_event(&"army_evac")), "army evac needs the list")
	_force_today(&"army_truck")
	Inventory.add_item(ItemDatabase.get_item(&"documents"), 1)
	_check(S.choose(2), "sign up with documents")
	S.end_day()
	_check(S.flags.has("army_list") and S._event_allowed(S.get_event(&"army_evac")), "on the list -> evac can come")
	_force_today(&"army_evac")
	S.choose(1)
	S.end_day()
	_check(S.ending == &"army_evac", "ending army_evac")
	_start_default()
	S.day = 11
	S.flags["knows_signal"] = 1
	_check(not S._event_allowed(S.get_event(&"rescue_signal")), "rescue boats only from day 12")
	S.day = 12
	_check(S._event_allowed(S.get_event(&"rescue_signal")), "radio + day 12 -> rescue boat can come")
	_start_default()
	_force_today(&"helicopter")
	S.force_outcome = 0
	S.choose(2)
	S.end_day()
	_check(S.ending == &"rescued_air", "ending rescued_air (flashlight signal)")
	for id in S.ENDINGS:
		_check(S.get_ending_title(id) != String(id), "ending %s has a title" % id)

	print("\n[scene] journal UI")
	_start_default()
	var game := GAME_SCENE.instantiate()
	game.reload_on_retry = false
	add_child(game)
	await _frames(3)
	var journal: Journal = game.journal
	_check(journal.day_label.text == "วันที่ 1", "journal shows day 1")
	_check(game.boat.get_survivor_nodes().size() == 2, "2 survivors on the boat")
	_check(game.status_bar.info_label.text.begins_with("DAY 1   |   SURVIVORS: 2/2"), "top bar: '%s'" % game.status_bar.info_label.text)
	journal.show_page(1)
	var ration_page = journal.pages[1]
	var toggle: Button = ration_page.get_toggle(S.survivors[0], "water")
	_check(toggle != null, "water toggle exists")
	toggle.button_pressed = true
	await _frames(1)
	_check(S.get_ration(S.survivors[0], "water"), "toggle sets the ration")
	journal.show_page(2)
	var event_page = journal.pages[2]
	var buttons: Array[Button] = event_page.get_choice_buttons()
	_check(buttons.size() == 2, "first_night shows 2 choices")
	buttons[1].pressed.emit()
	await _frames(1)
	_check(S.chosen_choice == 1, "choice made from the journal")
	journal.end_day_button.pressed.emit()
	await _seconds(2.5)
	_check(S.day == 2 and journal.day_label.text == "วันที่ 2", "จบวัน -> day 2 (%d)" % S.day)
	_check(journal.page == 0, "journal back on the report page")
	_check(not game.transition.visible, "transition finished")

	print("\n[scene] ending panel + retry")
	_force_today(&"water_recedes")
	game.end_day()
	await _seconds(2.5)
	_check(game.ending_panel.visible and game.ending_panel.title_label.text == S.get_ending_title(&"reached_center"), "ending panel: '%s'" % game.ending_panel.title_label.text)
	game.ending_panel.retry_button.pressed.emit()
	_check(S.day == 1 and not S.is_finished() and S.get_survivor_count() == 2, "retry -> day 1 again")
	_check(S.get_supply_count(&"water") == 3, "retry restores starting supplies")
	game.queue_free()
	await _frames(2)

	print("\n[flow] summary -> Part 2")
	_check(GameState.has_part_2(), "PART_2_SCENE exists")
	var summary := SUMMARY_SCENE.instantiate()
	add_child(summary)
	await _frames(1)
	_check(not summary.get_node("%ContinueButton").disabled, "summary continue button enabled")
	summary.queue_free()

	print("\n[thai] glyphs")
	var font: Font = ThemeDB.get_project_theme().default_font
	var text := ""
	for ev in S.events:
		text += ev.title + ev.text
		for c in ev.choices:
			text += c.label
	var missing := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c > 127 and not font.has_char(c) and not missing.contains(text[i]):
			missing += text[i]
	_check(missing.is_empty(), "font has every glyph used by events (missing: '%s')" % missing)


# ------------------------------------------------------------------ helpers
func _start_default() -> void:
	GameState.part1_completed = false
	S.reset()
	S.rng.seed = 42
	S.start_with_default_data()


func _force_today(id: StringName) -> void:
	S.force_event = id
	S._pick_event()
	S.state_changed.emit()


func _total_items() -> int:
	return Inventory.get_total_item_count()


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
	print("  %s  %s" % ["ok  " if cond else "FAIL", label])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true).timeout
