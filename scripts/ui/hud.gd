class_name GameHUD
extends CanvasLayer
## In-game overlay: timer (top right), status + CarryUI (top left), boat cargo bar
## (bottom), the floating "E" prompt over the nearest item, the "Q" prompt at the
## boat, toast messages and the time-up banner.

@export var normal_time_color: Color = Color("efe2bf")
@export var warning_time_color: Color = Color("e2583e")

var _player: Player
var _timer: ScavengeTimer
var _prompt_target: ItemPickup
var _boat: Boat
var _message_tween: Tween
var _pulse_tween: Tween

@onready var time_label: Label = %TimeLabel
@onready var timer_panel: PanelContainer = %TimerPanel
@onready var weight_label: Label = %WeightLabel
@onready var prompt: PanelContainer = %Prompt
@onready var prompt_label: Label = %PromptLabel
@onready var boat_prompt: PanelContainer = %BoatPrompt
@onready var boat_prompt_label: Label = %BoatPromptLabel
@onready var boat_count_label: Label = %BoatCountLabel
@onready var message: PanelContainer = %Message
@onready var message_label: Label = %MessageLabel
@onready var time_up_banner: Label = %TimeUpBanner
@onready var look_countdown: Control = %LookCountdown
@onready var look_number: Label = %LookNumber
@onready var inventory_bar: InventoryBar = %InventoryBar
@onready var carry_ui: CarryUI = %CarryUI


func _ready() -> void:
	prompt.hide()
	boat_prompt.hide()
	message.hide()
	time_up_banner.hide()
	Inventory.inventory_changed.connect(_on_inventory_changed)
	Inventory.add_failed.connect(_on_add_failed)
	BoatCargo.item_delivered.connect(_on_item_delivered)
	BoatCargo.boat_cargo_changed.connect(_update_boat_prompt)
	_on_inventory_changed()


func bind(player: Player, timer: ScavengeTimer) -> void:
	_player = player
	_timer = timer
	player.nearest_pickup_changed.connect(_on_nearest_pickup_changed)
	player.boat_range_changed.connect(_on_boat_range_changed)
	player.feedback.connect(_on_player_feedback)
	player.carry.carry_inventory_changed.connect(_on_carry_changed)
	carry_ui.bind(player.carry)
	timer.timer_updated.connect(_on_timer_updated)
	timer.warning_started.connect(_on_warning_started)
	_on_timer_updated(timer.duration)


func show_message(text: String, color: Color = Color("efe2bf")) -> void:
	message_label.text = text
	message_label.add_theme_color_override(&"font_color", color)
	message.show()
	message.modulate.a = 1.0
	message.reset_size()
	message.position.x = (message.get_parent_area_size().x - message.size.x) * 0.5
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.4)
	_message_tween.tween_property(message, "modulate:a", 0.0, 0.4)
	_message_tween.tween_callback(message.hide)


## Phones: cargo bar moves to the top (thumbs cover the bottom corners), key caps are
## hidden (the on-screen buttons are labelled) and hints talk about buttons, not keys.
func apply_mobile_layout() -> void:
	inventory_bar.anchor_top = 0.0
	inventory_bar.anchor_bottom = 0.0
	inventory_bar.offset_top = 14.0
	inventory_bar.offset_bottom = 134.0
	# small, between the status panel (left) and the pause button + timer (right)
	inventory_bar.offset_left += 50.0
	inventory_bar.offset_right += 50.0
	inventory_bar.pivot_offset = Vector2(inventory_bar.size.x * 0.5, 0.0)
	inventory_bar.scale = Vector2(0.5, 0.5)
	$Root/Prompt/HBox/KeyCap.hide()
	$Root/BoatPrompt/HBox/KeyCap.hide()
	$Root/LookCountdown/LookHint.text = "เวลา 60 วินาทีจะเริ่มเมื่อนับถึง 0  ·  แตะปุ่ม หยิบ เพื่อเริ่มทันที"


## Pre-round "look around" countdown: n > 0 shows the number, 0 shows "เริ่ม!" then hides.
func show_look_countdown(n: int) -> void:
	look_countdown.show()
	look_countdown.modulate.a = 1.0
	inventory_bar.visible = n <= 0 # the countdown sits where the cargo bar is
	look_number.text = str(n) if n > 0 else "เริ่ม!"
	look_number.pivot_offset = look_number.size * 0.5
	look_number.scale = Vector2(1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(look_number, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if n <= 0:
		tween.tween_interval(0.5)
		tween.tween_property(look_countdown, "modulate:a", 0.0, 0.3)
		tween.tween_callback(look_countdown.hide)


func is_look_countdown_visible() -> bool:
	return look_countdown.visible


func show_time_up() -> void:
	prompt.hide()
	boat_prompt.hide()
	_prompt_target = null
	_boat = null
	time_up_banner.show()
	time_up_banner.pivot_offset = time_up_banner.size * 0.5
	time_up_banner.scale = Vector2(2.2, 2.2)
	time_up_banner.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(time_up_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(time_up_banner, "modulate:a", 1.0, 0.2)


func _process(_delta: float) -> void:
	if _prompt_target != null and is_instance_valid(_prompt_target):
		_place_over(prompt, _prompt_target.get_prompt_anchor())
	if _boat != null and is_instance_valid(_boat):
		_place_over(boat_prompt, _boat.get_prompt_anchor())


func _place_over(panel: Control, world_pos: Vector2) -> void:
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	var view := panel.get_viewport_rect().size
	var pos := screen_pos - Vector2(panel.size.x * 0.5, panel.size.y)
	pos.x = clampf(pos.x, 8.0, view.x - panel.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, view.y - panel.size.y - 8.0)
	panel.position = pos


func _on_nearest_pickup_changed(pickup: ItemPickup) -> void:
	_prompt_target = pickup
	_update_prompt()


func _on_boat_range_changed(boat: Boat) -> void:
	_boat = boat
	_update_boat_prompt()


func _on_carry_changed() -> void:
	_update_prompt()
	_update_boat_prompt()


func _update_prompt() -> void:
	if _prompt_target == null or not is_instance_valid(_prompt_target) or _prompt_target.item == null:
		prompt.hide()
		return
	var item := _prompt_target.item
	var amount := _prompt_target.quantity
	var name_text := item.name_th + (" ×%d" % amount if amount > 1 else "")
	var verb := "พา%sไปด้วย (%d ช่อง)" % [item.name_th, item.slot_size] if item.is_person() else "หยิบ " + name_text
	if _player and not _player.carry.can_add(item):
		prompt_label.text = "%s  (มือไม่ว่าง %d/%d)" % [verb if item.is_person() else name_text, _player.carry.count(), CarryInventory.MAX_CARRY_ITEMS]
		prompt_label.add_theme_color_override(&"font_color", warning_time_color)
	else:
		prompt_label.text = verb
		prompt_label.add_theme_color_override(&"font_color", normal_time_color)
	prompt.show()
	prompt.reset_size()
	_place_over(prompt, _prompt_target.get_prompt_anchor())


func _update_boat_prompt() -> void:
	if _boat == null or not is_instance_valid(_boat) or _player == null:
		boat_prompt.hide()
		return
	var held := _player.carry.get_held_item_data().size()
	if held > 0:
		boat_prompt_label.text = "— โยนของขึ้นเรือ (ถืออยู่ %d)" % held
		boat_prompt_label.add_theme_color_override(&"font_color", normal_time_color)
	else:
		boat_prompt_label.text = "— ไม่มีของที่ต้องโยน"
		boat_prompt_label.add_theme_color_override(&"font_color", Color(normal_time_color, 0.6))
	boat_count_label.text = "บนเรือแล้ว %d ชิ้น" % BoatCargo.total_delivered
	boat_prompt.show()
	boat_prompt.reset_size()
	_place_over(boat_prompt, _boat.get_prompt_anchor())


func _on_timer_updated(time_left: float) -> void:
	time_label.text = GameState.format_time(time_left)


func _on_warning_started() -> void:
	time_label.add_theme_color_override(&"font_color", warning_time_color)
	show_message("น้ำกำลังมา! เหลือเวลาไม่ถึง %d วินาที" % ceili(_timer.warning_threshold), warning_time_color)
	timer_panel.pivot_offset = timer_panel.size * 0.5
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(timer_panel, "scale", Vector2(1.08, 1.08), 0.25)
	_pulse_tween.tween_property(timer_panel, "scale", Vector2.ONE, 0.25)
	_pulse_tween.tween_interval(0.5)


func _on_inventory_changed() -> void:
	var limit := ("/%.0f" % Inventory.max_weight) if Inventory.max_weight > 0.0 else ""
	weight_label.text = "บนเรือ %.1f%s กก.   ของ %d ชิ้น" % [Inventory.get_total_weight(), limit, Inventory.get_total_item_count()]


func _on_item_delivered(item: ItemData, total: int) -> void:
	if item.is_person():
		show_message("%sขึ้นเรือแล้ว ปลอดภัย!" % item.name_th, Color("9fd08a"))
	else:
		show_message("ส่งของขึ้นเรือแล้ว: %s  (รวม %d ชิ้น)" % [item.name_th, total])


func _on_player_feedback(text: String, is_warning: bool) -> void:
	show_message(text, warning_time_color if is_warning else normal_time_color)


func _on_add_failed(item: ItemData, reason: StringName) -> void:
	if reason == &"too_heavy":
		show_message("เรือรับน้ำหนักไม่ไหวแล้ว! (%s)" % item.name_th, warning_time_color)
	else:
		show_message("เรือเต็มแล้ว! (%d/%d ช่อง)" % [Inventory.get_used_slot_count(), Inventory.max_slots], warning_time_color)
