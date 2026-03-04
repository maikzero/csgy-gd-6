extends Camera2D

var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
const DEFAULT_OFFSET := Vector2(0, -30)

func shake(duration: float, intensity: float) -> void:
	if not SettingsManager.screen_shake_enabled:
		return
	_shake_duration = duration
	_shake_intensity = intensity

func _process(delta: float) -> void:
	if _shake_duration > 0.0:
		_shake_duration -= delta
		offset = DEFAULT_OFFSET + Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		offset = DEFAULT_OFFSET
