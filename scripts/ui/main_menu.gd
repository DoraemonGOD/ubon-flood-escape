extends Control

@onready var start_button: Button = %StartButton
@onready var how_to_button: Button = %HowToButton
@onready var quit_button: Button = %QuitButton
@onready var part2_test_button: Button = %Part2TestButton
@onready var how_to_panel: PanelContainer = %HowToPanel
@onready var close_how_to_button: Button = %CloseHowToButton


func _ready() -> void:
	get_tree().paused = false
	how_to_panel.hide()
	start_button.pressed.connect(GameState.start_new_game.bind(true))
	how_to_button.pressed.connect(_show_how_to)
	close_how_to_button.pressed.connect(_hide_how_to)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web") # a browser tab cannot be closed by the game
	# opens Part 2 directly with sample supplies (no Part 1 run needed)
	part2_test_button.pressed.connect(GameState.start_part_2_test)
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if how_to_panel.visible and event.is_action_pressed(&"pause"):
		_hide_how_to()
		get_viewport().set_input_as_handled()


func _show_how_to() -> void:
	how_to_panel.show()
	close_how_to_button.grab_focus()


func _hide_how_to() -> void:
	how_to_panel.hide()
	how_to_button.grab_focus()
