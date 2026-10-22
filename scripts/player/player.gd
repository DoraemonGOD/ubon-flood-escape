class_name Player
extends CharacterBody2D
## PlayerController: walk / run (Shift), facing, picking items up into the
## CarryInventory (E) and throwing them onto a Boat (Q). The origin is at the feet.
##
## Animation setup:
## - AnimatedSprite2D holds the drawn frames (assets/characters/player_frames.tres):
##   locomotion sets idle/walk/run/carry_idle/carry_walk/carry_run_<dir> play by themselves,
##   pose sets pickup_<dir> (2 frames) and throw_<dir> (3 frames) are stepped by the AnimationPlayer.
## - AnimationPlayer (assets/characters/player_animations.tres) has pickup, throw_start,
##   throw_release, throw_recover: frame keys + squash/dip keys + method keys that call
##   _on_pickup_grab_frame() and _on_throw_release_frame() at the exact moment.

signal nearest_pickup_changed(pickup: ItemPickup) ## null when no item is in reach
signal boat_range_changed(boat: Boat) ## null when out of the boat zone
signal throw_started(item_count: int)
signal feedback(text: String, is_warning: bool) ## short message for the HUD

enum State { FREE, PICKUP, THROW }

const THROW_SCENE := preload("res://scenes/items/throw_item.tscn")
## Height of the hands above the feet when an item is released (px).
const HAND_HEIGHT := 46.0
## Height above the deck where a landed item rests (px).
const DECK_HEIGHT := 12.0

@export var move_speed: float = 230.0
@export var run_speed: float = 380.0

var controls_enabled := true
var facing := &"down" ## down / up / side
var state: State = State.FREE
var is_running := false

var _nearby: Array[ItemPickup] = []
var _nearest: ItemPickup = null
var _boat: Boat = null
var _pickup_target: ItemPickup = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var carry: CarryInventory = $CarryInventory
@onready var carry_stack: Node2D = $CarryStack
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	anim.animation_finished.connect(_on_animation_finished)
	carry.carry_inventory_changed.connect(_update_carry_stack)
	sprite.play(&"idle_down")
	_update_carry_stack()


func _physics_process(_delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled and state == State.FREE:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	is_running = input != Vector2.ZERO and Input.is_action_pressed(&"run")
	velocity = input * (run_speed if is_running else move_speed)
	move_and_slide()
	if state == State.FREE:
		_update_locomotion(input)
	_update_nearest()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	# is_action_pressed() ignores key-repeat echoes, so holding E or Q fires once.
	if event.is_action_pressed(&"interact"):
		try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"throw"):
		try_throw()
		get_viewport().set_input_as_handled()


## E: starts picking up the nearest item. Returns true if the pickup animation started.
func try_interact() -> bool:
	if not controls_enabled or state != State.FREE:
		return false
	if _nearest == null or not is_instance_valid(_nearest):
		return false
	if not carry.can_add(_nearest.item):
		if _nearest.item.slot_size > 1:
			feedback.emit("ต้องมีมือว่าง %d ช่องถึงจะพา%sไปได้ (CARRY %d/%d)" % [_nearest.item.slot_size, _nearest.item.name_th, carry.count(), CarryInventory.MAX_CARRY_ITEMS], true)
		else:
			feedback.emit("มือเต็มแล้ว! (CARRY %d/%d) ไปโยนของขึ้นเรือก่อน" % [carry.count(), CarryInventory.MAX_CARRY_ITEMS], true)
		return false
	if not _nearest.reserve():
		return false
	_pickup_target = _nearest
	state = State.PICKUP
	_face_towards(_pickup_target.global_position)
	_enter_pose(&"pickup")
	anim.play(&"pickup")
	return true


## Q: starts throwing everything held onto the boat. Returns true if the throw started.
func try_throw() -> bool:
	if not controls_enabled or state != State.FREE:
		return false
	if _boat == null:
		if not carry.is_empty():
			feedback.emit("ต้องเข้าใกล้เรือก่อนถึงจะโยนได้", true)
		return false
	if not carry.has_throwable():
		feedback.emit("ไม่มีของที่ต้องโยน", true)
		return false
	if not BoatCargo.can_accept(carry.get_held_item_data()):
		feedback.emit("เรือเต็มแล้ว!", true)
		return false
	state = State.THROW
	_face_towards(_boat.get_drop_center())
	_enter_pose(&"throw")
	throw_started.emit(carry.get_held_item_data().size())
	anim.play(&"throw_start")
	return true


## Stops any pickup/throw in progress without losing items, and returns to idle.
func cancel_action() -> void:
	if state == State.PICKUP and _pickup_target != null and is_instance_valid(_pickup_target):
		_pickup_target.release_reservation()
	_pickup_target = null
	if state != State.FREE:
		anim.stop()
		_exit_pose()


func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	if not value:
		cancel_action()
		velocity = Vector2.ZERO
		_update_locomotion(Vector2.ZERO)
		_set_nearest(null)


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()


func get_nearest_pickup() -> ItemPickup:
	return _nearest


func get_boat() -> Boat:
	return _boat


## Called by Boat's InteractionZone.
func set_boat_in_range(boat: Boat, in_range: bool) -> void:
	if in_range:
		_boat = boat
	elif _boat == boat:
		_boat = null
	boat_range_changed.emit(_boat)


# ------------------------------------------------- AnimationPlayer method keys
## Method key in "pickup": the hand reaches the item now.
func _on_pickup_grab_frame() -> void:
	if state != State.PICKUP or _pickup_target == null or not is_instance_valid(_pickup_target):
		return
	var target := _pickup_target
	_pickup_target = null
	if carry.add(target.item):
		target.take_one()
	else:
		target.release_reservation()


## Method key in "throw_release": the next held item leaves the hand now.
func _on_throw_release_frame() -> void:
	if state != State.THROW or _boat == null:
		return
	var entry := carry.begin_throw()
	if entry == null:
		return
	var throw: ThrowItem = THROW_SCENE.instantiate()
	get_parent().add_child(throw)
	throw.launch(entry.item, global_position + _hand_ground_offset(), HAND_HEIGHT, _boat.next_drop_position(), DECK_HEIGHT)
	throw.landed.connect(_on_throw_landed.bind(entry, _boat))


func _on_throw_landed(throw: ThrowItem, entry: CarryInventory.CarriedItem, boat: Boat) -> void:
	# Only now does the item count: BoatCargo first, then it leaves the hands.
	if BoatCargo.deliver(entry.item):
		carry.confirm_thrown(entry)
		if is_instance_valid(boat):
			boat.on_item_landed(entry.item, throw.global_position, throw.end_height)
	else:
		carry.cancel_throw(entry)
		feedback.emit("เรือเต็มแล้ว! %s ยังอยู่ในมือ" % entry.item.name_th, true)


func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		&"pickup":
			_exit_pose()
		&"throw_start":
			anim.play(&"throw_release")
		&"throw_release":
			if controls_enabled and carry.has_throwable() and _boat != null:
				anim.play(&"throw_start", -1.0, 2.5) # quick wind-up for the next item
			else:
				anim.play(&"throw_recover")
		&"throw_recover":
			_exit_pose()


# ------------------------------------------------------------------ visuals
func _enter_pose(pose_set: StringName) -> void:
	sprite.animation = StringName("%s_%s" % [pose_set, facing])
	sprite.stop()
	_update_carry_stack()


func _exit_pose() -> void:
	state = State.FREE
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	_update_locomotion(Vector2.ZERO)


func _update_locomotion(input: Vector2) -> void:
	if input != Vector2.ZERO:
		if absf(input.x) >= absf(input.y):
			facing = &"side"
			sprite.flip_h = input.x < 0.0
		else:
			facing = &"up" if input.y < 0.0 else &"down"
	var kind := "idle"
	if input != Vector2.ZERO:
		kind = "run" if is_running else "walk"
	var anim_name := StringName("%s%s_%s" % ["carry_" if carry.has_throwable() else "", kind, facing])
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
	_update_carry_stack()


func _face_towards(target: Vector2) -> void:
	var d := target - global_position
	if absf(d.x) >= absf(d.y):
		facing = &"side"
		sprite.flip_h = d.x < 0.0
	else:
		facing = &"up" if d.y < 0.0 else &"down"


func _hand_ground_offset() -> Vector2:
	match facing:
		&"side":
			return Vector2(-16.0 if sprite.flip_h else 16.0, 0)
		&"up":
			return Vector2(0, -6)
	return Vector2(0, 8)


## Shows the held items in the character's arms (in-flight ones are hidden).
func _update_carry_stack() -> void:
	var held := carry.get_held_item_data()
	var base := Vector2(0, -38)
	match facing:
		&"side":
			base = Vector2(-15.0 if sprite.flip_h else 15.0, -42)
		&"up":
			base = Vector2(0, -50)
	# facing away: the stack is in front of the body, i.e. hidden behind it
	var want_behind := facing == &"up"
	if want_behind != (carry_stack.get_index() < sprite.get_index()):
		move_child(carry_stack, 0 if want_behind else sprite.get_index())
	var icons := carry_stack.get_children()
	for i in icons.size():
		var icon := icons[i] as Sprite2D
		icon.visible = i < held.size() and state != State.PICKUP
		if icon.visible:
			icon.texture = held[i].icon
			icon.position = base + Vector2((i % 2) * 6.0 - 3.0, -i * 10.0)


# ------------------------------------------------------------------ pickups
func _update_nearest() -> void:
	var best: ItemPickup = null
	if controls_enabled:
		var best_dist := INF
		for pickup in _nearby:
			if not is_instance_valid(pickup) or not pickup.can_be_collected():
				continue
			var dist := global_position.distance_squared_to(pickup.global_position)
			if dist < best_dist:
				best_dist = dist
				best = pickup
	_set_nearest(best)


func _set_nearest(pickup: ItemPickup) -> void:
	if pickup == _nearest:
		return
	if _nearest != null and is_instance_valid(_nearest):
		_nearest.set_highlighted(false)
	_nearest = pickup
	if _nearest != null:
		_nearest.set_highlighted(true)
	nearest_pickup_changed.emit(_nearest)


func _on_area_entered(area: Area2D) -> void:
	if area is ItemPickup and not _nearby.has(area):
		_nearby.append(area)


func _on_area_exited(area: Area2D) -> void:
	_nearby.erase(area)
