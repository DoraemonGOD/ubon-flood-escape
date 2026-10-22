extends ScrollContainer
## Journal tab 5 "ล่องเรือ": every few days the family can paddle somewhere new.
## Pick a destination here; the voyage minigame plays when the day ends.

@onready var info_label: Label = %VoyageInfo
@onready var options_box: VBoxContainer = %VoyageOptions


func _ready() -> void:
	SurvivalState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in options_box.get_children():
		options_box.remove_child(child)
		child.queue_free()
	var here := SurvivalState.get_location()
	var here_text := "ตอนนี้อยู่ที่: %s\n%s" % [here.name_th, here.description] if here else ""
	if SurvivalState.is_finished():
		info_label.text = here_text
		return
	if not SurvivalState.is_voyage_day():
		info_label.text = "%s\n\nล่องเรือย้ายที่ได้อีกครั้งในวันที่ %d" % [here_text, SurvivalState.next_voyage_day()]
		return
	if not SurvivalState.can_voyage():
		var why := "ต้องรอคนที่ออกสำรวจกลับมาก่อน" if not SurvivalState.expedition.is_empty() or not SurvivalState.expedition_plan.is_empty() else "ล่องเรือไปแล้ววันนี้"
		info_label.text = "%s\n\nวันนี้ล่องเรือได้ แต่%s" % [here_text, why]
		return
	info_label.text = "%s\n\nวันนี้ล่องเรือย้ายที่ได้! ระหว่างทางต้องกดปุ่มให้ทันเพื่อเก็บของที่ลอยมาและหลบสิ่งกีดขวาง" % here_text
	var group := ButtonGroup.new()
	options_box.add_child(_option("อยู่ที่เดิม", "", &"", group))
	for loc in SurvivalState.voyage_options():
		options_box.add_child(_option(loc.name_th, loc.description, loc.id, group))


func get_option_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in options_box.get_children():
		if not child.is_queued_for_deletion():
			result.append(child)
	return result


func _option(title: String, desc: String, id: StringName, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.name = String(id) if id != &"" else "stay"
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = SurvivalState.voyage_destination == id
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override(&"font_size", 17)
	b.text = title + ("\n" + desc if desc != "" else "")
	b.pressed.connect(func() -> void: SurvivalState.plan_voyage(id))
	return b
