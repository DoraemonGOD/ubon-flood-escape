extends Node2D
## Intro cutscene (plays when "เริ่มเกม" is pressed): the family watches TV, a news
## flash says the city will flood tonight and every road is cut, the power dies,
## water comes in — then Part 1 starts.
## Click / Space / Enter = next line now. Esc or the "ข้าม" button = skip everything.
## Every line of dialogue is in the LINES-style calls inside _run() — edit the text there.

signal finished

## Tests turn this off so the cutscene does not change the scene when it ends.
@export var auto_continue: bool = true
## Seconds per character for a line's on-screen time (plus a minimum).
@export var seconds_per_char: float = 0.055
@export var min_line_time: float = 2.4

const SPEAKER_COLORS := {
	"": Color("cfc6ad"), "ผู้ประกาศข่าว": Color("9fc4ff"), "แม่": Color("dcb65a"),
	"น้องฝน": Color("e7a3b8"), "ตาบุญ": Color("c9b98f"), "คุณ": Color("efe2bf"),
}

var _skipped := false
var _done := false
var _advance := false
var _time := 0.0
var _tv_on := true
var lines_shown: int = 0

@onready var room: Node2D = $Room
@onready var tv_shot: Node2D = $TvShot
@onready var room_tint: CanvasModulate = $RoomTint
@onready var tv_light: PointLight2D = $Room/Inner/TvLight
@onready var family: Node2D = $Room/Inner/Family
@onready var flood: Polygon2D = $Room/Inner/FloodWater
@onready var lightning: ColorRect = %Lightning
@onready var news_flood: Sprite2D = $TvShot/NewsFlood
@onready var ticker: Label = $TvShot/Ticker/Bar/Text
@onready var tv_static: Sprite2D = $TvShot/Static
@onready var subtitle: PanelContainer = %Subtitle
@onready var speaker_label: Label = %Speaker
@onready var line_label: Label = %Line
@onready var skip_button: Button = %SkipButton
@onready var title_card: Control = %TitleCard
@onready var fade: ColorRect = %Fade
@onready var jingle: AudioStreamPlayer = $Sfx/Jingle
@onready var thunder: AudioStreamPlayer = $Sfx/Thunder


func _ready() -> void:
	get_tree().paused = false
	skip_button.pressed.connect(skip)
	if Platform.is_mobile():
		$UI/Hint.text = "แตะจอ = บรรทัดถัดไป   ·   ปุ่ม ข้าม = ข้ามทั้งหมด"
	tv_shot.hide()
	title_card.hide()
	subtitle.hide()
	lightning.hide()
	_run()


func _process(delta: float) -> void:
	_time += delta
	if _tv_on:
		# the TV's restless blue light on the family's faces
		tv_light.energy = 1.25 + sin(_time * 9.0) * 0.12 + sin(_time * 23.0) * 0.08
	if tv_shot.visible:
		ticker.position.x -= 140.0 * delta
		if ticker.position.x < -ticker.size.x:
			ticker.position.x = ticker.get_parent().size.x


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled() # before skip(): skipping leaves the scene tree
		skip()
	elif event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE):
		_advance = true
		get_viewport().set_input_as_handled()


## Skips straight to the game.
func skip() -> void:
	_skipped = true
	_finish()


func is_done() -> bool:
	return _done


# ------------------------------------------------------------------- the story
func _run() -> void:
	await _fade_to(0.0, 1.0)
	_slow_push(room, 1.06, 9.0)
	await _say("", "อุบลราชธานี — ฝนตกหนักไม่หยุดมาสามวันสามคืนแล้ว")
	await _say("น้องฝน", "แม่ ฝนจะหยุดเมื่อไหร่คะ")
	await _say("แม่", "อีกเดี๋ยวก็หยุดลูก ดูทีวีไปก่อนนะ")
	await _say("ตาบุญ", "ตาอยู่มาเจ็ดสิบปี ไม่เคยเห็นฝนตกนานขนาดนี้เลย")
	if _skipped:
		return
	jingle.play()
	await _say("", "ตึ๊ง ตึ๊ง... \"ขออภัยที่ขัดจังหวะรายการ — ข่าวด่วน\"")
	_cut_to_tv()
	await _say("ผู้ประกาศข่าว", "ขณะนี้เขื่อนตอนบนเร่งระบายน้ำ ระดับแม่น้ำมูลและแม่น้ำชีเพิ่มสูงขึ้นอย่างรวดเร็ว")
	await _say("ผู้ประกาศข่าว", "คาดว่าน้ำจะท่วมฉับพลันในตัวเมืองอุบลราชธานีภายในคืนนี้")
	await _say("ผู้ประกาศข่าว", "ถนนทุกสายเข้าออกจังหวัดถูกน้ำตัดขาด เจ้าหน้าที่ยังไม่สามารถเข้าถึงพื้นที่ได้")
	await _say("ผู้ประกาศข่าว", "ขอให้ประชาชนเตรียมพร้อม และช่วยเหลือตัวเองไปก่อน จนกว่า—")
	if _skipped:
		return
	await _power_cut()
	await _say("น้องฝน", "แม่! น้ำเข้าบ้านแล้ว!")
	await _say("คุณ", "ทุกคนตั้งสติไว้! ผมจะเอาเรือมาจอดที่ระเบียง")
	await _say("แม่", "เอาของที่จำเป็นใส่เรือให้เร็วที่สุด แล้วอย่าลืมพาทุกคนไปด้วยนะลูก")
	if _skipped:
		return
	subtitle.hide()
	title_card.show()
	title_card.modulate.a = 0.0
	await _tween_prop(title_card, "modulate:a", 1.0, 0.8)
	await _wait(3.2)
	_finish()


func _say(speaker: String, text: String) -> void:
	if _skipped:
		return
	subtitle.show()
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	speaker_label.add_theme_color_override(&"font_color", SPEAKER_COLORS.get(speaker, Color.WHITE))
	line_label.text = text
	line_label.visible_ratio = 0.0
	lines_shown += 1
	var duration := maxf(min_line_time, text.length() * seconds_per_char)
	var typing := create_tween()
	typing.tween_property(line_label, "visible_ratio", 1.0, minf(duration * 0.45, 1.6))
	_advance = false
	await _wait(duration)
	typing.kill()
	line_label.visible_ratio = 1.0


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skipped and not _advance:
		await get_tree().process_frame
		t += get_process_delta_time()
	_advance = false


func _cut_to_tv() -> void:
	if _skipped:
		return
	room.hide()
	tv_shot.show()
	room_tint.color = Color.WHITE # the night tint is for the room only
	news_flood.scale = Vector2(0.25, 0.25)
	news_flood.modulate.a = 0.4
	var t := create_tween().set_parallel()
	t.tween_property(news_flood, "scale", Vector2(0.95, 0.95), 14.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(news_flood, "modulate:a", 0.85, 6.0)


func _power_cut() -> void:
	# picture breaks into static, then everything goes dark; lightning; water comes in
	var t := create_tween()
	t.tween_property(tv_static, "modulate:a", 0.9, 0.25)
	await _wait(0.6)
	tv_shot.hide()
	room.show()
	room.scale = Vector2.ONE
	_tv_on = false
	tv_light.energy = 0.0
	room_tint.color = Color(0.16, 0.18, 0.26)
	thunder.play()
	await _flash()
	for person in family.get_children():
		(person as AnimatedSprite2D).play(&"look")
	var rise := create_tween()
	rise.tween_property(flood, "position:y", -70.0, 6.0).set_trans(Tween.TRANS_SINE)


func _flash() -> void:
	lightning.show()
	lightning.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(lightning, "modulate:a", 0.8, 0.05)
	t.tween_property(lightning, "modulate:a", 0.15, 0.1)
	t.tween_property(lightning, "modulate:a", 0.6, 0.05)
	t.tween_property(lightning, "modulate:a", 0.0, 0.5)
	await t.finished
	lightning.hide()


func _slow_push(node: Node2D, to_scale: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * to_scale, seconds).set_trans(Tween.TRANS_SINE)


func _fade_to(alpha: float, seconds: float) -> void:
	fade.show()
	await _tween_prop(fade, "modulate:a", alpha, seconds)
	if alpha <= 0.0:
		fade.hide()


func _tween_prop(obj: Object, prop: String, value: Variant, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(obj, prop, value, seconds)
	await t.finished


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if auto_continue:
		GameState.begin_scavenging()
