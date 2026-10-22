extends ScrollContainer
## Journal tab 4 "ออกสำรวจ": send one person out for a few days to search nearby
## houses. A flashlight finds more, rope keeps them safer — but that gear is not
## on the boat while they are gone.

@onready var info_label: Label = %ExpeditionInfo
@onready var members_box: VBoxContainer = %Members
@onready var gear_box: VBoxContainer = %Gear
@onready var odds_label: Label = %Odds


func _ready() -> void:
	SurvivalState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for box in [members_box, gear_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	odds_label.text = ""
	var ex := SurvivalState.expedition
	if not ex.is_empty():
		info_label.text = "%s ออกไปสำรวจอยู่ จะกลับมาในวันที่ %d" % [ex.member.display_name, ex.return_day]
		return
	info_label.text = "ส่งใครสักคนเกาะห่วงยางออกไปหาเสบียงจากบ้านละแวกนี้ (ไป %d วัน)\nอาจได้ของกลับมา — หรืออาจบาดเจ็บ หรือไม่กลับมาอีกเลย" % SurvivalState.rules.expedition_days
	var plan := SurvivalState.expedition_plan
	var planned: SurvivorData = plan.get("member")
	var group := ButtonGroup.new()
	members_box.add_child(_member_button("ไม่ส่งใครไป", null, planned == null, group))
	for s in SurvivalState.survivors:
		if s.is_alive():
			members_box.add_child(_member_button(s.display_name, s, planned == s, group))
	if planned == null:
		return
	var gear: Array = plan.get("gear", [])
	for g in SurvivalState.EXPEDITION_GEAR:
		if SurvivalState.get_supply_count(g) <= 0:
			continue
		var item := ItemDatabase.get_item(g)
		var cb := CheckBox.new()
		cb.text = "พก%s %s" % [item.name_th, "(หาของได้มากขึ้น)" if g == &"flashlight" else "(ปลอดภัยขึ้น ไม่หลงหาย)"]
		cb.icon = item.icon
		cb.expand_icon = false
		cb.add_theme_constant_override(&"icon_max_width", 32)
		cb.add_theme_font_size_override(&"font_size", 17)
		cb.button_pressed = gear.has(g)
		cb.toggled.connect(_on_gear_toggled.bind(g))
		gear_box.add_child(cb)
	odds_label.text = "พกของไปด้วย = ของชิ้นนั้นจะไม่อยู่บนเรือจนกว่าเขาจะกลับมา"


func _member_button(text: String, s: SurvivorData, pressed: bool, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override(&"font_size", 18)
	b.text = text
	if s != null and not SurvivalState.can_send_on_expedition(s):
		b.disabled = true
		var why := ", ".join(SurvivalState.describe_status(s))
		b.text += "  — ยังไปไม่ได้" + (" (%s)" % why if why != "" else "")
	b.pressed.connect(func() -> void: SurvivalState.plan_expedition(s, [] as Array[StringName]))
	return b


func _on_gear_toggled(on: bool, g: StringName) -> void:
	var plan := SurvivalState.expedition_plan
	if plan.is_empty():
		return
	var gear: Array[StringName] = []
	gear.assign(plan.gear)
	if on and not gear.has(g):
		gear.append(g)
	elif not on:
		gear.erase(g)
	SurvivalState.plan_expedition(plan.member, gear)
