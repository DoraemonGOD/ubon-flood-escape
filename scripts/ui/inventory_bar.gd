class_name InventoryBar
extends PanelContainer
## Bottom bar: the boat hold (Inventory autoload). One InventorySlotUI per slot, the "ของบนเรือ (x/y)" header
## and a description tooltip when the mouse points at a slot.

const SLOT_SCENE := preload("res://scenes/ui/inventory_slot.tscn")
const FULL_COLOR := Color("e2583e")

var _slots: Array[InventorySlotUI] = []
var _hovered: InventorySlotUI

@onready var slots_box: HBoxContainer = %Slots
@onready var slots_label: Label = %SlotsLabel
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_en: Label = %TooltipEn
@onready var tooltip_desc: Label = %TooltipDesc
@onready var tooltip_stats: Label = %TooltipStats


func _ready() -> void:
	tooltip.hide()
	Inventory.inventory_changed.connect(refresh)
	Inventory.item_collected.connect(_on_item_collected)
	refresh()


func refresh() -> void:
	while _slots.size() < Inventory.max_slots:
		var slot: InventorySlotUI = SLOT_SCENE.instantiate()
		slots_box.add_child(slot)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		_slots.append(slot)
	while _slots.size() > Inventory.max_slots:
		_slots.pop_back().queue_free()
	var shown: Array = [] # one entry per slot: [stack, is_extra_part]
	for stack in Inventory.get_slots():
		for k in stack.item.slot_size:
			shown.append([stack, k > 0])
	for i in _slots.size():
		_slots[i].set_stack(shown[i][0] if i < shown.size() else null)
		_slots[i].modulate.a = 0.55 if i < shown.size() and shown[i][1] else 1.0
	slots_label.text = "ของบนเรือ (%d/%d ช่อง)" % [Inventory.get_used_slot_count(), Inventory.max_slots]
	slots_label.add_theme_color_override(&"font_color", FULL_COLOR if Inventory.is_full() else Color("efe2bf"))
	if _hovered:
		_on_slot_hovered(_hovered)


func get_slot_nodes() -> Array[InventorySlotUI]:
	return _slots


func _on_item_collected(item: ItemData, _amount: int) -> void:
	for slot in _slots:
		if slot.stack and slot.stack.item.id == item.id:
			slot.flash()


func _on_slot_hovered(slot: InventorySlotUI) -> void:
	_hovered = slot
	if slot.stack == null:
		tooltip.hide()
		return
	var item := slot.stack.item
	tooltip_name.text = item.name_th
	tooltip_en.text = item.name_en
	tooltip_desc.text = item.description
	tooltip_stats.text = "จำนวน %d (ช่องละไม่เกิน %d)   น้ำหนัก %.1f กก." % [slot.stack.count, item.max_stack, slot.stack.get_weight()]
	tooltip.show()
	tooltip.reset_size()
	var pos := slot.global_position + Vector2(slot.size.x * 0.5 - tooltip.size.x * 0.5, -tooltip.size.y - 12.0)
	var screen := get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, screen.x - tooltip.size.x - 8.0)
	tooltip.global_position = pos


func _on_slot_unhovered(slot: InventorySlotUI) -> void:
	if _hovered == slot:
		_hovered = null
		tooltip.hide()
