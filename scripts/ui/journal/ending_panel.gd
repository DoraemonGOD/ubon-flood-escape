class_name EndingPanel
extends PanelContainer
## End of the survival phase: rescued / reached the evacuation centre / nobody survived.

signal retry_requested
signal new_game_requested
signal menu_requested

@onready var title_label: Label = %EndingTitle
@onready var story_label: Label = %EndingStory
@onready var people_label: Label = %EndingPeople
@onready var retry_button: Button = %RetryButton
@onready var new_game_button: Button = %NewGameButton
@onready var menu_button: Button = %EndMenuButton


func _ready() -> void:
	retry_button.pressed.connect(retry_requested.emit)
	new_game_button.pressed.connect(new_game_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)
	hide()


func open(ending: StringName) -> void:
	title_label.text = SurvivalState.get_ending_title(ending)
	story_label.text = "\n".join(SurvivalState.journal)
	var lines: PackedStringArray = []
	var alive := 0
	for s in SurvivalState.survivors:
		var state := "รอดชีวิต"
		if not s.is_alive():
			state = "สูญหาย" if s.away else "เสียชีวิต"
		elif s.away:
			state = "ยังไม่กลับมาจากการสำรวจ"
		else:
			alive += 1
		lines.append("• %s — %s" % [s.display_name, state])
	lines.append("")
	lines.append("อยู่กลางสายน้ำ %d วัน · รอด %d จาก %d คน" % [SurvivalState.day, alive, SurvivalState.survivors.size()])
	if ending != &"all_dead":
		if SurvivalState.get_supply_count(&"documents") > 0:
			lines.append("เอกสารสำคัญที่ติดมาทำให้ลงทะเบียนรับความช่วยเหลือได้ทันที")
		else:
			lines.append("ไม่มีเอกสารติดตัว ต้องใช้เวลาหลายวันกว่าจะยืนยันตัวตนได้")
	people_label.text = "\n".join(lines)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	retry_button.grab_focus()
