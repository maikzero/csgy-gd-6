extends Control

static var music_enabled: bool = true
static var sound_enabled: bool = true
static var hit_flash_enabled: bool = true
static var blood_enabled: bool = true
static var screen_shake_enabled: bool = true
static var hit_lag_enabled: bool = true
static var retro_filter_enabled: bool = false
static var parallax_enabled: bool = true
static var delay_bar_enabled: bool = true

signal delay_bar_toggled(enabled: bool)

@onready var panel: PanelContainer = $Panel
@onready var settings_button: Button = $SettingsButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/TitleRow/CloseButton
@onready var music_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/MusicRow/MusicToggle
@onready var sfx_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/SFXRow/SFXToggle
@onready var hit_flash_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/HitFlashRow/HitFlashToggle
@onready var blood_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/BloodRow/BloodToggle
@onready var screen_shake_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ScreenShakeRow/ScreenShakeToggle
@onready var hit_lag_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/HitLagRow/HitLagToggle
@onready var parallax_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ParallaxRow/ParallaxToggle
@onready var delay_bar_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/DelayBarRow/DelayBarToggle
@onready var retro_filter_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/RetroFilterRow/RetroFilterToggle
@onready var parallax_bg: ParallaxBackground = get_tree().current_scene.get_node("ParallaxBackground")
@onready var bgm: AudioStreamPlayer = get_tree().current_scene.get_node("BGM")
@onready var retro_filter: CanvasLayer = get_tree().current_scene.get_node("RetroFilter")

var _parallax_layer_scales: Array[Vector2] = []


func _ready() -> void:
	# Save original motion_scale for each ParallaxLayer so we can restore them
	for layer in parallax_bg.get_children():
		if layer is ParallaxLayer:
			_parallax_layer_scales.append(layer.motion_scale)
	settings_button.pressed.connect(_on_settings_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	music_toggle.toggled.connect(func(on):
		music_enabled = on
		_apply_music()
	)
	sfx_toggle.toggled.connect(func(on): sound_enabled = on)
	hit_flash_toggle.toggled.connect(func(on): hit_flash_enabled = on)
	blood_toggle.toggled.connect(func(on): blood_enabled = on)
	SettingsManager.screen_shake_enabled = screen_shake_toggle.button_pressed
	screen_shake_toggle.toggled.connect(func(on): SettingsManager.screen_shake_enabled = on)
	hit_lag_toggle.toggled.connect(func(on): hit_lag_enabled = on)
	parallax_toggle.toggled.connect(_on_parallax_toggled)
	delay_bar_toggle.toggled.connect(func(on):
		delay_bar_enabled = on
		delay_bar_toggled.emit(on)
	)
	retro_filter_toggle.toggled.connect(func(on):
		retro_filter_enabled = on
		retro_filter.visible = on
	)
	_apply_music()
	retro_filter.visible = retro_filter_enabled


func _on_settings_button_pressed() -> void:
	panel.visible = not panel.visible
	settings_button.visible = not settings_button.visible
	get_tree().paused = panel.visible


func _on_close_button_pressed() -> void:
	panel.visible = false
	settings_button.visible = true
	get_tree().paused = false
	_apply_music()


# Programmatic toggles (for other scripts to call)
func toggle_music() -> void:
	music_enabled = not music_enabled
	music_toggle.button_pressed = music_enabled
	_apply_music()


func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sfx_toggle.button_pressed = sound_enabled


func toggle_hit_flash() -> void:
	hit_flash_enabled = not hit_flash_enabled
	hit_flash_toggle.button_pressed = hit_flash_enabled


func toggle_blood() -> void:
	blood_enabled = not blood_enabled
	blood_toggle.button_pressed = blood_enabled

func toggle_screen_shake() -> void:
	SettingsManager.screen_shake_enabled = not SettingsManager.screen_shake_enabled
	screen_shake_toggle.button_pressed = SettingsManager.screen_shake_enabled

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

func _apply_music() -> void:
	bgm.stream_paused = not music_enabled
