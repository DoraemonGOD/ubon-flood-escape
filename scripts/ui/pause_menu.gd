class_name PauseMenu
extends CanvasLayer
## Esc opens/closes. Pauses the whole SceneTree, which also freezes the
## ScavengeTimer (it only counts while not paused). process_mode = ALWAYS.

signal pause_toggled(is_paused: bool)

## The level turns this off when time is up so the game can't be paused mid-transition.
var enabled := true:
	set(value):
		enabled = value
		if not enabled and visible:
			close()

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	hide()
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(GameState.start_new_game)
	menu_button.pressed.connect(GameState.go_to_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if visible:
		close()
	elif enabled:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	if not enabled:
		return
	get_tree().paused = true
	show()
	resume_button.grab_focus()
	pause_toggled.emit(true)


func close() -> void:
	get_tree().paused = false
	hide()
	pause_toggled.emit(false)
