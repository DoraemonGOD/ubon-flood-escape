extends Node
## Balance check: plays many survival runs with a simple sensible policy and prints
## how they end. Run: godot --headless --path . res://tests/balance_sim.tscn -- --runs=300 --data=default|part1|poor
## The bot: rations when someone gets thirsty/hungry, picks the last usable choice of an
## event, listens to the radio, voyages every 3 days (hits 70% of the prompts) and
## sometimes sends someone exploring.

const VOYAGE_SUCCESS := 0.7

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var runs := int(args.get("runs", "300"))
	var results := {}
	var days_total := 0
	var survivors_total := 0
	for r in runs:
		var S = SurvivalState
		S.reset()
		S.rng.seed = r + 1
		match args.get("data", "default"):
			"part1":
				Inventory.configure(16)
				for p in [["water", 4], ["canned_food", 5], ["medicine", 2], ["flashlight", 1], ["batteries", 4], ["rope", 1], ["radio", 1], ["documents", 1]]:
					Inventory.add_item(ItemDatabase.get_item(p[0]), p[1])
				S.start_from_part1(4)
			"poor":
				Inventory.configure(16)
				for p in [["water", 2], ["canned_food", 2]]:
					Inventory.add_item(ItemDatabase.get_item(p[0]), p[1])
				S.start_from_part1(2)
			_:
				S.start_with_default_data()
		while not S.is_finished() and S.day < 40:
			if S.can_listen_radio():
				S.listen_radio()
			for s in S.get_present():
				if s.thirst_days >= 2:
					S.set_ration(s, "water", true)
				if s.hunger_days >= 3:
					S.set_ration(s, "food", true)
				if s.needs_medicine():
					S.set_ration(s, "medicine", true)
			if S.current_event:
				for i in range(S.current_event.choices.size() - 1, -1, -1):
					if S.choose(i):
						break
			if S.can_voyage():
				var options: Array = S.voyage_options()
				var dest: LocationData = options[S.rng.randi_range(0, options.size() - 1)]
				S.plan_voyage(dest.id)
				var got := PackedStringArray()
				var hits := PackedStringArray()
				for i in S.rules.voyage_spawns:
					var obstacle: bool = S.rng.randf() < S.rules.voyage_obstacle_chance
					var ok: bool = S.rng.randf() < VOYAGE_SUCCESS
					if obstacle and not ok:
						hits.append(S.voyage_hit())
					elif not obstacle and ok:
						var id := StringName(dest.loot_table.keys()[S._weighted_index(dest.loot_table.values())])
						S.voyage_collect(id)
						got.append(String(id))
				S.complete_voyage(got, hits)
			elif S.expedition.is_empty() and S.day % 4 == 2:
				for s in S.get_present():
					if S.can_send_on_expedition(s) and s != S.survivors[0]:
						var gear: Array[StringName] = []
						if S.get_supply_count(&"rope") > 0:
							gear.append(&"rope")
						S.plan_expedition(s, gear)
						break
			S.end_day()
		results[S.ending] = results.get(S.ending, 0) + 1
		days_total += S.day
		survivors_total += S.get_survivor_count()
	print("runs=%d data=%s  endings=%s  avg_day=%.1f  avg_alive=%.2f" % [runs, args.get("data", "default"), results, float(days_total) / runs, float(survivors_total) / runs])
	get_tree().quit()
