class_name EventChoice
extends Resource
## One answer to an EventData. May need an item (shown with its icon; greyed out
## when you don't have it). Devices (flashlight, radio) need power instead of
## being used up — see SurvivalState.can_use_item().

@export var label: String
## "" = anyone can pick this.
@export var required_item: StringName = &""
## Use up one of the required item (medicine, water...). Devices only use 1 charge.
@export var consumes_item: bool = false
## Only if this person is on the boat and healthy (e.g. "grandpa" knows herbs).
@export var required_survivor: StringName = &""
## Only if this story flag is set (e.g. "knows_signal").
@export var required_flag: String = ""
@export var outcomes: Array[ChoiceOutcome] = []
