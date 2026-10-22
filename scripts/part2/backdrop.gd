class_name Backdrop
extends Node2D
## The scenery behind the boat, rebuilt from SurvivalState whenever it changes:
##   time of day  -> sky picture, light tint, lamps/windows on at dusk & night
##   weather      -> storm clouds, rain strength + slant, lightning flashes, fog
##   water level  -> buildings sink as the flood rises and come back as it falls
##   location     -> which place is shown (village / temple / market / field / highway)

const SKIES := {
	SurvivalState.TimeOfDay.DAWN: preload("res://assets/backgrounds/sky_dawn.svg"),
	SurvivalState.TimeOfDay.DAY: preload("res://assets/backgrounds/sky_day.svg"),
	SurvivalState.TimeOfDay.DUSK: preload("res://assets/backgrounds/sky_dusk.svg"),
	SurvivalState.TimeOfDay.NIGHT: preload("res://assets/backgrounds/night_sky.svg"),
}
const TINTS := {
	SurvivalState.TimeOfDay.DAWN: Color(0.86, 0.8, 0.82),
	SurvivalState.TimeOfDay.DAY: Color(0.95, 0.96, 1.0),
	SurvivalState.TimeOfDay.DUSK: Color(0.86, 0.68, 0.6),
	SurvivalState.TimeOfDay.NIGHT: Color(0.5, 0.55, 0.72),
}
## Pixels the buildings sink between normal water (0) and the peak (1).
@export var sink_pixels: float = 46.0

var _lightning_left := 0.0

@onready var sky: Sprite2D = $Sky
@onready var storm_clouds: Sprite2D = $StormClouds
@onready var far_lights: Node2D = $FarLights
@onready var locations_root: Node2D = $Locations
@onready var fog: Sprite2D = $Fog
@onready var lightning: Polygon2D = $Lightning


## The scene passes in the nodes that live outside this one.
func apply(tint: CanvasModulate, rain: CPUParticles2D, lamp_lights: Array[Node]) -> void:
	var t := SurvivalState.time_of_day
	var w := SurvivalState.weather
	sky.texture = SKIES[t]
	var dark := 1.0
	match w:
		SurvivalState.Weather.STORM:
			dark = 0.72
		SurvivalState.Weather.HEAVY_RAIN:
			dark = 0.85
		SurvivalState.Weather.LIGHT_RAIN:
			dark = 0.94
	var c: Color = TINTS[t]
	tint.color = Color(c.r * dark, c.g * dark, c.b * dark)
	storm_clouds.modulate.a = {SurvivalState.Weather.STORM: 1.0, SurvivalState.Weather.HEAVY_RAIN: 0.7, SurvivalState.Weather.LIGHT_RAIN: 0.35, SurvivalState.Weather.CLEAR: 0.0}[w]
	var rain_strength: float = {SurvivalState.Weather.STORM: 1.0, SurvivalState.Weather.HEAVY_RAIN: 0.8, SurvivalState.Weather.LIGHT_RAIN: 0.35, SurvivalState.Weather.CLEAR: 0.0}[w]
	rain.emitting = rain_strength > 0.0
	rain.modulate.a = clampf(rain_strength + 0.2, 0.0, 1.0)
	rain.direction = Vector2(-0.45 if w == SurvivalState.Weather.STORM else -0.2, 1.0)
	fog.modulate.a = 0.55 if t == SurvivalState.TimeOfDay.DAWN else (0.25 if w == SurvivalState.Weather.LIGHT_RAIN else 0.0)
	var lights_on := t == SurvivalState.TimeOfDay.NIGHT or t == SurvivalState.TimeOfDay.DUSK
	far_lights.visible = lights_on
	for light in lamp_lights:
		light.visible = lights_on
	for child in locations_root.get_children():
		child.visible = child.name.to_snake_case() == String(SurvivalState.location)
	locations_root.position.y = SurvivalState.get_water_level() * sink_pixels


func _process(delta: float) -> void:
	if SurvivalState.weather != SurvivalState.Weather.STORM:
		lightning.visible = false
		return
	_lightning_left -= delta
	if _lightning_left <= 0.0:
		_lightning_left = randf_range(3.0, 7.0)
		lightning.visible = true
		lightning.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(lightning, "modulate:a", 0.55, 0.05)
		tween.tween_property(lightning, "modulate:a", 0.1, 0.08)
		tween.tween_property(lightning, "modulate:a", 0.45, 0.05)
		tween.tween_property(lightning, "modulate:a", 0.0, 0.35)
