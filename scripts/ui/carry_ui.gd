class_name CarryUI
extends PanelContainer
## "CARRY x/3" with the icons of what is in the player's hands, plus how many
## items are already on the boat. Items flying to the boat are shown faded.

const SLOT_STYLE := preload("res://assets/ui/slot_style.tres")
const FULL_COLOR := Color("e2583e")
const NORMAL_COLOR := Color("dcb65a")

var _carry: CarryInventory
var _slots: Array[Panel] = []

@onready var carry_label: Label = %CarryLabel
@onready var slots_box: HBoxContainer = %CarrySlots
@onready var delivered_label: Label = %DeliveredLabel


func _ready() -> void:
	for i in CarryInventory.MAX_CARRY_ITEMS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override(&"panel", SLOT_STYLE)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		slot.add_child(icon)
		slots_box.add_child(slot)
		_slots.append(slot)
	BoatCargo.boat_cargo_changed.connect(_refresh_delivered)
	_refresh_delivered()
	refresh()


func bind(carry: CarryInventory) -> void:
	_carry = carry
	carry.carry_inventory_changed.connect(refresh)
	carry.item_picked_up.connect(_on_item_picked_up)
	refresh()


func refresh() -> void:
	var entries: Array = _carry.get_items() if _carry else []
	var used := _carry.count() if _carry else 0
	carry_label.text = "CARRY %d/%d" % [used, CarryInventory.MAX_CARRY_ITEMS]
	carry_label.add_theme_color_override(&"font_color", FULL_COLOR if used >= CarryInventory.MAX_CARRY_ITEMS else NORMAL_COLOR)
	# one panel per hand-space unit; a family member (slot_size 2) fills two
	var panel_items: Array = []
	for entry in entries:
		for k in entry.item.slot_size:
			panel_items.append(entry)
	for i in _slots.size():
		var icon: TextureRect = _slots[i].get_node("Icon")
		if i < panel_items.size():
			icon.texture = panel_items[i].item.icon
			icon.modulate.a = 0.35 if panel_items[i].in_flight else 1.0
		else:
			icon.texture = null


func _refresh_delivered() -> void:
	delivered_label.text = "ส่งขึ้นเรือแล้ว %d ชิ้น" % BoatCargo.total_delivered


func _on_item_picked_up(_item: ItemData) -> void:
	var slot := _slots[clampi(_carry.count() - 1, 0, _slots.size() - 1)]
	slot.pivot_offset = slot.size * 0.5
	var tween := slot.create_tween()
	tween.tween_property(slot, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.14)
