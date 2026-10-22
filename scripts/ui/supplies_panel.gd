class_name SuppliesPanel
extends PanelContainer
## "เสบียงบนเรือ": icon, name and count of every supply. Reads SurvivalState
## (which reads the Inventory); stores nothing itself.

@onready var summary_label: Label = %Summary
@onready var rows: GridContainer = %Rows
@onready var empty_label: Label = %EmptyLabel


func _ready() -> void:
	Inventory.inventory_changed.connect(refresh)
	SurvivalState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var entries := SurvivalState.get_supplies()
	for entry in entries:
		rows.add_child(_make_row(entry.item, entry.count))
	empty_label.visible = entries.is_empty()
	summary_label.text = "อาหาร %d  ·  น้ำ %d" % [SurvivalState.get_food(), SurvivalState.get_water()]


func get_row_count() -> int:
	return rows.get_child_count()


func _make_row(item: ItemData, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = item.name_th
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override(&"font_size", 15)
	row.add_child(name_label)
	var count_label := Label.new()
	count_label.text = "× %d" % count
	count_label.add_theme_font_size_override(&"font_size", 15)
	count_label.add_theme_color_override(&"font_color", Color("dcb65a"))
	row.add_child(count_label)
	return row
