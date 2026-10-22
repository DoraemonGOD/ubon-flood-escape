class_name Journal
extends PanelContainer
## The survival journal: 5 tabs (บันทึก / แบ่งเสบียง / เหตุการณ์ / ออกสำรวจ / ล่องเรือ)
## and the "จบวัน" button. Pages read SurvivalState themselves.

signal end_day_pressed

const TAB_NAMES := ["บันทึก", "แบ่งเสบียง", "เหตุการณ์", "ออกสำรวจ", "ล่องเรือ"]

var page := 0

@onready var day_label: Label = %DayLabel
@onready var weather_label: Label = %WeatherLabel
@onready var tabs: Array[Button] = [%TabReport, %TabRation, %TabEvent, %TabExpedition, %TabVoyage]
@onready var pages: Array[Control] = [%ReportPage, %RationPage, %EventPage, %ExpeditionPage, %VoyagePage]
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var end_day_button: Button = %EndDayButton


func _ready() -> void:
	var group := ButtonGroup.new()
	for i in tabs.size():
		tabs[i].toggle_mode = true
		tabs[i].button_group = group
		tabs[i].pressed.connect(show_page.bind(i))
	prev_button.pressed.connect(func() -> void: show_page(page - 1))
	next_button.pressed.connect(func() -> void: show_page(page + 1))
	end_day_button.pressed.connect(end_day_pressed.emit)
	SurvivalState.state_changed.connect(refresh)
	refresh()
	show_page(0)


func show_page(index: int) -> void:
	page = clampi(index, 0, pages.size() - 1)
	for i in pages.size():
		pages[i].visible = i == page
		tabs[i].set_pressed_no_signal(i == page)
	prev_button.disabled = page == 0
	next_button.disabled = page == pages.size() - 1


func set_locked(locked: bool) -> void:
	end_day_button.disabled = locked or SurvivalState.is_finished()


func refresh() -> void:
	day_label.text = "วันที่ %d" % SurvivalState.day
	var here := SurvivalState.get_location()
	weather_label.text = "%s · อากาศ: %s" % [here.name_th if here else "", SurvivalState.get_weather_th()]
	# a dot on tabs that still want attention
	var needs_choice := SurvivalState.current_event != null and SurvivalState.chosen_choice < 0
	tabs[2].text = TAB_NAMES[2] + (" •" if needs_choice else "")
	var anyone_thirsty := false
	for s in SurvivalState.get_present():
		if not SurvivalState.status_icons(s).is_empty():
			anyone_thirsty = true
	tabs[1].text = TAB_NAMES[1] + (" •" if anyone_thirsty and SurvivalState.rations.is_empty() else "")
	tabs[4].text = TAB_NAMES[4] + (" •" if SurvivalState.can_voyage() and SurvivalState.voyage_destination == &"" else "")
	end_day_button.text = "ออกเรือ ▸" if SurvivalState.voyage_destination != &"" else "จบวัน ▸"
	end_day_button.disabled = SurvivalState.is_finished()
