class_name VoyageGame
extends CanvasLayer
## Voyage minigame (every few days): the boat paddles to a new place. Things float
## towards it; when the key prompt appears, press the shown direction in time
## (WASD / arrow keys, or click the on-screen arrow).
##   item     + right key in time -> grabbed onto the boat
##   obstacle + right key in time -> dodged; missed -> hit (lose an item or someone hurt)
## Emits `finished` after the result screen's button. All supply changes go
## through SurvivalState (voyage_collect / voyage_hit).

signal finished(collected: PackedStringArray, hits: PackedStringArray)

const DIRS := [&"move_up", &"move_down", &"move_left", &"move_right"]
const DIR_TEXT := {&"move_up": "↑  W", &"move_down": "↓  S", &"move_left": "←  A", &"move_right": "→  D"}
const CATCH_X := 470.0
const SPAWN_X := 1380.0
const SPEED := 330.0
const SKIES := {
	0: preload("res://assets/backgrounds/sky_dawn.svg"), 1: preload("res://assets/backgrounds/sky_day.svg"),
	2: preload("res://assets/backgrounds/sky_dusk.svg"), 3: preload("res://assets/backgrounds/night_sky.svg"),
}

## Testing / balance: when >= 0 the game plays itself with this success rate.
@export_range(-1.0, 1.0) var auto_play: float = -1.0

var destination: LocationData
var collected: PackedStringArray = []
var hits: PackedStringArray = []
var window := 1.1
var _queue: Array[Dictionary] = []
var _active: Dictionary = {} ## the spawn that currently shows a prompt
var _spawn_timer := 0.6
var _done := false
var _time := 0.0

@onready var sky: Sprite2D = $Sky
@onready var far_a: Sprite2D = $FarA
@onready var far_b: Sprite2D = $FarB
@onready var boat: Node2D = $Boat
@onready var floaters: Node2D = $Floaters
@onready var rain: CPUParticles2D = $Rain
@onready var title_label: Label = %VoyageTitle
@onready var score_label: Label = %VoyageScore
@onready var prompt: PanelContainer = %QtePrompt
@onready var prompt_label: Label = %QteKey
@onready var prompt_bar: ProgressBar = %QteBar
@onready var feedback: Label = %QteFeedback
@onready var result_panel: PanelContainer = %VoyageResult
@onready var result_text: Label = %VoyageResultText
@onready var arrive_button: Button = %ArriveButton
@onready var arrows: Array[Button] = [%ArrowUp, %ArrowDown, %ArrowLeft, %ArrowRight]


func _ready() -> void:
	result_panel.hide()
	prompt.hide()
	feedback.text = ""
	arrive_button.pressed.connect(func() -> void: finished.emit(collected, hits))
	for i in arrows.size():
		arrows[i].pressed.connect(press.bind(DIRS[i]))


## Call right after adding to the tree.
func start(dest: LocationData) -> void:
	destination = dest
	var rules := SurvivalState.rules
	window = rules.voyage_window + (rules.voyage_rope_bonus if SurvivalState.get_supply_count(&"rope") > 0 else 0.0)
	title_label.text = "ล่องเรือไป%s" % dest.name_th
	sky.texture = SKIES[int(SurvivalState.time_of_day)]
	rain.emitting = SurvivalState.weather >= SurvivalState.Weather.LIGHT_RAIN
	# the family rides along (same frames as on the big boat, smaller)
	var people := SurvivalState.get_present()
	for i in people.size():
		var person := AnimatedSprite2D.new()
		person.sprite_frames = people[i].sprite_frames
		person.centered = false
		person.offset = Vector2(-48, -120)
		person.scale = Vector2(0.62, 0.62)
		person.position = Vector2(-100 + i * 52, -46)
		person.play(&"idle")
		boat.add_child(person)
	_queue.clear()
	for i in rules.voyage_spawns:
		var obstacle := SurvivalState.rng.randf() < rules.voyage_obstacle_chance
		var entry := {"obstacle": obstacle, "dir": DIRS[SurvivalState.rng.randi_range(0, 3)]}
		if obstacle and not dest.obstacles.is_empty():
			entry.texture = load(dest.obstacles[SurvivalState.rng.randi_range(0, dest.obstacles.size() - 1)])
		elif not obstacle:
			entry.item = _roll_item()
		_queue.append(entry)
	_update_score()


func is_done() -> bool:
	return _done


## Press a direction (keyboard or on-screen arrow).
func press(dir: StringName) -> void:
	if _active.is_empty() or not _active.get("prompting", false):
		return
	_resolve(_active, dir == _active.dir)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	for dir in DIRS:
		if event.is_action_pressed(dir):
			press(dir)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	_time += delta
	# scenery scrolls to show the boat moving
	for far in [far_a, far_b]:
		far.position.x -= 40.0 * delta
		if far.position.x <= -1280.0:
			far.position.x += 2560.0
	boat.position.y = 520.0 + sin(_time * 2.2) * 5.0
	boat.rotation = sin(_time * 1.6) * 0.03
	if _done:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and not _queue.is_empty() and _active.is_empty():
		_spawn(_queue.pop_front())
		_spawn_timer = 0.9
	if not _active.is_empty():
		_move_active(delta)
	elif _queue.is_empty() and floaters.get_child_count() == 0:
		_finish()


func _spawn(entry: Dictionary) -> void:
	var sprite := Sprite2D.new()
	if entry.obstacle:
		sprite.texture = entry.get("texture", preload("res://assets/environments/outside/log.svg"))
	else:
		sprite.texture = ItemDatabase.get_item(entry.item).icon
		sprite.scale = Vector2(0.9, 0.9)
	sprite.position = Vector2(SPAWN_X, 540 + SurvivalState.rng.randf_range(-14, 14))
	floaters.add_child(sprite)
	entry.node = sprite
	entry.prompting = false
	_active = entry


func _move_active(delta: float) -> void:
	var node: Sprite2D = _active.node
	node.position.x -= SPEED * delta
	node.position.y += sin(_time * 3.0) * 0.3
	var time_to_boat := (node.position.x - CATCH_X) / SPEED
	if not _active.prompting and time_to_boat <= window:
		_active.prompting = true
		prompt_label.text = DIR_TEXT[_active.dir]
		prompt.show()
		if auto_play >= 0.0:
			var ok := SurvivalState.rng.randf() < auto_play
			_resolve(_active, ok)
			return
	if _active.prompting:
		prompt_bar.value = clampf(time_to_boat / window, 0.0, 1.0) * 100.0
		prompt.position = Vector2(node.position.x - prompt.size.x * 0.5, node.position.y - 150)
		if time_to_boat <= 0.0:
			_resolve(_active, false)


func _resolve(entry: Dictionary, success: bool) -> void:
	_active = {}
	prompt.hide()
	var node: Sprite2D = entry.node
	var tween := node.create_tween()
	if not entry.obstacle:
		if success:
			var item := ItemDatabase.get_item(entry.item)
			SurvivalState.voyage_collect(entry.item)
			collected.append(item.name_th)
			_flash("+ " + item.name_th, Color("dcb65a"))
			tween.tween_property(node, "position", boat.position + Vector2(0, -40), 0.35).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(node, "scale", Vector2(0.3, 0.3), 0.35)
		else:
			_flash("พลาด!", Color("e2583e"))
			tween.tween_property(node, "position:x", -120.0, 1.6)
	else:
		if success:
			_flash("หลบได้!", Color("9fd08a"))
			var bt := boat.create_tween()
			bt.tween_property(boat, "position:x", boat.position.x - 40, 0.2)
			bt.tween_property(boat, "position:x", boat.position.x, 0.4)
			tween.tween_property(node, "position", Vector2(-160, node.position.y + 40), 1.4)
		else:
			var what := SurvivalState.voyage_hit()
			hits.append(what)
			_flash("ชน! " + what, Color("e2583e"))
			var bt := boat.create_tween()
			for k in 4:
				bt.tween_property(boat, "rotation", 0.12 if k % 2 == 0 else -0.12, 0.06)
			bt.tween_property(boat, "rotation", 0.0, 0.06)
			tween.tween_property(node, "position:x", -160.0, 1.2)
	tween.tween_callback(node.queue_free)
	_update_score()


func _flash(text: String, color: Color) -> void:
	feedback.text = text
	feedback.add_theme_color_override(&"font_color", color)
	feedback.modulate.a = 1.0
	var t := feedback.create_tween()
	t.tween_interval(0.7)
	t.tween_property(feedback, "modulate:a", 0.0, 0.4)


func _update_score() -> void:
	score_label.text = "เก็บได้ %d  ·  ชน %d  ·  เหลืออีก %d" % [collected.size(), hits.size(), _queue.size() + (0 if _active.is_empty() else 1)]


func _finish() -> void:
	_done = true
	prompt.hide()
	var lines: PackedStringArray = []
	lines.append("ถึง%sแล้ว" % destination.name_th)
	lines.append("เก็บของได้: " + (", ".join(collected) if not collected.is_empty() else "ไม่ได้อะไรเลย"))
	if not hits.is_empty():
		lines.append("ชนสิ่งกีดขวาง %d ครั้ง: %s" % [hits.size(), ", ".join(hits)])
	result_text.text = "\n".join(lines)
	arrive_button.text = "ถึง%s ▸" % destination.name_th
	result_panel.show()
	arrive_button.grab_focus()
	if auto_play >= 0.0:
		finished.emit.call_deferred(collected, hits)


func _roll_item() -> StringName:
	var ids: Array = destination.loot_table.keys()
	var weights: Array = destination.loot_table.values()
	if ids.is_empty():
		return &"water"
	return StringName(ids[SurvivalState._weighted_index(weights)])
