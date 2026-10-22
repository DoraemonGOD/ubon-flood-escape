class_name StatusBar
extends PanelContainer
## Top bar: title + DAY | SURVIVORS | WEATHER (all from SurvivalState).

@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var info_label: Label = %Info


func _ready() -> void:
	SurvivalState.state_changed.connect(refresh)
	refresh()


func set_titles(title: String, subtitle: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle


func refresh() -> void:
	var text := "DAY %d   |   SURVIVORS: %d/%d   |   WEATHER: %s" % [SurvivalState.day, SurvivalState.get_survivor_count(), SurvivalState.survivors.size(), SurvivalState.get_weather_name()]
	if SurvivalState.shelter_nights > 0:
		text += "   |   SHELTER"
	info_label.text = text
