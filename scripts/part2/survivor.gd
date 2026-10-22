class_name Survivor
extends Node2D
## A survivor sitting in the boat. Shows SurvivorData.sprite_frames:
## "idle" (breathing, loops) and now and then "look" (glances around).
## Origin = where the person sits (bottom-centre of the 96x128 frame).

@export var data: SurvivorData:
	set(value):
		data = value
		if is_node_ready():
			_apply()
## Seconds between glances (random in this range).
@export var look_interval: Vector2 = Vector2(3.5, 8.0)
@export var look_duration: float = 1.6

var _next_look := 0.0
var _look_left := 0.0
var _time := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var status_row: Node2D = $StatusRow


func _ready() -> void:
	_apply()
	_time = randf() * TAU # people don't breathe in sync
	_next_look = randf_range(look_interval.x, look_interval.y)


func _apply() -> void:
	if data == null:
		return
	sprite.sprite_frames = data.sprite_frames
	sprite.play(&"idle")
	sprite.frame = randi() % 2
	update_status()


## Little bubbles above the head (thirst, hunger, sick, injured) + a pale tint when unwell.
func update_status() -> void:
	if data == null or not is_node_ready():
		return
	for child in status_row.get_children():
		child.queue_free()
	var icons := SurvivalState.status_icons(data)
	for i in icons.size():
		var icon := Sprite2D.new()
		icon.texture = load("res://assets/ui/status/%s.svg" % icons[i])
		icon.position = Vector2((i - (icons.size() - 1) * 0.5) * 30.0, 0)
		status_row.add_child(icon)
	sprite.modulate = Color(0.85, 1.0, 0.82) if data.condition == SurvivorData.Condition.SICK else Color.WHITE


func _process(delta: float) -> void:
	_time += delta
	# a tiny shiver/sway on top of the frame animation
	sprite.rotation = sin(_time * 0.9) * 0.012
	if _look_left > 0.0:
		_look_left -= delta
		if _look_left <= 0.0:
			sprite.play(&"idle")
		return
	_next_look -= delta
	if _next_look <= 0.0:
		sprite.play(&"look")
		_look_left = look_duration
		_next_look = randf_range(look_interval.x, look_interval.y)
