# SettingsManager.gd (AutoLoad)
extends Node

# The 4 toggles
var sound_enabled: bool = true
var hit_flash_enabled: bool = true
var blood_enabled: bool = true
var screen_shake_enabled: bool = true

# Optional: Function to toggle them (connect this to UI buttons)
func toggle_sound() -> void:
	sound_enabled = !sound_enabled
	# You could save this setting with ConfigFile here if you want it to persist
