extends Control
## End-of-phase summary of what reached the boat. Reads the Inventory autoload
## (the boat hold) and BoatCargo; neither is cleared here, so Part 2 can continue.

const SLOT_STYLE := preload("res://assets/ui/slot_style.tres")

@onready var stats_label: Label = %StatsLabel
@onready var grid: GridContainer = %Grid
@onready var empty_label: Label = %EmptyLabel
@onready var missing_label: Label = %MissingLabel
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	get_tree().paused = false
	restart_button.pressed.connect(GameState.start_new_game)
	menu_button.pressed.connect(GameState.go_to_main_menu)
	continue_button.pressed.connect(GameState.go_to_part_2)
	continue_button.disabled = not GameState.has_part_2()
	continue_button.tooltip_text = "" if GameState.has_part_2() else "Part 2 กำลังพัฒนา"
	_build()
	restart_button.grab_focus()


func _build() -> void:
	for child in grid.get_children():
		child.queue_free()
	# One card per item type, in database order, merging stacks of the same type.
	var collected_types := 0
	var missing: PackedStringArray = []
	for item in ItemDatabase.get_all_items():
		var count := Inventory.get_item_count(item.id)
		if count > 0:
			grid.add_child(_make_card(item, count))
			collected_types += 1
		else:
			missing.append(item.name_th)
	empty_label.visible = collected_types == 0
	stats_label.text = "ส่งขึ้นเรือ %d ชิ้น   ·   ใช้ไป %d/%d ช่อง   ·   %.1f กก.   ·   เวลาที่เหลือ %s" % [
		BoatCargo.total_delivered, Inventory.get_used_slot_count(), Inventory.max_slots,
		Inventory.get_total_weight(), GameState.format_time(GameState.last_time_left)]
	if missing.is_empty():
		missing_label.text = "ครบทุกอย่างที่จำเป็น! พร้อมรับมือกับน้ำท่วมแล้ว"
	else:
		missing_label.text = "ยังขาด: " + ", ".join(missing)
	# family: who made it onto the boat, who is still in the house
	var aboard: PackedStringArray = []
	var left: PackedStringArray = []
	for member in ItemDatabase.get_family():
		if Inventory.get_item_count(member.id) > 0:
			aboard.append(member.name_th)
		else:
			left.append(member.name_th)
	aboard.insert(0, "คุณ")
	var family_line := "ครอบครัวบนเรือ: " + ", ".join(aboard)
	if not left.is_empty():
		family_line += "   ·   ยังติดอยู่ในบ้าน: " + ", ".join(left)
	missing_label.text = family_line + "\n" + missing_label.text
	if GameState.last_undelivered > 0:
		missing_label.text += "
ตกค้างในมือ %d ชิ้น — ไม่ได้ขึ้นเรือ" % GameState.last_undelivered


func _make_card(item: ItemData, count: int) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(130, 0)
	card.add_theme_constant_override(&"separation", 4)

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(84, 84)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override(&"panel", SLOT_STYLE)
	card.add_child(frame)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	frame.add_child(icon)

	var count_label := Label.new()
	count_label.text = "×%d" % count
	count_label.add_theme_font_size_override(&"font_size", 20)
	count_label.add_theme_constant_override(&"outline_size", 6)
	count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.add_child(count_label)

	var name_label := Label.new()
	name_label.theme_type_variation = &"PaperLabel"
	name_label.text = item.name_th
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 18)
	card.add_child(name_label)
	return card
