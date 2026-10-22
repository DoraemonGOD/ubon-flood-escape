class_name ScavengeTimer
extends Node
## Countdown for the scavenging phase. Counts in _process, so it stops
## automatically while the SceneTree is paused (process_mode = PAUSABLE).
## Change `duration` on the ScavengeTimer node in scavenging.tscn.

signal timer_updated(time_left: float)
signal warning_started
signal time_up

@export_range(5.0, 600.0, 1.0, "suffix:s") var duration: float = 60.0
@export_range(0.0, 120.0, 1.0, "suffix:s") var warning_threshold: float = 15.0

var time_left: float = 0.0
var running := false
var _warned := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	time_left = duration


func start() -> void:
	time_left = duration
	_warned = false
	running = true
	timer_updated.emit(time_left)


func stop() -> void:
	running = false


func is_warning() -> bool:
	return time_left <= warning_threshold


func _process(delta: float) -> void:
	if not running:
		return
	time_left = maxf(time_left - delta, 0.0)
	timer_updated.emit(time_left)
	if not _warned and time_left <= warning_threshold:
		_warned = true
		warning_started.emit()
	if time_left <= 0.0:
		running = false
		time_up.emit()
