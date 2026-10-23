extends Node
## Automated checks: Part 1 test plan + Carry & Throw feature (J1–J14).
## Run:  godot --headless --path . res://tests/test_part1.tscn
## Exit code = number of failed checks (0 = all passed).

const LEVEL_SCENE := preload("res://scenes/scavenging/scavenging.tscn")
const SUMMARY_SCENE := preload("res://scenes/summary/summary.tscn")
const INTRO_SCENE := preload("res://scenes/cutscene/intro_cutscene.tscn")
const MENU_SCENE := preload("res://scenes/main_menu/main_menu.tscn")
const BOAT_SPOT := Vector2(590, 870) # on the porch, inside the boat interaction zone

var _failures := 0
var _level: Node2D
var _player: Player
var _boat: Boat
var _hud: GameHUD


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("\n==== %s: %d failure(s) ====" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _run() -> void:
	Platform.save_enabled = false
	Platform.set_mode(Platform.PC)
	await _load_level()

	print("\n[movement] walk in every direction, run is faster")
	for dir in [["move_right", Vector2.RIGHT], ["move_left", Vector2.LEFT], ["move_up", Vector2.UP], ["move_down", Vector2.DOWN]]:
		var moved := await _move(Vector2(600, 600), dir[0], dir[1], false)
		_check(moved > 40.0, "%s moves the player (%.0f px)" % [dir[0], moved])
		_check(_player.velocity == Vector2.ZERO, "%s: player stops when released" % dir[0])
	_check(_player.sprite.animation == &"idle_down", "idle animation after walking (%s)" % _player.sprite.animation)
	var walked := await _move(Vector2(600, 600), "move_right", Vector2.RIGHT, false)
	var ran := await _move(Vector2(600, 600), "move_right", Vector2.RIGHT, true)
	_check(ran > walked * 1.4, "Shift run is clearly faster (walk %.0f px, run %.0f px)" % [walked, ran])

	print("\n[walls] collision still blocks walking and running")
	await _push(Vector2(760, 160), "move_up", func(p: Vector2) -> bool: return p.y > 0.0, "back wall")
	await _push(Vector2(420, 300), "move_down", func(p: Vector2) -> bool: return p.y < 384.0, "inner wall")
	await _push(Vector2(1300, 680), "move_right", func(p: Vector2) -> bool: return p.x < 1536.0, "right exterior wall")
	await _push(Vector2(40, 500), "move_left", func(p: Vector2) -> bool: return p.x > 0.0, "left exterior wall")
	await _push(Vector2(440, 870), "move_down", func(p: Vector2) -> bool: return p.y < 912.0, "porch edge (floodwater)")
	await _push(Vector2(560, 870), "move_right", func(p: Vector2) -> bool: return p.x < 645.0, "porch edge towards the boat (running)", true)

	print("\n[J1 + J4] pick up one item with E and the pickup animation")
	var radio := _pickup(&"radio")
	await _stand_at(radio.global_position + Vector2(0, 26))
	_check(_player.get_nearest_pickup() == radio, "radio is the nearest pickup")
	_press(&"interact")
	await _physics(2)
	_check(_player.state == Player.State.PICKUP, "state = PICKUP")
	_check(_player.anim.current_animation == &"pickup", "AnimationPlayer plays 'pickup'")
	_check(String(_player.sprite.animation).begins_with("pickup_"), "sprite shows pickup pose (%s)" % _player.sprite.animation)
	_check(_player.carry.count() == 0, "not in hands before the grab keyframe")
	await _seconds(0.6)
	_check(_player.carry.count() == 1, "CARRY 1/3 after the animation")
	_check(not is_instance_valid(radio), "radio removed from the scene")
	_check(_player.state == Player.State.FREE, "player can move again after pickup")
	_check(String(_player.sprite.animation).begins_with("carry_idle_"), "carry_idle when standing with items (%s)" % _player.sprite.animation)
	_check(_hud.carry_ui.carry_label.text == "CARRY 1/3", "UI reads '%s'" % _hud.carry_ui.carry_label.text)
	_check(Inventory.get_total_item_count() == 0 and BoatCargo.total_delivered == 0, "carried item is NOT in the permanent inventory / boat")

	print("\n[J2 + J3] up to 3 items, the 4th is refused and stays")
	await _collect(&"documents")
	var flash := _pickup(&"flashlight")
	await _stand_at(flash.global_position + Vector2(0, 26))
	_check(_player.try_interact() and not _player.try_interact(), "second E during a pickup is ignored")
	await _seconds(0.6)
	_check(_player.carry.count() == 3, "CARRY 3/3 (%d)" % _player.carry.count())
	var meds := _pickup(&"medicine")
	await _stand_at(meds.global_position + Vector2(0, 26))
	_check(_player.try_interact() == false, "4th pickup refused")
	_check(_player.state == Player.State.FREE, "no pickup animation started")
	_check(is_instance_valid(meds) and meds.can_be_collected() and meds.quantity == 1, "medicine stays in the world")
	_check(_player.carry.count() == 3, "still CARRY 3/3")
	_check(_hud.message_label.text.begins_with("มือเต็ม"), "message: '%s'" % _hud.message_label.text)

	print("\n[J5] running while carrying")
	await _stand_at(Vector2(600, 600))
	Input.action_press("run")
	Input.action_press("move_right")
	await _seconds(0.25)
	_check(_player.is_running and _player.sprite.animation == &"carry_run_side", "carry_run_side plays (%s)" % _player.sprite.animation)
	Input.action_release("move_right")
	Input.action_release("run")
	await _physics(3)

	print("\n[J6] Q outside the boat zone does nothing")
	_check(_player.get_boat() == null, "not in boat range")
	_press(&"throw")
	await _physics(3)
	_check(_player.state == Player.State.FREE and _player.carry.count() == 3 and BoatCargo.total_delivered == 0, "no throw, nothing lost or delivered")

	print("\n[J7 + J10] Q at the boat starts the throw; cargo only counts on landing")
	await _stand_at(BOAT_SPOT)
	_check(_player.get_boat() == _boat, "player is in the boat zone")
	_check(_hud.boat_prompt.visible and _hud.boat_prompt_label.text.contains("โยนของขึ้นเรือ"), "boat prompt: '%s'" % _hud.boat_prompt_label.text)
	_press(&"throw")
	await _physics(2)
	_check(_player.state == Player.State.THROW, "state = THROW")
	_check(_player.anim.current_animation == &"throw_start", "AnimationPlayer plays 'throw_start'")
	_check(_player.velocity == Vector2.ZERO, "movement locked during throw")
	await _seconds(0.3) # first item released at ~0.21 s, lands at ~0.71 s
	var flying := _player.carry.get_items().filter(func(e): return e.in_flight).size()
	_check(flying >= 1, "an item is in the air (%d)" % flying)
	_check(BoatCargo.total_delivered == 0, "BoatCargo still 0 while the item flies")
	_check(_player.carry.count() == 3, "carry keeps the in-flight item until it lands")

	print("\n[J8 + J9] each landing -1 carry, all 3 delivered")
	await _wait_until(func() -> bool: return BoatCargo.total_delivered >= 1, 2.0)
	_check(BoatCargo.total_delivered == 1 and _player.carry.count() == 2, "after 1st landing: cargo 1, CARRY 2/3 (cargo %d, carry %d)" % [BoatCargo.total_delivered, _player.carry.count()])
	await _wait_until(func() -> bool: return _player.state == Player.State.FREE and BoatCargo.total_delivered == 3, 3.0)
	_check(BoatCargo.total_delivered == 3 and _player.carry.count() == 0, "all 3 on the boat, hands empty")
	_check(BoatCargo.get_quantity(&"radio") == 1 and BoatCargo.get_quantity(&"documents") == 1 and BoatCargo.get_quantity(&"flashlight") == 1, "BoatCargo records per item")
	_check(Inventory.get_total_item_count() == 3, "permanent Inventory (boat hold) has 3")
	_check(_boat.get_cargo_visual_count() == 3, "3 items lie on the boat deck")
	_check(_hud.carry_ui.delivered_label.text == "ส่งขึ้นเรือแล้ว 3 ชิ้น", "UI: '%s'" % _hud.carry_ui.delivered_label.text)
	await _physics(2)
	_check(String(_player.sprite.animation).begins_with("idle_"), "back to idle after throw_recover (%s)" % _player.sprite.animation)
	_press(&"throw")
	await _physics(2)
	_check(_player.state == Player.State.FREE and _hud.message_label.text == "ไม่มีของที่ต้องโยน", "empty hands: '%s'" % _hud.message_label.text)

	print("\n[J11] mashing Q never duplicates")
	await _collect(&"water")
	await _collect(&"water")
	_check(_player.carry.count() == 2, "holding 2 water")
	await _stand_at(BOAT_SPOT)
	var started := 0
	for i in 10:
		if _player.try_throw():
			started += 1
	for i in 6:
		_press(&"throw")
		await _physics(1)
	_check(started == 1, "only one throw sequence started (%d)" % started)
	await _wait_until(func() -> bool: return _player.state == Player.State.FREE and _player.carry.count() == 0, 3.0)
	_check(BoatCargo.total_delivered == 5 and BoatCargo.get_quantity(&"water") == 2, "exactly 2 water delivered (total %d)" % BoatCargo.total_delivered)

	print("\n[cancel] throw cancelled before release loses nothing")
	await _collect(&"canned_food")
	await _stand_at(BOAT_SPOT)
	_check(_player.try_throw(), "throw started")
	await _physics(2)
	_player.set_controls_enabled(false)
	await _seconds(0.9)
	_check(BoatCargo.total_delivered == 5, "nothing delivered (%d)" % BoatCargo.total_delivered)
	_check(_player.carry.count() == 1 and _player.carry.has_throwable(), "canned food still in hands, not in flight")
	_player.set_controls_enabled(true)

	print("\n[J12] pause in the middle of a throw")
	var timer: ScavengeTimer = _level.get_node("ScavengeTimer")
	var pause: PauseMenu = _level.get_node("PauseMenu")
	await _physics(2)
	_check(_player.try_throw(), "throw started")
	await _seconds(0.3)
	pause.open()
	var t_paused := timer.time_left
	var throw := _find_throw()
	var throw_pos := throw.global_position if throw else Vector2.ZERO
	await _seconds(0.6)
	_check(get_tree().paused, "tree is paused")
	_check(is_equal_approx(timer.time_left, t_paused), "timer frozen (%.3f -> %.3f)" % [t_paused, timer.time_left])
	_check(throw != null and throw.global_position == throw_pos and throw.is_flying(), "thrown item frozen in the air")
	_check(BoatCargo.total_delivered == 5 and _player.state == Player.State.THROW, "state unchanged while paused (total %d, state %d, throw %s, anim %s)" % [BoatCargo.total_delivered, _player.state, throw, _player.anim.current_animation])
	pause.close()
	await _wait_until(func() -> bool: return _player.state == Player.State.FREE and _player.carry.count() == 0, 2.0)
	_check(BoatCargo.total_delivered == 6 and _player.carry.count() == 0, "throw completes after resume (total %d)" % BoatCargo.total_delivered)
	_check(timer.time_left < t_paused, "timer runs again")

	print("\n[J13] time up: no picking up, no throwing")
	_level.end_delay = 999.0
	await _collect(&"batteries")
	var batteries := _pickup(&"batteries")
	await _stand_at(batteries.global_position + Vector2(0, 26))
	timer.time_left = 0.1
	await _seconds(0.3)
	_check(_level.is_finished() and not _player.controls_enabled, "level finished, controls off")
	_check(_player.try_interact() == false and batteries.can_be_collected() == false, "pickup disabled")
	await _stand_at(BOAT_SPOT)
	_check(_player.try_throw() == false and BoatCargo.total_delivered == 6, "throw disabled")
	_check(_player.carry.count() == 1, "undelivered item stays counted as undelivered")
	_check(not pause.enabled and _hud.time_up_banner.visible, "pause off, banner shown")

	print("\n[summary] shows only what reached the boat")
	GameState.last_undelivered = _player.carry.count()
	var summary := SUMMARY_SCENE.instantiate()
	add_child(summary)
	await _frames(2)
	var grid: GridContainer = summary.get_node("%Grid")
	_check(grid.get_child_count() == 5, "5 item types on the boat (%d)" % grid.get_child_count())
	_check(summary.get_node("%StatsLabel").text.begins_with("ส่งขึ้นเรือ 6 ชิ้น"), "stats: %s" % summary.get_node("%StatsLabel").text)
	_check(summary.get_node("%MissingLabel").text.contains("ตกค้างในมือ 1 ชิ้น"), "undelivered shown")
	summary.queue_free()

	print("\n[J14] restart: nothing left over")
	_level.queue_free()
	await _frames(2)
	await _load_level()
	_check(BoatCargo.total_delivered == 0 and BoatCargo.get_records().is_empty(), "BoatCargo empty")
	_check(Inventory.get_used_slot_count() == 0, "boat hold empty")
	_check(_player.carry.count() == 0 and _player.state == Player.State.FREE, "hands empty")
	_check(_boat.get_cargo_visual_count() == 0, "boat deck empty")
	_check(get_tree().get_nodes_in_group(&"item_pickups").size() == 16, "all 16 pickups back (13 supplies + 3 family)")
	_check(_level.get_node("ScavengeTimer").time_left > 59.5, "timer back at 60 s")

	print("\n[family] a person needs 2 free hand slots and takes 2 boat slots")
	var mother := _pickup(&"family_mother")
	_check(mother != null and mother.item.is_person() and mother.item.slot_size == 2, "mother is a 2-slot person pickup")
	await _collect(&"water")
	await _collect(&"canned_food")
	await _stand_at(mother.global_position + Vector2(0, 26))
	_check(_player.get_nearest_pickup() == mother, "mother is the nearest pickup")
	_check(_player.try_interact() == false and is_instance_valid(mother), "2 items in hands -> cannot take mother (needs 2 free)")
	_check(_hud.message_label.text.contains("2 ช่อง"), "message explains the 2 slots: '%s'" % _hud.message_label.text)
	await _stand_at(BOAT_SPOT)
	_player.try_throw()
	await _wait_until(func() -> bool: return _player.state == Player.State.FREE and _player.carry.count() == 0, 3.0)
	await _collect(&"water")
	await _collect(&"family_mother")
	_check(_player.carry.count() == 3 and _player.carry.item_count() == 2, "water + mother = 3/3 units, 2 entries (%d, %d)" % [_player.carry.count(), _player.carry.item_count()])
	_check(_hud.carry_ui.carry_label.text == "CARRY 3/3", "UI: '%s'" % _hud.carry_ui.carry_label.text)
	_check(not _player.carry.can_add(ItemDatabase.get_item(&"rope")), "hands full")
	await _stand_at(BOAT_SPOT)
	_player.try_throw()
	await _wait_until(func() -> bool: return _player.state == Player.State.FREE and _player.carry.count() == 0, 3.0)
	_check(Inventory.get_item_count(&"family_mother") == 1, "mother is on the boat")
	_check(Inventory.get_used_slot_count() == 4, "hold: water(stacked) + canned food + mother(2) = 4 slots (%d)" % Inventory.get_used_slot_count())
	_check(Inventory.get_free_slot_count() == Inventory.max_slots - 4, "free slots account for the person")
	_check(_boat.get_cargo_visual_count() == 4, "mother rides on the deck (%d visuals)" % _boat.get_cargo_visual_count())
	# Part 1 -> Part 2 hand-off (without changing scene)
	GameState.rescued_family.clear()
	GameState.left_behind.clear()
	for member in ItemDatabase.get_family():
		if Inventory.get_item_count(member.id) > 0:
			GameState.rescued_family.append(member.survivor_id)
		else:
			GameState.left_behind.append(member.survivor_id)
	_check(GameState.rescued_family == [&"mother"] and GameState.left_behind.size() == 2, "rescued: mother; left behind: sister, grandpa")
	SurvivalState.reset()
	SurvivalState.start_with_family(GameState.rescued_family)
	_check(SurvivalState.get_survivor_count() == 2, "Part 2 starts with you + mother (%d)" % SurvivalState.get_survivor_count())
	SurvivalState.reset()
	SurvivalState.start_with_family([&"mother", &"sister", &"grandpa"])
	_check(SurvivalState.get_survivor_count() == 4, "whole family rescued -> 4 survivors")
	SurvivalState.reset()

	print("\n[layout] items move to different spots every new game")
	var house: House = _level.get_node("World/House")
	var before := {}
	for p in house.get_pickups():
		before[p] = p.position
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	house.randomize_layout(rng)
	var moved := 0
	var used := {}
	var people_on_seats := true
	var seat_positions := house.family_spots.get_children().map(func(n): return n.position)
	var spot_positions := house.item_spots.get_children().map(func(n): return n.position)
	var on_spots := true
	for p in house.get_pickups():
		if p.position != before[p]:
			moved += 1
		used[p.position] = true
		if p.item.is_person():
			people_on_seats = people_on_seats and seat_positions.has(p.position)
		else:
			on_spots = on_spots and spot_positions.has(p.position)
	var total := house.get_pickups().size()
	_check(moved >= total / 2, "most pickups moved (%d/%d)" % [moved, total])
	_check(used.size() == total, "no two pickups share a spot")
	_check(people_on_seats and on_spots, "people on seats, supplies on item spots")
	var first := {}
	for p in house.get_pickups():
		first[p] = p.position
	rng.seed = 999
	house.randomize_layout(rng)
	var differs := 0
	for p in house.get_pickups():
		if p.position != first[p]:
			differs += 1
	_check(differs > 0, "another seed gives another layout (%d differ)" % differs)
	_check(house.item_spots.get_child_count() >= 13 and house.family_spots.get_child_count() >= 3, "enough spots (%d items, %d seats)" % [house.item_spots.get_child_count(), house.family_spots.get_child_count()])

	print("\n[intro] cutscene plays its lines and can be skipped")
	_level.queue_free()
	await _frames(2)
	var intro := INTRO_SCENE.instantiate()
	intro.auto_continue = false
	add_child(intro)
	await _seconds(1.3)
	_check(intro.lines_shown >= 1 and intro.subtitle.visible, "first line on screen (%d)" % intro.lines_shown)
	for i in 5:
		intro._advance = true
		await _seconds(0.2)
	_check(intro.tv_shot.visible and intro.lines_shown >= 5, "click-through reaches the TV news (%d lines)" % intro.lines_shown)
	_check(intro.ticker.text.contains("ถนนทุกสาย") and intro.ticker.text.contains("เจ้าหน้าที่"), "news says roads are cut and officials cannot reach")
	var finished := [false]
	intro.finished.connect(func(): finished[0] = true)
	intro.skip()
	await _frames(2)
	_check(finished[0] and intro.is_done(), "skip ends the cutscene")
	intro.queue_free()

	print("\n[look] 5-second look-around before the timer starts")
	for skip_with_e in [false, true]:
		var lvl: Node2D = LEVEL_SCENE.instantiate()
		lvl.randomize_layout = false
		lvl.look_seconds = 2
		add_child(lvl)
		var pl: Player = lvl.get_node("World/Player")
		var tm: ScavengeTimer = lvl.get_node("ScavengeTimer")
		var hd: GameHUD = lvl.get_node("HUD")
		await _physics(3)
		if not skip_with_e:
			_check(lvl.is_looking() and not tm.running and is_equal_approx(tm.time_left, tm.duration), "timer waits during the countdown (%.1f)" % tm.time_left)
			_check(not pl.controls_enabled, "player cannot move or pick up yet")
			_check(hd.is_look_countdown_visible() and hd.look_number.text == "2", "countdown shows '%s'" % hd.look_number.text)
			_check(get_viewport().get_camera_2d() != pl.camera and get_viewport().get_camera_2d().zoom.x < pl.camera.zoom.x, "camera zoomed out over the whole house")
			await _seconds(2.3)
		else:
			_press(&"interact")
			await _physics(2)
		var how := "E skips the countdown" if skip_with_e else "after the countdown"
		_check(not lvl.is_looking() and tm.running and pl.controls_enabled, "%s: timer runs and controls are on" % how)
		await _seconds(0.7)
		_check(get_viewport().get_camera_2d() == pl.camera, "%s: camera back on the player" % how)
		lvl.queue_free()
		await _frames(2)

	print("\n[platform] chooser on first launch, no Part 2 test button")
	Platform.mode = Platform.PC
	Platform.chosen = false
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await _frames(2)
	var picker: PlatformPicker = null
	for child in menu.get_children():
		if child is PlatformPicker:
			picker = child
	_check(picker != null, "first launch shows the platform picker")
	_check(not menu.has_node("%Part2TestButton") and menu.find_child("Part2TestButton", true, false) == null, "Part 2 test button removed")
	picker.mobile_button.pressed.emit()
	await _frames(2)
	_check(Platform.is_mobile() and Platform.chosen and not is_instance_valid(picker), "picking mobile saves the choice and closes the picker")
	_check(menu.platform_button.text.contains("มือถือ") and menu.how_to_body.text.contains("จอยสติ๊ก"), "menu shows the mobile platform + touch how-to")
	menu.platform_button.pressed.emit()
	await _frames(2)
	var picker2: PlatformPicker = menu.get_child(menu.get_child_count() - 1) as PlatformPicker
	_check(picker2 != null and picker2.can_cancel, "bottom-left button reopens the picker (with cancel)")
	picker2.pc_button.pressed.emit()
	await _frames(2)
	_check(not Platform.is_mobile() and menu.how_to_body.text.contains("WASD"), "switching back to computer")
	menu.queue_free()
	await _frames(2)

	print("\n[mobile] touch stick + buttons drive the same actions")
	Platform.set_mode(Platform.MOBILE)
	await _load_level()
	var touch: TouchControls = null
	for child in _level.get_children():
		if child is TouchControls:
			touch = child
	_check(touch != null, "level adds touch controls on mobile")
	_check(_hud.inventory_bar.scale.x < 1.0 and _hud.inventory_bar.anchor_top == 0.0, "cargo bar moved to the top")
	await _stand_at(Vector2(600, 600))
	var from := _player.global_position
	_touch(0, Vector2(220, 520), true)
	_drag(0, Vector2(260, 520))
	await _physics(2)
	_check(Input.get_action_strength(&"move_right") > 0.4 and not Input.is_action_pressed(&"run"), "half push = walk right (%.2f)" % Input.get_action_strength(&"move_right"))
	_drag(0, Vector2(340, 520))
	await _seconds(0.3)
	_check(Input.is_action_pressed(&"run") and _player.is_running, "full push = run")
	_check(_player.global_position.x - from.x > 60.0, "player moved right with the stick (%.0f px)" % (_player.global_position.x - from.x))
	_touch(0, Vector2(340, 520), false)
	await _physics(2)
	_check(not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"run") and _player.velocity == Vector2.ZERO, "lifting the finger stops the player")
	var rope := _pickup(&"rope")
	await _stand_at(rope.global_position + Vector2(0, 26))
	_touch(0, Vector2(220, 520), true) # one finger on the stick ...
	var center := touch.interact_button.position + touch.interact_button.texture_normal.get_size() * 0.5
	_touch(1, center, true) # ... and another on "หยิบ"
	await _physics(2)
	_touch(1, center, false)
	_touch(0, Vector2(220, 520), false)
	_check(_player.state == Player.State.PICKUP, "หยิบ button picks up while the stick is held (multi-touch)")
	await _seconds(0.6)
	_check(_player.carry.count() == 1, "rope in hands")
	var pause_center := touch.pause_button.position + touch.pause_button.texture_normal.get_size() * 0.5
	_touch(2, pause_center, true)
	await _frames(2)
	_touch(2, pause_center, false)
	var pm: PauseMenu = _level.get_node("PauseMenu")
	_check(get_tree().paused and pm.visible, "II button pauses")
	await _frames(2)
	_check(not touch.visible, "touch controls hide under the pause menu")
	pm.close()
	await _frames(2)
	_check(touch.visible, "touch controls come back after resume")
	_level.queue_free()
	await _frames(2)
	Platform.set_mode(Platform.PC)

	print("\n[thai] Thai glyphs")
	var font: Font = ThemeDB.get_project_theme().default_font
	var thai := "น้ำดื่มอาหารกระป๋องยาสามัญไฟฉายแบตเตอรี่เชือกวิทยุพกพาเอกสารสำคัญโยนของขึ้นเรือมือเต็ม"
	var missing := ""
	for i in thai.length():
		if not font.has_char(thai.unicode_at(i)):
			missing += thai[i]
	_check(missing.is_empty(), "font has every Thai glyph used (missing: '%s')" % missing)


# ------------------------------------------------------------------ helpers
func _load_level() -> void:
	_level = LEVEL_SCENE.instantiate()
	_level.randomize_layout = false # fixed positions so the checks know where things are
	_level.look_seconds = 0
	add_child(_level)
	_player = _level.get_node("World/Player")
	_boat = _level.get_node("World/Boat")
	_hud = _level.get_node("HUD")
	await _physics(2)


func _pickup(id: StringName) -> ItemPickup:
	for node in get_tree().get_nodes_in_group(&"item_pickups"):
		var p := node as ItemPickup
		if p.item.id == id and p.quantity > 0 and not p.is_queued_for_deletion():
			return p
	return null


func _collect(id: StringName) -> void:
	var p := _pickup(id)
	await _stand_at(p.global_position + Vector2(0, 26))
	_player.try_interact()
	await _seconds(0.6)


func _find_throw() -> ThrowItem:
	for child in _player.get_parent().get_children():
		if child is ThrowItem:
			return child
	return null


func _teleport(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO


func _stand_at(pos: Vector2) -> void:
	_teleport(pos)
	await _physics(4)


func _move(start: Vector2, action: String, dir: Vector2, run: bool) -> float:
	await _stand_at(start)
	var from := _player.global_position
	if run:
		Input.action_press("run")
	Input.action_press(action)
	await _seconds(0.3)
	var moved := (_player.global_position - from).dot(dir)
	Input.action_release(action)
	Input.action_release("run")
	await _physics(2)
	return moved


func _push(start: Vector2, action: String, ok: Callable, label: String, run := false) -> void:
	await _stand_at(start)
	if run:
		Input.action_press("run")
	Input.action_press(action)
	await _seconds(1.0)
	Input.action_release(action)
	Input.action_release("run")
	_check(ok.call(_player.global_position), "%s blocks the player (ended at %s)" % [label, _player.global_position.round()])


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = get_tree().root.get_final_transform() * pos # viewport -> window coords
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = get_tree().root.get_final_transform() * pos # viewport -> window coords
	Input.parse_input_event(ev)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _wait_until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
	print("  %s  %s" % ["ok  " if cond else "FAIL", label])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true).timeout
