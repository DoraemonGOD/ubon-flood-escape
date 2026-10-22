extends ScrollContainer
## Journal tab 2 "แบ่งเสบียง": tick who gets water / food / medicine tonight.
## Nothing is used until the day ends; the counts show what will be left.

const KINDS := [["water", &"water", "น้ำ"], ["food", &"canned_food", "อาหาร"], ["medicine", &"medicine", "ยา"]]
const WARN := Color(0.62, 0.2, 0.12)
const OK_COLOR := Color(0.3, 0.38, 0.2)

@onready var stock_label: Label = %StockLabel
@onready var rows: VBoxContainer = %RationRows


func _ready() -> void:
	SurvivalState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	stock_label.text = "เหลือหลังแบ่งคืนนี้:  น้ำ %d  ·  อาหาร %d  ·  ยา %d" % [
		SurvivalState.available(&"water"), SurvivalState.available(&"canned_food"), SurvivalState.available(&"medicine")]
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for s in SurvivalState.survivors:
		rows.add_child(_make_row(s))


func get_toggle(survivor: SurvivorData, kind: String) -> Button:
	for row in rows.get_children():
		if row.get_meta("survivor_id") == survivor.id:
			return row.find_child(kind, true, false) as Button
	return null


func _make_row(s: SurvivorData) -> Control:
	var row := HBoxContainer.new()
	row.set_meta("survivor_id", s.id)
	row.add_theme_constant_override(&"separation", 10)
	row.add_child(_portrait(s))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	var name_label := Label.new()
	name_label.theme_type_variation = &"PaperLabel"
	name_label.text = s.display_name
	name_label.add_theme_font_size_override(&"font_size", 21)
	info.add_child(name_label)
	var status := Label.new()
	status.theme_type_variation = &"PaperLabel"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override(&"font_size", 15)
	var words := SurvivalState.describe_status(s)
	status.text = ", ".join(words) if not words.is_empty() else "ยังพอไหว"
	status.add_theme_color_override(&"font_color", WARN if not words.is_empty() else OK_COLOR)
	info.add_child(status)
	row.add_child(info)
	if s.is_present():
		for k in KINDS:
			if k[0] == "medicine" and not s.needs_medicine():
				continue
			row.add_child(_toggle(s, k[0], k[1], k[2]))
	else:
		row.modulate.a = 0.5
	return row


func _toggle(s: SurvivorData, kind: String, item_id: StringName, text: String) -> Button:
	var b := Button.new()
	b.name = kind
	b.toggle_mode = true
	b.button_pressed = SurvivalState.get_ration(s, kind)
	b.icon = ItemDatabase.get_item(item_id).icon
	b.expand_icon = true
	b.text = text
	b.custom_minimum_size = Vector2(92, 52)
	b.add_theme_font_size_override(&"font_size", 16)
	b.disabled = not b.button_pressed and SurvivalState.available(item_id) <= 0
	b.tooltip_text = "ให้%sคืนนี้" % text
	b.toggled.connect(func(on: bool) -> void: SurvivalState.set_ration(s, kind, on))
	return b


func _portrait(s: SurvivorData) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = s.sprite_frames.get_frame_texture(&"idle", 0)
	atlas.region = Rect2(18, 20, 60, 56)
	var t := TextureRect.new()
	t.texture = atlas
	t.custom_minimum_size = Vector2(56, 52)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not s.is_alive():
		t.modulate = Color(0.4, 0.4, 0.4)
	return t
