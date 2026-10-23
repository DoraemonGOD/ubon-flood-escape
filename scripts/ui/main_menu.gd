extends Control
## Main menu. On first launch it asks which device the game is played on (Platform);
## the small button at the bottom left changes it later.

const HOW_TO_TAIL := "\n\nน้ำจะท่วมถึงบ้านใน 60 วินาที วิ่งขนของจำเป็นไปโยนขึ้นเรือ\nของและคนที่อยู่บนเรือเท่านั้นที่จะไปต่อในช่วงเอาชีวิตรอด — ของอยู่คนละที่ทุกครั้งที่เริ่มใหม่"
const HOW_TO_PC := "• WASD หรือปุ่มลูกศร — เดิน   • Shift — วิ่ง\n• E — หยิบของ / พาคนในบ้านไปด้วย (มือว่าง 3 ช่อง, คน 1 คน = 2 ช่อง)\n• Q — โยนของขึ้นเรือ (ต้องยืนที่ระเบียงข้างเรือ)\n• Esc — หยุดเกม / เล่นต่อ" + HOW_TO_TAIL
const HOW_TO_MOBILE := "• จอยสติ๊ก (แตะค้างฝั่งซ้ายของจอ) — เดิน · ดันสุดขอบ = วิ่ง\n• ปุ่ม หยิบ — หยิบของ / พาคนในบ้านไปด้วย (มือว่าง 3 ช่อง, คน 1 คน = 2 ช่อง)\n• ปุ่ม โยน — โยนของขึ้นเรือ (ต้องยืนที่ระเบียงข้างเรือ)\n• ปุ่ม II — หยุดเกม · ถือโทรศัพท์แนวนอน" + HOW_TO_TAIL

@onready var start_button: Button = %StartButton
@onready var how_to_button: Button = %HowToButton
@onready var quit_button: Button = %QuitButton
@onready var platform_button: Button = %PlatformButton
@onready var how_to_body: Label = $HowToPanel/VBox/Body
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
	platform_button.pressed.connect(open_platform_picker.bind(true))
	_refresh_platform()
	start_button.grab_focus()
	if not Platform.chosen:
		open_platform_picker(false)


## Shows the computer / phone chooser. can_cancel = false on first launch.
func open_platform_picker(can_cancel: bool) -> PlatformPicker:
	var picker := PlatformPicker.new()
	picker.can_cancel = can_cancel
	add_child(picker)
	picker.picked.connect(func(mode: StringName) -> void:
		Platform.set_mode(mode)
		picker.queue_free()
		_refresh_platform()
		start_button.grab_focus())
	picker.cancelled.connect(func() -> void:
		picker.queue_free()
		platform_button.grab_focus())
	return picker


func _refresh_platform() -> void:
	platform_button.text = "เล่นบน: " + ("มือถือ / แท็บเล็ต" if Platform.is_mobile() else "คอมพิวเตอร์")
	how_to_body.text = HOW_TO_MOBILE if Platform.is_mobile() else HOW_TO_PC


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
