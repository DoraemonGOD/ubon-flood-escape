extends Node2D
## Controller for scenes/scavenging/scavenging.tscn: connects the player, boat,
## timer, HUD and pause menu, plays sounds, and ends the phase when time runs out.

signal scavenging_finished

## Capacity of the boat hold = the permanent Inventory autoload (slots).
@export_range(1, 16) var boat_hold_slots: int = 12
## 0 = no weight limit.
@export_range(0.0, 200.0, 0.5, "suffix:kg") var max_boat_weight: float = 0.0
## Seconds the "time's up" banner stays before the summary opens.
@export var end_delay: float = 1.8
## Shuffle where supplies and family members are every new game (tests turn it off).
@export var randomize_layout: bool = true
## Seconds to look over the whole house (zoomed out) before the 60 s timer starts. 0 = start at once.
@export_range(0, 10) var look_seconds: int = 5

var _finished := false
var _looking := false
var _look_camera: Camera2D
var _last_whole_second := -1

@onready var house: House = $World/House
@onready var player: Player = $World/Player
@onready var boat: Boat = $World/Boat
@onready var scavenge_timer: ScavengeTimer = $ScavengeTimer
@onready var hud: GameHUD = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var pickup_sfx: AudioStreamPlayer = $Sfx/Pickup
@onready var error_sfx: AudioStreamPlayer = $Sfx/Error
@onready var tick_sfx: AudioStreamPlayer = $Sfx/Tick
@onready var time_up_sfx: AudioStreamPlayer = $Sfx/TimeUp
@onready var throw_sfx: AudioStreamPlayer = $Sfx/Throw
@onready var thud_sfx: AudioStreamPlayer = $Sfx/Thud


func _ready() -> void:
	get_tree().paused = false
	Inventory.configure(boat_hold_slots, max_boat_weight)
	BoatCargo.reset()
	if randomize_layout:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		house.randomize_layout(rng)
	player.global_position = house.get_player_spawn()
	player.set_camera_limits(house.camera_limits)
	hud.bind(player, scavenge_timer)
	if Platform.is_mobile():
		add_child(TouchControls.new())
		hud.apply_mobile_layout()
	player.carry.item_picked_up.connect(_on_item_picked_up)
	player.throw_started.connect(_on_throw_started)
	player.feedback.connect(_on_player_feedback)
	BoatCargo.item_delivered.connect(_on_item_delivered)
	Inventory.add_failed.connect(_on_add_failed)
	scavenge_timer.timer_updated.connect(_on_timer_updated)
	scavenge_timer.time_up.connect(_on_time_up)
	pause_menu.enabled = true
	if look_seconds > 0:
		_look_around()
	else:
		scavenge_timer.start()


func is_looking() -> bool:
	return _looking


## Zoomed-out view of the whole house with a countdown, so the player can plan a route.
func _look_around() -> void:
	_looking = true
	player.set_controls_enabled(false)
	var rect := house.camera_limits
	var view := get_viewport_rect().size
	_look_camera = Camera2D.new()
	_look_camera.position = rect.get_center()
	var z := minf(view.x / rect.size.x, view.y / rect.size.y)
	_look_camera.zoom = Vector2.ONE * z
	$World.add_child(_look_camera)
	_look_camera.make_current()
	for n in range(look_seconds, 0, -1):
		if not _looking:
			return
		hud.show_look_countdown(n)
		tick_sfx.play()
		await get_tree().create_timer(1.0, false).timeout
	_start_round()


func _start_round() -> void:
	if not _looking:
		return
	_looking = false
	hud.show_look_countdown(0)
	pickup_sfx.play()
	# glide from the overview to the player, then hand over to the player's camera
	var cam := _look_camera
	var tween := create_tween().set_parallel()
	tween.tween_property(cam, "global_position", player.camera.get_screen_center_position(), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cam, "zoom", player.camera.zoom, 0.5).set_trans(Tween.TRANS_SINE)
	player.set_controls_enabled(true)
	scavenge_timer.start()
	await tween.finished
	player.camera.make_current()
	cam.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _looking and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		get_viewport().set_input_as_handled()
		_start_round()


func is_finished() -> bool:
	return _finished


func _on_item_picked_up(_item: ItemData) -> void:
	pickup_sfx.play()


func _on_throw_started(_count: int) -> void:
	throw_sfx.play()


func _on_item_delivered(_item: ItemData, _total: int) -> void:
	thud_sfx.play()


func _on_player_feedback(_text: String, is_warning: bool) -> void:
	if is_warning:
		error_sfx.play()


func _on_add_failed(_item: ItemData, _reason: StringName) -> void:
	error_sfx.play()


func _on_timer_updated(time_left: float) -> void:
	var whole := ceili(time_left)
	if whole != _last_whole_second:
		_last_whole_second = whole
		if scavenge_timer.is_warning() and time_left > 0.0:
			tick_sfx.play()


func _on_time_up() -> void:
	if _finished:
		return
	_finished = true
	# Stops pickup/throw input. A throw already in the air still lands and counts.
	player.set_controls_enabled(false)
	get_tree().call_group(&"item_pickups", &"disable")
	pause_menu.enabled = false
	hud.show_time_up()
	time_up_sfx.play()
	scavenging_finished.emit()
	await get_tree().create_timer(end_delay).timeout
	GameState.finish_scavenging(scavenge_timer.time_left, scavenge_timer.duration, player.carry.item_count())
