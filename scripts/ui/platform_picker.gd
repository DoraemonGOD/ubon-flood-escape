class_name PlatformPicker
extends Control
## Full-screen "เล่นบนอุปกรณ์ไหน?" chooser shown by the main menu: computer (keyboard)
## or phone/tablet (touch controls). Emits picked(mode); the menu saves it.

signal picked(mode: StringName)
signal cancelled

## Show a "ยกเลิก" button (when changing an earlier choice).
var can_cancel: bool = false

var pc_button: Button
var mobile_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.06, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PaperPanel"
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"PaperTitle"
	title.text = "เล่นบนอุปกรณ์ไหน?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := Label.new()
	note.theme_type_variation = &"PaperLabel"
	note.text = "เลือกเพื่อให้ปุ่มควบคุมเหมาะกับเครื่อง — เปลี่ยนทีหลังได้ที่ปุ่มมุมซ้ายล่างของเมนู"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 28)
	box.add_child(row)
	var suggested := Platform.suggested()
	pc_button = _choice(row, preload("res://assets/ui/icon_pc.svg"), "คอมพิวเตอร์", "คีย์บอร์ด: WASD · E · Q", Platform.PC, suggested)
	mobile_button = _choice(row, preload("res://assets/ui/icon_phone.svg"), "มือถือ / แท็บเล็ต", "จอยสติ๊กและปุ่มบนจอ", Platform.MOBILE, suggested)

	if can_cancel:
		var cancel := Button.new()
		cancel.text = "ยกเลิก"
		cancel.custom_minimum_size = Vector2(200, 0)
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cancel.pressed.connect(func() -> void: cancelled.emit())
		box.add_child(cancel)
	var current := Platform.mode if Platform.chosen else suggested
	(mobile_button if current == Platform.MOBILE else pc_button).grab_focus()


func _choice(parent: Control, icon: Texture2D, title: String, detail: String, mode: StringName, suggested: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 250)
	b.icon = icon
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override(&"font_size", 24)
	var tag := ""
	if Platform.chosen and Platform.mode == mode:
		tag = "\n(ใช้อยู่ตอนนี้)"
	elif not Platform.chosen and mode == suggested:
		tag = "\n(แนะนำสำหรับเครื่องนี้)"
	b.text = "%s\n%s%s" % [title, detail, tag]
	b.pressed.connect(func() -> void: picked.emit(mode))
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if can_cancel and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
