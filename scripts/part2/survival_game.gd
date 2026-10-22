extends Node2D
## Part 2 survival scene: the family's boat on the flood + the journal.
## The game rules live in SurvivalState; this script connects the journal, the boat,
## the changing backdrop, the voyage minigame, the day transition and the ending.

const VOYAGE_SCENE := preload("res://scenes/part2/voyage.tscn")

## The retry button reloads this scene. Tests turn this off.
@export var reload_on_retry: bool = true
## Testing / balance: voyages play themselves with this success rate (-1 = player plays).
@export_range(-1.0, 1.0) var voyage_auto_play: float = -1.0

var _busy := false
var _voyage: VoyageGame

@onready var boat: SurvivalBoat = $World/Boat
@onready var backdrop: Backdrop = $Background
@onready var rain: CPUParticles2D = $Rain
@onready var night_tint: CanvasModulate = $NightTint
@onready var status_bar: StatusBar = %StatusBar
@onready var journal: Journal = %Journal
@onready var ending_panel: EndingPanel = %EndingPanel
@onready var transition: ColorRect = %DayTransition
@onready var transition_label: Label = %TransitionLabel


func _ready() -> void:
	get_tree().paused = false
	SurvivalState.ensure_started()
	boat.refresh()
	status_bar.set_titles("SURVIVAL DIARY", "บันทึกเอาชีวิตรอดกลางสายน้ำ")
	journal.end_day_pressed.connect(end_day)
	SurvivalState.state_changed.connect(_on_state_changed)
	ending_panel.retry_requested.connect(retry)
	ending_panel.new_game_requested.connect(GameState.start_new_game)
	ending_panel.menu_requested.connect(GameState.go_to_main_menu)
	_apply_backdrop()
	transition.show()
	transition.modulate.a = 1.0
	transition_label.text = "วันที่ %d" % SurvivalState.day
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(transition, "modulate:a", 0.0, 0.8)
	tween.tween_callback(transition.hide)
	if SurvivalState.is_finished():
		ending_panel.open(SurvivalState.ending)


## "จบวัน": voyage minigame first (if a destination was picked), then fade to
## black, run the night, fade back in on the next journal page.
func end_day() -> void:
	if _busy or SurvivalState.is_finished():
		return
	_busy = true
	journal.set_locked(true)
	if SurvivalState.voyage_destination != &"":
		_start_voyage()
	else:
		_play_night()


func is_voyage_running() -> bool:
	return _voyage != null and is_instance_valid(_voyage)


func get_voyage() -> VoyageGame:
	return _voyage


func retry() -> void:
	SurvivalState.restart_survival()
	if reload_on_retry:
		get_tree().reload_current_scene()


func _start_voyage() -> void:
	_voyage = VOYAGE_SCENE.instantiate()
	_voyage.auto_play = voyage_auto_play
	add_child(_voyage)
	_voyage.start(SurvivalState.locations[SurvivalState.voyage_destination])
	_voyage.finished.connect(_on_voyage_finished, CONNECT_ONE_SHOT)


func _on_voyage_finished(collected: PackedStringArray, hits: PackedStringArray) -> void:
	SurvivalState.complete_voyage(collected, hits)
	_voyage.queue_free()
	_voyage = null
	_play_night()


func _play_night() -> void:
	transition.show()
	transition.modulate.a = 0.0
	transition_label.text = "คืนที่ %d ผ่านไป..." % SurvivalState.day
	var tween := create_tween()
	tween.tween_property(transition, "modulate:a", 1.0, 0.5)
	tween.tween_callback(_run_night)
	tween.tween_interval(0.9)
	tween.tween_property(transition, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_after_night)


func _run_night() -> void:
	SurvivalState.end_day()
	if not SurvivalState.is_finished():
		transition_label.text = "วันที่ %d" % SurvivalState.day
	journal.show_page(0)


func _after_night() -> void:
	transition.hide()
	_busy = false
	journal.set_locked(false)
	if SurvivalState.is_finished():
		journal.hide()
		ending_panel.open(SurvivalState.ending)


func _on_state_changed() -> void:
	boat.refresh_survivors()
	_apply_backdrop()


func _apply_backdrop() -> void:
	var lamps: Array[Node] = [boat.get_node("Hull/LampLight")]
	backdrop.apply(night_tint, rain, lamps)
