extends Node
## Dev helper: renders one screen and saves a PNG, then quits. Needs a window (not --headless).
##   godot --path . res://tests/screenshot.tscn -- --shot=level --out=C:/tmp/level.png
## --shot = menu | level | summary | pause

var _args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	Platform.save_enabled = false
	match _args.get("platform", "pc"):
		"mobile":
			Platform.set_mode(Platform.MOBILE)
		"unset":
			Platform.mode = Platform.PC
			Platform.chosen = false
		_:
			Platform.set_mode(Platform.PC)
	var shot: String = _args.get("shot", "level")
	match shot:
		"menu":
			add_child(load(GameState.MAIN_MENU_SCENE).instantiate())
		"frames":
			# contact sheet of every player frame: one row per pose set, down/up/side side by side
			var frames: SpriteFrames = load("res://assets/characters/player_frames.tres")
			var bg := ColorRect.new()
			bg.color = Color("cdbb93")
			bg.size = Vector2(1280, 720)
			add_child(bg)
			# --scale=N --sets=walk,run --dirs=side to zoom into a few pose sets
			var sc := float(_args.get("scale", "0.88"))
			var sets: PackedStringArray = _args.get("sets", "idle,walk,run,carry_idle,carry_walk,carry_run,pickup,throw").split(",")
			var dirs: PackedStringArray = _args.get("dirs", "down,up,side").split(",")
			var y := 0
			for set_name in sets:
				var x := 0
				for dir in dirs:
					var anim := StringName("%s_%s" % [set_name, dir])
					for i in frames.get_frame_count(anim):
						var s := Sprite2D.new()
						s.texture = frames.get_frame_texture(anim, i)
						s.centered = false
						s.scale = Vector2(sc, sc)
						s.position = Vector2(x, y)
						add_child(s)
						x += int(64 * sc) - 2
					x += 14
				y += int(100 * sc)
		"survival":
			# --data=default|part1|empty --survivors=N --days=N (simulate) --event=id --page=0..3 --ending=1
			SurvivalState.reset()
			SurvivalState.rng.seed = int(_args.get("seed", "7"))
			match _args.get("data", "default"):
				"default":
					SurvivalState.start_with_default_data()
				_:
					Inventory.configure(16)
					if _args.get("data") == "part1":
						for pair in [["water", 4], ["canned_food", 5], ["medicine", 2], ["flashlight", 1], ["batteries", 4], ["rope", 1], ["radio", 1], ["documents", 1]]:
							Inventory.add_item(ItemDatabase.get_item(pair[0]), pair[1])
					SurvivalState.start_from_part1(int(_args.get("survivors", "0")))
			for i in int(_args.get("days", "0")):
				SurvivalState.chosen_choice = -1
				if i % 2 == 0:
					for sv in SurvivalState.get_present():
						SurvivalState.set_ration(sv, "water", true)
				SurvivalState.end_day()
			if _args.has("event"):
				SurvivalState.force_event = StringName(_args["event"])
				SurvivalState._pick_event()
				SurvivalState.state_changed.emit()
			if _args.has("location"):
				SurvivalState.location = StringName(_args["location"])
			if _args.has("time"):
				SurvivalState.time_of_day = int(_args["time"])
			if _args.has("weather"):
				SurvivalState.weather = int(_args["weather"])
			if _args.has("setday"):
				SurvivalState.day = int(_args["setday"])
			var game: Node = load(GameState.PART_2_SCENE).instantiate()
			add_child(game)
			await get_tree().create_timer(1.6).timeout
			if _args.has("voyage"):
				SurvivalState.day = 3
				SurvivalState.plan_voyage(StringName(_args["voyage"]))
				game.end_day()
			game.journal.show_page(int(_args.get("page", "0")))
			if _args.has("ration"):
				for sv in SurvivalState.get_present():
					SurvivalState.set_ration(sv, "water", true)
			if _args.has("ending"):
				SurvivalState.ending = &"rescued"
				game.journal.hide()
				game.ending_panel.open(&"rescued")
		"intro":
			# --lines=N skips ahead N subtitle lines, then waits --wait
			var intro: Node = load(GameState.INTRO_SCENE).instantiate()
			intro.auto_continue = false
			add_child(intro)
			await get_tree().create_timer(1.2).timeout
			for i in int(_args.get("lines", "0")):
				intro._advance = true
				await get_tree().create_timer(0.35).timeout
		"summary":
			_fill_bag()
			GameState.last_time_left = 0.0
			add_child(load(GameState.SUMMARY_SCENE).instantiate())
		_:
			var level: Node = load(GameState.SCAVENGING_SCENE).instantiate()
			level.look_seconds = int(_args.get("look", "0"))
			add_child(level)
			var player: Player = level.get_node("World/Player")
			await get_tree().physics_frame
			player.global_position = Vector2(_args.get("x", "880").to_float(), _args.get("y", "520").to_float())
			if _args.has("zoom"):
				player.camera.zoom = Vector2.ONE * _args["zoom"].to_float()
				player.set_camera_limits(Rect2(-100000, -100000, 200000, 200000))
			player.camera.reset_smoothing()
			# items already on the boat (--cargo=N) and in the hands
			var boat: Boat = level.get_node("World/Boat")
			var ids := ["water", "canned_food", "medicine", "rope", "documents", "batteries"]
			for i in int(_args.get("cargo", "0")):
				var cargo_item := ItemDatabase.get_item(ids[i % ids.size()])
				if BoatCargo.deliver(cargo_item):
					boat.on_item_landed(cargo_item, boat.next_drop_position(), Player.DECK_HEIGHT)
			for id in ["water", "canned_food", "radio"]:
				player.carry.add(ItemDatabase.get_item(id))
			if shot == "throw":
				for i in 4:
					await get_tree().physics_frame
				player.try_throw()
			if _args.has("near"):
				player.global_position = Vector2(860, 500)
			if shot == "pause":
				await get_tree().create_timer(0.5, true).timeout
				level.get_node("PauseMenu").open()
	await get_tree().create_timer(float(_args.get("wait", "1.2")), true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_args.get("out", "user://shot.png"))
	get_tree().quit()


func _fill_bag() -> void:
	Inventory.configure(8)
	for pair in [["water", 3], ["water", 1], ["canned_food", 3], ["medicine", 1], ["flashlight", 1], ["batteries", 4], ["radio", 1], ["documents", 1]]:
		Inventory.add_item(ItemDatabase.get_item(pair[0]), pair[1])
