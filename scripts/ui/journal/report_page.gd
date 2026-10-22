extends ScrollContainer
## Journal tab 1 "บันทึก": what happened last night + everyone's condition.
## Also the radio: listening uses power and may teach how to call rescue boats.

@onready var lines_label: Label = %ReportLines
@onready var radio_button: Button = %RadioButton


func _ready() -> void:
	radio_button.pressed.connect(_on_radio_pressed)
	SurvivalState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	lines_label.text = "\n".join(SurvivalState.journal) if not SurvivalState.journal.is_empty() else "..."
	var has_radio := SurvivalState.get_supply_count(&"radio") > 0
	radio_button.visible = has_radio and not SurvivalState.is_finished()
	if not has_radio:
		return
	radio_button.disabled = not SurvivalState.can_listen_radio()
	if SurvivalState.radio_used_today:
		radio_button.text = "ฟังวิทยุไปแล้ววันนี้"
	elif radio_button.disabled:
		radio_button.text = "วิทยุไม่มีไฟ — ต้องมีแบตเตอรี่"
	else:
		radio_button.text = "เปิดวิทยุฟังข่าว (ไฟเหลือ %d)" % SurvivalState.charge[&"radio"]


func _on_radio_pressed() -> void:
	SurvivalState.listen_radio()
	await get_tree().process_frame
	scroll_vertical = int(get_v_scroll_bar().max_value)
