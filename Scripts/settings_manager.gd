extends Control

var sound_enabled: bool = true
var hit_flash_enabled: bool = true
var blood_enabled: bool = true
var screen_shake_enabled: bool = true
var parallax_enabled: bool = true
var delay_bar_enabled: bool = true

signal delay_bar_toggled(enabled: bool)

@onready var panel: PanelContainer = $Panel
@onready var settings_button: Button = $SettingsButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/TitleRow/CloseButton
@onready var sound_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/SoundRow/SoundToggle
@onready var hit_flash_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/HitFlashRow/HitFlashToggle
@onready var blood_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/BloodRow/BloodToggle
@onready var screen_shake_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ScreenShakeRow/ScreenShakeToggle
@onready var parallax_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ParallaxRow/ParallaxToggle
@onready var delay_bar_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/DelayBarRow/DelayBarToggle
@onready var parallax_bg: ParallaxBackground = get_tree().current_scene.get_node("ParallaxBackground")

var _parallax_layer_scales: Array[Vector2] = []


func _ready() -> void:
	# Save original motion_scale for each ParallaxLayer so we can restore them
	for layer in parallax_bg.get_children():
		if layer is ParallaxLayer:
			_parallax_layer_scales.append(layer.motion_scale)
	settings_button.pressed.connect(_on_settings_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	sound_toggle.toggled.connect(func(on): 
		sound_enabled = on
		_apply_sound()
	)
	hit_flash_toggle.toggled.connect(func(on): hit_flash_enabled = on)
	blood_toggle.toggled.connect(func(on): blood_enabled = on)
	screen_shake_enabled = screen_shake_toggle.button_pressed
	screen_shake_toggle.toggled.connect(func(on): screen_shake_enabled = on)
	parallax_toggle.toggled.connect(_on_parallax_toggled)
	delay_bar_toggle.toggled.connect(func(on):
		delay_bar_enabled = on
		delay_bar_toggled.emit(on)
	)
	_apply_sound()


func _on_settings_button_pressed() -> void:
	panel.visible = not panel.visible
	settings_button.visible = not settings_button.visible
	get_tree().paused = panel.visible


func _on_close_button_pressed() -> void:
	panel.visible = false
	settings_button.visible = true
	get_tree().paused = false


# Programmatic toggles (for other scripts to call)
func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sound_toggle.button_pressed = sound_enabled
	_apply_sound()


func toggle_hit_flash() -> void:
	hit_flash_enabled = not hit_flash_enabled
	hit_flash_toggle.button_pressed = hit_flash_enabled


func toggle_blood() -> void:
	blood_enabled = not blood_enabled
	blood_toggle.button_pressed = blood_enabled

func toggle_screen_shake() -> void:
	screen_shake_enabled = not screen_shake_enabled
	screen_shake_toggle.button_pressed = screen_shake_enabled

func _on_parallax_toggled(on: bool) -> void:
	parallax_enabled = on
	_apply_parallax(on)


func toggle_parallax() -> void:
	parallax_enabled = not parallax_enabled
	parallax_toggle.button_pressed = parallax_enabled
	_apply_parallax(parallax_enabled)


func _apply_parallax(on: bool) -> void:
	var i := 0
	for layer in parallax_bg.get_children():
		if layer is ParallaxLayer:
			layer.motion_scale = _parallax_layer_scales[i] if on else Vector2.ZERO
			i += 1
			
func _apply_sound() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, !sound_enabled)
