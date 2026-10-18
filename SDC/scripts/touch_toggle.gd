extends "res://scripts/touch_button.gd"
## Toggle activation uses the same release and scroll cancellation as every tap.
func _init() -> void:
	toggle_mode=true

func _ready() -> void:
	super._ready()
