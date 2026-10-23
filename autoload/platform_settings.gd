extends Node
## Which controls the player uses: keyboard (PC) or on-screen touch controls (MOBILE).
## Chosen in the main menu on first launch and saved in user://settings.cfg.
## Also shows a "turn your phone sideways" overlay when a phone is held upright.

signal changed(mode: StringName)

const PC := &"pc"
const MOBILE := &"mobile"
const SETTINGS_PATH := "user://settings.cfg"

var mode: StringName = PC
## False until the player has picked once (the main menu then asks).
var chosen: bool = false
## Tests turn this off so they never overwrite the player's settings file.
var save_enabled: bool = true

var _rotate_hint: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key("platform", "mode"):
		mode = StringName(cfg.get_value("platform", "mode"))
		chosen = mode == PC or mode == MOBILE
	if not chosen:
		mode = suggested()
	_build_rotate_hint()
	get_tree().root.size_changed.connect(_update_rotate_hint)
	_update_rotate_hint()


## Best guess for this device: phones and tablets get touch controls.
func suggested() -> StringName:
	var phone := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return MOBILE if phone and DisplayServer.is_touchscreen_available() else PC


func is_mobile() -> bool:
	return mode == MOBILE


func set_mode(new_mode: StringName, save: bool = true) -> void:
	mode = new_mode
	chosen = true
	if save and save_enabled:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("platform", "mode", String(mode))
		cfg.save(SETTINGS_PATH)
	_update_rotate_hint()
	changed.emit(mode)


func _build_rotate_hint() -> void:
	_rotate_hint = CanvasLayer.new()
	_rotate_hint.layer = 120
	_rotate_hint.visible = false
	add_child(_rotate_hint)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 24)
	bg.add_child(box)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/ui/icon_rotate.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 420)
	box.add_child(icon)
	var label := Label.new()
	label.text = "หมุนโทรศัพท์เป็นแนวนอนเพื่อเล่น"
	label.theme_type_variation = &"TitleLabel"
	label.add_theme_font_size_override(&"font_size", 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


func _update_rotate_hint() -> void:
	if _rotate_hint == null:
		return
	var size := get_tree().root.get_visible_rect().size
	_rotate_hint.visible = is_mobile() and size.y > size.x
