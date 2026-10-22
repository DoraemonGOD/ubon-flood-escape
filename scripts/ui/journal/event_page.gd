extends ScrollContainer
## Journal tab 3 "เหตุการณ์": today's event. Answers that need an item show its icon
## and are greyed out ("ต้องมี ...") when you don't have it — that is where the
## things you grabbed in Part 1 pay off.

@onready var title_label: Label = %EventTitle
@onready var text_label: Label = %EventText
@onready var choices_box: VBoxContainer = %Choices
@onready var hint_label: Label = %EventHint


func _ready() -> void:
	SurvivalState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	var ev := SurvivalState.current_event
	if ev == null:
		title_label.text = "วันนี้เงียบสงบ"
		text_label.text = "ไม่มีอะไรเกิดขึ้นเป็นพิเศษ เสียงฝนกระทบผิวน้ำเป็นเพื่อนเราทั้งวัน"
		hint_label.text = ""
		return
	title_label.text = SurvivalState.get_event_title()
	text_label.text = SurvivalState.get_event_text()
	for i in ev.choices.size():
		choices_box.add_child(_choice_button(ev.choices[i], i))
	if SurvivalState.chosen_choice < 0:
		hint_label.text = "ยังไม่ได้เลือก — ถ้าจบวันเลย จะเลือก \"%s\"" % ev.choices[ev.default_choice].label
	else:
		hint_label.text = ""


func get_choice_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in choices_box.get_children():
		if not child.is_queued_for_deletion():
			result.append(child)
	return result


func _choice_button(c: EventChoice, index: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override(&"font_size", 19)
	b.button_pressed = SurvivalState.chosen_choice == index
	b.text = c.label
	if c.required_item != &"":
		var item := ItemDatabase.get_item(c.required_item)
		b.icon = item.icon
		b.expand_icon = false
		b.add_theme_constant_override(&"icon_max_width", 40)
		var verb := "ใช้" if c.consumes_item else "ต้องมี"
		b.text += "   [%s%s]" % [verb, item.name_th]
	b.disabled = not SurvivalState.can_choose(index)
	if b.disabled and c.required_item != &"":
		b.tooltip_text = "ต้องมี %s ที่ใช้งานได้" % ItemDatabase.get_item(c.required_item).name_th
	b.pressed.connect(func() -> void: SurvivalState.choose(index))
	return b
