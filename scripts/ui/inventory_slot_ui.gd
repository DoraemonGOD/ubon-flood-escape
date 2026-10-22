class_name InventorySlotUI
extends Panel
## One square in the inventory bar. Shows an InventoryStack (or nothing).

signal hovered(slot: InventorySlotUI)
signal unhovered(slot: InventorySlotUI)

@export var normal_style: StyleBox
@export var hover_style: StyleBox

var stack: InventoryStack

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Count


func _ready() -> void:
	pivot_offset = size * 0.5
	add_theme_stylebox_override(&"panel", normal_style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_stack(null)


func set_stack(value: InventoryStack) -> void:
	stack = value
	icon.texture = stack.item.icon if stack else null
	count_label.text = str(stack.count) if stack else ""
	tooltip_text = "" # we draw our own tooltip panel


func flash() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.09).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16)


func _on_mouse_entered() -> void:
	add_theme_stylebox_override(&"panel", hover_style)
	hovered.emit(self)


func _on_mouse_exited() -> void:
	add_theme_stylebox_override(&"panel", normal_style)
	unhovered.emit(self)
